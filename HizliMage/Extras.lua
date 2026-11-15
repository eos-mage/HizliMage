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

-- Meslek aletleri ve kritik eşyalar — "en değersiz" raporunda ve otomatik işlemlerde
-- asla aday olarak gösterilmez. Mining Pick, Skinning Knife, Blacksmith Hammer, Arclight
-- Spanner, Fishing Pole çeşitleri. Yeni kalem gerekirse buraya eklenir.
local PROTECTED = {
    [2901]  = "Mining Pick",
    [20723] = "Brilliant Pickaxe",
    [40772] = "Hammer Pick",             -- Mining Pick alternatifi
    [7005]  = "Skinning Knife",
    [12709] = "Finkle's Skinner",
    [19901] = "Zulian Slicer",
    [40892] = "Hunting Knife",
    [5956]  = "Blacksmith Hammer",
    [40893] = "Masterwork Smithing Hammer",
    [6219]  = "Arclight Spanner",
    [40772] = "Hammer Pick",
    [40893] = "Masterwork Smithing Hammer",
    [6256]  = "Fishing Pole",
    [6365]  = "Strong Fishing Pole",
    [6366]  = "Darkwood Fishing Pole",
    [6367]  = "Big Iron Fishing Pole",
    [12225] = "Blump Family Fishing Pole",
    [19970] = "Arcanite Fishing Pole",
    [25978] = "Seth's Graphite Fishing Pole",
    [45858] = "Nat Pagle's Extreme Angler FC-5000",
    [45991] = "Bone Fishing Pole",
    [19022] = "Nat Pagle's Fish Terminator",
}

-- Küçük yardımcı: link'ten itemID çıkar (bazı sürümlerde info bazen id döndürmez).
local function idFromLink(link)
    if type(link) ~= "string" then return nil end
    local id = link:match("item:(%d+)")
    return id and tonumber(id) or nil
end

-- Görev eşyası (classID 12), sıfır değerli, iyi kalite (yeşil üstü) ve meslek aletleri
-- aday değil.
function Extras:FindCheapest()
    local best, bestV, bestBag, bestSlot
    for bag = 0, 4 do
        for slot = 1, slots(bag) do
            local link, cnt, quality, noValue, id = info(bag, slot)
            local itemID = id or idFromLink(link)
            if link and not noValue and (quality or 1) <= 1 and not (itemID and PROTECTED[itemID]) then
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

-- Büyü kitabındaki en yüksek rank'lar: ad -> rank, ad -> o rank'ın büyü kimliği
local function bestRanks()
    local best, bestID = {}, {}
    local function add(name, sub, id)
        local r = rankOf(sub)
        if name and r and (not best[name] or r > best[name]) then best[name] = r; bestID[name] = id end
    end
    if C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines and C_SpellBook.GetSpellBookItemName then
        local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0
        for line = 1, C_SpellBook.GetNumSpellBookSkillLines() do
            local li = C_SpellBook.GetSpellBookSkillLineInfo(line)
            if li then
                for i = li.itemIndexOffset + 1, li.itemIndexOffset + li.numSpellBookItems do
                    local ok, name, sub = pcall(C_SpellBook.GetSpellBookItemName, i, bank)
                    if ok then
                        local id
                        if C_SpellBook.GetSpellBookItemInfo then
                            local ok2, info = pcall(C_SpellBook.GetSpellBookItemInfo, i, bank)
                            if ok2 and type(info) == "table" and not HM.IsSecret(info.spellID) then id = info.spellID end
                        end
                        add(name, sub, id)
                    end
                end
            end
        end
    elseif GetNumSpellTabs and GetSpellTabInfo and GetSpellBookItemName then
        for tab = 1, GetNumSpellTabs() do
            local _, _, offset, num = GetSpellTabInfo(tab)
            for i = offset + 1, offset + num do
                local ok, name, sub = pcall(GetSpellBookItemName, i, BOOKTYPE_SPELL or "spell")
                local id
                if GetSpellBookItemInfo then
                    local ok2, _, sid = pcall(GetSpellBookItemInfo, i, BOOKTYPE_SPELL or "spell")
                    if ok2 then id = sid end
                end
                if ok then add(name, sub, id) end
            end
        end
    end
    return best, bestID
end

-- EllesmereUI'ın Uprank özelliği (Forever Essentials) varsa onu açık tutar; yeni rank öğrenilince
-- bardaki eski rank'ları o değiştirir. Dönüş: true = Uprank bu işi üstleniyor.
local function ellesmereUprank()
    local P = _G.EllesmereUIDB
    local U = EllesmereUI and EllesmereUI._SpellUprank
    if not (P and U) then return false end
    P.spellUprank = P.spellUprank or {}
    if P.spellUprank.enabled ~= true then
        P.spellUprank.enabled = true
        if U.Apply and not HM:InCombat() then pcall(U.Apply) end
    end
    return true
end

-- Bardaki eski rank'ları en yüksek rank'la değiştirir (Uprank yoksa kendi yapar).
function Extras:CheckRanks(force)
    if not GetActionInfo then return end
    local best, bestID = bestRanks()
    local old, swapped, seen = {}, {}, {}
    local canSwap = not HM:InCombat() and (not GetCursorInfo or GetCursorInfo() == nil)
        and C_Spell and C_Spell.PickupSpell and PlaceAction and ClearCursor
    local uprank = ellesmereUprank()
    for slot = 1, 120 do
        local kind, id = GetActionInfo(slot)
        if kind == "spell" and id then
            local name = HM:SpellName(id)
            local r = rankOf(spellSub(id))
            if name and r and best[name] and best[name] > r then
                local newID = bestID[name]
                if canSwap and not uprank and newID and newID ~= id then
                    local ok = pcall(C_Spell.PickupSpell, newID)
                    if ok and GetCursorInfo and GetCursorInfo() == "spell" then
                        pcall(PlaceAction, slot)
                        pcall(ClearCursor)
                        if not seen[name] then swapped[#swapped + 1] = string.format("%s → rank %d", name, best[name]) end
                    else
                        pcall(ClearCursor)
                        if not seen[name] then old[#old + 1] = string.format("%s (barda %d, kitapta %d)", name, r, best[name]) end
                    end
                elseif not seen[name] then
                    old[#old + 1] = string.format("%s (barda %d, kitapta %d)", name, r, best[name])
                end
                seen[name] = true
            end
        end
    end
    if #swapped > 0 then
        HM:Print("Bar güncellendi: " .. table.concat(swapped, ", "))
    end
    if #old > 0 then
        if uprank then
            if force then HM:Print("Barda eski rank: " .. table.concat(old, ", ") .. " — EllesmereUI Uprank savaş bitince değiştirir.") end
        else
            HM:Print("Barda eski rank: " .. table.concat(old, ", ") .. ". Büyü kitabından yenisini bara sürükle.")
        end
    elseif force and #swapped == 0 then
        HM:Print("Bardaki tüm yetenekler en yüksek rank'ta" .. (uprank and " (otomatik güncelleme: EllesmereUI Uprank açık)." or "."))
    end
end

local pending = false
local function later()
    if pending then return end
    pending = true
    C_Timer.After(2, function()
        pending = false
        if HM:InCombat() then Extras.deferred = true else Extras:CheckRanks(false) end
    end)
end

HM:On("LEARNED_SPELL_IN_TAB", later)
HM:On("LEARNED_SPELL_IN_SKILL_LINE", later)
HM:On("TRAINER_CLOSED", later)
HM:On("PLAYER_REGEN_ENABLED", function() if Extras.deferred then Extras.deferred = false; later() end end)
HM:OnLogin(function() C_Timer.After(5, later) end)
