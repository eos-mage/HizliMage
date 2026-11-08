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
    local set = {}
    for _, s in ipairs(Route()) do
        if s.k == "A" and s.q then
            for _, q in ipairs(s.q) do set[q] = true end
        end
    end
    self.questSet = set
end

function Guide:QuestWanted(qid)
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

-- Döndürür: "done" (koşul sağlandı), "skip" (görev alınmamış/atlanmış), "wait", "level" (seviye yetersiz)
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
                allDone = false
                anyOpen = true
            end
        end
        if allDone then return "done" end
        if s.lvl and level < s.lvl then return "level" end
        return "wait"
    elseif k == "D" then
        local pending = false
        for _, q in ipairs(s.q or {}) do
            if flagged(q) then
                -- bitti
            elseif onQuest(q) then
                if not questComplete(q) then pending = true end
            else
                -- alınmamış ya da bırakılmış: atla
            end
        end
        if pending then return "wait" end
        local any = false
        for _, q in ipairs(s.q or {}) do if onQuest(q) or flagged(q) then any = true end end
        return any and "done" or "skip"
    elseif k == "T" then
        local pending, any = false, false
        for _, q in ipairs(s.q or {}) do
            if flagged(q) then
                any = true
            elseif onQuest(q) then
                pending = true
            end
        end
        if pending then return "wait" end
        return any and "done" or "skip"
    elseif k == "L" then
        return (level >= (s.lvl or 1)) and "done" or "wait"
    elseif k == "G" then
        if db.stepArrived == idx then return "done" end
        if playerInMap(s.m) then return "done" end
        return "wait"
    elseif k == "F" then
        if db.stepArrived == idx then return "done" end
        local d = distanceTo(s)
        if d and d <= 8 then return "done" end
        return "wait"
    elseif k == "H" then
        if db.stepArrived == idx then return "done" end
        return "wait"
    elseif k == "R" then
        if db.stepTrained then return "done" end
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
    frame.header:SetWidth(WIDTH - 60)
    frame.header:SetJustifyH("LEFT")
    frame.header:SetTextColor(0.25, 0.78, 0.92)

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
    frame.status1:SetTextColor(0.6, 0.85, 1)

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

    local bPrev = MakeButton(frame, "<", 26, function() Guide:Prev() end, "Önceki adım")
    local bNext = MakeButton(frame, ">", 26, function() Guide:Next() end, "Sonraki adım")
    local bDone = MakeButton(frame, "Tamam", 54, function() Guide:Complete() end, "Bu adımı bitir / atla (alınamayan görev varsa atlar)")
    local bGrind = MakeButton(frame, "Kas", 40, function() Guide:PointGrind() end, "Seviyene uygun kasma noktası")
    local bTrain = MakeButton(frame, "Eğitmen", 62, function() if HM.Trainer then HM.Trainer:PointTrainer("class") end end, "En yakın sınıf eğitmeni")
    local bDung = MakeButton(frame, "Zindan", 54, function() Guide:ListDungeons() end, "Seviyene uygun zindanlar")
    bPrev:SetPoint("BOTTOMLEFT", 8, 8)
    bNext:SetPoint("LEFT", bPrev, "RIGHT", 2, 0)
    bDone:SetPoint("LEFT", bNext, "RIGHT", 4, 0)
    bGrind:SetPoint("LEFT", bDone, "RIGHT", 4, 0)
    bTrain:SetPoint("LEFT", bGrind, "RIGHT", 4, 0)
    bDung:SetPoint("LEFT", bTrain, "RIGHT", 4, 0)
    frame.buttons = { bPrev, bNext, bDone, bGrind, bTrain, bDung }

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
    if s.n and s.n ~= "" then parts[#parts + 1] = s.n end
    if s.k == "A" then
        if s.item then parts[#parts + 1] = "|cffffd100Eşya görevi:|r düşen eşyaya çantadan sağ tıkla." end
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
                for _, l in ipairs(objectiveLines(q)) do parts[#parts + 1] = l end
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
    elseif s.k == "G" or s.k == "F" then
        local d = distanceTo(s)
        if d then parts[#parts + 1] = string.format("Uzaklık: %d yd", math.floor(d)) end
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

    frame.header:SetText(HM:T(string.format("%s  •  %d/%d  •  %s", (ns.CD and ns.CD.label) and ("Hızlı " .. ns.CD.label) or "Hızlı Mage", db.step, #route, s.sec or "")))
    frame.title:SetText(HM:T(stepTitle(s)))
    frame.collapse.text:SetText(db.frame.collapsed and "+" or "–")

    local collapsed = db.frame.collapsed
    local h = 30 + frame.title:GetStringHeight()
    if collapsed then
        frame.body:Hide(); frame.upcoming:Hide(); frame.recent:Hide()
        frame.status1:Hide(); frame.status2:Hide(); frame.status3:Hide()
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
    local s3 = HM.Trainer and HM.Trainer:PendingText() or ""
    local hadS3 = (frame.status3:GetText() or "") ~= ""
    frame.status1:SetText(HM:T(s1))
    frame.status2:SetText(HM:T(table.concat(parts, "  •  ")))
    frame.status3:SetText(HM:T(s3))
    if not noResize and hadS3 ~= (s3 ~= "") then self:Refresh() end
end

---------------------------------------------------------------------------
-- Adım motoru
---------------------------------------------------------------------------
function Guide:PointStep()
    local s = self:Step()
    if s and HM.Arrow and s.m and s.x and s.y then
        HM.Arrow:SetTarget(s.m, s.x, s.y, s.t, "step")
    end
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

function Guide:SetStep(i, reason)
    local route = Route()
    if #route == 0 then return end
    if i < 1 then i = 1 end
    if i > #route then i = #route end
    HM.db.step = i
    HM.db.stepTrained = false
    HM.db.stepArrived = nil
    self:PointStep()
    if reason then
        self:Announce(i)
        self:Check()
    else
        self:Refresh()
    end
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
    local guard = 0
    local startStep = HM.db.step
    local skippedMsgs = 0
    while guard < 80 do
        guard = guard + 1
        local idx = HM.db.step
        local s = route[idx]
        if not s or idx >= #route then break end
        local st = self:Status(s, idx)
        if st == "done" or st == "skip" then
            if st == "skip" and skippedMsgs < 3 and HM.db.debug then
                HM:Print("Atlandı (görev alınmamış): " .. (s.t or ""))
                skippedMsgs = skippedMsgs + 1
            end
            HM.db.step = idx + 1
            HM.db.stepTrained = false
            HM.db.stepArrived = nil
        else
            break
        end
    end
    self.checking = false
    if HM.db.step ~= startStep then
        self:Announce(HM.db.step)
        self:PointStep()
    end
    self:Refresh()
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
        HM.db.stepArrived = HM.db.step
        self:Check()
    end
end

-- Uçuş haritası açıldı: yakındaysak uçuş noktası adımı tamam.
function Guide:OnTaxi()
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
    if not db.initialized or not route[db.step] then
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
        while pick > 1 and route[pick - 1] and route[pick - 1].sec == route[pick].sec and route[pick - 1].k ~= "A" and route[pick - 1].k ~= "T" and route[pick - 1].k ~= "D" do
            pick = pick - 1
        end
        db.step = pick
        db.initialized = true
        HM:Print(string.format("Rota seviyene göre %d. adımdan başlıyor.", pick))
    end
    self.ready = true
    self:SetStep(db.step)
    self:Check()
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
