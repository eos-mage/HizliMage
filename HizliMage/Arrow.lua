-- Yön oku: hedefe uzaklık ve yön. Mümkünse Blizzard'ın kendi harita işaretini de koyar.

local ADDON, ns = ...
local HM = ns.HM
local Arrow = {}
HM.Arrow = Arrow

local atan2 = math.atan2 or function(y, x) return math.atan(y, x) end
local sqrt = math.sqrt
local FONT = "Fonts\\ARIALN.TTF"

local frame
local target          -- { m, x, y, label, kind, wx, wy, cont }
local arrived = false

local function SetFont(fs, size, flags)
    pcall(fs.SetFont, fs, FONT, size, flags or "OUTLINE")
    if not fs:GetFont() then fs:SetFontObject(GameFontHighlightSmall) end
end
ns.SetFont = SetFont

function Arrow:Create()
    if frame then return end
    local db = HM.db
    frame = CreateFrame("Frame", "HizliMageArrow", UIParent)
    frame:SetSize(120, 96)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, _, x, y = self:GetPoint()
        db.arrow.point, db.arrow.x, db.arrow.y = point, x, y
    end)

    frame.tex = frame:CreateTexture(nil, "ARTWORK")
    frame.tex:SetSize(52, 52)
    frame.tex:SetPoint("TOP", 0, 0)
    frame.tex:SetTexture("Interface\\AddOns\\" .. ADDON .. "\\media\\arrow")

    frame.dist = frame:CreateFontString(nil, "OVERLAY")
    SetFont(frame.dist, 15)
    frame.dist:SetPoint("TOP", frame.tex, "BOTTOM", 0, -2)

    frame.label = frame:CreateFontString(nil, "OVERLAY")
    SetFont(frame.label, 12)
    frame.label:SetPoint("TOP", frame.dist, "BOTTOM", 0, -1)
    frame.label:SetWidth(220)
    frame.label:SetTextColor(1, 0.82, 0)

    -- Ok gizli olsa da varış kontrolü çalışsın diye ayrı bir sürücü kare.
    local driver = CreateFrame("Frame")
    driver:SetScript("OnUpdate", function(self, elapsed)
        self.acc = (self.acc or 0) + elapsed
        if self.acc < 0.05 then return end
        self.acc = 0
        Arrow:Update()
    end)
    self:Reposition()
    self:Refresh()
end

function Arrow:Reposition()
    if not frame then return end
    local a = HM.db.arrow
    frame:ClearAllPoints()
    frame:SetPoint(a.point or "TOP", UIParent, a.point or "TOP", a.x or 0, a.y or -110)
end

function Arrow:Refresh()
    if not frame then return end
    if HM.db.arrow.shown and target then frame:Show() else frame:Hide() end
end

function Arrow:GetTarget() return target end

-- kind: "step", "aoe", "trainer", "dungeon"
function Arrow:SetTarget(m, x, y, label, kind)
    if not (m and x and y) then
        target = nil
        self:ClearNative()
        self:Refresh()
        return
    end
    target = { m = m, x = x, y = y, label = label or "", kind = kind or "step" }
    target.wx, target.wy, target.cont = HM:MapWorldPos(m, x, y)
    arrived = false
    self:SetNative(target)
    self:Refresh()
    if frame then
        frame.label:SetText(HM:T(target.label))
    end
end

function Arrow:Update()
    if not target or not frame then return end
    local visible = frame:IsShown()
    if not target.wx then
        target.wx, target.wy, target.cont = HM:MapWorldPos(target.m, target.x, target.y)
    end
    local ok, px, py, pc = pcall(HM.PlayerWorldPos, HM)
    if not ok or not px or not target.wx then
        if visible then
            frame.tex:Hide()
            frame.dist:SetText(HM:T(HM:MapName(target.m)))
        end
        return
    end
    if pc ~= target.cont then
        if visible then
            frame.tex:Hide()
            frame.dist:SetText(HM:T("Başka kıta: " .. HM:MapName(target.m)))
        end
        return
    end
    local dn = target.wx - px   -- kuzey bileşeni
    local dw = target.wy - py   -- batı bileşeni
    local dist = sqrt(dn * dn + dw * dw)

    if visible then
        local facing = GetPlayerFacing and GetPlayerFacing()
        if facing and not HM.IsSecret(facing) then
            -- Yön: kuzeyden saat yönünün tersine; dokuyu oyuncunun baktığı yöne göre döndür.
            frame.tex:SetRotation(atan2(dw, dn) - facing)
            frame.tex:Show()
        else
            frame.tex:Hide()
        end
        if dist < 40 then
            frame.tex:SetVertexColor(0.35, 1, 0.35)
        elseif dist < 250 then
            frame.tex:SetVertexColor(1, 0.85, 0.2)
        else
            frame.tex:SetVertexColor(1, 1, 1)
        end
        frame.dist:SetText(string.format("%d yd", math.floor(dist)))
    end

    if not arrived and dist <= 15 then
        arrived = true
        if HM.Guide then HM.Guide:OnArrive(target, dist) end
    end
    if HM.Guide and HM.Guide.OnDistance then HM.Guide:OnDistance(target, dist) end
end

---------------------------------------------------------------------------
-- Blizzard harita işareti ve TomTom (varsa)
---------------------------------------------------------------------------
function Arrow:SetNative(t)
    local db = HM.db
    if db.nativeWaypoint and C_Map and C_Map.SetUserWaypoint and UiMapPoint and UiMapPoint.CreateFromCoordinates then
        local can = true
        if C_Map.CanSetUserWaypointOnMap then
            local ok, res = pcall(C_Map.CanSetUserWaypointOnMap, t.m)
            can = ok and res
        end
        if can then
            local point = UiMapPoint.CreateFromCoordinates(t.m, t.x / 100, t.y / 100)
            if pcall(C_Map.SetUserWaypoint, point) and C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
                pcall(C_SuperTrack.SetSuperTrackedUserWaypoint, true)
            end
        end
    end
    if db.tomtom and TomTom and TomTom.AddWaypoint then
        if self.tomtomUID and TomTom.RemoveWaypoint then pcall(TomTom.RemoveWaypoint, TomTom, self.tomtomUID) end
        local ok, uid = pcall(TomTom.AddWaypoint, TomTom, t.m, t.x / 100, t.y / 100,
            { title = "Hızlı Mage: " .. (t.label or ""), persistent = false, minimap = true, world = true })
        if ok then self.tomtomUID = uid end
    end
end

function Arrow:ClearNative()
    if C_Map and C_Map.ClearUserWaypoint and HM.db and HM.db.nativeWaypoint then
        pcall(C_Map.ClearUserWaypoint)
    end
    if self.tomtomUID and TomTom and TomTom.RemoveWaypoint then
        pcall(TomTom.RemoveWaypoint, TomTom, self.tomtomUID)
        self.tomtomUID = nil
    end
end

HM:OnLogin(function() Arrow:Create() end)
