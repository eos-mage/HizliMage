-- Otomatik görev alma ve teslim etme. Shift basılıyken hiçbir şey yapmaz.
-- Yalnızca rotadaki görevler otomatik alınır (rota dışı görevi elle tıklarsın); gri ve tekrarlanabilir
-- görevler alınmaz; birden çok ödül seçeneği varsa seçimi sana bırakır ve en değerlisini sohbete yazar.

local ADDON, ns = ...
local HM = ns.HM
local Auto = {}
HM.Auto = Auto

local active = true   -- aynı NPC görüşmesinde döngüye girmemek için

local function enabled()
    return HM.db and HM.db.autoQuest and active and not IsShiftKeyDown()
end

local function npcAllowed(unit)
    local guid = UnitGUID(unit)
    if guid and HM.IsSecret(guid) then return false end
    -- Oyuncuların paylaştığı görevleri otomatik kabul etme.
    if UnitExists(unit) and UnitIsPlayer(unit) then return false end
    return true
end

local function stopForThisNPC()
    active = false
end

local function windowsClosed()
    local frames = { GossipFrame, QuestFrame }
    for _, f in ipairs(frames) do
        if f and f.IsShown and f:IsShown() then return false end
    end
    return true
end

local function resetLater()
    C_Timer.After(0.5, function()
        if windowsClosed() then active = true end
    end)
end

local function wanted(qid)
    if not qid or qid == 0 then return false end
    if HM.Guide and HM.Guide.QuestWanted then return HM.Guide:QuestWanted(qid) end
    return true
end

-- Rotadaki sıradaki adımın görevleri önce.
local function priority(qid)
    local cur = HM.Guide and HM.Guide.CurrentQuestIDs and HM.Guide:CurrentQuestIDs()
    if cur then
        for _, q in ipairs(cur) do if q == qid then return 0 end end
    end
    return 1
end

-- Görev detayı: kabul et
HM:On("QUEST_DETAIL", function()
    if not enabled() then return end
    if not npcAllowed("questnpc") then return end
    local id = GetQuestID and GetQuestID() or 0
    if id == 0 then return end
    if not wanted(id) then
        HM:Print("Rota dışı görev (" .. id .. "): istersen elle kabul et.")
        return
    end
    AcceptQuest()
end)

HM:On("QUEST_ACCEPT_CONFIRM", function()
    if not enabled() then return end
    if ConfirmAcceptQuest then ConfirmAcceptQuest() end
end)

-- Eski tip görev selamlaması (QuestFrame greeting)
HM:On("QUEST_GREETING", function()
    if not (HM.db and HM.db.autoQuest) then return end
    if not active or IsShiftKeyDown() or not npcAllowed("npc") then stopForThisNPC(); return end
    for i = 1, (GetNumActiveQuests() or 0) do
        local _, isComplete = GetActiveTitle(i)
        if isComplete then
            SelectActiveQuest(i)
            return
        end
    end
    local best, bestP
    for i = 1, (GetNumAvailableQuests() or 0) do
        local trivial, repeatable, qid = false, false, nil
        if GetAvailableQuestInfo then
            local ok, a, b, c, d, e = pcall(GetAvailableQuestInfo, i)
            if ok then trivial, repeatable, qid = a, c, e end
        end
        if not trivial and not repeatable and (qid == nil or wanted(qid)) then
            local p = qid and priority(qid) or 2
            if not bestP or p < bestP then best, bestP = i, p end
        end
    end
    if best then SelectAvailableQuest(best) end
end)

-- Gossip penceresi (modern ve eski API)
HM:On("GOSSIP_SHOW", function()
    if not (HM.db and HM.db.autoQuest) then return end
    if not active or IsShiftKeyDown() or not npcAllowed("npc") then stopForThisNPC(); return end

    if C_GossipInfo and C_GossipInfo.GetActiveQuests then
        for _, q in ipairs(C_GossipInfo.GetActiveQuests() or {}) do
            if q.isComplete and q.questID then
                C_GossipInfo.SelectActiveQuest(q.questID)
                return
            end
        end
        local best, bestP
        for _, q in ipairs(C_GossipInfo.GetAvailableQuests() or {}) do
            if not q.isTrivial and not q.repeatable and q.questID and wanted(q.questID) then
                local p = priority(q.questID)
                if not bestP or p < bestP then best, bestP = q.questID, p end
            end
        end
        if best then
            C_GossipInfo.SelectAvailableQuest(best)
            return
        end
    elseif GetGossipActiveQuests then
        local act = { GetGossipActiveQuests() }          -- title, level, trivial, complete, legendary, ignored
        for i = 1, #act, 6 do
            if act[i + 3] then
                SelectGossipActiveQuest((i + 5) / 6)
                return
            end
        end
        local av = { GetGossipAvailableQuests() }        -- title, level, trivial, frequency, repeatable, legendary, ignored
        for i = 1, #av, 7 do
            if not av[i + 2] and not av[i + 4] then
                SelectGossipAvailableQuest((i + 6) / 7)
                return
            end
        end
    end
end)

-- İlerleme ekranı: görev günlüğünde olan ve tamamlanabilir görevi teslim et
-- (bez bağışı gibi günlükte olmayan tekrarlanabilir görevlere dokunmaz).
HM:On("QUEST_PROGRESS", function()
    if not enabled() then return end
    if not npcAllowed("questnpc") then return end
    if not IsQuestCompletable() then return end
    local id = GetQuestID and GetQuestID() or 0
    local title = GetTitleText and GetTitleText()
    if not HM:IsInQuestLog(id, title) then return end
    CompleteQuest()
end)

local function itemValue(link)
    if not link then return 0 end
    local price
    if C_Item and C_Item.GetItemInfo then
        price = select(11, C_Item.GetItemInfo(link))
    elseif GetItemInfo then
        price = select(11, GetItemInfo(link))
    end
    return price or 0
end

-- Ödül ekranı: seçenek 0-1 ise al, birden çoksa en değerliyi öner.
HM:On("QUEST_COMPLETE", function()
    if not enabled() then return end
    if not npcAllowed("questnpc") then return end
    local n = GetNumQuestChoices() or 0
    if n <= 1 then
        GetQuestReward(1)
        return
    end
    local best, bestV = nil, -1
    for i = 1, n do
        local link = GetQuestItemLink("choice", i)
        local _, _, count = GetQuestItemInfo("choice", i)
        local v = itemValue(link) * (count or 1)
        if v > bestV then best, bestV = link, v end
    end
    if best then
        HM:Print("Ödülü sen seç. Satış değeri en yüksek: " .. best .. " (" .. HM:Money(bestV) .. ")")
    end
end)

HM:On("GOSSIP_CLOSED", resetLater)
HM:On("QUEST_FINISHED", resetLater)
