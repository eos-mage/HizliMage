-- Rehber penceresi ve görev-adım motoru (v2).
--
-- Adım türleri (Route_*.lua, QuestieDB Forever verisinden üretildi):
--   G git (bölgeye var)      F uçuş noktası        H hearth bağla      R eğitmen
--   A görev al               D görev hedefleri     T görev teslim      L seviye kas
-- Her adımda q = görev kimlikleri, m/x/y = harita ve yüzde koordinat, lvl = gereken seviye.
-- Motor görev günlüğünü izler: görev alınınca A, hedefler bitince D, teslim edilince T kendiliğinden geçer.

local ADDON, ns = ...
local HM = ns.HM
local Guide = {}
HM.Guide = Guide

local FONT = "Fonts\\ARIALN.TTF"
local WIDTH = 320
local frame

local CHECK = "|TInterface\\RaidFrame\\ReadyCheck-Ready:12:12:0:0|t"
local KIND_LABEL = {
    G = "Git", F = "Uçuş", H = "Hearth", R = "Eğitmen", A = "Al", D = "Yap", T = "Teslim", L = "Kas", N = "Not",
}
local KIND_COLOR = {
    G = "|cff9ad0ff", F = "|cffc0a0ff", H = "|cffc0a0ff", R = "|cffc0a0ff", A = "|cffffd100", D = "|cffffffff",
    T = "|cff80ff80", L = "|cffff9050", N = "|cffcccccc",
}

local function Font(fs, size, flags)
    pcall(fs.SetFont, fs, FONT, size, flags or "")
    if not fs:GetFont() then fs:SetFontObject(GameFontHighlightSmall) end
end

local function Route() return ns.Route or {} end
local G_NEAR = 500   -- "Git" adımı: hedef noktaya bu kadar yaklaşınca tamam (yd)

function Guide:Step(i)
    return Route()[i or HM.db.step]
end

---------------------------------------------------------------------------
-- Görev durumu yardımcıları
---------------------------------------------------------------------------
local function flagged(qid)
    if HM.db and HM.db.doneQ and HM.db.doneQ[qid] then return true end
    if C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then
        local ok, res = pcall(C_QuestLog.IsQuestFlaggedCompleted, qid)
        if ok and res == true then return true end
    end
    if IsQuestFlaggedCompleted then
        local ok, res = pcall(IsQuestFlaggedCompleted, qid)
        if ok and res == true then return true end
    end
    return false
end

local function onQuest(qid)
    return HM:IsInQuestLog(qid, nil)
end

local function questComplete(qid)
    if C_QuestLog and C_QuestLog.IsComplete then
        local ok, res = pcall(C_QuestLog.IsComplete, qid)
        if ok and res == true then return true end
    end
    for _, q in ipairs(HM:GetQuestLog()) do
        if q.id == qid then return q.complete end
    end
    return false
end

Guide.QuestDone = flagged
Guide.OnQuest = onQuest

-- Rotadaki tüm görevler (Auto modülü yalnızca bunları otomatik alır).
function Guide:BuildQuestSet()
    local set, turnIn = {}, {}
    for i, s in ipairs(Route()) do
        if s.k == "A" and s.q then
            for _, q in ipairs(s.q) do set[q] = true end
        elseif s.k == "T" and s.q then
            for _, q in ipairs(s.q) do turnIn[q] = i end
        end
    end
    self.questSet = set
    self.turnIn = turnIn      -- görev -> teslim adımının sırası
    self.autoSkipped = {}
end

-- Ön koşulu (rotada) atlanmış ya da teslim edilmeden geçilmiş bir görev alınamaz: kendiliğinden atla.
function Guide:PrereqMissing(q, s, idx)
    if not (s.pre and s.pre[q]) then return false end
    local db = HM.db
    for _, p in ipairs(s.pre[q]) do
        if flagged(p) or onQuest(p) then
            -- ön koşul tamam ya da elde
        elseif db.questSkip and db.questSkip[p] then
            return true, p
        elseif self.turnIn and self.turnIn[p] and self.turnIn[p] < idx then
            return true, p
        end
    end
    return false
end

function Guide:QuestWanted(qid)
    if ns.UnavailableQuests and ns.UnavailableQuests[qid] then return false end
    -- Kamp görevleri (The Great Outdoors, Camping 101: ...) rota dışında da istenir: meslek buff'larını açar.
    if HM.Camp and HM.Camp.IsCampQuest and HM.Camp:IsCampQuest(qid) then return true end
    if not self.questSet then return true end
    return self.questSet[qid] == true
end

-- Oyuncunun bulunduğu adımda alınması gereken görevler (gossip sıralaması için).
function Guide:CurrentQuestIDs()
    local s = self:Step()
    if s and s.k == "A" then return s.q end
    return nil
end

---------------------------------------------------------------------------
-- Adım koşulları
---------------------------------------------------------------------------
local function parseRange(sec)
    if not sec then return end
    local a, b = sec:match("%((%d+)%-(%d+)%)")
    if a then return tonumber(a), tonumber(b) end
end

local function playerInMap(m)
    if not m then return true end
    return HM:PlayerMapChain()[m] == true
end

local function distanceTo(s)
    if not (s and s.m and s.x and s.y) then return end
    local px, py, pc = HM:PlayerWorldPos()
    local wx, wy, wc = HM:MapWorldPos(s.m, s.x, s.y)
    if not (px and wx) or pc ~= wc then return end
    return math.sqrt((wx - px) ^ 2 + (wy - py) ^ 2)
end

---------------------------------------------------------------------------
-- Akıllı yol tarifi: uçuş / Hearthstone adımları sabit değildir. Oyuncu plan dışına çıkınca
-- (Hearthstone'u erken kullanmak, ölmek, başka yerden dönmek) bulunduğu yere göre yeniden hesaplanır.
---------------------------------------------------------------------------
local TAXI_FIX, TAXI_RATE = 150, 0.22   -- planlayıcıyla aynı bedel: uçuş = 150 + 0.22 x mesafe (yürüyüş-eşdeğeri yd)
local FLY_MIN_SAVE = 400                -- plan dışı uçuş önermek için en az kazanç (yd)

local function isTravel(s)
    return (s and s.k == "G" and (s.fly or s.hs or s.tp)) and true or false
end

local function pointDist(m1, x1, y1, m2, x2, y2)
    local ax, ay, ac = HM:MapWorldPos(m1, x1, y1)
    local bx, by, bc = HM:MapWorldPos(m2, x2, y2)
    if not (ax and bx) or ac ~= bc then return end
    return math.sqrt((ax - bx) ^ 2 + (ay - by) ^ 2)
end

local function onTaxi()
    if UnitOnTaxi then
        local ok, r = pcall(UnitOnTaxi, "player")
        if ok and r and not HM.IsSecret(r) then return true end
    end
    return false
end

-- Uçuş görevlisi -> yer adı (uçuş haritasındaki düğüm adının başı)
local FP_PLACE = {
    ["Devrak"] = "Crossroads", ["Bragok"] = "Ratchet", ["Omusa Thunderhorn"] = "Camp Taurajo", ["Tharm"] = "Sun Rock Retreat",
    ["Vhulgra"] = "Splintertree Post", ["Andruk"] = "Zoram'gar Outpost", ["Zarise"] = "Tarren Mill", ["Nyse"] = "Freewind Post",
    ["Thalon"] = "Shadowprey Village", ["Urda"] = "Hammerfall", ["Thysta"] = "Grom'gol", ["Gringer"] = "Booty Bay",
    ["Shardi"] = "Brackenwall Village", ["Gorrik"] = "Kargath", ["Breyk"] = "Stonard", ["Shyn"] = "Camp Mojache",
    ["Bulkrek Ragefist"] = "Gadgetzan", ["Gorkas"] = "Revantusk Village", ["Grisha"] = "Thorium Point", ["Kroum"] = "Valormok",
    ["Brakkar"] = "Bloodvenom Post", ["Gryfe"] = "Marshal's Refuge", ["Vahgruk"] = "Flame Crest", ["Georgia"] = "Light's Hope Chapel",
    ["Yugrek"] = "Everlook", ["Runk Windtamer"] = "Cenarion Hold", ["Doras"] = "Orgrimmar", ["Michael Garrett"] = "Undercity",
    ["Tal"] = "Thunder Bluff",
}

local function fpKey(m, x, y)
    return m .. ":" .. math.floor(x + 0.5) .. ":" .. math.floor(y + 0.5)
end

-- Uçuş noktası adı: "Devrak (Crossroads)"; yalnız yer istenirse "Crossroads".
local function fpLabel(f, placeOnly)
    if not f then return "uçuş görevlisi" end
    if placeOnly then return f.place or f.npc or HM:MapName(f.m) end
    if f.npc and f.place and not f.npc:find("(", 1, true) then return f.npc .. " (" .. f.place .. ")" end
    return f.npc or f.place or HM:MapName(f.m)
end

-- Rotadaki uçuş noktalarının adları (görevli + yer), bir kez çıkarılır.
function Guide:FlightNames()
    local route = Route()
    if self.fpNames and self.fpNamesRoute == route then return self.fpNames end
    local names = {}
    local function slot(m, x, y)
        local k = fpKey(m, x, y)
        names[k] = names[k] or {}
        return names[k]
    end
    for _, s in ipairs(route) do
        if s.k == "F" and s.m and s.x and s.y then
            local npc = (s.t or ""):gsub("%s*%(uçuş noktasını al%)", "")
            local sl = slot(s.m, s.x, s.y)
            sl.npc = npc
            local bare = npc:gsub("%s*%(.*%)$", "")
            sl.place = sl.place or FP_PLACE[bare]
        elseif s.k == "G" and s.fly and s.fx and s.fy and s.m and s.x and s.y then
            local to = slot(s.m, s.x, s.y)
            to.place = to.place or (s.t or ""):match("^(.-) noktasına uç")
            local pl, npc = (s.n or ""):match("^(.-) uçuş görevlisi (.-)'a git")
            if pl then
                local from = slot(s.fm or s.m, s.fx, s.fy)
                from.place = from.place or pl
                from.npcShort = from.npcShort or npc
            end
        end
    end
    self.fpNames, self.fpNamesRoute = names, route
    return names
end

-- Rotada bu adıma kadar açılmış uçuş noktaları: geçilen "Uçuş" adımları ve uçuş adımlarının uçları.
function Guide:KnownFlightPoints(idx)
    idx = idx or HM.db.step
    local route = Route()
    local c = self.fpCache
    if c and c.idx == idx and c.route == route then return c.list end
    local names = self:FlightNames()
    local list, byKey = {}, {}
    local function add(m, x, y)
        if not (m and x and y) then return end
        local k = fpKey(m, x, y)
        if byKey[k] then return end
        local f = { m = m, x = x, y = y }
        f.wx, f.wy, f.wc = HM:MapWorldPos(m, x, y)
        local nm = names[k]
        if nm then f.npc, f.place = nm.npc or nm.npcShort, nm.place end
        -- Uçuş haritası bu kıtada açıldıysa ve nokta orada yoksa: karakter bu noktayı açmamış.
        local tn = HM.db.taxiNodes and f.wc ~= nil and HM.db.taxiNodes[f.wc]
        if tn and tn.ok and f.place then
            local pl, hit = f.place:lower(), false
            for name in pairs(tn.names) do
                if name:sub(1, #pl) == pl then hit = true; break end
            end
            if not hit then f.unknown = true end
        end
        byKey[k] = f
        list[#list + 1] = f
    end
    for i = 1, math.min(idx, #route) do
        local s = route[i]
        if s.k == "F" and i < idx then
            add(s.m, s.x, s.y)
        elseif s.k == "G" and s.fly and s.fx then
            add(s.fm or s.m, s.fx, s.fy)          -- plan bu kalkış noktasını açık sayıyor
            if i < idx then add(s.m, s.x, s.y) end
        end
    end
    self.fpCache = { idx = idx, route = route, list = list }
    return list
end

-- Yolculuk adımından sonraki ilk gerçek iş: konumu olan, kendisi yolculuk olmayan ve bitmemiş adım.
function Guide:NextAction(idx)
    local route = Route()
    for i = idx + 1, math.min(#route, idx + 10) do
        local s = route[i]
        if s and s.k ~= "N" and s.m and s.x and s.y and not isTravel(s) then
            local st = "wait"
            if s.k == "A" or s.k == "D" or s.k == "T" then
                local ok, r = pcall(self.Status, self, s, i)
                if ok then st = r end
            end
            if st ~= "done" and st ~= "skip" then return s, i end
        end
    end
end

-- Planlı uçuş adımı için tavsiye. Döndürür:
--   "skip"  uçuşa gerek kalmadı (sıradaki işe doğrudan yürümek daha kısa)
--   "walk"  varış noktasına yürümek uçmaktan kısa
--   "plan"  hesaplanamadı: plandaki kalkış noktası
--   tablo   en uygun kalkış uçuş noktası {m, x, y, npc, place}
function Guide:FlyAdvice(s, idx)
    local px, py, pc = HM:PlayerWorldPos()
    local dx, dy, dc = HM:MapWorldPos(s.m, s.x, s.y)
    if not (px and dx) or pc ~= dc then return "plan" end
    local best, bestA
    local pm = s.fm or s.m
    for _, a in ipairs(self:KnownFlightPoints(idx)) do
        local planned = (a.m == pm and math.abs(a.x - s.fx) < 1 and math.abs(a.y - s.fy) < 1)
        if a.wx and a.wc == pc and (planned or not a.unknown)
            and not (a.m == s.m and math.abs(a.x - s.x) < 1 and math.abs(a.y - s.y) < 1) then
            local cost = math.sqrt((a.wx - px) ^ 2 + (a.wy - py) ^ 2) + TAXI_FIX
                + TAXI_RATE * math.sqrt((a.wx - dx) ^ 2 + (a.wy - dy) ^ 2)
            if not best or cost < best then best, bestA = cost, a end
        end
    end
    local direct = math.sqrt((dx - px) ^ 2 + (dy - py) ^ 2)
    local nxt = self:NextAction(idx)
    if nxt then
        local nx, ny, nc = HM:MapWorldPos(nxt.m, nxt.x, nxt.y)
        if nx and nc == pc then
            local toNext = math.sqrt((nx - px) ^ 2 + (ny - py) ^ 2)
            local destNext = math.sqrt((nx - dx) ^ 2 + (ny - dy) ^ 2)
            local via = math.min(best or direct, direct) + destNext
            if toNext <= via + 50 then return "skip" end
        end
    end
    if not best or direct <= best then return "walk" end
    return bestA
end

-- Teleport kullanılabilir mi? (büyü biliniyor ve çantada Rune of Teleportation var; bilinmiyorsa "evet" say)
function Guide.TeleportUsable(spell)
    if Guide.SpellKnown(spell) == false then return false end
    if Guide.ItemCount(17031) == 0 then return false end
    return true
end

-- Geçiş zinciri (ışınlan -> eğitmen -> uç) boşa mı düştü? Oyuncu zincirin varacağı yere başka yoldan
-- (ör. doğrudan uçarak) zaten varmışsa zincirin kalan adımları geçilir.
function Guide:TransitArrived(idx)
    local route = Route()
    local dest
    for i = idx, math.min(#route, idx + 4) do
        local s = route[i]
        if not s then break end
        if s.k == "G" and s.fly then dest = s; break end
        if not (isTravel(s) or s.k == "R" or s.k == "N") then break end
    end
    if not dest then return false end
    local d = distanceTo(dest)
    return (d ~= nil and d <= G_NEAR and playerInMap(dest.m)) and true or false
end

-- Bölüme giriş adımı ([Git] / Teleport) boşa mı? Bölümün kalan adımlarında yapılacak iş kalmadıysa evet
-- (görevler bitmiş, bırakılmış ya da atlanmış): o bölgeye hiç gitmeden sonraki bölüme geçilir.
function Guide:SectionEmpty(idx)
    local route = Route()
    local sec = route[idx] and route[idx].sec
    if not sec then return false end
    local n = 0
    for i = idx + 1, math.min(#route, idx + 150) do
        local s = route[i]
        if not s or s.sec ~= sec then break end
        n = n + 1
        if s.k == "A" or s.k == "D" or s.k == "T" then
            local ok, st = pcall(self.Status, self, s, i)
            if not ok or (st ~= "done" and st ~= "skip") then return false end
        elseif s.k == "F" or s.k == "H" or s.k == "R" or s.k == "L" then
            return false
        elseif s.k == "G" and (s.learn or s.hs) then
            return false
        end
    end
    return n > 0
end

-- Hearthstone adımı boşa mı düştü? (sıradaki işe handan daha yakınız)
function Guide:HearthPointless(s, idx)
    local nxt = self:NextAction(idx)
    if not nxt then return false end
    local px, py, pc = HM:PlayerWorldPos()
    local nx, ny, nc = HM:MapWorldPos(nxt.m, nxt.x, nxt.y)
    local innNext = pointDist(s.m, s.x, s.y, nxt.m, nxt.x, nxt.y)
    if not (px and nx and innNext) or pc ~= nc then return false end
    return math.sqrt((nx - px) ^ 2 + (ny - py) ^ 2) <= innNext + 100
end

-- Herhangi bir adımın hedefine uçarak gitmek belirgin kısaysa: { from, to, save }. Değilse nil (yürü).
function Guide:TravelAdvice(s, idx)
    if not (s and s.m and s.x and s.y) or s.fly or onTaxi() then return nil end
    if s.tp and Guide.TeleportUsable(s.tp) then return nil end      -- ışınlanabiliyorsa uçuş önerme
    local px, py, pc = HM:PlayerWorldPos()
    local tx, ty, tc = HM:MapWorldPos(s.m, s.x, s.y)
    if not (px and tx) or pc ~= tc then return nil end
    local direct = math.sqrt((tx - px) ^ 2 + (ty - py) ^ 2)
    if direct < 600 then self.advFly = nil; return nil end
    local fps = self:KnownFlightPoints(idx)
    local best, bestA, bestB
    for _, a in ipairs(fps) do
        if a.wx and a.wc == pc and not a.unknown then
            local walkA = math.sqrt((a.wx - px) ^ 2 + (a.wy - py) ^ 2)
            if walkA < direct then
                for _, b in ipairs(fps) do
                    if b ~= a and b.wx and b.wc == pc and not b.unknown then
                        local cost = walkA + TAXI_FIX + TAXI_RATE * math.sqrt((a.wx - b.wx) ^ 2 + (a.wy - b.wy) ^ 2)
                            + math.sqrt((b.wx - tx) ^ 2 + (b.wy - ty) ^ 2)
                        if not best or cost < best then best, bestA, bestB = cost, a, b end
                    end
                end
            end
        end
    end
    -- kararsız gidip gelmesin: bir kez önerdiyse küçük kazançta da sürdür
    local need = (self.advFly == idx) and 150 or FLY_MIN_SAVE
    if best and direct - best >= need then
        self.advFly = idx
        return { from = bestA, to = bestB, save = direct - best }
    end
    self.advFly = nil
    return nil
end

-- Görev günlükte ama hedefleri bitmemiş mi? Hedefi olmayan (teslimat) görevler ve okunamayanlar: hayır.
local function questBlocked(qid)
    if questComplete(qid) then return false end
    if not (C_QuestLog and C_QuestLog.GetQuestObjectives) then return false end
    local ok, objs = pcall(C_QuestLog.GetQuestObjectives, qid)
    if not ok or type(objs) ~= "table" then return false end
    for _, o in ipairs(objs) do
        if type(o) == "table" then
            local f = o.finished
            if f ~= nil and not HM.IsSecret(f) and f == false then return true end
        end
    end
    return false
end

-- Döndürür: "done" (koşul sağlandı), "skip" (görev alınmamış/atlanmış), "wait", "level" (seviye yetersiz)
-- Görevin, adları verilen hedefleri bitti mi? true/false; hiçbiri eşleşmezse nil (görevin tamamına bakılır).
function Guide.ObjectivesDone(qid, names)
    if not (C_QuestLog and C_QuestLog.GetQuestObjectives) then return nil end
    local ok, objs = pcall(C_QuestLog.GetQuestObjectives, qid)
    if not ok or type(objs) ~= "table" then return nil end
    local matched = false
    for _, o in ipairs(objs) do
        if type(o) == "table" and type(o.text) == "string" and not HM.IsSecret(o.text) then
            local txt = o.text:lower()
            for _, nm in ipairs(names) do
                if txt:find(nm:lower(), 1, true) then
                    matched = true
                    if not o.finished then return false end
                    break
                end
            end
        end
    end
    if matched then return true end
    return nil
end

function Guide:Status(s, idx)
    if not s then return "wait" end
    local db = HM.db
    local k = s.k
    local level = HM:Level()
    if k == "A" then
        local allDone, anyOpen = true, false
        for _, q in ipairs(s.q or {}) do
            if flagged(q) or onQuest(q) or (db.questSkip and db.questSkip[q]) then
                -- bu görev tamam
            else
                local missing, p = self:PrereqMissing(q, s, idx)
                local unavailable = ns.UnavailableQuests and ns.UnavailableQuests[q]
                if missing or unavailable then
                    -- Yalnız sıradaki adımda kalıcı olarak atla; "sonraki adımlar" listesi için
                    -- hesaplanırken (ön koşul henüz alınmamış olabilir) sadece "-" göster.
                    if idx == db.step then
                        db.questSkip = db.questSkip or {}
                        db.questSkip[q] = true
                        if not self.autoSkipped[q] then
                            self.autoSkipped[q] = true
                            if missing then
                                HM:Print(string.format("Atlandı: görev %d (%s), ön koşulu olan %d numaralı görev yapılmamış.", q, s.npc or s.t or "", p))
                            else
                                HM:Print("Atlandı: " .. tostring(unavailable))
                            end
                        end
                    end
                else
                    allDone = false
                    anyOpen = true
                end
            end
        end
        if allDone then return "done" end
        if s.lvl and level < s.lvl then
            -- İsteğe bağlı adım (opt, ör. ön görev): seviye yetmiyorsa bekletme, geç.
            if s.opt and idx == db.step then return "skip" end
            return "level"
        end
        return "wait"
    elseif k == "D" then
        local pending = false
        for _, q in ipairs(s.q or {}) do
            if flagged(q) then
                -- bitti
            elseif onQuest(q) then
                if not questComplete(q) then
                    local hv = s.have and s.have[q]
                    if hv then
                        -- Malzeme durağı (ör. tüy topla, sonra yuvaya koy): günlükte hedefi yok, çantadaki adede bak.
                        if not Guide.HaveItems(hv) then pending = true end
                    elseif s.soft then
                        -- Yumuşak durak (ör. "eğitmenden mesleği öğren"): görevin sayılan hedefi yoksa bekletme;
                        -- yalnız açıkça bitmemiş bir hedef varsa bekle.
                        if questBlocked(q) then pending = true end
                    else
                        -- Görevin hedefleri birkaç durağa bölünmüşse yalnız bu duraktaki hedeflere bak.
                        local part = s.o and s.o[q]
                        if not (part and Guide.ObjectivesDone(q, part) == true) then pending = true end
                    end
                end
            else
                -- alınmamış ya da bırakılmış: atla
            end
        end
        if pending then return "wait" end
        local any = false
        for _, q in ipairs(s.q or {}) do if onQuest(q) or flagged(q) then any = true end end
        return any and "done" or "skip"
    elseif k == "T" then
        local pending, any, blocked = false, false, nil
        for _, q in ipairs(s.q or {}) do
            if flagged(q) then
                any = true
            elseif onQuest(q) then
                -- Hedefleri bitmemiş görev burada teslim edilemez: sıradaki adımda bekletme (yalnız o anki adım için).
                if idx == db.step and questBlocked(q) then blocked = blocked or q else pending = true end
            end
        end
        if pending then return "wait" end
        if blocked then
            self.blockedNote = self.blockedNote or {}
            if not self.blockedNote[idx] then
                self.blockedNote[idx] = true
                HM:Print(string.format("Geçildi: %s. Görevin hedefleri bitmemiş, şimdi teslim edilemez; bitirirsen bu NPC'ye dönüp elle teslim et.", s.t or tostring(blocked)))
            end
            return "skip"
        end
        return any and "done" or "skip"
    elseif k == "L" then
        return (level >= (s.lvl or 1)) and "done" or "wait"
    elseif k == "G" then
        if db.stepArrived == idx then return "done" end
        if s.learn then
            local known = Guide.SpellKnown(s.learn)
            if known == true then return "done" end
            -- Büyü öğrenilebilir durumdaysa (20+) eğitmenin yanına gelmek yetmez: öğrenene kadar bekle.
            if known == false and (HM:Level() or 0) >= 20 then return "wait" end
        end
        if idx == db.step and not onTaxi() then
            -- Plan dışına çıkıldıysa yolculuk adımı boşa düşmüş olabilir: kendiliğinden geç.
            if s.fly and s.fx then
                if self:FlyAdvice(s, idx) == "skip" then return "done" end
            elseif s.hs then
                if self:HearthPointless(s, idx) then return "done" end
            elseif s.tp then
                if self:TransitArrived(idx) or self:SectionEmpty(idx) then return "done" end
            elseif not s.learn then
                -- Bölüme giriş: bölümde yapılacak iş kalmadıysa oraya gitmeye gerek yok.
                if self:SectionEmpty(idx) then return "done" end
            end
        end
        if playerInMap(s.m) then
            -- Bölgedeyiz: hedef kasabaya yaklaşınca tamam (uzaklık hesaplanamıyorsa bölge yeter).
            local d = distanceTo(s)
            if s.near then
                if d and d <= s.near then return "done" end
            elseif not d or d <= G_NEAR then
                return "done"
            end
        end
        return "wait"
    elseif k == "F" then
        if db.stepArrived == idx then return "done" end
        local d = distanceTo(s)
        if d and d <= 8 then return "done" end
        return "wait"
    elseif k == "H" then
        if db.stepArrived == idx then return "done" end
        local d = distanceTo(s)
        if d and d <= 40 and GetBindLocation and GetMinimapZoneText then
            local okB, loc = pcall(GetBindLocation)
            local okZ, zone = pcall(GetMinimapZoneText)
            if okB and okZ and type(loc) == "string" and loc ~= "" and loc == zone then
                db.bind = { m = s.m, x = s.x, y = s.y }
                return "done"
            end
        end
        return "wait"
    elseif k == "R" then
        if db.stepTrained then return "done" end
        -- Başkentten geçmeden (ör. doğrudan uçarak) hedef bölgeye vardıysak eğitim sonraki geçişe kalır.
        if idx == db.step and s.m and not playerInMap(s.m) and self:TransitArrived(idx) then return "done" end
        -- Son çift seviyeden beri eğitmene gidilmişse (öğrenilecek büyü kalmadı) adım tamam sayılır.
        if (db.trainPending or 0) == 0 and (HM:Level() or 0) >= 4 then return "done" end
        return "wait"
    elseif k == "N" then
        return "done"
    end
    return "wait"
end

---------------------------------------------------------------------------
-- Pencere
---------------------------------------------------------------------------
local function MakeButton(parent, text, width, onClick, tip)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width, 20)
    b:SetText(HM:T(text))
    local fs = b:GetFontString()
    if fs then Font(fs, 11) end
    b:SetScript("OnClick", onClick)
    if tip then
        b:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(HM:T(tip), 1, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    b.label = text
    return b
end

function Guide:Create()
    if frame then return end
    local db = HM.db
    frame = CreateFrame("Frame", "HizliMageFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    frame:SetWidth(WIDTH)
    frame:SetHeight(160)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, _, x, y = self:GetPoint()
        db.frame.point, db.frame.x, db.frame.y = point, x, y
    end)
    if frame.SetBackdrop then
        frame:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 14,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        frame:SetBackdropColor(0.05, 0.06, 0.1, 0.88)
        frame:SetBackdropBorderColor(0.25, 0.65, 0.95, 0.9)
    end

    frame.header = frame:CreateFontString(nil, "OVERLAY")
    Font(frame.header, 11)
    frame.header:SetPoint("TOPLEFT", 10, -8)
    frame.header:SetWidth(WIDTH - 80)
    frame.header:SetJustifyH("LEFT")
    frame.header:SetTextColor(0.25, 0.78, 0.92)
    frame.header:SetWordWrap(false)      -- uzun bölüm adı ikinci satıra sarıp adım başlığının üstüne binmesin
    frame.header:SetMaxLines(1)

    frame.close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    frame.close:SetSize(22, 22)
    frame.close:SetPoint("TOPRIGHT", 0, 0)
    frame.close:SetScript("OnClick", function() Guide:Toggle(false) end)

    frame.collapse = CreateFrame("Button", nil, frame)
    frame.collapse:SetSize(18, 18)
    frame.collapse:SetPoint("RIGHT", frame.close, "LEFT", 2, 0)
    frame.collapse.text = frame.collapse:CreateFontString(nil, "OVERLAY")
    Font(frame.collapse.text, 14, "OUTLINE")
    frame.collapse.text:SetPoint("CENTER")
    frame.collapse:SetScript("OnClick", function()
        db.frame.collapsed = not db.frame.collapsed
        Guide:Refresh()
    end)

    -- Menü çarkı: pencere daraltılmışken de görünür; komut ezberlemeden ayarlar (Menu.lua).
    frame.menuBtn = CreateFrame("Button", nil, frame)
    frame.menuBtn:SetSize(16, 16)
    frame.menuBtn:SetPoint("RIGHT", frame.collapse, "LEFT", -2, 0)
    frame.menuBtn.tex = frame.menuBtn:CreateTexture(nil, "ARTWORK")
    frame.menuBtn.tex:SetAllPoints()
    HM.SetIcon(frame.menuBtn.tex, "OptionsIcon-Brown", "Interface\\Buttons\\UI-OptionsButton")
    frame.menuBtn:SetScript("OnClick", function()
        if HM.Menu then HM.Menu:Toggle(frame) else HM:Print("Menü modülü yüklenmemiş. Oyunu tamamen kapatıp aç.") end
    end)
    frame.menuBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(HM:T("Menü: pinler, uyarılar, otomatik işler — tek tıkla aç/kapat"), 1, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    frame.menuBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    frame.title = frame:CreateFontString(nil, "OVERLAY")
    Font(frame.title, 13, "OUTLINE")
    frame.title:SetPoint("TOPLEFT", 10, -24)
    frame.title:SetWidth(WIDTH - 20)
    frame.title:SetJustifyH("LEFT")
    frame.title:SetTextColor(1, 0.82, 0)

    -- Başlığa tıklayınca ok tekrar adımın hedefine döner.
    frame.titleButton = CreateFrame("Button", nil, frame)
    frame.titleButton:SetAllPoints(frame.title)
    frame.titleButton:SetScript("OnClick", function() Guide:PointStep() end)

    frame.recent = frame:CreateFontString(nil, "OVERLAY")
    Font(frame.recent, 11)
    frame.recent:SetPoint("TOPLEFT", frame.title, "BOTTOMLEFT", 0, -3)
    frame.recent:SetWidth(WIDTH - 20)
    frame.recent:SetJustifyH("LEFT")
    frame.recent:SetJustifyV("TOP")
    frame.recent:SetTextColor(0.45, 0.8, 0.45)

    frame.body = frame:CreateFontString(nil, "OVERLAY")
    Font(frame.body, 12)
    frame.body:SetPoint("TOPLEFT", frame.recent, "BOTTOMLEFT", 0, -3)
    frame.body:SetWidth(WIDTH - 20)
    frame.body:SetJustifyH("LEFT")
    frame.body:SetJustifyV("TOP")
    if frame.body.SetSpacing then frame.body:SetSpacing(1) end
    frame.body:SetTextColor(0.93, 0.93, 0.93)

    frame.upcoming = frame:CreateFontString(nil, "OVERLAY")
    Font(frame.upcoming, 11)
    frame.upcoming:SetWidth(WIDTH - 20)
    frame.upcoming:SetJustifyH("LEFT")
    frame.upcoming:SetJustifyV("TOP")
    frame.upcoming:SetTextColor(0.62, 0.62, 0.62)

    frame.status1 = frame:CreateFontString(nil, "OVERLAY")
    Font(frame.status1, 11)
    frame.status1:SetWidth(WIDTH - 20)
    frame.status1:SetJustifyH("LEFT")
    frame.status1:SetJustifyV("TOP")
    frame.status1:SetWordWrap(true)
    frame.status1:SetNonSpaceWrap(true)
    frame.status1:SetTextColor(0.6, 0.85, 1)

    -- XP satırı (status1) üstüne mouse gelince kalan XP vb. detaylar tooltip olarak çıksın.
    frame.status1Hit = CreateFrame("Frame", nil, frame)
    frame.status1Hit:SetSize(WIDTH - 20, 16)
    frame.status1Hit:SetPoint("TOPLEFT", frame.status1, "TOPLEFT", 0, 0)
    frame.status1Hit:SetFrameStrata(frame:GetFrameStrata() or "MEDIUM")
    frame.status1Hit:SetFrameLevel((frame:GetFrameLevel() or 0) + 20)
    frame.status1Hit:EnableMouse(true)
    frame.status1Hit:SetScript("OnEnter", function(self)
        local xp, max = UnitXP("player") or 0, UnitXPMax("player") or 1
        local rem = max - xp
        local rested = GetXPExhaustion and GetXPExhaustion() or 0
        local level = HM:Level()
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(string.format("XP durumu — seviye %d", level), 1, 0.82, 0)
        GameTooltip:AddLine(string.format("Mevcut: %s / %s (%%%d)",
            HM:Short(xp), HM:Short(max), math.floor(xp / max * 100)), 1, 1, 1)
        GameTooltip:AddLine(string.format("|cff80ff80Seviyeye kalan:|r %s XP", HM:Short(rem)), 1, 1, 1)
        if rested and rested > 0 then
            GameTooltip:AddLine(string.format("|cff8080ffDinlenmiş:|r %s XP (%%%d)",
                HM:Short(rested), math.floor(rested / max * 100)), 1, 1, 1)
        end
        local rate = (HM.Stats and HM.Stats.Rate) and HM.Stats:Rate() or 0
        if rate > 0 then
            local eta = rem / rate * 3600
            GameTooltip:AddLine(string.format("|cffffd100Son 15 dk hız:|r %s XP/sa  →  %s",
                HM:Short(rate), HM:Duration(eta)), 1, 1, 1)
        end
        GameTooltip:Show()
    end)
    frame.status1Hit:SetScript("OnLeave", function() GameTooltip:Hide() end)

    frame.status2 = frame:CreateFontString(nil, "OVERLAY")
    Font(frame.status2, 11)
    frame.status2:SetWidth(WIDTH - 20)
    frame.status2:SetJustifyH("LEFT")
    frame.status2:SetTextColor(0.85, 0.85, 0.6)

    frame.status3 = frame:CreateFontString(nil, "OVERLAY")
    Font(frame.status3, 11)
    frame.status3:SetWidth(WIDTH - 20)
    frame.status3:SetJustifyH("LEFT")
    frame.status3:SetTextColor(1, 0.55, 0.2)

    -- Alt sıra toplam 304 + 8 kenar = 312 (pencere 320): Menü düğmesi sığsın diye diğerleri biraz daraltıldı.
    local bPrev = MakeButton(frame, "<", 22, function() Guide:Prev() end, "Önceki adım")
    local bNext = MakeButton(frame, ">", 22, function() Guide:Next() end, "Sonraki adım")
    local bDone = MakeButton(frame, "Tamam", 50, function() Guide:Complete() end, "Bu adımı bitir / atla (alınamayan görev varsa atlar)")
    local bGrind = MakeButton(frame, "Kas", 36, function() Guide:PointGrind() end, "Seviyene uygun kasma noktası")
    local bTrain = MakeButton(frame, "Eğitmen", 58, function() if HM.Trainer then HM.Trainer:PointTrainer("class") end end, "En yakın sınıf eğitmeni")
    local bDung = MakeButton(frame, "Zindan", 50, function()
        if HM.Dungeons then HM.Dungeons:TogglePicker(frame) else Guide:ListDungeons() end
    end, "Seviyene uygun zindanlar — tıkla, birini seç")
    local bMenu = MakeButton(frame, "Menü", 44, function()
        if HM.Menu then HM.Menu:Toggle(frame) else HM:Print("Menü modülü yüklenmemiş. Oyunu tamamen kapatıp aç.") end
    end, "Ayarlar menüsü: pinler, uyarılar, otomatik işler — tek tıkla aç/kapat")
    bPrev:SetPoint("BOTTOMLEFT", 8, 8)
    bNext:SetPoint("LEFT", bPrev, "RIGHT", 2, 0)
    bDone:SetPoint("LEFT", bNext, "RIGHT", 4, 0)
    bGrind:SetPoint("LEFT", bDone, "RIGHT", 4, 0)
    bTrain:SetPoint("LEFT", bGrind, "RIGHT", 4, 0)
    bDung:SetPoint("LEFT", bTrain, "RIGHT", 4, 0)
    bMenu:SetPoint("LEFT", bDung, "RIGHT", 4, 0)
    frame.buttons = { bPrev, bNext, bDone, bGrind, bTrain, bDung, bMenu }

    self:Reposition()
    self:ApplyScale()
    if db.frame.shown then frame:Show() else frame:Hide() end

    -- Durum satırları saniyede bir, görev hedefleri 2 saniyede bir güncellenir.
    local acc, acc2 = 0, 0
    frame:SetScript("OnUpdate", function(_, elapsed)
        acc = acc + elapsed
        acc2 = acc2 + elapsed
        if acc >= 1 then
            acc = 0
            Guide:UpdateStatus()
        end
        if acc2 >= 2 then
            acc2 = 0
            local s = Guide:Step()
            if s and (s.k == "D" or s.k == "G" or s.k == "F") then Guide:Refresh(true) end
        end
    end)
end

function Guide:Reposition()
    if not frame then return end
    local f = HM.db.frame
    frame:ClearAllPoints()
    frame:SetPoint(f.point or "RIGHT", UIParent, f.point or "RIGHT", f.x or -40, f.y or 120)
end

function Guide:ApplyScale()
    if frame then frame:SetScale(HM.db.frame.scale or 1) end
end

function Guide:Toggle(show)
    if not frame then return end
    if show == nil then show = not frame:IsShown() end
    HM.db.frame.shown = show
    if show then frame:Show(); self:Refresh() else frame:Hide() end
end

local function stepTitle(s)
    if not s then return "" end
    return string.format("%s[%s]|r %s", KIND_COLOR[s.k] or "|cffffffff", KIND_LABEL[s.k] or s.k, s.t or "")
end

local function objectiveLines(qid)
    local lines = {}
    if not (C_QuestLog and C_QuestLog.GetQuestObjectives) then return lines end
    local ok, objs = pcall(C_QuestLog.GetQuestObjectives, qid)
    if not ok or type(objs) ~= "table" then return lines end
    for _, o in ipairs(objs) do
        if type(o) == "table" and o.text and not HM.IsSecret(o.text) then
            local txt = o.text
            if o.finished then
                lines[#lines + 1] = CHECK .. " " .. txt
            else
                lines[#lines + 1] = "• " .. txt
            end
        end
    end
    return lines
end

function Guide:BodyText(s, status)
    local parts = {}

    -- Koordinat ve lokasyon bilgisi: her adımda nereye gideceğin belli olsun
    if s.x and s.y then
        local locLine = string.format("|cff888888(%.0f, %.0f)|r", s.x, s.y)
        if s.npc and s.npc ~= "" and s.k == "A" then
            locLine = locLine .. "  |cff88bbdd" .. s.npc .. "|r"
        end
        parts[#parts + 1] = locLine
    end

    -- Minimum seviye uyarısı: level yetersizse kırmızı göster
    if s.lvl and s.lvl > 1 then
        local myLevel = HM:Level()
        if myLevel < s.lvl then
            parts[#parts + 1] = string.format("|cffff6060! Seviye %d gerekli|r (sen %d)", s.lvl, myLevel)
        end
    end

    local note = s.n
    if s.fly and s.fx and s.fy then
        -- Uçuş adımı: kalkış noktası oyuncunun o anki yerine göre.
        local adv = self:FlyAdvice(s, HM.db.step)
        if adv == "walk" then
            note = "|cff80ff80Varış noktası yakın:|r uçmaya gerek yok, yürü."
        elseif type(adv) == "table" and not (adv.m == (s.fm or s.m) and math.abs(adv.x - s.fx) < 1 and math.abs(adv.y - s.fy) < 1) then
            note = string.format("|cff80ff80Sana en uygun uçuş görevlisi %s (%.0f, %.0f):|r oradan %s.", fpLabel(adv), adv.x, adv.y, s.t or "uç")
        end
    end
    if note and note ~= "" then parts[#parts + 1] = note end
    if s.k == "A" then
        if s.item then parts[#parts + 1] = "|cffffd100Eşya görevi:|r düşen eşyaya çantadan sağ tıkla." end
        -- Görev günlüğü doluysa uyar (zindan görevleri yer tutuyor olabilir).
        local okL, logL = pcall(HM.GetQuestLog, HM)
        if okL and type(logL) == "table" then
            local maxQ = 20
            if C_QuestLog and C_QuestLog.GetMaxNumQuestsCanAccept then
                local okM, m = pcall(C_QuestLog.GetMaxNumQuestsCanAccept)
                if okM and type(m) == "number" and not HM.IsSecret(m) and m > 0 then maxQ = m end
            end
            if #logL >= maxQ then
                parts[#parts + 1] = string.format("|cffff6060Görev günlüğü dolu (%d/%d):|r önce bir görevi teslim et ya da bırak.", #logL, maxQ)
            end
        end
        if status == "level" then
            parts[#parts + 1] = string.format("|cffff6060Seviye %d gerekiyor|r (sen %d). Yakında kas ya da Tamam ile atla.", s.lvl or 1, HM:Level())
        else
            local missing = {}
            for _, q in ipairs(s.q or {}) do
                if not (flagged(q) or onQuest(q)) then missing[#missing + 1] = q end
            end
            if #missing > 0 and #missing < #(s.q or {}) then
                parts[#parts + 1] = string.format("%d görev alındı, %d kaldı. NPC vermiyorsa Tamam ile atla.", #(s.q) - #missing, #missing)
            end
        end
    elseif s.k == "D" then
        for _, q in ipairs(s.q or {}) do
            if onQuest(q) then
                local hv = s.have and s.have[q]
                if hv then
                    -- Malzeme durağı: görev günlüğünde sayacı yok, çantadan say.
                    for id, n in pairs(hv) do
                        local c = Guide.ItemCount(id)
                        if c then
                            parts[#parts + 1] = string.format("%s Çantada %d/%d", (c >= n) and CHECK or "•", c, n)
                        else
                            parts[#parts + 1] = string.format("• %d adet topla (sayılamadı: toplayınca Tamam'a bas)", n)
                        end
                    end
                    parts[#parts + 1] = "|cff888888Bu eşya görevin sonraki adımında kullanılacak.|r"
                else
                    for _, l in ipairs(objectiveLines(q)) do parts[#parts + 1] = l end
                end
            end
        end
    elseif s.k == "T" then
        local ready, notReady = 0, 0
        for _, q in ipairs(s.q or {}) do
            if onQuest(q) then
                if questComplete(q) then ready = ready + 1 else notReady = notReady + 1 end
            end
        end
        if notReady > 0 then parts[#parts + 1] = string.format("|cffff9050%d görev henüz tamamlanmadı.|r", notReady) end
    elseif s.k == "L" then
        parts[#parts + 1] = string.format("Hedef seviye %d (sen %d).", s.lvl or 1, HM:Level())
    elseif s.k == "H" then
        parts[#parts + 1] = "Hancıyla konuş, burayı evin yap. Zaten buraya bağlıysan yanına gelince geçer (ya da Tamam)."
    elseif s.k == "G" or s.k == "F" then
        local d = distanceTo(s)
        if d then parts[#parts + 1] = string.format("Uzaklık: %d yd", math.floor(d)) end
        if s.k == "F" then parts[#parts + 1] = "Uçuş görevlisiyle konuş; harita açılınca geçer (nokta zaten açıksa da)." end
        if s.tp then
            local known = Guide.SpellKnown(s.tp)
            if known == false then
                parts[#parts + 1] = "|cffff9050Bu Teleport öğrenilmemiş: şehirdeki portal eğitmeninden öğren; şimdilik uçarak git.|r"
            else
                local runes = Guide.ItemCount(17031)
                if runes == 0 then
                    parts[#parts + 1] = "|cffff6060Rune of Teleportation yok:|r reagent satıcısından al; şimdilik uçarak git."
                elseif runes then
                    parts[#parts + 1] = string.format("|cff80ff80Rune of Teleportation: %d|r", runes)
                end
            end
        end
        if s.learn and Guide.SpellKnown(s.learn) == false then
            parts[#parts + 1] = "Portal eğitmeniyle konuş; büyüyü öğrenince adım geçer."
        end
        if s.hs then
            local hsState = Guide.HearthState()
            local bind = HM.db.bind
            local bd = bind and bind.m and pointDist(bind.m, bind.x, bind.y, s.m, s.x, s.y)
            if bind and bind.m and (not bd or bd > 200) then
                parts[#parts + 1] = "|cffff9050Hearth'ün bu hana bağlı değil: yürüyerek/uçarak dön (ya da hana bağla).|r"
            elseif hsState == true then
                parts[#parts + 1] = "|cff80ff80Hearthstone hazır.|r"
            elseif type(hsState) == "number" then
                parts[#parts + 1] = string.format("|cffff9050Hearthstone beklemede (%d dk): yürüyerek dön.|r", math.ceil(hsState / 60))
            end
        end
    end
    -- Hearthstone hazırsa ve hedef bağlı hanın dibindeyse: uzun yürüyüş yerine hearth öner.
    local hearthHint = false
    if not s.hs and s.m and s.x and s.y then
        local bind = self:BindSpot()
        if bind and bind.m then
            local d = distanceTo(s)
            if d and d > 800 then
                local bx, by, bc = HM:MapWorldPos(bind.m, bind.x, bind.y)
                local wx, wy, wc = HM:MapWorldPos(s.m, s.x, s.y)
                if bx and wx and bc == wc then
                    local near = math.sqrt((bx - wx) ^ 2 + (by - wy) ^ 2)
                    if near < 300 and Guide.HearthState() == true then
                        parts[#parts + 1] = string.format("|cff80ff80Hearthstone hazır:|r kullanırsan ~%d yd yürümezsin.", math.floor(d - near))
                        hearthHint = true
                    end
                end
            end
        end
    end
    -- Plan dışı bir yerdeysen ve uçmak belirgin kısaysa söyle (ok da o uçuş görevlisini gösterir).
    if not hearthHint and not s.fly and not (s.hs and Guide.HearthState() == true) then
        local adv = self:TravelAdvice(s, HM.db.step)
        if adv then
            parts[#parts + 1] = string.format("|cff80ff80Uçarak git:|r %s uçuş görevlisinden %s noktasına uç (yaklaşık %d yd daha az yürüyüş).",
                fpLabel(adv.from), fpLabel(adv.to, true), math.floor(adv.save / 50 + 0.5) * 50)
        end
    end
    -- Endgame zincir etiketi: bu adımdaki görev bir endgame zincirinin parçasıysa göster
    if HM.Chains and s.q then
        for _, q in ipairs(s.q) do
            local tag = HM.Chains:GetChainTag(q)
            if tag then
                parts[#parts + 1] = tag
                break
            end
        end
    end

    return table.concat(parts, "\n")
end

-- Yapılmış son adımlar (yeşil ✓): bu karakterin bitirdiği görevler görünür kalsın.
function Guide:RecentText()
    local route = Route()
    local out = {}
    local i = HM.db.step - 1
    while route[i] and #out < 2 do
        local s = route[i]
        if s.k == "A" or s.k == "T" or s.k == "D" then
            local st = self:Status(s, i)
            local mark = (st == "skip") and "-" or CHECK
            table.insert(out, 1, mark .. " " .. (KIND_LABEL[s.k] or s.k) .. ": " .. (s.t or ""))
        end
        i = i - 1
    end
    return table.concat(out, "\n")
end

function Guide:UpcomingText()
    local route = Route()
    local out = {}
    local i = HM.db.step + 1
    local n = 0
    while route[i] and n < 3 do
        local s = route[i]
        if s.k ~= "N" then
            local mark = ">"
            if s.k == "A" or s.k == "T" or s.k == "D" then
                local st = self:Status(s, i)
                if st == "done" then mark = CHECK elseif st == "skip" then mark = "|cff888888-|r" end
            end
            out[#out + 1] = mark .. " " .. (KIND_LABEL[s.k] or s.k) .. ": " .. (s.t or "")
            n = n + 1
        end
        i = i + 1
    end
    return table.concat(out, "\n")
end

-- /hm liste: bulunduğun bölümün adımları, yapılanlar ✓ ile.
function Guide:ListSection()
    local route = Route()
    local cur = route[HM.db.step]
    if not cur then return end
    local sec = cur.sec
    local first = HM.db.step
    while first > 1 and route[first - 1].sec == sec do first = first - 1 end
    HM:Print("Bölüm: " .. (sec or "") .. "  (" .. CHECK .. " yapıldı, >> şimdiki, - sırada)")
    local i = first
    local shown = 0
    while route[i] and route[i].sec == sec and shown < 40 do
        local s = route[i]
        local mark
        if i < HM.db.step then
            mark = CHECK
        elseif i == HM.db.step then
            mark = "|cffffd100>>|r"
        else
            local st = (s.k == "A" or s.k == "T" or s.k == "D") and self:Status(s, i) or "wait"
            mark = (st == "done") and CHECK or "-"
        end
        HM:Print(string.format("%s %d %s: %s", mark, i, KIND_LABEL[s.k] or s.k, s.t or ""))
        shown = shown + 1
        i = i + 1
    end
end

function Guide:Refresh(light)
    if not frame then return end
    local db = HM.db
    local route = Route()
    local s = route[db.step]
    if not s then
        frame.title:SetText(HM:T("Rota yüklenemedi"))
        return
    end
    local status = self:Status(s, db.step)

    frame.header:SetText(HM:T(string.format("%d/%d  •  %s", db.step, #route, s.sec or "")))
    frame.title:SetText(HM:T(stepTitle(s)))
    frame.collapse.text:SetText(db.frame.collapsed and "+" or "–")

    local collapsed = db.frame.collapsed
    local h = 30 + frame.title:GetStringHeight()
    if collapsed then
        frame.body:Hide(); frame.upcoming:Hide(); frame.recent:Hide()
        frame.status1:Hide(); frame.status2:Hide(); frame.status3:Hide()
        if frame.status1Hit then frame.status1Hit:Hide() end
        for _, b in ipairs(frame.buttons) do b:Hide() end
        frame:SetHeight(h + 6)
        return
    end

    frame.recent:Show()
    frame.recent:SetText(HM:T(self:RecentText()))
    local recentH = frame.recent:GetStringHeight()
    if (frame.recent:GetText() or "") == "" then recentH = 0 end
    h = h + 3 + recentH

    frame.body:Show()
    frame.body:SetText(HM:T(self:BodyText(s, status)))
    local bodyH = frame.body:GetStringHeight()
    if (frame.body:GetText() or "") == "" then bodyH = 0 end
    h = h + 4 + bodyH

    frame.upcoming:ClearAllPoints()
    frame.upcoming:SetPoint("TOPLEFT", frame.body, "BOTTOMLEFT", 0, -4)
    frame.upcoming:SetText(HM:T(self:UpcomingText()))
    frame.upcoming:Show()
    h = h + 4 + frame.upcoming:GetStringHeight()

    frame.status1:ClearAllPoints()
    frame.status1:SetPoint("TOPLEFT", frame.upcoming, "BOTTOMLEFT", 0, -6)
    frame.status2:ClearAllPoints()
    frame.status2:SetPoint("TOPLEFT", frame.status1, "BOTTOMLEFT", 0, -2)
    frame.status3:ClearAllPoints()
    frame.status3:SetPoint("TOPLEFT", frame.status2, "BOTTOMLEFT", 0, -2)
    frame.status1:Show(); frame.status2:Show(); frame.status3:Show()
    if frame.status1Hit then frame.status1Hit:Show() end
    for _, b in ipairs(frame.buttons) do b:Show() end

    self:UpdateStatus(true)
    h = h + 6 + frame.status1:GetStringHeight() + 2 + frame.status2:GetStringHeight()
    if frame.status3:GetText() and frame.status3:GetText() ~= "" then
        h = h + 2 + frame.status3:GetStringHeight()
    end
    frame:SetHeight(h + 40)
end

function Guide:UpdateStatus(noResize)
    if not frame or not frame:IsShown() or HM.db.frame.collapsed then return end
    local s1 = HM.Stats and HM.Stats:XPText() or ""
    local pend = HM.Extras and HM.Extras:PendingXPText()
    if pend and pend ~= "" then s1 = s1 .. "  •  " .. pend end
    local parts = {}
    if HM.Stats then parts[#parts + 1] = HM.Stats:GoldText() end
    if HM.Bags then parts[#parts + 1] = HM.Bags:SupplyText() end
    if HM.XpBuffs then
        local xpLine = HM.XpBuffs:StatusLine()
        if xpLine then parts[#parts + 1] = xpLine end
    end
    local s3 = HM.Trainer and HM.Trainer:PendingText() or ""
    -- Kamp: şimdi yapılacak iş (ateş kur, eşya koy, otur) ya da bulunduğun kasabadaki kamp işi.
    if HM.Camp and HM.Camp.ActionLine then
        local okC, c = pcall(HM.Camp.ActionLine, HM.Camp)
        if okC and c and c ~= "" then s3 = (s3 ~= "" and (s3 .. "\n") or "") .. c end
    end
    -- Kitap: yakında kitap varsa (200 yd içi) ya da Undercity'de biriken kitap varsa.
    if HM.Books then
        if HM.Books.ActionLine then
            local okB, c = pcall(HM.Books.ActionLine, HM.Books)
            if okB and c and c ~= "" then s3 = (s3 ~= "" and (s3 .. "\n") or "") .. c end
        end
        if HM.Books.CityErrand then
            local okE, e = pcall(HM.Books.CityErrand, HM.Books)
            if okE and e and e ~= "" then s3 = (s3 ~= "" and (s3 .. "\n") or "") .. e end
        end
    end
    local oldH = frame.status3:GetStringHeight()
    local hadS3 = (frame.status3:GetText() or "") ~= ""
    frame.status1:SetText(HM:T(s1))
    frame.status2:SetText(HM:T(table.concat(parts, "  •  ")))
    frame.status3:SetText(HM:T(s3))
    if frame.status1Hit then
        local h = frame.status1:GetStringHeight() or 14
        if h < 14 then h = 14 end
        frame.status1Hit:SetHeight(h + 2)
    end
    -- Satır eklendi/kalktı ya da satır sayısı değiştiyse pencere yüksekliğini yenile.
    if not noResize and (hadS3 ~= (s3 ~= "") or (s3 ~= "" and oldH ~= frame.status3:GetStringHeight())) then self:Refresh() end
end

---------------------------------------------------------------------------
-- Adım motoru
---------------------------------------------------------------------------
-- Oku sıradaki adıma çevirir. Uçuş gerekiyorsa (planlı ya da plan dışı) önce en uygun uçuş görevlisini gösterir.
-- keep = true: hedef değişmediyse oka dokunma (periyodik yenileme için). Döndürür: hedef değişti mi.
function Guide:PointStep(keep)
    local s = self:Step()
    if not s or not HM.Arrow or not s.m or not s.x or not s.y then return false end
    local idx = HM.db.step
    local cur = HM.Arrow.GetTarget and HM.Arrow:GetTarget()
    if keep then
        if not HM:PlayerWorldPos() then return false end        -- konum okunamıyor (savaş/yükleme): bekle
        -- Oyuncu oku başka bir şeye çevirdiyse (kasma noktası, zindan, eğitmen) periyodik yenileme dokunmaz.
        if cur and cur.kind ~= "step" then return false end
    end
    local tm, tx, ty, label = s.m, s.x, s.y, s.t
    self.redirect = nil
    if s.fly and s.fx and s.fy then
        local d = distanceTo(s)
        if not d or d > G_NEAR then
            local adv = self:FlyAdvice(s, idx)
            if type(adv) == "table" then
                tm, tx, ty, label = adv.m, adv.x, adv.y, "Uçuş görevlisi: " .. fpLabel(adv)
            elseif adv ~= "walk" then
                tm, tx, ty, label = (s.fm or s.m), s.fx, s.fy, "Uçuş görevlisi"
            end
            self.redirect = true
        end
    elseif not (s.hs and Guide.HearthState() == true) then
        local adv = self:TravelAdvice(s, idx)
        if adv then
            tm, tx, ty, label = adv.from.m, adv.from.x, adv.from.y, "Uçuş görevlisi: " .. fpLabel(adv.from)
            self.redirect = true
        end
    end
    local same = cur and cur.kind == "step" and cur.m == tm and cur.x == tx and cur.y == ty and cur.label == (label or "")
    if keep and same then return false end
    HM.Arrow:SetTarget(tm, tx, ty, label, "step")
    return not same
end

-- Seviyeye uygun kasma noktası (ns.Grind: {lo, hi, m, x, y, n}).
function Guide:GrindSpot(level)
    level = level or HM:Level()
    local list = ns.Grind or {}
    for _, g in ipairs(list) do
        if level >= g[1] and level <= g[2] then return g end
    end
    return list[#list]
end

function Guide:PointGrind()
    local g = self:GrindSpot()
    if g and HM.Arrow then
        HM.Arrow:SetTarget(g[3], g[4], g[5], "Kas: " .. (g[6] or ""), "aoe")
        HM:Print(string.format("Ok kasma noktasında: %s (%s %.1f, %.1f). Başlığa tıklayınca adıma döner.", g[6] or "", HM:MapName(g[3]), g[4], g[5]))
    else
        HM:Print("Bu seviye için kasma noktası yok.")
    end
end

function Guide:Announce(i)
    local route = Route()
    local s = route[i]
    if not s then return end
    HM:Print(string.format("Sıradaki (%d/%d): %s", i, #route, stepTitle(s)))
end

-- Adımın rota sürümünden bağımsız kimliği ("A:97246", "G:Razor Hill (Durotar)"): rota güncellenip
-- adımlar kayınca girişte aynı adım yeniden bulunur.
local function stepKey(s)
    if not s then return nil end
    return s.k .. ":" .. ((s.q and table.concat(s.q, ",")) or s.t or "")
end
Guide.StepKey = stepKey

function Guide:SetStep(i, reason)
    local route = Route()
    if #route == 0 then return end
    if i < 1 then i = 1 end
    if i > #route then i = #route end
    HM.db.step = i
    HM.db.stepKey = stepKey(route[i])
    HM.db.stepTrained = false
    HM.db.stepArrived = nil
    self:PointStep()
    pcall(self.FilterQuestie, self)
    if reason then
        self:Announce(i)
        self:Check()
    else
        self:Refresh()
    end
end

---------------------------------------------------------------------------
-- Questie filtresi: sadece yakındaki rotadaki görevleri haritada göster
-- Diğerlerini gizle → harita temiz kalır, sadece yapman gerekeni görürsün
---------------------------------------------------------------------------
function Guide:FilterQuestie()
    if self.questieFiltered then return end
    if not (Questie and Questie.db and Questie.db.profile) then return end
    self.questieFiltered = true
    local prof = Questie.db.profile
    local changed = false
    -- Önceki sürümün yazdığı geçersiz değeri onar (lowLevelStyle sayı olmalı: 1 = önemsiz görevleri gizle).
    if type(prof.lowLevelStyle) ~= "number" then
        prof.lowLevelStyle = Questie.LOWLEVEL_NONE or 1
        changed = true
    end
    -- Zindan/raid görev verenleri haritayı dolduruyor: Questie'nin kendi ayarıyla gizle.
    -- (Zindan görevleri Hızlı Mage'in Zindan düğmesinde yerleriyle duruyor.) Geri açmak: /hm zindanpin
    if HM.db.hideDungeonPins ~= false then
        if prof.showDungeonQuests ~= false then prof.showDungeonQuests = false; changed = true end
        if prof.showRaidQuests ~= false then prof.showRaidQuests = false; changed = true end
    end
    if changed and QuestieLoader and QuestieLoader.ImportModule then
        local ok, AQ = pcall(QuestieLoader.ImportModule, QuestieLoader, "AvailableQuests")
        if ok and type(AQ) == "table" then
            if AQ.ResetLevelRequirementCache then pcall(AQ.ResetLevelRequirementCache) end
            if AQ.CalculateAndDrawAll then pcall(AQ.CalculateAndDrawAll) end
        end
    end
end

-- /hm zindanpin: zindan görev verenlerini haritada göster/gizle
function Guide:ToggleDungeonPins()
    local db = HM.db
    db.hideDungeonPins = (db.hideDungeonPins == false)
    if Questie and Questie.db and Questie.db.profile then
        Questie.db.profile.showDungeonQuests = not db.hideDungeonPins
        Questie.db.profile.showRaidQuests = not db.hideDungeonPins
        if QuestieLoader and QuestieLoader.ImportModule then
            local ok, AQ = pcall(QuestieLoader.ImportModule, QuestieLoader, "AvailableQuests")
            if ok and type(AQ) == "table" and AQ.CalculateAndDrawAll then pcall(AQ.CalculateAndDrawAll) end
        end
    end
    HM:Print("Haritada zindan görev verenleri: " .. (db.hideDungeonPins and "gizli" or "görünür"))
end

function Guide:Next() self:SetStep(HM.db.step + 1, "next") end
function Guide:Prev() self:SetStep(HM.db.step - 1) end

-- "Tamam": adımı bitir. A adımında alınmamış görevler atlanır (D/T adımları da kendiliğinden geçer).
function Guide:Complete()
    local route = Route()
    local s = self:Step()
    if HM.db.step >= #route then
        HM:Print("Rota bitti. 60'a hoş geldin!")
        return
    end
    if s and s.k == "A" then
        HM.db.questSkip = HM.db.questSkip or {}
        local skipped = 0
        for _, q in ipairs(s.q or {}) do
            if not (flagged(q) or onQuest(q)) then
                HM.db.questSkip[q] = true
                skipped = skipped + 1
            end
        end
        if skipped > 0 then HM:Print(string.format("%d görev atlandı; bunların hedef ve teslim adımları da geçilecek.", skipped)) end
    elseif s and s.k == "R" then
        HM.db.stepTrained = true
    elseif s and (s.k == "G" or s.k == "F" or s.k == "H") then
        HM.db.stepArrived = HM.db.step
    end
    self:SetStep(HM.db.step + 1, "done")
end

-- Koşulları değerlendirir; sağlananları zincirleme geçer (en fazla 80 adım).
function Guide:Check()
    if self.checking or not self.ready then return end
    local route = Route()
    if #route == 0 then return end
    self.checking = true
    local startStep = HM.db.step
    -- Bir adımın durumu hesaplanırken hata çıkarsa motor kilitli kalmasın: hata kaydedilir, devam edilir.
    local ok, err = pcall(function()
        local guard = 0
        local skippedMsgs = 0
        while guard < 80 do
            guard = guard + 1
            local idx = HM.db.step
            local s = route[idx]
            if not s or idx >= #route then break end
            local st = self:Status(s, idx)
            if st == "done" or st == "skip" then
                if st == "skip" and s.k == "T" and s.q then
                    HM.db.questSkip = HM.db.questSkip or {}
                    for _, q in ipairs(s.q) do
                        if not (flagged(q) or onQuest(q)) then HM.db.questSkip[q] = true end
                    end
                end
                if st == "skip" and skippedMsgs < 3 and HM.db.debug then
                    HM:Print("Atlandı (görev alınmamış): " .. (s.t or ""))
                    skippedMsgs = skippedMsgs + 1
                end
                HM.db.step = idx + 1
                HM.db.stepKey = stepKey(route[idx + 1])
                HM.db.stepTrained = false
                HM.db.stepArrived = nil
            else
                break
            end
        end
    end)
    self.checking = false
    if not ok then
        HM.db.lastError = tostring(err)
        if not self.errorShown then
            self.errorShown = true
            HM:Print("|cffff8080Rehber adım kontrolünde hata:|r " .. tostring(err) .. " (/hm tani)")
        end
    end
    if HM.db.step ~= startStep then
        self:Announce(HM.db.step)
        self:PointStep()
    end
    local okR, errR = pcall(self.Refresh, self)
    if not okR then HM.db.lastError = tostring(errR) end
end

-- /hm tani: motorun ve görev API'sinin durumu (sorun bildirirken bunu yaz).
function Guide:Diagnose()
    local db = HM.db
    local route = Route()
    local s = route[db.step]
    HM:Print(string.format("Motor: hazır=%s kontrol=%s adım=%d/%d sonHata=%s", tostring(self.ready), tostring(self.checking),
        db.step or 0, #route, db.lastError and db.lastError:sub(1, 120) or "-"))
    local map = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    local chain = {}
    for m in pairs(HM:PlayerMapChain()) do chain[#chain + 1] = tostring(m) end
    table.sort(chain)
    local px, py, pc = HM:PlayerWorldPos()
    HM:Print(string.format("Harita: %s (gizli=%s) zincir=%s konum=%s", tostring(map), tostring(HM.IsSecret(map)),
        table.concat(chain, ","), px and string.format("%.0f,%.0f kıta %s", px, py, tostring(pc)) or "yok"))
    local log = HM:GetQuestLog()
    local ids = {}
    for _, q in ipairs(log) do ids[#ids + 1] = tostring(q.id) .. (q.complete and "✓" or "") end
    HM:Print(string.format("Görev günlüğü: %d görev [%s]", #log, table.concat(ids, " ")))
    if not s then return end
    local okS, st = pcall(self.Status, self, s, db.step)
    HM:Print(string.format("Adım %d [%s] %s → durum: %s", db.step, s.k, (s.t or ""):sub(1, 60), okS and tostring(st) or ("HATA " .. tostring(st))))
    for _, q in ipairs(s.q or {}) do
        HM:Print(string.format("  görev %d: bitmiş=%s günlükte=%s hedefler=%s atlanmış=%s", q, tostring(flagged(q)),
            tostring(onQuest(q)), tostring(questComplete(q)), tostring(db.questSkip and db.questSkip[q] or false)))
    end
    if s.k == "G" or s.k == "F" then
        local d = distanceTo(s)
        HM:Print(string.format("  hedef harita %s, bölgedeyiz=%s, uzaklık=%s", tostring(s.m), tostring(playerInMap(s.m)), d and math.floor(d) .. " yd" or "hesaplanamadı"))
    end
end

-- Ok hedefe yaklaşınca (Arrow'dan): G/F/H adımları için varış.
function Guide:OnArrive(target, dist) end

function Guide:OnDistance(target, dist)
    if target.kind ~= "step" then return end
    local s = self:Step()
    if not s or s.m ~= target.m or s.x ~= target.x or s.y ~= target.y then return end
    local r
    if s.k == "G" then r = s.r or 25 elseif s.k == "F" then r = 8 elseif s.k == "H" then r = nil end
    if r and dist <= r then
        HM.db.stepArrived = HM.db.step
        self:Check()
    elseif s.k == "H" and dist <= 40 and self.hearthNear ~= HM.db.step then
        -- Hancının yanına geldik: zaten buraya bağlıysak adım kendiliğinden geçsin.
        self.hearthNear = HM.db.step
        self:Check()
    end
end

function Guide:OnTrained()
    local s = self:Step()
    HM.db.stepTrained = true
    if s and s.k == "R" then self:Check() end
end

-- Hearth bağlandı (HEARTHSTONE_BOUND / bind yeri değişti)
function Guide:OnBound()
    local s = self:Step()
    if s and s.k == "H" then
        HM.db.bind = { m = s.m, x = s.x, y = s.y }
        HM.db.stepArrived = HM.db.step
        self:Check()
    end
end

-- Büyü biliniyor mu? true / false / nil (API yok)
function Guide.SpellKnown(id)
    if C_SpellBook and C_SpellBook.IsSpellKnown then
        local ok, r = pcall(C_SpellBook.IsSpellKnown, id)
        if ok and r ~= nil and not HM.IsSecret(r) then return r and true or false end
    end
    if IsPlayerSpell then
        local ok, r = pcall(IsPlayerSpell, id)
        if ok and r ~= nil then return r and true or false end
    end
    if IsSpellKnown then
        local ok, r = pcall(IsSpellKnown, id)
        if ok and r ~= nil then return r and true or false end
    end
    return nil
end

-- Çantadaki eşya sayısı (bilinmiyorsa nil)
function Guide.ItemCount(id)
    if C_Item and C_Item.GetItemCount then
        local ok, n = pcall(C_Item.GetItemCount, id)
        if ok and type(n) == "number" and not HM.IsSecret(n) then return n end
    end
    if GetItemCount then
        local ok, n = pcall(GetItemCount, id)
        if ok and type(n) == "number" then return n end
    end
    return nil
end

-- Çantada istenen adetler var mı? ({[eşyaId] = adet}); sayılamıyorsa false.
function Guide.HaveItems(need)
    for id, n in pairs(need) do
        local c = Guide.ItemCount(id)
        if not c or c < n then return false end
    end
    return true
end

-- Hearthstone hazır mı? true / kalan saniye (sayı) / nil (bilinmiyor)
function Guide.HearthState()
    local start, dur
    if C_Container and C_Container.GetItemCooldown then
        local ok, a, b = pcall(C_Container.GetItemCooldown, 6948)
        if ok then start, dur = a, b end
    end
    if start == nil and GetItemCooldown then
        local ok, a, b = pcall(GetItemCooldown, 6948)
        if ok then start, dur = a, b end
    end
    if type(start) ~= "number" or type(dur) ~= "number" or HM.IsSecret(start) or HM.IsSecret(dur) then return nil end
    if dur <= 1.5 or start == 0 then return true end
    local left = start + dur - GetTime()
    if left <= 0 then return true end
    return left
end

-- Hearth'ün bağlı olduğu han: son bağlama adımı (kayıt yoksa rotada geride kalan son H adımı).
function Guide:BindSpot()
    local db = HM.db
    if db.bind and db.bind.m then return db.bind end
    local route = Route()
    for i = math.min(db.step or 1, #route), 1, -1 do
        local s = route[i]
        if s and s.k == "H" then return s end
    end
end

-- Konum izleyici (2 sn'de bir): Hearthstone / ışınlanma / uçuş sonrası yol tarifini yeniler ve
-- hearth'ün gerçekte bağlı olduğu yeri öğrenir (rotadaki handan farklı olabilir).
function Guide:Watch()
    local db = HM.db
    if not (db and self.ready) then return end
    if onTaxi() then self.wasTaxi = true; return end
    local now = GetTime()
    local hs = Guide.HearthState()
    if self.hsReady == true and type(hs) == "number" and hs > 600 then
        self.hearthUsedAt = now          -- bekleme süresi yeni başladı: az önce kullanıldı
    end
    if hs ~= nil then self.hsReady = (hs == true) end
    local px, py, pc, map = HM:PlayerWorldPos()
    local moved = false
    if px then
        local last = self.lastPos
        local jump = last and (last.c ~= pc or math.sqrt((last.x - px) ^ 2 + (last.y - py) ^ 2) > 250)
        if jump then moved = true end
        if self.hearthUsedAt then
            local dt = now - self.hearthUsedAt
            if dt > 90 then
                self.hearthUsedAt = nil
            elseif jump or (dt >= 15 and not (db.bind and db.bind.m)) then
                -- Hearthstone'dan sonra indiğimiz yer = hearth'ün gerçekte bağlı olduğu han
                local ok, pos = pcall(C_Map.GetPlayerMapPosition, map, "player")
                if ok and pos and pos.x and not HM.IsSecret(pos.x) then
                    db.bind = { m = map, x = pos.x * 100, y = pos.y * 100, real = true }
                end
                self.hearthUsedAt = nil
                moved = true
            end
        end
        self.lastPos = { x = px, y = py, c = pc }
    end
    if self.wasTaxi then self.wasTaxi = nil; moved = true end
    if moved then
        self:PointStep(true)
        self:Check()
    elseif self.redirect then
        if self:PointStep(true) then pcall(self.Refresh, self) end
    end
end

local function watchLoop()
    pcall(Guide.Watch, Guide)
    C_Timer.After(2, watchLoop)
end
Guide.StartWatch = function()
    if Guide.watching then return end
    Guide.watching = true
    C_Timer.After(2, watchLoop)
end

-- Uçuş haritası açıkken karakterin gerçekten açmış olduğu noktaları kaydeder (kıta -> adlar).
-- Yol tarifi açılmamış bir noktadan uçuş önermesin diye.
function Guide:RecordTaxiNodes()
    local found, n = {}, 0
    if NumTaxiNodes and TaxiNodeName then
        local ok, cnt = pcall(NumTaxiNodes)
        if ok and type(cnt) == "number" and not HM.IsSecret(cnt) then
            for i = 1, cnt do
                local okN, name = pcall(TaxiNodeName, i)
                local typ = "REACHABLE"
                if TaxiNodeGetType then
                    local okT, t = pcall(TaxiNodeGetType, i)
                    if okT and type(t) == "string" then typ = t end
                end
                if okN and type(name) == "string" and not HM.IsSecret(name) and (typ == "REACHABLE" or typ == "CURRENT") then
                    found[name:lower()] = true
                    n = n + 1
                end
            end
        end
    end
    if n == 0 and C_TaxiMap and C_TaxiMap.GetAllTaxiNodes and C_Map and C_Map.GetBestMapForUnit then
        local okM, map = pcall(C_Map.GetBestMapForUnit, "player")
        local ok, nodes = false, nil
        if okM and map and not HM.IsSecret(map) then ok, nodes = pcall(C_TaxiMap.GetAllTaxiNodes, map) end
        if ok and type(nodes) == "table" then
            for _, nd in ipairs(nodes) do
                if type(nd) == "table" and type(nd.name) == "string" and (nd.state == 0 or nd.state == 1) then
                    found[nd.name:lower()] = true
                    n = n + 1
                end
            end
        end
    end
    if n == 0 then return end
    local _, _, pc = HM:PlayerWorldPos()
    if pc == nil then return end
    -- Adlar rotadaki yer adlarıyla uyuşuyor mu? (uyuşmuyorsa bu veriyi kullanma)
    local okNames = false
    for _, nm in pairs(self:FlightNames()) do
        if nm.place then
            local pl = nm.place:lower()
            for name in pairs(found) do
                if name:sub(1, #pl) == pl then okNames = true; break end
            end
        end
        if okNames then break end
    end
    HM.db.taxiNodes = HM.db.taxiNodes or {}
    HM.db.taxiNodes[pc] = { ok = okNames, names = found }
    self.fpCache = nil
end

-- Uçuş haritası açıldı: yakındaysak uçuş noktası adımı tamam.
function Guide:OnTaxi()
    pcall(self.RecordTaxiNodes, self)
    local s = self:Step()
    if s and s.k == "F" then
        local d = distanceTo(s)
        if not d or d <= 120 then
            HM.db.stepArrived = HM.db.step
            self:Check()
        end
    end
end

-- Giriş: kayıtlı adım yoksa seviyeye ve bitmiş görevlere göre yerleş.
function Guide:Sync()
    local db = HM.db
    local route = Route()
    if #route == 0 then return end
    local level = HM:Level()
    local ver = ns.RouteVer and ns.RouteVer[ns.class or ""]
    local reroute = false
    if ver and db.routeVer ~= ver then
        reroute = db.initialized and true or false
        db.routeVer = ver
        db.stepKey = nil
    end
    if reroute or not db.initialized or not route[db.step] then
        local pick = #route
        local lastHi
        for i, s in ipairs(route) do
            local lo, hi = parseRange(s.sec)
            if hi then lastHi = hi else hi = lastHi end
            local tooLow = hi and hi < level - 2
            if not tooLow and (s.k == "A" or s.k == "T" or s.k == "D") then
                local open = false
                for _, q in ipairs(s.q or {}) do
                    if not flagged(q) then open = true end
                end
                if open then pick = i; break end
            end
        end
        -- bölümün başındaki Git/uçuş adımlarına geri sar
        local function rewindable(st)
            if st.k == "A" or st.k == "T" or st.k == "D" or st.hs or st.fly then return false end
            -- Rota yenilendiyse bölgenin ortasındayız: "kasabaya git" adımına dönme, yalnız han/uçuş noktası adımlarını göster.
            if reroute then return st.k == "F" or st.k == "H" end
            return true
        end
        while pick > 1 and route[pick - 1] and route[pick - 1].sec == route[pick].sec and rewindable(route[pick - 1]) do
            pick = pick - 1
        end
        db.step = pick
        db.initialized = true
        if reroute then
            HM:Print(string.format("Rota yenilendi. Bitirdiğin görevlere göre %d. adımdan devam.", pick))
        else
            HM:Print(string.format("Rota seviyene göre %d. adımdan başlıyor.", pick))
        end
    end
    for _, q in ipairs(ns.UnskipQuests or {}) do
        if db.questSkip and db.questSkip[q] and not flagged(q) then db.questSkip[q] = nil end
    end
    -- Rota güncellendiyse (adımlar kaydıysa) aynı adımı kimliğinden bul.
    if db.stepKey and route[db.step] and stepKey(route[db.step]) ~= db.stepKey then
        local lo, hi = math.max(1, db.step - 40), math.min(#route, db.step + 40)
        for i = lo, hi do
            if stepKey(route[i]) == db.stepKey then db.step = i; break end
        end
    end
    -- Teslim/yap adımında başlıyorsak ve görev ne günlükte ne bitmiş ne atlanmışsa, hemen gerideki
    -- "al" adımına dön (aksi hâlde görev hiç alınmamış sayılıp atlanırdı).
    local cur = route[db.step]
    if cur and (cur.k == "T" or cur.k == "D") and cur.q then
        local open = false
        for _, q in ipairs(cur.q) do
            if not (flagged(q) or onQuest(q) or (db.questSkip and db.questSkip[q])) then open = true end
        end
        if open then
            for i = db.step - 1, math.max(1, db.step - 8), -1 do
                local a = route[i]
                if a and a.k == "A" and a.q then
                    local hit = false
                    for _, q in ipairs(a.q) do for _, q2 in ipairs(cur.q) do if q == q2 then hit = true end end end
                    if hit then db.step = i; break end
                end
            end
        end
    end
    self.ready = true
    self:SetStep(db.step)
    self:Check()
    Guide.StartWatch()
end

function Guide:ListDungeons()
    local level = HM:Level()
    local found, first = 0, nil
    for _, d in ipairs(ns.Dungeons or {}) do
        if level >= d.a - 2 and level <= d.b then
            found = found + 1
            local where = d.m and string.format("%s (%.1f, %.1f)", HM:MapName(d.m), d.x, d.y) or "giriş henüz doğrulanmadı"
            HM:Print(string.format("|cffffd100%s|r %d-%d: %s", d.n, d.a, d.b, where))
            if not first and d.m then first = d end
        end
    end
    if found == 0 then
        HM:Print("Seviyene uygun zindan yok.")
    else
        HM:Print("Forever'da zindan çöpleri az, görevleri çok XP verir: görevleriyle bir kez gir.")
        if first and HM.Arrow then
            HM.Arrow:SetTarget(first.m, first.x, first.y, first.n, "dungeon")
        end
    end
end

-- Görev kimliğine göre adım bul (/hm gorev 1234)
function Guide:FindQuest(qid)
    for i, s in ipairs(Route()) do
        if s.q then
            for _, q in ipairs(s.q) do if q == qid then return i, s end end
        end
    end
end

---------------------------------------------------------------------------
-- Olaylar
---------------------------------------------------------------------------
local pendingCheck = false
local function scheduleCheck(delay)
    if pendingCheck then return end
    pendingCheck = true
    C_Timer.After(delay or 0.4, function()
        pendingCheck = false
        Guide:Check()
    end)
end
Guide.ScheduleCheck = scheduleCheck

HM:OnLogin(function()
    Guide:Create()
    Guide:BuildQuestSet()
    -- Görev günlüğü ve harita verisi bir an sonra hazır olur.
    C_Timer.After(2, function() Guide:Sync() end)
end)

HM:On("QUEST_ACCEPTED", function(_, a, b)
    -- Classic: (questLogIndex, questID); modern: (questID)
    local qid = b or a
    if type(qid) == "number" and HM.db then
        HM.db.doneQ = HM.db.doneQ or {}
    end
    scheduleCheck(0.3)
end)

HM:On("QUEST_TURNED_IN", function(_, questID)
    if type(questID) == "number" and HM.db then
        HM.db.doneQ = HM.db.doneQ or {}
        HM.db.doneQ[questID] = true
    end
    scheduleCheck(0.3)
end)

HM:On("QUEST_LOG_UPDATE", function() scheduleCheck(0.6) end)
HM:On("UNIT_QUEST_LOG_CHANGED", function(_, unit) if unit == "player" then scheduleCheck(0.6) end end)
HM:On("QUEST_REMOVED", function() scheduleCheck(0.6) end)
HM:On("PLAYER_LEVEL_UP", function() scheduleCheck(0.5) end)
HM:On("ZONE_CHANGED_NEW_AREA", function() scheduleCheck(1) end)
HM:On("ZONE_CHANGED", function() scheduleCheck(1) end)
HM:On("TAXIMAP_OPENED", function() Guide:OnTaxi() end)
HM:On("PLAYER_CONTROL_GAINED", function()
    -- Uçuştan indik (ya da kontrol geri geldi): yol tarifini bulunduğumuz yere göre yenile.
    if Guide.ready then
        Guide:PointStep(true)
        scheduleCheck(1)
    end
end)
-- Eğitmen penceresi kapandı: R adımındaysak ve eğitmenin yanındaysak tamam (Trainer modülü sınıfı tanımasa da).
HM:On("TRAINER_CLOSED", function()
    local s = Guide:Step()
    if s and s.k == "R" then
        local d = distanceTo(s)
        if not d or d <= 60 then
            HM.db.stepTrained = true
            scheduleCheck(0.2)
        end
    end
end)
HM:On("HEARTHSTONE_BOUND", function() Guide:OnBound() end)
HM:On("PLAYER_UPDATE_RESTING", function()
    if GetBindLocation then
        local loc = GetBindLocation()
        if loc and loc ~= HM.db.lastBind then
            HM.db.lastBind = loc
            Guide:OnBound()
        end
    end
end)
-- Hancı "burayı ev yap" onayı: hearth adımındaysak otomatik onayla.
HM:On("CONFIRM_BINDER", function()
    local s = Guide:Step()
    if s and s.k == "H" and HM.db and HM.db.autoQuest and ConfirmBinder then
        pcall(ConfirmBinder)
        if StaticPopup_Hide then pcall(StaticPopup_Hide, "CONFIRM_BINDER") end
    end
end)
HM:On("PLAYER_ENTERING_WORLD", function()
    C_Timer.After(3, function()
        if HM.db and HM.db.initialized and Guide.ready then Guide:Check() end
    end)
end)
