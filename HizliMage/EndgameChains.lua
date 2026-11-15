-- Endgame görev zincirleri: attunement, reputation, önemli eşya/anahtar zincirleri.
-- Leveling rotasında bu zincirlerin parçası olan görevler özel işaretle gösterilir.
-- /hm zincir → seviyeye uygun endgame zincirleri, /hm zincir tum → hepsi.

local ADDON, ns = ...
local HM = ns.HM
local Chains = {}
HM.Chains = Chains

local OK, BAD, WARN = "|cff80ff80+|r ", "|cffff6060x|r ", "|cffffd100!|r "
local CHAIN = "|cffff8000*|r "  -- zincir ikonu

---------------------------------------------------------------------------
-- Endgame Görev Zincirleri Veritabanı (Horde, Classic/Forever)
-- startLvl: zincire başlanabilecek minimum seviye
-- idealLvl: en verimli başlama seviyesi
-- questIds: bu zincirin parçası olan görev IDleri (rotadaki adımlarla eşleşir)
-- reward: ne kazandırır
-- rep: hangi itibar (reputation) verir
-- category: "attunement", "key", "reputation", "class", "gear", "prebis"
---------------------------------------------------------------------------
local ENDGAME_CHAINS = {
    ---------------------------------------------------------------------------
    -- RAID ATTUNEMENT'LAR
    ---------------------------------------------------------------------------
    {
        name = "Onyxia Attunement",
        category = "attunement",
        startLvl = 55, idealLvl = 58,
        startNpc = "Warlord's Command (Kargath, Badlands)",
        reward = "Onyxia's Lair raidi acilir",
        steps = {
            "1. Warlord's Command: Kargath'tan al (sev. 55+)",
            "2. Eitrigg's Wisdom → For The Horde! → UBRS'de Warchief Rend Blackhand'i oldur",
            "3. What the Wind Carries → The Champion of the Horde → Thrall (Orgrimmar)",
            "4. Mistress of Deception → Rexxar (Desolace/Stonetalon sınırı)",
            "5. Embassy of the Horde → Drakkisath's Brand → UBRS boss odasindaki mumu yak",
            "6. Blood of the Black Dragon Champion → UBRS Drakkisath'tan kan al",
        },
        questIds = { 4903, 4941, 4974, 6566, 6567, 6568, 6569, 6570, 6584, 6585 },
    },
    {
        name = "Molten Core Attunement",
        category = "attunement",
        startLvl = 55, idealLvl = 58,
        startNpc = "Lothos Riftwalker (BRD girisi, Blackrock Mountain)",
        reward = "MC'ye portaldan girilebilir (BRD icinden yurumek gerekmez)",
        steps = {
            "1. Lothos Riftwalker ile konus (BRD girisindeki portal yaninda)",
            "2. Attunement to the Core: BRD'nin dibindeki lavda MC girisine dokundur",
            "3. Lothos'a teslim et → artik Blackrock Mountain'deki portaldan MC'ye gir",
        },
        questIds = { 7848, 7487 },
    },
    {
        name = "BWL Attunement",
        category = "attunement",
        startLvl = 55, idealLvl = 60,
        startNpc = "Scarshield Quartermaster (LBRS girisi, Blackrock Spire)",
        reward = "BWL raidi acilir — UBRS Drakkisath odasindaki orba dokun",
        steps = {
            "1. Scarshield Quartermaster'i oldur (LBRS giris koridoru) → Blackhand's Command mektubu duser",
            "2. Mektubu oku → Blackhand's Command gorevi baslar",
            "3. UBRS'de General Drakkisath'i oldur, odasindaki orba dokun",
        },
        questIds = { 7761 },
    },
    {
        name = "Naxxramas Attunement",
        category = "attunement",
        startLvl = 60, idealLvl = 60,
        startNpc = "Archmage Angela Dosantos (Light's Hope Chapel, EPL)",
        reward = "Naxxramas raidi acilir",
        rep = "Argent Dawn",
        steps = {
            "Honored: 60g + Arcane Crystal + 2x Nexus Crystal",
            "Revered: 30g + Arcane Crystal + 1x Nexus Crystal",
            "Exalted: ucretsiz",
            "NOT: Argent Dawn reputation ne kadar yuksekse o kadar ucuz!",
        },
        questIds = {},
    },

    ---------------------------------------------------------------------------
    -- ZINDAN ANAHTARLARI
    ---------------------------------------------------------------------------
    {
        name = "Shadowforge Key (BRD)",
        category = "key",
        startLvl = 48, idealLvl = 52,
        startNpc = "Franclorn Forgewright (Blackrock Mountain, hayalet - olmen gerekir)",
        reward = "BRD arka kapilari acilir — daha hizli farm rutalari",
        steps = {
            "1. Blackrock Mountain'da ol, yanindaki lavda hayaletini bul (olmek gerekir!)",
            "2. Dark Iron Legacy gorevi: BRD'de Fineous Darkvire'i oldur → Ironfel al",
            "3. Lyceum'dan gec, Shrine of Thaurissan'daki kaliba dokun → Shadowforge Key",
        },
        questIds = { 3801, 3802 },
    },
    {
        name = "Seal of Ascension (LBRS/UBRS Key)",
        category = "key",
        startLvl = 55, idealLvl = 58,
        startNpc = "Vaelan (LBRS icinde, giris yakininda)",
        reward = "UBRS giris kapisi — 60'ta temel raid hazirligi",
        steps = {
            "1. Vaelan ile konus (LBRS icinde) → Seal of Ascension",
            "2. LBRS'de 3 parcayi topla: Gemstone (ilk boss), Unadorned Seal",
            "3. Dustwallow Marsh: Emberstrife'in magarasinda muhrü tamamla",
        },
        questIds = { 4742, 4743 },
    },
    {
        name = "Scepter of Celebras (Maraudon Key)",
        category = "key",
        startLvl = 41, idealLvl = 44,
        startNpc = "Cavindra (Maraudon dis giris magarasi)",
        reward = "Maraudon portalini acar — Princess boss'una hizli erisim",
        steps = {
            "1. Cavindra (Mara giris magarasi): Legends of Maraudon",
            "2. Noxxion + Lord Vyletongue drop parcalari",
            "3. Celebras the Cursed'i kurtardiktan sonra asayi birlestir",
        },
        questIds = { 7044, 7046, 7064 },
    },
    {
        name = "Mallet of Zul'Farrak",
        category = "key",
        startLvl = 40, idealLvl = 45,
        startNpc = "Qiaga the Keeper (Hinterlands, Revantusk Village)",
        reward = "ZF'de Gahz'rilla boss'unu cagirir — ek loot + gorev",
        steps = {
            "1. Sacred Mallet: Jintha'Alor (Hinterlands) tepesindeki Vile Priestess'ten duser",
            "2. Tepenin en ustundeki altarda kullan → Mallet of Zul'Farrak olur",
        },
        questIds = { 3843 },
    },

    ---------------------------------------------------------------------------
    -- REPUTATION (itibar) ZINCIRLERI
    ---------------------------------------------------------------------------
    {
        name = "Argent Dawn (Plaguelands)",
        category = "reputation",
        startLvl = 50, idealLvl = 53,
        startNpc = "Plaguelands görevleri + Scholo/Strat ruslari",
        reward = "Naxx attunement ucuz olur, Argent Dawn enchant (exalted), Cromie'den taşıma",
        rep = "Argent Dawn",
        steps = {
            "WPL + EPL görevleri: Bulwark → Chillwind Camp → Light's Hope Chapel",
            "Cauldron zinciri (WPL): 4 cauldron gorevi → her biri rep verir",
            "Scholomance + Stratholme boss oldurmek → reputation tokeni duser",
            "Scourge Stone turn-in: farm edilmis taslari Argent Dawn NPC'sine ver",
        },
        questIds = { 5097, 5098, 5212, 5214, 5228, 5243, 5251, 5263 },
    },
    {
        name = "Timbermaw Hold",
        category = "reputation",
        startLvl = 48, idealLvl = 52,
        startNpc = "Nafien / Grazle (Felwood / Winterspring giris tuneli)",
        reward = "Felwood-Winterspring gecis tuneli, enchant tarifleri, alchemy tarifi",
        rep = "Timbermaw Hold",
        steps = {
            "Felwood'daki Deadwood furbolglarini oldur (rep farm)",
            "Winterspring'deki Winterfall furbolglarini oldur (rep farm)",
            "Feather turn-in: Deadwood Headdress Feather x5 → rep",
            "Winterfall Spirit Beads turn-in (Winterspring)",
        },
        questIds = { 8462, 8464 },
    },
    {
        name = "Thorium Brotherhood",
        category = "reputation",
        startLvl = 47, idealLvl = 50,
        startNpc = "Master Smith Burninate (Searing Gorge, Thorium Point)",
        reward = "BS/LW/Enchanting yuksek seviye tarifleri — Fire Resistance gear crafting",
        rep = "Thorium Brotherhood",
        steps = {
            "Searing Gorge görevleri: Thorium Point NPC'leri",
            "Dark Iron Residue turn-in (BRD farm → Neutral→Friendly)",
            "Incendosaur Scale, Dark Iron Ore, Fiery Core → Friendly→Honored",
            "Lava Core, Fiery Core, Blood of the Mountain → Honored→Revered",
        },
        questIds = { 3906, 4081, 4083, 4084 },
    },
    {
        name = "Cenarion Circle",
        category = "reputation",
        startLvl = 55, idealLvl = 58,
        startNpc = "Cenarion Hold NPC'leri (Silithus)",
        reward = "AQ acilis zinciri, Nature Resistance gear, Silithus enchantlar",
        rep = "Cenarion Circle",
        steps = {
            "Silithus görevleri: Cenarion Hold questline",
            "Twilight Text turn-in → Encrypted Twilight Texts (farm)",
            "Field Duty tekrar edilebilir görevler",
            "AQ20/AQ40 boss oldurmek → rep",
        },
        questIds = {},
    },

    ---------------------------------------------------------------------------
    -- SINIF GÖREVLERI (MAGE)
    ---------------------------------------------------------------------------
    {
        name = "Mage Sunken Temple Quest (Level 50)",
        category = "class",
        startLvl = 50, idealLvl = 52,
        startNpc = "Archmage Xylem (Azshara)",
        reward = "Arcane Staff of Xylem / Celestial Orb / Glacial Spike gibi class gear",
        steps = {
            "1. Azshara'daki Archmage Xylem'den al",
            "2. Sunken Temple'da mini boss'lari oldur",
            "3. Item'i geri getir → sinif odullerinden birini sec",
        },
        questIds = { 8258 },
    },

    ---------------------------------------------------------------------------
    -- PREBIS / ONEMLI ESYA ZINCIRLERI
    ---------------------------------------------------------------------------
    {
        name = "Onyxia Scale Cloak (FR Cloak)",
        category = "gear",
        startLvl = 60, idealLvl = 60,
        startNpc = "Mux Manascrambler / Chromatic Mantle quest",
        reward = "Onyxia Scale Cloak — BWL Nefarian icin gerekli fire resist cloak",
        steps = {
            "Onyxia'yi oldur → Scale duser",
            "LW 300 olan birine yaptir (tarif Onyxia drop)",
        },
        questIds = {},
    },
    {
        name = "Tirion Fordring Zinciri (In Dreams)",
        category = "reputation",
        startLvl = 52, idealLvl = 56,
        startNpc = "Tirion Fordring (Eastern Plaguelands, 7, 43 civari)",
        reward = "Mark of Fordring (neck) + cok iyi XP + Argent Dawn rep",
        rep = "Argent Dawn",
        steps = {
            "1. Of Forgotten Memories → Tirion'un kulubesi (EPL kuzeybatisi)",
            "2. Of Lost Honor → Of Love and Family → uzun gorev zinciri",
            "3. In Dreams → final gorev, harika hikaye + odul",
        },
        questIds = { 5742, 5781, 5845, 5846, 5848, 5862 },
    },
    {
        name = "Fallen Hero Zinciri (Blasted Lands → BRD)",
        category = "gear",
        startLvl = 50, idealLvl = 55,
        startNpc = "Fallen Hero of the Horde (Blasted Lands / Swamp of Sorrows siniri)",
        reward = "Mark of Resolution (neck) veya Mark of Tyranny (trinket) — Pre-BiS",
        steps = {
            "1. Fallen Hero of the Horde (Swamp of Sorrows siniri) ile konus",
            "2. Heroic zinciri → Blasted Lands demon oldurme gorevleri",
            "3. BRD'de The Challenge gorevi → odul sec",
        },
        questIds = { 2784, 2801, 2702 },
    },
}

---------------------------------------------------------------------------
-- Lookup: questId → chain bilgisi (rotadaki adımlarla eşleştirmek için)
---------------------------------------------------------------------------
local questToChain = {}
for _, chain in ipairs(ENDGAME_CHAINS) do
    if chain.questIds then
        for _, qid in ipairs(chain.questIds) do
            questToChain[qid] = chain
        end
    end
end

-- Dışarıya aç: Guide.lua ve Route sistemi kullanabilsin
function Chains:GetChainForQuest(questId)
    return questToChain[questId]
end

function Chains:IsEndgameQuest(questId)
    return questToChain[questId] ~= nil
end

function Chains:GetChainTag(questId)
    local c = questToChain[questId]
    if not c then return nil end
    local tags = {
        attunement = "|cffff0000[ATTUNEMENT]|r",
        key        = "|cffff8800[ANAHTAR]|r",
        reputation = "|cff00ccff[REPUTATION]|r",
        class      = "|cffcc66ff[SINIF]|r",
        gear       = "|cff00ff88[ESYA]|r",
        prebis     = "|cffffff00[PRE-BIS]|r",
    }
    return (tags[c.category] or "|cffff8000[ZINCIR]|r") .. " " .. c.name
end

---------------------------------------------------------------------------
-- Chat raporu: /hm zincir [tum]
---------------------------------------------------------------------------
function Chains:List(showAll)
    local level = HM:Level()
    HM:Print("|cff33ccff— Endgame gorev zincirleri —|r")

    local shown = 0
    for _, c in ipairs(ENDGAME_CHAINS) do
        if showAll or level >= (c.startLvl - 5) then
            local color = level >= c.startLvl and "|cff80ff80" or "|cff888888"
            local catTag = ({
                attunement = "|cffff0000ATTUNEMENT|r",
                key        = "|cffff8800ANAHTAR|r",
                reputation = "|cff00ccff REPUTATION|r",
                class      = "|cffcc66ff SINIF|r",
                gear       = "|cff00ff88 ESYA|r",
            })[c.category] or "|cffff8000ZINCIR|r"

            HM:Print(string.format("%s%s|r [%s] (sev. %d+)", color, c.name, catTag, c.startLvl))
            HM:Print(string.format("  Baslangic: %s", c.startNpc or "?"))
            HM:Print(string.format("  Odul: %s", c.reward or "?"))
            if c.rep then
                HM:Print(string.format("  Rep: |cff00ccff%s|r", c.rep))
            end
            shown = shown + 1
        end
    end

    if shown == 0 then
        HM:Print(WARN .. "Henuz seviyene uygun endgame zinciri yok. /hm zincir tum ile hepsini gor.")
    else
        HM:Print(string.format("  %d zincir gosterildi. /hm zincir tum = hepsi, /hm zincir <ad> = detay", shown))
    end
end

function Chains:Detail(search)
    if not search or search == "" then return self:List(false) end
    search = search:lower()

    for _, c in ipairs(ENDGAME_CHAINS) do
        if c.name:lower():find(search, 1, true) then
            HM:Print("|cff33ccff— " .. c.name .. " —|r")
            HM:Print("Kategori: " .. (c.category or "?"))
            HM:Print("Seviye: " .. c.startLvl .. "+ (ideal " .. (c.idealLvl or c.startLvl) .. ")")
            HM:Print("Baslangic: " .. (c.startNpc or "?"))
            HM:Print("Odul: " .. (c.reward or "?"))
            if c.rep then HM:Print("Rep: |cff00ccff" .. c.rep .. "|r") end
            HM:Print(" ")
            for _, s in ipairs(c.steps or {}) do
                HM:Print("  " .. s)
            end
            return
        end
    end
    HM:Print(BAD .. "'" .. search .. "' adinda zincir bulunamadi.")
end

---------------------------------------------------------------------------
-- Komut: /hm zincir [tum|<ad>]
---------------------------------------------------------------------------
function Chains:Command(arg)
    arg = (arg or ""):lower()
    if arg == "tum" or arg == "all" or arg == "hepsi" then
        self:List(true)
    elseif arg == "" then
        self:List(false)
    else
        self:Detail(arg)
    end
end
