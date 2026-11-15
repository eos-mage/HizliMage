-- Darkmoon Faire takibi: takvim, Sayge buff hatırlatma, bilet malzemesi çanta sayacı.
-- Komutlar: /hm faire (durum), /hm faire sayge (buff rehberi), /hm faire bilet (malzeme listesi)

local ADDON, ns = ...
local HM = ns.HM
local Faire = {}
HM.Faire = Faire

local function safe(v) if HM.IsSecret(v) then return nil end return v end
local OK, BAD, WARN = "|cff80ff80+|r ", "|cffff6060x|r ", "|cffffd100!|r "

---------------------------------------------------------------------------
-- Darkmoon Faire takvimi (Classic/Forever: her ayın ilk Cuma'sı + 7 gün)
-- Konum: tek aylar Mulgore, çift aylar Elwynn Forest (Horde için)
---------------------------------------------------------------------------
local FAIRE_WEEKDAY_FRI = 6  -- WoW: 1=Sun 2=Mon ... 6=Fri 7=Sat

-- İlk Cuma'yı bul (ayın 1-7. günlerinden biri)
local function firstFriday(year, month)
    -- Zeller tabanlı basit hesap yerine sabit tablo yaklaşımı yok; oyun API'si kullanılır.
    -- C_DateAndTime yoksa elle hesapla:
    -- WoW Classic'te date() varsa onu kullanabiliriz.
    local t = { year = year, month = month, day = 1 }
    local ts = time(t)
    local wday = tonumber(date("!%w", ts)) -- 0=Sun 1=Mon ... 5=Fri 6=Sat
    local daysToFri = (5 - wday) % 7  -- 5 = Friday
    return 1 + daysToFri  -- 1-7
end

-- Faire takvimi: kurulum = ilk Cuma, açılış = Pazartesi (+3), kapanış = Pazar (+9)
local function faireWindow(year, month)
    local ff = firstFriday(year, month)
    return {
        setup = ff,                  -- Cuma: NPC'ler gelir ama satıcılar yok
        open   = ff + 3,             -- Pazartesi: tam açık
        close  = ff + 9,             -- Pazar: son gün
    }
end

local function currentDate()
    local d = C_DateAndTime and C_DateAndTime.GetCurrentCalendarTime and C_DateAndTime.GetCurrentCalendarTime()
    if d and d.year and d.month and d.monthDay then
        return d.year, d.month, d.monthDay
    end
    -- yedek: sistem tarihi
    local t = date("!*t")
    return t.year, t.month, t.day
end

-- Konum: tek ay (1,3,5,7,9,11) = Mulgore (Horde-dostu), çift ay = Elwynn Forest
local function faireLocation(month)
    if month % 2 == 1 then
        return "|cff80ff80Mulgore|r (Thunder Bluff guneybatisi)", true   -- Horde-dostu
    else
        return "|cffff6060Elwynn Forest|r (Goldshire guneyi) — Alliance bolgesi, dikkatli ol!", false
    end
end

---------------------------------------------------------------------------
-- Sayge buff rehberi
---------------------------------------------------------------------------
local SAYGE_BUFFS = {
    { name = "+10% Hasar",       a1 = 1, a2 = 1, color = "|cffff6060", note = "En iyi secenek — DPS ve leveling icin" },
    { name = "+10% Intellect",   a1 = 2, a2 = 2, color = "|cff80c0ff", note = "Daha fazla mana ve krit" },
    { name = "+10% Stamina",     a1 = 3, a2 = 1, color = "|cff80ff80", note = "Hayatta kalma" },
    { name = "+10% Spirit",      a1 = 2, a2 = 1, color = "|cff80ff80", note = "Mana yenilenmesi" },
    { name = "+10% Agility",     a1 = 3, a2 = 3, color = "|cff80ff80", note = "Rogue/Hunter icin" },
    { name = "+10% Strength",    a1 = 3, a2 = 2, color = "|cff80ff80", note = "Warrior icin" },
    { name = "+10% Armor",       a1 = 1, a2 = 3, color = "|cff80ff80", note = "Tank icin" },
    { name = "+25 Direncler",    a1 = 1, a2 = 2, color = "|cff80ff80", note = "Buyu direnci" },
}

local function printSayge()
    HM:Print("|cff33ccff— Sayge'nin fali (Darkmoon Faire) —|r")
    HM:Print("Sayge'ye konus, iki soru cevaplayin. 2 saat suruyor, olunce gider.")
    for _, b in ipairs(SAYGE_BUFFS) do
        local tag = (b.a1 == 1 and b.a2 == 1) and " <-- MAGE" or ""
        HM:Print(string.format("  %s%s|r: cevap |cffffd100%d|r - |cffffd100%d|r  (%s)%s", b.color, b.name, b.a1, b.a2, b.note, tag))
    end
    HM:Print("Mage icin: |cffff6060+10% Hasar (1-1)|r ya da |cff80c0ff+10% Intellect (2-2)|r")
end

---------------------------------------------------------------------------
-- Bilet malzemeleri ve çanta sayacı
---------------------------------------------------------------------------
local TICKET_ITEMS = {
    -- { itemName, count, tickets, minLevel, source }
    { "Small Furry Paw",     5,  1,  1,  "Kucuk hayvanlar (Durotar, Mulgore tavsan/sincap)" },
    { "Copper Modulator",    5,  1,  1,  "Muhendislik (Kok sac calisma tezgahi) ya da AH" },
    { "Torn Bear Pelt",      5,  4,  10, "Ayilar (Silverpine, Hillsbrad, Ashenvale)" },
    { "Whirring Bronze Gizmo", 7, 4, 10, "Muhendislik ya da AH" },
    { "Soft Bushy Tail",     5,  8,  20, "Tilkiler (Redridge, Loch Modan, Stonetalon)" },
    { "Vibrant Plume",       5,  12, 30, "Kuslar (Stranglethorn, Arathi, Badlands)" },
    { "Evil Bat Eye",        10, 20, 40, "Yarasalar (Eastern Plaguelands, Felwood)" },
    { "Glowing Scorpid Blood", 10, 20, 40, "Akrepler (Tanaris, Blasted Lands, Silithus)" },
}

local function countInBags(itemName)
    local total = 0
    for bag = 0, 4 do
        local slots = 0
        if C_Container and C_Container.GetContainerNumSlots then
            slots = C_Container.GetContainerNumSlots(bag) or 0
        elseif GetContainerNumSlots then
            slots = GetContainerNumSlots(bag) or 0
        end
        for slot = 1, slots do
            local info
            if C_Container and C_Container.GetContainerItemInfo then
                info = C_Container.GetContainerItemInfo(bag, slot)
            end
            if info and info.itemName then
                local n = safe(info.itemName)
                if n and n == itemName then
                    total = total + (info.stackCount or 1)
                end
            end
        end
    end
    return total
end

local function printTickets()
    local level = HM:Level()
    HM:Print("|cff33ccff— Darkmoon Faire bilet malzemeleri —|r")
    HM:Print("Her teslim +100 Darkmoon itibari verir. Malzemeleri topla, Faire'de teslim et.")
    local anyFound = false
    for _, t in ipairs(TICKET_ITEMS) do
        if level >= t[4] then
            local have = countInBags(t[1])
            local sets = math.floor(have / t[2])
            local icon = have >= t[2] and OK or (have > 0 and WARN or BAD)
            HM:Print(string.format("  %s|cffffd100%s|r x%d = %d bilet — cantada: %d (%d teslim hazir) — %s",
                icon, t[1], t[2], t[3], have, sets, t[5]))
            anyFound = true
        end
    end
    if not anyFound then
        HM:Print("  Henuz seviye 10'da degilsin, sadece Small Furry Paw + Copper Modulator alabilirsin.")
    end
    HM:Print("Biletle alinabilir: 5 bilet = Storage Box (sev.6), 10+ bilet = odullu kutular")
end

---------------------------------------------------------------------------
-- Faire durum raporu
---------------------------------------------------------------------------
function Faire:Status()
    local year, month, day = currentDate()
    if not year then HM:Print(BAD .. "Tarih alinamadi."); return end

    local fw = faireWindow(year, month)
    local loc, hordeFriendly = faireLocation(month)

    HM:Print("|cff33ccff— Darkmoon Faire durumu —|r")
    HM:Print(string.format("  Bu ay (%d/%d): kurulum %d'inde, acilis %d - kapanis %d",
        month, year, fw.setup, fw.open, fw.close))
    HM:Print("  Konum: " .. loc)

    if day < fw.setup then
        local kalan = fw.setup - day
        HM:Print(WARN .. string.format("Faire %d gun sonra basliyor (kurulum %d'inde, acilis %d'inde).", kalan, fw.setup, fw.open))
    elseif day >= fw.setup and day < fw.open then
        HM:Print(WARN .. "Faire kurulumu basladi ama saticilar henuz yok. Acilis: " .. fw.open .. "'inde.")
    elseif day >= fw.open and day <= fw.close then
        local kalan = fw.close - day
        HM:Print(OK .. string.format("|cff00ff00FAIRE ACIK!|r %d gun kaldi. Git ve Sayge buff'ini al!", kalan + 1))
    else
        -- ay bitti, gelecek ayı hesapla
        local nm = month == 12 and 1 or (month + 1)
        local ny = month == 12 and (year + 1) or year
        local nfw = faireWindow(ny, nm)
        local nloc = faireLocation(nm)
        HM:Print(BAD .. string.format("Bu ayki Faire bitti. Sonraki: %d/%d, acilis %d'inde.", nm, ny, nfw.open))
        HM:Print("  Sonraki konum: " .. nloc)
    end

    -- Sayge buff kontrolü
    local hasSayge = false
    if UnitBuff then
        for i = 1, 40 do
            local name
            if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
                local ok, d = pcall(C_UnitAuras.GetAuraDataByIndex, "player", i, "HELPFUL")
                if ok and d then name = safe(d.name) end
            elseif UnitBuff then
                local ok, n = pcall(UnitBuff, "player", i)
                if ok then name = safe(n) end
            end
            if not name then break end
            if name and name:find("Sayge") then hasSayge = true; break end
        end
    end
    if hasSayge then
        HM:Print(OK .. "Sayge buff'in var!")
    else
        HM:Print(WARN .. "Sayge buff'in yok. Faire acikken git, 1-1 cevapla (+10% Hasar).")
    end
end

---------------------------------------------------------------------------
-- Giriş bildirimi: Faire açıksa veya yaklaşıyorsa hatırlat
---------------------------------------------------------------------------
HM:OnLogin(function()
    C_Timer.After(12, function()
        local ok, err = pcall(function()
            local year, month, day = currentDate()
            if not year then return end
            local fw = faireWindow(year, month)
            if day >= fw.open and day <= fw.close then
                local loc, horde = faireLocation(month)
                HM:Print("|cff9933ff[Darkmoon Faire]|r |cff00ff00ACIK!|r " .. loc)
                -- Sayge buff yoksa uyar
                local hasSayge = false
                for i = 1, 40 do
                    local name
                    if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
                        local _, d = pcall(C_UnitAuras.GetAuraDataByIndex, "player", i, "HELPFUL")
                        if d then name = safe(d.name) end
                    end
                    if not name then break end
                    if name and name:find("Sayge") then hasSayge = true; break end
                end
                if not hasSayge then
                    HM:Print("|cff9933ff[Darkmoon Faire]|r Sayge'den +10% Hasar al! (cevap 1-1) — /hm faire sayge")
                end
            elseif day >= (fw.setup - 2) and day < fw.setup then
                HM:Print("|cff9933ff[Darkmoon Faire]|r " .. (fw.setup - day) .. " gun sonra basliyor! Bilet malzemelerini topla — /hm faire bilet")
            end
        end)
    end)
end)

---------------------------------------------------------------------------
-- Komut: /hm faire [sayge|bilet]
---------------------------------------------------------------------------
function Faire:Command(arg)
    arg = (arg or ""):lower()
    if arg == "sayge" then
        printSayge()
    elseif arg == "bilet" or arg == "ticket" then
        printTickets()
    else
        self:Status()
        HM:Print("Alt komutlar: |cffffd100/hm faire sayge|r (buff rehberi), |cffffd100/hm faire bilet|r (malzeme listesi)")
    end
end
