-- DPS yardımcısı: proc ve donma takibi. Ekranın ortasında, karakterin üstünde büyük yazı:
--   ICE LANCE (Fingers of Frost / hedef donmuş)  •  BEDAVA BÜYÜ (Clearcasting)
--   ARCANE MISSILES (Missile Barrage)  •  Winter's Chill x3/5 → CONE OF COLD!
-- Komutlar: /hm proc ac|kapat|ses|test

local ADDON, ns = ...
local HM = ns.HM
local Procs = {}
HM.Procs = Procs

local FONT = "Fonts\\ARIALN.TTF"
local SOUND_PROC = 856           -- IG_MAINMENU_OPTION_CHECKBOX_ON (kısa, sessiz tık)
local frame
local pending = false
local shownKeys = {}             -- bu anda gösterilen proc'lar (ses tekrarı için)

local function db() return HM.db and HM.db.procs end
local function safe(v) if HM.IsSecret(v) then return nil end return v end

---------------------------------------------------------------------------
-- Tablolar (ad → gösterim). Adlar oyun içi İngilizce buff adları.
---------------------------------------------------------------------------
local PLAYER_PROCS = {
    MAGE = {
        ["Fingers of Frost"] = { text = "ICE LANCE", sub = "Fingers of Frost: hedef donmuş sayılır, Shatter kriti", color = { 0.45, 0.85, 1.00 }, sound = true },
        ["Clearcasting"]     = { text = "BEDAVA BÜYÜ", sub = "Clearcasting: sıradaki büyü mana yemez — Frostbolt", color = { 0.80, 0.60, 1.00 } },
        ["Missile Barrage"]  = { text = "ARCANE MISSILES", sub = "Missile Barrage: bedava ve hızlı füzeler", color = { 1.00, 0.55, 1.00 }, sound = true },
        ["Hot Streak"]       = { text = "PYROBLAST", sub = "Hot Streak: anında Pyroblast", color = { 1.00, 0.55, 0.20 }, sound = true },
    },
    DRUID = {
        ["Clearcasting"]     = { text = "BEDAVA BÜYÜ", sub = "Omen of Clarity: sıradaki yetenek bedava", color = { 0.80, 0.60, 1.00 } },
    },
    WARRIOR = {
        ["Enrage"]           = { text = "ENRAGE", sub = "Hasar artışı — bas", color = { 1.00, 0.45, 0.30 } },
    },
    HUNTER = {
        ["Frenzy"]           = { text = "FRENZY", sub = "Pet hız artışı", color = { 0.80, 0.90, 0.30 } },
        ["Quick Shots"]      = { text = "QUICK SHOTS", sub = "Ateş hızı artırıldı", color = { 0.45, 0.85, 1.00 }, sound = true },
        ["Rapid Killing"]    = { text = "RAPID KILLING", sub = "Hedef öldü — bonus hasar", color = { 1.00, 0.60, 0.20 }, sound = true },
    },
    WARLOCK = {
        ["Nightfall"]        = { text = "SHADOW BOLT!", sub = "Nightfall: anında Shadow Bolt — hemen bas!", color = { 0.60, 0.30, 0.90 }, sound = true },
        ["Backlash"]         = { text = "SHADOW BOLT!", sub = "Backlash: anında Shadow Bolt", color = { 0.60, 0.30, 0.90 }, sound = true },
    },
    ROGUE = {
        ["Remorseless Attacks"] = { text = "CRIT BONUSU", sub = "Remorseless: sıradaki yetenek ekstra krit", color = { 1.00, 0.85, 0.30 }, sound = true },
    },
    SHAMAN = {
        ["Clearcasting"]     = { text = "BEDAVA BÜYÜ", sub = "Elemental Focus: sıradaki 2 büyü mana yemez", color = { 0.80, 0.60, 1.00 } },
        ["Flurry"]           = { text = "FLURRY", sub = "Krit sonrası hız artışı", color = { 0.80, 0.90, 0.30 } },
    },
    PRIEST = {
        ["Spirit Tap"]       = { text = "SPIRIT TAP", sub = "Hedef öldü — mana doluyor", color = { 0.45, 0.85, 1.00 } },
    },
    PALADIN = {
        ["Vengeance"]        = { text = "VENGEANCE", sub = "Krit sonrası hasar artışı", color = { 1.00, 0.85, 0.30 } },
    },
}

-- Hedefte donma: Ice Lance (ve Shatter) zamanı
local FROZEN = { ["Frost Nova"] = true, ["Frostbite"] = true, ["Freeze"] = true, ["Frozen"] = true }
local WINTERS_CHILL = "Winter's Chill"
local WC_MAX = 5

---------------------------------------------------------------------------
-- Görsel
---------------------------------------------------------------------------
local function Create()
    if frame then return frame end
    frame = CreateFrame("Frame", "HizliMageProcs", UIParent)
    frame:SetSize(420, 90)
    frame:SetPoint("CENTER", 0, 150)
    frame:SetFrameStrata("HIGH")
    frame:EnableMouse(false)
    frame.main = frame:CreateFontString(nil, "OVERLAY")
    frame.main:SetFont(FONT, 34, "OUTLINE")
    frame.main:SetPoint("TOP", 0, 0)
    frame.sub = frame:CreateFontString(nil, "OVERLAY")
    frame.sub:SetFont(FONT, 15, "OUTLINE")
    frame.sub:SetPoint("TOP", frame.main, "BOTTOM", 0, -2)
    frame.sub:SetTextColor(0.9, 0.9, 0.9)
    frame.extra = frame:CreateFontString(nil, "OVERLAY")
    frame.extra:SetFont(FONT, 18, "OUTLINE")
    frame.extra:SetPoint("TOP", frame.sub, "BOTTOM", 0, -4)
    frame.extra:SetTextColor(0.6, 0.9, 1.0)
    frame:Hide()
    return frame
end

local function Sound()
    local p = db()
    if not (p and p.sound) then return end
    pcall(PlaySound, SOUND_PROC, "Master")
end

---------------------------------------------------------------------------
-- Aura okuma (gizli değerlere dayanıklı)
---------------------------------------------------------------------------
local function eachAura(unit, filter, fn)
    if not (UnitExists and UnitExists(unit)) then return end
    for i = 1, 40 do
        local aura
        if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
            local ok, d = pcall(C_UnitAuras.GetAuraDataByIndex, unit, i, filter)
            if ok and type(d) == "table" then aura = d end
        elseif UnitAura then
            local ok, name, icon, count = pcall(UnitAura, unit, i, filter)
            if ok and name then aura = { name = name, icon = icon, applications = count } end
        end
        if not aura then break end
        local name = safe(aura.name)
        if name and fn(name, aura) then return end
    end
end

local function knows(spellName)
    if not (C_Spell and C_Spell.GetSpellInfo) then return true end
    local ok, info = pcall(C_Spell.GetSpellInfo, spellName)
    if not ok then return true end
    return info ~= nil
end

local function Update()
    local p = db()
    if not (p and p.enabled) then if frame then frame:Hide() end return end
    local class = ns.class or select(2, UnitClass("player"))
    local table_ = PLAYER_PROCS[class]
    if not table_ then if frame then frame:Hide() end return end
    local f = Create()

    local main, sub, color, mainKey
    local extra = {}
    local newKeys = {}

    -- 1) Oyuncu proc'ları
    eachAura("player", "HELPFUL", function(name, aura)
        local def = table_[name]
        if def then
            if not main then
                main, sub, color, mainKey = def.text, def.sub, def.color, name
                local n = safe(aura.applications)
                if type(n) == "number" and n > 1 then main = main .. " x" .. n end
            else
                extra[#extra + 1] = def.text
            end
            newKeys[name] = def.sound
        end
        return false
    end)

    -- 2) Hedef: donma ve Winter's Chill (yalnız mage)
    if class == "MAGE" and UnitExists and UnitExists("target") and UnitCanAttack and UnitCanAttack("player", "target") then
        local frozen, wc
        eachAura("target", "HARMFUL", function(name, aura)
            if FROZEN[name] then frozen = name end
            if name == WINTERS_CHILL then wc = safe(aura.applications) or 1 end
            return false
        end)
        if frozen and knows("Ice Lance") then
            if not main then
                main, sub, color, mainKey = "ICE LANCE", frozen .. ": hedef donmuş — Ice Lance 4 kat, Shatter kriti", { 0.45, 0.85, 1.00 }, "frozen"
            else
                extra[#extra + 1] = "hedef donmuş (" .. frozen .. ")"
            end
            newKeys.frozen = true
        end
        if wc then
            if wc >= WC_MAX and knows("Cone of Cold") then
                if not main then
                    main, sub, color, mainKey = "CONE OF COLD!", "Winter's Chill 5/5 — yaklaş ve Cone of Cold ile bitir", { 1.00, 0.85, 0.30 }, "wc5"
                else
                    extra[#extra + 1] = "Winter's Chill 5/5 → Cone of Cold"
                end
                newKeys.wc5 = true
            else
                extra[#extra + 1] = string.format("Winter's Chill x%d/%d", wc, WC_MAX)
            end
        end
    end

    if not main and #extra == 0 then
        f:Hide()
        shownKeys = {}
        return
    end

    -- yeni başlayan proc'ta kısa ses
    for k, snd in pairs(newKeys) do
        if snd and not shownKeys[k] then Sound(); break end
    end
    shownKeys = newKeys

    if main then
        f.main:SetText(HM:T(main))
        f.main:SetTextColor(color[1], color[2], color[3])
        f.sub:SetText(HM:T(sub or ""))
    else
        f.main:SetText("")
        f.sub:SetText("")
    end
    f.extra:SetText(HM:T(table.concat(extra, "  •  ")))
    f:Show()
end

local function schedule()
    if pending then return end
    pending = true
    C_Timer.After(0.1, function()
        pending = false
        pcall(Update)
    end)
end

---------------------------------------------------------------------------
-- Olaylar ve komutlar
---------------------------------------------------------------------------
HM:On("UNIT_AURA", function(_, unit)
    if unit == "player" or unit == "target" then schedule() end
end)
HM:On("PLAYER_TARGET_CHANGED", schedule)
HM:On("PLAYER_REGEN_ENABLED", schedule)
HM:OnLogin(function() C_Timer.After(3, schedule) end)

function Procs:Command(arg)
    local p = db(); if not p then return end
    arg = (arg or ""):lower()
    if arg == "kapat" then p.enabled = false; schedule(); HM:Print("Proc göstergesi kapalı.")
    elseif arg == "ac" or arg == "aç" then p.enabled = true; schedule(); HM:Print("Proc göstergesi açık.")
    elseif arg == "ses" then p.sound = not p.sound; HM:Print("Proc sesi: " .. (p.sound and "açık" or "kapalı"))
    elseif arg == "test" then
        local f = Create()
        f.main:SetText(HM:T("ICE LANCE")); f.main:SetTextColor(0.45, 0.85, 1.00)
        f.sub:SetText(HM:T("Fingers of Frost: hedef donmuş sayılır, Shatter kriti"))
        f.extra:SetText(HM:T("Winter's Chill x3/5"))
        f:Show()
        Sound()
        C_Timer.After(4, function() pcall(Update) end)
    else
        HM:Print("Kullanım: /hm proc ac | kapat | ses | test — durum: " .. (p.enabled and "açık" or "kapalı") .. ", ses " .. (p.sound and "açık" or "kapalı"))
    end
end
