-- Büyü eğitimi: seviye atlayınca hatırlatma, eğitmende tek tıkla "önerilenleri al",
-- toplama mesleği sınırı uyarıları ve talent önerisi.

local ADDON, ns = ...
local HM = ns.HM
local Trainer = {}
HM.Trainer = Trainer

local FONT = "Fonts\\ARIALN.TTF"
local popup
local buying = false

-- Sınıf eğitmenini tanımak için o sınıfın temel büyü adları (İngilizce istemci).
local markerCache
local function isMarker(name)
    if not markerCache or markerCache.class ~= ns.class then
        markerCache = { class = ns.class }
        for _, n in ipairs((ns.CD or ns.ClassData.MAGE).markers) do markerCache[n] = true end
    end
    return markerCache[name] == true
end

local function rankNumber(sub)
    if not sub then return nil end
    return tonumber(tostring(sub):match("(%d+)"))
end

---------------------------------------------------------------------------
-- Hatırlatmalar
---------------------------------------------------------------------------
function Trainer:PendingText()
    local db = HM.db
    local out = {}
    if db.trainPending and db.trainPending > 0 then
        out[#out + 1] = string.format("Eğitim bekliyor: %d. seviye büyüleri", db.trainPending)
    end
    if self.profNote then out[#out + 1] = self.profNote end
    return table.concat(out, "  •  ")
end

function Trainer:PointTrainer(kind)
    local list
    if not kind or kind == "class" then
        list = (ns.CD or ns.ClassData.MAGE).trainers
    else
        list = ns.Trainers[kind]
    end
    local t = HM:Nearest(list)
    if t and HM.Arrow then
        HM.Arrow:SetTarget(t.m, t.x, t.y, t.n, "trainer")
        HM:Print("Ok en yakın eğitmende: " .. t.n .. " (" .. HM:MapName(t.m) .. "). Başlığa tıklayınca adıma döner.")
    end
end

function Trainer:TalentHint(level, force)
    local hint = ns.Talents[level]
    if not hint then
        if force then HM:Print("Bu seviye için talent önerisi yok (talentler 10'da başlar).") end
        return
    end
    HM:Print("Talent (" .. level .. "): |cff80ff80" .. hint .. "|r")
    if ns.class ~= "MAGE" and level == 10 then
        HM:Print("Not: Forever talent ağaçlarını değiştirdi; bu sıra Classic'e göre, talent ekranında karşılaştır.")
    end
    if ns.class == "MAGE" and level == 20 then
        HM:Print("AoE ağırlıklı gideceksen Improved Blizzard'ı açılır açılmaz öne al; Forever'da Blizzard yavaşlatması zayıflatıldı.")
    end
end

HM:On("PLAYER_LEVEL_UP", function(_, level)
    level = tonumber(level) or HM:Level()
    -- Mage yeni büyüleri çift seviyelerde öğrenir.
    local cd = ns.CD or ns.ClassData.MAGE
    if level % 2 == 0 then
        HM.db.trainPending = level
        local t = HM:Nearest(cd.trainers)
        HM:Print(string.format("Seviye %d: yeni yetenekler var. En yakın eğitmen: %s", level, t and t.n or "?"))
    end
    if level >= 10 then Trainer:TalentHint(level) end
    if cd.milestones and cd.milestones[level] then
        HM:Print("|cffffd100" .. cd.milestones[level] .. "|r")
    end
    if level == 40 then
        if ns.race == "Tauren" then
            HM:Print("40! Binek: Kar Stormsinger (Bloodhoof Village), Apprentice Riding + kodo 100 altın.")
        else
            HM:Print("40! Binek: Kildar (Orgrimmar, Valley of Honor), Apprentice Riding + binek 100 altın.")
        end
    end
    C_Timer.After(2, function() Trainer:CheckProfessions() end)
end)

---------------------------------------------------------------------------
-- Meslek sınırı (Apprentice 75 / Journeyman 150 / Expert 225)
---------------------------------------------------------------------------
local TIER_LEVEL = { [75] = 10, [150] = 20, [225] = 35 }
local PROF_KIND = { ["Herbalism"] = "herb", ["Mining"] = "mine", ["Skinning"] = "skin", ["First Aid"] = "firstaid" }

local function scanProfessions()
    local out = {}
    if GetProfessions and GetProfessionInfo then
        local list = { GetProfessions() }
        for i = 1, 6 do
            local idx = list[i]
            if idx then
                local name, _, rank, maxRank = GetProfessionInfo(idx)
                if name then out[#out + 1] = { name = name, rank = rank or 0, max = maxRank or 0 } end
            end
        end
    elseif GetNumSkillLines and GetSkillLineInfo then
        for i = 1, GetNumSkillLines() do
            local name, isHeader, _, rank, _, _, maxRank = GetSkillLineInfo(i)
            if name and not isHeader and PROF_KIND[name] then
                out[#out + 1] = { name = name, rank = rank or 0, max = maxRank or 0 }
            end
        end
    end
    return out
end

function Trainer:CheckProfessions()
    local level = HM:Level()
    local notes = {}
    for _, p in ipairs(scanProfessions()) do
        local need = TIER_LEVEL[p.max]
        if need and p.rank >= p.max - 5 and level >= need then
            local kind = PROF_KIND[p.name]
            local t = kind and HM:Nearest(ns.Trainers[kind])
            local msg = string.format("%s %d/%d: bir üst kademe için eğitmene git%s", p.name, p.rank, p.max, t and (" (" .. t.n .. ")") or "")
            notes[#notes + 1] = string.format("%s %d/%d", p.name, p.rank, p.max)
            local key = p.name .. p.max
            if not HM.db.reminded[key] then
                HM.db.reminded[key] = true
                HM:Print(msg)
            end
        end
    end
    self.profNote = (#notes > 0) and ("Meslek sınırı: " .. table.concat(notes, ", ")) or nil
end

HM:On("SKILL_LINES_CHANGED", function()
    C_Timer.After(0.5, function() Trainer:CheckProfessions() end)
end)
HM:OnLogin(function() C_Timer.After(3, function() Trainer:CheckProfessions() end) end)

---------------------------------------------------------------------------
-- Akıllı satın alma
---------------------------------------------------------------------------
local function shouldSkip(name, sub)
    local db = HM.db
    local cd = ns.CD or ns.ClassData.MAGE
    -- Kullanıcının /hm atla ile verdiği karar sınıf varsayılanından önce gelir.
    if db.trainSkip[name] ~= nil then return db.trainSkip[name] end
    if cd.skip[name] then return true end
    if cd.skipAfter10[name] and HM:Level() >= 10 then return true end
    if cd.singleRank[name] and (rankNumber(sub) or 1) >= 2 then return true end
    return false
end
Trainer.ShouldSkip = shouldSkip

-- Eğitmendeki alınabilir büyüleri tarar: önerilenler, atlananlar, toplam maliyet.
local function scanServices()
    local rec, skipped, cost, isMage = {}, {}, 0, false
    local n = GetNumTrainerServices and GetNumTrainerServices() or 0
    for i = 1, n do
        local name, sub, category = GetTrainerServiceInfo(i)
        if name and isMarker(name) then isMage = true end
        if name and category == "available" then
            local price = GetTrainerServiceCost and GetTrainerServiceCost(i) or 0
            local label = name .. ((sub and sub ~= "") and (" (" .. sub .. ")") or "")
            if shouldSkip(name, sub) then
                skipped[#skipped + 1] = label
            else
                rec[#rec + 1] = { index = i, name = name, sub = sub, label = label, cost = price or 0 }
                cost = cost + (price or 0)
            end
        end
    end
    return rec, skipped, cost, isMage
end

local function createPopup()
    popup = CreateFrame("Frame", "HizliMageTrainerPopup", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    popup:SetSize(260, 110)
    popup:SetFrameStrata("DIALOG")
    popup:SetClampedToScreen(true)
    popup:SetMovable(true)
    popup:EnableMouse(true)
    popup:RegisterForDrag("LeftButton")
    popup:SetScript("OnDragStart", popup.StartMoving)
    popup:SetScript("OnDragStop", popup.StopMovingOrSizing)
    if popup.SetBackdrop then
        popup:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 14,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        popup:SetBackdropColor(0.05, 0.06, 0.1, 0.92)
        popup:SetBackdropBorderColor(0.25, 0.65, 0.95, 0.9)
    end
    popup.text = popup:CreateFontString(nil, "OVERLAY")
    pcall(popup.text.SetFont, popup.text, FONT, 12, "")
    if not popup.text:GetFont() then popup.text:SetFontObject(GameFontHighlightSmall) end
    popup.text:SetPoint("TOPLEFT", 10, -10)
    popup.text:SetWidth(240)
    popup.text:SetJustifyH("LEFT")

    popup.buy = CreateFrame("Button", nil, popup, "UIPanelButtonTemplate")
    popup.buy:SetSize(150, 22)
    popup.buy:SetPoint("BOTTOMLEFT", 10, 10)
    popup.buy:SetScript("OnClick", function() Trainer:BuyRecommended() end)
    local fs = popup.buy:GetFontString()
    if fs then pcall(fs.SetFont, fs, FONT, 12, "") end

    popup.close = CreateFrame("Button", nil, popup, "UIPanelCloseButton")
    popup.close:SetSize(22, 22)
    popup.close:SetPoint("TOPRIGHT", 0, 0)
end

function Trainer:UpdatePopup()
    if not popup then return end
    local rec, skipped, cost = scanServices()
    local lines = {}
    if #rec == 0 then
        lines[1] = "Alınacak önerilen büyü yok."
        popup.buy:Disable()
    else
        lines[1] = string.format("Önerilen %d büyü: %s", #rec, HM:Money(cost))
        local names = {}
        for i = 1, math.min(#rec, 6) do names[#names + 1] = rec[i].label end
        if #rec > 6 then names[#names + 1] = "…" end
        lines[2] = "|cffb0b0b0" .. table.concat(names, ", ") .. "|r"
        if GetMoney() < cost then
            lines[#lines + 1] = "|cffff6060Para yetmiyor; sırayla alınabilenler alınır.|r"
        end
        popup.buy:Enable()
    end
    if #skipped > 0 then
        lines[#lines + 1] = "|cff909090Atlanan: " .. table.concat(skipped, ", ") .. "|r"
    end
    popup.text:SetText(HM:T(table.concat(lines, "\n")))
    popup.buy:SetText(HM:T(buying and "Alınıyor…" or "Önerilenleri al"))
    popup:SetHeight(popup.text:GetStringHeight() + 50)
end

function Trainer:BuyRecommended()
    if buying then return end
    buying = true
    local bought, spent = 0, 0
    local function step()
        if not popup or not popup:IsShown() then buying = false; return end
        local rec = scanServices()
        local nextItem
        for _, r in ipairs(rec) do
            if r.cost <= GetMoney() then nextItem = r; break end
        end
        if not nextItem then
            buying = false
            if bought > 0 then
                HM:Print(string.format("%d büyü alındı (%s).", bought, HM:Money(spent)))
            end
            Trainer:UpdatePopup()
            return
        end
        BuyTrainerService(nextItem.index)
        bought = bought + 1
        spent = spent + nextItem.cost
        C_Timer.After(0.35, step)
    end
    self:UpdatePopup()
    step()
end

-- Liste TRAINER_SHOW anında boş gelebilir; TRAINER_UPDATE ile tekrar denenir.
function Trainer:TryShow()
    if not self.trainerOpen then return end
    if IsTradeskillTrainer and IsTradeskillTrainer() then return end
    local _, _, _, isMage = scanServices()
    if isMage then self.atMageTrainer = true end
    if not self.atMageTrainer or not HM.db.smartTrain then return end
    if not popup then createPopup() end
    if not popup:IsShown() then
        popup:ClearAllPoints()
        if ClassTrainerFrame and ClassTrainerFrame:IsShown() then
            popup:SetPoint("TOPLEFT", ClassTrainerFrame, "TOPRIGHT", 4, -20)
        else
            popup:SetPoint("CENTER", UIParent, "CENTER", 260, 80)
        end
        popup:Show()
    end
    if not buying then self:UpdatePopup() end
end

HM:On("TRAINER_SHOW", function()
    Trainer.trainerOpen = true
    Trainer.atMageTrainer = false
    if not (IsTradeskillTrainer and IsTradeskillTrainer()) and SetTrainerServiceTypeFilter then
        pcall(SetTrainerServiceTypeFilter, "available", 1)
    end
    Trainer:TryShow()
end)

HM:On("TRAINER_UPDATE", function()
    Trainer:TryShow()
end)

HM:On("TRAINER_CLOSED", function()
    Trainer.trainerOpen = false
    if popup then popup:Hide() end
    buying = false
    if Trainer.atMageTrainer then
        Trainer.atMageTrainer = false
        HM.db.trainPending = 0
        if HM.Guide then HM.Guide:OnTrained() end
    end
end)
