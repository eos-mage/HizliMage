-- XpBuffs.lua: XP ve kamp/meslek buff'ları. Üç bölüm tek dosyada tutulur: oyun açıkken eklenen yeni
-- dosyaları istemci /reload ile görmeyebildiği için kamp modülü ayrı dosya yapılmadı.

---------------------------------------------------------------------------
-- 1/4 Kamp verisi (gen_campdata.py üretir): eşyalar, tarifler, görevler, eğitmenler, satıcılar
---------------------------------------------------------------------------
do
-- Otomatik üretildi (gen_campdata.py): WoW Forever kamp sistemi verisi. Elle düzenleme.
-- Kaynak: Questie Forever veritabanı, Questie eğitmen listeleri, WhatsTraining tarif verisi (sürüm 1.60.1).
local ADDON, ns = ...
ns.CampData = {
  -- Kamp buff'ları (büyü kimliği ve İngilizce ad; ad, kimlik tutmazsa yedek)
  aura = { nearby = 1283391, welcome = 1289723, benefits = 1229741, boosted = 1229451 },
  auraName = { nearby = "Campfire Nearby", welcome = "Welcoming Campfire", benefits = "Camp Benefits", boosted = "Boosted Rest" },
  -- Kamp ateşi kitleri (en iyisi önce), Basic Campfire Kit tarifi, odun ve çakmak
  fire = { { id=279974, n="Expert Campfire Kit", slots=10 }, { id=279961, n="Journeyman Campfire Kit", slots=5 }, { id=279981, n="Basic Campfire Kit", slots=3 } },
  kitSpell = 1229737, wood = 4470, flint = 4471, cooking = 185,
  -- Giriş görevi: The Great Outdoors (herhangi biri bitmişse tamam) ve ardından Camping 101: Cooking
  introAll = { 95998, 96101, 96604, 96605, 96606, 96607, 96608 },
  intro = {
    { q=96101, m=2521, x=41.7, y=44.8, n="Raan Wildwind", cookQ=96646, cook={ m=2521, x=43.9, y=43.8, n="Zerril Softbreeze" } },
    { q=96604, m=1411, x=52.0, y=47.3, n="Brakk", cookQ=96655, cook={ m=1411, x=51.1, y=42.5, n="Cook Torka" } },
    { q=96605, m=1412, x=46.2, y=67.3, n="Kaga Wildhoof", cookQ=96661, cook={ m=1412, x=44.9, y=61.7, n="Pyall Silentstride" } },
    { q=96607, m=1420, x=57.3, y=55.5, n="Eleanor Shackleton", cookQ=96658, cook={ m=1420, x=61.8, y=51.4, n="William Pickman" } },
  },
  -- Bütün kamp görevleri (rehber bunları da otomatik alır/teslim eder)
  quests = { [95998]=true, [96031]=true, [96044]=true, [96045]=true, [96046]=true, [96047]=true, [96050]=true, [96055]=true, [96056]=true, [96057]=true, [96058]=true, [96059]=true, [96101]=true, [96102]=true, [96604]=true, [96605]=true, [96606]=true, [96607]=true, [96608]=true, [96626]=true, [96627]=true, [96628]=true, [96629]=true, [96630]=true, [96634]=true, [96638]=true, [96646]=true, [96652]=true, [96655]=true, [96656]=true, [96658]=true, [96659]=true, [96661]=true, [97899]=true, [97900]=true, [97901]=true, [97902]=true, [97903]=true, [97904]=true, [97905]=true, [97906]=true, [97907]=true, [97908]=true, [97915]=true, [97916]=true, [97917]=true, [97918]=true, [97919]=true, [97920]=true, [97921]=true, [97922]=true, [97923]=true, [97924]=true, [97925]=true, [97927]=true, [97928]=true, [97929]=true, [97930]=true, [97931]=true, [97932]=true, [97933]=true, [97934]=true, [97935]=true, [97936]=true, [97937]=true, [97938]=true, [97939]=true, [97940]=true, [97941]=true, [97942]=true, [97943]=true, [97944]=true, [97946]=true, [97948]=true, [97949]=true, [97950]=true, [97951]=true, [97952]=true, [97953]=true, [97954]=true, [97955]=true, [97956]=true, [97957]=true, [97958]=true, [97959]=true, [97960]=true, [97961]=true, [97963]=true, [97964]=true, [97965]=true, [97967]=true, [97968]=true, [97969]=true, [97970]=true, [97971]=true, [97972]=true, [97973]=true, [98284]=true, [98285]=true, [98286]=true, [98287]=true },
  -- Meslekler: 1. kademe kamp eşyası (beceri 20), tarif büyüsü, üst kademe eşyalar, malzeme, görevler, eğitmenler
  prof = {
    { key="alch", id=171, n="Alchemy", item=279956, itemName="Mana Well", spell=1230564, up={ 279970, 279990 },
      mats = { { 2447, "Peacebloom", 1 }, { 3371, "Empty Vial", 1 } },
      q = { [97899]={ m=1454, x=55.8, y=32.9, n="Whuut" }, [97927]={ m=1456, x=46.7, y=34.4, n="Kray" }, [97951]={ m=1420, x=59.4, y=52.2, n="Carolai Anise" }, [97963]={ m=2521, x=43.7, y=43.4, n="Nyassa Swiftdraught" } },
      trainers = {
        { m=1454, x=55.8, y=32.9, n="Whuut" },
        { m=1454, x=56.8, y=33.0, n="Yelmak" },
        { m=1456, x=46.6, y=33.2, n="Bena Winterhoof" },
        { m=1456, x=46.7, y=34.4, n="Kray" },
        { m=1458, x=46.6, y=74.1, n="Doctor Martin Felben" },
        { m=1458, x=47.8, y=73.3, n="Doctor Herbert Halsey" },
        { m=1458, x=50.9, y=74.6, n="Doctor Marsh" },
        { m=1411, x=55.4, y=74.0, n="Miao'zan" },
        { m=1420, x=59.4, y=52.2, n="Carolai Anise" },
        { m=1424, x=61.6, y=19.2, n="Serge Hinott" },
        { m=1434, x=28.0, y=78.0, n="Jaxin Chong" },
        { m=1435, x=48.5, y=55.9, n="Rogvar" },
        { m=2521, x=43.7, y=43.4, n="Nyassa Swiftdraught" },
        { m=2521, x=59.2, y=76.3, n="Valiena Swiftgale" },
      } },
    { key="bs", id=164, n="Blacksmithing", item=279944, itemName="Sharpening Wheel", spell=1230171, up={ 279988, 279955 },
      mats = { { 2835, "Rough Stone", 1 }, { 2840, "Copper Bar", 1 } },
      q = { [97900]={ m=1411, x=52.0, y=40.7, n="Dwukk" }, [97928]={ m=1456, x=39.4, y=56.7, n="Thrag Stonehoof" }, [97952]={ m=1458, x=60.2, y=29.1, n="Basil Frye" }, [97964]={ m=2521, x=44.9, y=44.4, n="Aedi Thriceforged" } },
      trainers = {
        { m=1454, x=79.6, y=23.3, n="Snarl" },
        { m=1454, x=80.8, y=23.7, n="Ug'thok" },
        { m=1454, x=82.3, y=23.0, n="Saru Steelfury" },
        { m=1456, x=39.4, y=55.1, n="Karn Stonehoof" },
        { m=1456, x=39.4, y=56.7, n="Thrag Stonehoof" },
        { m=1458, x=60.2, y=29.1, n="Basil Frye" },
        { m=1458, x=61.3, y=30.6, n="James Van Brunt" },
        { m=1411, x=52.0, y=40.7, n="Dwukk" },
        { m=1413, x=51.3, y=28.9, n="Traugh" },
        { m=1420, x=21.0, y=46.4, n="Angus Hammerhand" },
        { m=1421, x=43.2, y=41.1, n="Guillaume Sorouy" },
        { m=1434, x=29.0, y=75.6, n="Brikk Keencraft" },
        { m=2521, x=44.9, y=44.4, n="Aedi Thriceforged" },
        { m=2521, x=65.5, y=80.3, n="Daeann Steelwind" },
      } },
    { key="ench", id=333, n="Enchanting", item=279976, itemName="Enchanted Lute", spell=1230643, up={ 279985, 279987 },
      mats = { { 4470, "Simple Wood", 1 }, { 10940, "Strange Dust", 1 } },
      q = { [97901]={ m=1454, x=53.5, y=38.5, n="Jhag" }, [97929]={ m=1456, x=44.6, y=38.5, n="Mot Dawnstrider" }, [97953]={ m=1420, x=61.8, y=51.6, n="Vance Undergloom" }, [98284]={ m=2521, x=43.2, y=43.1, n="Nasalanna Windsinger" } },
      trainers = {
        { m=1454, x=53.5, y=38.5, n="Jhag" },
        { m=1454, x=53.9, y=38.7, n="Godan" },
        { m=1456, x=44.6, y=38.5, n="Mot Dawnstrider" },
        { m=1456, x=44.9, y=37.5, n="Teg Dawnstrider" },
        { m=1458, x=62.5, y=61.8, n="Lavinia Crowe" },
        { m=1458, x=62.5, y=60.4, n="Malcomb Wynn" },
        { m=1411, x=56.7, y=73.7, n="Pa'zula" },
        { m=1420, x=61.8, y=51.6, n="Vance Undergloom" },
        { m=1442, x=49.2, y=57.2, n="Hgarth" },
        { m=2521, x=43.2, y=43.1, n="Nasalanna Windsinger" },
        { m=2521, x=59.2, y=76.4, n="Eaysaa Brightgust" },
      } },
    { key="eng", id=202, n="Engineering", item=279950, itemName="Reagent Bot", spell=1230656, up={ 279949, 279989 },
      mats = { { 4359, "Handful of Copper Bolts", 1 }, { 4361, "Copper Tube", 1 } },
      q = { [97902]={ m=1411, x=52.2, y=40.8, n="Mukdrak" }, [97930]={ m=1412, x=58.6, y=39.4, n="Twizwick Sprocketgrind" }, [97954]={ m=1458, x=75.3, y=73.1, n="Graham Van Talen" }, [98285]={ m=2521, x=54.0, y=38.9, n="Strange Hermit" } },
      trainers = {
        { m=1454, x=76.0, y=24.1, n="Thund" },
        { m=1454, x=76.0, y=25.4, n="Nogg" },
        { m=1454, x=76.2, y=25.2, n="Roxxik" },
        { m=1458, x=75.3, y=73.1, n="Graham Van Talen" },
        { m=1458, x=76.1, y=74.0, n="Franklin Lloyd" },
        { m=1411, x=52.2, y=40.8, n="Mukdrak" },
        { m=1412, x=58.6, y=39.4, n="Twizwick Sprocketgrind" },
        { m=1413, x=62.7, y=36.3, n="Tinkerwiz" },
        { m=1446, x=52.3, y=27.7, n="Buzzek Bracketswing" },
      } },
    { key="herb", id=182, n="Herbalism", item=279962, itemName="Incense Candle", spell=1229705, up={ 279964, 279947 },
      mats = { { 2447, "Peacebloom", 1 }, { 765, "Silverleaf", 1 } },
      q = { [97905]={ m=1454, x=55.6, y=39.5, n="Jandi" }, [97933]={ m=1456, x=50.0, y=40.4, n="Komin Winterhoof" }, [97957]={ m=1420, x=59.8, y=52.1, n="Faruza" }, [97968]={ m=2521, x=57.9, y=75.5, n="Syriel Nightrain" } },
      trainers = {
        { m=1454, x=55.6, y=39.5, n="Jandi" },
        { m=1456, x=50.0, y=40.4, n="Komin Winterhoof" },
        { m=1458, x=54, y=49.5, n="Martha Alliestar" },
        { m=1411, x=42.7, y=67.4, n="Zor'la" },
        { m=1411, x=55.4, y=75.1, n="Mishiki" },
        { m=1412, x=44.1, y=78.0, n="Garan Sunstrider" },
        { m=1420, x=32.5, y=65.1, n="Florence Nightshade" },
        { m=1420, x=59.8, y=52.1, n="Faruza" },
        { m=1424, x=61.7, y=19.5, n="Aranae Venomblood" },
        { m=1434, x=27.7, y=77.9, n="Flora Silverwind" },
        { m=1434, x=32.2, y=27.4, n="Angrun" },
        { m=1444, x=76.0, y=43.3, n="Ruw" },
        { m=1450, x=45.4, y=47.0, n="Malvor" },
        { m=2521, x=43.0, y=43.5, n="Halassa Fernbreeze" },
        { m=2521, x=57.9, y=75.5, n="Syriel Nightrain" },
      } },
    { key="lw", id=165, n="Leatherworking", item=279978, itemName="Camp Tent", spell=1229432, up={ 279941, 279945 },
      mats = { { 2318, "Light Leather", 5 } },
      q = { [97906]={ m=1454, x=62.8, y=44.1, n="Karolek" }, [97934]={ m=1412, x=44.9, y=61.5, n="Chaw Stronghide" }, [97958]={ m=1420, x=65.4, y=60.1, n="Shelene Rhobart" }, [97969]={ m=2521, x=44.7, y=44.5, n="Indari Sunseam" } },
      trainers = {
        { m=1454, x=62.8, y=44.1, n="Karolek" },
        { m=1454, x=63.3, y=44.8, n="Kamari" },
        { m=1456, x=41.5, y=42.6, n="Una" },
        { m=1456, x=42.1, y=43.5, n="Mak" },
        { m=1456, x=42.3, y=42.6, n="Tarn" },
        { m=1458, x=70.2, y=57.4, n="Arthur Moore" },
        { m=1458, x=70.9, y=58.4, n="Dan Golthas" },
        { m=1412, x=44.9, y=61.5, n="Chaw Stronghide" },
        { m=1413, x=44.8, y=59.5, n="Krulmoo Fullmoon" },
        { m=1413, x=46.0, y=35.9, n="Waldor" },
        { m=1420, x=65.4, y=60.1, n="Shelene Rhobart" },
        { m=1434, x=31.7, y=28.9, n="Brawn" },
        { m=1443, x=55.2, y=56.3, n="Narv Hidecrafter" },
        { m=1444, x=74.4, y=43.1, n="Hahrana Ironhide" },
        { m=2521, x=44.7, y=44.5, n="Indari Sunseam" },
        { m=2521, x=63.7, y=80.7, n="Emerii Tallgust" },
      } },
    { key="mine", id=186, n="Mining", item=279960, itemName="Lodestone", spell=1230161, up={ 279948, 279952 },
      mats = { { 2835, "Rough Stone", 1 }, { 2840, "Copper Bar", 1 } },
      q = { [97907]={ m=1411, x=51.8, y=40.9, n="Krunn" }, [97935]={ m=1456, x=34.4, y=57.9, n="Brek Stonehoof" }, [97959]={ m=1458, x=56.0, y=37.5, n="Brom Killian" }, [97970]={ m=2521, x=44.8, y=44.6, n="Messana Crestwind" } },
      trainers = {
        { m=1454, x=73.1, y=26.1, n="Makaru" },
        { m=1456, x=34.4, y=57.9, n="Brek Stonehoof" },
        { m=1458, x=56.0, y=37.5, n="Brom Killian" },
        { m=1411, x=40.5, y=68.1, n="Norzsh" },
        { m=1411, x=51.8, y=40.9, n="Krunn" },
        { m=1412, x=44.3, y=78.4, n="Vartha Rockmane" },
        { m=1420, x=32.2, y=65.8, n="Walter Mason" },
        { m=1421, x=43.4, y=40.5, n="Johan Focht" },
        { m=1446, x=51.1, y=28.1, n="Pikkle" },
        { m=2521, x=44.8, y=44.6, n="Messana Crestwind" },
        { m=2521, x=65.4, y=80.5, n="Halavuul Cragwind" },
      } },
    { key="skin", id=393, n="Skinning", item=279979, itemName="Camp Chair", spell=1229517, up={ 279969, 279938 },
      mats = { { 2318, "Light Leather", 3 }, { 4470, "Simple Wood", 2 } },
      q = { [97908]={ m=1454, x=63.4, y=45.4, n="Thuwd" }, [97936]={ m=1412, x=45.0, y=61.4, n="Yonn Deepcut" }, [97960]={ m=1420, x=65.6, y=60.0, n="Rand Rhobart" }, [97971]={ m=2521, x=43.3, y=43.4, n="Mendalass Tattermend" } },
      trainers = {
        { m=1454, x=63.4, y=45.4, n="Thuwd" },
        { m=1456, x=44.4, y=43.1, n="Mooranta" },
        { m=1458, x=70.2, y=59.2, n="Killian Hagey" },
        { m=1411, x=40.8, y=67.9, n="Kagil" },
        { m=1412, x=44.5, y=76.7, n="Nawka Wildsong" },
        { m=1412, x=45.0, y=61.4, n="Yonn Deepcut" },
        { m=1413, x=45.1, y=59.1, n="Dranh" },
        { m=1420, x=32.6, y=65.8, n="Margaret Weaver" },
        { m=1420, x=65.6, y=60.0, n="Rand Rhobart" },
        { m=1443, x=23.2, y=69.7, n="Malux" },
        { m=1444, x=74.5, y=43.0, n="Kulleg Stonehorn" },
        { m=2521, x=43.3, y=43.4, n="Mendalass Tattermend" },
        { m=2521, x=59.6, y=76.1, n="Ishlee Breezewhisper" },
      } },
    { key="tailor", id=197, n="Tailoring", item=279972, itemName="Faction Banner", spell=1229504, up={ 279943, 279959 },
      mats = { { 2996, "Bolt of Linen Cloth", 1 }, { 2320, "Coarse Thread", 1 } },
      q = { [96102]={ m=1454, x=62.9, y=49.2, n="Snang" }, [97937]={ m=1456, x=44.3, y=44.3, n="Vhan" }, [97961]={ m=1420, x=52.6, y=55.5, n="Bowen Brisboise" }, [97972]={ m=2521, x=44.9, y=44.2, n="Taleen Shimmerthread" } },
      trainers = {
        { m=1454, x=62.9, y=49.2, n="Snang" },
        { m=1454, x=63.6, y=49.9, n="Magar" },
        { m=1456, x=44.3, y=44.3, n="Vhan" },
        { m=1456, x=44.5, y=45.4, n="Tepa" },
        { m=1458, x=70.0, y=30.6, n="Rhiannon Davis" },
        { m=1458, x=70.1, y=29.8, n="Victor Ward" },
        { m=1458, x=70.8, y=30.7, n="Josef Gregorian" },
        { m=1413, x=44.9, y=59.4, n="Mahani" },
        { m=1413, x=52.2, y=31.7, n="Kil'hala" },
        { m=1420, x=52.6, y=55.5, n="Bowen Brisboise" },
        { m=1424, x=63.8, y=20.8, n="Daryl Stack" },
        { m=1434, x=28.8, y=76.8, n="Grarnik Goodstitch" },
        { m=2521, x=44.9, y=44.2, n="Taleen Shimmerthread" },
        { m=2521, x=64.4, y=81.2, n="Othesia Evengale" },
      } },
    { key="firstaid", id=129, n="First Aid", item=279968, itemName="First Aid Kit", spell=1230117, up={ 279940, 279951 },
      mats = { { 1251, "Linen Bandage", 3 }, { 159, "Refreshing Spring Water", 1 } },
      q = { [97903]={ m=1411, x=54.2, y=41.9, n="Rawrk" }, [97931]={ m=1412, x=46.1, y=64.0, n="Vira Younghoof" }, [97955]={ m=1420, x=61.8, y=52.8, n="Nurse Neela" }, [97965]={ m=2521, x=43.1, y=46.3, n="Naleeia Tattermend" } },
      trainers = {
        { m=1454, x=34.2, y=84.6, n="Arnok" },
        { m=1456, x=29.7, y=21.2, n="Pand Stonebinder" },
        { m=1458, x=73.2, y=55.1, n="Mary Edras" },
        { m=1411, x=54.2, y=41.9, n="Rawrk" },
        { m=1412, x=46.1, y=64.0, n="Vira Younghoof" },
        { m=1420, x=61.8, y=52.8, n="Nurse Neela" },
        { m=2521, x=43.1, y=46.3, n="Naleeia Tattermend" },
        { m=2521, x=63.2, y=72.6, n="Melasa Fairmend" },
      } },
    { key="fish", id=356, n="Fishing", item=279967, itemName="Fish Bowl", spell=1229745, up={ 279965, 279966 },
      mats = { { 6291, "Raw Brilliant Smallfish", 1 }, { 3371, "Empty Vial", 1 } },
      q = { [97904]={ m=1411, x=53.2, y=81.6, n="Lau'Tiki" }, [97932]={ m=1412, x=44.2, y=63.8, n="Uthan Stillwater" }, [97956]={ m=1420, x=67.2, y=51.0, n="Clyde Kellen" }, [97967]={ m=2521, x=45.0, y=48.4, n="Fenn Fairweather" } },
      trainers = {
        { m=1454, x=69.8, y=29.2, n="Lumak" },
        { m=1456, x=56.1, y=46.4, n="Kah Mistrunner" },
        { m=1458, x=80.7, y=31.3, n="Armand Cromwell" },
        { m=1411, x=53.2, y=81.6, n="Lau'Tiki" },
        { m=1412, x=44.2, y=63.8, n="Uthan Stillwater" },
        { m=1420, x=67.2, y=51.0, n="Clyde Kellen" },
        { m=1434, x=27.5, y=77.1, n="Myizz Luckycatch" },
        { m=1440, x=10.8, y=33.7, n="Kil'Hiwana" },
        { m=1443, x=22.7, y=72.4, n="Lui'Mala" },
        { m=2521, x=45.0, y=48.4, n="Fenn Fairweather" },
        { m=2521, x=63.3, y=75.7, n="Baelann Swiftcurrent" },
      } },
  },
  -- Cooking eğitmenleri (kamp ateşi için)
  cooks = {
    { m=1454, x=57.4, y=54.0, n="Zamja" },
    { m=1456, x=50.7, y=53.1, n="Aska Mistrunner" },
    { m=1458, x=62.1, y=44.9, n="Eunice Burch" },
    { m=1412, x=44.9, y=61.7, n="Pyall Silentstride" },
    { m=1413, x=55.3, y=31.8, n="Duhng" },
    { m=1417, x=74.1, y=33.8, n="Slagg" },
    { m=1420, x=61.8, y=51.4, n="William Pickman" },
    { m=1434, x=31.3, y=28.0, n="Mudduk" },
    { m=2521, x=43.9, y=43.8, n="Zerril Softbreeze" },
    { m=2521, x=60.6, y=72.7, n="Nyalah Brightfire" },
    { m=2548, x=58.6, y=44.6, n="Gorg" },
    { m=1411, x=51.1, y=42.5, n="Cook Torka" },
  },
  -- Satıcılar: genel (Simple Wood + Flint and Tinder; w=1 ise Refreshing Spring Water da satar), ticaret (Empty Vial + Coarse Thread)
  general = {
    { m=1454, x=46.1, y=40.9, n="Asoran", w=1 },
    { m=1454, x=48.1, y=80.5, n="Trak'gen", w=1 },
    { m=1454, x=57.6, y=52.9, n="Xen'to", w=1 },
    { m=1456, x=38.9, y=64.7, n="Kuruk", w=1 },
    { m=1456, x=51.0, y=52.5, n="Naal Mistrunner", w=1 },
    { m=1458, x=62.3, y=43.1, n="Ronald Burch", w=1 },
    { m=1458, x=69.2, y=48.9, n="Eleanor Rusk", w=1 },
    { m=1411, x=54.4, y=42.2, n="Jark", w=1 },
    { m=1411, x=56.3, y=73.4, n="K'waii", w=1 },
    { m=1412, x=45.3, y=61.3, n="Moorat Longstride", w=1 },
    { m=1413, x=51.7, y=29.9, n="Barg", w=1 },
    { m=1413, x=61.9, y=38.8, n="Jazzik", w=1 },
    { m=1416, x=20.9, y=74.6, n="Paige" },
    { m=1417, x=74.1, y=32.4, n="Graud", w=1 },
    { m=1418, x=3.1, y=45.9, n="Grawl", w=1 },
    { m=1420, x=61.2, y=52.6, n="Mrs. Winters", w=1 },
    { m=1421, x=44.0, y=39.9, n="Edwin Harly", w=1 },
    { m=1423, x=69.9, y=53.7, n="Caretaker Alen", w=1 },
    { m=1424, x=62.6, y=19.9, n="Kayren Soothallow", w=1 },
    { m=1425, x=79.4, y=79.1, n="Otho Moji'ko", w=1 },
    { m=1427, x=38.8, y=28.5, n="Master Smith Burninate", w=1 },
    { m=1434, x=28.2, y=74.3, n="Kelsey Yance", w=1 },
    { m=1434, x=31.6, y=27.9, n="Uthok", w=1 },
    { m=1441, x=45.9, y=51.5, n="Jawn Highmesa", w=1 },
    { m=1442, x=45.9, y=58.7, n="Grawnal", w=1 },
    { m=1443, x=24.9, y=71.8, n="Tukk", w=1 },
    { m=1443, x=40.5, y=79.3, n="Super-Seller 680", w=1 },
    { m=1446, x=67.0, y=22.0, n="Jabbey", w=1 },
    { m=1448, x=34.8, y=53.2, n="Bale", w=1 },
    { m=1449, x=43.3, y=7.7, n="Nergal", w=1 },
    { m=1450, x=45.2, y=34.7, n="Daeolyn Summerleaf", w=1 },
    { m=1451, x=51.9, y=39.2, n="Calandrath", w=1 },
    { m=1459, x=49.9, y=82.1, n="Rarck", w=1 },
    { m=2521, x=43.9, y=43.8, n="Zerril Softbreeze" },
    { m=2521, x=63.0, y=77.8, n="Antelariaa Cloudgaze" },
    { m=2548, x=76.7, y=53.2, n="Grizzek" },
  },
  trade = {
    { m=1454, x=47.9, y=80.3, n="Shimra" },
    { m=1454, x=60.6, y=48.9, n="Felika" },
    { m=1456, x=40.6, y=64, n="Shadi Mistrunner" },
    { m=1458, x=64.0, y=37.4, n="Daniel Bartlett" },
    { m=1458, x=64.1, y=50.6, n="Felicia Doan" },
    { m=1411, x=53.0, y=42.0, n="Flakk" },
    { m=1411, x=56.4, y=73.8, n="Tai'tasi" },
    { m=1412, x=45.6, y=61.7, n="Wunna Darkmane" },
    { m=1413, x=51.7, y=30.0, n="Tari'qa" },
    { m=1413, x=61.9, y=38.7, n="Ranik" },
    { m=1417, x=74.1, y=32.7, n="Keena" },
    { m=1420, x=61.0, y=52.4, n="Abigail Shiel" },
    { m=1421, x=43.2, y=40.7, n="Andrew Hilbert" },
    { m=1423, x=70.9, y=48.1, n="Jase Farlane" },
    { m=1424, x=62.3, y=19.0, n="Christoph Jeffcoat" },
    { m=1425, x=34.5, y=38.6, n="Gigget Zipcoil" },
    { m=1434, x=32.7, y=29.2, n="Nerrist" },
    { m=1435, x=44.8, y=56.6, n="Banalash" },
    { m=1441, x=46.2, y=51.5, n="Jandia" },
    { m=1442, x=45.4, y=59.3, n="Kulwia" },
    { m=1443, x=23.1, y=71.6, n="Lah'Mawhani" },
    { m=1443, x=51.0, y=53.5, n="Kireena" },
    { m=1443, x=60.3, y=38.1, n="Vendor-Tron 1000" },
    { m=1444, x=74.5, y=42.7, n="Sheendra Tallgrass" },
    { m=1447, x=45.2, y=90.8, n="Blimo Gadgetspring" },
    { m=1450, x=48.2, y=40.1, n="Lorelae Wintersong" },
    { m=1451, x=49.9, y=36.3, n="Mishta" },
    { m=1452, x=61.2, y=37.2, n="Qia" },
    { m=1459, x=50.1, y=82.2, n="Zora Guthrek" },
    { m=2521, x=44.8, y=45.0, n="Belandiel Farflight" },
    { m=2521, x=59.0, y=75.5, n="Iallion Featherfall" },
  },
}
end

---------------------------------------------------------------------------
-- 2/4 Kamp modülü: meslek kamp eşyaları, kamp buff'ı, hatırlatma (/hm kamp)
---------------------------------------------------------------------------
do
-- Kamp sistemi (WoW Forever): mesleklerin kamp eşyaları, kamp buff'ı ve hatırlatmalar.
--
-- Oyunun kuralları (1.60.1, Kasım 2026):
--   * Kamp ateşini Cooking kurar: Basic Campfire Kit (1 Simple Wood; çantada Flint and Tinder olmalı).
--   * Her oyuncu bir ateşe kendi mesleğinden TEK eşya koyar; bütün kamp eşyaları ortak 1 saat bekler.
--   * Ateşin yanında 1 dakika oturan herkes kamptaki bütün etkileri tek buff olarak alır
--     ("Camp Benefits", 1 saat). Başkasının kampı da olur.
--   * Kamp buff'ı aynı işi gören sınıf buff'ının zayıf kopyasıdır, onunla üst üste binmez
--     (Incense Candle / Arcane Intellect, Enchanted Lute / Mark of the Wild ...).
--   * 1. kademe eşyanın tarifi: meslek 20 olunca eğitmenden (1 gümüş) ya da "Camping 101" göreviyle.
-- Komutlar: /hm kamp (durum ve yapılacaklar), /hm kamp git, /hm kamp sec <eşya|oto>, /hm kamp sessiz

local ADDON, ns = ...
local HM = ns.HM
local Camp = {}
HM.Camp = Camp

local D = ns.CampData
local OK, BAD, WARN, DIM = "|cff80ff80+|r ", "|cffff6060x|r ", "|cffffd100!|r ", "|cff909090-|r "

Camp.skills = {}      -- skill id -> { rank, max }
Camp.skillApi = false -- meslek puanları okunabildi mi

---------------------------------------------------------------------------
-- Sınıfa göre değer (0 = işe yaramaz). Camp Tent ayrıca ele alınır (rested XP).
---------------------------------------------------------------------------
local VALUE = {
    MAGE    = { alch = 4.3, skin = 4.2, fish = 4.1, ench = 3, firstaid = 2.5, tailor = 2, eng = 1, herb = 0, mine = 0, bs = 0 },
    WARRIOR = { mine = 4.3, bs = 4.2, skin = 4.1, fish = 3, ench = 2.5, firstaid = 2, eng = 1, alch = 0, herb = 0, tailor = 0 },
    DRUID   = { mine = 4.3, bs = 4.2, skin = 4.1, fish = 3, firstaid = 2.5, alch = 2, tailor = 1.5, herb = 1.2, eng = 1, ench = 0 },
    DEFAULT = { fish = 4, skin = 3.8, ench = 3.5, firstaid = 3, mine = 2.5, bs = 2.4, alch = 2.3, herb = 2.2, tailor = 2.1, eng = 1 },
}
local WHY0 = {
    MAGE    = { herb = "Arcane Intellect'in zayıf kopyası, onunla üst üste binmez", mine = "yakın dövüş saldırı gücü verir", bs = "Strength verir" },
    WARRIOR = { alch = "mana verir", herb = "Intellect verir", tailor = "Spirit verir" },
    DRUID   = { ench = "Mark of the Wild'ın zayıf kopyası, onunla üst üste binmez" },
}

-- Seviyeye göre etki (beta verisi; oyun içi ipucu esastır).
local function step(level, t)
    local v = t[1][2]
    for i = 1, #t do if level >= t[i][1] then v = t[i][2] end end
    return v
end
local EFFECT = {
    alch = function(l) return string.format("5 sn'de %d mana", step(l, { { 1, 10 }, { 24, 15 }, { 34, 20 }, { 44, 24 }, { 54, 29 } })) end,
    bs = function(l) return string.format("Strength +%d", step(l, { { 1, 6 }, { 24, 11 }, { 38, 20 }, { 52, 34 } })) end,
    ench = function(l)
        return string.format("zırh +%d, bütün statlar +%d",
            step(l, { { 1, 71 }, { 20, 114 }, { 30, 163 }, { 40, 211 }, { 50, 260 }, { 60, 308 } }),
            step(l, { { 1, 2 }, { 20, 4 }, { 30, 7 }, { 40, 9 }, { 50, 12 }, { 60, 13 } }))
    end,
    eng = function() return "reagent satıcısı (buff değil)" end,
    herb = function(l) return string.format("Intellect +%d", step(l, { { 1, 2 }, { 14, 6 }, { 28, 12 }, { 42, 18 }, { 56, 25 } })) end,
    lw = function() return "rested XP'yi seviyenin %5'ine tamamlar" end,
    mine = function(l) return string.format("yakın dövüş saldırı gücü +%d", step(l, { { 1, 12 }, { 12, 20 }, { 22, 32 }, { 32, 49 }, { 42, 67 }, { 52, 90 } })) end,
    skin = function() return "kritik şansı +%2" end,
    tailor = function(l) return string.format("Spirit +%d", step(l, { { 1, 14 }, { 40, 19 }, { 50, 27 }, { 60, 32 } })) end,
    firstaid = function(l) return string.format("Stamina +%d", step(l, { { 1, 3 }, { 12, 8 }, { 24, 21 }, { 36, 34 }, { 48, 45 }, { 60, 56 } })) end,
    fish = function() return "bütün statlar +%8" end,
}
function Camp.Effect(key, level)
    local f = EFFECT[key]
    return f and f(level or HM:Level()) or ""
end

---------------------------------------------------------------------------
-- İstemci yardımcıları (hepsi korumalı: API yoksa ya da gizli değer dönerse nil)
---------------------------------------------------------------------------
local function safe(v) if HM.IsSecret(v) then return nil end return v end

local function count(id)
    local c = HM.Guide and HM.Guide.ItemCount and HM.Guide.ItemCount(id)
    return c or 0
end

local function spellKnown(id)
    if HM.Guide and HM.Guide.SpellKnown then return HM.Guide.SpellKnown(id) end
    return nil
end

local function flagged(qid)
    return HM.Guide and HM.Guide.QuestDone and HM.Guide.QuestDone(qid) or false
end

-- Eşyanın bekleme süresi: kalan saniye (0 = hazır), okunamıyorsa nil.
local function itemCooldown(id)
    local start, dur
    if C_Container and C_Container.GetItemCooldown then
        local ok, a, b = pcall(C_Container.GetItemCooldown, id)
        if ok then start, dur = a, b end
    end
    if start == nil and C_Item and C_Item.GetItemCooldown then
        local ok, a, b = pcall(C_Item.GetItemCooldown, id)
        if ok then start, dur = a, b end
    end
    if start == nil and GetItemCooldown then
        local ok, a, b = pcall(GetItemCooldown, id)
        if ok then start, dur = a, b end
    end
    if type(start) ~= "number" or type(dur) ~= "number" or HM.IsSecret(start) or HM.IsSecret(dur) then return nil end
    if start == 0 or dur <= 1.5 then return 0 end
    local left = start + dur - GetTime()
    if left <= 0 then return 0 end
    return left
end

local function restedPct()
    local ex = GetXPExhaustion and GetXPExhaustion() or 0
    local mx = UnitXPMax and UnitXPMax("player") or 0
    ex, mx = safe(ex), safe(mx)
    if type(ex) ~= "number" then ex = 0 end
    if type(mx) ~= "number" or mx <= 0 then return nil end
    return ex / mx * 100
end

local function mins(sec)
    if not sec then return "?" end
    if sec < 60 then return "<1 dk" end
    return string.format("%d dk", math.floor(sec / 60 + 0.5))
end

local function where(loc)
    if not loc then return "?" end
    return string.format("%s (%s %.0f, %.0f)", loc.n or "?", HM:MapName(loc.m), loc.x or 0, loc.y or 0)
end

local CAPITAL = { [1454] = true, [1456] = true, [1458] = true }

-- Nokta oyuncunun bulunduğu kasabada mı (başkentte şehrin tamamı, başka yerde ~500 yd)?
local function inTown(loc)
    if not (loc and loc.m and HM:PlayerMapChain()[loc.m] == true) then return false end
    if CAPITAL[loc.m] then return true end
    local px, py, pc = HM:PlayerWorldPos()
    local wx, wy, wc = HM:MapWorldPos(loc.m, loc.x, loc.y)
    if not (px and wx) or pc ~= wc then return false end
    return math.sqrt((wx - px) ^ 2 + (wy - py) ^ 2) <= 500
end

---------------------------------------------------------------------------
-- Meslek puanları
---------------------------------------------------------------------------
local NAMES   -- meslek adı (İngilizce) -> skill id; eski API'ler ad döndürür

local function names()
    if NAMES then return NAMES end
    NAMES = { ["Cooking"] = D.cooking }
    for _, p in ipairs(D.prof) do NAMES[p.n] = p.id end
    return NAMES
end

local function allIds()
    local t = { D.cooking }
    for _, p in ipairs(D.prof) do t[#t + 1] = p.id end
    return t
end

function Camp:ScanSkills()
    local out, api = {}, false
    -- 1) Forever: doğrudan kimlikle
    if C_SkillInfo and C_SkillInfo.GetSkillLineInfoByID then
        for _, id in ipairs(allIds()) do
            local ok, info = pcall(C_SkillInfo.GetSkillLineInfoByID, id)
            if ok then
                api = true
                if type(info) == "table" then
                    local r, m = safe(info.rank), safe(info.maxRank)
                    if type(r) == "number" and r > 0 then out[id] = { rank = r, max = type(m) == "number" and m or 0 } end
                end
            end
        end
    end
    -- 2) Sıra numarasıyla (C_SkillInfo ya da eski genel işlevler)
    if next(out) == nil then
        local map = names()
        if C_SkillInfo and C_SkillInfo.GetNumSkillLines and C_SkillInfo.GetSkillLineInfo then
            local okN, n = pcall(C_SkillInfo.GetNumSkillLines)
            if okN and type(n) == "number" then
                api = true
                for i = 1, n do
                    local ok, info = pcall(C_SkillInfo.GetSkillLineInfo, i)
                    if ok and type(info) == "table" and not info.isHeader then
                        local id = info.skillID or map[info.name or ""]
                        local r, m = safe(info.rank), safe(info.maxRank)
                        if id and type(r) == "number" and r > 0 then out[id] = { rank = r, max = type(m) == "number" and m or 0 } end
                    end
                end
            end
        elseif GetNumSkillLines and GetSkillLineInfo then
            local okN, n = pcall(GetNumSkillLines)
            if okN and type(n) == "number" then
                api = true
                for i = 1, n do
                    local ok, name, isHeader, _, rank, _, _, maxRank = pcall(GetSkillLineInfo, i)
                    if ok and name and not isHeader and map[name] and type(rank) == "number" and rank > 0 then
                        out[map[name]] = { rank = rank, max = maxRank or 0 }
                    end
                end
            end
        end
    end
    -- 3) GetProfessions (iki ana meslek + ikinciller)
    if next(out) == nil and GetProfessions and GetProfessionInfo then
        local map = names()
        local ok, a, b, c, d, e, f = pcall(GetProfessions)
        if ok then
            api = true
            for _, idx in ipairs({ a or false, b or false, c or false, d or false, e or false, f or false }) do
                if idx then
                    local ok2, name, _, rank, maxRank, _, _, line = pcall(GetProfessionInfo, idx)
                    local id = ok2 and ((type(line) == "number" and line) or map[name or ""])
                    if id and type(rank) == "number" and rank > 0 then out[id] = { rank = rank, max = maxRank or 0 } end
                end
            end
        end
    end
    self.skills = out
    self.skillApi = api
    return out
end

-- Trainer modülü için: { name, rank, max } listesi (adlar İngilizce).
function Camp:Professions()
    self:ScanSkills()
    local out = {}
    local byId = { [D.cooking] = "Cooking" }
    for _, p in ipairs(D.prof) do byId[p.id] = p.n end
    for id, s in pairs(self.skills) do
        out[#out + 1] = { id = id, name = byId[id] or tostring(id), rank = s.rank, max = s.max }
    end
    table.sort(out, function(x, y) return x.id < y.id end)
    return out
end

---------------------------------------------------------------------------
-- Buff'lar: Camp Benefits (1 saat), Boosted Rest (çadır kilidi), Campfire Nearby, Welcoming Campfire
---------------------------------------------------------------------------
local function auraEntry(a)
    local e = {}
    local exp = safe(a.expirationTime)
    if type(exp) == "number" and exp > 0 then e.exp = exp end
    return e
end

-- Döndürür: { benefits = {exp=}, boosted = {...}, nearby = {...}, welcome = {...} } ya da nil (okunamadı).
function Camp:ScanAuras()
    if C_Secrets and C_Secrets.ShouldAurasBeSecret then
        local ok, s = pcall(C_Secrets.ShouldAurasBeSecret)
        if ok and s == true then return nil end
    end
    local res, readable = {}, false
    if C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
        for key, id in pairs(D.aura) do
            local ok, a = pcall(C_UnitAuras.GetPlayerAuraBySpellID, id)
            if ok then
                readable = true
                if type(a) == "table" then res[key] = auraEntry(a); self.idsSeen = true end
            end
        end
    end
    -- Kimlikler hiç doğrulanmadıysa (ya da doğrudan sorgu yoksa) adla da tara: kimlik farklıysa öğren.
    local now = GetTime()
    if not self.idsSeen and (not readable or now - (self.nameScanAt or -100) >= 20) then
        self.nameScanAt = now
        local byName = {}
        for key, n in pairs(D.auraName) do byName[n] = key end
        for _, filter in ipairs({ "HELPFUL", "HARMFUL" }) do
            for i = 1, 40 do
                local a
                if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
                    local ok, r = pcall(C_UnitAuras.GetAuraDataByIndex, "player", i, filter)
                    if not ok then break end
                    a = r
                elseif UnitAura then
                    local ok, n, _, _, _, _, exp, _, _, _, sid = pcall(UnitAura, "player", i, filter)
                    if not ok then break end
                    if n then a = { name = n, expirationTime = exp, spellId = sid } end
                else
                    break
                end
                readable = true
                if not a then break end
                local nm = safe(a.name)
                local key = nm and byName[nm]
                if key then
                    res[key] = auraEntry(a)
                    local sid = safe(a.spellId)
                    if type(sid) == "number" and sid > 0 then D.aura[key] = sid end
                    self.idsSeen = true
                end
            end
        end
    end
    if not readable then return nil end
    return res
end

---------------------------------------------------------------------------
-- Durum hesabı
---------------------------------------------------------------------------
local function matsText(p)
    local parts = {}
    for _, m in ipairs(p.mats) do
        local have = count(m[1])
        parts[#parts + 1] = string.format("%s%s %d/%d|r", have >= m[3] and "|cff80ff80" or "|cffff8080", m[2], have, m[3])
    end
    return table.concat(parts, ", ")
end

local BUY = { [3371] = "trade", [2320] = "trade", [4470] = "general", [159] = "water" }

-- Satıcıda bulunmayan malzeme nereden gelir (kısa ipucu).
local SOURCE = {
    fish = "Raw Brilliant Smallfish balıkla tutulur (başlangıç bölgelerinin ve başkentlerin tatlı suları)",
    firstaid = "Linen Bandage = 1 Linen Cloth (First Aid)",
    lw = "Light Leather: deri yüzerek ya da açık artırmadan",
    skin = "Light Leather: deri yüzerek",
    tailor = "Bolt of Linen Cloth = 2 Linen Cloth (Tailoring)",
    alch = "Peacebloom: ot toplayarak ya da açık artırmadan",
    herb = "Peacebloom ve Silverleaf: ot toplayarak",
    mine = "Rough Stone ve Copper Bar: Copper Vein kazıp eriterek",
    bs = "Rough Stone ve Copper Bar: madenciden ya da açık artırmadan",
    ench = "Strange Dust: yeşil eşya bozarak (Disenchant)",
    eng = "Copper Bolts ve Copper Tube: Engineering ile yapılır",
}

-- Satıcıda olmayan malzemelerden eksik var mı?
local function missingGathered(p)
    for _, m in ipairs(p.mats) do
        if count(m[1]) < m[3] and not BUY[m[1]] then return true end
    end
    return false
end

-- Eksik malzemelerden satıcıda bulunan ilki için en yakın satıcı.
local function vendorFor(p)
    for _, m in ipairs(p.mats) do
        if count(m[1]) < m[3] and BUY[m[1]] then
            local kind = BUY[m[1]]
            if kind == "trade" then return (HM:Nearest(D.trade)) end
            if kind == "general" then return (HM:Nearest(D.general)) end
            local list = {}
            for _, v in ipairs(D.general) do if v.w then list[#list + 1] = v end end
            return (HM:Nearest(list))
        end
    end
end

local function questInLog(p)
    for qid, loc in pairs(p.q or {}) do
        if HM:IsInQuestLog(qid, nil) then return loc, qid end
    end
end

local function introDone()
    for _, q in ipairs(D.introAll) do if flagged(q) then return true end end
    return false
end

function Camp:Compute()
    local now = GetTime()
    local db = HM.db
    db.camp = db.camp or {}
    local level = HM:Level()
    local _, class = UnitClass("player")
    local st = { now = now, level = level, class = class }

    self:ScanSkills()
    local fresh = self:ScanAuras()
    if fresh then self.auras = fresh end
    local au = self.auras or {}
    st.aurasKnown = self.auras ~= nil

    local function present(key)
        local a = au[key]
        if not a then return false, nil end
        if a.exp then
            local left = a.exp - now
            if left <= 0 then return false, nil end
            return true, left
        end
        return true, nil
    end
    st.buffOn, st.buffLeft = present("benefits")
    st.boosted, st.boostedLeft = present("boosted")
    st.nearby = fresh ~= nil and (present("nearby"))
    st.welcome, st.welcomeLeft = present("welcome")
    if fresh == nil then st.welcome = false end
    -- Kamp ateşi karşılaşması: aynı ateş için tek hatırlatma. Dibinde 90 sn bekleyip buff alamadıysan
    -- (ör. yalnız dinlenme veren ateş) ya da 3 dk yanına gitmediysen o ateş için susar; 1 dk uzaklaşınca sıfırlanır.
    if fresh ~= nil then
        if st.welcome or st.nearby then
            self.nearLost = nil
            if not self.nearAt then self.nearAt, self.nearSpent, self.atFireAt, self.nearTold = now, false, nil, false end
            if st.welcome then
                if not self.atFireAt then self.atFireAt = now; self.nearSpent = false end
                if now - self.atFireAt >= 90 then self.nearSpent = true end
            else
                self.atFireAt = nil
                if now - self.nearAt >= 180 then self.nearSpent = true end
            end
        elseif self.nearAt then
            self.nearLost = self.nearLost or now
            if now - self.nearLost >= 60 then self.nearAt, self.nearLost = nil, nil end
        end
    end
    if st.buffOn and st.buffLeft then db.camp.buffUntil = time() + math.floor(st.buffLeft) end
    if st.aurasKnown and not st.buffOn then db.camp.buffUntil = nil end
    if not st.aurasKnown and db.camp.buffUntil then
        -- Giriş anında buff'lar henüz okunamadıysa son bilinen süreyi kullan.
        local left = db.camp.buffUntil - time()
        if left > 0 then st.buffOn, st.buffLeft = true, left end
    end

    -- Kamp ateşi
    for _, f in ipairs(D.fire) do
        local c = count(f.id)
        if c > 0 and not st.kit then st.kit = { id = f.id, n = f.n, count = c } end
    end
    st.wood, st.flint = count(D.wood), count(D.flint)
    st.cook = self.skills[D.cooking] and self.skills[D.cooking].rank or nil
    st.kitKnown = spellKnown(D.kitSpell)

    -- Adaylar: karakterin bildiği meslekler (puan okunamıyorsa çantadaki eşyalar)
    local values = VALUE[class] or VALUE.DEFAULT
    local rested = restedPct()
    st.rested = rested
    local cands = {}
    for _, p in ipairs(D.prof) do
        local sk = self.skills[p.id]
        local cnt = count(p.item)
        for _, u in ipairs(p.up) do cnt = cnt + count(u) end
        if sk or (not self.skillApi and cnt > 0) then
            local c = { p = p, rank = sk and sk.rank or nil, count = cnt }
            c.known = spellKnown(p.spell)
            c.value = values[p.key] or 2
            if c.value == 0 then c.why = WHY0[class] and WHY0[class][p.key] or "bu sınıfa katkısı yok" end
            if p.key == "lw" then
                if level >= 60 then
                    c.value, c.why = 0, "60. seviyede rested XP gerekmez"
                elseif st.boosted then
                    c.value, c.hold = 0.5, "çadır kilidi (Boosted Rest) bitince"
                elseif rested and rested >= 5 then
                    c.value, c.hold = 0.5, "rested XP zaten %5'in üstünde"
                else
                    c.value = 9
                end
            end
            c.ok = (c.rank or 20) >= 20
            c.ready = c.ok and cnt > 0
            if db.camp.pick == p.key then c.forced = true end
            cands[#cands + 1] = c
        end
    end
    table.sort(cands, function(x, y)
        if (x.forced and 1 or 0) ~= (y.forced and 1 or 0) then return x.forced and true or false end
        if x.value ~= y.value then return x.value > y.value end
        return x.p.id < y.p.id
    end)
    st.cands = cands
    for _, c in ipairs(cands) do
        if not st.goal and (c.value > 0 or c.forced) then st.goal = c end
        if not st.pick and c.ready and (c.value > 0 or c.forced) then st.pick = c end
    end

    -- Ortak bekleme süresi (bütün kamp eşyaları paylaşır)
    local cdItem = (st.pick and st.pick.p.item) or (cands[1] and cands[1].p.item) or D.prof[#D.prof].item
    st.cd = itemCooldown(cdItem)

    -- Şimdi yapılacak iş
    local taxi = UnitOnTaxi and UnitOnTaxi("player")
    local dead = UnitIsDeadOrGhost and UnitIsDeadOrGhost("player")
    local resting = IsResting and IsResting()
    local inInst = false
    if IsInInstance then
        local ok, a = pcall(IsInInstance)
        inInst = ok and a and true or false
    end
    st.resting = resting and true or false
    if taxi or dead then
        st.action = nil
    elseif (st.welcome or st.nearby) and not self.nearSpent and (not st.buffOn or (st.buffLeft and st.buffLeft < 1200)) then
        -- Yakında (Campfire Nearby) ya da dibinde (Welcoming Campfire) kamp ateşi var: 1 dk otur.
        st.action = "sit"
    elseif st.pick and (st.cd or 0) == 0 and st.aurasKnown then
        local need
        if st.pick.p.key == "lw" and not st.pick.forced then
            need = st.pick.value >= 9
        else
            need = (not st.buffOn) or (st.buffLeft ~= nil and st.buffLeft < 300)
        end
        if need and not resting and not inInst then
            st.action = st.kit and "place" or "fire"
        end
    end

    st.errands = self:Errands(st)
    for _, e in ipairs(st.errands) do
        if e.loc and e.town and inTown(e.loc) then st.cityErrand = e break end
    end

    -- Beceri 20'ye ulaştı, tarif yok: bir kez haber ver.
    db.camp.told = db.camp.told or {}
    for _, c in ipairs(cands) do
        if (c == st.goal or c.forced) and c.rank and c.rank >= 20 and c.known == false and c.count == 0 and not db.camp.told[c.p.key] then
            db.camp.told[c.p.key] = true
            local t = (HM:Nearest(c.p.trainers)) or (questInLog(c.p))
            HM:Print(string.format("|cffffd100Kamp:|r %s becerin %d, %s tarifini öğrenebilirsin (%s): %s",
                c.p.n, c.rank, c.p.itemName, Camp.Effect(c.p.key, level), where(t)))
        end
    end

    self.state = st
    return st
end

---------------------------------------------------------------------------
-- Yapılacaklar listesi (öncelik sırasıyla). e = { text, loc, town }
---------------------------------------------------------------------------
function Camp:Errands(st)
    local out = {}
    local function add(text, loc, town) out[#out + 1] = { text = text, loc = loc, town = town } end
    local level = st.level

    -- Düşük seviyede tanıtım görevleri (XP verir; yüksek seviyede gri olur)
    if level <= 12 and not introDone() then
        local t = HM:Nearest(D.intro)
        if t then add(string.format("The Great Outdoors görevi (405 XP, kampı tanıtır): %s. Önce görevi al, sonra ateşin yanında /sit yaz.", where(t)), t, false) end
    end

    -- Kamp ateşi: Cooking + kit
    if self.skillApi and not st.cook then
        local t = HM:Nearest(D.cooks)
        add("Cooking öğren (kamp ateşini Cooking kurar): " .. where(t), t, true)
    elseif st.kitKnown == false and not st.kit then
        local t = HM:Nearest(D.cooks)
        add("Basic Campfire Kit tarifini Cooking eğitmeninden al (vermiyorsa Cooking'i 20'ye çıkar): " .. where(t), t, true)
    end
    if not st.kit and (st.cook or not self.skillApi) then
        if st.wood > 0 and st.flint > 0 then
            add(string.format("Cooking penceresinden Basic Campfire Kit yap (Simple Wood %d var; her kit 1 odun).", st.wood))
        else
            local v = HM:Nearest(D.general)
            add(string.format("Kamp ateşi için %s al: %s", st.flint > 0 and "Simple Wood" or "Simple Wood ve Flint and Tinder", where(v)), v, true)
        end
    end

    -- İşe yarayan meslek eşyaları: en iyi iki aday (saatte tek eşya konabildiği için fazlası gürültü)
    local shown = 0
    for _, c in ipairs(st.cands) do
        if (c.value > 0 or c.forced) and shown < 2 then
            local p = c.p
            shown = shown + 1
            if not c.ok then
                add(string.format("%s %d/20: %s için %d puan daha (%s).", p.n, c.rank, p.itemName, 20 - c.rank, Camp.Effect(p.key, level)))
            elseif c.count == 0 then
                if c.known == false then
                    -- Tarif: en yakın eğitmen (1 gümüş). Günlükte Camping 101 varsa ve teslim NPC'si buradaysa ona.
                    local qloc = questInLog(p)
                    local t = HM:Nearest(p.trainers)
                    if qloc and (inTown(qloc) or not t) then
                        add(string.format("%s tarifi: Camping 101 görevini teslim et: %s", p.itemName, where(qloc)), qloc, true)
                    else
                        local extra = qloc and string.format(" (günlükteki Camping 101 görevinin teslim yeri: %s)", qloc.n or "?") or ""
                        add(string.format("%s tarifini öğren (1 gümüş, %s): %s%s", p.itemName, Camp.Effect(p.key, level), where(t), extra), t, true)
                    end
                else
                    local v = vendorFor(p)
                    local txt = string.format("%s yap (%s penceresi): %s", p.itemName, p.n, matsText(p))
                    if c.known == nil then txt = txt .. " — tarifi yoksa eğitmenden öğren" end
                    if missingGathered(p) and SOURCE[p.key] then txt = txt .. ". " .. SOURCE[p.key] end
                    if v then txt = txt .. ". Satıcı: " .. where(v) end
                    add(txt, v, v and true or false)
                end
            end
        end
    end

    -- Düşük seviyede meslek başına Camping 101 görevi (270 XP)
    if level <= 12 and introDone() then
        local giver = HM:Nearest(D.intro)
        for _, c in ipairs(st.cands) do
            local p = c.p
            local done = false
            for qid in pairs(p.q or {}) do if flagged(qid) then done = true end end
            if not done and c.known ~= true and not questInLog(p) and giver then
                add(string.format("Camping 101: %s görevini al (270 XP): %s", p.n, where(giver)), giver, false)
            end
        end
    end

    -- İşe yarar hiçbir aday yoksa yer tutmayan ikincil meslekleri öner (First Aid bezle kendiliğinden çıkar;
    -- Fishing 20 için ~10 dk balık tutmak gerekir).
    if not st.goal and self.skillApi then
        local NOTE = { firstaid = "Linen Cloth ile çıkar", fish = "20 için ~10 dk balık tutmak gerekir" }
        for _, key in ipairs({ "firstaid", "fish" }) do
            for _, p in ipairs(D.prof) do
                if p.key == key and not self.skills[p.id] then
                    local t = HM:Nearest(p.trainers)
                    add(string.format("%s öğren (ikincil meslek, yer tutmaz; %s): 20'de %s → %s. Eğitmen: %s",
                        p.n, NOTE[key], p.itemName, Camp.Effect(p.key, level), where(t)), t, true)
                end
            end
        end
    end
    return out
end

---------------------------------------------------------------------------
-- Metinler
---------------------------------------------------------------------------
local function pickEffect(st)
    local c = st.pick
    if not c then return "" end
    return Camp.Effect(c.p.key, st.level)
end

function Camp:ActionText(st)
    st = st or self.state
    if not st or not st.action then return nil end
    if st.action == "sit" then
        local own = ""
        if st.pick and (st.cd or 0) == 0 then own = string.format(" Önce %s koy.", st.pick.p.itemName) end
        if st.welcome then
            -- Ateşin dibindesin; oturunca geri sayım başlar (süre okunabiliyorsa göster).
            local left = ""
            if st.welcomeLeft and st.welcomeLeft <= 61 then left = string.format(" %d sn kaldı.", math.ceil(st.welcomeLeft)) end
            return "|cffffd100Kamp ateşinin yanındasın:|r /sit ile 1 dk otur, kamp buff'ı 1 saat." .. left .. own
        end
        return "|cffffd100Yakında kamp ateşi var:|r yanına gidip /sit ile 1 dk otur, kamp buff'ı 1 saat." .. own
    elseif st.action == "place" then
        return string.format("|cffffd100Kamp zamanı:|r %s kur, %s koy, /sit ile 1 dk otur (%s, 1 saat).",
            st.kit.n, st.pick.p.itemName, pickEffect(st))
    elseif st.action == "fire" then
        return string.format("|cffffd100Kamp:|r %s hazır ama kamp ateşi kitin yok. /hm kamp", st.pick.p.itemName)
    end
end

-- Rehber penceresinin alt satırı: şimdi yapılacak iş ya da bulunduğun kasabadaki kamp işi.
function Camp:ActionLine()
    local st = self.state
    if not st then return nil end
    local t = self:ActionText(st)
    if t then return t end
    if st.cityErrand and not HM:InCombat() then
        return "|cffffd100Kamp işi:|r " .. st.cityErrand.text
    end
    return nil
end

-- Durum satırındaki kısa işaret.
function Camp:Token()
    local st = self.state
    if not st then return nil end
    if st.buffOn then
        if st.buffLeft then return string.format("|cff80ff80Kamp %d dk|r", math.max(1, math.floor(st.buffLeft / 60 + 0.5))) end
        return "|cff80ff80Kamp|r"
    end
    if st.action then return "|cffffd100Kamp!|r" end
    if st.pick then
        if st.cd and st.cd > 0 then return string.format("|cff909090Kamp %d dk|r", math.ceil(st.cd / 60)) end
        return "|cffffd100Kamp|r"
    end
    if st.goal then return "|cffff6060Kamp|r" end
    return "|cff606060Kamp|r"
end

---------------------------------------------------------------------------
-- /hm kamp
---------------------------------------------------------------------------
function Camp:Status()
    local st = self:Compute()
    local level = st.level
    HM:Print("|cff33ccff— Kamp (meslek buff'ları) —|r")
    if self.lastError then HM:Print("|cffff8080Son hata (bildirirken bunu gönder):|r " .. self.lastError) end

    if st.buffOn then
        HM:Print(OK .. "Kamp buff'ı (Camp Benefits) aktif" .. (st.buffLeft and (": " .. mins(st.buffLeft) .. " kaldı") or "") .. ".")
    elseif st.aurasKnown then
        HM:Print(BAD .. "Kamp buff'ı yok.")
    else
        HM:Print(WARN .. "Buff'lar şu an okunamıyor (savaşta gizli); savaş bitince tekrar dene.")
    end

    if st.kit then
        HM:Print(OK .. string.format("Kamp ateşi: %s x%d (Simple Wood %d).", st.kit.n, st.kit.count, st.wood))
    elseif st.cook or not self.skillApi then
        HM:Print(BAD .. string.format("Kamp ateşi kiti yok (Simple Wood %d, Flint and Tinder %d).", st.wood, st.flint))
    else
        HM:Print(BAD .. "Cooking yok: kamp ateşi kuramazsın (başkasının ateşine eşya koyabilirsin).")
    end

    if not self.skillApi then
        HM:Print(WARN .. "Meslek puanları okunamadı; çantadaki kamp eşyalarına göre gidiyorum.")
    end
    if #st.cands == 0 then
        HM:Print(BAD .. "Kamp eşyası koyabileceğin bir mesleğin yok.")
    end
    for _, c in ipairs(st.cands) do
        local p = c.p
        local head = string.format("%s%s", p.n, c.rank and (" " .. c.rank) or "")
        local eff = Camp.Effect(p.key, level)
        if c.value == 0 and not c.forced then
            HM:Print(DIM .. string.format("%s → %s (%s): |cff909090sana yaramaz, %s.|r", head, p.itemName, eff, c.why or ""))
        elseif not c.ok then
            HM:Print(WARN .. string.format("%s → %s (%s): beceri 20 gerekli.", head, p.itemName, eff))
        elseif c.count > 0 then
            local note = c.hold and (" |cff909090(" .. c.hold .. ")|r") or ""
            local mark = (st.pick == c) and " |cff80ff80← önerilen|r" or ""
            HM:Print(OK .. string.format("%s → %s x%d (%s)%s%s", head, p.itemName, c.count, eff, mark, note))
        elseif c.known == false then
            HM:Print(BAD .. string.format("%s → %s (%s): tarif öğrenilmemiş.", head, p.itemName, eff))
        else
            HM:Print(BAD .. string.format("%s → %s (%s): çantada yok. Malzeme: %s", head, p.itemName, eff, matsText(p)))
        end
    end

    if st.pick then
        if st.cd == nil then
            HM:Print(WARN .. "Bekleme süresi okunamadı.")
        elseif st.cd > 0 then
            HM:Print(WARN .. "Sıradaki kamp eşyası " .. mins(st.cd) .. " sonra konabilir (bütün kamp eşyaları ortak 1 saat bekler).")
        else
            HM:Print(OK .. "Kamp eşyası koymaya hazırsın.")
        end
    end

    local act = self:ActionText(st)
    if act then HM:Print(act) end
    if st.resting and st.pick and not act then
        HM:Print(WARN .. "Şehirde ve handa kamp kurulmaz; dışarı çıkınca hatırlatırım.")
    end

    if #st.errands > 0 then
        HM:Print("|cff33ccffYapılacaklar:|r")
        for i, e in ipairs(st.errands) do HM:Print(string.format("  %d. %s", i, e.text)) end
        HM:Print("  |cffffd100/hm kamp git|r oku ilk işe çevirir.")
    end

    HM:Print("|cff909090Kural: ateşe tek eşya koyarsın, hepsi ortak 1 saat bekler; yanında 1 dk oturan herkes buff alır. Yolda gördüğün her kampa otur.|r")
    if level < 60 and not self.skills[165] then
        HM:Print("|cff909090En değerlisi Camp Tent (Leatherworking 20, 5 Light Leather): saatte bir rested XP'yi seviyenin %5'ine tamamlar.|r")
    end
    HM:Print("|cff909090Legacy (25+): Reagent Economy 1. kademe eşyaları malzemesiz yapar, Permanence süreyi %50 uzatır, Field Guide beklemeyi kısaltır.|r")
    HM:Print("Seçim: |cffffd100/hm kamp sec fish|r (alch bs ench eng herb lw mine skin tailor firstaid fish, |cffffd100oto|r = kendim seçerim). Hatırlatma: |cffffd100/hm kamp sessiz|r")
end

function Camp:Go()
    local st = self:Compute()
    for _, e in ipairs(st.errands) do
        if e.loc and e.loc.m and HM.Arrow then
            HM.Arrow:SetTarget(e.loc.m, e.loc.x, e.loc.y, "Kamp: " .. (e.loc.n or ""), "camp")
            HM:Print("Ok kamp işinde: " .. where(e.loc) .. ". Başlığa tıklayınca adıma döner.")
            return
        end
    end
    HM:Print("Gidilecek bir kamp işi yok.")
end

function Camp:Command(arg)
    arg = (arg or ""):lower()
    local a, b = arg:match("^(%S*)%s*(.-)$")
    local db = HM.db
    db.camp = db.camp or {}
    if a == "sessiz" or a == "sus" then
        db.camp.silent = not db.camp.silent
        HM:Print("Kamp hatırlatması: " .. (db.camp.silent and "kapalı" or "açık"))
    elseif a == "git" then
        self:Go()
    elseif a == "sec" or a == "seç" then
        if b == "" or b == "oto" or b == "auto" then
            db.camp.pick = nil
            HM:Print("Kamp eşyasını sınıfına göre kendim seçeceğim.")
        else
            local found
            for _, p in ipairs(D.prof) do
                if p.key == b or p.n:lower() == b or p.itemName:lower() == b then found = p end
            end
            if found then
                db.camp.pick = found.key
                HM:Print(string.format("Kamp eşyası seçildi: %s (%s).", found.itemName, found.n))
            else
                HM:Print("Bilinmeyen eşya. Anahtarlar: alch bs ench eng herb lw mine skin tailor firstaid fish, oto")
            end
        end
        self:Compute()
    else
        self:Status()
    end
end

-- Kamp görevleri rota dışı olsa da otomatik alınır/teslim edilir.
function Camp:IsCampQuest(qid)
    return D.quests[qid] == true
end

---------------------------------------------------------------------------
-- Döngü ve hatırlatma
---------------------------------------------------------------------------
function Camp:Remind()
    local st = self.state
    local db = HM.db
    if not st or not st.action or (db.camp and db.camp.silent) or HM.inInstance then
        if not (st and st.action) then self.lastKey = nil end
        return
    end
    local now = GetTime()
    local key = st.action .. ":" .. (st.pick and st.pick.p.key or "")
    if st.action == "sit" then
        -- Aynı kamp ateşi için bir kez.
        if self.nearTold then return end
        self.nearTold = true
    elseif self.lastKey == key then
        -- Aynı iş için: 10 dk arayla iki kez, sonra 30 dk'da bir (ısrar etme).
        local gap = ((self.repeats or 0) >= 2) and 1800 or 600
        if now - (self.lastAt or 0) < gap then return end
        self.repeats = (self.repeats or 0) + 1
    else
        self.repeats = 0
    end
    self.lastKey, self.lastAt = key, now
    local t = self:ActionText(st)
    if t then
        if not self.hinted then
            self.hinted = true
            t = t .. " |cff909090(ayrıntı /hm kamp, kapatmak /hm kamp sessiz)|r"
        end
        HM:Print(t)
    end
end

-- Girişte tek satır: kamp eşyası durumu (hazır mı, ne eksik).
function Camp:LoginNote()
    local db = HM.db
    if not db or (db.camp and db.camp.silent) or HM.inInstance or HM:InCombat() then return end
    local st = self:Compute()
    if st.action then return end          -- zaten hatırlatma gidecek
    local c = st.pick or st.goal
    if not c then return end
    if st.pick then
        if st.buffOn then return end
        local wait = (st.cd and st.cd > 0) and (", " .. mins(st.cd) .. " sonra konabilir") or ""
        HM:Print(string.format("|cffffd100Kamp:|r %s x%d hazır (%s)%s. /hm kamp", c.p.itemName, c.count, Camp.Effect(c.p.key, st.level), wait))
    elseif c.ok then
        HM:Print(string.format("|cffffd100Kamp:|r %s çantada yok (%s). Yapılacaklar: /hm kamp", c.p.itemName, Camp.Effect(c.p.key, st.level)))
    end
end

function Camp:Tick()
    if not HM.db or HM:InCombat() then return end
    self:Compute()
    self:Remind()
end

local function loop()
    local ok, err = pcall(Camp.Tick, Camp)
    if not ok then
        -- Sessizce yut ama kaydet: /hm kamp son hatayı gösterir (sorun bildirirken işe yarar).
        Camp.lastError = tostring(err)
        if HM.db and HM.db.debug and not Camp.errorShown then
            Camp.errorShown = true
            HM:Print("|cffff8080Kamp modülünde hata:|r " .. Camp.lastError)
        end
    end
    C_Timer.After(5, loop)
end

HM:OnLogin(function()
    HM.db.camp = HM.db.camp or {}
    C_Timer.After(8, loop)
    C_Timer.After(25, function() pcall(Camp.LoginNote, Camp) end)
end)

HM:On("PLAYER_REGEN_ENABLED", function()
    C_Timer.After(2, function() pcall(Camp.Tick, Camp) end)
end)
HM:On("SKILL_LINES_CHANGED", function()
    C_Timer.After(1, function() pcall(Camp.Tick, Camp) end)
end)
end

---------------------------------------------------------------------------
-- 3/4 XP buff takibi: yemek, uyku tulumu, rested (/hm xp)
---------------------------------------------------------------------------
do
-- XP buff takibi: yemek (Well Fed), uyku tulumu (Cozy Sleeping Bag), rested XP.
-- Kamp/meslek buff'ları (Camp Tent dahil) Camp.lua'da; burada yalnız özeti gösterilir.
-- Girişte ve aralıklarla eksikleri hatırlatır.
-- Komutlar: /hm xp (durum), /hm xp nasil (eksik buff nasıl alınır), /hm xp sessiz (hatırlatmayı kapat/aç)

local ADDON, ns = ...
local HM = ns.HM
local XpBuffs = {}
HM.XpBuffs = XpBuffs

local OK, BAD, WARN = "|cff80ff80+|r ", "|cffff6060x|r ", "|cffffd100!|r "
local function safe(v) if HM.IsSecret(v) then return nil end return v end

---------------------------------------------------------------------------
-- Buff adları (oyun içi İngilizce adlar)
---------------------------------------------------------------------------
-- Pişmiş yemek: Well Fed (öldürme XP'si +%5, 15 dk; ölünce gider)
local FOOD_BUFFS = {
    ["Well Fed"] = true,
    ["Food"] = true,        -- yerken görünen ara buff
    ["Refreshment"] = true,
}

-- Cozy Sleeping Bag: "Well-Rested" yığınları (yığın başına +%1, en çok 3)
local SLEEPING_BAG_BUFFS = {
    ["Well-Rested"] = true,
    ["Adventurer's Rest"] = true,
    ["Sleeping Bag"] = true,
    ["Camp Rest"] = true,
}

---------------------------------------------------------------------------
-- Buff kontrolü
---------------------------------------------------------------------------
local function hasAnyBuff(buffNames)
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
            if buffNames[name] then return true, name end
            -- kısmi eşleşme (ad biraz farklı olabilir)
            for key in pairs(buffNames) do
                if name:find(key, 1, true) then return true, name end
            end
        end
    end
    return false, nil
end

local function isRested()
    local cur = GetXPExhaustion and GetXPExhaustion()
    return cur and cur > 0
end

local function isInInn()
    return IsResting and IsResting()
end

---------------------------------------------------------------------------
-- Durum raporu: /hm xp
---------------------------------------------------------------------------
function XpBuffs:Status()
    local level = HM:Level()
    if level >= 60 then HM:Print("Zaten 60. seviyedesin, XP buff'larına gerek yok."); return end

    HM:Print("|cff33ccff— XP buff durumu —|r")

    -- 1) Yemek
    local hasFood, foodName = hasAnyBuff(FOOD_BUFFS)
    if hasFood then
        HM:Print(OK .. "Yemek buff'ı var (" .. (foodName or "Well Fed") .. "): öldürme XP'si +%5.")
    else
        HM:Print(BAD .. "Yemek buff'ı yok. Pişmiş yemek ye (oturarak en az 10 sn): öldürme XP'si +%5, 15 dk. Düşen etleri Cooking ile pişir.")
    end

    -- 2) Uyku tulumu
    local hasSleep, sleepName = hasAnyBuff(SLEEPING_BAG_BUFFS)
    if hasSleep then
        HM:Print(OK .. "Uyku tulumu buff'ı var (" .. (sleepName or "Well-Rested") .. "): +%3'e kadar XP, ölünce gitmez.")
    elseif level >= 14 then
        HM:Print(BAD .. "Uyku tulumu buff'ı yok. Cozy Sleeping Bag zinciri (14+): Barrens (Taurajo güneyi) → Stonetalon → Loch Modan barajı → Arathi (Thoradin Duvarı). Rehber rotada kendisi götürür.")
    else
        HM:Print(WARN .. "Uyku tulumu (Cozy Sleeping Bag): görev zinciri 14. seviyede açılır, +%3 XP verir.")
    end

    -- 3) Rested
    local restedXP = GetXPExhaustion and GetXPExhaustion() or 0
    if isRested() then
        HM:Print(OK .. string.format("Rested: %s XP birikmiş, öldürme XP'si 2 kat.", HM:Short(restedXP)))
    else
        HM:Print(BAD .. "Rested bitmiş. Oyundan handa ya da şehirde çık; Camp Tent (Leatherworking 20) saatte bir seviyenin %5'ine tamamlar.")
    end
    if isInInn() then
        HM:Print(OK .. "Şu an han/şehirdesin, dinleniyorsun.")
    end
    HM:Print(WARN .. "Legacy puanları (25+): Adventure → Well Rested dinlenme kapasitesini ve hızını artırır.")

    -- 4) Kamp / meslek buff'ları (ayrıntı /hm kamp)
    if HM.Camp then
        local okC, st = pcall(HM.Camp.Compute, HM.Camp)
        if okC and st then
            if st.buffOn then
                HM:Print(OK .. "Kamp buff'ı aktif" .. (st.buffLeft and string.format(" (%d dk)", math.floor(st.buffLeft / 60 + 0.5)) or "") .. ".")
            elseif st.pick then
                HM:Print(BAD .. string.format("Kamp buff'ı yok. %s hazır (%s): /hm kamp", st.pick.p.itemName, HM.Camp.Effect(st.pick.p.key, level)))
            else
                HM:Print(WARN .. "Kamp buff'ı yok (meslek kamp eşyaları): /hm kamp")
            end
        end
    end
    -- Kütüphane kitapları (10/20/25 milestone)
    if HM.Books then
        local okB, bst = pcall(HM.Books.Compute, HM.Books)
        if okB and bst then
            if bst.turnedIn >= 32 then
                HM:Print(OK .. "Kitap: 32/32 teslim edildi (Research Access kitli ya da kazanılmış).")
            elseif bst.milestone then
                local col = (bst.turnedIn >= bst.milestone.need - 2) and OK or WARN
                HM:Print(col .. string.format("Kitap: %d/32 (sonraki milestone %d — %d kaldı).", bst.turnedIn, bst.milestone.need, bst.milestone.need - bst.turnedIn))
            end
        end
    end

    local total = 0
    if hasFood then total = total + 5 end
    if hasSleep then total = total + 3 end
    HM:Print(string.format("|cff33ccff— Toplam sabit XP buff'ı: %%%d%s —|r", total,
        isRested() and " + rested (2 kat)" or ""))
end

---------------------------------------------------------------------------
-- Nasıl alınır (/hm xp ile birlikte eksik olanlar yazılır)
---------------------------------------------------------------------------
local FOOD_GUIDE = {
    short = "Yemek ye (+%5 XP)",
    steps = {
        "Cooking yoksa: herhangi bir Cooking eğitmeninden öğren.",
        "Düşen etleri kamp ateşinde ya da ocakta pişir; Cooking ile yapılan yemeklerin çoğu Well Fed verir.",
        "Oturarak en az 10 sn ye: 15 dk boyunca öldürme XP'si +%5. Ölünce gider, 15 dk'da bir tazele.",
    },
}

local SLEEP_GUIDE = {
    short = "Uyku tulumu al (+%3 XP)",
    steps = {
        "|cffffd100Cozy Sleeping Bag|r: beş nesneye tıklanan zincir (14+; rehber rotada kendisi götürür):",
        "|cff80ff801.|r The Barrens (46.4, 73.9), Taurajo güneyi → |cff88bbddBurned-Out Remains|r tıkla → Stepping Stones",
        "|cff80ff802.|r Stonetalon (40.8, 52.6), Sun Rock batısı → |cff88bbddPocket Litter|r tıkla (teslim) → Scramble",
        "|cff80ff803.|r Hemen kuzeybatısı (39.6, 49.9) → |cff88bbddMound of Dirt|r tıkla (teslim) → Wet Job",
        "|cff80ff804.|r Loch Modan (49.4, 12.9), Stonewrought Dam → |cff88bbddCarved Figurine|r tıkla (teslim) → Eagle's Fist",
        "   Yol: Tarren Mill → Arathi → Thandol Span → Wetlands → Dun Algaz geçidi. |cffff8080Alliance bölgesi: ölürsen ruhla koş, tıklamak yeter.|r",
        "|cff80ff805.|r Arathi (22.5, 24.2), Thoradin Duvarı → |cff88bbddMessenger Bag|r tıkla (teslim) → This Must Be The Place",
        "   → yanındaki |cff88bbddHastily Rolled-Up Satchel|r tıkla → |cff00ff00Cozy Sleeping Bag!|r",
        "Rotada: 1-3 Taurajo güneyi ve Sun Rock bölümlerinde, 4-5 Hillsbrad'den sonra (28 civarı).",
        "Tulumda yatınca dakikada +%1, en çok +%3 XP; ölünce gitmez, yemekle üst üste biner. Partidekiler de senin tulumunu kullanabilir.",
    },
}

local REST_GUIDE = {
    short = "Handa çıkış yap (rested)",
    steps = {
        "Oyundan han ya da şehirde çık: 8 saatte seviyenin %5'i kadar rested birikir (en çok %150).",
        "Rested = mavi XP çubuğu = öldürme XP'si 2 kat (görev tesliminde geçmez).",
        "Camp Tent (Leatherworking 20) saatte bir rested'ı seviyenin %5'ine tamamlar: /hm kamp",
    },
}

function XpBuffs:GetMissingTasks()
    local tasks = {}
    local level = HM:Level()
    if level >= 60 then return tasks end

    if not hasAnyBuff(FOOD_BUFFS) then
        tasks[#tasks + 1] = { guide = FOOD_GUIDE, color = "|cffff9040", priority = 1 }
    end
    if not hasAnyBuff(SLEEPING_BAG_BUFFS) and level >= 14 then
        tasks[#tasks + 1] = { guide = SLEEP_GUIDE, color = "|cffff6060", priority = 2 }
    end
    if not isRested() then
        tasks[#tasks + 1] = { guide = REST_GUIDE, color = "|cffffd100", priority = 4 }
    end
    return tasks
end

-- Pencerede gösterilecek tek satır özet
function XpBuffs:StatusLine()
    local level = HM:Level()
    local parts = {}
    local total = 0

    if level < 60 then
        local hasFood = hasAnyBuff(FOOD_BUFFS)
        if hasFood then total = total + 5; parts[#parts + 1] = "|cff80ff80Yemek|r"
        else parts[#parts + 1] = "|cffff6060Yemek|r" end

        local hasSleep = hasAnyBuff(SLEEPING_BAG_BUFFS)
        if hasSleep then total = total + 3; parts[#parts + 1] = "|cff80ff80Tulum|r"
        elseif level >= 14 then parts[#parts + 1] = "|cffff6060Tulum|r"
        else parts[#parts + 1] = "|cff606060Tulum|r" end

        if isRested() then parts[#parts + 1] = "|cff80ff80Rest|r"
        else parts[#parts + 1] = "|cffff6060Rest|r" end
    end

    if HM.Camp and HM.Camp.Token then
        local okT, tok = pcall(HM.Camp.Token, HM.Camp)
        if okT and tok then parts[#parts + 1] = tok end
    end
    if HM.Books and HM.Books.Token then
        local okB, tok = pcall(HM.Books.Token, HM.Books)
        if okB and tok then parts[#parts + 1] = tok end
    end

    if #parts == 0 then return nil end
    if level >= 60 then return table.concat(parts, " ") end
    return string.format("XP +%%%d %s", total, table.concat(parts, " "))
end

function XpBuffs:PrintGuide(guide)
    HM:Print("|cff33ccff" .. guide.short .. "|r")
    for _, step in ipairs(guide.steps) do
        HM:Print("  • " .. step)
    end
end

---------------------------------------------------------------------------
-- Giriş ve periyodik hatırlatma
---------------------------------------------------------------------------
local lastReminder = 0
local REMINDER_INTERVAL = 900  -- en sık 15 dakikada bir (saniye)

local function remind()
    if HM:InCombat() then return end
    local level = HM:Level()
    if level >= 60 then return end
    local db = HM.db
    if (db and db.xpBuffSilent) or HM.inInstance then return end

    local now = GetTime()
    if now - lastReminder < REMINDER_INTERVAL then return end
    lastReminder = now

    local tasks = XpBuffs:GetMissingTasks()
    if #tasks > 0 then
        local names = {}
        for _, t in ipairs(tasks) do names[#names + 1] = t.guide.short end
        HM:Print("|cff9933ff[XP]|r Eksik: " .. table.concat(names, ", ") .. " — durum /hm xp, nasıl alınır /hm xp nasil")
    end
end

HM:OnLogin(function()
    C_Timer.After(15, function() pcall(remind) end)
    C_Timer.After(300, function()
        local function loop()
            pcall(remind)
            C_Timer.After(300, loop)
        end
        loop()
    end)
end)

HM:On("PLAYER_REGEN_ENABLED", function()
    C_Timer.After(3, function() pcall(remind) end)
end)

---------------------------------------------------------------------------
-- Komut: /hm xp [sessiz]
---------------------------------------------------------------------------
function XpBuffs:Command(arg)
    arg = (arg or ""):lower()
    if arg == "sessiz" or arg == "sus" or arg == "kapat" then
        HM.db.xpBuffSilent = not (HM.db.xpBuffSilent or false)
        HM:Print("XP buff hatırlatması: " .. (HM.db.xpBuffSilent and "kapalı" or "açık"))
    elseif arg == "nasil" or arg == "nasıl" then
        local tasks = self:GetMissingTasks()
        if #tasks == 0 then HM:Print("Eksik XP buff'ı yok.") end
        for _, t in ipairs(tasks) do self:PrintGuide(t.guide) end
    else
        self:Status()
    end
end
end

---------------------------------------------------------------------------
-- 4/4 Kütüphane kitapları: 32 kitap takibi ve Study (/hm kitap)
---------------------------------------------------------------------------
do
-- Kütüphane kitapları (Horde teslim: Owen Thadd, Undercity Magic Quarter).
-- 32 kitap, 3 milestone (10/20/25) ve 1 kapanış görevi (32 — Research Access, Comprehension tam açılır).
-- Study mage'e özel; buna Comprehension da Comprehend Scroll ile birlikte 6. seviyede mage eğitmeninden.

local ADDON, ns = ...
local HM = ns.HM
local Books = {}
HM.Books = Books

local OK, BAD, WARN, DIM = "|cff80ff80+|r ", "|cffff6060x|r ", "|cffffd100!|r ", "|cff909090-|r "
local function lq(s) if HM.IsSecret(s) then return nil end return s end

---------------------------------------------------------------------------
-- Veri: 32 kitap, milestone görevleri, Light Feather, teslim NPC'si
---------------------------------------------------------------------------
Books.data = {
    librarian = { m = 1458, x = 73.4, y = 33.0, n = "Owen Thadd" },   -- Undercity Magic Quarter iç halkası
    feather   = 17056,                                                 -- Light Feather (Study için)
    study     = { mage = 1302508, lvl = 6 },                           -- Study mage-only
    milestones = {
        { q = 78150, need = 10, reward = "Scholarly Pendant (+3 Sta +2 Spi, 25'te giyilir) ya da Erudite's Amulet" },
        { q = 79536, need = 20, reward = "Philanthropist's Ring (+5 Int +10 Spell Power, 40'ta giyilir) ya da Field Researcher's Loop" },
        { q = 82208, need = 25, reward = "30. seviye görev zinciri: silah, muska ya da off-hand" },
        { q = 97286, need = 32, reward = "Research Access — Comprehension tam açılır, mage scroll'larını kendin yaparsın" },
    },
    -- Yan not: "Research Access" mage olsan da olmasan da verilir; Study yalnız mage'de çalışır.
    books = {
        -- 1-20 kademe (16 kitap: 8 Horde/tarafsız, 8 Alliance)
        { q=79094, m=1454, x=38.7, y=78.4, zone="Orgrimmar",             title="The Lessons of Ta'zo",                side="H", tier=20 },
        { q=79095, m=1420, x=59.4, y=52.3, zone="Tirisfal (Brill)",      title="Apothecary's Metaphysical Primer",    side="H", tier=20 },
        { q=78127, m=1421, x=63.5, y=63.2, zone="Silverpine (Amber Mill)", title="The Dalaran Digest",                side="H", tier=20 },
        { q=79096, m=1421, x=43.4, y=41.2, zone="Silverpine (Sepulcher)", title="Ataeric: On Arcane Curiosities",     side="H", tier=20 },
        { q=78143, m=1413, x=49.3, y=32.9, zone="Barrens (WC dışı)",     title="Secrets of the Dreamers",             side="H", tier=20 },
        { q=78145, m=1413, x=56.3, y=8.8,  zone="Barrens (Sludge Fen)",  title="Arcanic Systems Manual",              side="H", tier=20 },
        { q=79097, m=1413, x=62.7, y=36.3, zone="Barrens (Ratchet)",     title="Baxtan: On Destructive Magics",       side="N", tier=20 },
        { q=78149, m=1442, x=74.4, y=85.7, zone="Stonetalon (güney)",    title="Fury of the Land",                    side="N", tier=20 },
        { q=78124, m=0,    x=59.6, y=22.2, zone="Darkshore",             title="Nar'thalas Almanac",                  side="A", tier=20 },
        { q=78142, m=0,    x=45.4, y=70.4, zone="Westfall (Moonbrook)",  title="Bewitchments and Glamours",           side="A", tier=20 },
        { q=78146, m=0,    x=33.6, y=47.9, zone="Wetlands",              title="Goaz Scrolls",                        side="A", tier=20 },
        { q=78147, m=0,    x=16.7, y=28.4, zone="Duskwood",              title="Crimes Against Anatomy",              side="A", tier=20 },
        { q=78148, m=1432, x=77.4, y=14.0, zone="Loch Modan (Mo'grosh)", title="Runes of the Sorcerer-Kings",         side="A", tier=20 },
        { q=79091, m=0,    x=76.0, y=10.4, zone="Ironforge",             title="Antonidas Autobiography",             side="A", tier=20 },
        { q=79092, m=0,    x=65.4, y=70.1, zone="Elwynn Forest",         title="Theocritus' Research Journal",        side="A", tier=20 },
        { q=79093, m=1432, x=52.7, y=53.8, zone="Loch Modan (Thelsamar)",title="Rumi of Gnomeregan",                  side="A", tier=20, note="Westfall'daki ikinci kopya da sayılır" },
        -- 30-35 kademe (8 kitap, çoğu tarafsız/contested)
        { q=79535, m=1434, x=41.4, y=50.9, zone="Stranglethorn Vale",    title="Basilisks",                           side="N", tier=35 },
        { q=79947, m=1441, x=34.4, y=40.1, zone="Thousand Needles",      title="Geomancy",                            side="N", tier=35 },
        { q=79948, m=1416, x=48.4, y=57.6, zone="Alterac Mountains",     title="Defensive Magics 101",                side="N", tier=35 },
        { q=79949, m=1417, x=73.6, y=65.2, zone="Arathi Highlands",      title="A Web of Lies",                       side="N", tier=35 },
        { q=79950, m=1443, x=55.0, y=26.2, zone="Desolace",              title="Demons and You",                      side="N", tier=35 },
        { q=79951, m=1418, x=56.7, y=39.9, zone="Badlands",              title="Mummies: Unsavory Undead",            side="N", tier=35 },
        { q=79952, m=1445, x=57.2, y=20.8, zone="Dustwallow Marsh",      title="RwlRwlRwlRwl!",                       side="N", tier=35 },
        { q=79953, m=1435, x=61.5, y=22.5, zone="Swamp of Sorrows",      title="A Luddite's Guide (Demonic Pet)",     side="N", tier=35, note="Kafes kilidi: Muckdweller Murloc'dan Rusted Cage Key düşer" },
        -- 40-45 kademe (8 kitap)
        { q=81947, m=1435, x=70.0, y=51.0, zone="Swamp of Sorrows",      title="Sanguine Sorcery",                    side="N", tier=45 },
        { q=81949, m=1446, x=72.6, y=47.8, zone="Tanaris (Lost Rigger)", title="Legends of the Tidesages",            side="N", tier=45 },
        { q=81951, m=1444, x=50.6, y=15.7, zone="Feralas",               title="The Liminal and the Arcane",          side="N", tier=45, note="phase'lenmiş olabilir" },
        { q=81952, m=1447, x=20.7, y=62.0, zone="Azshara",               title="Everyday Etiquette",                  side="N", tier=45 },
        { q=81953, m=1428, x=29.0, y=28.9, zone="Burning Steppes",       title="Stonewrought Design",                 side="N", tier=45 },
        { q=81954, m=1425, x=36.0, y=72.8, zone="The Hinterlands",       title="Venomous Journeys",                   side="N", tier=45 },
        { q=81955, m=1427, x=37.8, y=49.3, zone="Searing Gorge",         title="A Mind of Metal",                     side="N", tier=45 },
        { q=81956, m=1419, x=55.4, y=32.3, zone="Blasted Lands",         title="Conjurer's Codex",                    side="N", tier=45 },
    },
}

---------------------------------------------------------------------------
-- Durum
---------------------------------------------------------------------------
local function flagged(qid)
    return HM.Guide and HM.Guide.QuestDone and HM.Guide.QuestDone(qid) or false
end
local function level() return HM:Level() or 1 end
local function featherCount()
    if HM.Guide and HM.Guide.ItemCount then return HM.Guide.ItemCount(Books.data.feather) end
    return 0
end
local function studyKnown()
    if HM.Guide and HM.Guide.SpellKnown then return HM.Guide.SpellKnown(Books.data.study.mage) end
    return nil
end

function Books:Compute()
    local st = { turnedIn = 0, remaining = {}, done = {} }
    for _, b in ipairs(self.data.books) do
        if flagged(b.q) then st.turnedIn = st.turnedIn + 1; st.done[b.q] = true
        else st.remaining[#st.remaining + 1] = b end
    end
    st.milestone = nil
    for _, m in ipairs(self.data.milestones) do
        if st.turnedIn < m.need then st.milestone = m; break end
    end
    local _, cls = UnitClass("player")
    st.class = cls
    st.feathers = featherCount()
    st.studyKnown = studyKnown()
    -- Yakındaki kitap: aynı harita, karakter 200 yd içinde, bitmemiş
    local px, py, pc = HM:PlayerWorldPos()
    st.nearest = nil
    st.onMapBooks = {}
    if HM:PlayerMapChain() then
        local chain = HM:PlayerMapChain()
        for _, b in ipairs(st.remaining) do
            if b.m ~= 0 and chain[b.m] then
                st.onMapBooks[#st.onMapBooks + 1] = b
                if px then
                    local wx, wy, wc = HM:MapWorldPos(b.m, b.x, b.y)
                    if wx and wc == pc then
                        local d = math.sqrt((wx - px) ^ 2 + (wy - py) ^ 2)
                        if not st.nearest or d < st.nearest.d then st.nearest = { b = b, d = d } end
                    end
                end
            end
        end
    end
    -- Undercity Magic Quarter'da mı?
    st.atOwen = false
    if px and self.data.librarian.m then
        local chain = HM:PlayerMapChain()
        if chain and chain[self.data.librarian.m] then
            local wx, wy, wc = HM:MapWorldPos(self.data.librarian.m, self.data.librarian.x, self.data.librarian.y)
            if wx and wc == pc then
                if math.sqrt((wx - px) ^ 2 + (wy - py) ^ 2) <= 200 then st.atOwen = true end
            end
        end
    end
    self.state = st
    return st
end

---------------------------------------------------------------------------
-- Pencere satırı ve işaret
---------------------------------------------------------------------------
function Books:ActionLine()
    local st = self.state or self:Compute()
    if level() >= 60 then return nil end
    if st.nearest and st.nearest.d <= 250 then
        return string.format("|cffffd100Kitap:|r yakında |cff88bbdd%s|r (%s %.0f, %.0f). Al, Undercity'de Owen Thadd'a teslim et.",
            st.nearest.b.title, st.nearest.b.zone, st.nearest.b.x, st.nearest.b.y)
    end
    return nil
end

function Books:CityErrand(chain)
    -- Undercity'ye uğradıysan ve çantada/günlükte kitap varsa Owen Thadd'a çevir.
    local st = self.state or self:Compute()
    if not st.atOwen then return nil end
    local pct = st.milestone and st.milestone.need or 32
    local left = (st.milestone and st.milestone.need - st.turnedIn) or 0
    if left <= 0 then return nil end
    return string.format("|cffffd100Kitap:|r Owen Thadd'a biriken kitapları teslim et (şu ana kadar %d/%d). Çantandaki Library Book'ları ver, Study'yi burada cast edebilirsin.", st.turnedIn, pct)
end

function Books:Token()
    local st = self.state or self:Compute()
    if level() >= 60 or st.turnedIn >= 32 then return nil end
    local color = "|cff909090"
    if st.nearest and st.nearest.d <= 250 then color = "|cffffd100"
    elseif st.turnedIn >= 20 then color = "|cff80ff80" end
    return string.format("%sKitap %d/32|r", color, st.turnedIn)
end

---------------------------------------------------------------------------
-- /hm kitap
---------------------------------------------------------------------------
local function side(b)
    if b.side == "H" then return "|cff80ff80Horde|r"
    elseif b.side == "A" then return "|cffff6060Alliance|r"
    else return "|cffffffffortak|r" end
end

function Books:Status()
    local st = self:Compute()
    HM:Print(string.format("|cff33ccff— Kütüphane kitapları (%d/32 teslim edildi) —|r", st.turnedIn))
    for _, m in ipairs(self.data.milestones) do
        if st.turnedIn >= m.need then
            HM:Print(OK .. string.format("%d kitap: %s", m.need, m.reward))
        else
            HM:Print(WARN .. string.format("%d kitap için %d daha lazım: %s", m.need, m.need - st.turnedIn, m.reward))
            break
        end
    end
    if st.nearest then
        HM:Print("|cff33ccffYakındaki kitap:|r " .. st.nearest.b.title ..
            string.format(" — %s (%.0f, %.0f), yaklaşık %d yd", st.nearest.b.zone, st.nearest.b.x, st.nearest.b.y, math.floor(st.nearest.d + 0.5)))
    elseif #st.onMapBooks > 0 then
        HM:Print(string.format("|cff33ccffBu haritada %d kitap var|r (bitmemiş).", #st.onMapBooks))
    end
    HM:Print("|cff33ccffKalan Horde-güvenli (seviyene uygun):|r")
    local shown = 0
    for _, b in ipairs(st.remaining) do
        if b.side ~= "A" and (not b.tier or level() + 3 >= b.tier - 15) and shown < 10 then
            shown = shown + 1
            HM:Print(string.format("  %s%s|r  %s %.0f, %.0f  %s  [%d+]", b.note and "|cffffd100" or "|cffffffff", b.title, b.zone, b.x, b.y, side(b), b.tier - 15))
            if b.note then HM:Print("     |cff909090" .. b.note .. "|r") end
        end
    end
    if st.class == "MAGE" then
        local feath, lvl = st.feathers, level()
        if st.studyKnown == true then
            HM:Print(OK .. string.format("Study öğrenilmiş. Owen Thadd'a bir kitap verdiysen Undercity Magic Quarter'da kullanabilirsin. Light Feather: %d (her Study bir tüy yakar). 1 saat bekleme.", feath))
        elseif lvl >= 6 then
            HM:Print(WARN .. "Study / Comprehend Scroll henüz yok: Orgrimmar'da mage eğitmeni Un'Thuul (38.7, 85.4) öğretir, ücretsiz.")
        else
            HM:Print(DIM .. "Study 6. seviyede açılır (mage'e özel).")
        end
    elseif st.class == "WARRIOR" or st.class == "DRUID" then
        HM:Print(DIM .. "Study mage'e özel. Milestone ödülleri her sınıfa uygun: 10'da +3 Sta kolye, 20'de yüzük, 25'te 30. seviye görev zinciri.")
    end
    HM:Print("|cff909090Kitap genellikle bir rafta, scroll ya da tomar olarak duruyor. Uzaktan ayırt etmesi zor; rotada geldiğinde ok bu modülden gelir.|r")
    HM:Print("Komutlar: |cffffd100/hm kitap git|r ok en yakın kitaba; |cffffd100/hm kitap sessiz|r hatırlatmayı kapat; |cffffd100/hm kitap tum|r bütün listeyi dök.")
end

function Books:All()
    HM:Print("|cff33ccff— Bütün kitaplar —|r")
    for _, b in ipairs(self.data.books) do
        local mark = flagged(b.q) and OK or "   "
        HM:Print(string.format("  %s%s  %s (%.0f, %.0f)  %s  [%d+]", mark, b.title, b.zone, b.x, b.y, side(b), b.tier - 15))
    end
end

function Books:Go()
    local st = self:Compute()
    if st.atOwen then
        HM:Print("Zaten Owen Thadd'ın yanındasın.")
        return
    end
    if not st.nearest then
        if st.turnedIn > 0 and (not st.milestone or st.turnedIn < st.milestone.need) and HM.Arrow then
            local l = self.data.librarian
            HM.Arrow:SetTarget(l.m, l.x, l.y, "Owen Thadd — kitap teslimi", "book")
            HM:Print("Ok Owen Thadd'da (Undercity Magic Quarter): " .. string.format("%s %.0f, %.0f", HM:MapName(l.m), l.x, l.y))
            return
        end
        HM:Print("Bu haritada bitmemiş kitap yok.")
        return
    end
    local b = st.nearest.b
    if HM.Arrow then
        HM.Arrow:SetTarget(b.m, b.x, b.y, "Kitap: " .. b.title, "book")
        HM:Print(string.format("Ok kitapta: %s — %s %.0f, %.0f (%d yd)", b.title, b.zone, b.x, b.y, math.floor(st.nearest.d + 0.5)))
    end
end

function Books:Command(arg)
    arg = (arg or ""):lower()
    local a, b = arg:match("^(%S*)%s*(.-)$")
    local db = HM.db
    db.books = db.books or { silent = false }
    if a == "sessiz" or a == "sus" then
        db.books.silent = not db.books.silent
        HM:Print("Kitap hatırlatması: " .. (db.books.silent and "kapalı" or "açık"))
    elseif a == "git" then self:Go()
    elseif a == "tum" or a == "tüm" then self:All()
    else self:Status() end
end

---------------------------------------------------------------------------
-- Döngü ve hatırlatma (kampla aynı düzen: aynı kitap için en çok iki kez)
---------------------------------------------------------------------------
function Books:Remind()
    local st = self.state
    local db = HM.db
    if not st or (db.books and db.books.silent) or HM.inInstance or HM:InCombat() then return end
    -- Yakında kitap: aynı kitap için bir kez
    if st.nearest and st.nearest.d <= 250 then
        local key = "near:" .. st.nearest.b.q
        if self.lastKey ~= key then
            self.lastKey = key
            local b = st.nearest.b
            HM:Print(string.format("|cffffd100Kitap:|r yakında |cff88bbdd%s|r (%s %.0f, %.0f). Rafı tıkla — Undercity'de Owen Thadd'a teslim edilir.",
                b.title, b.zone, b.x, b.y))
        end
        return
    end
    if self.lastKey and self.lastKey:sub(1, 5) == "near:" then
        self.lastKey = nil   -- uzaklaşınca sıfırla
    end
end

function Books:Tick()
    if not HM.db or HM:InCombat() then return end
    self:Compute()
    self:Remind()
end

local function loop()
    local ok, err = pcall(Books.Tick, Books)
    if not ok then Books.lastError = tostring(err) end
    C_Timer.After(5, loop)
end

HM:OnLogin(function()
    HM.db.books = HM.db.books or { silent = false }
    C_Timer.After(9, loop)
end)
end
