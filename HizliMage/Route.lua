-- Sınıf verisi: eğitmenler, zindanlar, talent planları, kasma noktaları, eşya kimlikleri.
-- Görev rotaları Route_MAGE.lua / Route_DRUID.lua / Route_WARRIOR.lua dosyalarında (otomatik üretilir).
-- Koordinatlar harita yüzdesidir (0-100); m = uiMapID.

local ADDON, ns = ...

-- Harita kimlikleri (Classic uiMapID)
local DUROTAR, BARRENS, ORGRIMMAR = 1411, 1413, 1454
local TIRISFAL, UNDERCITY, HILLSBRAD, ARATHI = 1420, 1458, 1424, 1417
local STONETALON, ASHENVALE, STV, DUSTWALLOW = 1442, 1440, 1434, 1445
local BADLANDS, TANARIS, FERALAS, AZSHARA = 1418, 1446, 1444, 1447
local UNGORO, FELWOOD, WINTERSPRING, EPL, SILITHUS = 1449, 1448, 1452, 1423, 1451
local MULGORE, TBLUFF, NEEDLES, DESOLACE = 1412, 1456, 1441, 1443


-- Eğitmenler (en yakını seçilir)
ns.Trainers = {
    herb = {
        { m = ORGRIMMAR, x = 55.6, y = 39.5, n = "Jandi (Orgrimmar)" },
        { m = UNDERCITY, x = 54.0, y = 49.5, n = "Martha Alliestar (Undercity)" },
        { m = 1456, x = 50.0, y = 40.4, n = "Komin Winterhoof (Thunder Bluff)" },
        { m = FERALAS, x = 76.0, y = 43.3, n = "Ruw (Camp Mojache)" },
    },
    mine = {
        { m = ORGRIMMAR, x = 73.1, y = 26.1, n = "Makaru (Orgrimmar)" },
        { m = UNDERCITY, x = 56.0, y = 37.5, n = "Brom Killian (Undercity)" },
        { m = 1456, x = 34.4, y = 57.9, n = "Brek Stonehoof (Thunder Bluff)" },
    },
    skin = {
        { m = ORGRIMMAR, x = 63.4, y = 45.4, n = "Thuwd (Orgrimmar)" },
        { m = 1443, x = 23.2, y = 69.7, n = "Malux (Shadowprey Village)" },
        { m = FERALAS, x = 74.5, y = 43.0, n = "Kulleg Stonehorn (Camp Mojache)" },
    },
    firstaid = {
        { m = DUROTAR, x = 54.2, y = 41.9, n = "Rawrk (Razor Hill)" },
        { m = ORGRIMMAR, x = 34.2, y = 84.6, n = "Arnok (Orgrimmar)" },
        { m = UNDERCITY, x = 73.2, y = 55.1, n = "Mary Edras (Undercity)" },
        { m = 1456, x = 29.7, y = 21.2, n = "Pand Stonebinder (Thunder Bluff)" },
    },
}

-- Zindanlar (Forever: çöp XP'si düşük, görevler yüksek). m = nil ise giriş henüz bilinmiyor.
ns.Dungeons = {
    { n = "Ragefire Chasm", a = 13, b = 18, m = ORGRIMMAR, x = 52.6, y = 49.0 },
    { n = "Ruins of Lordaeron (Forever, Undercity'nin üstü)", a = 15, b = 20 },
    { n = "Wailing Caverns", a = 17, b = 24, m = BARRENS, x = 46.0, y = 36.5 },
    { n = "Blackfathom Deeps", a = 22, b = 28, m = ASHENVALE, x = 14.5, y = 14.2 },
    { n = "Razorfen Kraul", a = 26, b = 32, m = BARRENS, x = 42.9, y = 90.2 },
    { n = "Scarlet Monastery", a = 30, b = 40, m = TIRISFAL, x = 82.6, y = 33.8 },
    { n = "Razorfen Downs", a = 34, b = 40, m = BARRENS, x = 49.0, y = 93.9 },
    { n = "Uldaman", a = 40, b = 46, m = BADLANDS, x = 44.6, y = 12.1 },
    { n = "Krol'dok Stronghold (Forever, Riverglades)", a = 40, b = 45 },
    { n = "Zul'Farrak", a = 44, b = 50, m = TANARIS, x = 38.7, y = 20.1 },
    { n = "Maraudon", a = 46, b = 52, m = 1443, x = 29.1, y = 62.5 },
    { n = "Alcaz Prison (Forever, Dustwallow)", a = 48, b = 53 },
    { n = "Sunken Temple", a = 50, b = 55, m = 1435, x = 69.9, y = 53.5 },
    { n = "Blackrock Depths", a = 52, b = 60, m = 1427, x = 34.8, y = 85.3 },
    { n = "Blackmaw Hold (Forever, Azshara)", a = 55, b = 60 },
    { n = "Dire Maul", a = 56, b = 60, m = FERALAS, x = 59.2, y = 45.1 },
    { n = "Scholomance", a = 58, b = 60, m = 1422, x = 69.7, y = 73.2 },
    { n = "Stratholme", a = 58, b = 60, m = EPL, x = 31.3, y = 15.7 },
    { n = "Shaper's Terrace (Forever, Un'Goro)", a = 58, b = 60 },
}

-- Talent planları. Mage: Claude Docs'taki "Classic mage 1–60 yol haritası" (Forever beta).
-- Druid ve warrior: Classic kasma sırası; Forever ağaçları değiştirdiği için talent ekranında doğrula.
local function expand(plan, last)
    local out = {}
    for _, p in ipairs(plan) do
        local from, to, name, max, fixed = p[1], p[2], p[3], p[4], p[5]
        for lvl = from, to do
            local rank = fixed or (lvl - from + 1)
            out[lvl] = string.format("%s (%d/%d)", name, rank, max)
        end
    end
    out[60] = last
    return out
end

local MOUNT_ORC = { m = ORGRIMMAR, x = 69.4, y = 13.1, n = "Kildar (Orgrimmar, Valley of Honor): Apprentice Riding + kurt" }
local MOUNT_TAUREN = { m = MULGORE, x = 46.8, y = 62.0, n = "Kar Stormsinger (Bloodhoof Village): Apprentice Riding + kodo" }

ns.ClassData = {
    MAGE = {
        label = "Mage",
        trainers = {
            { m = DUROTAR, x = 42.5, y = 69.0, n = "Mai'ah (Valley of Trials)" },
            { m = DUROTAR, x = 56.3, y = 75.1, n = "Un'Thuwa (Sen'jin Village)" },
            { m = ORGRIMMAR, x = 38.8, y = 85.9, n = "Orgrimmar, Valley of Spirits" },
            { m = UNDERCITY, x = 85.2, y = 12.5, n = "Undercity, Magic Quarter" },
            { m = TBLUFF, x = 25.7, y = 14.2, n = "Thunder Bluff, Spirit Rise" },
            { m = TIRISFAL, x = 62.0, y = 52.5, n = "Cain Firesong (Brill)" },
        },
        markers = { "Frostbolt", "Fireball", "Arcane Intellect", "Frost Armor", "Conjure Water", "Polymorph", "Frost Nova", "Arcane Explosion", "Fire Blast" },
        skip = {
            ["Scorch"] = true, ["Flamestrike"] = true, ["Pyroblast"] = true, ["Arcane Missiles"] = true,
            ["Arcane Blast"] = true, ["Amplify Magic"] = true, ["Dampen Magic"] = true, ["Detect Magic"] = true,
            ["Fire Ward"] = true, ["Frost Ward"] = true, ["Remove Lesser Curse"] = true,
            ["Teleport: Thunder Bluff"] = true, ["Portal: Thunder Bluff"] = true, ["Portal: Undercity"] = true, ["Portal: Orgrimmar"] = true,
        },
        skipAfter10 = { ["Fireball"] = true },
        singleRank = { ["Polymorph"] = true },
        buffs = {
            { n = "Arcane Intellect", ids = { 1459, 1460, 1461, 10156, 10157, 23028 } },
            { n = "zırh büyüsü", ids = { 168, 7300, 7301, 7302, 7320, 10219, 10220, 6117, 22782, 22783 } },
        },
        supply = "mage",
        talents = expand({
            { 10, 14, "Improved Frostbolt", 5 }, { 15, 16, "Elemental Precision", 2 },
            { 17, 19, "Frostbite", 3 }, { 20, 20, "Ice Lance", 1 }, { 21, 24, "Ice Shards", 5 },
            { 25, 25, "Ice Block", 1 }, { 26, 26, "Ice Shards", 5, 5 }, { 27, 29, "Shatter", 3 },
            { 30, 30, "Fingers of Frost", 2 }, { 31, 31, "Cold Snap", 1 }, { 32, 32, "Fingers of Frost", 2, 2 },
            { 33, 35, "Improved Blizzard", 3 }, { 36, 38, "Piercing Ice", 3 }, { 39, 41, "Frost Channeling", 3 },
            { 42, 42, "Ice Barrier", 1 }, { 43, 45, "Permafrost", 3 }, { 46, 47, "Arctic Reach", 2 },
            { 48, 52, "Winter's Chill", 5 }, { 53, 54, "Frost Warding", 2 }, { 55, 56, "Improved Frost Nova", 2 },
            { 57, 59, "Improved Cone of Cold", 3 },
        }, "serbest puan (raid build'ine geçmeden önce)"),
        train20 = "Blizzard, Blink, Evocation, Teleport: Orgrimmar ve Teleport: Undercity. Talent: Ice Lance.",
        train40 = "Frostfire Bolt ve yeni rank'lar.",
    },
    DRUID = {
        label = "Druid",
        trainers = {
            { m = TBLUFF, x = 76.5, y = 27.2, n = "Turak Runetotem (Thunder Bluff, Elder Rise)" },
            { m = MULGORE, x = 44.6, y = 76.5, n = "Gart Mistrunner (Camp Narache)" },
            { m = MULGORE, x = 47.5, y = 63.0, n = "Gennia Runetotem (Bloodhoof Village)" },
            { m = FERALAS, x = 76.0, y = 42.3, n = "Jannos Lighthoof (Camp Mojache)" },
            { m = 1450, x = 52.5, y = 40.6, n = "Loganaar (Moonglade)" },
        },
        markers = { "Wrath", "Healing Touch", "Mark of the Wild", "Moonfire", "Rejuvenation", "Thorns", "Entangling Roots", "Bear Form", "Claw", "Maul" },
        skip = {
            ["Starfire"] = true, ["Hurricane"] = true, ["Tranquility"] = true, ["Hibernate"] = true,
            ["Soothe Animal"] = true, ["Insect Swarm"] = true, ["Challenging Roar"] = true, ["Teleport: Moonglade"] = false,
        },
        skipAfter10 = { ["Wrath"] = true },
        singleRank = { ["Hibernate"] = true },
        buffs = {
            { n = "Mark of the Wild", ids = { 1126, 5232, 6756, 5234, 8907, 9884, 9885 } },
            { n = "Thorns", ids = { 467, 782, 1075, 8914, 9756, 9910 } },
        },
        supply = "bandage",
        talents = expand({
            { 10, 14, "Ferocity", 5 }, { 15, 19, "Thick Hide", 5 }, { 20, 21, "Feline Swiftness", 2 },
            { 22, 24, "Sharpened Claws", 3 }, { 25, 25, "Feral Charge", 1 }, { 26, 28, "Predatory Strikes", 3 },
            { 29, 30, "Blood Frenzy", 2 }, { 31, 32, "Primal Fury", 2 }, { 33, 34, "Savage Fury", 2 },
            { 35, 35, "Faerie Fire (Feral)", 1 }, { 36, 40, "Heart of the Wild", 5 }, { 41, 41, "Leader of the Pack", 1 },
            { 42, 46, "Feral Aggression", 5 }, { 47, 48, "Improved Shred", 2 }, { 49, 53, "Furor (Restoration)", 5 },
            { 54, 58, "Improved Mark of the Wild", 5 }, { 59, 59, "Natural Shapeshifter", 3, 1 },
        }, "serbest puan"),
        train20 = "Cat Form, Rip ve yeni rank'lar. Kedi formunda kasmaya geç.",
        train40 = "Dire Bear Form ve yeni rank'lar.",
        milestones = {
            [10] = "10: Bear Form görevi Thunder Bluff'taki druid eğitmeninden (Turak Runetotem) başlar; Moonglade'e götürür, Teleport: Moonglade'i de verir.",
            [16] = "16: Aquatic Form görev zinciri druid eğitmeninden başlar; suda hızlı yüzme, uzun yollarda zaman kazandırır.",
            [20] = "20: Cat Form eğitmenden; bundan sonra kedi formunda kasmak en hızlısı.",
            [30] = "30: Travel Form eğitmenden; bineğe kadar %40 hız.",
        },
    },
    WARRIOR = {
        label = "Warrior",
        trainers = {
            { m = ORGRIMMAR, x = 79.8, y = 31.4, n = "Grezz Ragefist (Orgrimmar, Valley of Honor)" },
            { m = DUROTAR, x = 54.2, y = 42.5, n = "Tarshaw Jaggedscar (Razor Hill)" },
            { m = MULGORE, x = 48.4, y = 63.7, n = "Krang Stonehoof (Bloodhoof Village)" },
            { m = TBLUFF, x = 57.2, y = 87.4, n = "Torm Ragetotem (Thunder Bluff, Hunter Rise)" },
            { m = UNDERCITY, x = 46.9, y = 15.2, n = "Christoph Walker (Undercity, War Quarter)" },
            { m = TIRISFAL, x = 61.9, y = 52.5, n = "Austil de Mon (Brill)" },
            { m = 1435, x = 44.9, y = 57.6, n = "Malosh (Stonard)" },
        },
        markers = { "Heroic Strike", "Battle Shout", "Charge", "Rend", "Thunder Clap", "Hamstring", "Overpower", "Sunder Armor", "Defensive Stance" },
        skip = {
            ["Challenging Shout"] = true, ["Shield Wall"] = true, ["Intercept"] = false,
        },
        skipAfter10 = {},
        singleRank = {},
        buffs = {},
        supply = "bandage",
        talents = expand({
            { 10, 12, "Improved Heroic Strike", 3 }, { 13, 14, "Deflection", 2 }, { 15, 19, "Tactical Mastery", 5 },
            { 20, 20, "Anger Management", 1 }, { 21, 23, "Deep Wounds", 3 }, { 24, 28, "Two-Handed Weapon Specialization", 5 },
            { 29, 30, "Impale", 2 }, { 31, 35, "Axe Specialization (ya da silahına göre Sword/Mace)", 5 }, { 36, 37, "Improved Charge", 2 },
            { 38, 38, "Sweeping Strikes", 1 }, { 39, 39, "Improved Overpower", 2, 1 }, { 40, 40, "Mortal Strike", 1 },
            { 41, 45, "Cruelty (Fury)", 5 }, { 46, 50, "Unbridled Wrath (Fury)", 5 }, { 51, 55, "Improved Battle Shout (Fury)", 5 },
            { 56, 59, "Enrage (Fury)", 5 },
        }, "serbest puan"),
        train20 = "Yeni rank'lar; Heroic Strike, Rend ve Overpower öncelikli.",
        train40 = "Yeni rank'lar.",
        milestones = {
            [10] = "10: Defensive Stance görevi warrior eğitmeninden başlar; tanklamak için şart.",
            [30] = "30: Berserker Stance görevi warrior eğitmeninden başlar; Whirlwind ve Intercept için gerekli.",
        },
    },
}


-- Kasma noktaları {seviye alt, üst, harita, x, y, açıklama}: "Kas" düğmesi ve L adımları.
ns.Grind = {
    { 10, 14, BARRENS, 63.7, 47.0, "Southsea korsanları (Ratchet güneyi)" },
    { 14, 17, BARRENS, 56.0, 8.5, "Venture Co. Drudger (Sludge Fen)" },
    { 17, 21, BARRENS, 45.0, 66.0, "Bristleback / Razormane kampları (Taurajo güneyi)" },
    { 21, 25, ASHENVALE, 35.4, 37.5, "Thistlefur furbolgları" },
    { 25, 29, NEEDLES, 36.0, 42.0, "Galak centaurları (Freewind kuzeyi)" },
    { 29, 32, DESOLACE, 56.0, 45.0, "Kolkar centaurları (Ghost Walker kuzeyi)" },
    { 32, 36, ARATHI, 32.4, 28.9, "Syndicate Highwayman (Northfold Manor)" },
    { 36, 40, STV, 42.9, 19.1, "Venture Co. Geologist/Miner (Lake Nazferiti)" },
    { 40, 44, BADLANDS, 60.0, 55.0, "Dustbelcher ogreleri (Kargath doğusu)" },
    { 44, 47, FERALAS, 56.0, 62.5, "Frayfeather hipogrifleri" },
    { 47, 50, TANARIS, 62.8, 29.2, "Wastewander Bandit/Thief" },
    { 50, 53, UNGORO, 66.1, 16.1, "Un'Goro gorilları" },
    { 53, 56, FELWOOD, 61.8, 8.2, "Deadwood furbolgları" },
    { 56, 58, WINTERSPRING, 58.1, 35.9, "Winterfall Den Watcher" },
    { 58, 60, SILITHUS, 26.1, 61.0, "Hive'Zora eşekarıları" },
}

-- Üretilen rotayı yükler: N (not) adımları bir sonraki adımın notuna katılır.
function ns.BuildRoute(class)
    local src = ns.Guides and (ns.Guides[class] or ns.Guides.MAGE)
    if not src then return {} end
    local r = {}
    local pendingNote
    for _, s in ipairs(src) do
        if s.k == "N" then
            pendingNote = (pendingNote and (pendingNote .. " ") or "") .. (s.t or "")
        else
            local c = {}
            for k, v in pairs(s) do c[k] = v end
            if pendingNote then
                c.n = (c.n and c.n ~= "") and (pendingNote .. "\n" .. c.n) or pendingNote
                pendingNote = nil
            end
            r[#r + 1] = c
        end
    end
    return r
end

-- Giriş anında karakterin sınıfına göre rota ve veri seçilir.
ns.HM:OnLogin(function()
    local _, class = UnitClass("player")
    local _, race = UnitRace("player")
    ns.class = ns.ClassData[class] and class or "MAGE"
    ns.race = race
    ns.CD = ns.ClassData[ns.class]
    ns.Route = ns.BuildRoute(ns.class)
    ns.Talents = ns.CD.talents
end)

-- Sık kullanılan eşya kimlikleri
ns.Items = {
    water = { 5350, 2288, 2136, 3772, 8077, 8078, 8079 },   -- Conjured Water ... Crystal Water
    food = { 5349, 1113, 1114, 1487, 8075, 8076, 22895 },   -- Conjured Muffin ... Cinnamon Roll
    bandage = { 1251, 2581, 3530, 3531, 6450, 6451, 8544, 8545, 14529, 14530 },
    cloth = {
        { 2589, "Linen Cloth" }, { 2592, "Wool Cloth" }, { 4306, "Silk Cloth" },
        { 4338, "Mageweave Cloth" }, { 14047, "Runecloth" }, { 14256, "Felcloth" },
    },
}
