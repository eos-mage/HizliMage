-- Zindan görev rehberi: her zindan için alınması gereken Horde görevleri.
-- /hm zindan → seviyeye uygun zindanlar + görevleri, /hm zindan <ad> → belirli zindan detayı.
-- Giriş hatırlatması: seviyeye uygun bir zindanın görevleri eksikse uyarır.

local ADDON, ns = ...
local HM = ns.HM
local Dungeons = {}
HM.Dungeons = Dungeons

local OK, BAD, WARN = "|cff80ff80+|r ", "|cffff6060x|r ", "|cffffd100!|r "

---------------------------------------------------------------------------
-- Zindan görev veritabanı (Horde + Neutral, Classic/Forever)
-- q = görev adı, npc = görev veren, loc = nereden alınır, lvl = min seviye,
-- pre = ön koşul açıklaması (nil = yok), qid = görev kimliği (biliniyorsa)
---------------------------------------------------------------------------
-- Diğer modüller (örn. DungeonPanel) adı DUNGEON_QUESTS[name] üzerinden okuyabilsin.
local DUNGEON_QUESTS
DUNGEON_QUESTS = {
    ["Ragefire Chasm"] = {
        tag = "RFC", minLvl = 13, maxLvl = 18, short = "Orgrimmar icindeki ilk zindan",
        quests = {
            { q = "Testing an Enemy's Strength",  npc = "Rahauro",          loc = "Thunder Bluff, Elder Rise",       lvl = 9, qid = 5723 },
            { q = "Searching for the Lost Satchel", npc = "Rahauro",        loc = "Thunder Bluff, Elder Rise",       lvl = 9, qid = 5722, note = "Devami icerde" },
            { q = "Slaying the Beast",             npc = "Neeru Fireblade", loc = "Orgrimmar, Cleft of Shadow",      lvl = 9, qid = 5761 },
            { q = "The Power to Destroy...",       npc = "Varimathras",     loc = "Undercity, Royal Quarter",        lvl = 9, qid = 5725 },
            { q = "Hidden Enemies",                npc = "Thrall",          loc = "Orgrimmar, Valley of Wisdom",     lvl = 9, qid = 5726, pre = "Thrall zincir gorevi" },
        },
    },
    ["Wailing Caverns"] = {
        tag = "WC", minLvl = 17, maxLvl = 24, short = "Barrens, en cok gorev veren erken zindan",
        quests = {
            { q = "Serpentbloom",                  npc = "Apothecary Zamah", loc = "Thunder Bluff, Pools of Vision", lvl = 14, qid = 962 },
            { q = "Leaders of the Fang",           npc = "Nara Wildmane",    loc = "Thunder Bluff, Elder Rise",      lvl = 10, qid = 914, pre = "Forgotten Pools zinciri (Crossroads)" },
            { q = "Deviate Hides",                 npc = "Nalpak",           loc = "WC girisi (dis mekan)",          lvl = 13, qid = 1486 },
            { q = "Deviate Eradication",           npc = "Ebru",             loc = "WC girisi (dis mekan)",          lvl = 15, qid = 1487 },
            { q = "Smart Drinks",                  npc = "Mebok Mizzyrix",   loc = "Ratchet",                        lvl = 13, qid = 1491 },
            { q = "Trouble at the Docks",          npc = "Crane Operator Bigglefuzz", loc = "Ratchet",              lvl = 14, qid = 959 },
        },
    },
    ["Shadowfang Keep"] = {
        tag = "SFK", minLvl = 18, maxLvl = 24, short = "Silverpine Forest, Undead dostu zindan",
        quests = {
            { q = "Deathstalkers in Shadowfang",   npc = "High Executor Hadrec", loc = "The Sepulcher, Silverpine",  lvl = 18, qid = 1098 },
            { q = "The Book of Ur",                npc = "Keeper Bel'dugur",     loc = "Undercity, Apothecarium",    lvl = 16, qid = 1013 },
            { q = "Arugal Must Die",               npc = "Dalar Dawnweaver",     loc = "The Sepulcher, Silverpine",  lvl = 18, qid = 1014 },
        },
    },
    ["Blackfathom Deeps"] = {
        tag = "BFD", minLvl = 22, maxLvl = 28, short = "Ashenvale kuzey kiyisi, su alti zindan",
        quests = {
            { q = "The Essence of Aku'Mai",        npc = "Je'neu Sancrea",   loc = "Zoram Strand, Ashenvale",       lvl = 17, qid = 6563, pre = "Trouble in the Deeps (Sunrock Retreat)" },
            { q = "Amongst the Ruins",             npc = "Je'neu Sancrea",   loc = "Zoram Strand, Ashenvale",       lvl = 21, qid = 6921 },
            { q = "Allegiance to the Old Gods",    npc = "Je'neu Sancrea",   loc = "Zoram Strand, Ashenvale",       lvl = 21, qid = 6565, pre = "Damp Note (dis mekandan)" },
            { q = "Blackfathom Villainy",          npc = "Argent Guard Thaelrid", loc = "BFD icinde",               lvl = 18, qid = 6561 },
        },
    },
    ["Razorfen Kraul"] = {
        tag = "RFK", minLvl = 26, maxLvl = 32, short = "Barrens guneyi, quilboar zindani",
        quests = {
            { q = "Going, Going, Guano!",          npc = "Master Apothecary Faranell", loc = "Undercity, Apothecarium", lvl = 30, qid = 1109 },
            { q = "A Vengeful Fate",               npc = "Auld Stonespire",  loc = "Thunder Bluff",                 lvl = 29, qid = 1102 },
            { q = "Mortality Wanes",               npc = "Heralath Fallowbrook", loc = "RFK girisi",                lvl = 26 },
            { q = "Willix the Importer",           npc = "Willix (icerde)",  loc = "RFK icinde (escort)",           lvl = 26, qid = 1144 },
        },
    },
    ["Gnomeregan"] = {
        tag = "Gnomer", minLvl = 26, maxLvl = 34, short = "Dun Morogh, Alliance bolgesi — teleport ile gidilir",
        quests = {
            { q = "Rig Wars",                      npc = "Nogg",             loc = "Orgrimmar, Valley of Honor",    lvl = 25, qid = 2841 },
            { q = "Chief Engineer Scooty",         npc = "Sovik",            loc = "Orgrimmar, Valley of Honor",    lvl = 20, qid = 2842, pre = "Rig Wars (teleport acilir)" },
        },
    },
    ["Scarlet Monastery"] = {
        tag = "SM", minLvl = 30, maxLvl = 40, short = "Tirisfal Glades, 4 kanatli zindan — en iyi XP/loot",
        quests = {
            { q = "Hearts of Zeal",                npc = "Master Apothecary Faranell", loc = "Undercity, Apothecarium", lvl = 30, qid = 1113, pre = "Going, Going, Guano! (RFK)" },
            { q = "Compendium of the Fallen",      npc = "Sage Truthseeker", loc = "Thunder Bluff",                 lvl = 28, qid = 1049 },
            { q = "Into The Scarlet Monastery",    npc = "Varimathras",      loc = "Undercity, Royal Quarter",       lvl = 33, qid = 1048 },
            { q = "Vorrel's Revenge",              npc = "Vorrel Sengutz",   loc = "SM Graveyard icinde",           lvl = 25, qid = 1051 },
            { q = "Test of Lore",                  npc = "Parqual Fintallas", loc = "Undercity, Apothecarium",      lvl = 25, qid = 1160, pre = "Uzun zincir: Test of Faith (Thousand Needles)" },
            { q = "Mythology of the Titans",       npc = "Librarian Mae Paledust", loc = "Ironforge (neutral gorev)", lvl = 28, note = "Neutral, Library boss'u icin" },
        },
    },
    ["Razorfen Downs"] = {
        tag = "RFD", minLvl = 34, maxLvl = 40, short = "Barrens guneyi, undead quilboar zindani",
        quests = {
            { q = "An Unholy Alliance",            npc = "Varimathras",      loc = "Undercity, Royal Quarter",       lvl = 28, qid = 6521, pre = "RFK'dan Small Scroll zinciri" },
            { q = "Bring the End",                 npc = "Andrew Brownell",  loc = "Undercity, Magic Quarter",       lvl = 37, qid = 3341 },
            { q = "A Host of Evil",                npc = "Myriam Moonsinger", loc = "Ratchet, The Barrens",         lvl = 28, qid = 6626 },
        },
    },
    ["Uldaman"] = {
        tag = "Ulda", minLvl = 40, maxLvl = 46, short = "Badlands, titan kalintilarinda arkeoloji zindani",
        quests = {
            { q = "Uldaman Reagent Run",           npc = "Jarkal Mossmeld",  loc = "Kargath, Badlands",             lvl = 36, qid = 2202, pre = "Badlands Reagent Run" },
            { q = "Reclaimed Treasures",           npc = "Patrick Garrett",  loc = "Undercity",                     lvl = 33, qid = 2342 },
            { q = "Necklace Recovery",             npc = "Dran Droffers",    loc = "Orgrimmar, The Drag",           lvl = 37, qid = 2283, pre = "Shattered Necklace item dropi" },
            { q = "Solution to Doom",              npc = "Theldurin the Lost", loc = "Badlands (dis mekan)",        lvl = 30, qid = 709, note = "Neutral" },
            { q = "The Platinum Discs",            npc = "Discs of Norgannon", loc = "Uldaman son odasi (icerde)", lvl = 40, qid = 2278, note = "Neutral, Thunder Bluff'a teslim" },
        },
    },
    ["Zul'Farrak"] = {
        tag = "ZF", minLvl = 44, maxLvl = 50, short = "Tanaris, trol tapinagi — stairway event cok XP",
        quests = {
            { q = "The Spider God",                npc = "Master Gadrin",    loc = "Sen'jin Village, Durotar",      lvl = 40, qid = 2936, pre = "Venom Bottles zinciri (Hinterlands)" },
            { q = "Gahz'rilla",                    npc = "Wizzle Brassbolts", loc = "Shimmering Flats",            lvl = 40, qid = 2770, note = "Mallet of Zul'Farrak gerekli (Hinterlands)" },
            { q = "Scarab Shells",                 npc = "Tran'rek",         loc = "Gadgetzan, Tanaris",            lvl = 40, qid = 2865 },
            { q = "Troll Temper",                  npc = "Trenton Lighthammer", loc = "Gadgetzan, Tanaris",         lvl = 40, qid = 3042 },
            { q = "Tiara of the Deep",             npc = "Tabetha",          loc = "Dustwallow Marsh",              lvl = 40, qid = 2846 },
            { q = "Divino-matic Rod",              npc = "Chief Engineer Bilgewhizzle", loc = "Gadgetzan, Tanaris", lvl = 40, qid = 2768 },
            { q = "The Prophecy of Mosh'aru",      npc = "Yeh'kinya",        loc = "Steamwheedle Port, Tanaris",    lvl = 40, qid = 3527, pre = "Screecher Spirits zinciri" },
        },
    },
    ["Maraudon"] = {
        tag = "Mara", minLvl = 46, maxLvl = 52, short = "Desolace, iki girisli dev zindan — Princess cok loot",
        quests = {
            { q = "Shadowshard Fragments",         npc = "Uthel'nay",        loc = "Orgrimmar, Valley of Spirits",  lvl = 39, qid = 7068 },
            { q = "Vyletongue Corruption",         npc = "Vark Battlescar",  loc = "Shadowprey Village, Desolace",  lvl = 41, qid = 7029 },
            { q = "Corruption of Earth and Seed",  npc = "Selendra",         loc = "Shadowprey Village, Desolace",  lvl = 45, qid = 7064 },
            { q = "Twisted Evils",                 npc = "Willow",           loc = "Kormek's Hut, Desolace",        lvl = 41, qid = 7028, note = "Neutral" },
            { q = "Legends of Maraudon",           npc = "Cavindra",         loc = "Mara magarasi girisi (dis)",    lvl = 41, qid = 7044, note = "Neutral, Noxxion + Vyletongue droplari" },
        },
    },
    ["Sunken Temple"] = {
        tag = "ST", minLvl = 50, maxLvl = 55, short = "Swamp of Sorrows, labirent + ejderha patronu",
        quests = {
            { q = "The Temple of Atal'Hakkar",     npc = "Fel'zerul",        loc = "Stonard, Swamp of Sorrows",     lvl = 38, qid = 1445, pre = "Pool of Tears zinciri" },
            { q = "The Sunken Temple",             npc = "Witch Doctor Uzer'i", loc = "Camp Mojache, Feralas",      lvl = 46, qid = 3380 },
            { q = "Into the Depths",               npc = "Marvon Rivetseeker", loc = "Broken Pillar, Tanaris",      lvl = 46, qid = 3446, note = "Neutral" },
            { q = "Jammal'an the Prophet",         npc = "Atal'ai Exile",    loc = "Shadra'Alor, Hinterlands",      lvl = 38, qid = 1446, note = "Neutral" },
            { q = "The God Hakkar",                npc = "Yeh'kinya",        loc = "Steamwheedle Port, Tanaris",    lvl = 40, qid = 3528, pre = "Screecher Spirits, ZF gorevleri" },
            { q = "The Essence of Eranikus",       npc = "Drop (icerde)",    loc = "Shade of Eranikus boss dropi",  lvl = 48, qid = 3373, note = "Neutral" },
        },
    },
    ["Blackrock Depths"] = {
        tag = "BRD", minLvl = 52, maxLvl = 60, short = "Blackrock Mountain, en buyuk zindan — pek cok gorev",
        quests = {
            { q = "The Last Element",              npc = "Vivian Lagrave",   loc = "Kargath, Badlands",             lvl = 48, qid = 7201 },
            { q = "Lost Thunderbrew Recipe",       npc = "Vivian Lagrave",   loc = "Kargath, Badlands",             lvl = 50, qid = 4134, pre = "Apothecary Zinge (Undercity)" },
            { q = "Disharmony of Flame",           npc = "Thunderheart",     loc = "Kargath, Badlands",             lvl = 48, qid = 3906 },
            { q = "KILL ON SIGHT: Dark Iron Dwarves", npc = "Arilan",        loc = "Kargath (poster)",              lvl = 48, qid = 4081 },
            { q = "Commander Gor'shak",            npc = "Galamav the Marksman", loc = "Kargath, Badlands",         lvl = 48, qid = 3981, pre = "Disharmony of Flame" },
            { q = "The Royal Rescue",              npc = "Thrall",           loc = "Orgrimmar",                     lvl = 48, qid = 4003 },
            { q = "Ribbly Screwspigot",            npc = "Yuka Screwspigot", loc = "Flame Crest, Burning Steppes", lvl = 48, qid = 4136, note = "Neutral" },
            { q = "The Heart of the Mountain",     npc = "Maxwort Uberglint", loc = "Flame Crest, Burning Steppes", lvl = 50, qid = 4123, note = "Neutral" },
        },
    },
    ["Dire Maul"] = {
        tag = "DM", minLvl = 56, maxLvl = 60, short = "Feralas, uc kanatli 60 zindani — tribute run",
        quests = {
            { q = "Lethtendris's Web",             npc = "Talo Thornhoof",   loc = "Camp Mojache, Feralas",         lvl = 54, qid = 7489 },
            { q = "Elven Legends",                 npc = "Sage Korolusk",    loc = "Camp Mojache, Feralas",         lvl = 54, qid = 7481 },
            { q = "Pusillin and the Elder Azj'Tordin", npc = "Azj'Tordin",   loc = "Lariss Pavilion, Feralas",      lvl = 54, qid = 7441, note = "Neutral" },
            { q = "The Gordok Ogre Suit",          npc = "Knot Thimblejack", loc = "DM North (icerde)",             lvl = 56, qid = 5518, note = "Neutral, Tribute Run icin" },
        },
    },
    ["Scholomance"] = {
        tag = "Scholo", minLvl = 58, maxLvl = 60, short = "Western Plaguelands, undead okulu",
        quests = {
            { q = "Scholomance",                   npc = "High Executor Derrington", loc = "The Bulwark, Tirisfal",  lvl = 55, qid = 838, pre = "All Along the Watchtowers" },
            { q = "Barov Family Fortune",          npc = "Alexi Barov",      loc = "The Bulwark, Tirisfal",         lvl = 52, qid = 5341 },
            { q = "Plagued Hatchlings",            npc = "Betina Bigglezink", loc = "Light's Hope Chapel, EPL",     lvl = 55, qid = 5529, note = "Neutral" },
            { q = "Doctor Theolen Krastinov",      npc = "Eva Sarkhoff",     loc = "Caer Darrow, WPL",              lvl = 55, qid = 5382, note = "Neutral" },
        },
    },
    ["Stratholme"] = {
        tag = "Strat", minLvl = 58, maxLvl = 60, short = "Eastern Plaguelands, Living/Undead tarafi",
        quests = {
            { q = "Ramstein",                      npc = "Nathanos Blightcaller", loc = "Blightcaller'in evi, EPL", lvl = 56, qid = 6163, pre = "The Corpulent One zinciri" },
            { q = "The Great Fras Siabi",          npc = "Smokey LaRue",     loc = "Light's Hope Chapel, EPL",      lvl = 55, qid = 5214, note = "Neutral, Living tarafi" },
            { q = "The Archivist",                 npc = "Duke Nicholas Zverenhoff", loc = "Light's Hope Chapel, EPL", lvl = 55, qid = 5251, note = "Neutral" },
            { q = "The Flesh Does Not Lie",        npc = "Betina Bigglezink", loc = "Light's Hope Chapel, EPL",     lvl = 55, qid = 5212, note = "Neutral, Undead tarafi" },
            { q = "Houses of the Holy",            npc = "Leonid Barthalomew", loc = "Light's Hope Chapel, EPL",    lvl = 55, qid = 5243, note = "Neutral, Undead tarafi" },
            { q = "Above and Beyond",              npc = "Duke Nicholas Zverenhoff", loc = "Light's Hope Chapel, EPL", lvl = 55, qid = 5263, note = "Baron Rivendare icin" },
        },
    },
}

---------------------------------------------------------------------------
-- Görev tamamlama kontrolü
---------------------------------------------------------------------------
-- Görev durumu: "done" (tamamlanmış), "active" (logda/devam ediyor), nil (alınmamış)
local function questStatus(questName, qid)
    -- 1) qid ile tamamlanmış mı
    if qid then
        if C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then
            local ok, done = pcall(C_QuestLog.IsQuestFlaggedCompleted, qid)
            if ok and done then return "done" end
        end
    end
    -- 2) HM.db.doneQ'da var mı (addon'un kendi kayıtları)
    if qid and HM.db and HM.db.doneQ and HM.db.doneQ[qid] then return "done" end
    -- 3) görev logunda aktif mi
    if C_QuestLog and C_QuestLog.GetNumQuestLogEntries then
        local ok, n = pcall(C_QuestLog.GetNumQuestLogEntries)
        if ok and n then
            for i = 1, n do
                local info
                if C_QuestLog.GetInfo then
                    local ok2, inf = pcall(C_QuestLog.GetInfo, i)
                    if ok2 and inf then info = inf end
                end
                if info then
                    if info.title == questName then return "active" end
                    -- qid ile de kontrol (isComplete alanı varsa)
                    if qid and info.questID == qid then
                        if info.isComplete then return "done" end
                        return "active"
                    end
                end
            end
        end
    end
    -- yedek: GetQuestLogTitle
    if GetQuestLogTitle then
        for i = 1, (GetNumQuestLogEntries and GetNumQuestLogEntries() or 25) do
            local ok, title, _, _, _, _, isComplete, questID = pcall(GetQuestLogTitle, i)
            if ok then
                if title == questName then
                    if isComplete then return "done" end
                    return "active"
                end
                if qid and questID == qid then
                    if isComplete then return "done" end
                    return "active"
                end
            end
        end
    end
    return nil
end

-- Eski API uyumluluk sarmalayıcılar (popup ve sayaç için)
local function isQuestDone(questName, qid)
    return questStatus(questName, qid) == "done"
end

local function isQuestInLog(questName, qid)
    local s = questStatus(questName, qid)
    return s == "active" or s == "done"
end

---------------------------------------------------------------------------
-- Zindan görev listesi yazdırma
---------------------------------------------------------------------------
local function matchDungeon(query)
    query = query:lower()
    for name, data in pairs(DUNGEON_QUESTS) do
        if name:lower():find(query, 1, true) or data.tag:lower():find(query, 1, true) then
            return name, data
        end
    end
    return nil
end

local function printDungeonQuests(name, data)
    local level = HM:Level()
    HM:Print(string.format("|cff33ccff— %s (%s) sev. %d-%d —|r", name, data.tag, data.minLvl, data.maxLvl))
    HM:Print("  " .. data.short)
    local missing, done, active = 0, 0, 0
    for _, q in ipairs(data.quests) do
        local tooLow = level < q.lvl
        local status = questStatus(q.q, q.qid)
        local icon, nameColor
        if status == "done" then
            icon = OK;  nameColor = "|cff80ff80"  -- yeşil: tamamlanmış
            done = done + 1
        elseif status == "active" then
            icon = WARN; nameColor = "|cffffd100"  -- sarı: logda/devam ediyor
            active = active + 1
        elseif tooLow then
            icon = "  "; nameColor = "|cff606060"  -- gri: seviye düşük
        else
            icon = BAD;  nameColor = "|cffff6060"  -- kırmızı: alınmamış
            missing = missing + 1
        end
        if not tooLow or status then
            local line = string.format("  %s%s%s|r — %s (%s)", icon, nameColor, q.q, q.npc, q.loc)
            if q.pre then line = line .. " |cffff8080[On kosul: " .. q.pre .. "]|r" end
            if q.note then line = line .. " |cff80ff80(" .. q.note .. ")|r" end
            HM:Print(line)
        end
    end
    HM:Print(string.format("  |cff80ff80%d tamamlandi|r, |cffffd100%d devam ediyor|r, |cffff6060%d alinmamis|r",
        done, active, missing))
    if missing > 0 then
        HM:Print(WARN .. "Zindana girmeden once kirmizi gorevleri al!")
    end
end

---------------------------------------------------------------------------
-- /hm zindan genişletilmiş: seviyeye uygun zindanlar + görev sayısı
---------------------------------------------------------------------------
-- Dönüş: avail (seviye yeten), done, active, missing
-- (Dungeons:List bunu kullanır; eskiden List'ten SONRA tanımlıydı ve /hm zindan
--  "attempt to call global 'questStats'" hatası veriyordu.)
local function questStats(data, level)
    local avail, done, active, missing = 0, 0, 0, 0
    for _, q in ipairs(data.quests) do
        if level >= q.lvl then
            avail = avail + 1
            local s = questStatus(q.q, q.qid)
            if s == "done" then done = done + 1
            elseif s == "active" then active = active + 1
            else missing = missing + 1 end
        end
    end
    return avail, done, active, missing
end

function Dungeons:List()
    local level = HM:Level()
    local found = 0
    HM:Print("|cff33ccff— Seviyene uygun zindanlar ve gorevleri —|r")
    -- sırala: minLvl'e göre
    local sorted = {}
    for name, data in pairs(DUNGEON_QUESTS) do
        sorted[#sorted + 1] = { name = name, data = data }
    end
    table.sort(sorted, function(a, b) return a.data.minLvl < b.data.minLvl end)

    for _, entry in ipairs(sorted) do
        local data = entry.data
        if level >= data.minLvl - 4 and level <= data.maxLvl + 2 then
            found = found + 1
            local avail, done, active, missing = questStats(data, level)
            local color
            if avail > 0 and done >= avail then color = "|cff80ff80"
            elseif done > 0 or active > 0 then color = "|cffffd100"
            else color = "|cffff8080" end
            local parts = {}
            if done > 0 then parts[#parts + 1] = "|cff80ff80" .. done .. " tamam|r" end
            if active > 0 then parts[#parts + 1] = "|cffffd100" .. active .. " devam|r" end
            if missing > 0 then parts[#parts + 1] = "|cffff6060" .. missing .. " eksik|r" end
            HM:Print(string.format("  %s%s (%s)|r %d-%d: %s — |cffffd100/hm zindan %s|r",
                color, entry.name, data.tag, data.minLvl, data.maxLvl, table.concat(parts, " "), data.tag:lower()))
        end
    end
    if found == 0 then
        HM:Print("  Seviyene uygun zindan yok henuz.")
    else
        HM:Print("Forever'da zindan gorevleri cok XP verir: girmeden once gorevleri al!")
    end
end

---------------------------------------------------------------------------
-- Tıklanabilir zindan seçici (popup menü)
---------------------------------------------------------------------------
local FONT = "Fonts\\ARIALN.TTF"
local popup

local function Font(fs, size, flags)
    pcall(fs.SetFont, fs, FONT, size, flags or "")
    if not fs:GetFont() then fs:SetFontObject(GameFontHighlightSmall) end
end

local function sortedDungeons()
    local list = {}
    for name, data in pairs(DUNGEON_QUESTS) do
        list[#list + 1] = { name = name, data = data }
    end
    table.sort(list, function(a, b) return a.data.minLvl < b.data.minLvl end)
    return list
end

local MAX_ROWS = 8

local function CreatePopup()
    if popup then return popup end
    popup = CreateFrame("Frame", "HizliMageDungeonPicker", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    popup:SetSize(260, 40)
    popup:SetPoint("CENTER", 0, 0)
    popup:SetFrameStrata("DIALOG")
    popup:SetMovable(true)
    popup:EnableMouse(true)
    popup:RegisterForDrag("LeftButton")
    popup:SetScript("OnDragStart", function(self) self:StartMoving() end)
    popup:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    popup:SetClampedToScreen(true)

    if popup.SetBackdrop then
        popup:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 16, edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 },
        })
    end

    -- başlık
    popup.title = popup:CreateFontString(nil, "OVERLAY")
    Font(popup.title, 13, "OUTLINE")
    popup.title:SetPoint("TOP", 0, -8)
    popup.title:SetTextColor(0.25, 0.78, 0.92)

    -- kapat düğmesi
    local close = CreateFrame("Button", nil, popup, "UIPanelCloseButton")
    close:SetSize(20, 20)
    close:SetPoint("TOPRIGHT", -2, -2)
    close:SetScript("OnClick", function() popup:Hide() end)

    -- satır düğmeleri
    popup.rows = {}
    for i = 1, MAX_ROWS do
        local row = CreateFrame("Button", nil, popup)
        row:SetSize(240, 22)
        row:SetPoint("TOPLEFT", 10, -24 - (i - 1) * 24)
        row:EnableMouse(true)

        -- arka plan (hover)
        row.bg = row:CreateTexture(nil, "BACKGROUND")
        row.bg:SetAllPoints()
        row.bg:SetColorTexture(1, 1, 1, 0)

        -- zindan adı (sol)
        row.label = row:CreateFontString(nil, "OVERLAY")
        Font(row.label, 12)
        row.label:SetPoint("LEFT", 4, 0)
        row.label:SetJustifyH("LEFT")
        row.label:SetWidth(160)

        -- görev sayacı (sağ)
        row.count = row:CreateFontString(nil, "OVERLAY")
        Font(row.count, 11)
        row.count:SetPoint("RIGHT", -4, 0)
        row.count:SetJustifyH("RIGHT")

        row:SetScript("OnEnter", function(self)
            self.bg:SetColorTexture(0.3, 0.6, 0.9, 0.25)
            if self.dungeonName and self.dungeonData then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(HM:T(self.dungeonName), 0.25, 0.78, 0.92)
                GameTooltip:AddLine(HM:T(self.dungeonData.short), 1, 1, 1, true)
                GameTooltip:AddLine(" ")
                local level = HM:Level()
                for _, q in ipairs(self.dungeonData.quests) do
                    if level >= q.lvl or questStatus(q.q, q.qid) then
                        local s = questStatus(q.q, q.qid)
                        local c, mark
                        if s == "done" then     c = "|cff80ff80"; mark = " +  "   -- yeşil
                        elseif s == "active" then c = "|cffffd100"; mark = " !  "  -- sarı
                        else                     c = "|cffff6060"; mark = " x  "   -- kırmızı
                        end
                        local line = mark .. c .. q.q .. "|r — " .. q.npc .. "  |cff88bbdd(" .. (q.loc or "?") .. ")|r"
                        if q.pre then line = line .. " |cffff8080[" .. q.pre .. "]|r" end
                        GameTooltip:AddLine(HM:T(line), 1, 1, 1, false)
                    end
                end
                GameTooltip:Show()
            end
        end)
        row:SetScript("OnLeave", function(self)
            self.bg:SetColorTexture(1, 1, 1, 0)
            GameTooltip:Hide()
        end)
        row:SetScript("OnClick", function(self)
            if self.dungeonName and self.dungeonData then
                printDungeonQuests(self.dungeonName, self.dungeonData)
                -- oku tıklayınca ayrıca Guide arrow'u da ayarla
                local d
                for _, dd in ipairs(ns.Dungeons or {}) do
                    if dd.n == self.dungeonName and dd.m then d = dd; break end
                end
                if d and HM.Arrow then
                    HM.Arrow:SetTarget(d.m, d.x, d.y, d.n, "dungeon")
                end
            end
        end)

        row:Hide()
        popup.rows[i] = row
    end

    popup:Hide()
    return popup
end

function Dungeons:ShowPicker(anchor)
    local p = CreatePopup()
    local level = HM:Level()
    local list = sortedDungeons()

    -- seviyeye uygun zindanları filtrele
    local visible = {}
    for _, entry in ipairs(list) do
        local data = entry.data
        if level >= data.minLvl - 4 and level <= data.maxLvl + 2 then
            visible[#visible + 1] = entry
        end
    end

    if #visible == 0 then
        HM:Print("Seviyene uygun zindan yok henuz.")
        p:Hide()
        return
    end

    local count = math.min(#visible, MAX_ROWS)
    p.title:SetText(HM:T("Zindan sec (" .. count .. " uygun)"))
    local height = 32 + count * 24 + 8
    p:SetHeight(height)

    for i = 1, MAX_ROWS do
        local row = p.rows[i]
        if i <= count then
            local entry = visible[i]
            local data = entry.data
            local avail, done, active, missing = questStats(data, level)
            row.dungeonName = entry.name
            row.dungeonData = data

            -- renk: tümü tamamlanmış = yeşil, bazıları devam ediyor = sarı, hiç alınmamış = kırmızı
            local nameColor
            if avail > 0 and done >= avail then nameColor = "|cff80ff80"
            elseif done > 0 or active > 0 then nameColor = "|cffffd100"
            else nameColor = "|cffff8080" end

            row.label:SetText(HM:T(string.format("%s%s|r |cff808080(%s)|r %d-%d",
                nameColor, entry.name, data.tag, data.minLvl, data.maxLvl)))

            -- sayaç: yeşil/sarı/kırmızı ayrı ayrı
            local parts = {}
            if done > 0 then parts[#parts + 1] = "|cff80ff80" .. done .. " tamam|r" end
            if active > 0 then parts[#parts + 1] = "|cffffd100" .. active .. " devam|r" end
            if missing > 0 then parts[#parts + 1] = "|cffff6060" .. missing .. " eksik|r" end
            row.count:SetText(HM:T(table.concat(parts, " ")))

            row:Show()
        else
            row:Hide()
        end
    end

    -- konum: anchor varsa yanına, yoksa ekran ortasına
    p:ClearAllPoints()
    if anchor then
        p:SetPoint("TOPLEFT", anchor, "TOPRIGHT", 4, 0)
    else
        p:SetPoint("CENTER", 0, 0)
    end
    p:Show()
end

function Dungeons:HidePicker()
    if popup then popup:Hide() end
end

function Dungeons:TogglePicker(anchor)
    if popup and popup:IsShown() then
        popup:Hide()
    else
        self:ShowPicker(anchor)
    end
end

---------------------------------------------------------------------------
-- Komut: /hm zindan [ad]
---------------------------------------------------------------------------
function Dungeons:Command(arg)
    arg = (arg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    if arg == "" then
        self:List()
    else
        local name, data = matchDungeon(arg)
        if name then
            printDungeonQuests(name, data)
        else
            HM:Print(BAD .. "Zindan bulunamadi: " .. arg .. ". Mevcut: RFC, WC, SFK, BFD, RFK, Gnomer, SM, RFD, Ulda, ZF, Mara, ST, BRD, DM, Scholo, Strat")
        end
    end
end

---------------------------------------------------------------------------
-- Giriş hatırlatması: seviyeye uygun zindanın alınmamış görevleri varsa
---------------------------------------------------------------------------
HM:OnLogin(function()
    C_Timer.After(18, function()
        local ok, err = pcall(function()
            local level = HM:Level()
            local sorted = {}
            for name, data in pairs(DUNGEON_QUESTS) do
                sorted[#sorted + 1] = { name = name, data = data }
            end
            table.sort(sorted, function(a, b) return a.data.minLvl < b.data.minLvl end)

            for _, entry in ipairs(sorted) do
                local data = entry.data
                -- sadece tam seviye aralığındaki zindanları uyar (±2 tolerans değil)
                if level >= data.minLvl and level <= data.maxLvl then
                    local avail, inLog = 0, 0
                    for _, q in ipairs(data.quests) do
                        if level >= q.lvl then
                            avail = avail + 1
                            if isQuestInLog(q.q) then inLog = inLog + 1 end
                        end
                    end
                    if avail > 0 and inLog < avail then
                        HM:Print(string.format("|cff9933ff[Zindan]|r %s (%s) icin %d gorev alinabilir, %d alinmis — |cffffd100/hm zindan %s|r",
                            entry.name, data.tag, avail, inLog, data.tag:lower()))
                        return  -- ilk uygun zindanı söyle, geri kalanı için /hm zindan
                    end
                end
            end
        end)
    end)
end)

-- Panel ve diger modullere zindan veritabanini ac
Dungeons.data = DUNGEON_QUESTS
function Dungeons:GetInfo(name)
    return DUNGEON_QUESTS[name]
end

