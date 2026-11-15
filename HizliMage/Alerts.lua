-- Zindan uyarıları: kesilebilir büyü (Counterspell), çalınabilir buff (Spellsteal/dispel), patron notları,
-- öğrenilen büyü günlüğü. Komutlar: /hm uyari [ac|kapat|ses|test], /hm notlar, /hm cast
--
-- Forever/Midnight istemcisinde düşman büyü bilgileri savaşta "secret value" olabilir; her okuma korumalıdır.

local ADDON, ns = ...
local HM = ns.HM
local Alerts = {}
HM.Alerts = Alerts

local SPELLSTEAL = 30449

-- Sınıfa göre kesme yetenekleri (Forever/Classic rank kimlikleri, düşükten yükseğe). stance: savaşçı duruş sırası,
-- formIds: druid form kimliği (5 ayı, 8 dire ayı), shield: kalkan takılı olmalı.
local KICKS = {
    MAGE    = { { ids = { 2139 }, name = "Counterspell" } },
    WARRIOR = {
        { ids = { 6552, 6554 }, name = "Pummel", stance = { [3] = true }, hint = "Berserker duruşuna geç" },
        { ids = { 72, 1671, 1672 }, name = "Shield Bash", stance = { [1] = true, [2] = true }, shield = true, hint = "kalkan tak (Battle/Defensive)" },
    },
    DRUID   = {
        { ids = { 5211, 6798, 8983 }, name = "Bash", formIds = { [5] = true, [8] = true }, hint = "Ayı formuna geç" },
        { ids = { 16979 }, name = "Feral Charge", formIds = { [5] = true, [8] = true }, hint = "Ayı formuna geç" },
    },
    ROGUE   = { { ids = { 1766, 1767, 1768, 1769 }, name = "Kick" } },
    SHAMAN  = { { ids = { 8042, 8044, 8045, 8046, 10412, 10413, 10414 }, name = "Earth Shock" } },
    PRIEST  = { { ids = { 15487 }, name = "Silence" } },
}
-- Grup arkadaşlarındaki lanet/zehir için çözme büyüleri
local CURES = {
    MAGE  = { Curse = { ids = { 475 }, name = "Remove Lesser Curse" } },
    DRUID = { Curse = { ids = { 2782 }, name = "Remove Curse" }, Poison = { ids = { 8946, 2893 }, name = "Cure Poison / Abolish Poison" } },
    PRIEST = { Magic = { ids = { 527, 988 }, name = "Dispel Magic" }, Disease = { ids = { 528, 552 }, name = "Cure Disease / Abolish Disease" } },
    SHAMAN = { Poison = { ids = { 526 }, name = "Cure Poison" }, Disease = { ids = { 2870 }, name = "Cure Disease" } },
    PALADIN = { Magic = { ids = { 4987 }, name = "Cleanse" }, Poison = { ids = { 1152, 4987 }, name = "Purify / Cleanse" }, Disease = { ids = { 1152, 4987 }, name = "Purify / Cleanse" } },
}

local function playerClass()
    if ns.class then return ns.class end
    local ok, _, c = pcall(UnitClass, "player")
    return ok and c or "MAGE"
end

-- Türkçe ad + İngilizce orijinal
local function trName(name)
    local tr = ns.SpellTR and ns.SpellTR[name]
    if tr then return tr .. " (" .. name .. ")" end
    return name
end
local FONT = "Fonts\\ARIALN.TTF"   -- Friz Quadrata Türkçe harfleri (ğ ş ı İ) içermez; rehber penceresiyle aynı font
local SOUND_KES = 8959      -- RAID_WARNING
local SOUND_DIKKAT = 8960   -- RAID_BOSS_EMOTE_WARNING
local SOUND_BOSS = 12889    -- ALARM_CLOCK_WARNING_3

local frame, hideTimer
local seenCast = {}         -- guid..start → true (aynı büyü için tek uyarı)
local seenAura = {}         -- guid..auraInstanceID → true
local shownBoss = {}        -- patron adı → true (bu oturumda)
local lastInstance          -- son girilen zindan adı
local activeCastKey         -- ekranda duran uyarının büyü anahtarı

local function db()
    local d = HM.db
    if not d then return nil end
    if type(d.alerts) ~= "table" then
        d.alerts = { enabled = true, sound = true, nameplates = true, stealable = true, notes = true, cure = true }
    end
    if type(d.castLog) ~= "table" then d.castLog = {} end
    return d.alerts
end

local function safe(v) if HM.IsSecret(v) then return nil end return v end

---------------------------------------------------------------------------
-- Görsel
---------------------------------------------------------------------------
local COLORS = {
    kes    = { 1.00, 0.25, 0.25 },
    dikkat = { 1.00, 0.65, 0.20 },
    cal    = { 0.75, 0.45, 1.00 },
    boss   = { 1.00, 0.85, 0.30 },
    bilgi  = { 0.60, 0.85, 1.00 },
}

local function Create()
    if frame then return frame end
    frame = CreateFrame("Frame", "HizliMageAlert", UIParent)
    frame:SetSize(560, 64)
    frame:SetPoint("TOP", UIParent, "TOP", 0, -230)
    frame:SetFrameStrata("HIGH")
    frame:EnableMouse(false)

    frame.bg = frame:CreateTexture(nil, "BACKGROUND")
    frame.bg:SetAllPoints()
    frame.bg:SetColorTexture(0, 0, 0, 0.45)

    frame.icon = frame:CreateTexture(nil, "ARTWORK")
    frame.icon:SetSize(44, 44)
    frame.icon:SetPoint("LEFT", 10, 0)
    frame.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    frame.title = frame:CreateFontString(nil, "OVERLAY")
    pcall(frame.title.SetFont, frame.title, FONT, 30, "OUTLINE")
    if not frame.title:GetFont() then frame.title:SetFontObject(GameFontNormalHuge) end
    frame.title:SetPoint("TOPLEFT", frame, "TOPLEFT", 64, -6)
    frame.title:SetPoint("RIGHT", -10, 0)
    frame.title:SetJustifyH("LEFT")
    frame.title:SetWordWrap(false)

    frame.sub = frame:CreateFontString(nil, "OVERLAY")
    pcall(frame.sub.SetFont, frame.sub, FONT, 17, "OUTLINE")
    if not frame.sub:GetFont() then frame.sub:SetFontObject(GameFontHighlight) end
    frame.sub:SetPoint("TOPLEFT", frame.title, "BOTTOMLEFT", 0, -2)
    frame.sub:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, 6)
    frame.sub:SetJustifyH("LEFT")
    frame.sub:SetJustifyV("TOP")
    frame.sub:SetWordWrap(true)
    frame.sub:SetTextColor(1, 1, 1)

    frame:Hide()
    return frame
end

function Alerts:Show(kind, title, sub, icon, seconds, key)
    local f = Create()
    local c = COLORS[kind] or COLORS.bilgi
    -- patron notları uzun: iki-üç satır için daha yüksek şerit
    f:SetHeight(kind == "boss" and 104 or 66)
    f.icon:SetPoint("LEFT", 10, kind == "boss" and 16 or 0)
    f.title:SetText(HM:T(title or ""))
    f.title:SetTextColor(c[1], c[2], c[3])
    f.sub:SetText(HM:T(sub or ""))
    if icon then f.icon:SetTexture(icon); f.icon:Show() else f.icon:Hide() end
    f:SetAlpha(1)
    f:Show()
    activeCastKey = key
    if hideTimer then hideTimer:Cancel() end
    hideTimer = C_Timer.NewTimer(seconds or 3, function()
        if frame then frame:Hide() end
        activeCastKey = nil
    end)
end

function Alerts:HideIf(key)
    if frame and frame:IsShown() and activeCastKey and activeCastKey == key then
        frame:Hide()
        activeCastKey = nil
    end
end

local function Sound(id)
    local a = db()
    if not (a and a.sound) then return end
    pcall(PlaySound, id, "Master")
end

---------------------------------------------------------------------------
-- Büyü bilgisi yardımcıları
---------------------------------------------------------------------------
local function known(spellId)
    if IsPlayerSpell then
        local ok, r = pcall(IsPlayerSpell, spellId)
        if ok and r then return true end
    end
    if IsSpellKnown then
        local ok, r = pcall(IsSpellKnown, spellId)
        if ok and r then return true end
    end
    return false
end

local function cooldownLeft(spellId)
    local start, dur
    if C_Spell and C_Spell.GetSpellCooldown then
        local ok, cd = pcall(C_Spell.GetSpellCooldown, spellId)
        if ok and type(cd) == "table" then start, dur = safe(cd.startTime), safe(cd.duration) end
    elseif GetSpellCooldown then
        local ok, s, d = pcall(GetSpellCooldown, spellId)
        if ok then start, dur = safe(s), safe(d) end
    end
    if start and dur and dur > 1.6 then
        local left = start + dur - GetTime()
        if left > 0.3 then return left end
    end
    return 0
end

local function stanceOK(k)
    if k.stance then
        local ok, f = pcall(GetShapeshiftForm)
        f = ok and safe(f) or 0
        if not k.stance[f] then return false end
    end
    if k.formIds then
        local ok, id = pcall(GetShapeshiftFormID)
        id = ok and safe(id) or nil
        if not (id and k.formIds[id]) then return false end
    end
    if k.shield then
        local fn = (C_Item and C_Item.IsEquippedItemType) or IsEquippedItemType
        if not fn then return false end
        local ok, r = pcall(fn, "Shields")
        if not (ok and safe(r)) then return false end
    end
    return true
end

-- Sınıfın kesme durumu: "yok" (bilinen kesme yok) | "hazir", ad | "cd", ad, kalan sn | "form", ad, ipucu
local function kickState()
    local list = KICKS[playerClass()]
    if not list then return "yok" end
    local best, bestLeft, formHint
    for _, k in ipairs(list) do
        local id
        for _, sid in ipairs(k.ids) do if known(sid) then id = sid end end
        if id then
            if stanceOK(k) then
                local left = cooldownLeft(id)
                if left <= 0 then return "hazir", k.name end
                if not bestLeft or left < bestLeft then best, bestLeft = k.name, left end
            elseif not formHint then
                formHint = { k.name, k.hint or "duruş/form uygun değil" }
            end
        end
    end
    if best then return "cd", best, bestLeft end
    if formHint then return "form", formHint[1], formHint[2] end
    return "yok"
end

local function inInstance()
    if not IsInInstance then return false end
    local ok, inside, kind = pcall(IsInInstance)
    return ok and inside and (kind == "party" or kind == "raid"), kind
end

local function instanceName()
    if not GetInstanceInfo then return nil end
    local ok, name, kind = pcall(GetInstanceInfo)
    if ok and (kind == "party" or kind == "raid") then return safe(name) end
end

local function castInfo(unit)
    local name, text, tex, startMS, endMS, castID, notInt, spellId, channel
    if UnitCastingInfo then
        local ok, n, t, x, s, e, _, cid, ni, sid = pcall(UnitCastingInfo, unit)
        if ok and n then name, text, tex, startMS, endMS, castID, notInt, spellId = n, t, x, s, e, cid, ni, sid end
    end
    if not name and UnitChannelInfo then
        local ok, n, t, x, s, e, _, ni, sid = pcall(UnitChannelInfo, unit)
        if ok and n then name, text, tex, startMS, endMS, notInt, spellId, channel = n, t, x, s, e, ni, sid, true end
    end
    if not name then return nil end
    return {
        name = safe(name) or "büyü", tex = safe(tex), start = safe(startMS) or 0, endMS = safe(endMS),
        castID = safe(castID), notInt = safe(notInt), spellId = safe(spellId), channel = channel,
        secret = HM.IsSecret(name),
    }
end

local function unitGUID(unit)
    if not UnitGUID then return unit end
    local ok, g = pcall(UnitGUID, unit)
    return (ok and safe(g)) or unit
end

local function npcName(unit)
    local ok, n = pcall(UnitName, unit)
    return ok and safe(n) or nil
end

local function hostile(unit)
    if not UnitCanAttack then return true end
    local ok, r = pcall(UnitCanAttack, "player", unit)
    if not ok or HM.IsSecret(r) then return true end
    return r == true
end

-- Hangi birimlerin büyüsü umurumuzda: hedef, odak, patronlar, bana vuran isim plakaları,
-- zindanda kritik büyü (iyileştirme/kontrol) atan herkes.
local function relevant(unit, info)
    if unit == "target" or unit == "focus" then return true end
    if unit:match("^boss%d") then return true end
    if unit:match("^nameplate%d+$") then
        local a = db()
        if not (a and a.nameplates) then return false end
        if UnitIsUnit then
            local ok, r = pcall(UnitIsUnit, unit .. "target", "player")
            if ok and not HM.IsSecret(r) and r then return true end
        end
        if info and ns.CriticalCasts[info.name] and inInstance() then
            local cat = ns.CriticalCasts[info.name]
            return cat == "iyileştirme" or cat == "diriltme" or cat == "uyku" or cat == "korku" or cat == "zihin kontrolü" or cat == "kontrol"
        end
    end
    return false
end

---------------------------------------------------------------------------
-- Büyü günlüğü (öğrenme)
---------------------------------------------------------------------------
local function logCast(unit, info)
    local a = db(); if not a then return end
    local who = npcName(unit); if not who or info.secret then return end
    local log = HM.db.castLog
    local e = log[who]
    if not e then
        -- sınırsız büyümesin
        local n = 0
        for _ in pairs(log) do n = n + 1 end
        if n > 400 then return end
        e = {}; log[who] = e
    end
    local s = e[info.name] or { n = 0 }
    s.n = s.n + 1
    if info.notInt ~= nil then s.kes = (info.notInt == false) end
    e[info.name] = s
end

function Alerts:PrintCastLog(who)
    local a = db(); if not a then return end
    who = who or npcName("target")
    if not who then HM:Print("Bir hedef seç ya da /hm cast <NPC adı> yaz."); return end
    local e = HM.db.castLog[who]
    if not e then HM:Print(who .. " için kayıtlı büyü yok (henüz büyü atarken görülmedi)."); return end
    HM:Print("|cffffd100" .. who .. "|r büyüleri:")
    local list = {}
    for name, s in pairs(e) do list[#list + 1] = { name = name, s = s } end
    table.sort(list, function(x, y) return x.s.n > y.s.n end)
    for _, it in ipairs(list) do
        local kes = it.s.kes == true and "|cff33ff33KES'lenebilir|r" or (it.s.kes == false and "|cffff5555kesilemez|r" or "?")
        local crit = ns.CriticalCasts[it.name] and (" — " .. ns.CriticalCasts[it.name]) or ""
        HM:Print(string.format("  %s x%d  %s%s", it.name, it.s.n, kes, crit))
    end
end

---------------------------------------------------------------------------
-- Büyü uyarısı
---------------------------------------------------------------------------
local lastSoundAt = 0

local function onCastStart(unit)
    local a = db()
    if not (a and a.enabled) then return end
    if not hostile(unit) then return end
    local info = castInfo(unit)
    if not info then return end
    if not relevant(unit, info) then return end
    logCast(unit, info)

    local key = unitGUID(unit) .. ":" .. tostring(info.start)
    if seenCast[key] then return end
    seenCast[key] = true
    C_Timer.After(30, function() seenCast[key] = nil end)

    local who = npcName(unit) or "Düşman"
    local crit = ns.CriticalCasts[info.name]
    local interruptible = (info.notInt == false)     -- nil (gizli) ise bilinmiyor
    local state, kname, extra = kickState()
    local shown = trName(info.name)

    if interruptible and state ~= "yok" then
        if state == "hazir" then
            Alerts:Show("kes", "KES: " .. shown, who .. (crit and (" — " .. crit) or "") .. "  (" .. kname .. " hazır)", info.tex, 3, key)
            if GetTime() - lastSoundAt > 1.0 then Sound(SOUND_KES); lastSoundAt = GetTime() end
        elseif state == "cd" then
            local sub = string.format("%s — %s %.0f sn sonra", who, kname, extra or 0)
            if crit then sub = sub .. " — " .. crit .. "!" end
            Alerts:Show(crit and "dikkat" or "bilgi", "Kesilebilir: " .. shown, sub, info.tex, 2.5, key)
            if crit and GetTime() - lastSoundAt > 1.5 then Sound(SOUND_DIKKAT); lastSoundAt = GetTime() end
        else -- form/duruş uygun değil
            local sub = who .. " — " .. tostring(extra) .. " → " .. kname
            if crit then sub = sub .. " — " .. crit .. "!" end
            Alerts:Show(crit and "dikkat" or "bilgi", "Kesilebilir: " .. shown, sub, info.tex, 2.5, key)
            if crit and GetTime() - lastSoundAt > 1.5 then Sound(SOUND_DIKKAT); lastSoundAt = GetTime() end
        end
    elseif crit then
        -- kesemiyoruz ama tehlikeli: haber ver
        local sub = who .. " — " .. crit
        if info.notInt == true then sub = sub .. " (kesilemez)" end
        if state == "yok" and info.notInt == false then
            local cls = playerClass()
            local when = (cls == "MAGE" and "Counterspell 24. seviyede") or (cls == "WARRIOR" and "Shield Bash 12 / Pummel 38. seviyede") or (cls == "DRUID" and "ayı formunda Bash") or "kesme yeteneğin yok"
            sub = sub .. " (" .. when .. ")"
        end
        Alerts:Show("dikkat", "DİKKAT: " .. shown, sub, info.tex, 3, key)
        if GetTime() - lastSoundAt > 1.5 then Sound(SOUND_DIKKAT); lastSoundAt = GetTime() end
    end
end

local function onCastStop(unit)
    local key = unitGUID(unit)
    if activeCastKey and activeCastKey:sub(1, #key) == key then Alerts:HideIf(activeCastKey) end
end

---------------------------------------------------------------------------
-- Çalınabilir / dispel edilebilir buff
---------------------------------------------------------------------------
local function scanAuras(unit)
    local a = db()
    if not (a and a.enabled and a.stealable) then return end
    if not UnitExists or not UnitExists(unit) or not hostile(unit) then return end
    local guid = unitGUID(unit)
    local canSteal = known(SPELLSTEAL)
    for i = 1, 40 do
        local aura
        if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
            local ok, d = pcall(C_UnitAuras.GetAuraDataByIndex, unit, i, "HELPFUL")
            if ok and type(d) == "table" then aura = d end
        elseif UnitAura then
            local ok, name, icon, _, _, _, _, _, isStealable, _, spellId = pcall(UnitAura, unit, i, "HELPFUL")
            if ok and name then aura = { name = name, icon = icon, isStealable = isStealable, spellId = spellId, auraInstanceID = spellId } end
        end
        if not aura then break end
        local name = safe(aura.name)
        local stealable = safe(aura.isStealable) == true
        local magic = safe(aura.dispelName) == "Magic"
        local notable = name and ns.NotableBuffs and ns.NotableBuffs[name]
        if name and ((canSteal and stealable) or ((stealable or magic) and notable)) then
            local k = guid .. ":" .. tostring(safe(aura.auraInstanceID) or safe(aura.spellId) or name)
            if not seenAura[k] then
                seenAura[k] = true
                C_Timer.After(60, function() seenAura[k] = nil end)
                local who = npcName(unit) or "Hedef"
                if canSteal and stealable then
                    Alerts:Show("cal", "ÇAL: " .. trName(name), who .. " — Spellsteal ile al", safe(aura.icon), 3, nil)
                    Sound(SOUND_DIKKAT)
                else
                    Alerts:Show("cal", "Hedefte buff: " .. trName(name), who .. " — büyü türü, şifacı/şaman dispel edebilir", safe(aura.icon), 2.5, nil)
                end
            end
        end
    end
end

---------------------------------------------------------------------------
-- Grup arkadaşlarında lanet/zehir/hastalık: ÇÖZ (sınıfın çözme büyüsü varsa)
---------------------------------------------------------------------------
local seenDebuff = {}
local lastCureAt = {}

local function cureFor(dispelName)
    local cures = CURES[playerClass()]
    local c = cures and cures[dispelName]
    if not c then return nil end
    for _, id in ipairs(c.ids) do if known(id) then return c.name end end
    return nil
end

local function scanFriendly(unit)
    local a = db()
    if not (a and a.enabled and a.cure ~= false) then return end
    if not CURES[playerClass()] then return end
    if not UnitExists or not UnitExists(unit) then return end
    if UnitIsDeadOrGhost then
        local ok, dead = pcall(UnitIsDeadOrGhost, unit)
        if ok and safe(dead) then return end
    end
    local now = GetTime()
    if lastCureAt[unit] and now - lastCureAt[unit] < 4 then return end
    local guid = unitGUID(unit)
    for i = 1, 40 do
        local aura
        if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
            local ok, d = pcall(C_UnitAuras.GetAuraDataByIndex, unit, i, "HARMFUL")
            if ok and type(d) == "table" then aura = d end
        elseif UnitAura then
            local ok, name, icon, _, dispelName, _, _, _, _, _, spellId = pcall(UnitAura, unit, i, "HARMFUL")
            if ok and name then aura = { name = name, icon = icon, dispelName = dispelName, spellId = spellId, auraInstanceID = spellId } end
        end
        if not aura then break end
        local name, dn = safe(aura.name), safe(aura.dispelName)
        local cure = dn and cureFor(dn)
        if name and cure then
            local k = guid .. ":" .. tostring(safe(aura.auraInstanceID) or safe(aura.spellId) or name)
            if not seenDebuff[k] then
                seenDebuff[k] = true
                C_Timer.After(20, function() seenDebuff[k] = nil end)
                lastCureAt[unit] = now
                local who = (unit == "player") and "sende" or ((npcName(unit) or unit) .. "'de")
                local kind = (dn == "Curse" and "lanet") or (dn == "Poison" and "zehir") or (dn == "Disease" and "hastalık") or "büyü"
                Alerts:Show("cal", "ÇÖZ: " .. trName(name), string.format("%s %s var → %s", who, kind, cure), safe(aura.icon), 3, nil)
                Sound(SOUND_DIKKAT)
                return
            end
        end
    end
end

---------------------------------------------------------------------------
-- Patron notları
---------------------------------------------------------------------------
local function shortName(full)
    return (full or ""):gsub("^The ", "")
end

function Alerts:PrintNotes(which)
    local notes, title
    if which and which ~= "" then
        local q = which:lower()
        for name, t in pairs(ns.DungeonNotes) do
            if name:lower():find(q, 1, true) then notes, title = t, name break end
        end
        if not notes then HM:Print("Zindan bulunamadı: " .. which .. ". Örnek: /hm notlar wailing"); return end
    else
        title = instanceName()
        notes = title and ns.DungeonNotes[title]
        if not notes then
            HM:Print("Zindanda değilsin ya da bu zindan için not yok. /hm notlar <ad> ile bak (ör. /hm notlar zul).")
            local names = {}
            for name, t in pairs(ns.DungeonNotes) do names[#names + 1] = name .. " (" .. t.lvl .. ")" end
            table.sort(names)
            HM:Print("Notu olanlar: " .. table.concat(names, ", "))
            return
        end
    end
    HM:Print("|cffffd100" .. shortName(title) .. " (" .. (notes.lvl or "") .. ")|r patron notları:")
    local list = {}
    for boss, note in pairs(notes) do if boss ~= "lvl" then list[#list + 1] = boss end end
    table.sort(list)
    for _, boss in ipairs(list) do HM:Print("  |cff33ccff" .. boss .. "|r: " .. ns.ExpandNote(notes[boss], playerClass())) end
end

-- Elit / nadir / dünya patronu hedef: hedef alır almaz uyar (aynı mob için bir kez).
local CLASS_TR = { elite = "ELİT", rareelite = "NADİR ELİT", rare = "NADİR", worldboss = "DÜNYA PATRONU" }
local lastEliteGUID
local function eliteCheck()
    if not (UnitClassification and UnitExists and UnitExists("target")) then return end
    if UnitIsPlayer and UnitIsPlayer("target") then return end
    if not hostile("target") then return end
    local ok, cls = pcall(UnitClassification, "target")
    cls = ok and safe(cls) or nil
    local label = cls and CLASS_TR[cls]
    if not label then return end
    local guid = unitGUID("target")
    if guid == lastEliteGUID then return end
    lastEliteGUID = guid
    local who = npcName("target") or "?"
    local lvl = UnitLevel and safe(UnitLevel("target"))
    local lvlText = (type(lvl) == "number") and (lvl > 0 and ("seviye " .. lvl) or "seviye ??") or ""
    local mine = HM:Level()
    local warn = ""
    if type(lvl) == "number" and lvl > 0 and lvl >= mine then warn = " — tek başına zor, dikkat" elseif lvl == -1 then warn = " — kafatası seviyesi, kaç" end
    Alerts:Show("dikkat", label .. ": " .. who, (lvlText ~= "" and (lvlText .. " ") or "") .. (cls == "elite" and "elit mob: normalin 2-3 katı can ve hasar" or cls == "rare" and "nadir mob: iyi ganimet, daha güçlü" or "çok güçlü") .. warn, nil, 5, "elite")
    Sound(SOUND_DIKKAT)
end

local function onTargetChanged()
    local a = db(); if not a then return end
    seenAura = {}
    if a.enabled then
        scanAuras("target")
        pcall(eliteCheck)
    end
    if not a.notes then return end
    local who = npcName("target")
    if not who or shownBoss[who] then return end
    local inst = instanceName()
    local notes = inst and ns.DungeonNotes[inst]
    local note = notes and notes[who]
    if not note then
        -- zindan dışında da patron adıyla eşleşirse göster (ör. harita adı farklı)
        for _, t in pairs(ns.DungeonNotes) do if t[who] then note = t[who] break end end
    end
    if note then
        shownBoss[who] = true
        note = ns.ExpandNote(note, playerClass())
        Alerts:Show("boss", "PATRON: " .. who, note, nil, 7, nil)
        Sound(SOUND_BOSS)
        HM:Print("|cffffd100" .. who .. "|r: " .. note)
    end
end

local function onEnterWorld()
    local a = db(); if not a then return end
    local inst = instanceName()
    if inst and inst ~= lastInstance and a.notes then
        lastInstance = inst
        local notes = ns.DungeonNotes[inst]
        if notes then
            local n = 0
            for boss in pairs(notes) do if boss ~= "lvl" then n = n + 1 end end
            HM:Print(string.format("%s: %d patron notu var. Patronu hedef alınca uyarı çıkar; tamamı için /hm notlar", shortName(inst), n))
        else
            HM:Print(shortName(inst) .. ": bu zindan için hazır not yok; gördüğüm büyüleri öğreniyorum (/hm cast).")
        end
        local st, kname = kickState()
        if st == "yok" then
            HM:Print("Kesme yeteneğin henüz yok; kesilebilir tehlikeli büyüler DİKKAT olarak gösterilir.")
        else
            HM:Print("Kesme: " .. tostring(kname) .. " — kesilebilir büyüde KES uyarısı verilir.")
        end
    elseif not inst then
        lastInstance = nil
    end
end

---------------------------------------------------------------------------
-- Komutlar
---------------------------------------------------------------------------
function Alerts:Command(arg)
    local a = db(); if not a then return end
    arg = (arg or ""):lower()
    if arg == "kapat" then a.enabled = false; HM:Print("Zindan uyarıları kapatıldı.")
    elseif arg == "ac" or arg == "aç" then a.enabled = true; HM:Print("Zindan uyarıları açık.")
    elseif arg == "ses" then a.sound = not a.sound; HM:Print("Uyarı sesi: " .. (a.sound and "açık" or "kapalı"))
    elseif arg == "plaka" then a.nameplates = not a.nameplates; HM:Print("İsim plakası büyüleri: " .. (a.nameplates and "açık" or "kapalı"))
    elseif arg == "buff" then a.stealable = not a.stealable; HM:Print("Çalınabilir buff uyarısı: " .. (a.stealable and "açık" or "kapalı"))
    elseif arg == "not" then a.notes = not a.notes; HM:Print("Patron notları: " .. (a.notes and "açık" or "kapalı"))
    elseif arg == "coz" or arg == "çöz" then a.cure = (a.cure == false); HM:Print("Lanet/zehir çözme uyarısı: " .. (a.cure ~= false and "açık" or "kapalı"))
    elseif arg == "test" then
        local st, kname = kickState()
        local kn = (st ~= "yok" and kname) or (KICKS[playerClass()] and KICKS[playerClass()][1].name) or "kesme"
        Alerts:Show("kes", "KES: " .. trName("Healing Touch"), "Lord Pythas — iyileştirme  (" .. kn .. " hazır)", 136041, 3, nil)
        Sound(SOUND_KES)
        C_Timer.After(3.2, function() Alerts:Show("cal", "ÇÖZ: " .. trName("Curse of Weakness"), "sende lanet var → " .. ((CURES[playerClass()] and CURES[playerClass()].Curse and CURES[playerClass()].Curse.name) or "şifacı/mage"), 136138, 3, nil) end)
        C_Timer.After(6.4, function() Alerts:Show("boss", "PATRON: Lady Anacondra", ns.ExpandNote(ns.DungeonNotes["Wailing Caverns"]["Lady Anacondra"], playerClass()), nil, 6, nil) end)
    else
        local st, kname, extra = kickState()
        local ks = (st == "yok" and "yok") or (st == "hazir" and (kname .. " hazır")) or (st == "cd" and string.format("%s %.0f sn", kname, extra or 0)) or (kname .. ": " .. tostring(extra))
        HM:Print(string.format("Zindan uyarıları: %s | ses %s | plaka %s | buff %s | notlar %s | çöz %s | kesme: %s",
            a.enabled and "açık" or "kapalı", a.sound and "açık" or "kapalı", a.nameplates and "açık" or "kapalı",
            a.stealable and "açık" or "kapalı", a.notes and "açık" or "kapalı", a.cure ~= false and "açık" or "kapalı", ks))
        HM:Print("Kullanım: /hm uyari ac|kapat|ses|plaka|buff|not|coz|test   /hm notlar [zindan]   /hm cast [NPC]")
    end
end

---------------------------------------------------------------------------
-- Olaylar
---------------------------------------------------------------------------
HM:On("UNIT_SPELLCAST_START", function(_, unit) if type(unit) == "string" then onCastStart(unit) end end)
HM:On("UNIT_SPELLCAST_CHANNEL_START", function(_, unit) if type(unit) == "string" then onCastStart(unit) end end)
HM:On("UNIT_SPELLCAST_STOP", function(_, unit) if type(unit) == "string" then onCastStop(unit) end end)
HM:On("UNIT_SPELLCAST_INTERRUPTED", function(_, unit) if type(unit) == "string" then onCastStop(unit) end end)
HM:On("UNIT_SPELLCAST_CHANNEL_STOP", function(_, unit) if type(unit) == "string" then onCastStop(unit) end end)
HM:On("PLAYER_TARGET_CHANGED", onTargetChanged)
HM:On("UNIT_AURA", function(_, unit)
    if unit == "target" then scanAuras("target")
    elseif unit == "player" or (type(unit) == "string" and unit:match("^party%d$")) then scanFriendly(unit) end
end)
HM:On("GROUP_ROSTER_UPDATE", function() seenDebuff = {} end)
HM:On("PLAYER_ENTERING_WORLD", function() C_Timer.After(3, onEnterWorld) end)
HM:On("ZONE_CHANGED_NEW_AREA", function() C_Timer.After(2, onEnterWorld) end)
