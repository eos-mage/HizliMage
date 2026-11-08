-- Hızlı Mage v2: Horde 1-60 görev-görev hızlı kasma rehberi (WoW Forever / Classic Era)
-- Çekirdek: kayıtlı ayarlar, olay sistemi, uyumluluk yardımcıları, komutlar.

local ADDON, ns = ...
local HM = {}
ns.HM = HM
_G.HizliMage = HM

HM.name = ADDON
HM.version = "2.0.0"

do
    local _, _, _, iface = GetBuildInfo()
    HM.interface = tonumber(iface) or 0
    -- Forever istemcisi 16000-16999 aralığını kullanır (beta: 16001).
    HM.isForever = HM.interface >= 16000 and HM.interface < 17000
end

---------------------------------------------------------------------------
-- Varsayılan ayarlar (karakter başına kaydedilir)
---------------------------------------------------------------------------
local DEFAULTS = {
    step = 1,
    initialized = false,
    frame = { point = "RIGHT", x = -40, y = 120, scale = 1.0, shown = true, collapsed = false },
    arrow = { point = "TOP", x = 0, y = -110, shown = true },
    autoQuest = true,
    autoSell = true,
    autoRepair = true,
    smartTrain = true,
    nativeWaypoint = true,
    tomtom = true,
    ascii = false,
    debug = false,
    goldTarget = 100,      -- 40. seviye binek (Forever: Apprentice Riding + binek 100 altın)
    epicTarget = 1200,     -- 60. seviye epik binek (Forever: 1000 + 200 altın)
    waterMin = 10,
    trainSkip = {},        -- /hm atla ile kullanıcı kararları (true = atla, false = al)
    trainPending = 0,      -- eğitmene gidilmesi gereken son seviye (0 = yok)
    reminded = {},         -- meslek uyarıları (oturumlar arası tekrar etmesin)
    questSkip = {},        -- Tamam ile atlanan görevler (kimlik -> true)
    doneQ = {},            -- bu karakterin teslim ettiği görevler (kimlik -> true)
    routeVersion = 0,      -- rota biçimi değişince adım sayacı yeniden hizalanır
}
local ROUTE_VERSION = 2

local function copyDefaults(src, dst)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then dst[k] = {} end
            copyDefaults(v, dst[k])
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
end

---------------------------------------------------------------------------
-- Olay sistemi
---------------------------------------------------------------------------
local eventFrame = CreateFrame("Frame")
HM.handlers = {}
HM.loginFns = {}

function HM:On(event, fn)
    local list = self.handlers[event]
    if not list then
        local ok = pcall(eventFrame.RegisterEvent, eventFrame, event)
        if not ok then return false end
        list = {}
        self.handlers[event] = list
    end
    list[#list + 1] = fn
    return true
end

function HM:OnLogin(fn)
    self.loginFns[#self.loginFns + 1] = fn
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
    local list = HM.handlers[event]
    if not list then return end
    for i = 1, #list do
        local ok, err = pcall(list[i], event, ...)
        if not ok and HM.db and HM.db.debug then
            HM:Print("Hata (" .. event .. "): " .. tostring(err))
        end
    end
end)

---------------------------------------------------------------------------
-- Metin yardımcıları
---------------------------------------------------------------------------
local TR_MAP = {
    { "ç", "c" }, { "Ç", "C" }, { "ğ", "g" }, { "Ğ", "G" }, { "ı", "i" }, { "İ", "I" },
    { "ö", "o" }, { "Ö", "O" }, { "ş", "s" }, { "Ş", "S" }, { "ü", "u" }, { "Ü", "U" },
    { "•", "-" }, { "…", "..." }, { "–", "-" }, { "—", "-" },
}

-- Türkçe karakterler kare görünürse /hm ascii ile sadeleştirilir.
function HM:T(s)
    if s == nil then return "" end
    s = tostring(s)
    if self.db and self.db.ascii then
        for i = 1, #TR_MAP do
            s = (s:gsub(TR_MAP[i][1], TR_MAP[i][2]))
        end
    end
    return s
end

function HM:Print(msg)
    local frame = DEFAULT_CHAT_FRAME or ChatFrame1
    if frame then
        frame:AddMessage(self:T("|cff3fc7ebHızlı Mage|r: " .. tostring(msg)))
    end
end

function HM:Money(copper)
    copper = math.floor(tonumber(copper) or 0)
    if GetCoinTextureString then
        return GetCoinTextureString(copper)
    end
    local g = math.floor(copper / 10000)
    local s = math.floor((copper % 10000) / 100)
    local c = copper % 100
    return string.format("%da %dg %db", g, s, c)
end

function HM:Short(n)
    n = tonumber(n) or 0
    if n >= 1000000 then return string.format("%.1fM", n / 1000000) end
    if n >= 1000 then return string.format("%.1fk", n / 1000) end
    return tostring(math.floor(n))
end

function HM:Duration(sec)
    sec = tonumber(sec)
    if not sec or sec <= 0 or sec ~= sec or sec == math.huge then return "?" end
    if sec < 60 then return "<1 dk" end
    local h = math.floor(sec / 3600)
    local m = math.floor((sec % 3600) / 60)
    if h > 0 then return string.format("%d sa %d dk", h, m) end
    return string.format("%d dk", m)
end

-- Midnight/Forever istemcisindeki "secret value" korumasına karşı.
function HM.IsSecret(v)
    if issecretvalue == nil or v == nil then return false end
    local ok, res = pcall(issecretvalue, v)
    return ok and res == true
end

function HM:SpellName(id)
    if C_Spell and C_Spell.GetSpellName then
        local ok, name = pcall(C_Spell.GetSpellName, id)
        if ok and name then return name end
    end
    if GetSpellInfo then
        local ok, name = pcall(GetSpellInfo, id)
        if ok then return name end
    end
end

function HM:Level()
    return UnitLevel("player") or 1
end

function HM:InCombat()
    return (InCombatLockdown and InCombatLockdown()) or (UnitAffectingCombat and UnitAffectingCombat("player"))
end

---------------------------------------------------------------------------
-- Harita / konum yardımcıları
---------------------------------------------------------------------------
-- Oyuncunun dünya koordinatı: x = kuzey, y = batı (HereBeDragons ile aynı eksenler).
function HM:PlayerWorldPos()
    if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition and C_Map.GetWorldPosFromMapPos) then return end
    local map = C_Map.GetBestMapForUnit("player")
    if not map or HM.IsSecret(map) then return end
    local pos = C_Map.GetPlayerMapPosition(map, "player")
    if not pos then return end
    local px, py = pos.x, pos.y
    if px == nil or HM.IsSecret(px) or HM.IsSecret(py) or (px == 0 and py == 0) then return end
    local cont, wpos = C_Map.GetWorldPosFromMapPos(map, pos)
    if not cont or not wpos then return end
    return wpos.x, wpos.y, cont, map
end

function HM:MapWorldPos(map, x, y)
    if not (map and x and y and CreateVector2D and C_Map and C_Map.GetWorldPosFromMapPos) then return end
    local ok, cont, wpos = pcall(C_Map.GetWorldPosFromMapPos, map, CreateVector2D(x / 100, y / 100))
    if not ok or not cont or not wpos then return end
    return wpos.x, wpos.y, cont
end

function HM:MapName(map)
    if map and C_Map and C_Map.GetMapInfo then
        local info = C_Map.GetMapInfo(map)
        if info and info.name then return info.name end
    end
    return "?"
end

-- Oyuncunun bulunduğu harita ve üst haritaları (bölge kontrolü için).
function HM:PlayerMapChain()
    local chain = {}
    if not (C_Map and C_Map.GetBestMapForUnit) then return chain end
    local map = C_Map.GetBestMapForUnit("player")
    local guard = 0
    while map and map > 0 and guard < 8 do
        chain[map] = true
        local info = C_Map.GetMapInfo and C_Map.GetMapInfo(map)
        map = info and info.parentMapID
        guard = guard + 1
    end
    return chain
end

-- Verilen nokta listesinden oyuncuya en yakın olanı (aynı kıta) döndürür.
function HM:Nearest(list)
    if not list then return end
    local px, py, pc = self:PlayerWorldPos()
    local best, bestD
    for _, p in ipairs(list) do
        local wx, wy, wc = self:MapWorldPos(p.m, p.x, p.y)
        if px and wx and wc == pc then
            local d = math.sqrt((wx - px) ^ 2 + (wy - py) ^ 2)
            if not bestD or d < bestD then best, bestD = p, d end
        end
    end
    return best or list[1], bestD
end

---------------------------------------------------------------------------
-- Görev günlüğü (Classic ve Forever/modern API)
---------------------------------------------------------------------------
function HM:GetQuestLog()
    local out = {}
    if C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetInfo then
        local n = C_QuestLog.GetNumQuestLogEntries() or 0
        for i = 1, n do
            local info = C_QuestLog.GetInfo(i)
            if info and not info.isHeader and info.title then
                local complete = info.questID and C_QuestLog.IsComplete and C_QuestLog.IsComplete(info.questID)
                out[#out + 1] = { title = info.title, id = info.questID, complete = complete and true or false }
            end
        end
    elseif GetNumQuestLogEntries and GetQuestLogTitle then
        local n = GetNumQuestLogEntries() or 0
        for i = 1, n do
            local title, _, _, isHeader, _, isComplete, _, questID = GetQuestLogTitle(i)
            if title and not isHeader then
                out[#out + 1] = { title = title, id = questID, complete = (isComplete == 1 or isComplete == true) }
            end
        end
    end
    return out
end

function HM:IsInQuestLog(questID, title)
    if questID and questID > 0 and C_QuestLog then
        if C_QuestLog.GetLogIndexForQuestID then
            local idx = C_QuestLog.GetLogIndexForQuestID(questID)
            if idx and idx > 0 then return true end
        end
        if C_QuestLog.IsOnQuest and C_QuestLog.IsOnQuest(questID) then return true end
    end
    for _, q in ipairs(self:GetQuestLog()) do
        if (questID and questID > 0 and q.id == questID) or (title and q.title == title) then
            return true
        end
    end
    return false
end

---------------------------------------------------------------------------
-- Yükleme
---------------------------------------------------------------------------
HM:On("ADDON_LOADED", function(_, name)
    if name ~= ADDON then return end
    if type(HizliMageDB) ~= "table" then HizliMageDB = {} end
    copyDefaults(DEFAULTS, HizliMageDB)
    HM.db = HizliMageDB
end)

HM:On("PLAYER_LOGIN", function()
    if not HM.db then
        if type(HizliMageDB) ~= "table" then HizliMageDB = {} end
        copyDefaults(DEFAULTS, HizliMageDB)
        HM.db = HizliMageDB
    end
    -- v1 hub rotasından v2 görev rotasına geçiş: eski adım numarası anlamsız, seviyeye göre yeniden yerleş.
    if HM.db.routeVersion ~= ROUTE_VERSION then
        HM.db.routeVersion = ROUTE_VERSION
        HM.db.initialized = false
        HM.db.step = 1
        HM.db.questSkip = {}
    end
    for i = 1, #HM.loginFns do
        local ok, err = pcall(HM.loginFns[i])
        if not ok then HM:Print("Başlatma hatası: " .. tostring(err)) end
    end
    local _, class = UnitClass("player")
    if not ns.ClassData[class] then
        HM:Print("Bu sınıf için özel rota yok; mage rotası ve genel yardımcılar çalışır.")
    end
    local cd = ns.CD
    HM:Print(string.format("v%s hazır: %s (%s), rota %d adım. Komutlar için |cffffd100/hm yardim|r", HM.version, UnitName("player") or "?", cd and cd.label or "?", #(ns.Route or {})))
end)

---------------------------------------------------------------------------
-- Etkileşim tuşu (Interact With Target): /hm tus F
-- Yakındaki görev NPC'si, posta kutusu, görev nesnesi tek tuşla; hedef almak gerekmez.
---------------------------------------------------------------------------
function HM:InteractKey()
    if GetBindingKey then
        local ok, k1 = pcall(GetBindingKey, "INTERACTTARGET")
        if ok and k1 then return k1 end
    end
end

function HM:BindInteract(key)
    key = (key or ""):upper():gsub("%s+", "")
    if key == "" then
        local cur = self:InteractKey()
        self:Print(cur and ("Etkileşim tuşu: " .. cur .. ". Değiştirmek için /hm tus G") or "Etkileşim tuşu bağlı değil. Örnek: /hm tus F")
        return
    end
    if self:InCombat() then self:Print("Savaşta tuş atanamaz; savaş bitince tekrar dene."); return end
    if not SetBinding then self:Print("Bu istemcide tuş atama API'si yok; Tuş Ayarları > Hedefleme > Interact With Target'ı elle ata."); return end
    local ok, res = pcall(SetBinding, key, "INTERACTTARGET")
    if not ok or not res then
        self:Print("Tuş atanamadı: " .. key .. ". Örnekler: F, G, SHIFT-F, MOUSEWHEELUP")
        return
    end
    if SaveBindings and GetCurrentBindingSet then pcall(SaveBindings, GetCurrentBindingSet()) end
    -- Yakındaki NPC/nesneyi hedefsiz etkileşime açan ayarlar (yumuşak hedefleme).
    if SetCVar then
        pcall(SetCVar, "SoftTargetInteract", 3)        -- her zaman açık
        pcall(SetCVar, "SoftTargetInteractArc", 2)     -- her yön
        pcall(SetCVar, "SoftTargetInteractRange", 15)  -- 15 yard
        pcall(SetCVar, "SoftTargetIconInteract", 1)    -- etkileşim ikonu
        pcall(SetCVar, "SoftTargetNameplateInteract", 1)
    end
    self.db.reminded = self.db.reminded or {}
    self.db.reminded.interact = true
    self:Print("Etkileşim tuşu " .. key .. " oldu. NPC'nin yanına gel, " .. key .. " bas: konuşma/görev penceresi açılır; posta ve nesneler için de geçerli.")
end

HM:OnLogin(function()
    C_Timer.After(8, function()
        if not HM.db or (HM.db.reminded and HM.db.reminded.interact) then return end
        if not HM:InteractKey() then
            HM:Print("İpucu: etkileşim tuşu bağlı değil. |cffffd100/hm tus F|r ile F'e ata (NPC'yle hedef almadan konuşursun).")
        end
    end)
end)

---------------------------------------------------------------------------
-- Komutlar
---------------------------------------------------------------------------
local function onoff(v) return v and "|cff40ff40açık|r" or "|cffff5050kapalı|r" end

local HELP = {
    "|cffffd100/hm|r rehber penceresini aç/kapat",
    "|cffffd100/hm ok|r yön okunu aç/kapat",
    "|cffffd100/hm ileri|r, |cffffd100/hm geri|r, |cffffd100/hm tamam|r, |cffffd100/hm adim 120|r adımlar arasında gezin",
    "|cffffd100/hm gorev 843|r görev kimliğinin rotadaki adımına git, |cffffd100/hm bolum|r bölüm listesi, |cffffd100/hm liste|r bu bölümün adımları (yapılanlar ✓)",
    "|cffffd100/hm kas|r seviyene uygun kasma noktası, |cffffd100/hm egitmen|r en yakın sınıf eğitmeni",
    "|cffffd100/hm tus F|r etkileşim tuşunu (Interact With Target) F'e bağlar; yakındaki NPC/nesneyle hedef almadan konuşursun",
    "|cffffd100/hm zindan|r seviyene uygun zindanlar (Forever'da zindan görevleri çok XP verir)",
    "|cffffd100/hm oto|r otomatik görev al/teslim et (Shift basılıyken devre dışı; yalnızca rotadaki görevler)",
    "|cffffd100/hm sat|r gri eşyaları otomatik sat, |cffffd100/hm tamir|r otomatik tamir",
    "|cffffd100/hm egitim|r akıllı büyü satın alma penceresi, |cffffd100/hm atla Scorch|r atlama listesine ekle/çıkar",
    "|cffffd100/hm hedef 100|r binek altın hedefi, |cffffd100/hm su 10|r minimum su",
    "|cffffd100/hm bez|r 60 için bez stoku, |cffffd100/hm talent|r bu seviyenin talent önerisi",
    "|cffffd100/hm rank|r barda eski rank'lı yetenek var mı, |cffffd100/hm canta|r çantadaki en değersiz eşya",
    "|cffffd100/hm harita|r Blizzard harita işareti, |cffffd100/hm ascii|r Türkçe harf sorunu için",
    "|cffffd100/hm boyut 0.9|r pencere ölçeği, |cffffd100/hm sifirla|r konum ve adımı sıfırla",
}

SLASH_HIZLIMAGE1 = "/hm"
SLASH_HIZLIMAGE2 = "/hizlimage"
SlashCmdList["HIZLIMAGE"] = function(msg)
    msg = (msg or ""):gsub("^%s+", ""):gsub("%s+$", "")
    local cmd, rest = msg:match("^(%S+)%s*(.-)$")
    cmd = (cmd or ""):lower()
    local db = HM.db
    if not db then return end

    if cmd == "" then
        if HM.Guide then HM.Guide:Toggle() end
    elseif cmd == "yardim" or cmd == "help" then
        HM:Print("komutlar:")
        for _, line in ipairs(HELP) do HM:Print(line) end
    elseif cmd == "ok" then
        db.arrow.shown = not db.arrow.shown
        if HM.Arrow then HM.Arrow:Refresh() end
        HM:Print("Yön oku " .. onoff(db.arrow.shown))
    elseif cmd == "ileri" then
        HM.Guide:Next()
    elseif cmd == "geri" then
        HM.Guide:Prev()
    elseif cmd == "tamam" then
        HM.Guide:Complete()
    elseif cmd == "adim" then
        local n = tonumber(rest)
        if n then HM.Guide:SetStep(n) else HM:Print("Kullanım: /hm adim 12") end
    elseif cmd == "aoe" or cmd == "kas" then
        HM.Guide:PointGrind()
    elseif cmd == "gorev" then
        local n = tonumber(rest)
        local idx = n and HM.Guide:FindQuest(n)
        if idx then HM.Guide:SetStep(idx) else HM:Print("Bu görev rotada yok: " .. tostring(rest)) end
    elseif cmd == "tus" then
        HM:BindInteract(rest)
    elseif cmd == "liste" then
        HM.Guide:ListSection()
    elseif cmd == "bolum" then
        local last
        for i, st in ipairs(ns.Route or {}) do
            if st.sec ~= last then
                last = st.sec
                HM:Print(string.format("%d: %s", i, st.sec or ""))
            end
        end
    elseif cmd == "egitmen" then
        if HM.Trainer then HM.Trainer:PointTrainer("class") end
    elseif cmd == "zindan" then
        HM.Guide:ListDungeons()
    elseif cmd == "oto" then
        db.autoQuest = not db.autoQuest
        HM:Print("Otomatik görev " .. onoff(db.autoQuest))
    elseif cmd == "sat" then
        db.autoSell = not db.autoSell
        HM:Print("Gri eşya satışı " .. onoff(db.autoSell))
    elseif cmd == "tamir" then
        db.autoRepair = not db.autoRepair
        HM:Print("Otomatik tamir " .. onoff(db.autoRepair))
    elseif cmd == "egitim" then
        db.smartTrain = not db.smartTrain
        HM:Print("Akıllı büyü satın alma " .. onoff(db.smartTrain))
    elseif cmd == "atla" then
        if rest == "" then
            local names = {}
            local cd = ns.CD or ns.ClassData.MAGE
            local merged = {}
            for k, v in pairs(cd.skip) do merged[k] = v end
            for k, v in pairs(db.trainSkip) do merged[k] = v end
            for k, v in pairs(merged) do if v then names[#names + 1] = k end end
            table.sort(names)
            HM:Print("Atlanan büyüler: " .. table.concat(names, ", "))
        else
            local now = HM.Trainer and HM.Trainer.ShouldSkip(rest, nil)
            db.trainSkip[rest] = not now
            HM:Print(rest .. (db.trainSkip[rest] and " atlanacak" or " artık satın alınacak"))
        end
    elseif cmd == "hedef" then
        local n = tonumber(rest)
        if n then db.goldTarget = n end
        HM:Print("Binek altın hedefi: " .. db.goldTarget .. " altın")
    elseif cmd == "su" then
        local n = tonumber(rest)
        if n then db.waterMin = n end
        HM:Print("Minimum su: " .. db.waterMin)
    elseif cmd == "bez" then
        if HM.Bags then HM.Bags:ClothReport() end
    elseif cmd == "talent" then
        if HM.Trainer then HM.Trainer:TalentHint(HM:Level(), true) end
    elseif cmd == "rank" then
        if HM.Extras then HM.Extras:CheckRanks(true) end
    elseif cmd == "canta" then
        if HM.Extras then HM.Extras:ReportCheapest(true) end
    elseif cmd == "harita" then
        db.nativeWaypoint = not db.nativeWaypoint
        HM:Print("Blizzard harita işareti " .. onoff(db.nativeWaypoint))
        if HM.Arrow then HM.Arrow:Refresh() end
    elseif cmd == "ascii" then
        db.ascii = not db.ascii
        HM:Print("ASCII modu " .. onoff(db.ascii))
        if HM.Guide then HM.Guide:Refresh() end
    elseif cmd == "boyut" then
        local n = tonumber(rest)
        if n and n >= 0.5 and n <= 2 then
            db.frame.scale = n
            if HM.Guide then HM.Guide:ApplyScale() end
        else
            HM:Print("Kullanım: /hm boyut 0.9 (0.5-2)")
        end
    elseif cmd == "sifirla" then
        db.frame.point, db.frame.x, db.frame.y = DEFAULTS.frame.point, DEFAULTS.frame.x, DEFAULTS.frame.y
        db.arrow.point, db.arrow.x, db.arrow.y = DEFAULTS.arrow.point, DEFAULTS.arrow.x, DEFAULTS.arrow.y
        db.initialized = false
        db.questSkip = {}
        if HM.Guide then HM.Guide:Reposition(); HM.Guide:Sync() end
        if HM.Arrow then HM.Arrow:Reposition() end
        HM:Print("Konumlar ve adım seviyene göre sıfırlandı.")
    elseif cmd == "debug" then
        db.debug = not db.debug
        HM:Print("Hata ayıklama " .. onoff(db.debug))
    else
        HM:Print("Bilinmeyen komut. /hm yardim")
    end
end
