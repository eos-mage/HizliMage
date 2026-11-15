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

-- Rehberin kendiliğinden atlayacağı görevler ([görevId] = "neden"). Rota üretici v2.7'den beri tek başına
-- bitmeyen görevleri (elit yaratık, zindan, savaş alanı nişanı, meslek/AH eşyası) rotaya hiç koymuyor;
-- bu liste yalnız sunucuda verilmeyen bir görev çıkarsa elle doldurulur.
ns.UnavailableQuests = {
}
-- Daha önce yanlışlıkla "atlandı" işaretlenen görevler: girişte işaret kaldırılır (bir kez).
ns.UnskipQuests = { 97249 }

-- Talent planları. Mage: Forever Frost ağacına göre (foreverdb.net, Kasım 2026): Piercing Ice ve
-- Elemental Precision yok; Precision (3, +6% isabet), Ice Lance (3. sıra), Fingers of Frost (5. sıra),
-- Winter's Chill artık Frostbolt → Cone of Cold patlaması. Sıra kuralı: her satır üsttekilere 5 puan ister.
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
            -- 1. sıra (10+)            2. sıra (15+, 5 puan)        3. sıra (20+, 10 puan)
            { 10, 14, "Improved Frostbolt", 5 }, { 15, 17, "Frostbite", 3 }, { 18, 19, "Precision", 3 },
            { 20, 20, "Ice Lance", 1 }, { 21, 21, "Precision", 3, 3 }, { 22, 24, "Ice Shards", 5 },
            -- 4. sıra (25+, 15 puan)
            { 25, 27, "Shatter", 3 }, { 28, 28, "Ice Shards", 5, 4 }, { 29, 29, "Ice Shards", 5, 5 },
            -- 5. sıra (30+, 20 puan)
            { 30, 31, "Fingers of Frost", 2 }, { 32, 32, "Ice Block", 1 }, { 33, 33, "Cold Snap", 1 },
            { 34, 36, "Frost Channeling", 3 }, { 37, 38, "Improved Frost Nova", 2 }, { 39, 39, "Arctic Reach", 2 },
            -- 7. sıra (40+, 30 puan)
            { 40, 40, "Ice Barrier", 1 }, { 41, 41, "Arctic Reach", 2, 2 }, { 42, 44, "Permafrost", 3 },
            { 45, 49, "Winter's Chill", 5 }, { 50, 52, "Improved Cone of Cold", 3 }, { 53, 55, "Improved Blizzard", 3 },
            { 56, 57, "Frost Warding", 2 }, { 58, 59, "Arcane Resilience", 3 },
        }, "Arcane Resilience (3/3) — sonra 60 raid build'i: 18/0/33 (Arcane Concentration, Arcane Meditation, Missile Barrage)"),
        talentNotes = {
            "Frostbolt doldurucu; Frostbite/Frost Nova donması ve Fingers of Frost'ta Ice Lance (donmuşa 4 kat) + Shatter kriti.",
            "Kalkan: Ice Block (32) → Cold Snap (33) ile sıfırla; Ice Barrier (40) her çekişte açık dursun.",
            "45+: 5 Frostbolt → Winter's Chill yığını → Cone of Cold ile bitir (Imp. CoC 50-52 bunu büyütür).",
            "Permafrost (42-44) ile kiting kolaylaşır; Improved Blizzard yalnız AoE kasıyorsan öne al.",
        },
        train20 = "Blizzard, Blink, Evocation, Teleport: Orgrimmar ve Teleport: Undercity. Talent: Ice Lance.",
        train40 = "Frostfire Bolt ve yeni rank'lar.",
        milestones = {
            [20] = "20: Teleport açıldı. Orgrimmar'da portal eğitmeni Thuul'dan Teleport: Orgrimmar'ı öğren, reagent satıcısı Horthus'tan Rune of Teleportation al; Undercity'ninkini oradaki portal eğitmeni Lexington Mortaim verir. Rehber başkente dönüşlerde ve kıta değişimlerinde ışınlanmayı kullanır.",
            [30] = "30: Teleport: Thunder Bluff açıldı (Birgitte Cranston, Spirit Rise). Rota kullanmıyor; istersen al.",
        },
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
    HUNTER = {
        label = "Hunter",
        trainers = {
            { m = DUROTAR, x = 42.0, y = 68.8, n = "Jen'shan (Valley of Trials)" },
            { m = DUROTAR, x = 52.5, y = 42.1, n = "Thotar (Razor Hill)" },
            { m = ORGRIMMAR, x = 66.5, y = 18.4, n = "Orgrimmar, Valley of Honor" },
            { m = TBLUFF, x = 57.3, y = 89.0, n = "Thunder Bluff, Hunter Rise" },
            { m = MULGORE, x = 47.4, y = 56.6, n = "Lanka Farshot (Bloodhoof Village)" },
            { m = UNDERCITY, x = 52.1, y = 9.0, n = "Undercity, War Quarter" },
        },
        markers = { "Auto Shot", "Serpent Sting", "Arcane Shot", "Concussive Shot", "Aspect of the Hawk", "Multi-Shot", "Aimed Shot", "Rapid Fire", "Feign Death" },
        skip = {
            ["Eagle Eye"] = true, ["Beast Lore"] = true, ["Eyes of the Beast"] = true,
            ["Scorpid Sting"] = true, ["Aspect of the Wild"] = true,
        },
        skipAfter10 = {},
        singleRank = {},
        buffs = {
            { n = "Aspect of the Hawk", ids = { 13165, 14318, 14319, 14320, 14321, 14322, 25296 } },
        },
        supply = "bandage",
        talents = expand({
            -- BM leveling (Forever): Deadly Aspects → Focused Fire → Pathfinding → Unleashed Fury → Bestial Swiftness → Summon Hawk → Ferocity → Intimidation
            { 10, 14, "Deadly Aspects", 5 }, { 15, 16, "Focused Fire", 2 }, { 17, 18, "Pathfinding", 2 },
            { 19, 19, "Improved Revive Pet", 2, 1 }, { 20, 24, "Unleashed Fury", 5 }, { 25, 25, "Summon Hawk", 1 },
            { 26, 27, "Bestial Swiftness", 2 }, { 28, 29, "Ferocity", 5, 1 },  { 30, 30, "Intimidation", 1 },
            -- 30+: Bestial Discipline, Frenzy, Bestial Wrath
            { 31, 33, "Bestial Discipline", 3 }, { 34, 37, "Frenzy", 4 }, { 38, 39, "Endurance Training", 2 },
            { 40, 40, "Bestial Wrath", 1 },
            -- 40+: MM dip: Lethal Attacks, Mortal Shots, Careful Aim, Trueshot Aura
            { 41, 45, "Lethal Attacks", 5 }, { 46, 50, "Mortal Shots", 5 },
            { 51, 53, "Careful Aim", 3 }, { 54, 55, "Hawk Eye", 2 },
            { 56, 58, "Improved Concussive Shot", 3 }, { 59, 59, "Ferocity", 5, 3 },
        }, "serbest puan — 60 raid build'i: 31/20/0 (BM/MM)"),
        talentNotes = {
            "Pet ile çek: Aspect of the Hawk sürekli açık, Auto Shot mesafesinden Serpent Sting → Arcane Shot/Aimed Shot.",
            "25: Summon Hawk — 2 hawk havada tutarak DPS'i ciddi artır; hawk cooldown'u Arcane Shot ile paylaşılır.",
            "30: Intimidation — pet stun'u, solo tehlikeli mob'ları kontrol eder.",
            "40: Bestial Wrath — pet'e %50 hasar artışı ve CC bağışıklığı, zor mob'larda kullan.",
            "Hit cap: seviye 60'ta 9% isabet (305 silah becerisi ile 6%). Agility > AP > Crit.",
        },
        train20 = "Aimed Shot, Aspect of the Cheetah, Freezing Trap ve yeni rank'lar.",
        train40 = "Yeni rank'lar. Feign Death çok önemli (aggro sıfırlama, Freezing Trap yerleştirme).",
        milestones = {
            [10] = "10: Pet taming görevi hunter eğitmeninden; 3 farklı hayvanı evcilleştir, kendi pet'ini seç.",
        },
    },
    WARLOCK = {
        label = "Warlock",
        trainers = {
            { m = DUROTAR, x = 42.0, y = 69.0, n = "Nartok (Valley of Trials)" },
            { m = ORGRIMMAR, x = 48.2, y = 45.5, n = "Orgrimmar, Cleft of Shadow" },
            { m = TBLUFF, x = 25.0, y = 14.5, n = "Thunder Bluff, Pools of Vision" },
            { m = UNDERCITY, x = 85.1, y = 25.6, n = "Undercity, Magic Quarter" },
            { m = TIRISFAL, x = 62.3, y = 52.4, n = "Ageron Kargal (Brill)" },
        },
        markers = { "Shadow Bolt", "Corruption", "Bane of Agony", "Immolate", "Drain Life", "Life Tap", "Fear", "Summon Voidwalker", "Rain of Fire" },
        skip = {
            ["Curse of Weakness"] = true, ["Detect Invisibility"] = true, ["Unending Breath"] = true,
            ["Eye of Kilrogg"] = true, ["Ritual of Summoning"] = true,
        },
        skipAfter10 = {},
        singleRank = {},
        buffs = {
            { n = "Demon Armor", ids = { 706, 1086, 11733, 11734, 11735 } },
        },
        supply = "healthstone",
        talents = expand({
            -- Affliction leveling (Forever): Imp. Corruption → Suppression → Demonology dip → drain tank
            { 10, 14, "Improved Corruption", 5 }, { 15, 19, "Suppression", 5 },
            -- 20-26: Demonology dip for pet sustain
            { 20, 24, "Unholy Power", 5 }, { 25, 26, "Demonic Energies", 2 },
            -- 27-30: back to Affliction
            { 27, 29, "Improved Drains", 3 }, { 30, 30, "Amplify Curse", 1 },
            -- 31-40: Affliction core
            { 31, 32, "Improved Bane of Agony", 2 }, { 33, 34, "Improved Life Tap", 2 },
            { 35, 37, "Pandemic", 3 }, { 38, 40, "Soul Siphon", 3 },
            -- 41-60: heavy Affliction
            { 41, 41, "Siphon Life", 1 }, { 42, 46, "Malevolence", 5 }, { 47, 51, "Shadow Mastery", 5 },
            { 52, 54, "Fel Concentration", 3 }, { 55, 56, "Nightfall", 2 },
            { 57, 59, "Improved Shadow Bolt", 3 },
        }, "serbest puan — 60 raid build: SM/Ruin (30/0/21)"),
        talentNotes = {
            "Pet'i gönder → Bane of Agony → Corruption → Immolate → wand (30 öncesi) veya Drain Life (30 sonrası).",
            "30+: Drain tanking başlıyor; Life Tap ile mana al, Drain Life ile can al — durma yok.",
            "Siphon Life (41) ile DoT sayısı artar, her mob'dan can gelir; AoE'de Rain of Fire + DoT'lar.",
            "Forever: Bane ve Curse ayrıldı, aynı hedefe ikisini birden koyabilirsin.",
            "Forever: DoT'lar krit yapabilir, Drain Soul her tick'te Soul Shard üretebilir.",
        },
        train20 = "Drain Life, Succubus quest, Rain of Fire ve yeni rank'lar. Drain Life öğren!",
        train40 = "Felsteed (ücretsiz binek!), yeni rank'lar.",
        milestones = {
            [10] = "10: Voidwalker quest — warlock eğitmeninden; Voidwalker en iyi leveling pet'i (tank).",
            [20] = "20: Succubus quest — warlock eğitmeninden; CC yeteneği.",
            [40] = "40: Felsteed quest — ücretsiz binek! Altın biriktirmene gerek yok.",
        },
    },
    ROGUE = {
        label = "Rogue",
        trainers = {
            { m = DUROTAR, x = 43.6, y = 68.9, n = "Rwag (Valley of Trials)" },
            { m = DUROTAR, x = 52.1, y = 43.3, n = "Kru'gar (Razor Hill)" },
            { m = ORGRIMMAR, x = 44.1, y = 55.2, n = "Orgrimmar, Cleft of Shadow" },
            { m = TBLUFF, x = 59.4, y = 51.4, n = "Thunder Bluff" },
            { m = UNDERCITY, x = 84.1, y = 74.0, n = "Undercity, Rogues' Quarter" },
            { m = TIRISFAL, x = 65.1, y = 60.5, n = "Marion Call (Brill)" },
        },
        markers = { "Sinister Strike", "Eviscerate", "Stealth", "Backstab", "Gouge", "Kick", "Slice and Dice", "Sprint", "Vanish" },
        skip = {
            ["Pick Pocket"] = true, ["Pick Lock"] = true, ["Detect Traps"] = true, ["Distract"] = true,
            ["Safe Fall"] = true, ["Blinding Powder"] = true,
        },
        skipAfter10 = {},
        singleRank = {},
        buffs = {},
        supply = "bandage",
        talents = expand({
            -- Combat leveling (Forever)
            { 10, 11, "Remorseless Attacks", 2 }, { 12, 13, "Improved Sinister Strike", 2 },
            { 14, 16, "Improved Eviscerate", 3 }, { 17, 19, "Puncturing Wounds", 3 },
            { 20, 22, "Deflection", 3 }, { 23, 23, "Riposte", 1 },
            { 24, 26, "Precision", 3 }, { 27, 27, "Flawless Execution", 1 },
            { 28, 30, "Dual Wield Specialization", 3 },
            -- 30+: Blade Flurry, deeper Combat
            { 31, 31, "Blade Flurry", 1 }, { 32, 34, "Aggression", 3 },
            { 35, 35, "Flash of Steel", 1 }, { 36, 38, "Weapon Expertise", 3 },
            { 39, 39, "Hack and Slash", 1 }, { 40, 40, "Adrenaline Rush", 1 },
            -- 40+: fill out
            { 41, 43, "Improved Slice and Dice", 3 }, { 44, 46, "Composure", 3 },
            { 47, 51, "Malice (Assassination)", 5 }, { 52, 54, "Ruthlessness (Assassination)", 3 },
            { 55, 55, "Relentless Strikes (Assassination)", 1 },
            { 56, 59, "Lethality (Assassination)", 4 },
        }, "serbest puan — 60 raid build: Combat Swords (19/32/0)"),
        talentNotes = {
            "Stealth → Cheap Shot / Ambush → Sinister Strike → Slice and Dice (2CP) → Sinister Strike → Eviscerate (4-5 CP).",
            "Blade Flurry (31): AoE ve tek hedef DPS artışı — cooldown'da sürekli kullan.",
            "Adrenaline Rush (40): enerji taşması — burst anlarında ve zor mob'larda.",
            "Forever: Shank yeni bir yetenek, ekstra enerji verir. Zehirler krit yapabilir.",
            "Crit > Agility > AP > Strength. Hızlı silahlar (1.4-1.8) daha fazla zehir proc'u.",
        },
        train20 = "Yeni rank'lar ve Poisons quest — Orgrimmar Cleft of Shadow'dan başlar; zehirler büyük DPS artışı.",
        train40 = "Yeni rank'lar.",
        milestones = {
            [20] = "20: Poison quest — rogue eğitmeninden; Instant Poison ana silahta, Deadly Poison yan silahta.",
            [22] = "22: Vanish — hayatta kalma ve Sap/Cheap Shot resetleme.",
        },
    },
    SHAMAN = {
        label = "Shaman",
        trainers = {
            { m = DUROTAR, x = 42.0, y = 69.0, n = "Shikrik (Valley of Trials)" },
            { m = DUROTAR, x = 52.4, y = 42.2, n = "Swart (Razor Hill)" },
            { m = ORGRIMMAR, x = 38.3, y = 36.1, n = "Orgrimmar, Valley of Spirits" },
            { m = TBLUFF, x = 22.5, y = 20.5, n = "Thunder Bluff, Spirit Rise" },
            { m = MULGORE, x = 26.3, y = 24.5, n = "Seer Ravenfeather (Camp Narache)" },
        },
        markers = { "Lightning Bolt", "Earth Shock", "Flame Shock", "Stormstrike", "Lightning Shield", "Healing Wave", "Windfury Weapon", "Searing Totem", "Strength of Earth Totem" },
        skip = {
            ["Astral Recall"] = true, ["Purge"] = true, ["Far Sight"] = true,
            ["Stoneclaw Totem"] = true, ["Sentry Totem"] = true,
        },
        skipAfter10 = { ["Lightning Bolt"] = true },
        singleRank = {},
        buffs = {
            { n = "Lightning Shield", ids = { 324, 325, 905, 945, 8134, 10431, 10432 } },
        },
        supply = "bandage",
        talents = expand({
            -- Enhancement leveling (Forever)
            { 10, 14, "Thundering Strikes", 5 }, { 15, 17, "Mental Dexterity", 3 },
            { 18, 19, "Improved Ghost Wolf", 2 }, { 20, 20, "Shamanistic Focus", 1 },
            { 21, 23, "Elemental Weapons", 3 }, { 24, 24, "Ancestral Knowledge", 1 },
            { 25, 25, "Stormstrike", 1 }, { 26, 29, "Flurry", 4 },
            { 30, 30, "Improved Stormstrike", 2, 1 },
            -- 30+: deeper Enhancement
            { 31, 35, "Weapon Mastery", 5 }, { 36, 38, "Dual Wield", 3 },
            { 39, 39, "Dual Wield Specialization", 1 },
            { 40, 40, "Shamanistic Rage", 1 },
            -- 40+: fill out and dip Elemental/Restoration
            { 41, 45, "Maelstrom Weapon", 5 }, { 46, 48, "Spirit Weapons", 3 },
            { 49, 53, "Toughness", 5 }, { 54, 58, "Anticipation", 5 },
            { 59, 59, "Improved Stormstrike", 2, 2 },
        }, "serbest puan — 60 raid build: Enhancement (0/44/7)"),
        talentNotes = {
            "Lightning Shield + Windfury Weapon sürekli açık; Searing + Strength of Earth totem her savaşta.",
            "Lightning Bolt ile çek → Flame Shock → Stormstrike CD'de → Earth Shock doldurucu.",
            "30: Windfury Weapon — dev vuruşlar, yavaş iki elli silah kullan (yavaş = daha büyük WF proc).",
            "Maelstrom Weapon (41+): 5 yığınla anında Lightning Bolt / Healing Wave — çok güçlü.",
            "Forever: Totem twisting yok, Call of the Elements ile 4 totem tek tuş; Ghost Wolf iç mekanda çalışır.",
        },
        train20 = "Ghost Wolf, yeni totemler ve rank'lar. Ghost Wolf bineğe kadar hız demek.",
        train40 = "Yeni rank'lar. Dual Wield — iki silah kullanmaya geç!",
        milestones = {
            [4] = "4: İlk totem görevleri (Earth, Fire, Water, Air) — eğitmenlerden; her biri totem tipini açar.",
            [20] = "20: Ghost Wolf — anında form değişimi (Improved Ghost Wolf talentiyle); bineğe kadar %40 hız.",
            [30] = "30: Windfury Weapon — Enhancement'ın kalbi; yavaş, ağır silah kullan.",
        },
    },
    PRIEST = {
        label = "Priest",
        trainers = {
            { m = DUROTAR, x = 42.0, y = 69.0, n = "Ken'jai (Valley of Trials)" },
            { m = ORGRIMMAR, x = 35.6, y = 87.7, n = "Orgrimmar, Valley of Spirits" },
            { m = TBLUFF, x = 25.4, y = 14.8, n = "Thunder Bluff, Spirit Rise" },
            { m = UNDERCITY, x = 49.0, y = 18.5, n = "Undercity, War Quarter" },
            { m = TIRISFAL, x = 61.8, y = 52.4, n = "Dark Cleric Beryl (Brill)" },
        },
        markers = { "Shadow Word: Pain", "Mind Blast", "Mind Flay", "Power Word: Shield", "Renew", "Psychic Scream", "Devouring Plague", "Vampiric Embrace", "Shadowform" },
        skip = {
            ["Levitate"] = true, ["Mind Soothe"] = true, ["Shackle Undead"] = true,
            ["Holy Fire"] = true, ["Smite"] = true,
        },
        skipAfter10 = { ["Smite"] = true },
        singleRank = {},
        buffs = {
            { n = "Power Word: Fortitude", ids = { 1243, 1244, 1245, 2791, 10937, 10938 } },
            { n = "Inner Fire", ids = { 588, 7128, 602, 1006, 10951, 10952 } },
        },
        supply = "bandage",
        talents = expand({
            -- Shadow leveling (Forever): Discipline dip then Shadow
            { 10, 11, "Wand Specialization (Discipline)", 2 }, { 12, 14, "Twin Disciplines", 3 },
            { 15, 19, "Spirit Tap (Shadow)", 5 },
            { 20, 20, "Mind Flay (Shadow)", 1 }, { 21, 22, "Improved Shadow Word: Pain", 2 },
            { 23, 25, "Shadow Focus", 3 }, { 26, 27, "Improved Mind Flay", 2 },
            { 28, 28, "Improved Mind Blast", 1 }, { 29, 29, "Shadow Weaving", 3, 1 },
            { 30, 30, "Vampiric Embrace", 1 },
            -- 30+: deeper Shadow
            { 31, 31, "Devouring Contagion", 1 }, { 32, 32, "Silence", 1 },
            { 33, 37, "Darkness", 5 }, { 38, 39, "Shadow Weaving", 3, 2 },
            { 40, 40, "Shadowform", 1 },
            -- 40+: Shadow mastery + Discipline dip
            { 41, 43, "Shadow Power", 3 }, { 44, 46, "Misery", 3 },
            { 47, 49, "Improved Vampiric Embrace", 3 },
            { 50, 54, "Meditation (Discipline)", 5 },
            { 55, 57, "Mental Agility (Discipline)", 3 },
            { 58, 59, "Improved Power Word: Shield (Discipline)", 2 },
        }, "serbest puan — 60 raid build: Shadow (13/0/38)"),
        talentNotes = {
            "Wand + DoT oyunu: SW:Pain → Mind Blast → Mind Flay (20+) → wand; Spirit Tap mana doldurur.",
            "Vampiric Embrace (30): tüm Shadow hasarın seni iyileştirir — durma yok, mob'dan mob'a.",
            "Shadowform (40): %15 Shadow hasar artışı, %15 hasar azaltma — oyun değişir.",
            "Forever: DoT'lar dinamik güncellenir (snapshot yok), profession büyüler daha etkili.",
            "Intellect + Spell Power/Shadow > Spirit > Stamina. Wand DPS 30'a kadar çok önemli.",
        },
        train20 = "Mind Flay (talent ise zaten alınıyor), Holy Fire, yeni rank'lar.",
        train40 = "Shadowform (talent), yeni rank'lar.",
        milestones = {
            [20] = "20: Mind Flay (Shadow talent) — ana doldurucu yetenek; yoksa wand kullan.",
            [30] = "30: Vampiric Embrace — hasarın seni iyileştirir; downtime neredeyse sıfır.",
            [40] = "40: Shadowform — %15 Shadow hasar ve %15 fiziksel hasar azaltma; endgame başlangıcı.",
        },
    },
    PALADIN = {
        label = "Paladin",
        trainers = {
            { m = ORGRIMMAR, x = 49.5, y = 89.0, n = "Orgrimmar, Valley of Spirits" },
            { m = UNDERCITY, x = 57.4, y = 7.8, n = "Undercity" },
            -- Blood Elf trainers (Forever: Horde Paladin = Blood Elf)
            { m = 1941, x = 81.7, y = 42.3, n = "Noellene (Sunstrider Isle)" },
            { m = 1942, x = 79.1, y = 52.1, n = "Jesthenis Sunstriker (Falconwing Square)" },
            { m = 1942, x = 48.0, y = 35.5, n = "Champion Bachi (Silvermoon City)" },
        },
        markers = { "Seal of Righteousness", "Judgement", "Holy Strike", "Blessing of Might", "Consecration", "Hammer of Justice", "Flash of Light", "Divine Shield", "Seal of Command" },
        skip = {
            ["Blessing of Protection"] = true, ["Turn Undead"] = true, ["Sense Undead"] = true,
        },
        skipAfter10 = {},
        singleRank = {},
        buffs = {
            { n = "Blessing of Might", ids = { 19740, 19834, 19835, 19836, 19837, 19838, 25291 } },
        },
        supply = "bandage",
        talents = expand({
            -- Retribution leveling (Forever)
            { 10, 14, "Benediction", 5 }, { 15, 19, "Conviction", 5 },
            { 20, 20, "Seal of Command", 1 }, { 21, 22, "Pursuit of Justice", 2 },
            { 23, 24, "Sanctified Judgement", 2 }, { 25, 25, "Sacred Arbiter", 1 },
            { 26, 30, "Vengeance", 5 },
            -- 30+: deeper Retribution
            { 31, 35, "Two-Handed Weapon Specialization", 5 },
            { 36, 36, "Sanctity Aura", 1 }, { 37, 39, "Improved Sanctity Aura", 3 },
            { 40, 40, "Repentance", 1 },
            -- 40+: Holy dip for sustainability
            { 41, 45, "Divine Strength (Holy)", 5 }, { 46, 50, "Divine Intellect (Holy)", 5 },
            { 51, 53, "Improved Seal of Righteousness (Holy)", 3 },
            { 54, 58, "Illumination (Holy)", 5 }, { 59, 59, "Spiritual Focus (Holy)", 3, 1 },
        }, "serbest puan — 60 raid build: Ret (11/0/40) veya Healadin (31/8/12)"),
        talentNotes = {
            "Seal of Command (20) + yavaş iki elli silah = dev vuruşlar; Judgement + Holy Strike cooldown'da kullan.",
            "Blessing of Might ve Retribution Aura sürekli açık; Seal of Righteousness tek elle veya hızlı silahla.",
            "Repentance (40): CC yeteneği, zindan ve zor mob'larda; Hammer of Justice ile birlikte kullan.",
            "Forever: Seal of Command ile Judgement + Stun = neredeyse çift hasar (stunned hedefe bonuslu).",
            "Strength > Stamina > Spell Power > Int. Yavaş, ağır iki elli silah her zaman en iyisi.",
        },
        train20 = "Yeni Seal'lar ve rank'lar.",
        train40 = "Charger (Paladin bineği — quest zinciri, çoğunlukla ücretsiz).",
        milestones = {
            [12] = "12: Redemption — ölü oyuncuyu diriltme; grup oyununda şart.",
            [20] = "20: Seal of Command (Retribution talent) — dev proc'lu vuruşlar; oyun değişir.",
            [40] = "40: Charger quest veya binek satın al; Repentance (talent) = CC.",
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
