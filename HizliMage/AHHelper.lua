---------------------------------------------------------------------------
-- AHHelper.lua: seviyene ve sınıfına göre AH'de aranacak akıllı liste.
-- /hm ah          : chat'e slot başlıkları + tam suffix adları basar
-- /hm ah <slot>   : sadece belirli slota odaklan (helm/chest/cloak vs.)
-- AH açıkken bu suffix'leri kopyalayıp Browse kutusuna yapıştır.
---------------------------------------------------------------------------
local _, ns = ...
local HM = ns.HM
if not HM then return end

local AH = {}
HM.AH = AH

-- Sınıf → öncelikli caster/healer suffix'leri ve açıklamaları
local CASTER_DMG = {
    ["MAGE"]    = { "of Frozen Wrath", "of Arcane Wrath", "of Fiery Wrath" },
    ["WARLOCK"] = { "of Shadow Wrath", "of Fiery Wrath" },
    ["PRIEST"]  = { "of Shadow Wrath", "of Healing", "of the Sorcerer" },
    ["DRUID"]   = { "of Nature's Wrath", "of the Sorcerer", "of Healing" },
    ["SHAMAN"]  = { "of Nature's Wrath", "of Fiery Wrath", "of Healing" },
    ["PALADIN"] = { "of the Crusade", "of Healing" },
}

local SECONDARY = { "of the Sorcerer", "of the Owl", "of the Eagle" }  -- Int+Spi / Int+Spi / Int+Sta

-- Her slot için: baz item önerisi (opsiyonel, named drop) + suffix taraması
local SLOTS = {
    { key = "helm",     label = "Baş (Helm)",           bases = {"Silk Cowl", "Wizard's Hat", "Scouting Headband"} },
    { key = "neck",     label = "Boyun (Necklace)",     bases = {"Amulet", "Chain of the Scirocco", "Pendant"} },
    { key = "shoulder", label = "Omuz (Shoulder)",      bases = {"Mantle", "Silk Spaulders"} },
    { key = "cloak",    label = "Pelerin (Cloak)",      bases = {"Mistscape Cloak", "Grassland Cloak", "Durable Cloak", "Greater Scorpid Cloak"} },
    { key = "chest",    label = "Göğüs (Robe/Chest)",   bases = {"Silk Robe", "Emerald Vest", "Mail Combat Armor"} },
    { key = "wrist",    label = "Bilek (Bracers)",      bases = {"Silk Wristbands", "Dervish Bracers"} },
    { key = "hand",     label = "El (Gloves)",          bases = {"Silk Gloves", "Dervish Gloves"} },
    { key = "waist",    label = "Bel (Belt)",           bases = {"Silk Belt", "Dervish Belt"} },
    { key = "legs",     label = "Bacak (Pants)",        bases = {"Silk Pants", "Dervish Leggings"} },
    { key = "feet",     label = "Ayak (Boots)",         bases = {"Silk Boots", "Dervish Boots"} },
    { key = "ring",     label = "Yüzük (Ring) ×2",      bases = {"Band", "Ring", "Signet"} },
    { key = "trinket",  label = "Trinket ×2",           bases = {"Beads", "Minor Mana Gem"}, note = "Trinket sloğuna AH'den suffix'siz özel eşyalar (Shadow Hood, Serpent Coil, vs. — dungeon drop'ları)" },
    { key = "weapon",   label = "Ana el (MH/2H)",       bases = {"Spellshifter Rod", "Odo's Ley Staff (SFK)", "Rod of the Sleepwalker (BFD quest)"}, note = "Suffix'li staff/dagger: 'of Frozen Wrath' baz dagger/wand ilvl 22-30" },
    { key = "offhand",  label = "Yan el (Offhand)",     bases = {"Tome of Divine Right", "Chained Censer"}, note = "Caster offhand nadir; genelde 2H staff tercih edilir" },
    { key = "wand",     label = "Asa (Wand)",           bases = {"Zapthrottle Mote Extractor — hayır, oyuncak"}, note = "Wand için 'of Frozen Wrath' veya named: Hypnotic Blade yanlış kategori, doğru: Burning Sprite (BFD drop)" },
}

-- İlvl bandı seviyeye göre öner (±4 civarı)
local function ilvlRange(level)
    local lo = math.max(1, level - 3)
    local hi = level + 3
    return lo, hi
end

-- Frost SP suffix'inin verdiği ortalama SP miktarı (ilvl bandına göre)
local function suffixSPAt(suffix, ilvlHi)
    if suffix:find("Wrath") then
        if ilvlHi <= 20 then return 5
        elseif ilvlHi <= 28 then return 9
        elseif ilvlHi <= 36 then return 11
        elseif ilvlHi <= 44 then return 13
        else return 15 end
    elseif suffix:find("Sorcerer") then
        return "+Int + Spi"
    elseif suffix:find("Owl") then
        return "+Int + Spi"
    elseif suffix:find("Eagle") then
        return "+Int + Sta"
    end
    return "?"
end

local function reportSlot(slot, level, classKey)
    local lo, hi = ilvlRange(level)
    HM:Print(string.format("|cffffd100%s|r  (ilvl %d-%d)", slot.label, lo, hi))
    -- Named baz item önerileri
    if slot.bases and #slot.bases > 0 then
        local shown = {}
        for i, b in ipairs(slot.bases) do if i <= 4 then shown[#shown+1] = b end end
        HM:Print("  Baz adaylar: " .. table.concat(shown, ", "))
    end
    -- Ana suffix'ler
    local sfx = CASTER_DMG[classKey] or CASTER_DMG["MAGE"]
    for _, s in ipairs(sfx) do
        local sp = suffixSPAt(s, hi)
        if type(sp) == "number" then
            HM:Print(string.format("  |cff80ff80%s|r → +%d spell power (frost/arcane/fire odaklı)", s, sp))
        end
    end
    -- İkincil (Int+Spi tipi)
    for _, s in ipairs(SECONDARY) do
        HM:Print(string.format("  |cff80bbdd%s|r → %s", s, suffixSPAt(s, hi)))
    end
    if slot.note then HM:Print("  |cff888888Not:|r " .. slot.note) end
end

function AH:Report(filter)
    local level = UnitLevel("player") or 1
    local class = ns.class or (UnitClass and select(2, UnitClass("player"))) or "MAGE"
    HM:Print(string.format("|cffffd100AH alışveriş listesi — %d. seviye %s|r", level, class))
    HM:Print("|cff888888AH'de Browse kutusuna suffix'i aynen yaz (tırnak koyma); ilvl filtresi varsa seviye ±3 aralığı|r")
    HM:Print(" ")
    local f = filter and filter:lower() or nil
    for _, slot in ipairs(SLOTS) do
        if not f or slot.key == f or slot.label:lower():find(f, 1, true) then
            reportSlot(slot, level, class)
            HM:Print(" ")
        end
    end
    HM:Print("|cff888888İpucu: aynı arayışta birden fazla cloak baz adı yoksa suffix'i yalnız ara → tüm bazlar listelenir|r")
    HM:Print("|cff888888Enchant: silaha Minor Wizard Oil (+8 SP, 30dk) — AH'den 1-5 altın|r")
end

function AH:Toggle()
    -- Ileride GUI olursa buradan açılır; şimdilik basit rapor.
    self:Report()
end
