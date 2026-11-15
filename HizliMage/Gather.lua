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
-- Gösterim (v2.18):
--   Dünya haritası : varsayılan "küçük nokta" (harita kapanmasın diye); simge ya da hiç de seçilebilir
--   Minimap        : görüş alanındaki düğümler (GatherMate2'deki gibi); varsayılan küçük nokta, simge de seçilebilir
--
-- Ayarlar (menüden ya da komutla):
--   /hm ot, /hm maden     ot / maden noktalarını aç/kapat   /hm topla  ikisini aç
--   /hm topla harita nokta|simge|yok    dünya haritasındaki görünüm
--   /hm topla minimap nokta|simge|yok   minimap'teki görünüm (yalnız "/hm topla minimap" açar/kapatır)
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
-- Minimap pinleri (GatherMate2'deki gibi): minimap'in gösterdiği alandaki düğümler.
--
--  * Konum: düğümle oyuncunun dünya koordinatı farkı (yarda) / minimap yarıçapı.
--    Yarıçapı istemci verir (C_Minimap.GetViewRadius): yakınlaştırma ve iç/dış mekân
--    farkı orada hesaplıdır.
--  * Dönen minimap (rotateMinimap) açıksa fark oyuncunun yönüne göre döndürülür.
--  * Kare minimap (EllesmereUI gibi arayüzler GetMinimapShape tanımlar) köşeleri de
--    kullanır; üstten/alttan kırpılmış haritada kırpılan şeride pin konmaz.
--  * Pinler tıklamayı geçirir (minimap'e tıklama bozulmaz); üstüne gelince ad çıkar.
---------------------------------------------------------------------------
local MM = { pins = {}, cand = {}, n = 0, shown = 0, dirty = true, candAt = -100, errors = 0 }
Gather.MM = MM
local MM_SIZE = 12          -- kenar payı için en büyük pin boyu (minimap birimi)
local MM_DOT  = { 6, 7, 9 }       -- nokta boyu: pin boyutu Küçük / Orta / Büyük
local MM_ICONSIZE = { 10, 12, 15 } -- simge boyu
local MM_COLOR = { herb = { 0.30, 0.95, 0.40 }, ore = { 1.00, 0.50, 0.10 } }
local MM_MAX = 80           -- en fazla pin
local MM_TICK = 0.05        -- konum güncelleme aralığı (sn)
local MM_ICON = {
    herb = { "Interface\\Icons\\INV_Misc_Flower_02", "atlas:Mobile-Herbalism", "atlas:worldquest-icon-herbalism" },
    ore  = { "Interface\\Icons\\INV_Pick_02", "atlas:Mobile-Mining", "atlas:worldquest-icon-mining" },
}
local CIRCLE = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
-- C_Minimap.GetViewRadius yoksa: yakınlaştırma düzeyine göre çap (yarda)
local MM_DIAM = {
    outdoor = { [0] = 466.67, 400, 333.33, 266.67, 200, 133.33 },
    indoor  = { [0] = 300, 240, 180, 120, 80, 50 },
}

local function mmRadius(mm)
    if C_Minimap and C_Minimap.GetViewRadius then
        local ok, r = pcall(C_Minimap.GetViewRadius)
        if ok and type(r) == "number" and not HM.IsSecret(r) and r > 1 then return r end
    end
    local zoom = mm.GetZoom and mm:GetZoom()
    if type(zoom) ~= "number" then zoom = 0 end
    local indoors = IsIndoors and IsIndoors()
    return (MM_DIAM[indoors and "indoor" or "outdoor"][zoom] or MM_DIAM.outdoor[0]) / 2
end

local function mmShape()
    if type(GetMinimapShape) == "function" then
        local ok, s = pcall(GetMinimapShape)
        if ok and type(s) == "string" then return s end
    end
    return "ROUND"
end

-- Minimap'in bu çeyreği yuvarlak mı? (GetMinimapShape adları: ROUND, SQUARE,
-- CORNER-TOPLEFT, SIDE-LEFT, TRICORNER-TOPLEFT ...)
local function quadrantRound(shape, right, top)
    if shape == "ROUND" then return true end
    if shape == "SQUARE" then return false end
    local kind, where = shape:match("^(%a+)%-(%a+)$")
    if not kind then return true end
    local v, h = top and "TOP" or "BOTTOM", right and "RIGHT" or "LEFT"
    if kind == "CORNER" then return where == v .. h end
    if kind == "SIDE" then return where == v or where == h end
    if kind == "TRICORNER" then
        -- adı geçen köşenin karşısındaki köşe kare, öbür üçü yuvarlak
        local ov = where:find("TOP") and "BOTTOM" or "TOP"
        local oh = where:find("LEFT") and "RIGHT" or "LEFT"
        return not (v == ov and h == oh)
    end
    return true
end
Gather.QuadrantRound = quadrantRound

-- Dönen minimap: yön (radyan) ya da nil; ikinci dönüş false ise yön okunamadı (çizme).
local rotAt, rotOn = -100, false
local function mmFacing(now)
    if now - rotAt > 1 then
        rotAt = now
        rotOn = (GetCVar and GetCVar("rotateMinimap") == "1") and true or false
        if rotOn and C_Minimap and C_Minimap.IsRotateMinimapIgnored then
            local ok, ign = pcall(C_Minimap.IsRotateMinimapIgnored)
            if ok and ign == true then rotOn = false end
        end
    end
    if not rotOn then return nil, true end
    local f = GetPlayerFacing and GetPlayerFacing()
    if type(f) ~= "number" or HM.IsSecret(f) then return nil, false end
    return f, true
end

local function mmEnter(self)
    local n = self.node
    if not n then return end
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
    GameTooltip:SetText(HM:T(n.n), 1, 0.82, 0)
    GameTooltip:AddLine(HM:T(string.format("%s noktası · gereken beceri %d", self.kind == "herb" and "Ot" or "Maden", n.skill or 1)), 1, 1, 1)
    GameTooltip:Show()
end

local function mmLeave() GameTooltip:Hide() end

-- Minimap'teki görünüm: 0 = gösterme, 1 = küçük nokta (varsayılan), 2 = simge
function Gather:MiniMode()
    local db = HM.db
    if not db then return 1 end
    local m = db.gatherMiniMode
    if m == 0 or m == 2 then return m end
    return 1
end

local function mmScaleIndex()
    local v = HM.db and HM.db.pinScale
    if v == 2 or v == 3 then return v end
    return 1
end

-- Pinin görünümü: nokta (yeşil ot, turuncu maden) ya da meslek simgesi.
local function mmSkin(p, kind, mode)
    local si = mmScaleIndex()
    if mode == 1 then
        local c = MM_COLOR[kind] or MM_COLOR.herb
        p.tex:SetTexture(CIRCLE)
        if p.tex.SetTexCoord then p.tex:SetTexCoord(0, 1, 0, 1) end
        p.tex:SetVertexColor(c[1], c[2], c[3], 1)
        p:SetSize(MM_DOT[si], MM_DOT[si])
    else
        p.tex:SetVertexColor(1, 1, 1, 1)
        local k = HM.ApplyIcon(p.tex, MM_ICON[kind])
        -- simge dosyalarının kenar çerçevesini kırp (atlas ise dokunma)
        if k ~= "atlas" and p.tex.SetTexCoord then p.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
        p:SetSize(MM_ICONSIZE[si], MM_ICONSIZE[si])
    end
end

local function mmPin(i)
    local p = MM.pins[i]
    if p then return p end
    local mm = _G.Minimap
    p = CreateFrame("Frame", nil, mm)
    p:SetSize(MM_SIZE, MM_SIZE)
    if p.SetFrameLevel and mm.GetFrameLevel then p:SetFrameLevel((mm:GetFrameLevel() or 1) + 4) end
    p.ring = p:CreateTexture(nil, "BACKGROUND")
    p.ring:SetTexture(CIRCLE)
    p.ring:SetVertexColor(0, 0, 0, 0.9)
    p.ring:SetPoint("TOPLEFT", -1, 1)
    p.ring:SetPoint("BOTTOMRIGHT", 1, -1)
    p.tex = p:CreateTexture(nil, "ARTWORK")
    p.tex:SetAllPoints()
    -- simgeyi daire içine al (maske dokusu varsa)
    if p.CreateMaskTexture and p.tex.AddMaskTexture then
        local ok, mask = pcall(p.CreateMaskTexture, p)
        if ok and mask then
            pcall(mask.SetTexture, mask, CIRCLE, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            mask:SetAllPoints(p.tex)
            pcall(p.tex.AddMaskTexture, p.tex, mask)
            p.mask = mask
        end
    end
    p:EnableMouse(true)
    if p.SetMouseClickEnabled then pcall(p.SetMouseClickEnabled, p, false) end
    p:SetScript("OnEnter", mmEnter)
    p:SetScript("OnLeave", mmLeave)
    p:Hide()
    MM.pins[i] = p
    return p
end

local function mmHideAll()
    if not MM.anyShown then return end
    for i = 1, #MM.pins do
        local p = MM.pins[i]
        if p:IsShown() then p:Hide() end
    end
    MM.shown, MM.anyShown, MM.lx = 0, false, nil
end

-- Oyuncunun çevresindeki düğümleri topla (minimap'in gösterebileceği alan + pay).
local function mmRebuild(px, py, mapID, radius, now)
    local db = HM.db
    local cand, n = MM.cand, 0
    local reach = radius * 1.5 + 30          -- kare haritanın köşesi yarıçapın 1,41 katı
    local r2 = reach * reach
    for kind in pairs(KIND) do
        local off = (kind == "herb") and db.gatherHerbOff or (kind == "ore") and db.gatherOreOff
        if not off then
            local rank, known = Gather:Skill(kind)
            local limit = (db.gatherSkillOnly and known) and (rank or -1) or nil
            for _, e in ipairs(worldNodes(kind, mapID)) do
                if not limit or e[3].skill <= limit then
                    local dx, dy = e[1] - px, e[2] - py
                    local d2 = dx * dx + dy * dy
                    if d2 <= r2 then
                        n = n + 1
                        local c = cand[n]
                        if not c then c = {}; cand[n] = c end
                        c[1], c[2], c[3], c[4], c[5] = e[1], e[2], e[3], kind, d2
                    end
                end
            end
        end
    end
    for i = #cand, n + 1, -1 do cand[i] = nil end
    if n > MM_MAX then
        table.sort(cand, function(a, b) return a[5] < b[5] end)
        for i = n, MM_MAX + 1, -1 do cand[i] = nil end
        n = MM_MAX
    end
    MM.n, MM.map, MM.cx, MM.cy, MM.cr, MM.candAt, MM.dirty = n, mapID, px, py, radius, now, false
    local mode = Gather:MiniMode()
    local skin = mode * 10 + mmScaleIndex()
    for i = 1, n do
        local p, c = mmPin(i), cand[i]
        if p.kind ~= c[4] or p.skin ~= skin then
            p.kind, p.skin = c[4], skin
            mmSkin(p, c[4], mode)
        end
        p.node = c[3]
    end
    for i = n + 1, #MM.pins do
        local p = MM.pins[i]
        if p:IsShown() then p:Hide() end
        p.node = nil
    end
    MM.force = true
end

function Gather:MinimapUpdate(force)
    local db = HM.db
    local mm = _G.Minimap
    if not (db and mm) or self:MiniMode() == 0 or (db.gatherHerbOff and db.gatherOreOff) or HM.inInstance
        or (mm.IsVisible and not mm:IsVisible()) then
        mmHideAll()
        return
    end
    local px, py, _, mapID = HM:PlayerWorldPos()
    if not px then mmHideAll() return end
    local now = GetTime()
    local facing, fok = mmFacing(now)
    if not fok then mmHideAll() return end
    local radius = mmRadius(mm)
    local moved2 = MM.cx and ((px - MM.cx) * (px - MM.cx) + (py - MM.cy) * (py - MM.cy)) or math.huge
    if force or MM.dirty or mapID ~= MM.map or radius ~= MM.cr or (now - MM.candAt) > 2
        or moved2 > (radius * 0.25) * (radius * 0.25) then
        mmRebuild(px, py, mapID, radius, now)
    end
    local w, h = mm:GetWidth(), mm:GetHeight()
    if type(w) ~= "number" or type(h) ~= "number" or w < 10 or h < 10 then mmHideAll() return end
    if not MM.force and px == MM.lx and py == MM.ly and facing == MM.lf and w == MM.lw and h == MM.lh then return end
    MM.force = false
    MM.lx, MM.ly, MM.lf, MM.lw, MM.lh = px, py, facing, w, h

    local halfW, halfH = w / 2, h / 2
    local shape = mmShape()
    -- görünen dikdörtgen: tıklama alanı içe çekilmişse (kırpılmış harita) o şeride pin koyma
    local il, ir, it, ib = 0, 0, 0, 0
    if mm.GetHitRectInsets then
        local a, b, c, d = mm:GetHitRectInsets()
        il, ir, it, ib = tonumber(a) or 0, tonumber(b) or 0, tonumber(c) or 0, tonumber(d) or 0
    end
    local pad = MM_SIZE / 2 + 1
    local maxR = math.min(halfW, halfH) - pad
    local sinF, cosF
    if facing then sinF, cosF = math.sin(facing), math.cos(facing) end
    local shown = 0
    for i = 1, MM.n do
        local c, p = MM.cand[i], MM.pins[i]
        local e, s = py - c[2], px - c[1]           -- doğu (+), güney (+): yarda
        if facing then e, s = e * cosF - s * sinF, e * sinF + s * cosF end
        local x, y = e / radius * halfW, -(s / radius) * halfH
        local inside
        if quadrantRound(shape, x >= 0, y >= 0) then
            inside = (x * x + y * y) <= maxR * maxR
        else
            inside = true
        end
        if inside and (x < -(halfW - il - pad) or x > (halfW - ir - pad) or y > (halfH - it - pad) or y < -(halfH - ib - pad)) then
            inside = false
        end
        if inside then
            p:ClearAllPoints()
            p:SetPoint("CENTER", mm, "CENTER", x, y)
            if not p:IsShown() then p:Show() end
            shown = shown + 1
        elseif p:IsShown() then
            p:Hide()
        end
    end
    MM.shown, MM.anyShown, MM.radius, MM.shape = shown, shown > 0, radius, shape
end

local function mmStart()
    if MM.driver then return end
    local f = CreateFrame("Frame", nil, UIParent)
    local acc = 0
    f:SetScript("OnUpdate", function(self, elapsed)
        acc = acc + (elapsed or 0)
        if acc < MM_TICK then return end
        acc = 0
        local ok, err = pcall(Gather.MinimapUpdate, Gather)
        if not ok then
            HM:LogError("minimap pinleri", err)
            MM.errors = MM.errors + 1
            if MM.errors >= 5 then          -- aynı hata saniyede 20 kez yazılmasın
                self:SetScript("OnUpdate", nil)
                pcall(mmHideAll)
            end
        end
    end)
    MM.driver = f
end

---------------------------------------------------------------------------
-- Ayarlar
---------------------------------------------------------------------------
function Gather:Set(kind, on, quiet)
    if kind == "herb" then HM.db.gatherHerbOff = not on else HM.db.gatherOreOff = not on end
    if not quiet then
        HM:Print((kind == "herb" and "Ot noktaları: " or "Maden noktaları: ") .. (on and "|cff80ff80açık|r" or "|cffff6060kapalı|r"))
        if on and self:NoProfession(kind) then
            HM:Print((kind == "herb" and "Bu karakterde Herbalism yok" or "Bu karakterde Mining yok") .. "; bu yüzden haritada görünmezler. " .. HINT_NOPROF)
        end
    end
    MM.dirty = true
    if HM.Pins then HM.Pins:Refresh() end
end

function Gather:ToggleHerb() self:Set("herb", HM.db.gatherHerbOff and true or false) end
function Gather:ToggleOre() self:Set("ore", HM.db.gatherOreOff and true or false) end

function Gather:AllOn()
    HM.db.gatherHerbOff, HM.db.gatherOreOff = false, false
    HM:Print("Ot ve maden noktaları |cff80ff80açık|r.")
    MM.dirty = true
    if HM.Pins then HM.Pins:Refresh() end
end

function Gather:SetSkillOnly(on, quiet)
    HM.db.gatherSkillOnly = on and true or false
    if not quiet then
        HM:Print("Yalnızca toplayabildiğim düğümler: " .. (on and "|cff80ff80açık|r" or "|cffff6060kapalı|r (hepsi görünür)"))
    end
    MM.dirty = true
    if HM.Pins then HM.Pins:Refresh() end
end

-- Minimap denemesi (/hm topla test): oyuncunun çevresine 8 yöne 60 yarda uzağa deneme
-- noktası koyar (yalnız bellekte; /reload ya da ikinci çağrı kaldırır). Kuzeydeki pin
-- minimap'in üstünde, doğudaki sağında görünmelidir; üstüne gelince yönü yazar.
-- Ot/maden verisi olmayan yerde (şehir gibi) minimap gösterimini sınamak içindir.
function Gather:TestRing()
    if MM.test then
        world[MM.test.kind][MM.test.map] = MM.test.saved
        MM.test, MM.dirty = nil, true
        HM:Print("Minimap denemesi kaldırıldı.")
        return false
    end
    local px, py, _, mapID = HM:PlayerWorldPos()
    if not px then
        HM:Print("Konum okunamıyor (zindan içi olabilir); deneme yapılamadı.")
        return false
    end
    local DIRS = {
        { "kuzey", 1, 0 }, { "kuzeydoğu", 0.7071, -0.7071 }, { "doğu", 0, -1 }, { "güneydoğu", -0.7071, -0.7071 },
        { "güney", -1, 0 }, { "güneybatı", -0.7071, 0.7071 }, { "batı", 0, 1 }, { "kuzeybatı", 0.7071, 0.7071 },
    }
    local ring = {}
    for i, d in ipairs(DIRS) do
        -- dünya ekseni: x = kuzey (+), y = batı (+)
        ring[i] = { px + d[2] * 60, py + d[3] * 60, { x = 0, y = 0, id = 401, n = "Deneme: " .. d[1] .. " (60 yd)", skill = 1 } }
    end
    MM.test = { kind = "herb", map = mapID, saved = world.herb[mapID] }
    world.herb[mapID] = ring
    local db = HM.db
    db.gatherHerbOff = false
    if self:MiniMode() == 0 then db.gatherMiniMode = 1 end
    MM.dirty = true
    local ok, err = pcall(self.MinimapUpdate, self, true)
    if not ok then HM:LogError("minimap pinleri", err) end
    HM:Print(string.format("Minimap denemesi: çevrene 8 yöne 60 yarda uzağa deneme noktası kondu; şu an %d tanesi görünüyor. Kuzeydeki pin minimap'in üstünde olmalı (üstüne gelince yönü yazar). Kaldırmak için yeniden |cffffd100/hm topla test|r.", MM.shown or 0))
    return true
end

-- Dünya haritasındaki görünüm: 0 = gösterme, 1 = küçük nokta (varsayılan), 2 = simge
local MODE_NAME = { [0] = "gizli", [1] = "küçük nokta", [2] = "simge" }
local MODE_WORD = {
    yok = 0, gizli = 0, kapat = 0, kapali = 0, ["kapalı"] = 0, ["0"] = 0,
    nokta = 1, kucuk = 1, ["küçük"] = 1, ["1"] = 1,
    simge = 2, ikon = 2, buyuk = 2, ["büyük"] = 2, ["2"] = 2,
}

function Gather:MapMode()
    local m = HM.db and HM.db.gatherMapMode
    if m == 0 or m == 2 then return m end
    return 1
end

function Gather:SetMapMode(mode, quiet)
    if type(mode) == "string" then mode = MODE_WORD[mode:lower():match("^%s*(.-)%s*$")] end
    if mode ~= 0 and mode ~= 1 and mode ~= 2 then
        if not quiet then
            HM:Print("Dünya haritasında ot/maden: " .. MODE_NAME[self:MapMode()]
                .. ". Değiştirmek için |cffffd100/hm topla harita nokta|r (ya da |cffffd100simge|r / |cffffd100yok|r).")
        end
        return false
    end
    HM.db.gatherMapMode = mode
    if not quiet then HM:Print("Dünya haritasında ot/maden: |cff80ff80" .. MODE_NAME[mode] .. "|r") end
    if HM.Pins then HM.Pins:Refresh() end
    return true
end

-- Minimap'teki görünüm: 0 = gösterme, 1 = küçük nokta, 2 = simge (sözcükle de verilebilir)
function Gather:SetMiniMode(mode, quiet)
    if type(mode) == "string" then mode = MODE_WORD[mode:lower():match("^%s*(.-)%s*$")] end
    if mode ~= 0 and mode ~= 1 and mode ~= 2 then
        if not quiet then
            HM:Print("Minimap'te ot/maden: " .. MODE_NAME[self:MiniMode()]
                .. ". Değiştirmek için |cffffd100/hm topla minimap nokta|r (ya da |cffffd100simge|r / |cffffd100yok|r).")
        end
        return false
    end
    HM.db.gatherMiniMode = mode
    if mode ~= 0 then HM.db.gatherMiniLast = mode end
    MM.dirty = true
    if not quiet then HM:Print("Minimap'te ot/maden: |cff80ff80" .. MODE_NAME[mode] .. "|r") end
    local ok, err = pcall(self.MinimapUpdate, self, true)
    if not ok then HM:LogError("minimap pinleri", err) end
    return true
end

-- Aç / kapat (on = nil ise tersine çevirir); açarken son kullanılan görünüme döner.
function Gather:SetMinimap(on, quiet)
    if on == nil then on = (self:MiniMode() == 0) end
    local last = HM.db.gatherMiniLast
    return self:SetMiniMode(on and ((last == 2) and 2 or 1) or 0, quiet)
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
    local mmText = MODE_NAME[self:MiniMode()]
    if self:MiniMode() ~= 0 and MM.radius then
        mmText = mmText .. string.format(" (şu an %d nokta, görüş ~%d yd)", MM.shown or 0, math.floor(MM.radius + 0.5))
    end
    HM:Print(string.format("Görünüm: dünya haritasında %s, minimap'te %s. Menü > Harita pinleri'nden değişir.", MODE_NAME[self:MapMode()], mmText))
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
    if db.gatherMapMode ~= 0 and db.gatherMapMode ~= 2 then db.gatherMapMode = 1 end
    if db.gatherMinimapOff == true and db.gatherMiniMode == nil then db.gatherMiniMode = 0 end   -- 2.18 ilk denemesindeki ayar
    db.gatherMinimapOff = nil
    if db.gatherMiniMode ~= 0 and db.gatherMiniMode ~= 2 then db.gatherMiniMode = 1 end
    HM:Ticker(2, function() Gather:ProximityCheck() end, "ot/maden yakınlık")
    if _G.Minimap then mmStart() end
end)
