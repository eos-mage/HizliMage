-- Otomatik buff isteme: eksik buff varsa yakındaki Priest/Druid/Paladin'a kibarca whisper atar.
-- Savaş dışında, throttle'lı (aynı kişiye 5 dk'da bir), güzel bir dille.
-- /hm buff (durum), /hm buff oto (aç/kapat), /hm buff sessiz (whisper kapatmadan kontrol et)

local ADDON, ns = ...
local HM = ns.HM
local BuffReq = {}
HM.BuffReq = BuffReq

local function safe(v) if HM.IsSecret(v) then return nil end return v end
local OK, BAD, WARN = "|cff80ff80+|r ", "|cffff6060x|r ", "|cffffd100!|r "

---------------------------------------------------------------------------
-- Hangi sınıf hangi buff verir
---------------------------------------------------------------------------
-- Buff verebilecek sınıflar ve mesajlar (İngilizce)
local BUFF_PROVIDERS = {
    PRIEST = {
        { buff = "Power Word: Fortitude", short = "Fort", minLevel = 1,
          request = "Hi! Could you please buff me with Fort? Would really appreciate it :)" },
        { buff = "Divine Spirit", short = "Spirit", minLevel = 30,
          request = "Hey! Mind giving me Spirit buff please? Thanks a lot :)" },
        { buff = "Shadow Protection", short = "Shadow Prot", minLevel = 30,
          request = "Hi! Shadow Protection would be great if you don't mind :) ty!" },
    },
    DRUID = {
        { buff = "Mark of the Wild", short = "MotW", minLevel = 1,
          request = "Hi! Could you please give me Mark of the Wild? Thanks :)" },
        { buff = "Thorns", short = "Thorns", minLevel = 6,
          request = "Hey! Mind buffing me with Thorns please? ty :)" },
    },
    PALADIN = {
        { buff = "Blessing of Might", short = "Might", minLevel = 4,
          request = "Hi! Could you please give me a Blessing? Might or Kings would be great :)" },
        { buff = "Blessing of Kings", short = "Kings", minLevel = 20,
          request = "Hi! Blessing of Kings please? Would appreciate it :)" },
        { buff = "Blessing of Wisdom", short = "Wisdom", minLevel = 14,
          request = "Hey! Blessing of Wisdom would be awesome for my mana :) ty!" },
    },
    MAGE = {
        { buff = "Arcane Intellect", short = "AI", minLevel = 1,
          request = "Hi fellow mage! Could you buff me with AI please? :)" },
    },
    WARLOCK = {
        { buff = "Healthstone", short = "Healthstone", minLevel = 10,
          request = "Hey! Could I get a Healthstone please? Thanks :)" },
    },
}

-- Her sınıfın hangi dış buff'lara ihtiyacı var + Paladin Blessing öncelik sırası
-- Classic kuralı: bir Paladin = bir Blessing; 2 Paladin = 2 farklı Blessing alabilirsin
-- Mage: Fort, Spirit, MotW, Thorns + Blessings (Wisdom > Kings > Might)
-- Druid: Fort, Spirit, AI, Thorns yok (kendinde var) + Blessings (Kings > Might > Wisdom)
-- Warrior: Fort, MotW, AI + Blessings (Might > Kings > Wisdom)
-- myMin = senin karakterin bu buff'u almak için gereken minimum level
-- Düşük levelde gereksiz buff istenmez
local CLASS_NEEDS = {
    MAGE = {
        { provider = "PRIEST",  buff = "Power Word: Fortitude", myMin = 1 },
        { provider = "PRIEST",  buff = "Divine Spirit",         myMin = 20 },
        { provider = "PRIEST",  buff = "Shadow Protection",     myMin = 25 },
        { provider = "DRUID",   buff = "Mark of the Wild",      myMin = 1 },
        { provider = "DRUID",   buff = "Thorns",                myMin = 1 },
    },
    DRUID = {
        { provider = "PRIEST",  buff = "Power Word: Fortitude", myMin = 1 },
        { provider = "PRIEST",  buff = "Divine Spirit",         myMin = 20 },
        { provider = "PRIEST",  buff = "Shadow Protection",     myMin = 25 },
        { provider = "MAGE",    buff = "Arcane Intellect",      myMin = 1 },
        { provider = "DRUID",   buff = "Mark of the Wild",      myMin = 1 },
    },
    WARRIOR = {
        { provider = "PRIEST",  buff = "Power Word: Fortitude", myMin = 1 },
        { provider = "PRIEST",  buff = "Shadow Protection",     myMin = 25 },
        { provider = "DRUID",   buff = "Mark of the Wild",      myMin = 1 },
        { provider = "DRUID",   buff = "Thorns",                myMin = 1 },
        { provider = "MAGE",    buff = "Arcane Intellect",      myMin = 1 },
    },
}

-- Paladin Blessing öncelik sırası + minimum karakter seviyesi
-- myMin: bu blessing'i istemek için senin gereken minimum levelin
local BLESSING_PRIORITY = {
    MAGE    = { {b="Blessing of Wisdom", myMin=10}, {b="Blessing of Kings", myMin=20}, {b="Blessing of Might", myMin=10} },
    DRUID   = { {b="Blessing of Kings", myMin=20}, {b="Blessing of Might", myMin=10}, {b="Blessing of Wisdom", myMin=10} },
    WARRIOR = { {b="Blessing of Might", myMin=10}, {b="Blessing of Kings", myMin=20}, {b="Blessing of Wisdom", myMin=10} },
}

-- Buff ailesi: biri varsa diğerini isteme (group/greater sürümleri dahil)
local BUFF_FAMILY = {
    ["Power Word: Fortitude"] = { "Power Word: Fortitude", "Prayer of Fortitude" },
    ["Divine Spirit"] = { "Divine Spirit", "Prayer of Spirit" },
    ["Shadow Protection"] = { "Shadow Protection", "Prayer of Shadow Protection" },
    ["Mark of the Wild"] = { "Mark of the Wild", "Gift of the Wild" },
    ["Thorns"] = { "Thorns" },
    ["Blessing of Might"] = { "Blessing of Might", "Greater Blessing of Might" },
    ["Blessing of Kings"] = { "Blessing of Kings", "Greater Blessing of Kings" },
    ["Blessing of Wisdom"] = { "Blessing of Wisdom", "Greater Blessing of Wisdom" },
    ["Arcane Intellect"] = { "Arcane Intellect", "Arcane Brilliance" },
    ["Healthstone"] = {},  -- item, buff yok — çantada var mı diye kontrol edilir
}

-- Blessing: herhangi biri varsa diğerini isteme (tek slot)
local BLESSING_FAMILY = { "Blessing of Might", "Blessing of Kings", "Blessing of Wisdom",
    "Greater Blessing of Might", "Greater Blessing of Kings", "Greater Blessing of Wisdom" }

---------------------------------------------------------------------------
-- Buff kontrol
---------------------------------------------------------------------------
local function hasBuff(buffName)
    local family = BUFF_FAMILY[buffName] or { buffName }
    for i = 1, 40 do
        local name
        if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
            local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, "player", i, "HELPFUL")
            if not ok or not aura then break end
            name = safe(aura.name)
        elseif UnitBuff then
            local ok, n = pcall(UnitBuff, "player", i)
            if not ok or not n then break end
            name = safe(n)
        else break end
        if name then
            for _, fn in ipairs(family) do
                if name == fn then return true end
            end
        end
    end
    return false
end

-- Aktif Blessing'leri say
local function activeBlessings()
    local count = 0
    local active = {}
    for _, bName in ipairs(BLESSING_FAMILY) do
        if hasBuff(bName) then
            count = count + 1
            active[bName] = true
            -- Greater ve normal aynı sayılsın
            local base = bName:gsub("Greater ", "")
            active[base] = true
        end
    end
    return count, active
end

-- Bu karakterin eksik dış buff'ları (normal buff + akıllı Blessing mantığı)
local function missingExternalBuffs()
    local myClass = ns.class or select(2, UnitClass("player"))
    local needs = CLASS_NEEDS[myClass]
    if not needs then return {} end

    local myLevel = UnitLevel("player") or 1
    local missing = {}

    -- 1) Normal buff'lar (Priest, Druid, Mage) — kendi levelin yetiyorsa iste
    for _, need in ipairs(needs) do
        if myLevel >= (need.myMin or 1) and not hasBuff(need.buff) then
            local provBuffs = BUFF_PROVIDERS[need.provider]
            if provBuffs then
                for _, pb in ipairs(provBuffs) do
                    if pb.buff == need.buff then
                        missing[#missing + 1] = { class = need.provider, buff = pb.buff, short = pb.short, request = pb.request, minLevel = pb.minLevel or 1 }
                        break
                    end
                end
            end
        end
    end

    -- 2) Paladin Blessing'ler — kendi levelin yetiyorsa iste
    local blessingCount, activeB = activeBlessings()
    local priority = BLESSING_PRIORITY[myClass] or BLESSING_PRIORITY.MAGE
    for _, entry in ipairs(priority) do
        local bName = entry.b or entry
        local bMyMin = entry.myMin or 1
        if myLevel >= bMyMin and not activeB[bName] then
            local provBuffs = BUFF_PROVIDERS.PALADIN
            if provBuffs then
                for _, pb in ipairs(provBuffs) do
                    if pb.buff == bName then
                        missing[#missing + 1] = { class = "PALADIN", buff = pb.buff, short = pb.short, request = pb.request, minLevel = pb.minLevel or 1 }
                        break
                    end
                end
            end
        end
    end

    return missing
end

---------------------------------------------------------------------------
-- Yakındaki oyuncuları tara (nameplates veya party/raid)
---------------------------------------------------------------------------
-- AFK kara liste: AFK yanıtı gelen kişilere bir daha istek atma (oturum boyunca)
local afkBlacklist = {}  -- [name] = true

local function isUnitAFK(unit)
    if not unit then return false end
    if UnitIsAFK and UnitIsAFK(unit) then return true end
    return false
end

local function nearbyPlayers()
    local found = {}
    -- 1) Party/raid üyeleri
    local prefix, count = "party", GetNumGroupMembers and (GetNumGroupMembers() - 1) or 0
    if IsInRaid and IsInRaid() then prefix = "raid"; count = GetNumGroupMembers() or 0 end
    for i = 1, count do
        local unit = prefix .. i
        if UnitExists(unit) and UnitIsPlayer(unit) and not UnitIsUnit(unit, "player") then
            local name = safe(GetUnitName(unit, true))
            local _, cls = UnitClass(unit)
            if name and cls and not UnitIsDeadOrGhost(unit) and not isUnitAFK(unit) and not afkBlacklist[name] then
                local canSee = CheckInteractDistance and CheckInteractDistance(unit, 2) -- ~20 yd (trade range)
                if canSee then
                    local lvl = UnitLevel(unit) or 0
                    found[#found + 1] = { name = name, class = cls, unit = unit, level = lvl }
                end
            end
        end
    end
    -- 2) Nameplate tarama (yakındaki oyuncular, partide olmasa bile)
    if C_NamePlate and C_NamePlate.GetNamePlates then
        local plates = C_NamePlate.GetNamePlates()
        if plates then
            for _, plate in ipairs(plates) do
                local unit = plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.unit)
                if unit and UnitExists(unit) and UnitIsPlayer(unit) and not UnitIsUnit(unit, "player")
                   and UnitIsFriend("player", unit) and not UnitIsDeadOrGhost(unit)
                   and not isUnitAFK(unit) then
                    local name = safe(GetUnitName(unit, true))
                    local _, cls = UnitClass(unit)
                    if name and cls and not afkBlacklist[name] then
                        local dup = false
                        for _, f in ipairs(found) do if f.name == name then dup = true; break end end
                        if not dup then
                            local lvl = UnitLevel(unit) or 0
                            found[#found + 1] = { name = name, class = cls, unit = unit, level = lvl }
                        end
                    end
                end
            end
        end
    end
    return found
end

---------------------------------------------------------------------------
-- AFK otomatik yanıtı yakala: "<AFK>" içeren whisper gelince kara listeye al
---------------------------------------------------------------------------
HM:On("CHAT_MSG_SYSTEM", function(_, msg)
    -- WoW AFK yanıtı: "Player is Away From Keyboard: AFK message"
    if not msg then return end
    local name = msg:match("^(%S+) is Away From Keyboard")
    if name then
        afkBlacklist[name] = true
    end
end)

-- AFK auto-reply whisper'ı da yakala
HM:On("CHAT_MSG_AFK", function(_, msg, sender)
    if sender then
        local clean = sender:match("^([^-]+)") or sender
        afkBlacklist[clean] = true
    end
end)

-- Gelen whisper: biri sana yazdıysa ona tekrar buff isteği atma (yanıt vermiş demek)
-- Oturum boyunca o kişiye bir daha otomatik mesaj gitmez
local repliedPlayers = {}  -- [name] = true

HM:On("CHAT_MSG_WHISPER", function(_, msg, sender)
    if sender then
        local clean = sender:match("^([^-]+)") or sender
        repliedPlayers[clean] = true
    end
end)

-- Mesaj gönderilmiş kişiler: bir kişiye oturumda sadece 1 kez buff isteği gider
local contactedPlayers = {}  -- [name] = true

---------------------------------------------------------------------------
-- Whisper throttle: aynı kişiye aynı buff için 5 dk'da bir
---------------------------------------------------------------------------
local whisperLog = {}  -- [name..buff] = GetTime()
local WHISPER_COOLDOWN = 300  -- 5 dakika

local function canWhisper(playerName, buffShort)
    -- AFK kara listesinde mi
    if afkBlacklist[playerName] then return false end
    -- Bize whisper yazmış mı (yanıt vermiş = tekrar rahatsız etme)
    if repliedPlayers[playerName] then return false end
    -- Bu oturumda zaten mesaj attık mı (aynı kişiye bir kez yeter)
    if contactedPlayers[playerName] then return false end
    -- Throttle: aynı kişiye aynı buff 5 dk'da bir (yedek kontrol)
    local key = playerName .. ":" .. buffShort
    local last = whisperLog[key]
    if last and (GetTime() - last) < WHISPER_COOLDOWN then return false end
    return true
end

local function markWhispered(playerName, buffShort)
    whisperLog[playerName .. ":" .. buffShort] = GetTime()
    contactedPlayers[playerName] = true  -- oturumda bir kez yeter
end

---------------------------------------------------------------------------
-- Whisper gönder
---------------------------------------------------------------------------
local function sendWhisper(playerName, message)
    if not SendChatMessage then return false end
    local ok = pcall(SendChatMessage, message, "WHISPER", nil, playerName)
    return ok
end

---------------------------------------------------------------------------
-- Ana tarama: eksik buff varsa yakındaki uygun sınıfa whisper at
---------------------------------------------------------------------------
local lastScan = 0
local SCAN_INTERVAL = 120  -- 2 dakikada bir tara

function BuffReq:Scan(verbose)
    if HM:InCombat() then return end
    -- Uçarken buff isteme, durduğumuzda yaparız
    if UnitOnTaxi and UnitOnTaxi("player") then return end
    if IsFlying and IsFlying() then return end
    local level = HM:Level()
    if level < 5 then return end  -- çok düşük seviyede buff pek yok

    local db = HM.db
    if not db then return end
    if db.buffRequestOff and not verbose then return end

    local missing = missingExternalBuffs()
    if #missing == 0 then
        if verbose then HM:Print(OK .. "Tum dis buff'lar mevcut!") end
        return
    end

    local nearby = nearbyPlayers()
    if #nearby == 0 then
        if verbose then
            HM:Print(WARN .. "Eksik buff'lar: ")
            for _, m in ipairs(missing) do
                HM:Print("  " .. BAD .. m.short .. " (" .. m.class .. ")")
            end
            HM:Print("  Yakininda uygun sinif yok.")
        end
        return
    end

    -- Eşleştir: eksik buff → yakındaki uygun sınıf
    -- Paladin kuralı: bir Paladin'dan sadece bir Blessing iste
    local sent = 0
    local paladinUsed = {}  -- [paladinName] = true (bu Paladin'a zaten bir Blessing istendi)
    for _, m in ipairs(missing) do
        for _, p in ipairs(nearby) do
            if p.class == m.class and (p.level >= (m.minLevel or 1)) and canWhisper(p.name, m.short) then
                -- Paladin ise: bu Paladin'a zaten istek gitti mi?
                if m.class == "PALADIN" and paladinUsed[p.name] then
                    -- atla, sonraki Paladin'ı dene
                else
                    if not db.buffRequestOff then
                        local ok = sendWhisper(p.name, m.request)
                        if ok then
                            markWhispered(p.name, m.short)
                            if m.class == "PALADIN" then paladinUsed[p.name] = true end
                            HM:Print(string.format("|cff9933ff[Buff]|r %s → |cffffd100%s|r (%s)",
                                m.short, p.name, m.class))
                            sent = sent + 1
                        end
                    else
                        if verbose then
                            HM:Print(string.format("  %s%s|r isteyebilirsin: |cffffd100%s|r (%s) yakininda",
                                WARN, m.short, p.name, m.class))
                        end
                    end
                    break  -- bu buff için bir kişiye yeter
                end
            end
        end
    end

    if verbose and sent == 0 then
        HM:Print(WARN .. "Eksik buff var ama uygun sinif yakininda yok veya son 5 dk icinde zaten istendi.")
    end
end

---------------------------------------------------------------------------
-- Durum raporu: /hm buff
---------------------------------------------------------------------------
function BuffReq:Status()
    HM:Print("|cff33ccff— Buff durumu —|r")

    -- Kendi buff'ları
    local cd = ns.CD or (ns.ClassData and ns.ClassData[ns.class])
    if cd and cd.buffs then
        for _, b in ipairs(cd.buffs) do
            local names = {}
            for _, id in ipairs(b.ids) do
                local n = HM:SpellName(id)
                if n then names[n] = true end
            end
            local has = false
            for i = 1, 40 do
                local name
                if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
                    local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, "player", i, "HELPFUL")
                    if not ok or not aura then break end
                    name = safe(aura.name)
                elseif UnitBuff then
                    name = UnitBuff("player", i)
                    if not name then break end
                end
                if name and names[name] then has = true; break end
            end
            HM:Print((has and OK or BAD) .. b.n .. (has and " var" or " YOK — kendin bas!"))
        end
    end

    -- Dış buff'lar (sınıfa göre)
    local myClass = ns.class or select(2, UnitClass("player"))
    local needs = CLASS_NEEDS[myClass] or {}
    for _, need in ipairs(needs) do
        local has = hasBuff(need.buff)
        local provBuffs = BUFF_PROVIDERS[need.provider] or {}
        local short = need.buff
        for _, pb in ipairs(provBuffs) do if pb.buff == need.buff then short = pb.short; break end end
        HM:Print((has and OK or WARN) .. short .. " (" .. need.buff .. ")" .. (has and " var" or " yok — " .. need.provider))
    end
    -- Paladin Blessing'ler
    local _, activeB = activeBlessings()
    local priority = BLESSING_PRIORITY[myClass] or BLESSING_PRIORITY.MAGE
    for _, entry in ipairs(priority) do
        local bName = entry.b or entry
        local has = activeB[bName]
        HM:Print((has and OK or WARN) .. bName .. (has and " var" or " yok — PALADIN (her Paladin bir tane verebilir)"))
    end

    local db = HM.db
    HM:Print("Otomatik buff isteme: " .. (db.buffRequestOff and "kapali" or "acik") .. " (/hm buff oto)")
end

---------------------------------------------------------------------------
-- Periyodik tarama
---------------------------------------------------------------------------
HM:OnLogin(function()
    -- Her 30 saniyede bir tarama
    local function loop()
        if not HM:InCombat() then
            pcall(BuffReq.Scan, BuffReq, false)
        end
        C_Timer.After(SCAN_INTERVAL, loop)
    end
    C_Timer.After(20, loop)
end)

-- Savaş bitince de kontrol et (buff süresi dolmuş olabilir)
HM:On("PLAYER_REGEN_ENABLED", function()
    C_Timer.After(5, function()
        if not HM:InCombat() then pcall(BuffReq.Scan, BuffReq, false) end
    end)
end)

---------------------------------------------------------------------------
-- Buff atana teşekkür: UNIT_AURA ile algıla, savaş dışında whisper at
---------------------------------------------------------------------------
local THANK_MESSAGES = {
    "Thanks for the %s! Really appreciate it :)",
    "Thank you for %s! You're awesome :)",
    "Ty for %s! <3",
    "Thanks for the %s buff! :)",
}

local TRACKED_BUFF_NAMES = {}
for _, provClass in pairs(BUFF_PROVIDERS) do
    for _, b in ipairs(provClass) do
        TRACKED_BUFF_NAMES[b.buff] = b.short
        local family = BUFF_FAMILY[b.buff]
        if family then
            for _, fn in ipairs(family) do
                TRACKED_BUFF_NAMES[fn] = b.short
            end
        end
    end
end

local thankedPlayers = {}
local THANK_COOLDOWN = 60
local knownBuffs = {}  -- [buffName] = true → önceden var olan buff'lar

-- Giriş sonrası mevcut buff'ları kaydet (bunlara teşekkür etmeyiz)
local function snapshotBuffs()
    knownBuffs = {}
    for i = 1, 40 do
        local name
        if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
            local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, "player", i, "HELPFUL")
            if not ok or not aura then break end
            name = safe(aura.name)
        elseif UnitBuff then
            local ok, n = pcall(UnitBuff, "player", i)
            if not ok or not n then break end
            name = safe(n)
        else break end
        if name and TRACKED_BUFF_NAMES[name] then
            knownBuffs[name] = true
        end
    end
end

HM:OnLogin(function()
    C_Timer.After(3, snapshotBuffs)
end)

-- Yeni buff algılandığında teşekkür et (UNIT_AURA ile, CLEU'dan daha güvenli)
HM:On("UNIT_AURA", function(_, unit)
    if unit ~= "player" then return end
    if HM:InCombat() then return end
    if HM.db and HM.db.buffRequestOff then return end

    pcall(function()
        for i = 1, 40 do
            local name, source
            if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
                local aura = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
                if not aura then break end
                name = safe(aura.name)
                source = aura.sourceUnit
            elseif UnitBuff then
                local results = { pcall(UnitBuff, "player", i) }
                if not results[1] or not results[2] then break end
                name = safe(results[2])
                source = results[17] or nil  -- 16th return = caster unit
            else break end

            if name and TRACKED_BUFF_NAMES[name] and not knownBuffs[name] then
                knownBuffs[name] = true  -- artık biliyoruz
                -- source varsa ve başka bir oyuncuysa teşekkür et
                if source and pcall(UnitExists, source) and UnitExists(source)
                   and UnitIsPlayer(source) and not UnitIsUnit(source, "player") then
                    local srcOk, srcName = pcall(GetUnitName, source, true)
                    srcName = srcOk and safe(srcName)
                    if srcName then
                        local clean = srcName:match("^([^-]+)") or srcName
                        local last = thankedPlayers[clean]
                        if not last or (GetTime() - last) >= THANK_COOLDOWN then
                            local short = TRACKED_BUFF_NAMES[name]
                            local msg = string.format(THANK_MESSAGES[math.random(#THANK_MESSAGES)], short)
                            C_Timer.After(1.5, function()
                                if SendChatMessage and not HM:InCombat() then
                                    pcall(SendChatMessage, msg, "WHISPER", nil, clean)
                                    thankedPlayers[clean] = GetTime()
                                    repliedPlayers[clean] = true
                                    HM:Print(string.format("|cff66ff66[Buff]|r %s'a tesekkur edildi (%s)", clean, short))
                                end
                            end)
                        end
                    end
                end
            end
        end
    end)
end)

---------------------------------------------------------------------------
-- Komut: /hm buff [on|off|oto|sessiz]
---------------------------------------------------------------------------
function BuffReq:Command(arg)
    arg = (arg or ""):lower()
    if arg == "on" or arg == "ac" or arg == "aç" then
        HM.db.buffRequestOff = false
        HM:Print(OK .. "Buff isteme |cff80ff80ACIK|r — yakinindaki oyunculara otomatik whisper atar.")
    elseif arg == "off" or arg == "kapat" or arg == "kapa" then
        HM.db.buffRequestOff = true
        HM:Print(BAD .. "Buff isteme |cffff6060KAPALI|r — /hm buff on ile tekrar ac.")
    elseif arg == "oto" then
        HM.db.buffRequestOff = not (HM.db.buffRequestOff or false)
        HM:Print("Otomatik buff isteme: " .. (HM.db.buffRequestOff and "kapali — /hm buff on ile ac" or "acik — yakinindaki oyunculara otomatik whisper atar"))
    elseif arg == "sessiz" or arg == "kontrol" then
        -- whisper atmadan sadece durumu göster
        local old = HM.db.buffRequestOff
        HM.db.buffRequestOff = true
        self:Scan(true)
        HM.db.buffRequestOff = old
    else
        self:Status()
        self:Scan(true)
    end
end
