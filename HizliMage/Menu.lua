---------------------------------------------------------------------------
-- Menu.lua: tek tıkla aç/kapat menüsü. Komut ezberlemek gerekmesin diye
-- sık kullanılan ayarların hepsi burada; rehber penceresindeki "Menü"
-- düğmesi, başlıktaki çark ya da /hm menu ile açılır, Esc ile kapanır.
--
-- Satır türleri:
--   toggle : tıkla -> aç/kapat (yeşil tik / kırmızı çarpı)
--   choice : küçük düğmelerden birini seç (ör. yaklaşınca haber mesafesi)
--   action : tıkla -> bir iş yap (rapor, pencere aç)
---------------------------------------------------------------------------
local _, ns = ...
local HM = ns.HM
if not HM then return end

local Menu = {}
HM.Menu = Menu

local FONT = "Fonts\\ARIALN.TTF"
local ROW_H, COL_W, PAD = 20, 260, 12
-- Simge: { bu istemcinin atlas adı, yedek dosya yolu }. Durum ayrıca satırın sağında
-- "Açık / Kapalı" diye yazılır; doku yüklenmese de ne olduğu okunur.
local ICON = {
    on  = { "atlas:UI-LFG-ReadyMark",   "Interface\\RaidFrame\\ReadyCheck-Ready" },
    off = { "atlas:UI-LFG-DeclineMark", "Interface\\RaidFrame\\ReadyCheck-NotReady" },
    na  = { "atlas:UI-LFG-PendingMark", "Interface\\RaidFrame\\ReadyCheck-Waiting" },
    go  = { "Interface\\ChatFrame\\ChatFrameExpandArrow" },
}
local function setIcon(tex, key)
    HM.ApplyIcon(tex, ICON[key])
end

local frame
local rows = {}

local function Font(fs, size, flags)
    pcall(fs.SetFont, fs, FONT, size, flags or "")
    if not fs:GetFont() and fs.SetFontObject and GameFontHighlightSmall then fs:SetFontObject(GameFontHighlightSmall) end
end

---------------------------------------------------------------------------
-- Dinlenme (zzz) göstergesi: EllesmereUI oyuncu çerçevesinin "Rested Indicator"
-- seçeneği. Blizzard çerçevesi bunu kendisi gösterir; EllesmereUI'da varsayılan kapalıdır.
---------------------------------------------------------------------------
local restPending = false

local function restApply()
    local pf = _G.EllesmereUIUnitFrames_Player
    if pf and type(pf._restUpdate) == "function" then
        if InCombatLockdown and InCombatLockdown() then
            restPending = true
            return
        end
        local ok, err = pcall(pf._restUpdate)
        if not ok then HM:LogError("zzz göstergesi", err) end
    end
end

-- true / false; EllesmereUI yoksa nil
function Menu:RestedState()
    if type(EllesmereUIDB) ~= "table" then return nil end
    return EllesmereUIDB.showRestedIndicator == true
end

-- on = nil ise tersine çevirir
function Menu:SetRested(on, verbose)
    if type(EllesmereUIDB) ~= "table" then
        if verbose then
            HM:Print("EllesmereUI yüklü değil: Blizzard'ın oyuncu çerçevesi dinlenirken zzz simgesini kendisi gösterir.")
        end
        return false
    end
    if on == nil then on = not (EllesmereUIDB.showRestedIndicator == true) end
    EllesmereUIDB.showRestedIndicator = on and true or false
    -- Animasyonlu zzz (portrenin üstünde, Forever'ın kendi görünümü); kullanıcı elle kapattıysa dokunma.
    if on and EllesmereUIDB.restedIndicatorAnimated == nil then EllesmereUIDB.restedIndicatorAnimated = true end
    restApply()
    if verbose then
        HM:Print("Dinlenme (zzz) göstergesi: " .. (on and "|cff80ff80açık|r — han ya da şehirde oyuncu çerçevende görünür." or "|cffff6060kapalı|r"))
    end
    return true
end

---------------------------------------------------------------------------
-- Menü içeriği
---------------------------------------------------------------------------
local function dbflag(key, inverse)
    return function()
        local v = HM.db[key]
        if inverse then return not v end
        return v and true or false
    end, function(on)
        if inverse then HM.db[key] = not on else HM.db[key] = on and true or false end
    end
end

local function sub(tbl, key, inverse)
    return function()
        local t = HM.db[tbl]
        if type(t) ~= "table" then return nil end
        if inverse then return not t[key] end
        return t[key] and true or false
    end, function(on)
        if type(HM.db[tbl]) ~= "table" then HM.db[tbl] = {} end
        if inverse then HM.db[tbl][key] = not on else HM.db[tbl][key] = on and true or false end
    end
end

local function toggle(label, tip, get, set)
    return { kind = "toggle", label = label, tip = tip, get = get, set = set }
end

local function build()
    local items = {}
    local function add(col, it) it.col = col; items[#items + 1] = it end
    local g, s

    -- 1. sütun -----------------------------------------------------------
    add(1, { kind = "header", label = "Harita pinleri" })
    add(1, toggle("Rare moblar", "Dünya haritasında rare mobların çıktığı noktalar. Üstüne gelince seviye, yaklaşık yeniden doğma süresi ve düşen eşyalar görünür.",
        function() return not HM.db.pinsRareOff end, function(on) if HM.Pins then HM.Pins:Set("pinsRareOff", on, true) end end))
    add(1, toggle("Hazine sandığı noktaları", "Sandıkların çıkabildiği noktalar. Sandık her zaman orada olmaz; bu noktalardan birinde çıkar.",
        function() return not HM.db.pinsChestOff end, function(on) if HM.Pins then HM.Pins:Set("pinsChestOff", on, true) end end))
    add(1, toggle("Uçuş noktaları", "Rotandaki uçuş noktaları.",
        function() return not HM.db.pinsFpOff end, function(on) if HM.Pins then HM.Pins:Set("pinsFpOff", on, true) end end))
    local herb = toggle("Ot noktaları", "Otların çıkabildiği noktalar (GatherMate2 verisi).",
        function() return not HM.db.gatherHerbOff end, function(on) if HM.Gather then HM.Gather:Set("herb", on, true) end end)
    herb.note = function()
        if HM.Gather and HM.Gather:NoProfession("herb") then
            return "meslek yok", "Bu karakterde Herbalism olmadığı için ot noktaları gizli. Yine de görmek için alttaki \"Yalnızca toplayabildiklerim\" satırını kapat."
        end
    end
    add(1, herb)
    local ore = toggle("Maden noktaları", "Madenlerin çıkabildiği noktalar (GatherMate2 verisi).",
        function() return not HM.db.gatherOreOff end, function(on) if HM.Gather then HM.Gather:Set("ore", on, true) end end)
    ore.note = function()
        if HM.Gather and HM.Gather:NoProfession("ore") then
            return "meslek yok", "Bu karakterde Mining olmadığı için maden noktaları gizli. Yine de görmek için alttaki \"Yalnızca toplayabildiklerim\" satırını kapat."
        end
    end
    add(1, ore)
    add(1, toggle("Yalnızca toplayabildiklerim", "Açıkken mesleğin ve becerin yetmeyen ot/maden noktaları gizlenir. Kapatırsan hepsi görünür.",
        function() return HM.db.gatherSkillOnly and true or false end, function(on) if HM.Gather then HM.Gather:SetSkillOnly(on, true) end end))

    add(1, { kind = "header", label = "Haber ve uyarılar" })
    add(1, { kind = "choice", label = "Yakında haber", tip = "Bir ot ya da maden noktasına bu kadar yarda yaklaşınca sohbete tek satır düşer ve kısa bir ses çalar. \"Yok\" kapatır.",
        choices = { { "Yok", 0 }, { "40", 40 }, { "60", 60 }, { "80", 80 } },
        get = function() return HM.db.gatherRange or 0 end,
        set = function(v) if HM.Gather then HM.Gather:SetRange(v, true) end end })
    add(1, toggle("Rare görünce haber ver", "Bir rare'i hedef aldığında, fareyle üstüne geldiğinde ya da isim plakası göründüğünde adını ve düşen eşyalarını yazar.",
        function() return not HM.db.rareAlertOff end, function(on) if HM.Pins then HM.Pins:SetRareAlert(on, true) end end))
    add(1, toggle("Mob seviye uyarısı", "Hedef aldığın düşman XP vermeyecek kadar düşükse (gri) ya da tehlikeli derecede yüksekse (turuncu/kırmızı/kafatası) yazar.",
        function() return not HM.db.mobColorOff end, function(on) if HM.MobColor then HM.MobColor:Set(on, true) end end))
    g, s = sub("alerts", "enabled")
    add(1, toggle("Zindan uyarıları", "Kesilecek büyü (KES), çözülecek lanet/zehir (ÇÖZ), çalınacak buff (ÇAL) ve patron notları.", g, s))
    add(1, toggle("Proc göstergesi", "Fingers of Frost, Clearcasting gibi proc'lar ekranda belirir.",
        function() local p = HM.db.procs; return type(p) == "table" and p.enabled and true or false end,
        function(on) if HM.Procs then HM.Procs:Command(on and "ac" or "kapat") end end))
    g, s = dbflag("xpBuffSilent", true)
    add(1, toggle("XP buff hatırlatması", "Yemek, uyku tulumu gibi XP buff'ları eksikken hatırlatır.", g, s))
    g, s = sub("camp", "silent", true)
    add(1, toggle("Kamp hatırlatması", "Meslek kamp eşyası ve kamp buff'ı hatırlatmaları.", g, s))
    g, s = sub("books", "silent", true)
    add(1, toggle("Kitap hatırlatması", "Yakındaki kütüphane kitaplarını hatırlatır.", g, s))

    -- 2. sütun -----------------------------------------------------------
    add(2, { kind = "header", label = "Otomatik işler" })
    g, s = dbflag("autoQuest")
    add(2, toggle("Görev al / teslim et", "Yalnızca rotadaki görevler. Shift basılıyken devre dışı.", g, s))
    g, s = dbflag("autoSell")
    add(2, toggle("Gri eşyaları sat", "Satıcıda gri eşyalar kendiliğinden satılır.", g, s))
    g, s = dbflag("autoRepair")
    add(2, toggle("Tamir", "Tamir eden satıcıda otomatik tamir.", g, s))
    g, s = dbflag("smartTrain")
    add(2, toggle("Akıllı büyü alımı", "Eğitmende işe yarayan büyüler alınır, gereksizler atlanır.", g, s))
    g, s = dbflag("autoTalent")
    add(2, toggle("Talent", "Seviye atlayınca plandaki talent kendisi alınır.", g, s))
    g, s = dbflag("autoSort")
    add(2, toggle("Çanta sıralama", "Satıcıdan sonra ve yeni eşya alınca çanta sıralanır.", g, s))
    g, s = dbflag("buffRequestOff", true)
    add(2, toggle("Buff isteme (fısıltı)", "Yakındaki Priest/Druid/Paladin'e buff için otomatik fısıltı atar.", g, s))
    add(2, toggle("LFG otomatik mesaj", "Grup arama listesinde uygun grup liderlerine tanıtım fısıltısı atar.",
        function() local l = HM.db.lfg; return type(l) == "table" and l.on and true or false end,
        function(on) if HM.LFG then HM.LFG:Toggle(on) end end))

    add(2, { kind = "header", label = "Görünüm" })
    add(2, toggle("Yön oku", "Sıradaki adımın yönünü gösteren ok.",
        function() local a = HM.db.arrow; return type(a) == "table" and a.shown and true or false end,
        function(on) HM.db.arrow.shown = on and true or false; if HM.Arrow then HM.Arrow:Refresh() end end))
    add(2, toggle("Minimap koordinatı", "Minimap'in sağ üstünde küçük koordinat.",
        function() return HM.db.minimapCoords ~= false end,
        function(on) if (HM.db.minimapCoords ~= false) ~= on and HM.ToggleMinimapCoords then HM.ToggleMinimapCoords() end end))
    local zzz = toggle("Dinlenme (zzz) göstergesi", "Han ya da şehirde dinlenirken oyuncu çerçevende zzz. EllesmereUI'ın \"Rested Indicator\" seçeneğini açar/kapatır.",
        function() return Menu:RestedState() end, function(on) Menu:SetRested(on, false) end)
    zzz.na = function() Menu:SetRested(true, true) end      -- EllesmereUI yoksa nedenini söyle
    add(2, zzz)

    add(2, { kind = "header", label = "Araçlar" })
    add(2, { kind = "action", label = "Bu bölgede ne var?", tip = "Bulunduğun bölgedeki rare, sandık, uçuş, ot ve maden noktası sayılarını yazar.",
        run = function() if HM.Pins then HM.Pins:Status() end; if HM.Gather then HM.Gather:Report() end end })
    add(2, { kind = "action", label = "Zindan bilgi paneli", tip = "Zindan/raid bilgi panelini açar ya da kapatır.",
        run = function() if HM.DungeonPanel then HM.DungeonPanel:Toggle() end end })
    add(2, { kind = "action", label = "Sohbeti kopyala", tip = "Son sohbet satırlarını kopyalanabilir pencerede açar.",
        run = function() if HM.ChatCopy then HM.ChatCopy:Show() end end })
    add(2, { kind = "action", label = "AH alışveriş listesi", tip = "Seviyene göre Auction House'ta bakılacak eşyalar.",
        run = function() if HM.AH then HM.AH:Report(nil) end end })
    add(2, { kind = "action", label = "Tüm komutlar", tip = "Bütün /hm komutlarını sohbete yazar.",
        run = function() if SlashCmdList and SlashCmdList["HIZLIMAGE"] then SlashCmdList["HIZLIMAGE"]("yardim") end end })
    add(2, { kind = "action", label = "Hata kaydı", tip = "Eklentinin yakaladığı hataları yazar. Bir şey çalışmadığında buraya bak.",
        dyn = function() local n = HM.db.errors and #HM.db.errors or 0; return n > 0 and string.format("Hata kaydı (%d)", n) or "Hata kaydı (boş)" end,
        run = function() HM:ShowErrors("") end })
    return items
end

---------------------------------------------------------------------------
-- Pencere
---------------------------------------------------------------------------
local function rowTooltip(self)
    local it = self.item
    if not (it and it.tip) then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(HM:T(it.label), 1, 0.82, 0)
    GameTooltip:AddLine(HM:T(it.tip), 1, 1, 1, true)
    if it.note then
        local ok, _, why = pcall(it.note)
        if ok and why then GameTooltip:AddLine(HM:T(why), 1, 0.82, 0.3, true) end
    end
    GameTooltip:Show()
end

local function makeRow(parent)
    local r = CreateFrame("Button", nil, parent)
    r:SetSize(COL_W, ROW_H)
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(14, 14)
    r.icon:SetPoint("LEFT", 2, 0)
    r.label = r:CreateFontString(nil, "OVERLAY")
    Font(r.label, 12)
    r.label:SetPoint("LEFT", r.icon, "RIGHT", 5, 0)
    r.label:SetJustifyH("LEFT")
    r.state = r:CreateFontString(nil, "OVERLAY")
    Font(r.state, 11)
    r.state:SetPoint("RIGHT", -4, 0)
    r.state:SetJustifyH("RIGHT")
    r.hl = r:CreateTexture(nil, "HIGHLIGHT")
    r.hl:SetAllPoints()
    r.hl:SetColorTexture(1, 1, 1, 0.08)
    r.btns = {}
    r:SetScript("OnClick", function(self) Menu:Click(self.item) end)
    r:SetScript("OnEnter", rowTooltip)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return r
end

local function makeChoice(row, i)
    local b = CreateFrame("Button", nil, row)
    b:SetSize(32, ROW_H - 4)
    b.bg = b:CreateTexture(nil, "BACKGROUND")
    b.bg:SetAllPoints()
    b.bg:SetColorTexture(1, 1, 1, 0.06)
    b.text = b:CreateFontString(nil, "OVERLAY")
    Font(b.text, 11)
    b.text:SetPoint("CENTER")
    b:SetScript("OnClick", function(self)
        local it = row.item
        if it and it.set then
            local ok, err = pcall(it.set, self.value)
            if not ok then HM:LogError("menü: " .. tostring(it.label), err) end
        end
        Menu:Refresh()
    end)
    b:SetScript("OnEnter", function() rowTooltip(row) end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    row.btns[i] = b
    return b
end

function Menu:Create()
    if frame then return frame end
    self.items = build()
    frame = CreateFrame("Frame", "HizliMageMenu", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    if frame.SetBackdrop then
        frame:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 14,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        frame:SetBackdropColor(0.05, 0.06, 0.1, 0.95)
        frame:SetBackdropBorderColor(0.25, 0.65, 0.95, 0.9)
    end

    frame.title = frame:CreateFontString(nil, "OVERLAY")
    Font(frame.title, 13, "OUTLINE")
    frame.title:SetPoint("TOPLEFT", PAD, -10)
    frame.title:SetTextColor(0.25, 0.78, 0.92)
    frame.title:SetText(HM:T("Hızlı Mage menüsü"))

    frame.ver = frame:CreateFontString(nil, "OVERLAY")
    Font(frame.ver, 10)
    frame.ver:SetPoint("LEFT", frame.title, "RIGHT", 8, 0)
    frame.ver:SetTextColor(0.55, 0.55, 0.55)
    frame.ver:SetText("v" .. tostring(HM.version))

    frame.close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    frame.close:SetSize(22, 22)
    frame.close:SetPoint("TOPRIGHT", 0, 0)
    frame.close:SetScript("OnClick", function() frame:Hide() end)

    frame.hint = frame:CreateFontString(nil, "OVERLAY")
    Font(frame.hint, 10)
    frame.hint:SetTextColor(0.55, 0.55, 0.55)
    frame.hint:SetText(HM:T("Satıra tıkla: aç/kapat. Üstünde bekle: açıklama. Esc kapatır."))

    -- satırları sütunlara diz
    local y = { -34, -34 }
    local maxRows = 0
    for i, it in ipairs(self.items) do
        local r = makeRow(frame)
        r.item = it
        rows[i] = r
        local col = it.col or 1
        if it.kind == "header" and y[col] < -34 then y[col] = y[col] - 6 end
        r:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD + (col - 1) * (COL_W + PAD), y[col])
        y[col] = y[col] - ROW_H
        if it.kind == "header" then
            r.icon:Hide()
            r.label:ClearAllPoints()
            r.label:SetPoint("LEFT", 0, 0)
            Font(r.label, 12, "OUTLINE")
            r.label:SetTextColor(1, 0.82, 0)
            r.label:SetText(HM:T(it.label))
            r:EnableMouse(false)
        elseif it.kind == "choice" then
            local x = 0
            for c = #it.choices, 1, -1 do
                local b = makeChoice(r, c)
                b.value = it.choices[c][2]
                b.text:SetText(HM:T(it.choices[c][1]))
                b:SetPoint("RIGHT", r, "RIGHT", -x, 0)
                x = x + 34
            end
        end
        maxRows = math.max(maxRows, -y[col])
    end
    frame:SetSize(PAD * 3 + COL_W * 2, maxRows + 26)
    frame.hint:SetPoint("BOTTOMLEFT", PAD, 8)

    if UISpecialFrames then
        local found = false
        for _, n in ipairs(UISpecialFrames) do if n == "HizliMageMenu" then found = true end end
        if not found then table.insert(UISpecialFrames, "HizliMageMenu") end
    end
    frame:Hide()
    return frame
end

function Menu:Refresh()
    if not frame then return end
    for _, r in ipairs(rows) do
        local it = r.item
        if it.kind == "toggle" then
            local ok, v = pcall(it.get)
            if not ok then HM:LogError("menü: " .. tostring(it.label), v); v = nil end
            if v == nil then
                setIcon(r.icon, "na")
                r.label:SetTextColor(0.5, 0.5, 0.5)
                r.state:SetText(HM:T("yok"))
                r.state:SetTextColor(0.5, 0.5, 0.5)
            elseif v then
                local note
                if it.note then
                    local okN, text = pcall(it.note)
                    if okN and type(text) == "string" then note = text end
                end
                r.label:SetTextColor(0.95, 0.95, 0.95)
                if note then
                    -- açık ama şu an bir şey göstermiyor (ör. karakterde o meslek yok)
                    setIcon(r.icon, "na")
                    r.state:SetText(HM:T(note))
                    r.state:SetTextColor(1, 0.82, 0.3)
                else
                    setIcon(r.icon, "on")
                    r.state:SetText(HM:T("Açık"))
                    r.state:SetTextColor(0.35, 0.9, 0.35)
                end
            else
                setIcon(r.icon, "off")
                r.label:SetTextColor(0.62, 0.62, 0.62)
                r.state:SetText(HM:T("Kapalı"))
                r.state:SetTextColor(0.9, 0.4, 0.4)
            end
            r.label:SetText(HM:T(it.label))
        elseif it.kind == "choice" then
            setIcon(r.icon, "go")
            r.label:SetTextColor(0.95, 0.95, 0.95)
            r.label:SetText(HM:T(it.label))
            local ok, cur = pcall(it.get)
            for _, b in ipairs(r.btns) do
                local sel = ok and (b.value == cur)
                if sel then
                    b.text:SetTextColor(1, 0.82, 0)
                    b.bg:SetColorTexture(0.25, 0.65, 0.95, 0.35)
                else
                    b.text:SetTextColor(0.7, 0.7, 0.7)
                    b.bg:SetColorTexture(1, 1, 1, 0.06)
                end
            end
        elseif it.kind == "action" then
            setIcon(r.icon, "go")
            r.label:SetTextColor(0.6, 0.85, 1)
            local text = it.label
            if it.dyn then
                local ok, t = pcall(it.dyn)
                if ok and t then text = t end
            end
            r.label:SetText(HM:T(text))
        end
    end
end

function Menu:Click(it)
    if not it then return end
    if it.kind == "toggle" then
        local ok, cur = pcall(it.get)
        if ok and cur ~= nil then
            local ok2, err = pcall(it.set, not cur)
            if not ok2 then HM:LogError("menü: " .. tostring(it.label), err) end
        elseif it.na then
            pcall(it.na)
        end
    elseif it.kind == "action" and it.run then
        local ok, err = pcall(it.run)
        if not ok then
            HM:LogError("menü: " .. tostring(it.label), err)
            HM:Print("|cffff8080Bu işlem hata verdi ve kaydedildi.|r")
        end
    end
    self:Refresh()
end

function Menu:Show(anchor)
    local f = self:Create()
    f:ClearAllPoints()
    anchor = anchor or _G.HizliMageFrame
    if anchor and anchor.IsShown and anchor:IsShown() then
        -- rehber ekranın solundaysa sağına, sağındaysa soluna aç
        local left = anchor.GetLeft and anchor:GetLeft()
        local sw = UIParent and UIParent.GetWidth and UIParent:GetWidth()
        if type(left) == "number" and type(sw) == "number" and left > sw / 2 then
            f:SetPoint("TOPRIGHT", anchor, "TOPLEFT", -4, 0)
        else
            f:SetPoint("TOPLEFT", anchor, "TOPRIGHT", 4, 0)
        end
    else
        f:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
    end
    local sc = HM.db and HM.db.frame and HM.db.frame.scale
    if type(sc) == "number" and f.SetScale then f:SetScale(sc) end
    self:Refresh()
    f:Show()
end

function Menu:Toggle(anchor)
    if frame and frame:IsShown() then frame:Hide() else self:Show(anchor) end
end

function Menu:IsShown() return frame and frame:IsShown() and true or false end

---------------------------------------------------------------------------
-- Giriş
---------------------------------------------------------------------------
HM:OnLogin(function()
    HM:On("PLAYER_REGEN_ENABLED", function()
        if restPending then restPending = false; restApply() end
    end)
    HM:After(4, function()
        local db = HM.db
        -- zzz: EllesmereUI'da hiç ayarlanmamışsa bir kereliğine aç (kullanıcı kapatırsa dokunma).
        if type(EllesmereUIDB) == "table" and EllesmereUIDB.showRestedIndicator == nil and not db.zzzSet then
            db.zzzSet = true
            if Menu:SetRested(true, false) then
                HM:Print("Dinlenme (zzz) göstergesi açıldı: han ya da şehirde oyuncu çerçevende görünür. Kapatmak için Menü > Görünüm.")
            end
        end
        if not db.menuHint then
            db.menuHint = true
            HM:Print("Yeni: |cffffd100tıklanabilir menü|r. Rehber penceresindeki |cffffd100Menü|r düğmesi ya da |cffffd100/hm menu|r — pinler, uyarılar, otomatik işler tek tıkla açılıp kapanır.")
        end
    end, "menü girişi")
end)
