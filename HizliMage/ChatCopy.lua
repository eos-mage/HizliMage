---------------------------------------------------------------------------
-- ChatCopy.lua: sohbeti kopyalanabilir bir pencerede gösterir (/hm kopya).
--
-- Satırlar doğrudan sohbet çerçevesinin kendi geçmişinden okunur
-- (GetNumMessages / GetMessageInfo). Renk kodları, simgeler ve bağlantı
-- sarmalayıcıları ayıklanır; pencerede düz metin kalır: Ctrl+A, Ctrl+C.
--
-- (2.11–2.16 sürümleri sohbet çerçevelerinin AddMessage işlevini sarıyordu.
-- O yöntem hem pencereye ham kaçış kodlarını basıyordu hem de sohbetin kendi
-- akışına karışıyordu; kaldırıldı.)
---------------------------------------------------------------------------
local _, ns = ...
local HM = ns.HM
if not HM then return end

local ChatCopy = {}
HM.ChatCopy = ChatCopy

local MAX_LINES = 500

-- Kaçış kodlarını ayıkla: geriye görünen metin kalsın.
local function clean(s)
    s = s:gsub("||", "\001")                      -- gerçek dik çizgiyi koru
    s = s:gsub("|c%x%x%x%x%x%x%x%x", "")          -- |cAARRGGBB
    s = s:gsub("|cn[%w_]+:", "")                  -- |cnADLI_RENK:
    s = s:gsub("|r", "")
    s = s:gsub("|T.-|t", "")                      -- doku
    s = s:gsub("|A.-|a", "")                      -- atlas
    s = s:gsub("|H.-|h(.-)|h", "%1")              -- bağlantı: görünen metni bırak
    s = s:gsub("|K.-|k", "")                      -- korumalı ad
    s = s:gsub("|n", "\n")
    s = s:gsub("|", "")                           -- kalan tanınmayan kodlar editbox'ı bozmasın
    s = s:gsub("\001", "|")
    return s
end
ChatCopy.Clean = clean

-- Seçili (yoksa varsayılan) sohbet çerçevesinin son satırları.
function ChatCopy:Collect()
    local lines = {}
    local cf = SELECTED_CHAT_FRAME or DEFAULT_CHAT_FRAME or _G.ChatFrame1
    if not (cf and cf.GetNumMessages and cf.GetMessageInfo) then return lines, false end
    local okN, n = pcall(cf.GetNumMessages, cf)
    if not okN or type(n) ~= "number" then return lines, false end
    for i = math.max(1, n - MAX_LINES + 1), n do
        local ok, text = pcall(cf.GetMessageInfo, cf, i)
        if ok and type(text) == "string" and not HM.IsSecret(text) then
            local okC, c = pcall(clean, text)
            if okC and c ~= "" then lines[#lines + 1] = c end
        end
    end
    return lines, true
end

local popup
local function makePopup()
    popup = CreateFrame("Frame", "HM_ChatCopyPopup", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    popup:SetSize(720, 460)
    popup:SetPoint("CENTER")
    popup:SetFrameStrata("DIALOG")
    popup:SetMovable(true)
    popup:EnableMouse(true)
    popup:RegisterForDrag("LeftButton")
    popup:SetScript("OnDragStart", function(self) self:StartMoving() end)
    popup:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    popup:Hide()
    if popup.SetBackdrop then
        popup:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 24,
            insets = { left = 8, right = 8, top = 8, bottom = 8 },
        })
    end

    local title = popup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", 0, -12)
    pcall(title.SetFont, title, "Fonts\\ARIALN.TTF", 13, "")
    title:SetText(HM:T("Sohbet kopyala — Ctrl+A hepsini seçer, Ctrl+C kopyalar, Esc kapatır"))
    popup.title = title

    local close = CreateFrame("Button", nil, popup, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -6, -6)

    local scroll = CreateFrame("ScrollFrame", nil, popup, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 16, -36)
    scroll:SetPoint("BOTTOMRIGHT", -32, 48)
    popup.scroll = scroll

    local edit = CreateFrame("EditBox", nil, scroll)
    edit:SetMultiLine(true)
    if ChatFontNormal then edit:SetFontObject(ChatFontNormal) end
    edit:SetAutoFocus(false)
    edit:SetWidth(660)
    edit:SetScript("OnEscapePressed", function() popup:Hide() end)
    scroll:SetScrollChild(edit)
    popup.edit = edit

    local btnAll = CreateFrame("Button", nil, popup, "UIPanelButtonTemplate")
    btnAll:SetSize(140, 22)
    btnAll:SetPoint("BOTTOMLEFT", 16, 14)
    btnAll:SetText(HM:T("Hepsini seç"))
    btnAll:SetScript("OnClick", function()
        edit:SetFocus()
        edit:HighlightText()
    end)

    local btnRefresh = CreateFrame("Button", nil, popup, "UIPanelButtonTemplate")
    btnRefresh:SetSize(140, 22)
    btnRefresh:SetPoint("LEFT", btnAll, "RIGHT", 10, 0)
    btnRefresh:SetText(HM:T("Yenile"))
    btnRefresh:SetScript("OnClick", function() ChatCopy:Show() end)

    if UISpecialFrames then table.insert(UISpecialFrames, "HM_ChatCopyPopup") end
end

function ChatCopy:Show()
    local lines, readable = self:Collect()
    if not readable then
        HM:Print("Bu istemcide sohbet geçmişi okunamıyor (GetMessageInfo yok).")
        return
    end
    if not popup then makePopup() end
    local text = table.concat(lines, "\n")
    popup.edit:SetText(text)
    popup:Show()
    popup.edit:SetCursorPosition(#text)
    popup.edit:SetFocus()
    popup.edit:HighlightText()
    if #lines == 0 then HM:Print("Sohbet penceresinde kopyalanacak satır yok.") end
end
