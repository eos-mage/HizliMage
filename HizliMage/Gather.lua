---------------------------------------------------------------------------
-- Gather.lua: ot ve maden noktaları (harita pinleri + yaklaşınca haber).
--
-- Veri bu eklentide DEĞİL: ayrı "HizliMage_Veri" eklentisindedir (GatherMate2_Data'nın
-- Forever dökümü; GatherMateData2HerbDB ve GatherMateData2MineDB tabloları, harita
-- kimliği -> {koordinat = düğüm türü}). O veri başkasının derlemesi olduğu için
-- depoda yeniden dağıtılmaz; yalnızca bu bilgisayarda durur. Veri eklentisi (ya da
-- gerçek GatherMate2_Data) yüklü değilse modül sessizce boş çalışır.
--
-- Bunlar "bu düğüm burada çıkabiliyor" noktalarıdır; düğüm o an orada olmayabilir.
--
-- Ayarlar (menüden ya da komutla):
--   /hm ot, /hm maden     pinleri aç/kapat          /hm topla  ikisini aç
--   /hm yakin 40          yaklaşınca haber mesafesi (yarda), 0 = kapalı
--   /hm sayac             bulunduğun bölgede kaç nokta var
--   "Yalnızca toplayabildiklerim": mesleğin ve becerin yetmeyen düğümler gizlenir
---------------------------------------------------------------------------
local _, ns = ...
local HM = ns.HM
if not HM then return end

local Gather = {}
HM.Gather = Gather

-- düğüm türü -> { ad, gereken beceri }
local HERBS = {
    [401] = { "Peacebloom", 1 }, [402] = { "Silverleaf", 1 }, [403] = { "Earthroot", 15 },
    [404] = { "Mageroyal", 50 }, [405] = { "Briarthorn", 70 }, [407] = { "Stranglekelp", 85 },
    [408] = { "Bruiseweed", 100 }, [409] = { "Wild Steelbloom", 115 }, [410] = { "Grave Moss", 120 },
    [411] = { "Kingsblood", 125 }, [412] = { "Liferoot", 150 }, [413] = { "Fadeleaf", 160 },
    [414] = { "Goldthorn", 170 }, [415] = { "Khadgar's Whisker", 185 }, [416] = { "Wintersbite", 195 },
    [417] = { "Firebloom", 205 }, [418] = { "Purple Lotus", 210 }, [420] = { "Arthas' Tears", 220 },
    [421] = { "Sungrass", 230 }, [422] = { "Blindweed", 235 }, [423] = { "Ghost Mushroom", 245 },
    [424] = { "Gromsblood", 250 }, [425] = { "Golden Sansam", 260 }, [426] = { "Dreamfoil", 270 },
    [427] = { "Mountain Silversage", 280 }, [428] = { "Plaguebloom", 285 }, [429] = { "Icecap", 290 },
    [431] = { "Black Lotus", 300 }, [4401] = { "Demonsage", 300 },
}
local ORES = {
    [201] = { "Copper Vein", 1 }, [202] = { "Tin Vein", 65 }, [203] = { "Iron Deposit", 125 },
    [204] = { "Silver Vein", 75 }, [205] = { "Gold Vein", 155 }, [206] = { "Mithril Deposit", 175 },
    [207] = { "Ooze Covered Mithril Deposit", 175 }, [208] = { "Truesilver Deposit", 230 },
    [209] = { "Ooze Covered Silver Vein", 75 }, [210] = { "Ooze Covered Gold Vein", 155 },
    [211] = { "Ooze Covered Truesilver Deposit", 230 }, [212] = { "Ooze Covered Rich Thorium Vein", 275 },
    [213] = { "Ooze Covered Thorium Vein", 245 }, [214] = { "Small Thorium Vein", 245 },
    [215] = { "Rich Thorium Vein", 275 }, [217] = { "Dark Iron Deposit", 230 },
    [218] = { "Lesser Bloodstone Deposit", 75 }, [219] = { "Incendicite Mineral Vein", 65 },
    [4201] = { "Heavy Thorium Vein", 300 },
}
local KIND = {
    herb = { names = HERBS, prof = "Herbalism", label = "ot" },
    ore  = { names = ORES,  prof = "Mining",    label = "maden" },
}

-- GatherMate2 koordinatı: XXXXYYYY00 (10 hane) -> x%, y%
local function decode(coord)
    return math.floor(coord / 1e6) / 100, (math.floor(coord / 100) % 10000) / 100
end
Gather.Decode = decode

local function source(kind)
    if kind == "herb" then return GatherMateData2HerbDB end
    return GatherMateData2MineDB
end

---------------------------------------------------------------------------
-- Düğüm listeleri (harita başına bir kez çözülür)
---------------------------------------------------------------------------
local cache = { herb = {}, ore = {} }

local function allNodes(kind, mapID)
    local c = cache[kind][mapID]
    if c then return c end
    c = {}
    local db = source(kind)
    local src = type(db) == "table" and db[mapID]
    if type(src) == "table" then
        local names = KIND[kind].names
        -- Veri aynı düğümü birkaç metre arayla tekrar tekrar içerir: 0,4'lük ızgarada
        -- aynı türden tek nokta bırak (pin kalabalığını ve mükerrer haberi azaltır).
        local seen = {}
        for coord, id in pairs(src) do
            local x, y = decode(coord)
            local cell = id * 1000000 + math.floor(x / 0.4) * 1000 + math.floor(y / 0.4)
            if not seen[cell] then
                seen[cell] = true
                local info = names[id]
                c[#c + 1] = { x = x, y = y, id = id, n = info and info[1] or ("Düğüm #" .. tostring(id)), skill = info and info[2] or 1 }
            end
        end
        table.sort(c, function(a, b) if a.x ~= b.x then return a.x < b.x end return a.y < b.y end)
    end
    cache[kind][mapID] = c
    return c
end

---------------------------------------------------------------------------
-- Meslek becerisi (10 sn önbellek)
---------------------------------------------------------------------------
local skillAt, skills, skillKnown = -100, {}, false

local function readSkills()
    local now = GetTime()
    if now - skillAt < 10 then return end
    skillAt = now
    skills, skillKnown = {}, false
    local Camp = HM.Camp
    if not (Camp and Camp.Professions) then return end
    local ok, list = pcall(Camp.Professions, Camp)
    if not ok or type(list) ~= "table" then return end
    skillKnown = Camp.skillApi and true or false
    for _, p in ipairs(list) do
        if p.name and type(p.rank) == "number" then skills[p.name] = p.rank end
    end
end

-- Meslek puanı; meslek yoksa nil. İkinci dönüş: puanlar okunabildi mi.
function Gather:Skill(kind)
    readSkills()
    return skills[KIND[kind].prof], skillKnown
end

-- Bu türün pinleri açık ama karakterde o meslek olmadığı için hiçbiri görünmüyor mu?
-- (Yalnızca toplayabildiklerim açıkken mesleği olmayan karakterde liste boş kalır.)
function Gather:NoProfession(kind)
    local db = HM.db
    if not db or not db.gatherSkillOnly then return false end
    if (kind == "herb" and db.gatherHerbOff) or (kind == "ore" and db.gatherOreOff) then return false end
    local rank, known = self:Skill(kind)
    return known and rank == nil
end

local HINT_NOPROF = "Hepsini görmek için Menü > |cffffd100Yalnızca toplayabildiklerim|r satırını kapat."

-- filtered = true: "Yalnızca toplayabildiklerim" açıksa becerin yetmeyenler elenir.
function Gather:NodesFor(mapID, kind, filtered)
    if not (mapID and KIND[kind]) then return {} end
    local list = allNodes(kind, mapID)
    if not filtered or not (HM.db and HM.db.gatherSkillOnly) then return list end
    local rank, known = self:Skill(kind)
    if not known then return list end       -- beceri okunamıyorsa hiçbir şeyi saklama
    if not rank then return {} end          -- bu meslek yok
    local out = {}
    for i = 1, #list do
        if list[i].skill <= rank then out[#out + 1] = list[i] end
    end
    return out
end

function Gather:HerbsFor(mapID) return self:NodesFor(mapID, "herb", false) end
function Gather:OresFor(mapID) return self:NodesFor(mapID, "ore", false) end

---------------------------------------------------------------------------
-- Yaklaşınca haber: düğümlerin dünya koordinatı harita başına bir kez hesaplanır
---------------------------------------------------------------------------
local world = { herb = {}, ore = {} }     -- [mapID] = { {wx, wy, node}, ... }
local recent = {}                         -- son haberler: { wx, wy, zaman }
local lastPing = -100
local SAME_NODE = 300                     -- aynı yer için tekrar etme süresi (sn)
local SAME_SPOT = 30                      -- bu kadar yarda içindeki noktalar "aynı yer" sayılır
local MIN_GAP = 4                         -- iki haber arası en az süre (sn)

local function recentlyTold(wx, wy, now)
    for i = #recent, 1, -1 do
        local r = recent[i]
        if now - r[3] > SAME_NODE then
            table.remove(recent, i)
        else
            local dx, dy = r[1] - wx, r[2] - wy
            if dx * dx + dy * dy <= SAME_SPOT * SAME_SPOT then return true end
        end
    end
    return false
end

local function worldNodes(kind, mapID)
    local w = world[kind][mapID]
    if w then return w end
    w = {}
    for _, n in ipairs(allNodes(kind, mapID)) do
        local wx, wy = HM:MapWorldPos(mapID, n.x, n.y)
        if wx then w[#w + 1] = { wx, wy, n } end
    end
    world[kind][mapID] = w
    return w
end

-- En yakın, yakın zamanda haber verilmemiş uygun düğüm: node, mesafe(yd), tür, harita, wx, wy.
function Gather:Nearest(range)
    local px, py, _, mapID = HM:PlayerWorldPos()
    if not px then return nil end
    local db = HM.db
    local now = GetTime()
    local best, bestD, bestKind, bestE
    local r2 = range * range
    for kind in pairs(KIND) do
        local off = (kind == "herb") and db.gatherHerbOff or (kind == "ore") and db.gatherOreOff
        if not off then
            local rank, known = self:Skill(kind)
            local limit = (db.gatherSkillOnly and known) and (rank or -1) or nil
            for _, e in ipairs(worldNodes(kind, mapID)) do
                if not limit or e[3].skill <= limit then
                    local dx, dy = e[1] - px, e[2] - py
                    local d2 = dx * dx + dy * dy
                    if d2 <= r2 and (not bestD or d2 < bestD) and not recentlyTold(e[1], e[2], now) then
                        best, bestD, bestKind, bestE = e[3], d2, kind, e
                    end
                end
            end
        end
    end
    if best then return best, math.sqrt(bestD), bestKind, mapID, bestE[1], bestE[2] end
    return nil
end

function Gather:ProximityCheck()
    local db = HM.db
    if not db or (db.gatherRange or 0) <= 0 then return end
    if HM.inInstance then return end
    if UnitOnTaxi and UnitOnTaxi("player") then return end
    if UnitIsDeadOrGhost and UnitIsDeadOrGhost("player") then return end
    local now = GetTime()
    if now - lastPing < MIN_GAP then return end
    local node, dist, kind, _, wx, wy = self:Nearest(db.gatherRange)
    if not node then return end
    lastPing = now
    recent[#recent + 1] = { wx, wy, now }
    if PlaySound then pcall(PlaySound, (SOUNDKIT and SOUNDKIT.MAP_PING) or 3175) end
    HM:Print(string.format("|cff80ff80Yakında %s noktası:|r %s (~%d yd, %.1f, %.1f)",
        KIND[kind].label, node.n, math.floor(dist + 0.5), node.x, node.y))
end

---------------------------------------------------------------------------
-- Ayarlar
---------------------------------------------------------------------------
function Gather:Set(kind, on, quiet)
    if kind == "herb" then HM.db.gatherHerbOff = not on else HM.db.gatherOreOff = not on end
    if not quiet then
        HM:Print((kind == "herb" and "Ot pinleri: " or "Maden pinleri: ") .. (on and "|cff80ff80açık|r" or "|cffff6060kapalı|r"))
        if on and self:NoProfession(kind) then
            HM:Print((kind == "herb" and "Bu karakterde Herbalism yok" or "Bu karakterde Mining yok") .. "; bu yüzden haritada görünmezler. " .. HINT_NOPROF)
        end
    end
    if HM.Pins then HM.Pins:Refresh() end
end

function Gather:ToggleHerb() self:Set("herb", HM.db.gatherHerbOff and true or false) end
function Gather:ToggleOre() self:Set("ore", HM.db.gatherOreOff and true or false) end

function Gather:AllOn()
    HM.db.gatherHerbOff, HM.db.gatherOreOff = false, false
    HM:Print("Ot ve maden pinleri |cff80ff80açık|r.")
    if HM.Pins then HM.Pins:Refresh() end
end

function Gather:SetSkillOnly(on, quiet)
    HM.db.gatherSkillOnly = on and true or false
    if not quiet then
        HM:Print("Yalnızca toplayabildiğim düğümler: " .. (on and "|cff80ff80açık|r" or "|cffff6060kapalı|r (hepsi görünür)"))
    end
    if HM.Pins then HM.Pins:Refresh() end
end

function Gather:SetRange(y, quiet)
    y = tonumber(y)
    if not y then
        HM:Print(string.format("Yaklaşınca haber: %s. Değiştirmek için |cffffd100/hm yakin 40|r (0 = kapat).",
            (HM.db.gatherRange or 0) > 0 and (HM.db.gatherRange .. " yarda") or "kapalı"))
        return
    end
    if y < 0 then y = 0 end
    if y > 200 then y = 200 end
    HM.db.gatherRange = y
    if quiet then return end
    if y == 0 then
        HM:Print("Yaklaşınca haber: |cffff6060kapalı|r")
    else
        HM:Print(string.format("Yaklaşınca haber: |cff80ff80%d yarda|r", y))
    end
end

function Gather:Report()
    local mid = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player") or nil
    if not mid or HM.IsSecret(mid) then HM:Print("Bölge okunamadı.") return end
    local allH, allO = #allNodes("herb", mid), #allNodes("ore", mid)
    local h, o = #self:NodesFor(mid, "herb", true), #self:NodesFor(mid, "ore", true)
    local hr, known = self:Skill("herb")
    local orank = self:Skill("ore")
    HM:Print(string.format("%s: |cff80ff80%d ot|r, |cffcc8844%d maden|r noktası (toplayabildiğin: %d ot, %d maden).",
        HM:MapName(mid), allH, allO, h, o))
    if known then
        HM:Print(string.format("Becerin: Herbalism %s, Mining %s.", hr and tostring(hr) or "yok", orank and tostring(orank) or "yok"))
        if self:NoProfession("herb") or self:NoProfession("ore") then
            HM:Print("Mesleğin olmayan türün noktaları haritada ve yakınlık haberinde gizlidir. " .. HINT_NOPROF)
        end
    else
        HM:Print("Meslek becerin okunamadı; bütün düğümler gösteriliyor.")
    end
    if type(GatherMateData2HerbDB) ~= "table" and type(GatherMateData2MineDB) ~= "table" then
        HM:Print("|cffff8080Ot/maden verisi yüklü değil.|r Eklenti listesinde \"Hizli Mage - Veri\" (HizliMage_Veri) işaretli olmalı.")
    end
end

---------------------------------------------------------------------------
-- Giriş
---------------------------------------------------------------------------
HM:OnLogin(function()
    local db = HM.db
    db.gatherHerbOff = db.gatherHerbOff == true
    db.gatherOreOff = db.gatherOreOff == true
    if db.gatherSkillOnly == nil then db.gatherSkillOnly = true end
    if type(db.gatherRange) ~= "number" then db.gatherRange = 40 end
    db.gatherSize = nil     -- 2.16'nın kullanılmayan ayarı
    HM:Ticker(2, function() Gather:ProximityCheck() end, "ot/maden yakınlık")
end)
