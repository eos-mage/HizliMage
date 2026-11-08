-- Su/yemek takibi, buff hatırlatması, gri eşya satışı, otomatik tamir ve bez stoku.

local ADDON, ns = ...
local HM = ns.HM
local Bags = {}
HM.Bags = Bags

local function count(ids)
    local total = 0
    for _, id in ipairs(ids) do
        local n
        if C_Item and C_Item.GetItemCount then
            n = C_Item.GetItemCount(id)
        elseif GetItemCount then
            n = GetItemCount(id)
        end
        total = total + (n or 0)
    end
    return total
end

---------------------------------------------------------------------------
-- Buff kontrolü (savaş dışında)
---------------------------------------------------------------------------
local nameCache = {}
local function namesFor(ids)
    local key = ids
    if nameCache[key] then return nameCache[key] end
    local set, any = {}, false
    for _, id in ipairs(ids) do
        local n = HM:SpellName(id)
        if n then set[n] = true; any = true end
    end
    if any then nameCache[key] = set end
    return set
end

local function knowsAny(ids)
    for _, id in ipairs(ids) do
        if IsPlayerSpell and IsPlayerSpell(id) then return true end
        if IsSpellKnown and IsSpellKnown(id) then return true end
    end
    return false
end

local function hasBuff(names)
    for i = 1, 40 do
        local name
        if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
            local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, "player", i, "HELPFUL")
            if not ok or not aura then break end
            name = aura.name
        elseif UnitBuff then
            name = UnitBuff("player", i)
            if not name then break end
        else
            break
        end
        if name and not HM.IsSecret(name) and names[name] then return true end
    end
    return false
end

function Bags:MissingBuffs()
    if HM:InCombat() then return nil end
    local missing = {}
    local cd = ns.CD or ns.ClassData.MAGE
    for _, b in ipairs(cd.buffs or {}) do
        if knowsAny(b.ids) and not hasBuff(namesFor(b.ids)) then missing[#missing + 1] = b.n end
    end
    -- Druid hayvan formundayken buff yenileyemez; formdayken uyarı gösterme.
    if ns.class == "DRUID" and GetShapeshiftForm and (GetShapeshiftForm() or 0) > 0 then return {} end
    return missing
end

function Bags:SupplyText()
    local parts = {}
    local cd = ns.CD or ns.ClassData.MAGE
    if cd.supply == "bandage" then
        if HM:Level() >= 5 then
            local bnd = count(ns.Items.bandage)
            parts[#parts + 1] = string.format("%sBandaj %d|r", bnd < 5 and "|cffff6060" or "|cffffffff", bnd)
        end
    elseif HM:Level() >= 4 then
        local w = count(ns.Items.water)
        local f = count(ns.Items.food)
        local low = w < (HM.db.waterMin or 10)
        parts[#parts + 1] = string.format("%sSu %d|r  Yemek %d", low and "|cffff6060" or "|cffffffff", w, f)
    end
    local ok, missing = pcall(self.MissingBuffs, self)
    if ok and missing and #missing > 0 then
        parts[#parts + 1] = "|cffff9040Eksik: " .. table.concat(missing, ", ") .. "|r"
    end
    return table.concat(parts, "  •  ")
end

---------------------------------------------------------------------------
-- Satıcı: gri sat, tamir et
---------------------------------------------------------------------------
local function containerSlots(bag)
    if C_Container and C_Container.GetContainerNumSlots then return C_Container.GetContainerNumSlots(bag) or 0 end
    if GetContainerNumSlots then return GetContainerNumSlots(bag) or 0 end
    return 0
end

local function containerInfo(bag, slot)
    if C_Container and C_Container.GetContainerItemInfo then
        local info = C_Container.GetContainerItemInfo(bag, slot)
        if info then return info.quality, info.hyperlink, info.stackCount, info.hasNoValue, info.isLocked end
        return
    end
    if GetContainerItemInfo then
        local _, cnt, locked, quality, _, _, link, _, noValue = GetContainerItemInfo(bag, slot)
        return quality, link, cnt, noValue, locked
    end
end

local function useItem(bag, slot)
    if C_Container and C_Container.UseContainerItem then
        C_Container.UseContainerItem(bag, slot)
    elseif UseContainerItem then
        UseContainerItem(bag, slot)
    end
end

local function sellPrice(link)
    if not link then return 0 end
    local p
    if C_Item and C_Item.GetItemInfo then p = select(11, C_Item.GetItemInfo(link)) end
    if not p and GetItemInfo then p = select(11, GetItemInfo(link)) end
    return p or 0
end

local merchantOpen = false

function Bags:SellJunk()
    local queue, total = {}, 0
    for bag = 0, 4 do
        for slot = 1, containerSlots(bag) do
            local quality, link, cnt, noValue, locked = containerInfo(bag, slot)
            if quality == 0 and link and not noValue and not locked then
                local price = sellPrice(link) * (cnt or 1)
                if price > 0 then
                    queue[#queue + 1] = { bag = bag, slot = slot }
                    total = total + price
                end
            end
        end
    end
    if #queue == 0 then return end
    local i = 0
    local function nextSell()
        i = i + 1
        if not merchantOpen or i > #queue then
            if i > #queue then HM:Print("Gri eşyalar satıldı: " .. HM:Money(total)) end
            return
        end
        useItem(queue[i].bag, queue[i].slot)
        C_Timer.After(0.12, nextSell)
    end
    nextSell()
end

function Bags:Repair()
    if not (CanMerchantRepair and CanMerchantRepair()) then return end
    local cost, can = GetRepairAllCost()
    if can and cost and cost > 0 and GetMoney() >= cost then
        RepairAllItems()
        HM:Print("Tamir: " .. HM:Money(cost))
    end
end

HM:On("MERCHANT_SHOW", function()
    merchantOpen = true
    if IsShiftKeyDown() then return end
    if HM.db.autoRepair then Bags:Repair() end
    if HM.db.autoSell then C_Timer.After(0.2, function() Bags:SellJunk() end) end
end)

HM:On("MERCHANT_CLOSED", function() merchantOpen = false end)

---------------------------------------------------------------------------
-- Bez stoku (60'ta Tailoring için)
---------------------------------------------------------------------------
function Bags:ClothReport()
    local parts = {}
    for _, c in ipairs(ns.Items.cloth) do
        local n
        if C_Item and C_Item.GetItemCount then
            n = C_Item.GetItemCount(c[1], true)
        elseif GetItemCount then
            n = GetItemCount(c[1], true)
        end
        parts[#parts + 1] = string.format("%s: %d", c[2], n or 0)
    end
    HM:Print("Bez (çanta + banka): " .. table.concat(parts, ", "))
    HM:Print("İpucu: bez fiyatları ilk haftalarda yüksek; First Aid'e yetecek kadarını tut, fazlasını AH'ye koy, Tailoring'e 60'ta fiyatlar düşünce başla.")
end
