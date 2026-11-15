-- Arayüz düzeni: /hm duzen
-- Questie varken Blizzard görev takipçisini gizler, Forever'ın yerleşik hasar ölçerini kapatır (Details! kalır),
-- Details! penceresini sağ alta, sohbeti sol alta, rehber penceresini sol üste yerleştirir.

local ADDON, ns = ...
local HM = ns.HM
local Layout = {}
HM.Layout = Layout

-- Yerleşim sabitleri (UIParent birimi, 2133x1200 ölçeğinde). Sağ kenardaki dikey EllesmereUI çubukları
-- (Bar4/Bar5) ~100 birim yer kaplar; görev takipçisi bu çubukların soluna dizilir.
Layout.OPEN_UNLOCK_ONCE = nil   -- hata ayıklama: bu damga değişince girişte bir kez Unlock modu açılır
Layout.VERSION    = 17          -- artınca giriş yapınca düzen bir kez yeniden uygulanır
Layout.GUIDE_X, Layout.GUIDE_Y = 16, -52            -- rehber penceresi: sol üst, mikro menünün altı
Layout.TRACKER_X, Layout.TRACKER_Y = -120, -305     -- Questie takipçisi: minimap altı, sağ çubukların solu
Layout.TRACKER_H_RATIO = 0.5                        -- takipçi en fazla ekranın yarısı kadar uzasın
Layout.DETAILS_X, Layout.DETAILS_Y = -8, 8          -- Details!: sağ alt köşe
Layout.DETAILS_W, Layout.DETAILS_H = 330, 170
Layout.CHAT_X, Layout.CHAT_Y = 59, 43               -- ChatFrame1 sol alt (Ellesmere paneli 51 sol / 35 alt taşar)
Layout.CHAT_W, Layout.CHAT_H = 391, 177
-- EllesmereUI: alt-orta blok (küçük düğmeler, 3 sıra) ve üstünde cast bar + cooldown/buff çubukları
Layout.BTN      = 34                                 -- aksiyon düğmesi boyutu (varsayılan 45)
Layout.BLOCK_Y  = 20                                 -- ana çubuğun alt kenarı
Layout.CAST_Y   = 392                                -- cast bar alt kenarı: oyuncu ile hedef çerçevesinin arasında, karakterin altında
Layout.CD_Y     = 330                                -- Cooldowns çubuğu alt kenarı (cast barın altı)
Layout.UTIL_Y   = 290                                -- Utility çubuğu alt kenarı
Layout.BUFF_Y   = 254                                -- Buffs (takip edilen bufflar) alt kenarı
Layout.FOCUS_X, Layout.FOCUS_Y = 600, 384            -- Focus çerçevesi: oyuncu çerçevesinin solu (sağ kenarı x=600)
Layout.ELITE_BADGE = 22                              -- hedef çerçevesinde elit/nadir rozeti (px)
Layout.NP_ELITE_ICON = 26                            -- isim plakasında elit/nadir simgesi (px)
Layout.UF_W = 200                                    -- oyuncu/hedef çerçevesi genişliği (varsayılan 181)
Layout.PLAYER_POWER_H = 28                           -- oyuncu mana çubuğu kalınlığı (varsayılan 6); can çubuğuyla yarı yarıya
Layout.PLAYER_HEALTH_H = 28                          -- oyuncu can çubuğu kalınlığı (varsayılan 46)
Layout.MAP_SIZE = 240                                -- minimap boyutu (varsayılan 140, önceki 197)
Layout.MAP_X, Layout.MAP_Y = -6, -6                  -- minimap sağ üst köşeye yapışık
Layout.MICRO_X, Layout.MICRO_Y = 6, -4               -- mikro menü: sol üst köşe (fareyle görünür; Edit Mode düzenine yazılır)
Layout.BAG_X,   Layout.BAG_Y   = 320, -4             -- çanta çubuğu: mikro menünün sağı (çerçeve kendi ölçeğinde)
Layout.MICRO_SIZE = 3                                -- mikro menü / çanta boyutu: Edit Mode adım değeri (50 + 3*10 = %80)
Layout.XP_W, Layout.XP_H, Layout.XP_Y = 431, 14, 3   -- EllesmereUI XP çubuğu: bloğun hemen altı, blok genişliğinde

local function inCombatProtected(f)
    return f and f.IsProtected and InCombatLockdown and InCombatLockdown() and f:IsProtected()
end

---------------------------------------------------------------------------
-- Blizzard görev takipçisi
---------------------------------------------------------------------------
local trackerHooked = false

local function trackerFrame()
    return ObjectiveTrackerFrame or WatchFrame or QuestWatchFrame
end

function Layout:HideBlizzardTracker()
    local f = trackerFrame()
    if not f then return false end
    if inCombatProtected(f) then return false end
    f:Hide()
    if not trackerHooked then
        trackerHooked = true
        f:HookScript("OnShow", function(frame)
            if HM.db and HM.db.hideTracker and not inCombatProtected(frame) then frame:Hide() end
        end)
    end
    return true
end

function Layout:ShowBlizzardTracker()
    local f = trackerFrame()
    if f and not inCombatProtected(f) then f:Show() end
end

---------------------------------------------------------------------------
-- Forever yerleşik hasar ölçer
---------------------------------------------------------------------------
function Layout:FindBlizzardMeters()
    local out = {}
    for k, v in pairs(_G) do
        if type(k) == "string" and type(v) == "table" and k:find("DamageMeter") and not k:find("Details") then
            if type(v.GetObjectType) == "function" and type(v.IsShown) == "function" and type(v.GetParent) == "function" then
                local ok, parent = pcall(v.GetParent, v)
                if ok and parent == UIParent then out[#out + 1] = { name = k, frame = v } end
            end
        end
    end
    table.sort(out, function(a, b) return a.name < b.name end)
    return out
end

function Layout:HideBlizzardMeter(verbose)
    local names = {}
    for _, e in ipairs(self:FindBlizzardMeters()) do
        local f = e.frame
        if not inCombatProtected(f) then
            pcall(f.Hide, f)
            if not f.hmHooked then
                f.hmHooked = true
                pcall(f.HookScript, f, "OnShow", function(fr)
                    if HM.db and HM.db.hideBlizzMeter and not inCombatProtected(fr) then pcall(fr.Hide, fr) end
                end)
            end
            names[#names + 1] = e.name
        end
    end
    if verbose then
        if #names > 0 then
            HM:Print("Yerleşik hasar ölçer gizlendi: " .. table.concat(names, ", "))
        else
            HM:Print("Yerleşik hasar ölçer çerçevesi bulunamadı; Edit Mode'dan kapatman gerekebilir.")
        end
    end
    return #names
end

function Layout:ShowBlizzardMeter()
    for _, e in ipairs(self:FindBlizzardMeters()) do
        if not inCombatProtected(e.frame) then pcall(e.frame.Show, e.frame) end
    end
end

---------------------------------------------------------------------------
-- Details!
---------------------------------------------------------------------------
function Layout:ArrangeDetails(verbose)
    if not (Details and Details.GetInstance) then
        if verbose then HM:Print("Details! yüklü değil, atlandı.") end
        return false
    end
    local ok, inst = pcall(Details.GetInstance, Details, 1)
    if not ok or not inst then return false end
    -- pencere dökümü (hata ayıklama)
    local list = Details.tabela_instancias or {}
    if verbose then
        for i, o in ipairs(list) do
            local shown = o.baseframe and o.baseframe.IsShown and o.baseframe:IsShown()
            local p1, _, p2, x, y = "?", nil, "?", 0, 0
            if o.baseframe and o.baseframe.GetPoint then
                local okp, a, _, b, c, d = pcall(o.baseframe.GetPoint, o.baseframe)
                if okp then p1, p2, x, y = tostring(a), tostring(b), tonumber(c) or 0, tonumber(d) or 0 end
            end
            HM:Print(string.format("Details pencere %d: aktif=%s görünür=%s %s/%s %.0f,%.0f", i, tostring(o.ativa), tostring(shown), p1, p2, x, y))
        end
    end
    -- fazladan açık pencereleri kapat
    for i = 2, #list do
        local o = list[i]
        if o and o.ativa then
            if o.ShutDown then pcall(o.ShutDown, o) end
            if o.baseframe and o.baseframe.Hide then pcall(o.baseframe.Hide, o.baseframe) end
        end
    end
    local bf = inst.baseframe
    if bf then
        pcall(bf.ClearAllPoints, bf)
        pcall(bf.SetPoint, bf, "BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", Layout.DETAILS_X, Layout.DETAILS_Y)
    end
    if inst.SetSize then pcall(inst.SetSize, inst, Layout.DETAILS_W, Layout.DETAILS_H) end
    -- Details konumu LibWindow ile saklar; SaveMainWindowPosition hem posicao hem libwindow tablosunu günceller
    if inst.SaveMainWindowPosition then pcall(inst.SaveMainWindowPosition, inst) end
    if verbose then HM:Print(string.format("Details! penceresi sağ alta alındı (%dx%d), fazladan pencereler kapatıldı.", Layout.DETAILS_W, Layout.DETAILS_H)) end
    return true
end

---------------------------------------------------------------------------
-- Questie görev takipçisi
---------------------------------------------------------------------------
function Layout:ArrangeQuestie(verbose)
    local prof = Questie and Questie.db and Questie.db.profile
    local bf = Questie_BaseFrame
    if not (prof and bf) then
        if verbose then HM:Print("Questie takipçisi bulunamadı, atlandı.") end
        return false
    end
    if inCombatProtected(bf) then return false end
    prof.trackerSetpoint = "TOPRIGHT"
    prof.TrackerLocation = { "TOPRIGHT", "UIParent", "TOPRIGHT", Layout.TRACKER_X, Layout.TRACKER_Y }
    prof.TrackerHeight = 0
    prof.trackerHeightRatio = Layout.TRACKER_H_RATIO
    pcall(bf.ClearAllPoints, bf)
    pcall(bf.SetPoint, bf, unpack(prof.TrackerLocation))
    local QT = QuestieLoader and QuestieLoader.ImportModule and QuestieLoader:ImportModule("QuestieTracker")
    if QT and QT.Update then pcall(QT.Update, QT) end
    if verbose then HM:Print("Questie takipçisi minimap altına, sağ çubukların soluna alındı.") end
    return true
end

---------------------------------------------------------------------------
-- Sohbet
---------------------------------------------------------------------------
function Layout:ArrangeChat(verbose)
    local cf = ChatFrame1
    if not cf then return false end
    if inCombatProtected(cf) then return false end
    -- EllesmereUI sohbet modülü konumu kendi profilinde tutar ve her karede yeniden uygular
    local cdb = _G._ECHAT_DB
    local cfg = cdb and cdb.profile and cdb.profile.chat
    if cfg then
        cfg.chatPosition = { point = "BOTTOMLEFT", relPoint = "BOTTOMLEFT", x = Layout.CHAT_X, y = Layout.CHAT_Y }
        cfg.chatSize = { w = Layout.CHAT_W, h = Layout.CHAT_H }
        if verbose then HM:Print("Sohbet sol alt köşeye alındı (EllesmereUI).") end
        return true
    end
    pcall(cf.SetUserPlaced, cf, true)
    pcall(cf.ClearAllPoints, cf)
    pcall(cf.SetPoint, cf, "BOTTOMLEFT", UIParent, "BOTTOMLEFT", 36, 52)
    pcall(cf.SetSize, cf, 440, 150)
    if FCF_SavePositionAndDimensions then pcall(FCF_SavePositionAndDimensions, cf) end
    if verbose then HM:Print("Sohbet penceresi sol alta alındı (440x150).") end
    return true
end

---------------------------------------------------------------------------
-- EllesmereUI: aksiyon çubukları, mikro menü, cast bar, cooldown/buff çubukları
---------------------------------------------------------------------------
local function euiAddon(name)
    local EUI = EllesmereUI
    if not (EUI and EUI.Lite and EUI.Lite.GetAddon) then return nil end
    local ok, a = pcall(EUI.Lite.GetAddon, name, true)
    return ok and a or nil
end

-- Edit Mode düzeninde bir sistemin (MicroMenu, Bags) konumunu ve ayarlarını değiştirir; tek SaveLayouts ile kaydeder.
local function emFindSystem(entry, sysEnum)
    for _, sys in ipairs(entry.systems or {}) do
        if type(sys) == "table" and sys.system == sysEnum then return sys end
    end
end

local function emSetAnchor(sys, point, relPoint, x, y, settings)
    sys.anchorInfo = { point = point, relativeTo = "UIParent", relativePoint = relPoint, offsetX = x, offsetY = y }
    sys.anchorInfo2 = nil
    sys.isInDefaultPosition = false
    for id, val in pairs(settings or {}) do
        local row
        for _, r in ipairs(sys.settings or {}) do
            if type(r) == "table" and r.setting == id then row = r break end
        end
        if row then row.value = val else
            sys.settings = sys.settings or {}
            sys.settings[#sys.settings + 1] = { setting = id, value = val }
        end
    end
end

function Layout:EditModeMicroBags()
    local EUI = EllesmereUI
    if not (C_EditMode and C_EditMode.SaveLayouts and Enum and Enum.EditModeSystem) then return false, "Edit Mode API yok" end
    if EUI and EUI.EditModeOpen and EUI.EditModeOpen() then return false, "Edit Mode açık" end
    local blob, numPresets
    if EUI and EUI.EditModeLayoutsForSave then
        blob, numPresets = EUI.EditModeLayoutsForSave()
    end
    if not blob then return false, "düzen okunamadı" end
    local active = blob.activeLayout
    local entry = type(active) == "number" and blob.layouts and blob.layouts[active]
    if not entry then return false, "etkin düzen yok" end
    local layEnum = Enum.EditModeLayoutType
    local isPreset = (numPresets and active <= numPresets) or (layEnum and entry.layoutType == layEnum.Preset)
    if isPreset then
        -- Hazır ayarlar (Modern/Classic) yazılamaz: varsa "HizliMage" düzenini etkinleştir, yoksa etkin hazır ayarın
        -- kopyasından oluştur (Edit Mode'daki "yeni düzen" ile aynı iş).
        local found
        for i, l in ipairs(blob.layouts or {}) do
            if type(l) == "table" and l.layoutName == "HizliMage" and (not layEnum or l.layoutType ~= layEnum.Preset) then found = i break end
        end
        if not found then
            local function deepcopy(t)
                if type(t) ~= "table" then return t end
                local o = {}
                for k, v in pairs(t) do o[k] = deepcopy(v) end
                return o
            end
            local nl = deepcopy(entry)
            nl.layoutName = "HizliMage"
            nl.layoutType = (layEnum and layEnum.Account) or 1
            blob.layouts[#blob.layouts + 1] = nl
            found = #blob.layouts
        end
        blob.activeLayout = found
        entry = blob.layouts[found]
        HM.db.editModeLayoutMade = true
    end
    local sysMicro = Enum.EditModeSystem.MicroMenu
    local sysBags = Enum.EditModeSystem.Bags
    local changed = false
    local micro = sysMicro and emFindSystem(entry, sysMicro)
    if micro then
        local st = {}
        if Enum.EditModeMicroMenuSetting and Enum.EditModeMicroMenuSetting.Size then st[Enum.EditModeMicroMenuSetting.Size] = Layout.MICRO_SIZE end
        emSetAnchor(micro, "TOPLEFT", "TOPLEFT", Layout.MICRO_X, Layout.MICRO_Y, st)
        changed = true
    end
    local bags = sysBags and emFindSystem(entry, sysBags)
    if bags then
        local st = {}
        if Enum.EditModeBagsSetting and Enum.EditModeBagsSetting.Size then st[Enum.EditModeBagsSetting.Size] = Layout.MICRO_SIZE end
        emSetAnchor(bags, "TOPLEFT", "TOPLEFT", Layout.BAG_X, Layout.BAG_Y, st)
        changed = true
    end
    if not changed then return false, "MicroMenu/Bags sistemi düzen kaydında yok" end
    local ok, err = pcall(C_EditMode.SaveLayouts, blob)
    if not ok then return false, "SaveLayouts: " .. tostring(err) end
    -- Kaydetmek etkin düzeni değiştirmez; yeni düzeni ayrıca etkinleştir (birleşik listedeki sıra)
    local okA, errA = true, nil
    if C_EditMode.SetActiveLayout then
        okA, errA = pcall(C_EditMode.SetActiveLayout, blob.activeLayout)
    end
    HM.db.editModeWrote = (date and date("%H:%M:%S")) or true
    HM.db.editModeDbg = string.format("presets=%s active=%s layouts=%d setActive=%s %s", tostring(numPresets), tostring(blob.activeLayout), #blob.layouts, tostring(okA), tostring(errA or ""))
    return true
end

-- EllesmereUI modül profili: tüm modül ayarları merkezi EllesmereUIDB.profiles[<etkin>].addons[<klasör>] altında tutulur
-- (bazı modüller db nesnesini dışa açmaz, ör. birim çerçeveleri).
local function euiProfile(folder, addonObj)
    local P = _G.EllesmereUIDB
    local name = (P and P.activeProfile) or "Default"
    local prof = P and P.profiles and P.profiles[name]
    local t = prof and prof.addons and prof.addons[folder]
    if type(t) == "table" then return t end
    return addonObj and addonObj.db and addonObj.db.profile or nil
end

function Layout:ArrangeEllesmere(verbose)
    local EUI = EllesmereUI
    if not EUI then
        if verbose then HM:Print("EllesmereUI yüklü değil, çubuk düzeni atlandı.") end
        return false
    end
    if HM:InCombat() then return false end
    local notes = {}

    -- 1) Aksiyon çubukları: küçük düğmeler, alt-orta 3 sıralı blok
    local EAB = euiAddon("EllesmereUIActionBars")
    local prof = EAB and EAB.db and EAB.db.profile
    if prof and prof.bars then
        for _, key in ipairs({ "MainBar", "Bar2", "Bar3", "Bar4", "Bar5" }) do
            local b = prof.bars[key]
            if b then
                b.buttonWidth, b.buttonHeight = Layout.BTN, Layout.BTN
                b.buttonPadding = 2
                if EAB.ApplyButtonSizeForBar then pcall(EAB.ApplyButtonSizeForBar, EAB, key) end
            end
        end
        prof.barPositions = prof.barPositions or {}
        local bp = prof.barPositions
        local step = Layout.BTN + 2
        bp.MainBar = { point = "BOTTOM", relPoint = "BOTTOM", x = 0, y = Layout.BLOCK_Y }
        bp.Bar2    = { point = "BOTTOM", relPoint = "BOTTOM", x = 0, y = Layout.BLOCK_Y + step }
        bp.Bar3    = { point = "BOTTOM", relPoint = "BOTTOM", x = 0, y = Layout.BLOCK_Y + 2 * step }
        -- XP çubuğu: Blizzard'ınki ana çubuğun üstüne yapışık kalıp bloğun içinden geçiyor; EllesmereUI'nin
        -- kendi veri çubuğu kullanılır (yeniden yüklemede oluşur), blok genişliğinde ve bloğun altında
        if prof.useBlizzardDataBars ~= false then
            prof.useBlizzardDataBars = false
            HM.db.needReload = true
        end
        prof.bars.XPBar = prof.bars.XPBar or {}
        prof.bars.XPBar.width, prof.bars.XPBar.height = Layout.XP_W, Layout.XP_H
        bp.XPBar = { point = "BOTTOM", relPoint = "BOTTOM", x = 0, y = Layout.XP_Y }
        -- mikro menü + çanta çubuğu: konumları Blizzard Edit Mode düzeninde tutulur (aşağıda yazılır); fare gelince görünür
        for _, key in ipairs({ "MicroBar", "BagBar" }) do
            local b = prof.bars[key]
            if b and EAB.VisibilityCompat and EAB.VisibilityCompat.ApplyMode then
                pcall(EAB.VisibilityCompat.ApplyMode, b, "mouseover")
            end
        end
        for _, fn in ipairs({ "RefreshRuntimeVisibility", "RefreshMouseover", "ApplyCombatVisibility" }) do
            if EAB[fn] then pcall(EAB[fn], EAB) end
        end
        notes[#notes + 1] = "aksiyon çubukları " .. Layout.BTN .. "px, 3 sıra alt-orta; mikro menü ve çanta sol üstte fareyle görünür"
    end

    -- 2) Cast bar (Resource Bars modülü)
    local ERB = euiAddon("EllesmereUIResourceBars")
    local cb = ERB and ERB.db and ERB.db.profile and ERB.db.profile.castBar
    if cb then
        cb.unlockPos = { point = "BOTTOM", relPoint = "BOTTOM", x = 0, y = Layout.CAST_Y }
        notes[#notes + 1] = "cast bar karakterin altında, oyuncu-hedef çerçeveleri arasında"
    end

    -- 2b) Birim çerçeveleri: Focus çerçevesi ekran ortasında cooldown çubuklarının üstüne geliyordu; oyuncu çerçevesinin soluna
    local EUF = euiAddon("EllesmereUIUnitFrames")
    local up = euiProfile("EllesmereUIUnitFrames", EUF)
    if up then
        up.positions = up.positions or {}
        up.positions.focus = { point = "BOTTOMRIGHT", relPoint = "BOTTOMLEFT", x = Layout.FOCUS_X, y = Layout.FOCUS_Y }
        notes[#notes + 1] = "focus çerçevesi oyuncu çerçevesinin soluna"
    end

    -- 2c) Oyuncu/hedef çerçeveleri: biraz daha geniş, oyuncunun mana çubuğu daha kalın (yeniden yüklemede uygulanır)
    if up then
        up.player = up.player or {}
        up.target = up.target or {}
        local pl = up.player
        if pl.powerHeight ~= Layout.PLAYER_POWER_H or pl.healthHeight ~= Layout.PLAYER_HEALTH_H or pl.frameWidth ~= Layout.UF_W
            or up.target.frameWidth ~= Layout.UF_W or pl.powerPercentText ~= "right" then
            pl.powerHeight = Layout.PLAYER_POWER_H
            pl.healthHeight = Layout.PLAYER_HEALTH_H
            pl.frameWidth = Layout.UF_W
            pl.powerPercentText = "right"     -- mana çubuğunda % yazısı (sağda, can yüzdesiyle aynı hizada)
            pl.powerShowPercent = true
            pl.powerTextFormat = "perpp"
            pl.powerPercentSize = 11
            up.target.frameWidth = Layout.UF_W
            HM.db.needReload = true
        end
        notes[#notes + 1] = "oyuncu çerçevesi " .. Layout.UF_W .. " px; can/mana çubukları " .. Layout.PLAYER_HEALTH_H .. "/" .. Layout.PLAYER_POWER_H .. " px, mana yüzdesi açık"
    end

    -- 2c2) Can yazıları (sayı | %), elit rozeti, düşman isim plakaları
    do
        local changed = Layout:HealthEliteProfile()
        if changed then HM.db.needReload = true end
        Layout:NameplateCVars()
        notes[#notes + 1] = "can yazıları sayı | %, hedefte elit rozeti, düşman isim plakaları açık"
        if Layout:EnableUprank() then notes[#notes + 1] = "bardaki eski büyü rank'ları otomatik yenilenir (Ellesmere Uprank açıldı)" end
    end

    -- 2d) Minimap: daha büyük ve sağ üst köşeye yapışık
    local EMM = euiAddon("EllesmereUIMinimap")
    local mp = EMM and EMM.db and EMM.db.profile and EMM.db.profile.minimap
    if mp then
        mp.mapSize = Layout.MAP_SIZE
        mp.position = { point = "TOPRIGHT", relPoint = "TOPRIGHT", x = Layout.MAP_X, y = Layout.MAP_Y }
        if Minimap and not inCombatProtected(Minimap) then
            pcall(Minimap.ClearAllPoints, Minimap)
            pcall(Minimap.SetPoint, Minimap, "TOPRIGHT", UIParent, "TOPRIGHT", Layout.MAP_X, Layout.MAP_Y)
        end
        if _G._EMM_ApplyMinimap then pcall(_G._EMM_ApplyMinimap) end
        notes[#notes + 1] = "minimap " .. Layout.MAP_SIZE .. " px, sağ üst köşede"
    end

    -- 3) Cooldown yöneticisi çubukları (Cooldowns / Utility / Buffs)
    local ECME = euiAddon("EllesmereUICooldownManager")
    local cp = ECME and ECME.db and ECME.db.profile
    if cp then
        cp.cdmBarPositions = cp.cdmBarPositions or {}
        local half = UIParent:GetHeight() / 2
        cp.cdmBarPositions.cooldowns = { point = "BOTTOM", relPoint = "CENTER", x = 0, y = Layout.CD_Y - half }
        cp.cdmBarPositions.utility   = { point = "BOTTOM", relPoint = "CENTER", x = 0, y = Layout.UTIL_Y - half }
        cp.cdmBarPositions.buffs     = { point = "BOTTOM", relPoint = "CENTER", x = 0, y = Layout.BUFF_Y - half }
        notes[#notes + 1] = "cooldown ve buff çubukları cast barın altında"
    end

    -- 4) Mikro menü ve çanta çubuğu: Edit Mode düzeni (sol üst köşe, küçültülmüş)
    local okEM, emMsg = Layout:EditModeMicroBags()
    HM.db.editModeMsg = okEM and "ok" or tostring(emMsg)
    -- hata ayıklama: Edit Mode düzen listesi
    pcall(function()
        local info = C_EditMode and C_EditMode.GetLayouts and C_EditMode.GetLayouts()
        if type(info) == "table" then
            local names = {}
            for i, l in ipairs(info.layouts or {}) do names[#names + 1] = i .. ":" .. tostring(l.layoutName) .. "(" .. tostring(l.layoutType) .. ")" end
            HM.db.editModeInfo = "active=" .. tostring(info.activeLayout) .. " " .. table.concat(names, ", ")
        else
            HM.db.editModeInfo = "GetLayouts yok"
        end
        local EUI = EllesmereUI
        HM.db.editModeHelpers = tostring(EUI and EUI.EditModeLayoutsForSave ~= nil) .. "/" .. tostring(EUI and EUI.EditModeOpen ~= nil)
    end)
    if okEM then
        notes[#notes + 1] = "mikro menü ve çanta Edit Mode düzeninde sol üst köşeye yazıldı"
    elseif emMsg then
        notes[#notes + 1] = "mikro menü taşınamadı: " .. emMsg
    end

    -- 5) Kaydedilen konumları uygula (EllesmereUI'nin kendi yolu)
    if EUI._applySavedPositions then pcall(EUI._applySavedPositions) end
    if verbose and #notes > 0 then HM:Print("EllesmereUI: " .. table.concat(notes, "; ") .. ".") end
    return true
end

---------------------------------------------------------------------------
-- Can yazıları ve elit göstergeleri (v14): hedef/odak/oyuncu çerçevesinde "sayı | %",
-- hedef çerçevesinde elit rozeti, düşman isim plakaları açık (can %, sayı, elit simgesi).
-- Profil değerleri EllesmereUI yüklenmeden ÖNCE (ADDON_LOADED) yazılır ki tek /reload yetsin.
---------------------------------------------------------------------------
function Layout:HealthEliteProfile()
    local changed = false
    local up = euiProfile("EllesmereUIUnitFrames", euiAddon and euiAddon("EllesmereUIUnitFrames"))
    if up then
        for _, unit in ipairs({ "player", "target", "focus", "party" }) do
            up[unit] = up[unit] or {}
            if up[unit].rightTextContent ~= "both" then up[unit].rightTextContent = "both"; changed = true end
        end
        -- party: mana yazısı (sayı | %) göster
        local pt = up.party
        if pt.powerShowPercent ~= true or pt.powerPercentText ~= "right" then
            pt.powerShowPercent = true
            pt.powerPercentText = "right"
            pt.powerTextFormat = "perpp"
            pt.powerPercentSize = 10
            changed = true
        end
        local t = up.target
        if t.eliteIndicatorEnabled ~= true or t.eliteIndicatorSize ~= Layout.ELITE_BADGE then
            t.eliteIndicatorEnabled = true
            t.eliteIndicatorStyle = "badge"
            t.eliteIndicatorPosition = "topleft"
            t.eliteIndicatorSize = Layout.ELITE_BADGE
            t.eliteIndicatorShowInInstances = true
            changed = true
        end
    end
    local np = euiProfile("EllesmereUINameplates", euiAddon and euiAddon("EllesmereUINameplates"))
    if np then
        if np.classificationHideRare ~= false then np.classificationHideRare = false; changed = true end
        if np.classificationSlot == "none" or np.classificationSlot == nil then np.classificationSlot = "topleft"; changed = true end
        if np.rareEliteIconSize ~= Layout.NP_ELITE_ICON then np.rareEliteIconSize = Layout.NP_ELITE_ICON; changed = true end
        if np.textSlotRight ~= "healthPercent" then np.textSlotRight = "healthPercent"; changed = true end
        if np.textSlotCenter ~= "healthNumber" then np.textSlotCenter = "healthNumber"; changed = true end
    end
    return changed, up ~= nil, np ~= nil
end

-- Ellesmere "Uprank" (Forever Essentials): yeni rank öğrenilince bardaki eski rank'ları kendisi değiştirir.
-- Varsayılanı kapalı; açıyoruz. Dönüş: ayar değişti mi.
function Layout:EnableUprank()
    local P = _G.EllesmereUIDB
    if type(P) ~= "table" then return false end
    P.spellUprank = P.spellUprank or {}
    local changed = P.spellUprank.enabled ~= true
    P.spellUprank.enabled = true
    local U = EllesmereUI and EllesmereUI._SpellUprank
    if U and U.Apply and not HM:InCombat() then pcall(U.Apply) end   -- ilk kontrol bardaki her eski rank'ı yeniler
    return changed
end

-- Düşman isim plakaları (Blizzard varsayılanı kapalı: V tuşu). Dost plakaları karışıklık yapmasın diye kapalı kalır.
function Layout:NameplateCVars()
    local set = (C_CVar and C_CVar.SetCVar) or SetCVar
    if not set then return end
    pcall(set, "nameplateShowEnemies", "1")
    pcall(set, "nameplateShowEnemyMinions", "1")
    pcall(set, "nameplateShowEnemyMinus", "1")
end

---------------------------------------------------------------------------
-- Rehber penceresi
---------------------------------------------------------------------------
function Layout:ArrangeGuide()
    local db = HM.db
    db.frame.point, db.frame.x, db.frame.y = "TOPLEFT", Layout.GUIDE_X, Layout.GUIDE_Y
    db.frame.shown = true
    db.frame.collapsed = false
    if HM.Guide then
        HM.Guide:Reposition()
        HM.Guide:Toggle(true)
    end
    db.arrow.point, db.arrow.x, db.arrow.y = "TOP", 0, -110
    if HM.Arrow and HM.Arrow.Reposition then HM.Arrow:Reposition() end
end

---------------------------------------------------------------------------
-- Uygula / geri al
---------------------------------------------------------------------------
function Layout:Apply(verbose)
    local db = HM.db
    if HM:InCombat() then HM:Print("Savaşta düzen değiştirilemez; savaş bitince tekrar dene."); return end
    db.hideTracker = true
    db.hideBlizzMeter = true
    db.layoutApplied = true
    local questie = (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("Questie")) or (IsAddOnLoaded and IsAddOnLoaded("Questie")) or (Questie ~= nil)
    if questie then
        if self:HideBlizzardTracker() and verbose then HM:Print("Blizzard görev takipçisi gizlendi (Questie takipçisi kullanılıyor).") end
    else
        db.hideTracker = false
        if verbose then HM:Print("Questie yüklü değil; Blizzard görev takipçisi açık bırakıldı.") end
    end
    self:HideBlizzardMeter(verbose)
    self:ArrangeDetails(verbose)
    self:ArrangeQuestie(verbose)
    self:ArrangeChat(verbose)
    self:ArrangeEllesmere(verbose)
    self:ArrangeGuide()
    -- Bagnon'u kapat, Blizzard kategorili bag aç (Totik düzeni)
    if HM.BagSort then
        pcall(function()
            local bagnon = "Bagnon"
            local disable = C_AddOns and C_AddOns.DisableAddOn or DisableAddOn
            local isLoaded = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
            if disable and isLoaded then
                local loaded = isLoaded(bagnon)
                if loaded then
                    disable(bagnon)
                    if verbose then HM:Print("Bagnon devre disi birakildi — Blizzard kategorili canta sistemi aktif (reload'da etkili).") end
                    db.needReload = true
                end
            end
        end)
    end
    db.layoutVersion = Layout.VERSION
    db.takeShot = true -- doğrulama için 6 sn sonra oyun içi ekran görüntüsü (Screenshots klasörüne)
    C_Timer.After(6, function()
        if HM.db.takeShot and Screenshot and not HM:InCombat() then HM.db.takeShot = nil; pcall(Screenshot) end
    end)
    if db.needReload then
        db.needReload = nil
        HM:Print("Düzenin tamamlanması için bir kez /reload gerekiyor (XP çubuğu ve mikro menü).")
    end
    if verbose then HM:Print("Düzen uygulandı. Geri almak için /hm duzen sifirla") end
end

function Layout:Reset()
    local db = HM.db
    db.hideTracker = false
    db.hideBlizzMeter = false
    db.layoutApplied = false
    self:ShowBlizzardTracker()
    self:ShowBlizzardMeter()
    HM:Print("Blizzard görev takipçisi ve hasar ölçer geri açıldı. Pencere konumları için /hm sifirla")
end

-- Hata ayıklama: görünür ana çerçevelerin dökümü (SavedVariables'a yazılır, /hm dokum ile de yazdırılır)
function Layout:DumpFrames(toChat)
    local sw, sh = UIParent:GetWidth(), UIParent:GetHeight()
    local out = { string.format("UIParent %dx%d uiScale=%s", sw, sh, tostring(GetCVar and GetCVar("uiScale"))) }
    local f = EnumerateFrames and EnumerateFrames()
    local n, errs = 0, 0
    local function one(fr)
        local vis = fr:IsVisible()
        if HM.IsSecret(vis) or not vis then return end
        local parent = fr.GetParent and fr:GetParent()
        local l, t, w, h = fr:GetLeft(), fr:GetTop(), fr:GetWidth() or 0, fr:GetHeight() or 0
        if HM.IsSecret(l) or HM.IsSecret(t) or HM.IsSecret(w) or HM.IsSecret(h) then return end
        if not (l and t) then return end
        local topLeft = (l < sw * 0.33 and t > sh * 0.55 and w > 20 and h > 10 and w < sw * 0.9)
        if (parent == UIParent and (w > 80 or h > 200) and h > 10 and w < sw * 0.9) or topLeft then
            local nm = (fr.GetName and fr:GetName()) or "(adsız)"
            if HM.IsSecret(nm) then nm = "(gizli)" end
            local pn = parent and ((parent.GetName and parent:GetName()) or "(adsız üst)") or "-"
            if HM.IsSecret(pn) then pn = "(gizli)" end
            out[#out + 1] = string.format("%s %dx%d sol=%d üst=%d %s üst:%s%s", tostring(nm), w, h, l, t, fr.GetFrameStrata and fr:GetFrameStrata() or "", tostring(pn), topLeft and " *" or "")
            n = n + 1
        end
    end
    while f and n < 220 do
        local ok = pcall(one, f)
        if not ok then errs = errs + 1 end
        f = EnumerateFrames(f)
    end
    out[#out + 1] = string.format("(%d çerçeve, %d okunamadı)", n, errs)
    HM.db.frameDump = out
    if toChat then for _, line in ipairs(out) do HM:Print(line) end end
    return out
end

-- Girişte gizlemeleri yeniden uygula (konumlar oyun/Details tarafından zaten saklanır).
HM:OnLogin(function()
    C_Timer.After(10, function()
        if Layout.OPEN_UNLOCK_ONCE and HM.db.unlockStamp ~= Layout.OPEN_UNLOCK_ONCE then HM.db.openUnlock = true; HM.db.unlockStamp = Layout.OPEN_UNLOCK_ONCE end
        if HM.db.openUnlock and EllesmereUI and EllesmereUI.OpenUnlockMode and not HM:InCombat() then
            HM.db.openUnlock = nil
            pcall(EllesmereUI.OpenUnlockMode, EllesmereUI)
        end
    end)
    C_Timer.After(8, function()
        HM.db.dumpAt = date and date("%H:%M:%S") or "?"
        local ok, err = pcall(Layout.DumpFrames, Layout, false)
        HM.db.dumpError = ok and "" or tostring(err)
    end)
    -- düzen sürümü ilerlediyse (eklenti güncellemesi) yerleşimi bir kez sessizce yeniden uygula
    C_Timer.After(6, function()
        local db = HM.db
        if db and db.layoutApplied and (db.layoutVersion or 0) < Layout.VERSION and not HM:InCombat() then
            Layout:Apply(false)
            HM:Print("Arayüz düzeni güncellendi (sürüm " .. Layout.VERSION .. ").")
        end
    end)
    C_Timer.After(4, function()
        local db = HM.db
        if not db or not db.layoutApplied then return end
        if db.hideTracker then Layout:HideBlizzardTracker() end
        if db.hideBlizzMeter then Layout:HideBlizzardMeter(false) end
        for name in pairs(db.hiddenFrames or {}) do
            local f = _G[name]
            if f and f.Hide and not inCombatProtected(f) then
                pcall(f.Hide, f)
                if not f.hmHooked then
                    f.hmHooked = true
                    pcall(f.HookScript, f, "OnShow", function(fr) if HM.db.hiddenFrames and HM.db.hiddenFrames[name] then pcall(fr.Hide, fr) end end)
                end
            end
        end
    end)
end)

-- Eklenti yüklenirken (EllesmereUI çerçevelerini kurmadan önce) yalnız profil değerlerini yaz:
-- böylece düzen sürümü ilerlediğinde ikinci bir /reload gerekmez.
HM:On("ADDON_LOADED", function(_, name)
    if name ~= ADDON then return end
    local db = HM.db
    if not (db and db.layoutApplied) or (db.layoutVersion or 0) >= Layout.VERSION then return end
    if type(_G.EllesmereUIDB) ~= "table" then return end
    local ok, changed = pcall(Layout.HealthEliteProfile, Layout)
    db.earlyProfile = ok and (changed and "yazıldı" or "zaten uygun") or ("hata: " .. tostring(changed))
    pcall(function() local P = _G.EllesmereUIDB; P.spellUprank = P.spellUprank or {}; P.spellUprank.enabled = true end)
end)

HM:On("PLAYER_REGEN_ENABLED", function()
    local db = HM.db
    if not db or not db.layoutApplied then return end
    if db.hideTracker then Layout:HideBlizzardTracker() end
    if db.hideBlizzMeter then Layout:HideBlizzardMeter(false) end
end)
