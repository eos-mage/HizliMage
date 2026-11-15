-- DPS denetimi: /hm dps — ekipman, buff, rank, talent, wand/Shoot, su-yemek ve istemci ayarları.
-- Güvenli ayarları kendisi düzeltir (tuşa basınca büyü, büyü kuyruğu, kendine otomatik büyü, otomatik yağma),
-- geri kalanını ✓/✗ listesi olarak yazar. Girişte yalnız sorun sayısını söyler.

local ADDON, ns = ...
local HM = ns.HM
local Dps = {}
HM.Dps = Dps

local function safe(v) if HM.IsSecret(v) then return nil end return v end
local OK, BAD, WARN = "|cff80ff80+|r ", "|cffff6060x|r ", "|cffffd100!|r "

---------------------------------------------------------------------------
-- İstemci ayarları (DPS'i doğrudan etkileyenler)
---------------------------------------------------------------------------
local CVARS = {
    { "ActionButtonUseKeyDown", "1",   "Büyü tuşa BASINCA gider (bırakınca değil): her vuruşta ~50-100 ms kazanç" },
    { "SpellQueueWindow",       "400", "Büyü kuyruğu 400 ms: bir sonraki büyüyü erken basınca GCD boşluğu kalmaz" },
    { "autoSelfCast",           "1",   "Dost büyüleri hedefsizken kendine gider (Arcane Intellect, Ice Barrier)" },
    { "autoLootDefault",        "1",   "Otomatik yağma: her mobda bir tık daha az" },
}

local function getCVar(name)
    local g = (C_CVar and C_CVar.GetCVar) or GetCVar
    if not g then return nil end
    local ok, v = pcall(g, name)
    return ok and v or nil
end

local function setCVar(name, value)
    local s = (C_CVar and C_CVar.SetCVar) or SetCVar
    if not s then return false end
    return pcall(s, name, value)
end

function Dps:FixCVars(verbose)
    local fixed = {}
    for _, c in ipairs(CVARS) do
        local cur = getCVar(c[1])
        if cur ~= nil and tostring(cur) ~= c[2] then
            if setCVar(c[1], c[2]) then fixed[#fixed + 1] = c[1] .. "=" .. c[2] end
        end
    end
    if verbose then
        if #fixed > 0 then
            HM:Print(OK .. "Ayarlar düzeltildi: " .. table.concat(fixed, ", "))
        else
            HM:Print(OK .. "İstemci ayarları doğru (tuşa basınca büyü, 400 ms kuyruk, kendine otomatik büyü, otomatik yağma).")
        end
    end
    return #fixed
end

---------------------------------------------------------------------------
-- Ekipman
---------------------------------------------------------------------------
local SLOTS = {
    { 1, "Kafa" }, { 2, "Boyun" }, { 3, "Omuz" }, { 15, "Pelerin" }, { 5, "Göğüs" }, { 9, "Bilek" },
    { 10, "El" }, { 6, "Bel" }, { 7, "Bacak" }, { 8, "Ayak" }, { 11, "Yüzük 1" }, { 12, "Yüzük 2" },
    { 13, "Biblo 1" }, { 14, "Biblo 2" }, { 16, "Ana el" }, { 17, "Yan el" }, { 18, "Wand" },
}
-- Hangi seviyeden sonra boş yuva sorun sayılır (düşük seviyede yüzük/biblo/kafa bulunmaz)
local SLOT_MIN_LEVEL = { [1] = 25, [2] = 15, [3] = 18, [15] = 12, [9] = 12, [11] = 15, [12] = 25, [13] = 35, [14] = 45, [17] = 20, [18] = 6 }

local function itemStats(link)
    local f = (C_Item and C_Item.GetItemStats) or GetItemStats
    if not f then return nil end
    local ok, t = pcall(f, link)
    return ok and type(t) == "table" and t or nil
end

local function stat(t, ...)
    local sum = 0
    for i = 1, select("#", ...) do
        local v = t[select(i, ...)]
        if type(v) == "number" then sum = sum + v end
    end
    return sum
end

local function itemLevel(link)
    local f = (C_Item and C_Item.GetDetailedItemLevelInfo) or GetDetailedItemLevelInfo
    if not f then return nil end
    local ok, lvl = pcall(f, link)
    return ok and tonumber(lvl) or nil
end

local function enchantOf(link)
    local e = link and link:match("item:%d+:(%d*):")
    return e and e ~= "" and e ~= "0"
end

function Dps:Gear(verbose)
    local level = HM:Level()
    local caster = (ns.class == "MAGE" or ns.class == "DRUID")
    local problems, totInt, totSP, totSta, totSpi = {}, 0, 0, 0, 0
    local hasWand = false
    for _, s in ipairs(SLOTS) do
        local slot, label = s[1], s[2]
        local link = GetInventoryItemLink and GetInventoryItemLink("player", slot)
        if not link then
            if (SLOT_MIN_LEVEL[slot] or 1) <= level and not (slot == 17 and ns.class ~= "MAGE") then
                -- yan el: iki elli silah varsa boş olması normal
                local main = GetInventoryItemLink and GetInventoryItemLink("player", 16)
                local twoHand = false
                if slot == 17 and main then
                    local f = (C_Item and C_Item.GetItemInventoryTypeByID) or nil
                    local ok, invType = pcall(function() return select(9, (C_Item and C_Item.GetItemInfo or GetItemInfo)(main)) end)
                    twoHand = ok and (invType == "INVTYPE_2HWEAPON")
                end
                if not twoHand then problems[#problems + 1] = label .. " boş" end
            end
        else
            if slot == 18 then hasWand = true end
            local st = itemStats(link)
            if st then
                local int = stat(st, "ITEM_MOD_INTELLECT_SHORT")
                local sp = stat(st, "ITEM_MOD_SPELL_POWER_SHORT", "ITEM_MOD_SPELL_DAMAGE_DONE_SHORT", "ITEM_MOD_SPELL_FROST_DAMAGE_DONE_SHORT", "ITEM_MOD_SPELL_FIRE_DAMAGE_DONE_SHORT")
                local sta = stat(st, "ITEM_MOD_STAMINA_SHORT")
                local spi = stat(st, "ITEM_MOD_SPIRIT_SHORT")
                local melee = stat(st, "ITEM_MOD_STRENGTH_SHORT", "ITEM_MOD_AGILITY_SHORT")
                totInt, totSP, totSta, totSpi = totInt + int, totSP + sp, totSta + sta, totSpi + spi
                if caster and slot ~= 18 and slot ~= 13 and slot ~= 14 then
                    if melee > 0 and int == 0 and sp == 0 then
                        problems[#problems + 1] = label .. ": " .. link .. " savaşçı statı (Str/Agi), caster'a faydasız"
                    elseif level >= 15 and int == 0 and sp == 0 and spi == 0 and sta == 0 then
                        problems[#problems + 1] = label .. ": " .. link .. " statsız (beyaz/gri)"
                    end
                end
            end
            if level >= 50 and (slot == 16 or slot == 5 or slot == 9 or slot == 10 or slot == 8 or slot == 7 or slot == 3) and not enchantOf(link) then
                problems[#problems + 1] = label .. ": büyü (enchant) yok"
            end
        end
    end
    if ns.class == "MAGE" and level >= 6 and not hasWand then problems[#problems + 1] = "Wand yok — mana bitince ve kiting'de wand hasarı ciddi fark" end
    if verbose then
        if #problems == 0 then
            HM:Print(OK .. string.format("Ekipman temiz. Toplam Int %d, büyü gücü %d, Sta %d, Spirit %d.", totInt, totSP, totSta, totSpi))
        else
            HM:Print(BAD .. string.format("Ekipman: %d sorun (toplam Int %d, büyü gücü %d):", #problems, totInt, totSP))
            for _, p in ipairs(problems) do HM:Print("   • " .. p) end
            if caster then HM:Print("   Öncelik: büyü gücü > Int > Sta; Str/Agi eşyaları sat. Bez: 'of the Eagle' (Int+Sta), 'of the Owl' (Int+Spirit).") end
        end
    end
    return #problems
end

---------------------------------------------------------------------------
-- Bardaki yetenekler: Shoot (wand), ana büyüler
---------------------------------------------------------------------------
local function onBars(spellName)
    if not GetActionInfo then return true end
    for slot = 1, 120 do
        local kind, id = GetActionInfo(slot)
        if kind == "spell" and id then
            local n = HM:SpellName(id)
            if n == spellName then return true end
        end
    end
    return false
end

local function knowsName(spellName)
    if not (C_Spell and C_Spell.GetSpellInfo) then return nil end
    local ok, info = pcall(C_Spell.GetSpellInfo, spellName)
    if not ok then return nil end
    return info ~= nil
end

-- Shoot (wand) barda yoksa ilk boş yuvaya koyar (savaş dışında, imleç boşken). Dönüş: yuva no ya da nil
local SHOOT_ID = 5019
local function placeShoot()
    if HM:InCombat() or not (C_Spell and C_Spell.PickupSpell and PlaceAction and GetActionInfo) then return nil end
    if GetCursorInfo and GetCursorInfo() ~= nil then return nil end
    local known = (IsPlayerSpell and IsPlayerSpell(SHOOT_ID)) or (IsSpellKnown and IsSpellKnown(SHOOT_ID))
    if not known then return nil end
    -- önce ana bar (1-12), sonra diğer barlar
    for slot = 1, 72 do
        local kind = GetActionInfo(slot)
        if not kind then
            local ok = pcall(C_Spell.PickupSpell, SHOOT_ID)
            if ok and GetCursorInfo and GetCursorInfo() == "spell" then
                pcall(PlaceAction, slot)
                pcall(ClearCursor)
                if (GetActionInfo(slot)) then return slot end
            end
            pcall(ClearCursor)
            return nil
        end
    end
    return nil
end

function Dps:Bars(verbose)
    local problems = {}
    local level = HM:Level()
    local wand = GetInventoryItemLink and GetInventoryItemLink("player", 18)
    if wand and not onBars("Shoot") then
        local slot = placeShoot()
        if slot then
            HM:Print(OK .. "Shoot (wand ateşi) bara eklendi: yuva " .. slot .. (slot <= 12 and (" (tuş " .. (slot == 10 and "0" or slot == 11 and "-" or slot == 12 and "=" or tostring(slot)) .. ")") or "") .. ". Mana bitince ya da mob ölmek üzereyken kullan.")
        else
            problems[#problems + 1] = "Shoot (wand ateşi) barda yok — mana bitince ya da son vuruşta wand kullan"
        end
    end
    local core = {}
    if ns.class == "MAGE" then
        core = { "Frostbolt", "Fireball", "Frost Nova", "Counterspell", "Fire Blast" }
        if level >= 20 then core[#core + 1] = "Ice Lance" end
        if level >= 20 then core[#core + 1] = "Blink" end
        if level >= 26 then core[#core + 1] = "Cone of Cold" end
    elseif ns.class == "DRUID" then
        core = { "Wrath", "Moonfire", "Rejuvenation" }
    elseif ns.class == "WARRIOR" then
        core = { "Heroic Strike", "Charge", "Rend" }
    elseif ns.class == "HUNTER" then
        core = { "Auto Shot", "Serpent Sting", "Arcane Shot", "Concussive Shot" }
        if level >= 20 then core[#core + 1] = "Aimed Shot" end
        if level >= 18 then core[#core + 1] = "Multi-Shot" end
        if level >= 20 then core[#core + 1] = "Aspect of the Cheetah" end
    elseif ns.class == "WARLOCK" then
        core = { "Shadow Bolt", "Corruption", "Immolate", "Life Tap" }
        if level >= 14 then core[#core + 1] = "Drain Life" end
        if level >= 8 then core[#core + 1] = "Fear" end
    elseif ns.class == "ROGUE" then
        core = { "Sinister Strike", "Eviscerate", "Slice and Dice", "Kick" }
        if level >= 22 then core[#core + 1] = "Vanish" end
        if level >= 16 then core[#core + 1] = "Sprint" end
    elseif ns.class == "SHAMAN" then
        core = { "Lightning Bolt", "Earth Shock", "Flame Shock", "Lightning Shield" }
        if level >= 20 then core[#core + 1] = "Healing Wave" end
    elseif ns.class == "PRIEST" then
        core = { "Shadow Word: Pain", "Mind Blast", "Power Word: Shield" }
        if level >= 20 then core[#core + 1] = "Mind Flay" end
        if level >= 10 then core[#core + 1] = "Psychic Scream" end
    elseif ns.class == "PALADIN" then
        core = { "Judgement", "Seal of Righteousness", "Blessing of Might", "Flash of Light" }
        if level >= 6 then core[#core + 1] = "Holy Strike" end
        if level >= 8 then core[#core + 1] = "Hammer of Justice" end
    end
    for _, n in ipairs(core) do
        local known = knowsName(n)
        if known and not onBars(n) then problems[#problems + 1] = n .. " öğrenilmiş ama barda yok" end
    end
    if verbose then
        if #problems == 0 then HM:Print(OK .. "Bar: ana yetenekler ve Shoot yerinde.")
        else for _, p in ipairs(problems) do HM:Print(BAD .. p) end end
    end
    return #problems
end

---------------------------------------------------------------------------
-- Tam denetim
---------------------------------------------------------------------------
function Dps:Run()
    local issues = 0
    HM:Print("|cff33ccff— DPS denetimi —|r")
    -- 1) İstemci ayarları (kendi düzeltir)
    self:FixCVars(true)
    -- 2) Rank'lar
    if HM.Extras and HM.Extras.CheckRanks then HM.Extras:CheckRanks(true) end
    -- 3) Talent
    if HM.Talents and HM.Talents.Command then HM.Talents:Command("uygula") end
    -- 4) Buff'lar
    if HM.Bags and HM.Bags.MissingBuffs then
        local ok, missing = pcall(HM.Bags.MissingBuffs, HM.Bags)
        if ok and missing then
            if #missing > 0 then issues = issues + 1; HM:Print(BAD .. "Eksik buff: " .. table.concat(missing, ", ") .. " — hep açık dursun (Int = daha çok mana ve krit)")
            else HM:Print(OK .. "Buff'lar açık.") end
        end
    end
    -- 5) Ekipman ve bar
    issues = issues + self:Gear(true)
    issues = issues + self:Bars(true)
    -- 6) Su/yemek
    if HM.Bags and HM.Bags.SupplyText then
        local ok, txt = pcall(HM.Bags.SupplyText, HM.Bags)
        if ok and txt and txt ~= "" then HM:Print(WARN .. "Erzak: " .. txt) end
    end
    -- 7) Proc göstergesi
    local p = HM.db.procs
    HM:Print((p and p.enabled and OK or BAD) .. "Proc göstergesi " .. (p and p.enabled and "açık" or "kapalı") .. " (/hm proc), zindan uyarıları " .. (HM.db.alerts and HM.db.alerts.enabled and "açık" or "kapalı") .. " (/hm uyari)")
    HM:Print(string.format("|cff33ccff— %d sorun. Oynanış: Frostbolt doldurucu; donan hedefe Ice Lance; Fingers of Frost'ta Ice Lance; mana %%20'nin altında Evocation/mana taşı; mob yaklaşınca Frost Nova, geri çekil.|r", issues))
    return issues
end

HM:OnLogin(function()
    C_Timer.After(20, function()
        if HM:InCombat() then return end
        local n = Dps:FixCVars(false)
        local g = Dps:Gear(false) + Dps:Bars(false)
        if n > 0 then HM:Print("DPS ayarları düzeltildi (" .. n .. " ayar). Tam liste: /hm dps") end
        if g > 0 then HM:Print("DPS denetimi: ekipman/barda " .. g .. " sorun var — /hm dps") end
    end)
end)
