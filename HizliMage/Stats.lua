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
    local rate = self:Rate()
    local eta = (rate > 0) and ((max - xp) / rate * 3600) or nil
    local rested = GetXPExhaustion and GetXPExhaustion() or 0
    local parts = {}
    parts[#parts + 1] = string.format("XP/sa %s", rate > 0 and HM:Short(rate) or "—")
    parts[#parts + 1] = string.format("Seviyeye %s", eta and HM:Duration(eta) or "—")
    parts[#parts + 1] = string.format("%%%d", math.floor(xp / max * 100))
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
