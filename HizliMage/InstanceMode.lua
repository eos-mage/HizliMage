---------------------------------------------------------------------------
-- InstanceMode.lua: zindan/raid içindeyken dış dünya hatırlatmalarını susturur.
--
-- Kayıtlı ayarlara DOKUNMAZ: yalnızca HM.inInstance bayrağını tutar. XP buff,
-- kamp ve kitap hatırlatmaları, mob seviye uyarısı, ot/maden yakınlık uyarısı
-- ve rare uyarısı bu bayrağa bakarak susar. Zindandan çıkınca (ya da zindanda
-- /reload olsa bile) her şey kullanıcının kendi ayarıyla devam eder.
--
-- (2.14–2.16 sürümleri ayarları geçici olarak "kapalı" yazıp çıkışta geri
-- alıyordu; zindanda /reload olursa kapalı kalabiliyordu. Bu yüzden değişti.)
---------------------------------------------------------------------------
local _, ns = ...
local HM = ns.HM
if not HM then return end

local IM = {}
HM.InstanceMode = IM

HM.inInstance = false

function IM:Check(quiet)
    if not IsInInstance then return end
    local ok, inInst, instType = pcall(IsInInstance)
    local inside = (ok and inInst and (instType == "party" or instType == "raid")) and true or false
    if inside == HM.inInstance then return end
    HM.inInstance = inside
    if quiet then return end
    if inside then
        HM:Print("Zindan modu: dış dünya hatırlatmaları (XP buff, kamp, kitap, mob seviyesi, ot/maden) çıkana kadar susturuldu.")
    else
        HM:Print("Zindandan çıktın: hatırlatmalar kendi ayarlarınla devam ediyor.")
    end
end

HM:OnLogin(function()
    HM:On("PLAYER_ENTERING_WORLD", function() HM:After(1, function() IM:Check() end, "zindan modu") end)
    HM:On("ZONE_CHANGED_NEW_AREA", function() HM:After(0.5, function() IM:Check() end, "zindan modu") end)
    HM:After(2, function() IM:Check() end, "zindan modu")
end)
