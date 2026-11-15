---------------------------------------------------------------------------
-- LFG.lua: Looking For Group sıra beklerken, seviyesi benden yüksek olan ve
-- içlerinde mage olmayan grupların leader'larına otomatik mesaj at.
--
-- Spam riskini azaltmak için:
--   * Varsayılan KAPALI; /hm lfg ac ile açılır
--   * Aynı leader'a THROTTLE (10 dk) içinde tekrar mesaj yok
--   * Bir seansta en fazla MAX_PER_SESSION (10) whisper
--   * Mesaj gönderimleri arasında 2 sn ara (SendChatMessage flood'una karşı)
--   * Sadece LFG listesi yenilendiğinde tarar (kullanıcı bir aktivitede arıyor demektir)
--   * Oyuncu gruptaysa / rehber çalışmıyorsa devre dışı
--
-- Komutlar:
--   /hm lfg              : durum
--   /hm lfg ac|on        : aç
--   /hm lfg kapat|off    : kapat
--   /hm lfg mesaj <...>  : whisper şablonu (içinde %d varsa seviyen yerleşir)
--   /hm lfg sifirla      : ping log'u temizle
---------------------------------------------------------------------------
local _, ns = ...
local HM = ns.HM
if not HM then return end

local LFG = {}
HM.LFG = LFG

local DEFAULT_MSG = "Selam! %d. seviye frost mage'im — stabil DPS, cooldown yönetimi ve Polymorph CC hazır. DPS slotu açıksa beni tercih ederseniz boşa düşmezsiniz. :)"
local THROTTLE = 10 * 60      -- aynı leader'a tekrar en erken 10 dk sonra
local MAX_PER_SESSION = 10
local MIN_INTERVAL = 2.0      -- whisper'lar arası en az 2 sn

local sent = {}               -- leaderName -> timestamp
local sentCount = 0
local lastSendAt = 0
local queue = {}              -- gönderilecek {leader, msg}

-- Flood'suz whisper kuyruğu: 2 sn aralıklarla SendChatMessage.
local function pumpQueue()
    if #queue == 0 then return end
    local now = GetTime()
    if now - lastSendAt < MIN_INTERVAL then
        C_Timer.After(MIN_INTERVAL - (now - lastSendAt) + 0.05, pumpQueue)
        return
    end
    local item = table.remove(queue, 1)
    if item and item.leader and item.msg then
        pcall(SendChatMessage, item.msg, "WHISPER", nil, item.leader)
        lastSendAt = now
        sentCount = sentCount + 1
        sent[item.leader] = now
        HM:Print(string.format("|cff8080ffLFG:|r '%s' leader'ına yazıldı — %d/%d",
            item.leader, sentCount, MAX_PER_SESSION))
    end
    if #queue > 0 then C_Timer.After(MIN_INTERVAL + 0.05, pumpQueue) end
end

local function enqueue(leader, msg)
    queue[#queue + 1] = { leader = leader, msg = msg }
    pumpQueue()
end

-- Grup üyelerini tara: mage var mı, tank sayısı, healer sayısı.
-- Dönüş: hasMage (true/false; üye bilgisi okunamadıysa nil), tankCount, healerCount.
--
-- Bu istemcide üye bilgisi C_LFGList.GetSearchResultPlayerInfo(resultID, i) ile gelir:
-- { name, level, className, classFilename, specName, assignedRole, lfgRoles, isLeader, ... }
-- (Blizzard API belgesi, LFGListInfo). Eski ad GetSearchResultMemberInfo yedek olarak durur.
-- Üye bilgisi okunamazsa nil döner; çağıran taraf bunu "mage olabilir" sayıp yazmaz.
local function scanMembers(resultID, numMembers)
    local api = C_LFGList and (C_LFGList.GetSearchResultPlayerInfo or C_LFGList.GetSearchResultMemberInfo)
    if not api then return nil, 0, 0 end
    local mage, tanks, heals, read = false, 0, 0, 0
    for i = 1, (numMembers or 0) do
        local ok, r1, r2 = pcall(api, resultID, i)
        if ok and r1 ~= nil and not HM.IsSecret(r1) then
            local role, class
            if type(r1) == "table" then
                role = r1.assignedRole or r1.role
                class = r1.classFilename or r1.class
            else
                role, class = r1, r2
            end
            if not HM.IsSecret(role) and not HM.IsSecret(class) and (role ~= nil or class ~= nil) then
                read = read + 1
                if class == "MAGE" then mage = true end
                if role == "TANK" then tanks = tanks + 1
                elseif role == "HEALER" then heals = heals + 1 end
            end
        end
    end
    if read == 0 and (numMembers or 0) > 0 then return nil, 0, 0 end
    return mage, tanks, heals
end

local function activityMinLevel(activityID)
    if not activityID or not C_LFGList then return 0 end
    local get = C_LFGList.GetActivityInfoTable or C_LFGList.GetActivityInfo
    if not get then return 0 end
    local ok, info = pcall(get, activityID)
    if not ok or not info then return 0 end
    if type(info) == "table" then
        return info.minLevel or info.minLevelSuggestion or info.iLevel or 0
    end
    return 0
end

-- Yeni API'de info.activityIDs bir tablo. İçindeki ID'lerden en yüksek minLevel'ı bul.
local function infoMinLevel(info)
    if type(info) ~= "table" then return 0 end
    if info.activityID then return activityMinLevel(info.activityID) end
    local ids = info.activityIDs
    if type(ids) ~= "table" then return 0 end
    local best = 0
    for _, id in ipairs(ids) do
        local n = activityMinLevel(id)
        if n > best then best = n end
    end
    return best
end

local function processResult(resultID)
    local db = HM.db and HM.db.lfg
    if not db or not db.on then return end
    if sentCount >= MAX_PER_SESSION then return end
    if not (C_LFGList and C_LFGList.GetSearchResultInfo) then return end
    local ok, info = pcall(C_LFGList.GetSearchResultInfo, resultID)
    if not ok or not info then return end
    local leader = (type(info) == "table") and info.leaderName or nil
    if not leader or leader == "" or leader == (UnitName("player") or "") then return end
    -- Throttle
    local now = GetTime()
    if sent[leader] and (now - sent[leader]) < THROTTLE then return end
    -- Seviye kontrolü: aktivitenin min seviyesi > benim seviyem
    local minLvl = infoMinLevel(info)
    local myLvl = UnitLevel("player") or 1
    if minLvl <= myLvl then return end
    -- Mage var mı, tank ve healer var mı?
    local numM = (type(info) == "table") and info.numMembers or 0
    local mage, tanks, heals = scanMembers(resultID, numM)
    if mage ~= false then return end           -- mage var ya da üye bilgisi okunamadı: yazma
    if tanks < 1 and heals < 1 then return end  -- en az tank ya da healer olmalı (biri yeter)
    -- Hepsi tamam — kuyruğa at
    local tmpl = db.msg or DEFAULT_MSG
    local msg = (tmpl:find("%%d") and tmpl:format(myLvl)) or tmpl
    enqueue(leader, msg)
end

function LFG:OnResults()
    local db = HM.db and HM.db.lfg
    if not db or not db.on then return end
    if UnitInParty("player") or UnitInRaid("player") then return end
    if not (C_LFGList and C_LFGList.GetSearchResults) then return end
    local ok, a, b = pcall(C_LFGList.GetSearchResults)
    if not ok then return end
    local list = (type(b) == "table" and b) or (type(a) == "table" and a) or nil
    if not list then return end
    for _, id in ipairs(list) do pcall(processResult, id) end
end

-- Teşhis: ilk sonucun RAW API dönüşünü ekrana basar — field adlarını görmek için.
function LFG:Detay()
    if not (C_LFGList and C_LFGList.GetSearchResults) then
        HM:Print("|cffff6060C_LFGList yok|r"); return
    end
    local ok, a, b = pcall(C_LFGList.GetSearchResults)
    local list = (type(b) == "table" and b) or (type(a) == "table" and a) or nil
    if not list or #list == 0 then HM:Print("Liste boş — önce LFG'de Ara"); return end
    -- 2+ üyeli bir sonuç seç (gerçek grup); yoksa ilk sonucu al
    local id
    for _, rid in ipairs(list) do
        local ok2, info = pcall(C_LFGList.GetSearchResultInfo, rid)
        if ok2 and type(info) == "table" and (info.numMembers or 0) >= 2 then id = rid; break end
    end
    id = id or list[1]
    HM:Print("|cffffd100--- LFG detay, resultID " .. tostring(id) .. " ---|r")
    local okI, info = pcall(C_LFGList.GetSearchResultInfo, id)
    HM:Print("GetSearchResultInfo ok=" .. tostring(okI) .. " type=" .. type(info))
    if type(info) == "table" then
        for k, v in pairs(info) do HM:Print("  info." .. tostring(k) .. " = " .. tostring(v)) end
    else
        HM:Print("  info = " .. tostring(info))
    end
    -- activityIDs (çoğul) tablosundan hepsini çöz
    local actIDs = (type(info) == "table") and info.activityIDs or nil
    if type(actIDs) == "table" then
        for _, actID in ipairs(actIDs) do
            HM:Print("|cffffd100--- GetActivityInfoTable(" .. tostring(actID) .. ") ---|r")
            local getAct = C_LFGList.GetActivityInfoTable or C_LFGList.GetActivityInfo
            if getAct then
                local okA, act = pcall(getAct, actID)
                HM:Print("ok=" .. tostring(okA) .. " type=" .. type(act))
                if type(act) == "table" then
                    for k, v in pairs(act) do HM:Print("  act." .. tostring(k) .. " = " .. tostring(v)) end
                else
                    HM:Print("  act = " .. tostring(act))
                end
            end
        end
    end
    HM:Print("|cffffd100--- MemberInfo denemeleri (ilk 2 üye) ---|r")
    local numM = (type(info) == "table") and info.numMembers or 0
    for i = 1, math.min(numM, 2) do
        local tried = false
        for _, fn in ipairs({"GetSearchResultPlayerInfo", "GetSearchResultMemberInfo", "GetSearchResultMemberCounts"}) do
            if C_LFGList[fn] then
                tried = true
                local okM, r1, r2, r3, r4, r5, r6 = pcall(C_LFGList[fn], id, i)
                if okM and type(r1) == "table" then
                    local parts = {}
                    for k, v in pairs(r1) do parts[#parts + 1] = tostring(k) .. "=" .. tostring(v) end
                    table.sort(parts)
                    HM:Print(string.format("  m%d %s -> { %s }", i, fn, table.concat(parts, ", ")))
                else
                    HM:Print(string.format("  m%d %s ok=%s r1=%s r2=%s r3=%s r4=%s r5=%s r6=%s",
                        i, fn, tostring(okM), tostring(r1), tostring(r2), tostring(r3), tostring(r4), tostring(r5), tostring(r6)))
                end
            end
        end
        if not tried then HM:Print("  m" .. i .. " hiçbir member API yok") end
    end
    HM:Print("|cffffd100--- C_LFGList API listesi ---|r")
    local fns = {}
    for k, v in pairs(C_LFGList) do if type(v) == "function" then fns[#fns + 1] = k end end
    table.sort(fns)
    HM:Print(table.concat(fns, ", "))
    HM:Print("|cffffd100--- /hm kopya ile kopyala ---|r")
end

-- Teşhis: manuel tarama + her sonucun neden elendiğini basar.
function LFG:Scan()
    if not (C_LFGList and C_LFGList.GetSearchResults) then
        HM:Print("|cffff6060C_LFGList API yok|r — modül bu istemcide çalışmıyor.")
        return
    end
    if UnitInParty("player") or UnitInRaid("player") then
        HM:Print("|cffff6060Grupta/raid'desin|r — tarama modu kapalı olur.")
    end
    local ok, a, b = pcall(C_LFGList.GetSearchResults)
    if not ok then
        HM:Print("|cffff6060GetSearchResults hata:|r " .. tostring(a))
        return
    end
    local list = (type(b) == "table" and b) or (type(a) == "table" and a) or nil
    if not list or #list == 0 then
        HM:Print("|cffff6060Liste boş|r — önce LFG penceresinde bir aktivite seçip |cffffd100Ara|r'ya bas, sonra |cffffd100/hm lfg tara|r.")
        return
    end
    local myLvl = UnitLevel("player") or 1
    HM:Print(string.format("LFG tara: |cffffd100%d|r sonuç geldi. Seviyen: %d.", #list, myLvl))
    local eligible = 0
    for _, id in ipairs(list) do
        local okInfo, info = pcall(C_LFGList.GetSearchResultInfo, id)
        if okInfo and info then
            local leader = (type(info) == "table") and info.leaderName or "?"
            local minLvl = infoMinLevel(info)
            local numM = (type(info) == "table") and info.numMembers or 0
            local mage, tanks, heals = scanMembers(id, numM)
            local reasons = {}
            if minLvl <= myLvl then reasons[#reasons+1] = string.format("minLvl %d ≤ %d", minLvl, myLvl) end
            if mage == nil then reasons[#reasons+1] = "üye bilgisi okunamadı"
            elseif mage then reasons[#reasons+1] = "mage var" end
            if mage ~= nil and tanks < 1 and heals < 1 then reasons[#reasons+1] = "tank/healer yok" end
            if sent[leader] and (GetTime() - sent[leader]) < THROTTLE then reasons[#reasons+1] = "throttle" end
            if #reasons == 0 then
                eligible = eligible + 1
                HM:Print(string.format("  |cff80ff80✓|r %s (minLvl %d, %d üye, T:%d H:%d, mage yok)", leader, minLvl, numM, tanks, heals))
            else
                HM:Print(string.format("  |cff888888×|r %s (minLvl %d, %d üye, T:%d H:%d) → %s", leader, minLvl, numM, tanks, heals, table.concat(reasons, ", ")))
            end
        end
    end
    HM:Print(string.format("Uygun: |cffffd100%d|r / %d. Oto-mesaj %s.", eligible, #list,
        (HM.db.lfg and HM.db.lfg.on) and "açık" or "KAPALI (önce /hm lfg ac)"))
end

function LFG:Toggle(on)
    HM.db.lfg = HM.db.lfg or { on = false, msg = DEFAULT_MSG }
    HM.db.lfg.on = on and true or false
    HM:Print("LFG oto-mesaj: " .. (HM.db.lfg.on and "|cff80ff80açık|r" or "|cffff6060kapalı|r"))
    if HM.db.lfg.on and not (C_LFGList and C_LFGList.GetSearchResults) then
        HM:Print("|cffff6060Uyarı:|r Bu istemcide C_LFGList API'si yok, mesajlar gitmeyecek.")
    end
end

function LFG:SetMessage(m)
    HM.db.lfg = HM.db.lfg or { on = false, msg = DEFAULT_MSG }
    if m and m ~= "" then
        HM.db.lfg.msg = m
        HM:Print("LFG mesaj şablonu güncellendi. İçinde %d varsa seviyen yerleşir.")
        HM:Print("Örnek çıktı: " .. (m:find("%%d") and m:format(UnitLevel("player") or 1) or m))
    else
        HM:Print("Mevcut şablon: " .. (HM.db.lfg.msg or DEFAULT_MSG))
    end
end

function LFG:Status()
    local db = HM.db.lfg or {}
    HM:Print(string.format("LFG oto-mesaj: %s", db.on and "|cff80ff80açık|r" or "|cffff6060kapalı|r"))
    HM:Print(string.format("Bu seans gönderilen: %d / %d (aynı leader'a 10 dk içinde tekrar yok)",
        sentCount, MAX_PER_SESSION))
    HM:Print(string.format("Şablon: %s", db.msg or DEFAULT_MSG))
    HM:Print(string.format("LFG API: %s",
        (C_LFGList and C_LFGList.GetSearchResults) and "|cff80ff80var|r" or "|cffff6060yok|r"))
end

function LFG:Reset()
    sent, sentCount = {}, 0
    queue = {}
    HM:Print("LFG ping log sıfırlandı.")
end

-- Grup/raid'e girdiysem oto-mesajı kapat (whispers'ı istem dışı durdurur).
local wasInGroup = false
local function onGroupChange()
    local inGroup = (UnitInParty and UnitInParty("player")) or (UnitInRaid and UnitInRaid("player"))
    if inGroup and not wasInGroup then
        if HM.db and HM.db.lfg and HM.db.lfg.on then
            HM.db.lfg.on = false
            HM:Print("|cff80ff80LFG oto-mesaj:|r gruba girdin, otomatik kapatıldı. Tekrar açmak için /hm lfg ac.")
        end
    end
    wasInGroup = inGroup and true or false
end

HM:OnLogin(function()
    HM.db.lfg = HM.db.lfg or { on = false, msg = DEFAULT_MSG }
    wasInGroup = (UnitInParty and UnitInParty("player")) or (UnitInRaid and UnitInRaid("player")) or false
    if C_LFGList then
        HM:On("LFG_LIST_SEARCH_RESULTS_RECEIVED", function()
            C_Timer.After(0.3, function() pcall(LFG.OnResults, LFG) end)
        end)
    end
    HM:On("GROUP_ROSTER_UPDATE", onGroupChange)
    HM:On("PARTY_LEADER_CHANGED", onGroupChange)
end)
