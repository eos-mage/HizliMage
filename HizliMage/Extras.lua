-- Videolardan gelen üç kolaylık: çanta dolu yardımcısı, teslim bekleyen görev XP'si, eski rank uyarısı.

local ADDON, ns = ...
local HM = ns.HM
local Extras = {}
HM.Extras = Extras

---------------------------------------------------------------------------
-- Çanta yardımcıları
---------------------------------------------------------------------------
local function slots(bag)
    if C_Container and C_Container.GetContainerNumSlots then return C_Container.GetContainerNumSlots(bag) or 0 end
    if GetContainerNumSlots then return GetContainerNumSlots(bag) or 0 end
    return 0
end

local function info(bag, slot)
    if C_Container and C_Container.GetContainerItemInfo then
        local i = C_Container.GetContainerItemInfo(bag, slot)
        if i then return i.hyperlink, i.stackCount or 1, i.quality, i.hasNoValue, i.itemID end
        return
    end
    if GetContainerItemInfo then
        local _, cnt, _, quality, _, _, link, _, noValue, id = GetContainerItemInfo(bag, slot)
        return link, cnt or 1, quality, noValue, id
    end
end

local function itemData(link)
    local price, classID
    if C_Item and C_Item.GetItemInfo then
        local r = { C_Item.GetItemInfo(link) }
        price, classID = r[11], r[12]
    elseif GetItemInfo then
        local r = { GetItemInfo(link) }
        price, classID = r[11], r[12]
    end
    return price or 0, classID
end

-- Görev eşyası (classID 12), sıfır değerli ve iyi kalite (yeşil üstü) eşyalar aday değil.
function Extras:FindCheapest()
    local best, bestV, bestBag, bestSlot
    for bag = 0, 4 do
        for slot = 1, slots(bag) do
            local link, cnt, quality, noValue = info(bag, slot)
            if link and not noValue and (quality or 1) <= 1 then
                local price, classID = itemData(link)
                if classID ~= 12 and price > 0 then
                    local v = price * (cnt or 1)
                    if not bestV or v < bestV then best, bestV, bestBag, bestSlot = link, v, bag, slot end
                end
            end
        end
    end
    return best, bestV, bestBag, bestSlot
end

local lastReport = 0
function Extras:ReportCheapest(force)
    local now = GetTime()
    if not force and now - lastReport < 10 then return end
    lastReport = now
    local link, value = self:FindCheapest()
    if link then
        HM:Print("Çanta dolu. En değersiz eşya: " .. link .. " (" .. HM:Money(value) .. "). Yer açmak için onu sil ya da sat.")
    elseif force then
        HM:Print("Çantada silinebilecek gri ya da beyaz eşya bulamadım.")
    end
end

HM:On("UI_ERROR_MESSAGE", function(_, a, b)
    local msg = (type(b) == "string") and b or a
    if type(msg) ~= "string" then return end
    if (ERR_INV_FULL and msg == ERR_INV_FULL) or msg:lower():find("inventory is full", 1, true) then
        Extras:ReportCheapest(false)
    end
end)

---------------------------------------------------------------------------
-- Teslim bekleyen görevlerin XP'si
---------------------------------------------------------------------------
local function rewardXP(id)
    if not id or id <= 0 or not GetQuestLogRewardXP then return 0 end
    local ok, xp = pcall(GetQuestLogRewardXP, id)
    if ok and type(xp) == "number" then return xp end
    return 0
end

function Extras:PendingXP()
    local total, n = 0, 0
    for _, q in ipairs(HM:GetQuestLog()) do
        if q.complete then
            n = n + 1
            total = total + rewardXP(q.id)
        end
    end
    return total, n
end

function Extras:PendingXPText()
    if HM:Level() >= 60 then return "" end
    local ok, total, n = pcall(self.PendingXP, self)
    if not ok or not n or n == 0 then return "" end
    local max = UnitXPMax("player") or 1
    if total > 0 then
        return string.format("Teslime hazır %d görev: +%s XP (%%%d)", n, HM:Short(total), math.floor(total / max * 100))
    end
    return string.format("Teslime hazır %d görev", n)
end

---------------------------------------------------------------------------
-- Barda eski rank'lı yetenek
---------------------------------------------------------------------------
local function rankOf(sub)
    return sub and tonumber(tostring(sub):match("(%d+)")) or nil
end

local function spellSub(id)
    if C_Spell and C_Spell.GetSpellSubtext then
        local ok, s = pcall(C_Spell.GetSpellSubtext, id)
        if ok and s then return s end
    end
    if GetSpellSubtext then
        local ok, s = pcall(GetSpellSubtext, id)
        if ok then return s end
    end
end

-- Büyü kitabındaki en yüksek rank'lar: ad -> rank
local function bestRanks()
    local best = {}
    local function add(name, sub)
        local r = rankOf(sub)
        if name and r and (not best[name] or r > best[name]) then best[name] = r end
    end
    if C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines and C_SpellBook.GetSpellBookItemName then
        local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0
        for line = 1, C_SpellBook.GetNumSpellBookSkillLines() do
            local li = C_SpellBook.GetSpellBookSkillLineInfo(line)
            if li then
                for i = li.itemIndexOffset + 1, li.itemIndexOffset + li.numSpellBookItems do
                    local ok, name, sub = pcall(C_SpellBook.GetSpellBookItemName, i, bank)
                    if ok then add(name, sub) end
                end
            end
        end
    elseif GetNumSpellTabs and GetSpellTabInfo and GetSpellBookItemName then
        for tab = 1, GetNumSpellTabs() do
            local _, _, offset, num = GetSpellTabInfo(tab)
            for i = offset + 1, offset + num do
                local ok, name, sub = pcall(GetSpellBookItemName, i, BOOKTYPE_SPELL or "spell")
                if ok then add(name, sub) end
            end
        end
    end
    return best
end

function Extras:CheckRanks(force)
    if not GetActionInfo then return end
    local best = bestRanks()
    local old, seen = {}, {}
    for slot = 1, 120 do
        local kind, id = GetActionInfo(slot)
        if kind == "spell" and id and not seen[id] then
            seen[id] = true
            local name = HM:SpellName(id)
            local r = rankOf(spellSub(id))
            if name and r and best[name] and best[name] > r then
                old[#old + 1] = string.format("%s (barda %d, kitapta %d)", name, r, best[name])
            end
        end
    end
    if #old > 0 then
        HM:Print("Barda eski rank: " .. table.concat(old, ", ") .. ". Büyü kitabından yenisini bara sürükle.")
    elseif force then
        HM:Print("Bardaki tüm yetenekler en yüksek rank'ta.")
    end
end

local pending = false
local function later()
    if pending then return end
    pending = true
    C_Timer.After(2, function()
        pending = false
        if not HM:InCombat() then Extras:CheckRanks(false) end
    end)
end

HM:On("LEARNED_SPELL_IN_TAB", later)
HM:On("TRAINER_CLOSED", later)
HM:OnLogin(function() C_Timer.After(5, later) end)
