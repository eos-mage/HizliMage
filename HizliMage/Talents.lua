-- Talent otomasyonu (WoW Forever, C_Traits API'si): seviye atlayınca Route.lua'daki
-- planın o seviyedeki talent'ini kendisi alır ve chat'e yazar. Aynı yol EllesmereUI'ın
-- Classic Talents penceresinde de kullanılıyor: PurchaseRank (puanı yerleştir) →
-- C_ClassTalents.CommitConfig (öğren). Komutlar: /hm talent oto|uygula|api

local ADDON, ns = ...
local HM = ns.HM
local Talents = {}
HM.Talents = Talents

local FONT = "Fonts\\ARIALN.TTF"
local pending      -- bekleyen deneme (seviye)
local blocked      -- istemci otomatik çağrıyı engelledi → tek tıklık düğme
local popup

local function db() return HM.db end

---------------------------------------------------------------------------
-- Ağaç okuma
---------------------------------------------------------------------------
local function apiOK()
    return C_ClassTalents and C_Traits and C_ClassTalents.GetActiveConfigID
        and C_Traits.GetConfigInfo and C_Traits.GetTreeNodes and C_Traits.GetNodeInfo
        and C_Traits.PurchaseRank and C_ClassTalents.CommitConfig
end

local function config()
    if not apiOK() then return nil end
    local configID = C_ClassTalents.GetActiveConfigID()
    local info = configID and C_Traits.GetConfigInfo(configID)
    local treeID = info and info.treeIDs and info.treeIDs[1]
    if not treeID then return nil end
    return configID, treeID
end

local function nodeName(configID, info)
    local entryID = (info.activeEntry and info.activeEntry.entryID) or (info.entryIDs and info.entryIDs[1])
    local entry = entryID and C_Traits.GetEntryInfo(configID, entryID)
    local def = entry and entry.definitionID and C_Traits.GetDefinitionInfo(entry.definitionID)
    if not def then return nil end
    local name = def.overrideName
    if (not name or name == "") and def.spellID and C_Spell and C_Spell.GetSpellName then
        name = C_Spell.GetSpellName(def.spellID)
    end
    if HM.IsSecret and HM.IsSecret(name) then return nil end
    return name, def.spellID
end

local function num(v, default)
    if v == nil or (HM.IsSecret and HM.IsSecret(v)) then return default end
    return tonumber(v) or default
end

-- Düğümün alınmış rank'ı (yerleştirilmiş ama henüz öğrenilmemiş puan dahil)
local function rankOf(configID, nodeID, info)
    info = info or C_Traits.GetNodeInfo(configID, nodeID)
    if not info then return 0 end
    return num(info.ranksPurchased, nil) or num(info.activeRank, 0)
end

-- Ağaçtaki görünür talentler: byName[küçük ad] = { nodeID, info, spellID, name }
local function scan()
    local configID, treeID = config()
    if not configID then return nil end
    local byName = {}
    for _, nodeID in ipairs(C_Traits.GetTreeNodes(treeID)) do
        local info = C_Traits.GetNodeInfo(configID, nodeID)
        if info and info.isVisible and info.entryIDs and info.entryIDs[1] then
            local name, spellID = nodeName(configID, info)
            if name then
                byName[name:lower()] = { nodeID = nodeID, spellID = spellID, name = name,
                    base = rankOf(configID, nodeID, info), max = num(info.maxRanks, 0), can = info.canPurchaseRank }
            end
        end
    end
    return configID, treeID, byName
end

local function unspent(configID, treeID)
    local list = C_Traits.GetTreeCurrencyInfo and C_Traits.GetTreeCurrencyInfo(configID, treeID, false)
    local c = list and list[1]
    return num(c and c.quantity, 0)
end

-- "Precision (2/3)" → "Precision", 2, 3
local function parse(text)
    if type(text) ~= "string" then return nil end
    local name, r, m = text:match("^(.-)%s*%((%d+)/(%d+)%)")
    if not name then return nil end
    return name, tonumber(r), tonumber(m)
end

-- Oyunun kendi penceresinin seçili loadout'u (EllesmereUI ile aynı mantık): aktif
-- config'in kendi kimliği ya da başlangıç build'i ise nil → yalnız aktif config'e işle.
local function savedConfigID(configID)
    local spec = C_SpecializationInfo and C_SpecializationInfo.GetSpecialization
        and C_SpecializationInfo.GetSpecialization()
    local specID = spec and C_SpecializationInfo.GetSpecializationInfo(spec)
    if not specID or not C_ClassTalents.GetLastSelectedSavedConfigID then return nil end
    local saved = C_ClassTalents.GetLastSelectedSavedConfigID(specID)
    local consts = Constants and Constants.TraitConsts
    if saved == configID or (consts and saved == consts.STARTER_BUILD_TRAIT_CONFIG_ID) then return nil end
    return saved
end

---------------------------------------------------------------------------
-- Planı uygulama
---------------------------------------------------------------------------
-- 10..level arası plandaki eksik rank'ları sırayla yerleştirir (puan bitince durur).
-- Dönüş: alınanlar listesi { {name=, rank=, max=, spellID=, nodeID=} }, sorun metni, kalan puan
local function stage(level)
    local configID, treeID, byName = scan()
    if not configID then return nil, "talent API'si bulunamadı" end
    local points = unspent(configID, treeID)
    if points <= 0 then return {}, nil, 0, configID end
    local got, problem = {}, nil
    local added = {}
    for lvl = 10, level do
        if points <= 0 then break end
        local name, rank = parse(ns.Talents and ns.Talents[lvl])
        if name then
            local t = byName[name:lower()]
            if not t then
                problem = problem or ("'" .. name .. "' bu ağaçta yok (plan güncellenmeli)")
            else
                local have = math.max(rankOf(configID, t.nodeID), t.base + (added[t.nodeID] or 0))
                if have < rank then
                    local fresh = C_Traits.GetNodeInfo(configID, t.nodeID)
                    if fresh and fresh.canPurchaseRank and C_Traits.PurchaseRank(configID, t.nodeID) then
                        added[t.nodeID] = (added[t.nodeID] or 0) + 1
                        points = points - 1
                        got[#got + 1] = { name = t.name, rank = have + 1, max = (t.max > 0 and t.max) or rank, spellID = t.spellID, nodeID = t.nodeID }
                    else
                        problem = problem or (t.name .. " şu an alınamıyor (sıra puanı/ön koşul eksik)")
                        break
                    end
                end
            end
        end
    end
    return got, problem, points, configID
end

local function describe(got)
    local parts = {}
    for _, g in ipairs(got) do parts[#parts + 1] = string.format("%s (%d/%d)", g.name, g.rank, g.max) end
    return table.concat(parts, ", ")
end

local function banner(title, sub, spellID)
    if HM.Alerts and HM.Alerts.Show then
        local icon = spellID and C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(spellID)
        HM.Alerts:Show("bilgi", title, sub, icon, 5, "talent")
    end
end

-- 1.5 sn sonra sunucunun onayını kontrol eder.
local function verify(configID, got)
    C_Timer.After(1.5, function()
        local okAll = true
        for _, g in ipairs(got) do
            if rankOf(configID, g.nodeID) < g.rank then okAll = false end
        end
        if okAll then
            HM:Print("|cff80ff80Talent öğrenildi:|r " .. describe(got))
            local last = got[#got]
            banner("Talent: " .. last.name .. string.format(" (%d/%d)", last.rank, last.max),
                #got > 1 and describe(got) or "Plana göre otomatik alındı", last.spellID)
        else
            HM:Print("|cffff8080Talent onaylanmadı|r (" .. describe(got) .. "). Talent penceresinden kontrol et; /hm talent uygula ile yeniden dene.")
        end
    end)
end

-- Yerleştir + öğren. Dönüş: true = işlem yapıldı/başlatıldı
local function apply(level, manual)
    if blocked and not manual then
        Talents:ShowButton(level)
        return false
    end
    local got, problem, left, configID = stage(level)
    if not got then
        if manual then HM:Print("Talent: " .. tostring(problem)) end
        return false
    end
    if #got == 0 then
        if manual then
            HM:Print(problem and ("Talent: " .. problem) or "Talent: harcanmamış puan yok, plan güncel.")
        elseif problem then
            HM:Print("Talent: " .. problem)
        end
        return false
    end
    local ok = C_ClassTalents.CommitConfig(savedConfigID(configID))
    if not ok then
        if C_Traits.RollbackConfig then C_Traits.RollbackConfig(configID) end
        if HM:InCombat() then
            HM:Print("Talent: savaş bitince alınacak (" .. describe(got) .. ").")
            pending = level
        else
            HM:Print("|cffff8080Talent öğrenilemedi|r (" .. describe(got) .. "). Düğmeye tıkla ya da talent penceresini kullan.")
            Talents:ShowButton(level)
        end
        return false
    end
    if problem then HM:Print("Talent notu: " .. problem) end
    if left > 0 then HM:Print("Talent: " .. left .. " puan daha harcanabilir (/hm talent uygula).") end
    verify(configID, got)
    return true
end

---------------------------------------------------------------------------
-- Engellenirse: tek tıklık düğme (tıklama = donanım olayı, EllesmereUI'ın penceresi gibi)
---------------------------------------------------------------------------
function Talents:ShowButton(level)
    if not popup then
        popup = CreateFrame("Frame", "HizliMageTalentPopup", UIParent, "BackdropTemplate")
        popup:SetSize(300, 64)
        popup:SetPoint("TOP", 0, -300)
        popup:SetFrameStrata("HIGH")
        popup:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
        popup:SetBackdropColor(0.05, 0.05, 0.08, 0.92)
        popup:SetBackdropBorderColor(0.6, 0.85, 1, 0.9)
        popup:EnableMouse(true)
        popup:SetMovable(true)
        popup:RegisterForDrag("LeftButton")
        popup:SetScript("OnDragStart", popup.StartMoving)
        popup:SetScript("OnDragStop", popup.StopMovingOrSizing)
        popup.text = popup:CreateFontString(nil, "OVERLAY")
        popup.text:SetFont(FONT, 15, "OUTLINE")
        popup.text:SetPoint("TOPLEFT", 10, -8)
        popup.text:SetPoint("TOPRIGHT", -10, -8)
        popup.text:SetJustifyH("LEFT")
        popup.btn = CreateFrame("Button", nil, popup, "UIPanelButtonTemplate")
        popup.btn:SetSize(140, 24)
        popup.btn:SetPoint("BOTTOMLEFT", 10, 8)
        popup.btn:SetText("Talent'i öğren")
        popup.btn:SetScript("OnClick", function()
            popup:Hide()
            apply(popup.level or HM:Level(), true)
        end)
        popup.close = CreateFrame("Button", nil, popup, "UIPanelButtonTemplate")
        popup.close:SetSize(90, 24)
        popup.close:SetPoint("BOTTOMRIGHT", -10, 8)
        popup.close:SetText("Sonra")
        popup.close:SetScript("OnClick", function() popup:Hide() end)
    end
    popup.level = level
    local hint = ns.Talents and ns.Talents[level]
    popup.text:SetText(HM:T(string.format("Seviye %d talent: %s", level, hint or "plana göre")))
    popup:Show()
end

---------------------------------------------------------------------------
-- Olaylar
---------------------------------------------------------------------------
local function tryLater(level, attempt)
    local delays = { 2, 5, 10 }
    local d = delays[attempt]
    if not d then return end
    C_Timer.After(d, function()
        if not (db() and db().autoTalent) then return end
        if HM:InCombat() then pending = level; return end
        local configID, treeID = config()
        if not configID then return end
        if unspent(configID, treeID) <= 0 then
            tryLater(level, attempt + 1)   -- puan henüz düşmedi
            return
        end
        apply(level, false)
    end)
end

HM:On("PLAYER_LEVEL_UP", function(_, level)
    level = tonumber(level) or HM:Level()
    if level < 10 or not (db() and db().autoTalent) then return end
    tryLater(level, 1)
end)

HM:On("PLAYER_REGEN_ENABLED", function()
    if pending and db() and db().autoTalent then
        local level = pending
        pending = nil
        C_Timer.After(1, function() apply(level, false) end)
    end
end)

-- İstemci otomatik çağrıyı engellerse: Blizzard'ın "eklentiyi kapat" penceresini kapat, düğmeyi göster.
local function forbidden(_, addon, func)
    if addon ~= ADDON then return end
    if type(func) == "string" and (func:find("CommitConfig") or func:find("PurchaseRank")) then
        blocked = true
        if StaticPopup_Hide then StaticPopup_Hide("ADDON_ACTION_FORBIDDEN") end
        HM:Print("Bu istemci talent'in otomatik alınmasına izin vermiyor; bundan sonra tek tıklık düğme çıkacak.")
        Talents:ShowButton(HM:Level())
    end
end
HM:On("ADDON_ACTION_FORBIDDEN", forbidden)
HM:On("ADDON_ACTION_BLOCKED", forbidden)

-- Girişte harcanmamış puan varsa (eski seviyeler) planı tamamlar.
HM:OnLogin(function()
    C_Timer.After(14, function()
        if not (db() and db().autoTalent) or HM:Level() < 10 then return end
        local configID, treeID = config()
        if configID and unspent(configID, treeID) > 0 and not HM:InCombat() then
            HM:Print("Harcanmamış talent puanı var, plana göre alınıyor...")
            apply(HM:Level(), false)
        end
    end)
end)

---------------------------------------------------------------------------
-- Komutlar: /hm talent oto | uygula | api
---------------------------------------------------------------------------
function Talents:Command(arg)
    arg = (arg or ""):lower()
    if arg == "oto" or arg == "otomatik" then
        db().autoTalent = not db().autoTalent
        HM:Print("Otomatik talent " .. (db().autoTalent and "|cff80ff80açık|r: seviye atlayınca plandaki talent kendisi alınır." or "|cffff8080kapalı|r: yalnız öneri yazılır."))
    elseif arg == "uygula" or arg == "al" then
        apply(HM:Level(), true)
    elseif arg == "api" then
        local configID, treeID, byName = scan()
        if not configID then HM:Print("Talent API'si yok (C_ClassTalents/C_Traits)."); return end
        local n = 0
        for _ in pairs(byName) do n = n + 1 end
        HM:Print(string.format("config %s, ağaç %s, %d talent, harcanmamış puan %d, otomatik %s",
            tostring(configID), tostring(treeID), n, unspent(configID, treeID), db().autoTalent and "açık" or "kapalı"))
        local missing, seen = {}, {}
        for lvl = 10, 60 do
            local name = parse(ns.Talents and ns.Talents[lvl])
            if name and not seen[name] then
                seen[name] = true
                local t = byName[name:lower()]
                if t then
                    HM:Print(string.format("  %s: node %d, %d/%d%s", name, t.nodeID, rankOf(configID, t.nodeID),
                        t.max, t.can and " (alınabilir)" or ""))
                else
                    missing[#missing + 1] = name
                end
            end
        end
        if #missing > 0 then HM:Print("|cffff8080Ağaçta bulunamayan plan adları:|r " .. table.concat(missing, ", ")) end
    else
        return false
    end
    return true
end
