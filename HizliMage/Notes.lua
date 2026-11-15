-- Zindan notları: patron → önemli yetenekler ve yapılacaklar. Metinler sınıfa göre açılır:
-- {KES} kesme yeteneği, {KOK} kökten kurtulma, {AOE} kalabalık ekler, {CC} kontrol, {LANET}/{ZEHIR}/{DISPEL} çözme,
-- {KALKAN} savunma, {UZAK} alandan/yakın dövüşten uzaklaşma, {KACIS} kaçış. Oyun İngilizce olduğu için büyü adları İngilizce,
-- yanında Türkçe karşılığı uyarı şeridinde gösterilir (ns.SpellTR).

local ADDON, ns = ...

ns.NoteTokens = {
    MAGE = {
        KES = "KES (Counterspell)", KOK = "Blink ile çık", AOE = "Frost Nova + Blizzard/Arcane Explosion",
        CC = "Polymorph", LANET = "Remove Lesser Curse ile çöz", ZEHIR = "şifacı/druid çözsün",
        DISPEL = "şifacı/şaman dispel etsin (Spellsteal varsa çal)", KALKAN = "Mana Shield/Ice Barrier aç",
        UZAK = "menzilde kal", KACIS = "Blink",
    },
    WARRIOR = {
        KES = "KES (Pummel - Berserker / Shield Bash - kalkanla)", KOK = "bekle, Charge/Intercept ile çık",
        AOE = "Demoralizing Shout + Thunder Clap, Cleave/Whirlwind", CC = "Intimidating Shout (korku, dikkatli) ya da tankla",
        LANET = "şifacı/mage çözsün", ZEHIR = "şifacı/druid çözsün", DISPEL = "şifacı/şaman dispel etsin",
        KALKAN = "Defensive Stance + Shield Wall", UZAK = "vuruş anında geri çekil, patronun arkasına geç", KACIS = "Intercept/Charge",
    },
    DRUID = {
        KES = "KES (ayı formunda Bash / Feral Charge)", KOK = "form değiştir, kök kırılır", AOE = "Swipe (ayı) / Hurricane",
        CC = "Hibernate (canavar/ejder); Entangling Roots kapalı alanda çalışmaz", LANET = "Remove Curse ile çöz",
        ZEHIR = "Cure/Abolish Poison ile çöz", DISPEL = "şifacı/şaman dispel etsin", KALKAN = "Ayı formu + Barkskin",
        UZAK = "menzilde kal (tank değilsen)", KACIS = "form değiştir",
    },
}
ns.NoteTokens.DEFAULT = ns.NoteTokens.MAGE

function ns.ExpandNote(note, class)
    local map = ns.NoteTokens[class or "DEFAULT"] or ns.NoteTokens.DEFAULT
    return (tostring(note or ""):gsub("{(%u+)}", function(k) return map[k] or k end))
end

-- Uyarı şeridinde gösterilecek Türkçe büyü adları (oyun İngilizce)
ns.SpellTR = {
    ["Healing Touch"] = "İyileştirici Dokunuş", ["Healing Wave"] = "İyileştirme Dalgası", ["Lesser Healing Wave"] = "Küçük İyileştirme Dalgası",
    ["Heal"] = "İyileştirme", ["Lesser Heal"] = "Küçük İyileştirme", ["Greater Heal"] = "Büyük İyileştirme", ["Flash Heal"] = "Hızlı İyileştirme",
    ["Renew"] = "Yenileme", ["Rejuvenation"] = "Gençleşme", ["Regrowth"] = "Yeniden Büyüme", ["Holy Light"] = "Kutsal Işık",
    ["Flash of Light"] = "Işık Parıltısı", ["Dark Mending"] = "Karanlık Onarım", ["Shadow Mend"] = "Gölge Onarımı",
    ["Prayer of Healing"] = "Şifa Duası", ["Chain Heal"] = "Zincir Şifa", ["Tranquility"] = "Huzur", ["Scarlet Resurrection"] = "Kızıl Diriliş",
    ["Sleep"] = "Uyku", ["Druid's Slumber"] = "Druid Uykusu", ["Deep Sleep"] = "Derin Uyku", ["Hex"] = "Büyüleme (Hex)",
    ["Polymorph"] = "Dönüşüm (Koyun)", ["Fear"] = "Korku", ["Psychic Scream"] = "Psişik Çığlık", ["Terrify"] = "Dehşet",
    ["Mind Control"] = "Zihin Kontrolü", ["Dominate Mind"] = "Zihin Hâkimiyeti", ["Possess"] = "Ele Geçirme", ["Hex of Jammal'an"] = "Jammal'an Büyüsü",
    ["Entangling Roots"] = "Sarmaşık Kökleri", ["Frost Nova"] = "Buz Novası", ["Silence"] = "Sessizlik", ["Banshee Wail"] = "Banshee Çığlığı",
    ["Pyroblast"] = "Ateş Patlaması", ["Void Bolt"] = "Boşluk Oku", ["Chain Lightning"] = "Zincir Yıldırım", ["Chain Bolt"] = "Zincir Yıldırım",
    ["Chained Bolt"] = "Zincir Yıldırım", ["Mind Blast"] = "Zihin Patlaması", ["Shadow Bolt"] = "Gölge Oku", ["Fireball"] = "Ateş Topu",
    ["Frostbolt"] = "Buz Oku", ["Lightning Bolt"] = "Yıldırım", ["Forked Lightning"] = "Çatal Yıldırım", ["Soul Drain"] = "Ruh Emme",
    ["Arcane Missiles"] = "Arcane Füzeleri", ["Immolate"] = "Yakma", ["Wrath"] = "Gazap", ["Earth Shock"] = "Toprak Şoku",
    ["Flamestrike"] = "Alev Darbesi", ["Fire Nova"] = "Ateş Novası", ["Thunderclap"] = "Gök Gürültüsü", ["Thunder Clap"] = "Gök Gürültüsü",
    ["Whirlwind"] = "Hortum", ["Cleave"] = "Yarma", ["Mortal Strike"] = "Ölümcül Darbe", ["Frost Shock"] = "Buz Şoku",
    ["Flame Shock"] = "Alev Şoku", ["Curse of Agony"] = "Izdırap Laneti", ["Curse of Weakness"] = "Zayıflık Laneti",
    ["Curse of Blood"] = "Kan Laneti", ["Curse of Tongues"] = "Dil Laneti", ["Curse of Thorns"] = "Diken Laneti",
    ["Shadow Word: Pain"] = "Gölge Sözü: Acı", ["Mind Flay"] = "Zihin Yüzme", ["Drain Life"] = "Yaşam Emme", ["Corruption"] = "Yozlaşma",
    ["Lightning Shield"] = "Yıldırım Kalkanı", ["Power Word: Shield"] = "Güç Sözü: Kalkan", ["Shadow Shield"] = "Gölge Kalkanı",
    ["Frost Armor"] = "Buz Zırhı", ["Ice Armor"] = "Buz Zırhı", ["Devotion Aura"] = "Adanmışlık Aurası", ["Bloodlust"] = "Kan Hırsı",
    ["Frenzy"] = "Çılgınlık", ["Enrage"] = "Öfke", ["Inner Fire"] = "İç Ateş", ["Thorns"] = "Dikenler", ["Arcane Intellect"] = "Arcane Zekâ",
    ["Blink"] = "Işınlanma", ["Counterspell"] = "Büyü Kesme",
}

-- Hedefte görülünce bilgi verilecek önemli buff'lar (Spellsteal yoksa da)
ns.NotableBuffs = {
    ["Lightning Shield"] = true, ["Power Word: Shield"] = true, ["Shadow Shield"] = true, ["Renew"] = true, ["Rejuvenation"] = true,
    ["Bloodlust"] = true, ["Frenzy"] = true, ["Enrage"] = true, ["Devotion Aura"] = true, ["Inner Fire"] = true, ["Frost Armor"] = true,
    ["Ice Armor"] = true, ["Thorns"] = true, ["Arcane Intellect"] = true, ["Mana Shield"] = true, ["Ice Barrier"] = true,
    ["Blessing of Protection"] = true, ["Divine Shield"] = true, ["Regrowth"] = true,
}

ns.DungeonNotes = {
    ["Ragefire Chasm"] = {
        lvl = "13-18",
        ["Oggleflint"] = "Cleave: tankın yanında durma.",
        ["Taragaman the Hungerer"] = "Fire Nova (alan hasarı) + Uppercut: {UZAK}, UZAK DUR.",
        ["Jergosh the Invoker"] = "Immolate → {KES}. Curse of Weakness zararsız.",
        ["Bazzalan"] = "Poison + Sinister Strike: tanka bırak, {UZAK}.",
    },
    ["Wailing Caverns"] = {
        lvl = "17-24",
        ["Lady Anacondra"] = "Sleep → {KES} (uyutur). Lightning Bolt kesilebilir. Druid's Slumber: uyuyanı vurup uyandırın.",
        ["Lord Cobrahn"] = "Druid's Slumber (uyku) → {KES}. Poison: lanet değil zehir, {ZEHIR}. Yılan formunda daha sert vurur.",
        ["Kresh"] = "Düz kaplumbağa, mekanik yok.",
        ["Lord Pythas"] = "Healing Touch → {KES} mutlaka. Sleep → {KES}. Thunderclap: tankın dibinde durma.",
        ["Skum"] = "Chained Bolt → {KES} (zincirleme yıldırım).",
        ["Lord Serpentis"] = "Healing Touch → {KES} mutlaka. Lightning Bolt / Sleep kesilebilir.",
        ["Verdan the Everliving"] = "Grasping Vines (kök + hasar): {KOK}, {UZAK}.",
        ["Mutanus the Devourer"] = "Thundercrack (alan) + Terrify (korku): {KALKAN}, tankın yanında durma.",
        ["Deviate Faerie Dragon"] = "Nadir: Dragon's Breath (ağızdan ateş) → yan tarafta dur.",
    },
    ["Shadowfang Keep"] = {
        lvl = "22-30",
        ["Rethilgore"] = "Soul Drain → {KES}.",
        ["Razorclaw the Butcher"] = "Butcher Drain: tanka bırak.",
        ["Baron Silverlaine"] = "Veil of Shadow (iyileşme azalır) → {DISPEL}.",
        ["Commander Springvale"] = "Holy Light → {KES} mutlaka. Hammer of Justice (sersemletme). Devotion Aura: {DISPEL}.",
        ["Odo the Blindwatcher"] = "Howling Rage (öfke): patlamada {AOE}, geri çekil.",
        ["Fenrus the Devourer"] = "Toxic Saliva: {ZEHIR}; ölünce 4 worgen gelir, {AOE} hazır olsun.",
        ["Wolf Master Nandos"] = "Kurtları çağırır: {AOE}.",
        ["Archmage Arugal"] = "Void Bolt → {KES} mutlaka. Thundershock (alan). Arugal's Curse: seni worgen'e çevirir, bekle. Işınlanır, yakından takip et.",
    },
    ["Blackfathom Deeps"] = {
        lvl = "24-32",
        ["Ghamoo-ra"] = "Çok zırhlı kaplumbağa: büyüler/kanama iyi gider, Trample'dan uzak dur.",
        ["Lady Sarevess"] = "Forked Lightning → {KES}. {AOE} + Slow atar, {KACIS} hazır olsun.",
        ["Gelihast"] = "Net (kök): {KOK}.",
        ["Lorgus Jett"] = "Lightning Shield → {DISPEL}. Lightning Bolt → {KES}.",
        ["Baron Aquanis"] = "Frostbolt → {KES}.",
        ["Twilight Lord Kelris"] = "Mind Blast → {KES}. Sleep → {KES}. Ölünce havuza dalınır.",
        ["Old Serra'kis"] = "Poison; su altında, nefes kontrol.",
        ["Aku'mai"] = "Poison Cloud: zehir bulutundan UZAK DUR. Frenzy'de {AOE}, mesafe al.",
    },
    ["Razorfen Kraul"] = {
        lvl = "29-38",
        ["Roogug"] = "Lightning Bolt → {KES}. Totemleri önce kır.",
        ["Aggem Thorncurse"] = "Yaban domuzu ruhları çağırır: {AOE}.",
        ["Death Speaker Jargba"] = "Dominate Mind (zihin kontrolü): kontrol edileni {CC} ile tutun. Shadow Bolt → {KES}.",
        ["Overlord Ramtusk"] = "Knock Away + Thunderclap: UZAK DUR.",
        ["Agathelos the Raging"] = "Rampage (öfke): {UZAK}, {KALKAN}.",
        ["Blind Hunter"] = "Sonic Burst (sessizlik): Nadir yarasa, sessizlikten sonra büyü at.",
        ["Charlga Razorflank"] = "Chain Bolt → {KES}. Renew → {KES}. Lightning Shield → {DISPEL}.",
    },
    ["Scarlet Monastery"] = {
        lvl = "28-45",
        ["Interrogator Vishas"] = "Shadow Word: Pain → {KES}; kolay patron.",
        ["Bloodmage Thalnos"] = "Shadow Bolt → {KES}. Flame Shock/Flame Spike: yakınında durma.",
        ["Houndmaster Loksey"] = "Bloodlust (köpeklere buff) → {DISPEL}. Köpekleri {AOE}.",
        ["Arcanist Doan"] = "Polymorph → {KES}. Detonation: kalkan açınca sütunun arkasına kaç (büyük patlama). Silence atar.",
        ["Herod"] = "Whirlwind: UZAK DUR. Ölünce koşan adaylar gelir → {AOE}.",
        ["High Inquisitor Fairbanks"] = "Heal → {KES}. Fear (korku) atar.",
        ["Scarlet Commander Mograine"] = "Hammer of Justice. Ölünce Whitemane dirilt(me)ye gelir: Scarlet Resurrection kesilemez; Deep Sleep'e hazır ol.",
        ["High Inquisitor Whitemane"] = "Deep Sleep (herkesi uyutur, Mograine dirilir). Heal → {KES}. Power Word: Shield → {DISPEL}.",
    },
    ["Razorfen Downs"] = {
        lvl = "37-46",
        ["Tuten'kash"] = "Web Spray (ağ): {KACIS}. Curse of Tuten'kash → {LANET}.",
        ["Mordresh Fire Eye"] = "Fireball → {KES}. Fire Nova: UZAK DUR.",
        ["Glutton"] = "Disease Cloud: yakınında durma.",
        ["Ragglesnout"] = "Nadir: Heal → {KES}.",
        ["Amnennar the Coldbringer"] = "Frostbolt → {KES}. {AOE} + Amnennar's Wrath (alan): {UZAK}, buz hayaletlerini {AOE} ile tut.",
    },
    ["Uldaman"] = {
        lvl = "41-51",
        ["Revelosh"] = "Lightning Bolt → {KES}.",
        ["Ironaya"] = "Arcing Smash + War Stomp: UZAK DUR.",
        ["Obsidian Sentinel"] = "Bölünür: parçalara {AOE}.",
        ["Ancient Stone Keeper"] = "Sandstorm: alanından çık.",
        ["Galgann Firehammer"] = "Fire Nova + Flame Lash: UZAK DUR. Amplify Damage → {DISPEL}.",
        ["Grimlok"] = "Chain Bolt → {KES}. Shrink zararsız.",
        ["Archaedas"] = "Ground Tremor (sersemletme). Uyanan Earthen Guardian'ları hemen öldür.",
    },
    ["Zul'Farrak"] = {
        lvl = "44-54",
        ["Antu'sul"] = "Healing Wave → {KES} mutlaka. Earthgrab totemini kır. Bazilisk eklerini {AOE}.",
        ["Theka the Martyr"] = "Fevered Plague: dispel edilmez, bekle. Bir süre bağışık olur.",
        ["Witch Doctor Zum'rah"] = "Healing Wave → {KES}. Shadow Bolt kesilebilir. Mezarlardan zombi gelir: {AOE}.",
        ["Nekrum Gutchewer"] = "Shadowpriest Sezz'ziz ile birlikte: Heal → {KES}, Psychic Scream (korku), Mind Flay.",
        ["Shadowpriest Sezz'ziz"] = "Heal → {KES} mutlaka. Psychic Scream (korku).",
        ["Chief Ukorz Sandscalp"] = "Whirlwind: UZAK DUR; Ruuzlu ile gelir.",
        ["Hydromancer Velratha"] = "Healing Wave → {KES}. Lightning Shield → {DISPEL}. Frost Shock.",
        ["Gahz'rilla"] = "Freeze (buz sersemletmesi) + Icicle. Slam seni fırlatır; sırtını duvara ver.",
    },
    ["Maraudon"] = {
        lvl = "46-55",
        ["Noxxion"] = "Toxic Volley (zehir). İkiye bölünür: Scion'ları {AOE}.",
        ["Razorlash"] = "Puncture/Cleave: tankın yanında durma.",
        ["Lord Vyletongue"] = "Smoke Bomb + Blink: {UZAK}, satirleri {CC} ile tut.",
        ["Celebras the Cursed"] = "Wrath → {KES}. Entangling Roots: {KACIS}. Twisted Tranquility.",
        ["Landslide"] = "Knock Away + Trample: UZAK DUR. Golem çağırır.",
        ["Tinkerer Gizlock"] = "Bomb + Dragon Gun (ağızdan ateş): yan tarafta dur.",
        ["Rotgrip"] = "Puncture: tanka bırak.",
        ["Princess Theradras"] = "Dust Field (alan) + Boulder + Repulsive Gaze (korku): {UZAK}.",
    },
    ["The Temple of Atal'Hakkar"] = {
        lvl = "50-56",
        ["Jammal'an the Prophet"] = "Hex of Jammal'an (zihin kontrolü, {CC} ile kontrol). Flamestrike'tan çık. Ogom: Shadow Bolt → {KES}.",
        ["Ogom the Wretched"] = "Shadow Bolt → {KES}. Curse of Blood → {LANET}.",
        ["Zolo"] = "Heal → {KES}. Hex (Polymorph benzeri).",
        ["Mijan"] = "Healing Wave → {KES}.",
        ["Hukku"] = "Shadow Bolt → {KES}; imp'leri {AOE}.",
        ["Zul'Lor"] = "Shadow Bolt → {KES}. Curse of Blood → {LANET}.",
        ["Shade of Eranikus"] = "Deep Slumber (uyku), Acid Breath (ağızdan): yan tarafta dur. War Stomp.",
    },
    ["Blackrock Depths"] = {
        lvl = "52-60",
        ["Lord Roccor"] = "Earth Shock → {KES}. Ground Tremor.",
        ["Pyromancer Loregrain"] = "Fireball → {KES}.",
        ["Lord Incendius"] = "Fiery Burst (alan): UZAK DUR. Curse of Incendius → {LANET}.",
        ["General Angerforge"] = "%30'da ekler gelir: {AOE} hazır.",
        ["Golem Lord Argelmach"] = "Lightning Bolt / Shock → {KES}.",
        ["Ambassador Flamelash"] = "Fireball → {KES}. Burning Spirit'leri ona ulaşmadan öldür.",
        ["Princess Moira Bronzebeard"] = "Heal / Renew → {KES} mutlaka (önce İmparator ölürse dirilmez).",
        ["Emperor Dagran Thaurissan"] = "Hand of Thaurissan (sersemletme). Moira'nın Heal'ini KES.",
    },
    ["Lower Blackrock Spire"] = {
        lvl = "55-60",
        ["Shadow Hunter Vosh'gajin"] = "Shadow Bolt → {KES}. Hex: Polymorph benzeri, bekle. Curse of Blood → {LANET}.",
        ["Highlord Omokk"] = "Knock Away + Frenzy: UZAK DUR.",
        ["War Master Voone"] = "Throw Axe + Cleave.",
        ["Mother Smolderweb"] = "Poison + örümcek yavruları: {AOE}.",
        ["Gizrul the Slavener"] = "Fatal Bite: tanka bırak.",
        ["Overlord Wyrmthalak"] = "Blast Wave (alan): UZAK DUR. ekleri {CC} ile tut.",
    },
    ["Scholomance"] = {
        lvl = "58-60",
        ["Kirtonos the Herald"] = "Dominate Mind (zihin kontrolü), Curse of Tongues → {LANET}.",
        ["Jandice Barov"] = "Banshee Wail (sessizlik). Sahte kopyalar: gerçek olana odaklan (hasarı fazla olan).",
        ["Marduk Blackpool"] = "Shadow Shield → {DISPEL}. Shadow Bolt → {KES}.",
        ["Ras Frostwhisper"] = "Frostbolt → {KES}. Frost Volley + Chill Nova: {UZAK}. Fear atar.",
        ["Instructor Malicia"] = "Heal / Renew / Flash Heal → {KES} mutlaka.",
        ["Lady Illucia Barov"] = "Silence + Fear + Dominate Mind. Shadow Shock.",
        ["Lord Alexei Barov"] = "Immolate → {KES}. Veil of Shadow → {DISPEL}.",
        ["Darkmaster Gandling"] = "Arcane Missiles → {KES}. Shadow Portal: odaya ışınlananlar ekleri öldürüp dönsün.",
    },
    ["Stratholme"] = {
        lvl = "58-60",
        ["Archivist Galford"] = "Fireball → {KES}. Flamestrike'tan çık.",
        ["Balnazzar"] = "Mind Blast → {KES}. Sleep → {KES}. Psychic Scream (korku). Domination.",
        ["Baroness Anastari"] = "Possess (seni ele geçirir), Banshee Wail (sessizlik).",
        ["Maleki the Pallid"] = "Frostbolt → {KES}. Icetomb (buz hapsi).",
        ["Baron Rivendare"] = "Shadow Bolt → {KES}. Raise Dead: ekler. Mortal Strike/Cleave: UZAK DUR.",
    },
    ["Dire Maul"] = {
        lvl = "56-60",
        ["Lethtendris"] = "Shadow Bolt → {KES}. Curse of Thorns → {LANET}.",
        ["Alzzin the Wildshaper"] = "Wither + Enervate; şekil değiştirir. Ölünce kalabalık ek: {AOE}.",
        ["Magister Kalendris"] = "Mind Blast / Mind Flay → {KES}. Dominate Mind.",
        ["Prince Tortheldrin"] = "Counterspell atar: büyü sırası kesilebilir, Whirlwind'den UZAK DUR.",
        ["Cho'Rush the Observer"] = "Heal → {KES} mutlaka. Mind Blast.",
        ["King Gordok"] = "Mortal Strike + War Stomp: UZAK DUR.",
    },
}

-- Kesilmesi en kritik büyüler (isim eşleşmesi). KES uyarısını güçlendirir.
ns.CriticalCasts = {
    -- iyileştirme
    ["Healing Touch"] = "iyileştirme", ["Healing Wave"] = "iyileştirme", ["Lesser Healing Wave"] = "iyileştirme",
    ["Heal"] = "iyileştirme", ["Lesser Heal"] = "iyileştirme", ["Greater Heal"] = "iyileştirme", ["Flash Heal"] = "iyileştirme",
    ["Renew"] = "iyileştirme", ["Rejuvenation"] = "iyileştirme", ["Regrowth"] = "iyileştirme", ["Holy Light"] = "iyileştirme",
    ["Flash of Light"] = "iyileştirme", ["Dark Mending"] = "iyileştirme", ["Shadow Mend"] = "iyileştirme", ["Prayer of Healing"] = "iyileştirme",
    ["Chain Heal"] = "iyileştirme", ["Tranquility"] = "iyileştirme", ["Scarlet Resurrection"] = "diriltme",
    -- kontrol
    ["Sleep"] = "uyku", ["Druid's Slumber"] = "uyku", ["Deep Sleep"] = "uyku", ["Hex"] = "kontrol", ["Polymorph"] = "kontrol",
    ["Fear"] = "korku", ["Psychic Scream"] = "korku", ["Terrify"] = "korku", ["Mind Control"] = "zihin kontrolü",
    ["Dominate Mind"] = "zihin kontrolü", ["Possess"] = "zihin kontrolü", ["Hex of Jammal'an"] = "zihin kontrolü",
    ["Entangling Roots"] = "kök", ["{AOE}"] = "kök", ["Silence"] = "sessizlik", ["Banshee Wail"] = "sessizlik",
    -- ağır hasar
    ["Pyroblast"] = "ağır hasar", ["Void Bolt"] = "ağır hasar", ["Chain Lightning"] = "ağır hasar", ["Chain Bolt"] = "ağır hasar",
    ["Chained Bolt"] = "ağır hasar", ["Mind Blast"] = "ağır hasar", ["Shadow Bolt"] = "hasar", ["Fireball"] = "hasar",
    ["Frostbolt"] = "hasar", ["Lightning Bolt"] = "hasar", ["Forked Lightning"] = "hasar", ["Soul Drain"] = "hasar",
    ["Arcane Missiles"] = "hasar", ["Immolate"] = "hasar", ["Wrath"] = "hasar", ["Earth Shock"] = "hasar",
}
