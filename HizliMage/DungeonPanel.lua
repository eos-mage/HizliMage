---------------------------------------------------------------------------
-- DungeonPanel.lua: zindana/raid'e girince küçük bilgi penceresi aç.
-- İçerik:
--   * Zindan adı, tag ve seviye aralığı
--   * Kısa açıklama (ör. "Silverpine Forest, Undead dostu zindan")
--   * Boss listesi + her boss için notu (ns.ExpandNote ile sınıfa göre açılır)
-- Zindandan/raid'den çıkınca panel kapanır. Elle göster/gizle: /hm bilgi
---------------------------------------------------------------------------
local _, ns = ...
local HM = ns.HM
if not HM then return end

local Panel = {}
HM.DungeonPanel = Panel

local WIDTH, HEIGHT = 340, 340

local frame
local function build()
    frame = CreateFrame("Frame", "HM_DungeonPanel", UIParent, "BackdropTemplate")
    frame:SetSize(WIDTH, HEIGHT)
    frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 20, -220)
    frame:SetFrameStrata("MEDIUM")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    if frame.SetBackdrop then
        frame:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 20,
            insets = { left = 6, right = 6, top = 6, bottom = 6 },
        })
    end

    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.title:SetPoint("TOP", 0, -12)
    -- Türkçe karakterleri (ı ğ ş ç ö ü) doğru çizmek için ARIALN.TTF
    if frame.title.SetFont then pcall(frame.title.SetFont, frame.title, "Fonts\\ARIALN.TTF", 12, "OUTLINE") end
    frame.title:SetText(HM:T("HizliMage - Zindan bilgisi"))

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -4, -4)
    close:SetScript("OnClick", function() frame:Hide() end)

    local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 12, -36)
    scroll:SetPoint("BOTTOMRIGHT", -28, 12)

    local body = CreateFrame("Frame", nil, scroll)
    body:SetSize(WIDTH - 44, HEIGHT)
    scroll:SetScrollChild(body)

    body.text = body:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    body.text:SetPoint("TOPLEFT", 0, 0)
    body.text:SetPoint("TOPRIGHT", 0, 0)
    body.text:SetJustifyH("LEFT")
    body.text:SetJustifyV("TOP")
    body.text:SetSpacing(2)
    body.text:SetWordWrap(true)
    -- Türkçe karakter için ARIALN (default FRIZQT bazı Türkçe glifleri doğru çizmiyor)
    if body.text.SetFont then pcall(body.text.SetFont, body.text, "Fonts\\ARIALN.TTF", 12, "") end
    frame.body = body
    frame:Hide()
end

local function currentInstance()
    if not IsInInstance or not GetInstanceInfo then return nil end
    local inInst = IsInInstance()
    if not inInst then return nil end
    local name, instType = GetInstanceInfo()
    if instType ~= "party" and instType ~= "raid" then return nil end
    return name, instType
end

-- Boss notlarını tablodan sıralı çıkar (lvl alanı hariç).
local function bossList(notes)
    local out = {}
    if type(notes) ~= "table" then return out end
    for k, v in pairs(notes) do
        if k ~= "lvl" and type(v) == "string" then
            out[#out + 1] = { boss = k, note = v }
        end
    end
    table.sort(out, function(a, b) return a.boss < b.boss end)
    return out
end

function Panel:Refresh()
    if not frame then build() end
    local name, instType = currentInstance()
    if not name then frame:Hide(); return end

    local data = (HM.Dungeons and HM.Dungeons.data and HM.Dungeons.data[name]) or nil
    local notes = ns.DungeonNotes and ns.DungeonNotes[name] or nil

    local lines = {}
    local header = string.format("|cffffd100%s|r", name)
    if data then
        header = header .. string.format("  |cff888888(%s, seviye %d-%d)|r", data.tag or "", data.minLvl or 0, data.maxLvl or 0)
    elseif notes and notes.lvl then
        header = header .. string.format("  |cff888888(seviye %s)|r", notes.lvl)
    end
    lines[#lines + 1] = header
    if data and data.short then
        lines[#lines + 1] = "|cff80bbdd" .. data.short .. "|r"
    end
    lines[#lines + 1] = ""

    local list = bossList(notes)
    if #list == 0 then
        lines[#lines + 1] = "|cff888888Bu zindan için kaydedilmiş boss notu yok.|r"
        lines[#lines + 1] = "|cff888888HizliMage'in genel zindan listesi için|r |cffffd100/hm zindan|r"
    else
        for _, b in ipairs(list) do
            local expanded = (ns.ExpandNote and ns.class) and ns.ExpandNote(b.note, ns.class) or b.note
            lines[#lines + 1] = "|cffffd100" .. b.boss .. "|r"
            lines[#lines + 1] = "  " .. expanded
            lines[#lines + 1] = ""
        end
    end

    if instType == "raid" then
        frame.title:SetText(HM:T("HizliMage - Raid bilgisi"))
    else
        frame.title:SetText(HM:T("HizliMage - Zindan bilgisi"))
    end
    frame.body.text:SetText(HM:T(table.concat(lines, "\n")))
    frame.body.text:SetWidth(WIDTH - 44)
    frame.body:SetHeight(math.max(HEIGHT, frame.body.text:GetStringHeight() + 20))
    frame:Show()
end

function Panel:Hide()
    if frame then frame:Hide() end
end

function Panel:Toggle()
    if not frame then build() end
    if frame:IsShown() then frame:Hide() else self:Refresh() end
end

HM:OnLogin(function()
    HM:On("PLAYER_ENTERING_WORLD", function() C_Timer.After(2, function() pcall(Panel.Refresh, Panel) end) end)
    HM:On("ZONE_CHANGED_NEW_AREA", function() C_Timer.After(1, function() pcall(Panel.Refresh, Panel) end) end)
end)
