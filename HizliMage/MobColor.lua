---------------------------------------------------------------------------
-- MobColor.lua: hedef aldığın düşmanın seviyesine göre tek satır uyarı.
--   Gri  → XP vermez, boşuna kesme
--   Turuncu (+3/+4) → zorlu      Kırmızı (+5 ve üstü) → tehlikeli
--   Kafatası (seviye gizli) → kaç
-- Dost NPC, oyuncu, evcil hayvan ve ölüler için konuşmaz; aynı mob için 20 sn
-- içinde tekrar etmez. Zindan/raid içinde susar. /hm renk ile aç/kapat.
---------------------------------------------------------------------------
local _, ns = ...
local HM = ns.HM
if not HM then return end

local MobColor = {}
HM.MobColor = MobColor

local seen = {}          -- guid -> son uyarı zamanı
local THROTTLE = 20

-- XP vermeyen (gri) en yüksek mob seviyesi; Classic formülü.
local function grayLevel(pLvl)
    if pLvl <= 5 then return 0
    elseif pLvl <= 49 then return pLvl - math.floor(pLvl / 10) - 5
    elseif pLvl == 50 then return 40
    elseif pLvl <= 59 then return pLvl - math.floor(pLvl / 5) - 1
    else return pLvl - 9 end
end
MobColor.GrayLevel = grayLevel

local function isTrivial(unit, pLvl, tLvl)
    if UnitIsTrivial then
        local ok, t = pcall(UnitIsTrivial, unit)
        if ok and type(t) == "boolean" then return t end
    end
    return tLvl > 0 and tLvl <= grayLevel(pLvl)
end

function MobColor:Check()
    if HM.inInstance then return end
    if not (UnitExists and UnitExists("target")) then return end
    if UnitIsPlayer and UnitIsPlayer("target") then return end
    if UnitPlayerControlled and UnitPlayerControlled("target") then return end
    if UnitIsDead and UnitIsDead("target") then return end
    if UnitCanAttack and not UnitCanAttack("player", "target") then return end
    local guid = UnitGUID and UnitGUID("target")
    if not guid or HM.IsSecret(guid) then return end
    local now = GetTime()
    if seen[guid] and (now - seen[guid]) < THROTTLE then return end
    seen[guid] = now

    local pLvl = UnitLevel("player") or 1
    local tLvl = UnitLevel("target") or 0
    if HM.IsSecret(tLvl) or type(tLvl) ~= "number" then return end
    local name = UnitName("target") or "mob"
    local class = UnitClassification and UnitClassification("target") or "normal"
    local elite = (class == "elite" or class == "rareelite" or class == "worldboss")
    local tag = elite and " |cffffd100(elit)|r" or ""

    if tLvl == -1 then
        if PlaySound then pcall(PlaySound, (SOUNDKIT and SOUNDKIT.RAID_WARNING) or 8959) end
        HM:Print(string.format("|cffff4040Kafatası:|r %s%s — seviyesi senden en az 10 yüksek, uzak dur.", name, tag))
        return
    end
    local diff = tLvl - pLvl
    if isTrivial("target", pLvl, tLvl) then
        HM:Print(string.format("|cff888888Gri:|r %s (seviye %d)%s — XP vermez, kesme.", name, tLvl, tag))
    elseif diff >= 5 then
        HM:Print(string.format("|cffff4040Kırmızı:|r %s (seviye %d, +%d)%s — tehlikeli.", name, tLvl, diff, tag))
    elseif diff >= 3 then
        HM:Print(string.format("|cffff8040Turuncu:|r %s (seviye %d, +%d)%s — zorlu, cooldown'lar hazır olsun.", name, tLvl, diff, tag))
    elseif elite and diff >= -2 then
        HM:Print(string.format("|cffffd100Elit:|r %s (seviye %d) — tek başına riskli.", name, tLvl))
    end
end

function MobColor:Set(on, quiet)
    HM.db.mobColorOff = not on
    if not quiet then
        HM:Print("Mob seviye uyarısı: " .. (HM.db.mobColorOff and "|cffff6060kapalı|r" or "|cff80ff80açık|r"))
    end
end

function MobColor:Toggle()
    self:Set(HM.db.mobColorOff and true or false)
end

HM:OnLogin(function()
    HM.db.mobColorOff = HM.db.mobColorOff == true
    HM:On("PLAYER_TARGET_CHANGED", function()
        if HM.db.mobColorOff then return end
        MobColor:Check()
    end)
    -- uyarı tablosu büyümesin
    HM:Ticker(120, function()
        local now = GetTime()
        for g, t in pairs(seen) do if now - t > THROTTLE then seen[g] = nil end end
    end, "mob rengi")
end)
