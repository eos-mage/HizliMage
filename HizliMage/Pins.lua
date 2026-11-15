---------------------------------------------------------------------------
-- Pins.lua: dünya haritası pinleri ve rare takibi.
--
-- Pin türleri (her biri menüden ya da /hm pin ile ayrı ayrı açılıp kapanır):
--   F  uçuş noktaları (rotadaki F adımları)            kanat
--   R  rare moblar (PinsData.lua)                       retail'deki rare yıldızı (elitler çerçeveli)
--   C  hazine sandığı noktaları (PinsData.lua)          retail'deki küçük hazine sandığı
--   H  ot noktaları, M maden noktaları (Gather.lua)     küçük nokta (ya da meslek simgesi)
--
-- Rare ipucu: seviye, yaklaşık yeniden doğma aralığı, bu karakterin son görüş /
-- ölüm kaydı ve düşen eşyalar (kalite rengi + varsa yüzde).
-- Rare pinine TIKLAYINCA aynı bilgiler bir kartta açılır: karttaki eşya satırının
-- üstüne gelince eşyanın kendi ipucu (özellikleri) çıkar, tıklayınca sabitlenir,
-- Shift+tık sohbete bağlantı yazar.
--
-- Veri iki yerden gelir:
--   PinsData.lua (bu eklenti)      : rare ve sandık konumları, seviye, yeniden doğma aralığı
--   HizliMage_Veri (ayrı eklenti)  : düşen eşyalar (HizliMageDropData), ot/maden noktaları
-- HizliMage_Veri yüklü değilse pinler yine çizilir; ipucunda düşen eşya bölümü olmaz.
--
-- Rare takibi: hedef / fare üstü / isim plakasında bir rare görülünce zamanı
-- kaydedilir ve (kapatılmadıysa) tek satır haber verilir.
---------------------------------------------------------------------------
local _, ns = ...
local HM = ns.HM
if not HM then return end

local Pins = {}
HM.Pins = Pins

local pool = {}       -- yeniden kullanılacak pin çerçeveleri
local active = {}     -- şu an haritada görünenler
local hovered         -- ipucu açık olan pin

-- Her tür için aday dokular: bu istemcide var olan ilki kullanılır (HM.ResolveIcon).
-- Rare ve sandık: oyunun kendi (retail) harita simgeleri; bu istemcide yoksa eski dosya simgeleri.
local ICONS = {
    F = { "Interface\\MINIMAP\\Tracking\\FlightMaster", "atlas:FlightMaster", "atlas:TaxiNode_Neutral" },
    R = { "atlas:VignetteKill", "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8" },
    RE = { "atlas:VignetteKillElite", "atlas:VignetteKill", "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8" },   -- rare elit
    C = { "atlas:VignetteLoot", "atlas:VignetteLootElite", "Interface\\Icons\\INV_Box_01" },
    H = { "Interface\\Icons\\INV_Misc_Flower_02", "atlas:Mobile-Herbalism", "atlas:worldquest-icon-herbalism" },
    M = { "Interface\\Icons\\INV_Pick_02", "atlas:Mobile-Mining", "atlas:worldquest-icon-mining" },
}
Pins.ICONS = ICONS
-- Boyut: simgenin boyu (harita birimi), "Küçük" ayarında. Menüdeki "Pin boyutu"
-- (Küçük / Orta / Büyük) hepsini birlikte büyütür. Bu istemcide oyunun rare/sandık
-- simgeleri çerçevesini dolduruyor (oyunda ölçüldü), o yüzden atlas için ek pay yok.
local BASE  = { F = 12, R = 11, C = 8, H = 8, M = 8 }
local SCALE = { 1.0, 1.3, 1.7 }
local ATLAS_PAD = 1.0
local LEVEL = { H = 3, M = 4, C = 6, F = 7, R = 8 }

local function pinFactor()
    return SCALE[(HM.db and HM.db.pinScale) or 1] or 1
end
Pins.Factor = pinFactor

local function pinSize(kind, resolved)
    local s = (BASE[kind] or 10) * pinFactor()
    if resolved == "atlas" and (kind == "R" or kind == "C" or kind == "F") then s = s * ATLAS_PAD end
    return math.floor(s + 0.5)
end
-- Ot/maden "küçük nokta" görünümü: bölgede yüzlerce düğüm olduğu için simge yerine
-- renkli küçük daire (koyu çerçeveli). Harita okunur kalır; üstüne gelince adı çıkar.
local DOT_TEX = "Interface\\CharacterFrame\\TempPortraitAlphaMask"   -- beyaz daire
local DOT_SIZE = { 5, 7, 9 }          -- Küçük / Orta / Büyük
local DOT_COLOR = { H = { 0.30, 0.95, 0.40 }, M = { 1.00, 0.50, 0.10 } }
Pins.DOT_COLOR = DOT_COLOR
Pins.DOT_TEX = DOT_TEX

local QCOLOR = {
    [0] = "ff9d9d9d", [1] = "ffffffff", [2] = "ff1eff00", [3] = "ff0070dd", [4] = "ffa335ee", [5] = "ffff8000",
}

---------------------------------------------------------------------------
-- Metin yardımcıları (oyun dışı testte de çalışır)
---------------------------------------------------------------------------
local function hoursText(h)
    if h >= 48 then return string.format("%.0f gün", h / 24) end
    if h == math.floor(h) then return string.format("%d sa", h) end
    return string.format("%.1f sa", h)
end

-- "~8–12 sa" / "~6 sa"
function Pins.RespawnText(rmin, rmax)
    if not rmin or rmin <= 0 then return nil end
    if not rmax or rmax <= rmin then return "~" .. hoursText(rmin) end
    if rmax >= 48 then
        return string.format("~%s – %s", hoursText(rmin), hoursText(rmax))
    end
    local a = (rmin == math.floor(rmin)) and string.format("%d", rmin) or string.format("%.1f", rmin)
    return string.format("~%s–%s", a, hoursText(rmax))
end

local function pctText(p10)
    local p = (p10 or 0) / 10
    if p >= 10 then return string.format("%%%.0f", p) end
    return string.format("%%%.1f", p)
end

-- Düşen eşya verisi (HizliMage_Veri eklentisi); yüklü değilse nil.
function Pins.DropData()
    local d = _G.HizliMageDropData
    if type(d) == "table" and type(d.drops) == "table" then return d end
    return nil
end

-- Bir rare'in kaydı: örnek sayısı, { eşya, kalite, yüzde*10, ... }
function Pins.DropsFor(id)
    local d = Pins.DropData()
    local rec = d and d.drops[id]
    if type(rec) == "table" and type(rec[2]) == "table" then return rec[1] or 0, rec[2] end
    return nil, nil
end

-- Eşya etiketi: simge + kalite renginde ad. İstemci eşyayı tanımıyorsa yedek ad.
function Pins.ItemLabel(itemID, q)
    local name, quality, icon
    local getInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    if getInfo then
        local ok, n, _, ql, _, _, _, _, _, _, tex = pcall(getInfo, itemID)
        if ok and type(n) == "string" then name, quality, icon = n, ql, tex end
    end
    if not icon then
        local getIcon = (C_Item and C_Item.GetItemIconByID) or GetItemIcon
        if getIcon then
            local ok, tex = pcall(getIcon, itemID)
            if ok and tex then icon = tex end
        end
    end
    local cached = name ~= nil
    local DD = Pins.DropData()
    name = name or (DD and DD.items and DD.items[itemID]) or ("Eşya #" .. tostring(itemID))
    if type(quality) ~= "number" then quality = q or 1 end
    local text = "|c" .. (QCOLOR[quality] or QCOLOR[1]) .. name .. "|r"
    if icon then text = "|T" .. tostring(icon) .. ":14:14:0:0|t " .. text end
    return text, cached
end

-- Eşya bağlantısı: istemci eşyayı tanıyorsa kendi bağlantısı (ikinci dönüş true),
-- tanımıyorsa yedek adla kurulmuş bağlantı.
function Pins.ItemLink(itemID, q)
    local getInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    if getInfo then
        local ok, _, link = pcall(getInfo, itemID)
        if ok and type(link) == "string" and link:find("|H", 1, true) then return link, true end
    end
    local DD = Pins.DropData()
    local name = (DD and DD.items and DD.items[itemID]) or ("Eşya #" .. tostring(itemID))
    return "|c" .. (QCOLOR[q or 1] or QCOLOR[1]) .. "|Hitem:" .. tostring(itemID) .. "::::::::::::|h[" .. name .. "]|h|r", false
end

-- Sohbet satırı için: simge + tıklanabilir bağlantı (eşya önbellekteyse), değilse renkli ad.
function Pins.ItemChat(itemID, q)
    local link, real = Pins.ItemLink(itemID, q)
    if not real then return (Pins.ItemLabel(itemID, q)) end
    local getIcon = (C_Item and C_Item.GetItemIconByID) or GetItemIcon
    if getIcon then
        local ok, tex = pcall(getIcon, itemID)
        if ok and tex then return "|T" .. tostring(tex) .. ":14:14:0:0|t " .. link end
    end
    return link
end

-- Rare ipucu satırları: { {sol, sağ, r, g, b, [r2, g2, b2], item = eşyaID, q = kalite}, ... }
-- ve "eksik eşya bilgisi var mı". Eşya satırlarında item alanı doludur (kart bunu kullanır).
function Pins:RareLines(id, x, y)
    local D = HM.PinsData
    local r = D and D.rares and D.rares[id]
    if not r then return nil end
    local lines, pending = {}, false
    local lvl = (r[2] == r[3]) and tostring(r[2]) or (r[2] .. "–" .. r[3])
    lines[#lines + 1] = { string.format("%s · seviye %s", (r[4] == 1) and "Rare elit" or "Rare", lvl), nil, 0.78, 0.78, 0.9 }
    if x and y then lines[#lines + 1] = { string.format("Konum: %.1f, %.1f", x, y), nil, 0.7, 0.7, 0.7 } end

    local resp = Pins.RespawnText(r[5], r[6])
    if resp then
        lines[#lines + 1] = { "Yeniden doğma: " .. resp, "yaklaşık", 1, 0.82, 0, 0.6, 0.6, 0.6 }
    end

    -- bu karakterin kaydı
    local rec = HM.db and HM.db.rareSeen and HM.db.rareSeen[id]
    if rec and time then
        local now = time()
        if rec.k then
            local ago = now - rec.k
            local msg = "Ölü görüldü: " .. HM:Duration(ago) .. " önce"
            if r[5] and r[5] > 0 then
                local early, late = rec.k + r[5] * 3600, rec.k + (r[6] > 0 and r[6] or r[5]) * 3600
                if now < early then
                    msg = msg .. " — en erken " .. HM:Duration(early - now) .. " sonra doğar"
                elseif now <= late then
                    msg = msg .. " — doğma aralığında"
                else
                    msg = msg .. " — süresi doldu, doğmuş olabilir"
                end
            end
            lines[#lines + 1] = { msg, nil, 1, 0.6, 0.6 }
        end
        if rec.t and (not rec.k or rec.t > rec.k) then
            lines[#lines + 1] = { "Canlı görüldü: " .. HM:Duration(now - rec.t) .. " önce", nil, 0.6, 1, 0.6 }
        end
    end

    local n, drops = Pins.DropsFor(id)
    if drops and #drops >= 3 then
        local head
        if n < 0 then
            head = "Özel düşenler (yüzde yok; QuestieDB ve klasik veri)"
        elseif n > 0 then
            head = string.format("Düşenler (Wowhead Forever, %d kayıt%s)", n, n < 20 and ", az veri" or "")
        else
            head = "Düşenler (Wowhead Forever)"
        end
        lines[#lines + 1] = { " " }
        lines[#lines + 1] = { head, nil, 0.5, 0.75, 0.9 }
        for i = 1, #drops, 3 do
            local label, cached = Pins.ItemLabel(drops[i], drops[i + 1])
            if not cached then pending = true end
            local line
            if (drops[i + 2] or 0) > 0 then
                line = { label, pctText(drops[i + 2]), 1, 1, 1, 1, 0.95, 0.75 }
            else
                line = { label, nil, 1, 1, 1 }
            end
            line.item, line.q = drops[i], drops[i + 1]
            lines[#lines + 1] = line
        end
    elseif not Pins.DropData() then
        lines[#lines + 1] = { "Düşen eşya verisi yüklü değil (HizliMage_Veri eklentisi).", nil, 0.6, 0.6, 0.6 }
    else
        lines[#lines + 1] = { "Bu rare'e özel düşen eşya kaydı yok; seviyesine göre dünya eşyası düşürür.", nil, 0.6, 0.6, 0.6 }
    end
    return lines, pending
end

---------------------------------------------------------------------------
-- Pin çerçeveleri
---------------------------------------------------------------------------
local function showTooltip(self)
    -- bu rare'in kartı açıkken ipucu kartın üstüne binmesin
    if self.kind == "R" and Pins.CardRare and Pins.CardRare() == self.rareID then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(HM:T(self.title or "?"), 1, 0.82, 0)
    local pending = false
    if self.kind == "R" and self.rareID then
        local lines, pend = Pins:RareLines(self.rareID, self.px, self.py)
        pending = pend
        local hasItems = false
        for _, l in ipairs(lines or {}) do
            if l.item then hasItems = true end
            if l[2] then
                GameTooltip:AddDoubleLine(HM:T(l[1]), HM:T(l[2]), l[3] or 1, l[4] or 1, l[5] or 1, l[6] or 1, l[7] or 1, l[8] or 1)
            else
                GameTooltip:AddLine(HM:T(l[1]), l[3] or 1, l[4] or 1, l[5] or 1, true)
            end
        end
        if hasItems then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(HM:T("Tıkla: eşyaların özelliklerine bak"), 0.45, 0.8, 1)
        end
    else
        if self.subtitle then GameTooltip:AddLine(HM:T(self.subtitle), 1, 1, 1, true) end
        if self.note then GameTooltip:AddLine(HM:T(self.note), 0.7, 0.9, 1, true) end
    end
    GameTooltip:Show()
    -- İstemci eşya bilgisini sonradan getirir: fare hâlâ üstündeyse bir kez yenile.
    if pending and not self.retried then
        self.retried = true
        HM:After(0.6, function()
            if hovered == self and self:IsShown() then showTooltip(self) end
        end, "pin ipucu")
    end
end

-- Tıklama: yalnız rare pinleri tıklanır (eşya kartı). Öbür pinlerde tıklama alttaki
-- haritaya geçer. Sağ tık rare pininde de haritaya geçsin (uzaklaştırma bozulmasın);
-- bu ayar savaşta değiştirilemediği için savaş dışında bir kez yapılır.
local function setClickable(p, on)
    if p.clickable ~= on and p.SetMouseClickEnabled then
        if pcall(p.SetMouseClickEnabled, p, on) then p.clickable = on end
    end
    if on and not p.passRight and p.SetPassThroughButtons and not (InCombatLockdown and InCombatLockdown()) then
        if pcall(p.SetPassThroughButtons, p, "RightButton") then p.passRight = true end
    end
end

local function acquirePin(parent, kind, dot, elite)
    local p = table.remove(pool)
    if not p then
        p = CreateFrame("Button", nil, parent)
        p.ring = p:CreateTexture(nil, "ARTWORK")      -- nokta görünümünün koyu çerçevesi
        p.ring:SetAllPoints()
        p.ring:Hide()
        p.tex = p:CreateTexture(nil, "OVERLAY")
        p.tex:SetAllPoints()
        p:EnableMouse(true)
        p.clickable = true                            -- düğmeler tıklanabilir doğar
        if p.RegisterForClicks then pcall(p.RegisterForClicks, p, "LeftButtonUp") end
        p:SetScript("OnEnter", function(self)
            hovered = self
            self.retried = nil
            local ok, err = pcall(showTooltip, self)
            if not ok then HM:LogError("pin ipucu", err) end
        end)
        p:SetScript("OnLeave", function(self)
            if hovered == self then hovered = nil end
            GameTooltip:Hide()
        end)
        p:SetScript("OnClick", function(self)
            if self.kind ~= "R" or not self.rareID then return end
            local ok, err = pcall(Pins.ToggleCard, Pins, self.rareID, self.px, self.py, self)
            if not ok then HM:LogError("rare kartı", err) end
        end)
    end
    p:SetParent(parent)
    p.kind = kind
    setClickable(p, kind == "R")
    p.tex:ClearAllPoints()
    if dot and DOT_COLOR[kind] then
        local c = DOT_COLOR[kind]
        if HM.ResolveIcon({ DOT_TEX }) == "file" then
            p.ring:SetTexture(DOT_TEX)
            p.ring:SetVertexColor(0, 0, 0, 0.85)
            p.ring:Show()
            p.tex:SetTexture(DOT_TEX)
            if p.tex.SetTexCoord then p.tex:SetTexCoord(0, 1, 0, 1) end
            p.tex:SetVertexColor(c[1], c[2], c[3], 1)
            p.tex:SetPoint("TOPLEFT", 1, -1)
            p.tex:SetPoint("BOTTOMRIGHT", -1, 1)
        else
            -- daire dokusu bu istemcide yoksa düz renkli küçük kare
            p.ring:Hide()
            p.tex:SetAllPoints()
            p.tex:SetVertexColor(1, 1, 1, 1)
            if p.tex.SetColorTexture then p.tex:SetColorTexture(c[1], c[2], c[3], 0.95) end
        end
        p.dot = true
        local ds = DOT_SIZE[(HM.db and HM.db.pinScale) or 1] or DOT_SIZE[1]
        p:SetSize(ds, ds)
    else
        p.ring:Hide()
        p.tex:SetAllPoints()
        p.tex:SetVertexColor(1, 1, 1, 1)
        local resolved = HM.ApplyIcon(p.tex, (elite and kind == "R") and ICONS.RE or ICONS[kind] or ICONS.F)
        p.dot = nil
        local s = pinSize(kind, resolved)
        p:SetSize(s, s)
    end
    p:Show()
    return p
end

local function releaseAll()
    for i = #active, 1, -1 do
        local p = active[i]
        p:Hide()
        p:ClearAllPoints()
        p.title, p.subtitle, p.note, p.rareID, p.px, p.py, p.kind = nil, nil, nil, nil, nil, nil, nil
        pool[#pool + 1] = p
        active[i] = nil
    end
    hovered = nil
end

local function currentMapID()
    if WorldMapFrame and WorldMapFrame.GetMapID then
        local ok, id = pcall(WorldMapFrame.GetMapID, WorldMapFrame)
        if ok and type(id) == "number" then return id end
    end
    return nil
end

local function mapCanvas()
    if WorldMapFrame and WorldMapFrame.ScrollContainer and WorldMapFrame.ScrollContainer.Child then
        return WorldMapFrame.ScrollContainer.Child
    end
    return WorldMapFrame
end

-- Rotadan bu haritadaki tüm F (uçuş) adımları.
local function flightsFor(mapID)
    local route = ns.Route or {}
    local list, seen = {}, {}
    for _, step in ipairs(route) do
        if step.k == "F" and step.m == mapID and step.x and step.y then
            local key = string.format("%.1f_%.1f", step.x, step.y)
            if not seen[key] then
                seen[key] = true
                list[#list + 1] = { x = step.x, y = step.y, t = step.t or "Uçuş noktası" }
            end
        end
    end
    return list
end

---------------------------------------------------------------------------
-- Yerleştirme: Blizzard'ın kendi harita pinleriyle aynı yöntem
-- (MapCanvasMixin:ApplyPinPosition, MapCanvasPinMixin:ApplyCurrentScale / ApplyFrameLevel).
--
--  * Çerçeve düzeyi: haritanın bütün pinleri 2000'den başlayan mutlak düzeylerde durur;
--    keşfedilmiş bölge kaplaması da bunlardan biridir. Bizim pinler bunun ALTINDA kalırsa
--    keşfedilmiş bölgelerde kaplamanın arkasında kalıp görünmez. Düzey, haritanın kendi
--    düzey yöneticisinden alınır (vignette bandı: rare/hazine simgelerinin durduğu yer).
--  * Ölçek: tuval (harita resmi) yakınlaştırmaya göre ölçeklenir. Pin ölçeği 1/tuval ölçeği
--    yapılır; böylece simge her yakınlaştırmada ekranda aynı boyda kalır.
--  * Konum: (tuval boyu x oran) / pin ölçeği.
---------------------------------------------------------------------------
local FALLBACK_LEVEL = 2100

local function pinBaseLevel()
    if WorldMapFrame and WorldMapFrame.GetPinFrameLevelsManager then
        local ok, mgr = pcall(WorldMapFrame.GetPinFrameLevelsManager, WorldMapFrame)
        if ok and type(mgr) == "table" and mgr.GetValidFrameLevel then
            local defs = type(mgr.definitions) == "table" and mgr.definitions or {}
            for _, kind in ipairs({ "PIN_FRAME_LEVEL_VIGNETTE", "PIN_FRAME_LEVEL_AREA_POI", "PIN_FRAME_LEVEL_TOPMOST" }) do
                if kind == "PIN_FRAME_LEVEL_TOPMOST" or defs[kind] then
                    local ok2, lvl = pcall(mgr.GetValidFrameLevel, mgr, kind, 1)
                    if ok2 and type(lvl) == "number" and lvl > 0 then return lvl, kind end
                end
            end
        end
    end
    return FALLBACK_LEVEL, "yedek"
end

local function canvasScale(canvas)
    if WorldMapFrame and WorldMapFrame.GetCanvasScale then
        local ok, sc = pcall(WorldMapFrame.GetCanvasScale, WorldMapFrame)
        if ok and type(sc) == "number" and sc > 0.001 then return sc end
    end
    if canvas and canvas.GetScale then
        local sc = canvas:GetScale()
        if type(sc) == "number" and sc > 0.001 then return sc end
    end
    return 1
end

-- ctx = { canvas, w, h, cs (tuval ölçeği), base (çerçeve düzeyi) }
local function position(p, ctx)
    local ps = 1 / ctx.cs
    if p.SetScale then p:SetScale(ps) end
    if p.SetFrameLevel then p:SetFrameLevel(ctx.base + (LEVEL[p.kind] or 5)) end
    p:ClearAllPoints()
    p:SetPoint("CENTER", ctx.canvas, "TOPLEFT", ((p.px / 100) * ctx.w) / ps, -((p.py / 100) * ctx.h) / ps)
end

local function context()
    local canvas = mapCanvas()
    if not canvas then return nil end
    local w, h = canvas:GetSize()
    if type(w) ~= "number" or type(h) ~= "number" or w < 1 or h < 1 then return nil end
    local base, levelKind = pinBaseLevel()
    return { canvas = canvas, w = w, h = h, cs = canvasScale(canvas), base = base, levelKind = levelKind }
end

local function place(ctx, kind, x, y, dot, elite)
    local p = acquirePin(ctx.canvas, kind, dot, elite)
    p.px, p.py = x, y
    position(p, ctx)
    active[#active + 1] = p
    return p
end

-- Yakınlaştırma / pencere boyu değişti: çizili pinleri yeniden ölçekle ve yerleştir.
function Pins:Rescale()
    if #active == 0 then return end
    local ctx = context()
    if not ctx then return end
    self.lastCtx = ctx
    for _, p in ipairs(active) do
        if p.px and p.py then position(p, ctx) end
    end
end

-- Haritada çizilen pin sayıları (menü/sayaç ve test için).
Pins.lastCount = { F = 0, R = 0, C = 0, H = 0, M = 0 }

function Pins:Draw()
    releaseAll()
    local count = { F = 0, R = 0, C = 0, H = 0, M = 0 }
    self.lastCount = count
    local db = HM.db
    if not db or db.pinsOff then return end
    if not WorldMapFrame or not WorldMapFrame:IsShown() then return end
    local mapID = currentMapID()
    if not mapID then return end
    local ctx = context()
    if not ctx then return end
    self.lastCtx = ctx
    local D = HM.PinsData

    -- H / M: en altta kalsınlar diye önce. Görünüm: 0 = çizme, 1 = küçük nokta, 2 = simge
    local gmode = (HM.Gather and HM.Gather.MapMode) and HM.Gather:MapMode() or 2
    self.lastGatherMode = gmode
    if HM.Gather and gmode ~= 0 then
        local dot = (gmode == 1)
        if not db.gatherHerbOff then
            for _, n in ipairs(HM.Gather:NodesFor(mapID, "herb", true)) do
                local p = place(ctx, "H", n.x, n.y, dot)
                p.title = n.n
                p.subtitle = string.format("Ot noktası · gereken beceri %d", n.skill or 1)
                count.H = count.H + 1
            end
        end
        if not db.gatherOreOff then
            for _, n in ipairs(HM.Gather:NodesFor(mapID, "ore", true)) do
                local p = place(ctx, "M", n.x, n.y, dot)
                p.title = n.n
                p.subtitle = string.format("Maden noktası · gereken beceri %d", n.skill or 1)
                count.M = count.M + 1
            end
        end
    end

    -- C: hazine sandıkları
    if not db.pinsChestOff and D and D.chests and D.chests[mapID] then
        local list, names = D.chests[mapID], D.chestNames or {}
        for i = 1, #list, 3 do
            local p = place(ctx, "C", list[i + 1], list[i + 2])
            p.title = names[list[i]] or "Sandık"
            p.subtitle = string.format("Hazine sandığı noktası (%.1f, %.1f)", list[i + 1], list[i + 2])
            p.note = "Sandık her zaman burada olmaz; bu noktalardan birinde çıkar."
            count.C = count.C + 1
        end
    end

    -- F: uçuş noktaları
    if not db.pinsFpOff then
        for _, fp in ipairs(flightsFor(mapID)) do
            local p = place(ctx, "F", fp.x, fp.y)
            p.title = fp.t
            p.subtitle = string.format("Uçuş noktası (%.1f, %.1f)", fp.x, fp.y)
            count.F = count.F + 1
        end
    end

    -- R: rare moblar
    if not db.pinsRareOff and D and D.spots and D.spots[mapID] then
        local list = D.spots[mapID]
        for i = 1, #list, 3 do
            local r = D.rares[list[i]]
            if r then
                local p = place(ctx, "R", list[i + 1], list[i + 2], false, r[4] == 1)
                p.title = r[1]
                p.rareID = list[i]
                count.R = count.R + 1
            end
        end
    end
end

function Pins:Refresh()
    local ok, err = pcall(self.Draw, self)
    if not ok then HM:LogError("pin çizimi", err) end
end

---------------------------------------------------------------------------
-- Rare kartı: pine tıklayınca açılır. İpucundaki bilgilerin aynısı, ama eşya
-- satırları canlıdır:
--   üstüne gel   -> eşyanın kendi ipucu (özellikler; Shift basılıysa kuşandığınla karşılaştırma)
--   tıkla        -> eşya ipucu ekranda sabitlenir (sohbetteki bağlantıya tıklamak gibi)
--   Shift + tıkla -> bağlantıyı sohbete yazar, Ctrl + tıkla -> giyinme odası
-- Kart sürüklenebilir; aynı pine ikinci tık, çarpı ya da haritayı kapatmak kartı kapatır.
---------------------------------------------------------------------------
local card
local CARD_W, CARD_PAD, CARD_ROW = 290, 10, 18
local CARD_FONT = "Fonts\\ARIALN.TTF"

local function cardFont(fs, size, flags)
    pcall(fs.SetFont, fs, CARD_FONT, size, flags or "")
    if not fs:GetFont() and fs.SetFontObject and GameFontHighlightSmall then fs:SetFontObject(GameFontHighlightSmall) end
end

local function rowEnter(self)
    if not self.itemID then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    local ok = GameTooltip.SetItemByID and pcall(GameTooltip.SetItemByID, GameTooltip, self.itemID)
    if not ok and GameTooltip.SetHyperlink then
        ok = pcall(GameTooltip.SetHyperlink, GameTooltip, "item:" .. tostring(self.itemID))
    end
    if not ok then
        GameTooltip:SetText(HM:T("Eşya bilgisi okunamadı (#" .. tostring(self.itemID) .. ")"), 1, 0.5, 0.5)
    end
    GameTooltip:Show()
    if IsShiftKeyDown and IsShiftKeyDown() and GameTooltip_ShowCompareItem then
        pcall(GameTooltip_ShowCompareItem, GameTooltip)
    end
end

local function rowLeave() GameTooltip:Hide() end

local function rowClick(self)
    if not self.itemID then return end
    local link = Pins.ItemLink(self.itemID, self.q)
    -- Shift (sohbete yaz) / Ctrl (giyinme odası): oyunun kendi işleyicisi
    if IsModifiedClick and IsModifiedClick() and HandleModifiedItemClick then
        local ok, err = pcall(HandleModifiedItemClick, link)
        if not ok then HM:LogError("rare kartı: eşya bağlantısı", err) end
        return
    end
    if SetItemRef then
        local ok, err = pcall(SetItemRef, "item:" .. tostring(self.itemID), link, "LeftButton")
        if not ok then HM:LogError("rare kartı: eşya ipucu", err) end
    end
end

local function cardRow(i)
    local r = card.rows[i]
    if r then return r end
    r = CreateFrame("Button", nil, card)
    r.left = r:CreateFontString(nil, "OVERLAY")
    cardFont(r.left, 12)
    r.left:SetJustifyH("LEFT")
    if r.left.SetJustifyV then r.left:SetJustifyV("TOP") end
    r.right = r:CreateFontString(nil, "OVERLAY")
    cardFont(r.right, 11)
    r.right:SetJustifyH("RIGHT")
    r.right:SetPoint("RIGHT", -3, 0)
    r.hl = r:CreateTexture(nil, "HIGHLIGHT")
    r.hl:SetAllPoints()
    r.hl:SetColorTexture(1, 1, 1, 0.10)
    r:SetScript("OnEnter", rowEnter)
    r:SetScript("OnLeave", rowLeave)
    r:SetScript("OnClick", rowClick)
    card.rows[i] = r
    return r
end

local function cardCreate()
    if card then return card end
    local parent = WorldMapFrame or UIParent
    card = CreateFrame("Frame", "HizliMageRareCard", parent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    -- haritanın ve pinlerinin (çerçeve düzeyi 2000+) üstünde, ipuçlarının altında
    card:SetFrameStrata("FULLSCREEN_DIALOG")
    if card.SetFrameLevel then card:SetFrameLevel(6000) end
    card:SetClampedToScreen(true)
    card:EnableMouse(true)
    card:SetMovable(true)
    card:RegisterForDrag("LeftButton")
    card:SetScript("OnDragStart", function(self) self:StartMoving() end)
    card:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    if card.SetBackdrop then
        card:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 14,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        card:SetBackdropColor(0.05, 0.06, 0.1, 0.96)
        card:SetBackdropBorderColor(0.75, 0.75, 1, 0.9)
    end
    card.title = card:CreateFontString(nil, "OVERLAY")
    cardFont(card.title, 14, "OUTLINE")
    card.title:SetPoint("TOPLEFT", CARD_PAD, -10)
    card.title:SetPoint("RIGHT", card, "RIGHT", -26, 0)
    card.title:SetJustifyH("LEFT")
    card.title:SetTextColor(1, 0.82, 0)
    card.close = CreateFrame("Button", nil, card, "UIPanelCloseButton")
    card.close:SetSize(22, 22)
    card.close:SetPoint("TOPRIGHT", 0, 0)
    card.close:SetScript("OnClick", function() card:Hide() end)
    -- Kapatma düğmesi şablonu kendi sabit çerçeve düzeyiyle gelir (oyunda 510 ölçüldü);
    -- kart 6000'de olduğu için düğme kartın ALTINDA kalıp tıklanamıyordu.
    if card.close.SetFrameLevel and card.GetFrameLevel then card.close:SetFrameLevel((card:GetFrameLevel() or 6000) + 10) end
    card.hint = card:CreateFontString(nil, "OVERLAY")
    cardFont(card.hint, 10)
    card.hint:SetTextColor(0.55, 0.55, 0.55)
    card.hint:SetJustifyH("LEFT")
    card.hint:SetPoint("BOTTOMLEFT", CARD_PAD, 8)
    card.hint:SetWidth(CARD_W - 2 * CARD_PAD)
    card.rows = {}
    card:SetScript("OnHide", function(self)
        self.rareID = nil
        GameTooltip:Hide()
    end)
    card:Hide()
    return card
end

-- Kartı açık olan rare (yoksa nil).
function Pins.CardRare()
    if card and card:IsShown() then return card.rareID end
    return nil
end

function Pins:HideCard()
    if card and card:IsShown() then card:Hide() end
end

function Pins:RenderCard()
    local f = card
    if not (f and f.rareID) then return end
    local D = HM.PinsData
    local r = D and D.rares and D.rares[f.rareID]
    if not r then f:Hide() return end
    f.title:SetText(HM:T(r[1]))
    local lines, pending = self:RareLines(f.rareID, f.px, f.py)
    local rowW = CARD_W - 2 * CARD_PAD
    local y, n, items = -32, 0, 0
    for _, l in ipairs(lines or {}) do
        if l[1] == " " then
            y = y - 6
        else
            n = n + 1
            local row = cardRow(n)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", f, "TOPLEFT", CARD_PAD, y)
            row:SetSize(rowW, CARD_ROW)
            row.itemID, row.q = l.item, l.q
            row.left:SetText(HM:T(l[1]))
            row.left:SetTextColor(l[3] or 1, l[4] or 1, l[5] or 1)
            row.right:SetText(l[2] and HM:T(l[2]) or "")
            row.right:SetTextColor(l[6] or 1, l[7] or 1, l[8] or 1)
            row.left:ClearAllPoints()
            local h = CARD_ROW
            if l.item or l[2] then
                -- tek satır: ad solda, yüzde / not sağda
                row.left:SetPoint("LEFT", 3, 0)
                row.left:SetPoint("RIGHT", row.right, "LEFT", -6, 0)
                if row.left.SetWordWrap then row.left:SetWordWrap(false) end
            else
                -- uzun açıklama: satır kır, yüksekliği metne göre ayarla
                row.left:SetPoint("TOPLEFT", 3, -2)
                row.left:SetWidth(rowW - 6)
                if row.left.SetWordWrap then row.left:SetWordWrap(true) end
                local sh = row.left:GetStringHeight()
                if type(sh) == "number" and sh + 4 > h then h = sh + 4 end
                row:SetHeight(h)
            end
            row:EnableMouse(l.item and true or false)
            if l.item then items = items + 1 end
            row:Show()
            y = y - h
        end
    end
    for i = n + 1, #f.rows do
        f.rows[i]:Hide()
        f.rows[i].itemID = nil
    end
    f.nRows, f.nItems = n, items
    local bottom = 10
    if items > 0 then
        f.hint:SetText(HM:T("Eşyanın üstüne gel: özellikleri. Tıkla: ipucunu sabitle. Shift+tıkla: sohbete yaz."))
        f.hint:Show()
        local hh = f.hint:GetStringHeight()
        bottom = 14 + ((type(hh) == "number" and hh > 0) and hh or 12)
    else
        f.hint:Hide()
    end
    f:SetSize(CARD_W, -y + bottom)
    -- İstemci eşya bilgisini sonradan getirir: kart açıkken birkaç kez yenile.
    if pending and (f.tries or 0) < 4 then
        f.tries = (f.tries or 0) + 1
        local id = f.rareID
        HM:After(0.7, function()
            if card and card:IsShown() and card.rareID == id then Pins:RenderCard() end
        end, "rare kartı")
    end
end

-- anchor: tıklanan pin (kart onun yanında açılır); yoksa ekranın ortası.
function Pins:ShowCard(id, x, y, anchor)
    local f = cardCreate()
    f.rareID, f.px, f.py, f.tries = id, x, y, 0
    self:RenderCard()
    if not f.rareID then return end
    f:ClearAllPoints()
    local placed = false
    if anchor and anchor.GetCenter and anchor.GetEffectiveScale and f.GetEffectiveScale then
        local cx, cy = anchor:GetCenter()
        local es, fs = anchor:GetEffectiveScale(), f:GetEffectiveScale()
        if type(cx) == "number" and type(cy) == "number" and type(es) == "number" and type(fs) == "number" and fs > 0 then
            -- pinin ekrandaki yeri (kart ölçeğinde); ekranın sağ yarısındaysa kart sola açılır
            local px, py = cx * es / fs, cy * es / fs
            local uw, ues = UIParent and UIParent:GetWidth(), UIParent and UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()
            local sw = (type(uw) == "number" and type(ues) == "number") and (uw * ues / fs) or nil
            if type(sw) == "number" and px > sw * 0.6 then
                f:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", px - 14, py + 14)
            else
                f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", px + 14, py + 14)
            end
            placed = true
        end
    end
    if not placed then f:SetPoint("CENTER", UIParent, "CENTER", 0, 0) end
    GameTooltip:Hide()
    f:Show()
end

-- Aynı rare'in kartı açıksa kapatır, değilse açar.
function Pins:ToggleCard(id, x, y, anchor)
    if card and card:IsShown() and card.rareID == id then
        card:Hide()
        return false
    end
    self:ShowCard(id, x, y, anchor)
    return true
end

---------------------------------------------------------------------------
-- Aç / kapat
---------------------------------------------------------------------------
local LABEL = { pinsOff = "Harita pinleri", pinsFpOff = "Uçuş pinleri", pinsRareOff = "Rare pinleri", pinsChestOff = "Sandık pinleri" }

-- key: pinsOff / pinsFpOff / pinsRareOff / pinsChestOff; on = true ise görünür.
function Pins:Set(key, on, quiet)
    if not LABEL[key] then return end
    HM.db[key] = not on
    if not quiet then
        HM:Print(LABEL[key] .. ": " .. (on and "|cff80ff80açık|r" or "|cffff6060kapalı|r"))
    end
    self:Refresh()
end

-- Pin boyutu: 1 = küçük (varsayılan), 2 = orta, 3 = büyük. Rare, sandık, uçuş ve ot/maden
-- pinlerinin hepsini birlikte ölçekler (minimap'tekiler dahil).
local SCALE_NAME = { "küçük", "orta", "büyük" }
local SCALE_WORD = { kucuk = 1, ["küçük"] = 1, ["1"] = 1, orta = 2, normal = 2, ["2"] = 2, buyuk = 3, ["büyük"] = 3, ["3"] = 3 }

function Pins:PinScale()
    local v = HM.db and HM.db.pinScale
    if v == 2 or v == 3 then return v end
    return 1
end

function Pins:SetPinScale(v, quiet)
    if type(v) == "string" then v = SCALE_WORD[v:lower():match("^%s*(.-)%s*$")] end
    if v ~= 1 and v ~= 2 and v ~= 3 then
        if not quiet then
            HM:Print("Pin boyutu: " .. SCALE_NAME[self:PinScale()] .. ". Değiştirmek için |cffffd100/hm pin boyut kucuk|r (ya da |cffffd100orta|r / |cffffd100buyuk|r).")
        end
        return false
    end
    HM.db.pinScale = v
    if not quiet then HM:Print("Pin boyutu: |cff80ff80" .. SCALE_NAME[v] .. "|r") end
    if HM.Gather and HM.Gather.MM then HM.Gather.MM.dirty = true; HM.Gather.MM.skinGen = (HM.Gather.MM.skinGen or 0) + 1 end
    self:Refresh()
    return true
end

function Pins:Toggle()      self:Set("pinsOff", HM.db.pinsOff and true or false) end
function Pins:ToggleFp()    self:Set("pinsFpOff", HM.db.pinsFpOff and true or false) end
function Pins:ToggleRare()  self:Set("pinsRareOff", HM.db.pinsRareOff and true or false) end
function Pins:ToggleChest() self:Set("pinsChestOff", HM.db.pinsChestOff and true or false) end

function Pins:AllOn()
    local db = HM.db
    db.pinsOff, db.pinsFpOff, db.pinsRareOff, db.pinsChestOff = false, false, false, false
    HM:Print("Uçuş, rare ve sandık pinleri |cff80ff80açık|r.")
    self:Refresh()
end

-- /hm pin durum: bulunduğun (ya da haritada açık olan) bölgede ne var?
function Pins:Status()
    local mid = currentMapID()
    if not (WorldMapFrame and WorldMapFrame:IsShown()) or not mid then
        mid = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player") or nil
    end
    if not mid or HM.IsSecret(mid) then HM:Print("Bölge okunamadı.") return end
    local D = HM.PinsData
    local nR = (D and D.spots and D.spots[mid]) and (#D.spots[mid] / 3) or 0
    local nC = (D and D.chests and D.chests[mid]) and (#D.chests[mid] / 3) or 0
    local nF = #flightsFor(mid)
    local nH = HM.Gather and #HM.Gather:NodesFor(mid, "herb", true) or 0
    local nM = HM.Gather and #HM.Gather:NodesFor(mid, "ore", true) or 0
    HM:Print(string.format("%s (harita %d): |cffc0c0ff%d rare noktası|r, |cffffd080%d sandık noktası|r, %d uçuş, |cff80ff80%d ot|r, |cffcc8844%d maden|r.",
        HM:MapName(mid), mid, nR, nC, nF, nH, nM))
    if D and D.stats then
        local DD = Pins.DropData()
        local st = DD and DD.stats or {}
        if DD then
            HM:Print(string.format("Veritabanı: %d rare, %d sandık noktası. Düşen eşya: %d rare Wowhead Forever (yüzdeli), %d rare QuestieDB/klasik veri (yüzdesiz), %d rare için özel kayıt yok.",
                D.stats.rares or 0, D.stats.chestSpots or 0, st.wowhead or 0, st.other or 0,
                math.max(0, (D.stats.rares or 0) - (st.wowhead or 0) - (st.other or 0))))
        else
            HM:Print(string.format("Veritabanı: %d rare, %d sandık noktası. |cffff8080Düşen eşya verisi yüklü değil|r: eklenti listesinde \"Hizli Mage - Veri\" işaretli olmalı.",
                D.stats.rares or 0, D.stats.chestSpots or 0))
        end
    end
    -- Yerleşim bilgisi (harita açıkken): pin görünmüyorsa bakılacak sayılar
    local c = self.lastCtx
    if c and WorldMapFrame and WorldMapFrame:IsShown() then
        local lc = self.lastCount or {}
        HM:Print(string.format("Haritada çizili: %d rare, %d sandık, %d uçuş, %d ot, %d maden. Tuval %.0fx%.0f, ölçek %.2f, pin düzeyi %d (%s).",
            lc.R or 0, lc.C or 0, lc.F or 0, lc.H or 0, lc.M or 0, c.w, c.h, c.cs, c.base, tostring(c.levelKind)))
    end
    -- Minimap pinleri (ot/maden)
    local MM = HM.Gather and HM.Gather.MM
    if MM and HM.Gather.MiniMode and HM.Gather:MiniMode() ~= 0 then
        if MM.radius then
            HM:Print(string.format("Minimap: %d ot/maden noktası gösteriliyor (çevrede %d aday, görüş ~%d yd, biçim %s).",
                MM.shown or 0, MM.n or 0, math.floor(MM.radius + 0.5), tostring(MM.shape or "?")))
        else
            HM:Print("Minimap: ot/maden gösterimi açık; şu an çizilecek nokta yok ya da konum okunamıyor.")
        end
        if (MM.errors or 0) > 0 then
            HM:Print("|cffff8080Minimap pinleri hata verdi|r; ayrıntı için /hm hata.")
        end
    end
    if HM.ResolveIcon({ DOT_TEX }) ~= "file" then
        HM:Print("|cffff8080Nokta dokusu doğrulanamadı|r: ot/maden noktaları küçük kare olarak çizilir.")
    end
    -- Simge dokuları bu istemcide bulundu mu? (pin görünmüyorsa ilk bakılacak yer)
    local missing = {}
    local NAMES = { F = "uçuş", R = "rare", C = "sandık", H = "ot", M = "maden" }
    for _, k in ipairs({ "F", "R", "C", "H", "M" }) do
        local kind = HM.ResolveIcon(ICONS[k])
        if kind ~= "atlas" and kind ~= "file" then missing[#missing + 1] = NAMES[k] end
    end
    if #missing > 0 then
        HM:Print("|cffff8080Simge dokusu doğrulanamadı:|r " .. table.concat(missing, ", ") .. ". Bu pinler görünmüyorsa /hm hata çıktısıyla birlikte bildir.")
    end
end
Pins.ShowMapID = Pins.Status   -- eski komut adı (/hm pin mapid)

---------------------------------------------------------------------------
-- Rare takibi: gördüğünü kaydet, haber ver
---------------------------------------------------------------------------
local alerted = {}   -- npcID -> GetTime()
local ALERT_EVERY = 300

function Pins:RareSummary(id)
    local D = HM.PinsData
    local r = D and D.rares and D.rares[id]
    if not r then return nil end
    local lvl = (r[2] == r[3]) and tostring(r[2]) or (r[2] .. "–" .. r[3])
    local s = string.format("|cffc0c0ffRARE:|r %s (%s%s)", r[1], lvl, (r[4] == 1) and " elit" or "")
    local _, drops = Pins.DropsFor(id)
    if drops and #drops >= 3 then
        local parts = {}
        for i = 1, math.min(#drops, 9), 3 do
            local label = Pins.ItemChat(drops[i], drops[i + 1])
            if (drops[i + 2] or 0) > 0 then label = label .. " " .. pctText(drops[i + 2]) end
            parts[#parts + 1] = label
        end
        s = s .. " — " .. table.concat(parts, ", ")
    end
    return s
end

function Pins:NoteUnit(unit)
    if not (unit and UnitExists and UnitExists(unit)) then return end
    local D = HM.PinsData
    if not (D and D.rares) then return end
    local guid = UnitGUID and UnitGUID(unit)
    local id = HM.NpcIdFromGUID(guid)
    local r = id and D.rares[id]
    if not r then return end
    local db = HM.db
    if type(db.rareSeen) ~= "table" then db.rareSeen = {} end
    local rec = db.rareSeen[id]
    if not rec then rec = {}; db.rareSeen[id] = rec end
    local now = (time and time()) or 0
    local dead = UnitIsDead and UnitIsDead(unit)
    if HM.IsSecret(dead) then return end
    if dead then
        -- ilk ölü görüş (ya da önceki kayıttan sonra yeniden canlı görülmüşse) ölüm zamanı sayılır
        if not rec.k or (rec.t and rec.t > rec.k) or (now - rec.k) > 1800 then rec.k = now end
        return
    end
    rec.t = now
    if db.rareAlertOff or HM.inInstance then return end
    local gt = GetTime()
    if alerted[id] and (gt - alerted[id]) < ALERT_EVERY then return end
    alerted[id] = gt
    if PlaySound then pcall(PlaySound, (SOUNDKIT and SOUNDKIT.RAID_WARNING) or 8959) end
    HM:Print(self:RareSummary(id) or ("|cffc0c0ffRARE:|r " .. tostring(r[1])))
end

function Pins:SetRareAlert(on, quiet)
    HM.db.rareAlertOff = not on
    if not quiet then
        HM:Print("Rare görünce haber ver: " .. (on and "|cff80ff80açık|r" or "|cffff6060kapalı|r"))
    end
end

---------------------------------------------------------------------------
-- Giriş
---------------------------------------------------------------------------
HM:OnLogin(function()
    local db = HM.db
    db.pinsOff = db.pinsOff == true
    db.pinsFpOff = db.pinsFpOff == true
    db.pinsRareOff = db.pinsRareOff == true
    db.pinsChestOff = db.pinsChestOff == true
    db.rareAlertOff = db.rareAlertOff == true
    if type(db.rareSeen) ~= "table" then db.rareSeen = {} end
    if db.pinScale ~= 2 and db.pinScale ~= 3 then db.pinScale = 1 end

    if WorldMapFrame and WorldMapFrame.HookScript then
        WorldMapFrame:HookScript("OnShow", function() HM:After(0, function() Pins:Draw() end, "pin çizimi") end)
        WorldMapFrame:HookScript("OnHide", function() releaseAll(); Pins:HideCard() end)
        if hooksecurefunc then
            if WorldMapFrame.OnMapChanged then
                hooksecurefunc(WorldMapFrame, "OnMapChanged", function() Pins:HideCard(); Pins:Refresh() end)
            end
            local function rescale()
                local ok, err = pcall(Pins.Rescale, Pins)
                if not ok then HM:LogError("pin ölçeği", err) end
            end
            if WorldMapFrame.OnCanvasScaleChanged then hooksecurefunc(WorldMapFrame, "OnCanvasScaleChanged", rescale) end
            if WorldMapFrame.OnCanvasSizeChanged then hooksecurefunc(WorldMapFrame, "OnCanvasSizeChanged", rescale) end
        end
    end

    HM:On("PLAYER_TARGET_CHANGED", function() Pins:NoteUnit("target") end)
    HM:On("UPDATE_MOUSEOVER_UNIT", function() Pins:NoteUnit("mouseover") end)
    HM:On("NAME_PLATE_UNIT_ADDED", function(_, unit) Pins:NoteUnit(unit) end)
end)
