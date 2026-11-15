-- XP/saat, seviyeye kalan süre, dinlenmiş XP, altın/saat ve binek hedefi.

local ADDON, ns = ...
local HM = ns.HM
local Stats = {}
HM.Stats = Stats

local WINDOW = 15 * 60          -- son 15 dakikanın hızı
local sessionStart, gained = nil, 0
local lastXP, lastMax, lastLevel
local samples = {}              -- { t = zaman, g = toplam kazanılan XP }
local income, lastMoney = 0, nil

local function now() return GetTime() end

local function pushSample()
    local t = now()
    samples[#samples + 1] = { t = t, g = gained }
    -- 1 dakikadan sık örnek tutma, pencere dışını at
    while #samples > 2 and samples[2].t < t - WINDOW do
        table.remove(samples, 1)
    end
end

function Stats:Rate()
    if not sessionStart then return 0 end
    local t = now()
    local first
    for i = 1, #samples do
        if samples[i].t >= t - WINDOW then first = samples[i]; break end
    end
    local elapsed, delta
    if first and (t - first.t) > 60 then
        elapsed, delta = t - first.t, gained - first.g
    else
        elapsed, delta = t - sessionStart, gained
    end
    if elapsed < 60 then return 0 end
    return delta / elapsed * 3600
end

function Stats:XPText()
    local level = HM:Level()
    if level >= 60 then return "60. seviye: kasma bitti." end
    local xp, max = UnitXP("player") or 0, UnitXPMax("player") or 1
    local rem = max - xp
    local pct = math.floor(xp / max * 100)
    local rate = self:Rate()
    local eta = (rate > 0) and (rem / rate * 3600) or nil
    local rested = GetXPExhaustion and GetXPExhaustion() or 0
    local parts = {}
    -- İlk göze çarpan: kalan XP ve yüzde.
    parts[#parts + 1] = string.format("Kalan %s XP (%%%d)", HM:Short(rem), pct)
    if rate > 0 then
        parts[#parts + 1] = string.format("XP/sa %s", HM:Short(rate))
    end
    if eta then
        parts[#parts + 1] = string.format("Seviyeye %s", HM:Duration(eta))
    end
    if rested and rested > 0 then
        parts[#parts + 1] = string.format("Dinlenmiş %%%d", math.floor(rested / max * 100))
    end
    return table.concat(parts, "  •  ")
end

function Stats:GoldText()
    local money = GetMoney() or 0
    local hours = sessionStart and ((now() - sessionStart) / 3600) or 0
    local perHour = (hours > 0.02) and (income / hours) or 0
    local level = HM:Level()
    local target = (level < 40) and HM.db.goldTarget or HM.db.epicTarget
    local goal = (level < 40) and "Binek 40" or "Epik 60"
    local g = math.floor(money / 10000)
    local txt = string.format("%s: %d/%d altın", goal, g, target)
    if perHour > 0 then
        txt = string.format("Altın/sa %s  •  %s", HM:Money(perHour), txt)
    end
    return txt
end

local function onXP()
    local xp, max = UnitXP("player") or 0, UnitXPMax("player") or 1
    if lastXP then
        local delta
        if xp < lastXP then
            -- seviye atlandı: eski seviyenin kalanı + yeni seviyedeki XP
            delta = (lastMax - lastXP) + xp
        else
            delta = xp - lastXP
        end
        if delta > 0 then gained = gained + delta end
    end
    lastXP, lastMax, lastLevel = xp, max, HM:Level()
    pushSample()
end

local function onMoney()
    local m = GetMoney() or 0
    if lastMoney and m > lastMoney then income = income + (m - lastMoney) end
    lastMoney = m
end

HM:OnLogin(function()
    sessionStart = now()
    lastXP, lastMax, lastLevel = UnitXP("player") or 0, UnitXPMax("player") or 1, HM:Level()
    lastMoney = GetMoney() or 0
    pushSample()
end)

HM:On("PLAYER_XP_UPDATE", onXP)
HM:On("PLAYER_MONEY", onMoney)

-- WoW'un kendi XP barının (MainMenuExpBar) tooltip'ine "Kalan XP" ve ETA ekle.
HM:OnLogin(function()
    local bar = _G.MainMenuExpBar or _G.StatusTrackingBarManager
    if not bar or not bar.HookScript then return end
    local function enrich()
        if HM:Level() >= 60 then return end
        local xp = UnitXP("player") or 0
        local max = UnitXPMax("player") or 1
        local rem = max - xp
        local pct = math.floor(xp / max * 100)
        local rested = GetXPExhaustion and GetXPExhaustion() or 0
        if not GameTooltip:IsShown() then
            GameTooltip:SetOwner(bar, "ANCHOR_CURSOR")
            GameTooltip:AddLine("XP", 1, 0.82, 0)
        end
        GameTooltip:AddLine(string.format("|cff80ff80Seviyeye kalan:|r %s XP (%%%d)", HM:Short(rem), pct), 1, 1, 1)
        if rested and rested > 0 then
            GameTooltip:AddLine(string.format("|cff8080ffDinlenmiş:|r %s XP", HM:Short(rested)), 1, 1, 1)
        end
        local rate = Stats:Rate()
        if rate > 0 then
            local eta = rem / rate * 3600
            GameTooltip:AddLine(string.format("|cffffd100Son 15 dk hız:|r %s XP/sa  →  %s", HM:Short(rate), HM:Duration(eta)), 1, 1, 1)
        end
        GameTooltip:Show()
    end
    pcall(bar.HookScript, bar, "OnEnter", enrich)
    -- Eski WoW istemcilerinde ExhaustionTick (dinlenme kabarcığı) kendi tooltip'ini açar.
    if _G.ExhaustionTick and _G.ExhaustionTick.HookScript then
        pcall(_G.ExhaustionTick.HookScript, _G.ExhaustionTick, "OnEnter", enrich)
    end
end)
