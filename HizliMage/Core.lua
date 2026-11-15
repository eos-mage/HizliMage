-- Hızlı Mage v2: Horde 1-60 görev-görev hızlı kasma rehberi (WoW Forever / Classic Era)
-- Çekirdek: kayıtlı ayarlar, olay sistemi, uyumluluk yardımcıları, komutlar.

local ADDON, ns = ...
local HM = {}
ns.HM = HM
_G.HizliMage = HM

HM.name = ADDON
HM.version = "2.17.0"

do
    local _, _, _, iface = GetBuildInfo()
    HM.interface = tonumber(iface) or 0
    -- Forever istemcisi 16000-16999 aralığını kullanır (beta: 16001).
    HM.isForever = HM.interface >= 16000 and HM.interface < 17000
end

---------------------------------------------------------------------------
-- Varsayılan ayarlar (karakter başına kaydedilir)
---------------------------------------------------------------------------
local DEFAULTS = {
    step = 1,
    initialized = false,
    frame = { point = "RIGHT", x = -40, y = 120, scale = 1.0, shown = true, collapsed = false },
    arrow = { point = "TOP", x = 0, y = -110, shown = true },
    autoQuest = true,
    autoSell = true,
    autoRepair = true,
    smartTrain = true,
    nativeWaypoint = true,
    tomtom = true,
    ascii = false,
    debug = false,
    goldTarget = 100,      -- 40. seviye binek (Forever: Apprentice Riding + binek 100 altın)
    epicTarget = 1200,     -- 60. seviye epik binek (Forever: 1000 + 200 altın)
    waterMin = 10,
    trainSkip = {},        -- /hm atla ile kullanıcı kararları (true = atla, false = al)
    trainPending = 0,      -- eğitmene gidilmesi gereken son seviye (0 = yok)
    reminded = {},         -- meslek uyarıları (oturumlar arası tekrar etmesin)
    questSkip = {},        -- Tamam ile atlanan görevler (kimlik -> true)
    doneQ = {},            -- bu karakterin teslim ettiği görevler (kimlik -> true)
    routeVersion = 0,      -- rota biçimi değişince adım sayacı yeniden hizalanır
    hideTracker = false,   -- /hm duzen: Blizzard görev takipçisi gizli
    hideBlizzMeter = false, -- /hm duzen: yerleşik hasar ölçer gizli
    layoutApplied = false,
    layoutVersion = 0,     -- /hm duzen en son hangi yerleşim sürümüyle uygulandı
    alerts = { enabled = true, sound = true, nameplates = true, stealable = true, notes = true, cure = true },  -- zindan uyarıları
    castLog = {},          -- NPC → attığı büyüler (öğrenilen)
    autoTalent = true,     -- seviye atlayınca plandaki talent otomatik alınır (/hm talent oto)
    procs = { enabled = true, sound = true },   -- proc/donma göstergesi (/hm proc)
    hiddenFrames = {},     -- /hm gizle ile gizlenen çerçeveler
    xpBuffSilent = false,  -- XP buff hatırlatmasını sustur (/hm xp sessiz)
    autoSort = true,       -- çanta otomatik sıralama (satıcıdan sonra, yeni eşya alınca)
    buffRequestOff = false, -- otomatik buff isteme (yakındaki Priest/Druid/Paladin'a whisper)
    camp = { silent = false }, -- kamp/meslek buff'ları: hatırlatma, elle seçilen eşya (/hm kamp)
    books = { silent = false },   -- kütüphane kitapları: hatırlatma kapat/aç (/hm kitap sessiz)
    mapScale = 1.25,              -- dünya haritası ölçeği (0.7–2.0; /hm harita)
    minimapCoords = true,         -- minimap sağ üstte küçük koordinat (/hm koord)
    lfg = { on = false, msg = "Selam! %d. seviye frost mage'im — stabil DPS, cooldown yönetimi ve Polymorph CC hazır. DPS slotu açıksa beni tercih ederseniz boşa düşmezsiniz. :)" },
}
local ROUTE_VERSION = 2

local function copyDefaults(src, dst)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then dst[k] = {} end
            copyDefaults(v, dst[k])
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
end

---------------------------------------------------------------------------
-- Olay sistemi
---------------------------------------------------------------------------
local eventFrame = CreateFrame("Frame")
HM.handlers = {}
HM.loginFns = {}

function HM:On(event, fn)
    local list = self.handlers[event]
    if not list then
        local ok = pcall(eventFrame.RegisterEvent, eventFrame, event)
        if not ok then return false end
        list = {}
        self.handlers[event] = list
    end
    list[#list + 1] = fn
    return true
end

function HM:OnLogin(fn)
    self.loginFns[#self.loginFns + 1] = fn
end

---------------------------------------------------------------------------
-- Hata kaydı: yakalanan Lua hataları sessizce HizliMageDB.errors'a yazılır.
-- /hm hata ile listelenir; sorun bildirirken "çalışmıyor" yerine gerçek hata okunur.
---------------------------------------------------------------------------
HM.sessionErrors = 0
function HM:LogError(where, err)
    self.sessionErrors = (self.sessionErrors or 0) + 1
    local db = self.db
    if not db then return end
    if type(db.errors) ~= "table" then db.errors = {} end
    local msg = tostring(err)
    if #msg > 500 then msg = msg:sub(1, 500) .. "..." end
    local key = tostring(where) .. ": " .. msg
    local now = (time and time()) or 0
    local list = db.errors
    for i = 1, #list do
        if list[i].k == key then
            list[i].n = (list[i].n or 1) + 1
            list[i].t = now
            list[i].v = self.version
            if db.debug then self:Print("Hata (" .. tostring(where) .. "): " .. msg) end
            return
        end
    end
    list[#list + 1] = { k = key, n = 1, t = now, v = self.version }
    while #list > 30 do table.remove(list, 1) end
    if db.debug then self:Print("Hata (" .. tostring(where) .. "): " .. msg) end
end

function HM:ShowErrors(arg)
    local db = self.db
    arg = (arg or ""):lower()
    if arg == "temizle" or arg == "sil" or arg == "clear" then
        db.errors = {}
        self.sessionErrors = 0
        self:Print("Hata kaydı temizlendi.")
        return
    end
    local list = db.errors or {}
    if #list == 0 then
        self:Print("Kayıtlı hata yok.")
        return
    end
    self:Print(string.format("Kayıtlı %d hata (yeniden eskiye; |cffffd100/hm hata temizle|r siler):", #list))
    local shown = 0
    for i = #list, 1, -1 do
        local e = list[i]
        local when = (date and e.t and e.t > 0) and date("%d.%m %H:%M", e.t) or "?"
        self:Print(string.format("|cffff8080%s|r v%s x%d  %s", when, tostring(e.v or "?"), e.n or 1, tostring(e.k)))
        shown = shown + 1
        if shown >= 8 then break end
    end
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
    local list = HM.handlers[event]
    if not list then return end
    for i = 1, #list do
        local ok, err = pcall(list[i], event, ...)
        if not ok then HM:LogError(event, err) end
    end
end)

-- Zamanlayıcılar: C_Timer geri çağrıları korumasız çalışır; hata olursa kayda geçsin.
function HM:After(delay, fn, where)
    if not (C_Timer and C_Timer.After) then return end
    C_Timer.After(delay, function()
        local ok, err = pcall(fn)
        if not ok then HM:LogError(where or "zamanlayıcı", err) end
    end)
end

function HM:Ticker(interval, fn, where)
    if not (C_Timer and C_Timer.NewTicker) then return end
    return C_Timer.NewTicker(interval, function()
        local ok, err = pcall(fn)
        if not ok then HM:LogError(where or "sayaç", err) end
    end)
end

-- "Creature-0-4444-1-123-5831-0000ABCDEF" -> 5831 (oyuncu/evcil hayvan için nil)
function HM.NpcIdFromGUID(guid)
    if type(guid) ~= "string" or HM.IsSecret(guid) then return nil end
    local kind, id = guid:match("^(%a+)%-%d+%-%d+%-%d+%-%d+%-(%d+)%-")
    if kind == "Creature" or kind == "Vehicle" then return tonumber(id) end
    return nil
end

---------------------------------------------------------------------------
-- Metin yardımcıları
---------------------------------------------------------------------------
local TR_MAP = {
    { "ç", "c" }, { "Ç", "C" }, { "ğ", "g" }, { "Ğ", "G" }, { "ı", "i" }, { "İ", "I" },
    { "ö", "o" }, { "Ö", "O" }, { "ş", "s" }, { "Ş", "S" }, { "ü", "u" }, { "Ü", "U" },
    { "•", "-" }, { "…", "..." }, { "–", "-" }, { "—", "-" },
}

-- Türkçe karakterler kare görünürse /hm ascii ile sadeleştirilir.
function HM:T(s)
    if s == nil then return "" end
    s = tostring(s)
    if self.db and self.db.ascii then
        for i = 1, #TR_MAP do
            s = (s:gsub(TR_MAP[i][1], TR_MAP[i][2]))
        end
    end
    return s
end

function HM:Print(msg)
    local frame = DEFAULT_CHAT_FRAME or ChatFrame1
    if frame then
        frame:AddMessage(self:T("|cff3fc7ebHızlı Mage|r: " .. tostring(msg)))
    end
end

-- Dokular. İstemci yeni motor üzerinde; eski doku dosyalarının hepsinin durduğu garanti değil.
-- Bu yüzden her simge için bir aday listesi verilir ve bu istemcide gerçekten var olan ilki seçilir:
--   "atlas:Ad"  -> C_Texture.GetAtlasExists
--   dosya yolu  -> GetFileIDFromPath (yol istemcinin dosya listesinde yoksa nil döner)
-- Hiçbiri doğrulanamazsa son dosya adayı yine de denenir (eski davranış).
local iconCache = {}
HM.iconCache = iconCache

local function atlasExists(name)
    if not C_Texture then return false end
    if C_Texture.GetAtlasExists then
        local ok, r = pcall(C_Texture.GetAtlasExists, name)
        return ok and r and true or false
    end
    if C_Texture.GetAtlasInfo then
        local ok, r = pcall(C_Texture.GetAtlasInfo, name)
        return ok and r ~= nil
    end
    return false
end

-- Dönüş: tür ("atlas" | "file" | "file?" | nil), değer
function HM.ResolveIcon(cands)
    if type(cands) == "string" then cands = { cands } end
    local key = table.concat(cands, "|")
    local hit = iconCache[key]
    if hit then return hit[1], hit[2] end
    local kind, value
    for _, c in ipairs(cands) do
        local atlas = c:match("^atlas:(.+)$")
        if atlas then
            if atlasExists(atlas) then kind, value = "atlas", atlas; break end
        elseif GetFileIDFromPath then
            local ok, id = pcall(GetFileIDFromPath, c)
            if ok and type(id) == "number" and id > 0 then kind, value = "file", c; break end
        else
            kind, value = "file", c; break          -- denetlenemiyor: ilk dosyayı kullan
        end
    end
    if not kind then
        for i = #cands, 1, -1 do
            if not cands[i]:match("^atlas:") then kind, value = "file?", cands[i]; break end
        end
    end
    iconCache[key] = { kind, value }
    return kind, value
end

function HM.ApplyIcon(tex, cands)
    if not tex then return nil end
    if type(cands) == "string" then cands = { cands } end
    local kind, value = HM.ResolveIcon(cands)
    if kind == "atlas" then
        if tex.SetAtlas and pcall(tex.SetAtlas, tex, value) then return kind, value end
        kind, value = nil, nil                      -- atlas uygulanamadı: dosya adayına düş
        for i = #cands, 1, -1 do
            if not cands[i]:match("^atlas:") then kind, value = "file?", cands[i]; break end
        end
    end
    if value then
        tex:SetTexture(value)
        if tex.SetTexCoord then tex:SetTexCoord(0, 1, 0, 1) end   -- önceki atlasın kırpması kalmasın
    end
    return kind, value
end

-- Eski imza: tek atlas + tek dosya
function HM.SetIcon(tex, atlas, file)
    local cands = {}
    if atlas then cands[#cands + 1] = "atlas:" .. atlas end
    if file then cands[#cands + 1] = file end
    return HM.ApplyIcon(tex, cands)
end

function HM:Money(copper)
    copper = math.floor(tonumber(copper) or 0)
    local coin = (C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString) or GetCoinTextureString
    if coin then
        local ok, s = pcall(coin, copper)
        if ok and type(s) == "string" and s ~= "" then return s end
    end
    local g = math.floor(copper / 10000)
    local s = math.floor((copper % 10000) / 100)
    local c = copper % 100
    return string.format("%da %dg %db", g, s, c)
end

function HM:Short(n)
    n = tonumber(n) or 0
    if n >= 1000000 then return string.format("%.1fM", n / 1000000) end
    if n >= 1000 then return string.format("%.1fk", n / 1000) end
    return tostring(math.floor(n))
end

function HM:Duration(sec)
    sec = tonumber(sec)
    if not sec or sec <= 0 or sec ~= sec or sec == math.huge then return "?" end
    if sec < 60 then return "<1 dk" end
    local h = math.floor(sec / 3600)
    local m = math.floor((sec % 3600) / 60)
    if h > 0 then return string.format("%d sa %d dk", h, m) end
    return string.format("%d dk", m)
end

-- Midnight/Forever istemcisindeki "secret value" korumasına karşı.
function HM.IsSecret(v)
    if issecretvalue == nil or v == nil then return false end
    local ok, res = pcall(issecretvalue, v)
    return ok and res == true
end

function HM:SpellName(id)
    if C_Spell and C_Spell.GetSpellName then
        local ok, name = pcall(C_Spell.GetSpellName, id)
        if ok and name then return name end
    end
    if GetSpellInfo then
        local ok, name = pcall(GetSpellInfo, id)
        if ok then return name end
    end
end

function HM:Level()
    return UnitLevel("player") or 1
end

function HM:InCombat()
    return (InCombatLockdown and InCombatLockdown()) or (UnitAffectingCombat and UnitAffectingCombat("player"))
end

---------------------------------------------------------------------------
-- Harita / konum yardımcıları
---------------------------------------------------------------------------
-- Oyuncunun dünya koordinatı: x = kuzey, y = batı (HereBeDragons ile aynı eksenler).
function HM:PlayerWorldPos()
    if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition and C_Map.GetWorldPosFromMapPos) then return end
    local map = C_Map.GetBestMapForUnit("player")
    if not map or HM.IsSecret(map) then return end
    local pos = C_Map.GetPlayerMapPosition(map, "player")
    if not pos then return end
    local px, py = pos.x, pos.y
    if px == nil or HM.IsSecret(px) or HM.IsSecret(py) or (px == 0 and py == 0) then return end
    local cont, wpos = C_Map.GetWorldPosFromMapPos(map, pos)
    if not cont or not wpos then return end
    return wpos.x, wpos.y, cont, map
end

function HM:MapWorldPos(map, x, y)
    if not (map and x and y and CreateVector2D and C_Map and C_Map.GetWorldPosFromMapPos) then return end
    local ok, cont, wpos = pcall(C_Map.GetWorldPosFromMapPos, map, CreateVector2D(x / 100, y / 100))
    if not ok or not cont or not wpos then return end
    return wpos.x, wpos.y, cont
end

function HM:MapName(map)
    if map and C_Map and C_Map.GetMapInfo then
        local info = C_Map.GetMapInfo(map)
        if info and info.name then return info.name end
    end
    return "?"
end

-- Oyuncunun bulunduğu harita ve üst haritaları (bölge kontrolü için).
function HM:PlayerMapChain()
    local chain = {}
    if not (C_Map and C_Map.GetBestMapForUnit) then return chain end
    local map = C_Map.GetBestMapForUnit("player")
    local guard = 0
    while map and map > 0 and guard < 8 do
        chain[map] = true
        local info = C_Map.GetMapInfo and C_Map.GetMapInfo(map)
        map = info and info.parentMapID
        guard = guard + 1
    end
    return chain
end

-- Verilen nokta listesinden oyuncuya en yakın olanı (aynı kıta) döndürür.
function HM:Nearest(list)
    if not list then return end
    local px, py, pc = self:PlayerWorldPos()
    local best, bestD
    for _, p in ipairs(list) do
        local wx, wy, wc = self:MapWorldPos(p.m, p.x, p.y)
        if px and wx and wc == pc then
            local d = math.sqrt((wx - px) ^ 2 + (wy - py) ^ 2)
            if not bestD or d < bestD then best, bestD = p, d end
        end
    end
    return best or list[1], bestD
end

---------------------------------------------------------------------------
-- Görev günlüğü (Classic ve Forever/modern API)
---------------------------------------------------------------------------
function HM:GetQuestLog()
    local out = {}
    if C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetInfo then
        local n = C_QuestLog.GetNumQuestLogEntries() or 0
        for i = 1, n do
            local info = C_QuestLog.GetInfo(i)
            if info and not info.isHeader and info.title then
                local complete = info.questID and C_QuestLog.IsComplete and C_QuestLog.IsComplete(info.questID)
                out[#out + 1] = { title = info.title, id = info.questID, complete = complete and true or false }
            end
        end
    elseif GetNumQuestLogEntries and GetQuestLogTitle then
        local n = GetNumQuestLogEntries() or 0
        for i = 1, n do
            local title, _, _, isHeader, _, isComplete, _, questID = GetQuestLogTitle(i)
            if title and not isHeader then
                out[#out + 1] = { title = title, id = questID, complete = (isComplete == 1 or isComplete == true) }
            end
        end
    end
    return out
end

function HM:IsInQuestLog(questID, title)
    if questID and questID > 0 and C_QuestLog then
        if C_QuestLog.GetLogIndexForQuestID then
            local idx = C_QuestLog.GetLogIndexForQuestID(questID)
            if idx and idx > 0 then return true end
        end
        if C_QuestLog.IsOnQuest and C_QuestLog.IsOnQuest(questID) then return true end
    end
    for _, q in ipairs(self:GetQuestLog()) do
        if (questID and questID > 0 and q.id == questID) or (title and q.title == title) then
            return true
        end
    end
    return false
end

---------------------------------------------------------------------------
-- Yükleme
---------------------------------------------------------------------------
HM:On("ADDON_LOADED", function(_, name)
    if name ~= ADDON then return end
    if type(HizliMageDB) ~= "table" then HizliMageDB = {} end
    copyDefaults(DEFAULTS, HizliMageDB)
    HM.db = HizliMageDB
end)

HM:On("PLAYER_LOGIN", function()
    if not HM.db then
        if type(HizliMageDB) ~= "table" then HizliMageDB = {} end
        copyDefaults(DEFAULTS, HizliMageDB)
        HM.db = HizliMageDB
    end
    -- v1 hub rotasından v2 görev rotasına geçiş: eski adım numarası anlamsız, seviyeye göre yeniden yerleş.
    if HM.db.routeVersion ~= ROUTE_VERSION then
        HM.db.routeVersion = ROUTE_VERSION
        HM.db.initialized = false
        HM.db.step = 1
        HM.db.questSkip = {}
    end
    for i = 1, #HM.loginFns do
        local ok, err = pcall(HM.loginFns[i])
        if not ok then
            HM:LogError("giriş", err)
            HM:Print("Başlatma hatası: " .. tostring(err))
        end
    end
    local _, class = UnitClass("player")
    if not ns.ClassData[class] then
        HM:Print("Bu sınıf için özel rota yok; mage rotası ve genel yardımcılar çalışır.")
    end
    local cd = ns.CD
    HM:Print(string.format("v%s hazır: %s (%s), rota %d adım. Komutlar için |cffffd100/hm yardim|r", HM.version, UnitName("player") or "?", cd and cd.label or "?", #(ns.Route or {})))
end)

---------------------------------------------------------------------------
-- Etkileşim tuşu (Interact With Target): /hm tus F
-- Yakındaki görev NPC'si, posta kutusu, görev nesnesi tek tuşla; hedef almak gerekmez.
---------------------------------------------------------------------------
function HM:InteractKey()
    if GetBindingKey then
        local ok, k1 = pcall(GetBindingKey, "INTERACTTARGET")
        if ok and k1 then return k1 end
    end
end

function HM:BindInteract(key)
    key = (key or ""):upper():gsub("%s+", "")
    if key == "" then
        local cur = self:InteractKey()
        self:Print(cur and ("Etkileşim tuşu: " .. cur .. ". Değiştirmek için /hm tus G") or "Etkileşim tuşu bağlı değil. Örnek: /hm tus F")
        return
    end
    if self:InCombat() then self:Print("Savaşta tuş atanamaz; savaş bitince tekrar dene."); return end
    if not SetBinding then self:Print("Bu istemcide tuş atama API'si yok; Tuş Ayarları > Hedefleme > Interact With Target'ı elle ata."); return end
    local ok, res = pcall(SetBinding, key, "INTERACTTARGET")
    if not ok or not res then
        self:Print("Tuş atanamadı: " .. key .. ". Örnekler: F, G, SHIFT-F, MOUSEWHEELUP")
        return
    end
    if SaveBindings and GetCurrentBindingSet then pcall(SaveBindings, GetCurrentBindingSet()) end
    -- Yakındaki NPC/nesneyi hedefsiz etkileşime açan ayarlar (yumuşak hedefleme).
    if SetCVar then
        pcall(SetCVar, "SoftTargetInteract", 3)        -- her zaman açık
        pcall(SetCVar, "SoftTargetInteractArc", 2)     -- her yön
        pcall(SetCVar, "SoftTargetInteractRange", 15)  -- 15 yard
        pcall(SetCVar, "SoftTargetIconInteract", 1)    -- etkileşim ikonu
        pcall(SetCVar, "SoftTargetNameplateInteract", 1)
    end
    self.db.reminded = self.db.reminded or {}
    self.db.reminded.interact = true
    self:Print("Etkileşim tuşu " .. key .. " oldu. NPC'nin yanına gel, " .. key .. " bas: konuşma/görev penceresi açılır; posta ve nesneler için de geçerli.")
end

HM:OnLogin(function()
    C_Timer.After(8, function()
        if not HM.db or (HM.db.reminded and HM.db.reminded.interact) then return end
        if not HM:InteractKey() then
            HM:Print("İpucu: etkileşim tuşu bağlı değil. |cffffd100/hm tus F|r ile F'e ata (NPC'yle hedef almadan konuşursun).")
        end
    end)
end)

---------------------------------------------------------------------------
-- Komutlar
---------------------------------------------------------------------------
local function onoff(v) return v and "|cff40ff40açık|r" or "|cffff5050kapalı|r" end

local HELP = {
    "|cffffd100/hm|r rehber penceresini aç/kapat",
    "|cffffd100/hm menu|r tıklanabilir menü: pinler, uyarılar, otomatik işler tek tıkla açılır/kapanır (rehber penceresindeki |cffffd100Menü|r düğmesi de açar)",
    "|cffffd100/hm ok|r yön okunu aç/kapat",
    "|cffffd100/hm ileri|r, |cffffd100/hm geri|r, |cffffd100/hm tamam|r, |cffffd100/hm adim 120|r adımlar arasında gezin",
    "|cffffd100/hm gorev 843|r görev kimliğinin rotadaki adımına git, |cffffd100/hm bolum|r bölüm listesi, |cffffd100/hm liste|r bu bölümün adımları (yapılanlar ✓)",
    "|cffffd100/hm kas|r seviyene uygun kasma noktası, |cffffd100/hm egitmen|r en yakın sınıf eğitmeni",
    "|cffffd100/hm tus F|r etkileşim tuşunu (Interact With Target) F'e bağlar; yakındaki NPC/nesneyle hedef almadan konuşursun",
    "|cffffd100/hm kapat Plater|r eklentiyi devre dışı bırak, |cffffd100/hm ac Plater|r geri aç (/reload gerekir)",
    "|cffffd100/hm duzen|r arayüzü düzenler: Blizzard görev takipçisi ve yerleşik hasar ölçer gizlenir; Questie takipçisi minimap altına, Details! sağ alta, sohbet sol alta, rehber sol üste (|cffffd100/hm duzen sifirla|r geri alır)",
    "|cffffd100/hm gizle ÇerçeveAdı|r / |cffffd100/hm goster|r çerçeve gizle-göster (adı |cffffd100/hm ne|r ile fare altından öğren)",
    "|cffffd100/hm uyari|r zindan uyarıları: kesilebilir büyü (KES), lanet/zehir çözme (ÇÖZ), çalınabilir buff (ÇAL), patron notu; sınıfına göre (Counterspell / Pummel-Shield Bash / Bash); |cffffd100/hm uyari test|r dener",
    "|cffffd100/hm notlar [zindan]|r patron notları (ör. /hm notlar wailing)  |cffffd100/hm cast|r hedefin öğrenilen büyüleri",
    "|cffffd100/hm grafik|r en iyi görüntü ayarları (4K Ultra + MSAA 4x + CMAA2); |cffffd100/hm grafik ssaa|r %140 çözünürlük, |cffffd100dengeli|r FPS düşerse, |cffffd100durum|r mevcut değerler",
    "|cffffd100/hm makro|r sınıfına göre odak makrolarını oluşturur (mage: Koyun + Odak; druid: Uyut; warrior: OdakKes) — sonra Makrolar penceresinden çubuğa sürükle",
    "|cffffd100/hm zindan|r seviyene uygun zindanlar + görevleri; |cffffd100/hm zindan rfc|r belirli zindan detayı",
    "|cffffd100/hm oto|r otomatik görev al/teslim et (Shift basılıyken devre dışı; yalnızca rotadaki görevler)",
    "|cffffd100/hm sat|r gri eşyaları otomatik sat, |cffffd100/hm tamir|r otomatik tamir",
    "|cffffd100/hm egitim|r akıllı büyü satın alma penceresi, |cffffd100/hm atla Scorch|r atlama listesine ekle/çıkar",
    "|cffffd100/hm hedef 100|r binek altın hedefi, |cffffd100/hm su 10|r minimum su",
    "|cffffd100/hm bez|r 60 için bez stoku, |cffffd100/hm talent|r bu seviyenin talent önerisi, |cffffd100/hm talent tum|r 10-60 planı, |cffffd100/hm talent oto|r otomatik alma aç/kapat",
    "|cffffd100/hm rank|r barda eski rank'lı yetenek var mı, |cffffd100/hm canta|r çantadaki en değersiz eşya",
    "|cffffd100/hm harita 1.3|r dünya haritasını büyüt (0.7–2.0; |cffffd100/hm harita kapat|r 1.0'a döner; |cffffd100/hm harita isaret|r Blizzard harita işaretini çevirir); |cffffd100/hm koord|r minimap koordinatları; |cffffd100/hm ascii|r Türkçe harf sorunu için",
    "|cffffd100/hm boyut 0.9|r pencere ölçeği, |cffffd100/hm sifirla|r konum ve adımı sıfırla",
    "|cffffd100/hm tani|r rehber motoru ve görev API'si durumu (sorun bildirirken)",
    "|cffffd100/hm dps|r DPS denetimi: ayarlar, rank, talent, buff, ekipman, bar, erzak",
    "|cffffd100/hm proc|r proc göstergesi (Fingers of Frost → Ice Lance, Clearcasting, Winter's Chill) ac|kapat|ses|test",
    "|cffffd100/hm faire|r Darkmoon Faire: takvim, Sayge buff rehberi, bilet malzeme sayacı; |cffffd100/hm faire sayge|r / |cffffd100/hm faire bilet|r",
    "|cffffd100/hm xp|r XP buff durumu (yemek, uyku tulumu, rested, kamp); |cffffd100/hm xp nasil|r eksik olan nasıl alınır; |cffffd100/hm xp sessiz|r hatırlatmayı kapat",
    "|cffffd100/hm kamp|r meslek kamp eşyaları ve kamp buff'ı: neyin hazır, neyin eksik, sıradaki iş; |cffffd100/hm kamp git|r oku o işe çevirir; |cffffd100/hm kamp sec fish|r eşyayı elle seç (|cffffd100oto|r geri alır); |cffffd100/hm kamp sessiz|r hatırlatmayı kapat",
    "|cffffd100/hm kitap|r kütüphane kitabı takibi (32 kitap, 10/20/25 milestone ödülleri); |cffffd100/hm kitap git|r oku en yakın kitaba ya da teslim NPC'sine; |cffffd100/hm kitap tum|r bütün liste; |cffffd100/hm kitap sessiz|r hatırlatmayı kapat",
    "|cffffd100/hm sirala|r cantayi sirala; |cffffd100/hm sirala banka|r bankayi sirala; |cffffd100/hm sirala oto|r otomatik siralama; |cffffd100/hm canta duzen|r kategorili bag ac",
    "|cffffd100/hm buff|r buff durumu + yakinindaki buff verebilecek oyuncular; |cffffd100/hm buff on|r / |cffffd100off|r ac/kapat",
    "|cffffd100/hm zindanpin|r haritada zindan gorev verenlerini goster/gizle (Questie)",
    "|cffffd100/hm zincir|r seviyene uygun endgame gorev zincirleri (attunement, rep, anahtar); |cffffd100/hm zincir tum|r hepsi; |cffffd100/hm zincir onyxia|r detay",
    "|cffffd100/hm lfg|r LFG sırasında seviyesi senden yüksek + tank veya healer'ı olan + mage'siz grup leader'larına otomatik whisper; |cffffd100/hm lfg ac|r aç, |cffffd100/hm lfg mesaj \"...\"|r şablon (%d=seviyen), |cffffd100/hm lfg tara|r manuel tarama + neden elendi raporu, seans başına en fazla 10 mesaj, aynı leader'a 10 dk içinde tekrar yok",
    "|cffffd100/hm kopya|r sohbetin son 500 satırını kopyalanabilir pencerede aç (Ctrl+A → Ctrl+C); Classic/Forever'da native chat copy yok, bu onun yerine geçer",
    "|cffffd100/hm bilgi|r zindan/raid bilgi panelini aç-kapat (seviye aralığı, kısa açıklama, boss notları — sınıfına göre açıklanır); zindana girdiğinde otomatik açılır, çıkınca kapanır",
    "|cffffd100/hm pin|r harita pinlerini aç/kapat. Alt komutlar: |cffffd100fp|r uçuş, |cffffd100rare|r rare moblar (ipucunda seviye, yaklaşık doğma süresi, düşen eşyalar), |cffffd100sandik|r hazine sandığı noktaları, |cffffd100all|r hepsi, |cffffd100durum|r bu bölgede kaç nokta var, |cffffd100haber|r rare görünce haber ver aç/kapat",
    "|cffffd100/hm renk|r hedef aldığında mob seviye uyarısı (gri=XP yok atla, kırmızı=tehlikeli, skull=kaç) aç/kapat",
    "|cffffd100/hm ot|r ot noktası pinleri aç/kapat; |cffffd100/hm maden|r maden; |cffffd100/hm topla|r ikisini aç; |cffffd100/hm yakin 40|r noktaya yaklaşınca haber (0 = kapat); |cffffd100/hm sayac|r bu bölgedeki nokta sayısı; |cffffd100/hm becerim|r yalnızca toplayabildiklerimi göster aç/kapat",
    "|cffffd100/hm zzz|r dinlenme (zzz) göstergesini aç/kapat (EllesmereUI oyuncu çerçevesi); |cffffd100/hm hata|r eklentinin yakaladığı hatalar, |cffffd100/hm hata temizle|r siler",
    "|cffffd100/hm ah|r seviyene göre Auction House alışveriş listesi: her slot için önerilen suffix (|cff80ff80of Frozen Wrath|r vb.) ve baz item adları; |cffffd100/hm ah cloak|r tek slota odaklan (helm/cloak/chest/wrist/hand/waist/legs/feet/ring/trinket/weapon/offhand/neck/shoulder)",
}

---------------------------------------------------------------------------
-- Görüntü ayarları (/hm grafik): hesap genelinde Config.wtf'ye yazılır, tüm karakterler için geçerli
---------------------------------------------------------------------------
local GFX = {
    -- Alienware AW3225QF 4K OLED için: Ultra ön ayar + tam çözünürlük + MSAA 4x + CMAA2 + 16x doku filtresi
    ultra = {
        { "graphicsQuality", "10" },            -- Ultra ön ayar (alt ayarları da en üste çeker)
        { "graphicsTextureResolution", "2" },   -- doku: yüksek
        { "graphicsTextureFiltering", "5" },    -- 16x anizotropik
        { "graphicsProjectedTextures", "1" },
        { "graphicsShadowQuality", "5" },
        { "graphicsLiquidDetail", "3" },
        { "graphicsSunshafts", "3" },
        { "graphicsParticleDensity", "5" },
        { "graphicsSpellDensity", "5" },
        { "graphicsSSAO", "4" },
        { "graphicsDepthEffects", "3" },
        { "graphicsComputeEffects", "4" },
        { "graphicsOutlineMode", "2" },
        { "graphicsViewDistance", "10" },
        { "graphicsEnvironmentDetail", "10" },
        { "graphicsGroundClutter", "10" },
        { "shadowTextureSize", "4096" },        -- gölge dokusu (ön ayar 2048)
        { "physicsLevel", "2" },                -- kumaş/pelerin fiziği
        { "weatherDensity", "3" },
        { "RenderScale", "1" },                 -- 3840x2160 yerel
        { "ResampleQuality", "1" },             -- bikübik (ölçek 1 dışında geçerli)
        { "MSAAQuality", "2,0" },               -- MSAA 4x (kenarlar)
        { "ffxAntiAliasingMode", "3" },         -- CMAA2 (gölgelendirici kırışması)
        { "ffxGlow", "1" },
        { "maxFPSBk", "60" },                   -- arka plandayken 60 FPS (OLED ısınmasın)
    },
    ssaa = {
        { "RenderScale", "1.4" },               -- %140 üst örnekleme: en net görüntü, GPU'ya en yüklü
        { "ResampleQuality", "1" },
        { "MSAAQuality", "1,0" },               -- MSAA 2x yeter
        { "ffxAntiAliasingMode", "3" },
    },
    dengeli = {
        { "graphicsQuality", "7" },
        { "graphicsTextureResolution", "2" },
        { "graphicsTextureFiltering", "5" },
        { "graphicsShadowQuality", "3" },
        { "shadowTextureSize", "2048" },
        { "RenderScale", "1" },
        { "MSAAQuality", "1,0" },
        { "ffxAntiAliasingMode", "3" },
    },
}
local GFX_SHOW = { "graphicsQuality", "graphicsTextureResolution", "graphicsTextureFiltering", "graphicsShadowQuality", "shadowTextureSize",
    "graphicsSSAO", "graphicsViewDistance", "graphicsParticleDensity", "RenderScale", "MSAAQuality", "ffxAntiAliasingMode", "vsync", "GxApi", "GxMaximize" }

function HM:Graphics(arg)
    arg = (arg or ""):lower()
    if arg == "" then arg = "ultra" end
    if arg == "durum" then
        local fps = GetFramerate and GetFramerate() or 0
        local parts = {}
        for _, k in ipairs(GFX_SHOW) do
            local ok, v = pcall(GetCVar, k)
            parts[#parts + 1] = k .. "=" .. tostring(ok and v or "?")
        end
        local w, h = (GetPhysicalScreenSize and GetPhysicalScreenSize()) or 0, 0
        if GetPhysicalScreenSize then w, h = GetPhysicalScreenSize() end
        self:Print(string.format("Ekran %dx%d, %.0f FPS. %s", w or 0, h or 0, fps, table.concat(parts, "  ")))
        return
    end
    local set = GFX[arg]
    if not set then self:Print("Kullanım: /hm grafik [ultra|ssaa|dengeli|durum]"); return end
    if self:InCombat() then self:Print("Savaşta görüntü ayarı değiştirilemez; savaş bitince tekrar dene."); return end
    if arg == "ssaa" then
        -- önce ultra, üstüne üst örnekleme
        for _, kv in ipairs(GFX.ultra) do pcall(SetCVar, kv[1], kv[2]) end
    end
    local n, fail = 0, {}
    for _, kv in ipairs(set) do
        local ok = pcall(SetCVar, kv[1], kv[2])
        if ok then n = n + 1 else fail[#fail + 1] = kv[1] end
    end
    local fps = GetFramerate and GetFramerate() or 0
    self:Print(string.format("Görüntü ayarı '%s' uygulandı (%d ayar). Şu an %.0f FPS. Doku çözünürlüğü değiştiyse oyun yeniden başlatmak isteyebilir.", arg, n, fps))
    if #fail > 0 then self:Print("Yazılamayan: " .. table.concat(fail, ", ")) end
    if arg == "ultra" then self:Print("FPS 100'ün altına düşerse /hm grafik dengeli; GPU rahatsa daha net görüntü için /hm grafik ssaa") end
end

---------------------------------------------------------------------------
-- Odak makroları (/hm makro): karakter başına oluşturulur / güncellenir
---------------------------------------------------------------------------
local MACROS = {
    MAGE = {
        { "Koyun", "#showtooltip Polymorph\n/focus [mod:shift,@mouseover,harm,nodead][mod:shift]\n/clearfocus [mod:ctrl]\n/stopmacro [mod]\n/stopcasting\n/cast [@focus,harm,nodead][] Polymorph",
          "Tık: odağı koyun yap (odak yoksa hedefi). Shift+tık: fare altındaki/hedefi odak yap. Ctrl+tık: odağı temizle." },
        { "Odak", "/focus [@mouseover,harm,nodead][]", "Fare altındaki düşmanı (yoksa hedefi) odak yapar." },
        { "OdakKes", "#showtooltip Counterspell\n/stopcasting\n/cast [@focus,harm,nodead][] Counterspell",
          "Odağın büyüsünü keser (odak yoksa hedefin)." },
    },
    DRUID = {
        { "Uyut", "#showtooltip Hibernate\n/focus [mod:shift,@mouseover,harm,nodead][mod:shift]\n/clearfocus [mod:ctrl]\n/stopmacro [mod]\n/stopcasting\n/cast [@focus,harm,nodead][] Hibernate",
          "Tık: odağı uyut (canavar/ejder). Shift+tık odak yap, Ctrl+tık temizle." },
        { "Odak", "/focus [@mouseover,harm,nodead][]", "Fare altındaki düşmanı (yoksa hedefi) odak yapar." },
    },
    WARRIOR = {
        { "OdakKes", "#showtooltip Pummel\n/cast [@focus,harm,nodead,stance:3][harm,stance:3] Pummel\n/cast [@focus,harm,nodead,stance:1/2][harm,stance:1/2] Shield Bash",
          "Odağın (yoksa hedefin) büyüsünü keser: Berserker'da Pummel, Battle/Defensive'de Shield Bash." },
        { "Odak", "/focus [@mouseover,harm,nodead][]", "Fare altındaki düşmanı (yoksa hedefi) odak yapar." },
    },
}

-- Adı verilen makronun sırası (yoksa 0). GetMacroIndexByName yoksa yuvalar tek tek taranır;
-- böylece komut tekrar çalıştırıldığında aynı makrodan ikinci bir kopya oluşmaz.
local function macroIndex(name)
    if GetMacroIndexByName then
        local ok, idx = pcall(GetMacroIndexByName, name)
        if ok then return (type(idx) == "number" and idx > 0) and idx or 0 end
    end
    if GetMacroInfo then
        local total = (MAX_ACCOUNT_MACROS or 120) + (MAX_CHARACTER_MACROS or 30)
        for i = 1, total do
            local ok, n = pcall(GetMacroInfo, i)
            if ok and n == name then return i end
        end
    end
    return 0
end

function HM:CreateMacros()
    if self:InCombat() then self:Print("Savaşta makro oluşturulamaz; savaş bitince tekrar dene."); return end
    if not (CreateMacro and GetMacroInfo) then self:Print("Makro API'si yok."); return end
    local _, class = UnitClass("player")
    local list = MACROS[class]
    if not list then self:Print("Bu sınıf için hazır makro yok."); return end
    for _, m in ipairs(list) do
        local name, body, desc = m[1], m[2], m[3]
        local idx = macroIndex(name)
        local ok, err
        if idx and idx > 0 then
            ok, err = pcall(EditMacro, idx, name, "INV_MISC_QUESTIONMARK", body)
        else
            ok, err = pcall(CreateMacro, name, "INV_MISC_QUESTIONMARK", body, true)
        end
        if ok then
            self:Print("|cffffd100" .. name .. "|r makrosu " .. ((idx and idx > 0) and "güncellendi" or "oluşturuldu") .. ": " .. desc)
        else
            self:Print(name .. " makrosu yazılamadı: " .. tostring(err) .. " (karakter makro sayısı dolu olabilir)")
        end
    end
    self:Print("Makrolar penceresini (Esc → Macros ya da /macro) açıp çubuğa sürükle.")
end

SLASH_HIZLIMAGE1 = "/hm"
SLASH_HIZLIMAGE2 = "/hizlimage"
local function slashHandler(msg)
    msg = (msg or ""):gsub("^%s+", ""):gsub("%s+$", "")
    local cmd, rest = msg:match("^(%S+)%s*(.-)$")
    cmd = (cmd or ""):lower()
    local db = HM.db
    if not db then return end

    if cmd == "" then
        if HM.Guide then HM.Guide:Toggle() end
    elseif cmd == "yardim" or cmd == "help" then
        HM:Print("komutlar:")
        for _, line in ipairs(HELP) do HM:Print(line) end
    elseif cmd == "ok" then
        db.arrow.shown = not db.arrow.shown
        if HM.Arrow then HM.Arrow:Refresh() end
        HM:Print("Yön oku " .. onoff(db.arrow.shown))
    elseif cmd == "ileri" then
        HM.Guide:Next()
    elseif cmd == "geri" then
        HM.Guide:Prev()
    elseif cmd == "tamam" then
        HM.Guide:Complete()
    elseif cmd == "adim" then
        local n = tonumber(rest)
        if n then HM.Guide:SetStep(n) else HM:Print("Kullanım: /hm adim 12") end
    elseif cmd == "aoe" or cmd == "kas" then
        HM.Guide:PointGrind()
    elseif cmd == "gorev" then
        local n = tonumber(rest)
        local idx = n and HM.Guide:FindQuest(n)
        if idx then HM.Guide:SetStep(idx) else HM:Print("Bu görev rotada yok: " .. tostring(rest)) end
    elseif cmd == "tus" then
        HM:BindInteract(rest)
    elseif cmd == "liste" then
        HM.Guide:ListSection()
    elseif cmd == "kopya" or cmd == "chat" or cmd == "sohbet" then
        -- /hm kopya : son 500 sohbet satırını kopyalanabilir editbox'ta aç
        if HM.ChatCopy then HM.ChatCopy:Show() else HM:Print("Kopya modülü yüklü değil.") end
    elseif cmd == "bilgi" or cmd == "panel" or cmd == "zindanpanel" then
        -- /hm bilgi : zindan/raid bilgi panelini aç/kapat
        if HM.DungeonPanel then HM.DungeonPanel:Toggle() else HM:Print("Panel modülü yüklü değil.") end
    elseif cmd == "pin" or cmd == "pinler" then
        -- /hm pin : harita pinleri. Alt komut yoksa sistemi tümden aç/kapat.
        if not HM.Pins then HM:Print("Pin modülü yüklü değil."); return end
        local sub = rest:match("^(%S*)")
        if sub == "" or sub == nil then HM.Pins:Toggle()
        elseif sub == "fp" or sub == "ucus" then HM.Pins:ToggleFp()
        elseif sub == "rare" or sub == "nadir" then HM.Pins:ToggleRare()
        elseif sub == "sandik" or sub == "chest" or sub == "sandık" then HM.Pins:ToggleChest()
        elseif sub == "all" or sub == "hepsi" then HM.Pins:AllOn()
        elseif sub == "durum" or sub == "mapid" or sub == "id" then HM.Pins:Status()
        elseif sub == "haber" or sub == "uyari" or sub == "uyarı" then HM.Pins:SetRareAlert(HM.db.rareAlertOff and true or false)
        else HM:Print("/hm pin [fp|rare|sandik|all|durum|haber]") end
    elseif cmd == "renk" or cmd == "mob" then
        -- /hm renk : hedef aldığın mob'un gri/kırmızı uyarısını aç/kapat
        if HM.MobColor then HM.MobColor:Toggle() else HM:Print("Mob rengi modülü yüklü değil.") end
    elseif cmd == "ot" or cmd == "herb" then
        -- /hm ot : ot pinleri aç/kapat
        if HM.Gather then HM.Gather:ToggleHerb() else HM:Print("Gather modülü yüklü değil.") end
    elseif cmd == "maden" or cmd == "ore" or cmd == "mine" then
        -- /hm maden : maden pinleri aç/kapat
        if HM.Gather then HM.Gather:ToggleOre() else HM:Print("Gather modülü yüklü değil.") end
    elseif cmd == "topla" or cmd == "gather" then
        -- /hm topla : ot + maden hepsini aç
        if HM.Gather then HM.Gather:AllOn() else HM:Print("Gather modülü yüklü değil.") end
    elseif cmd == "yakin" or cmd == "yakın" or cmd == "proximity" then
        -- /hm yakin 40 : proximity uyarı mesafesi yarda; 0 = kapat
        if HM.Gather then HM.Gather:SetRange(rest) else HM:Print("Gather modülü yüklü değil.") end
    elseif cmd == "topla?" or cmd == "sayac" or cmd == "sayaç" or cmd == "nodes" then
        if HM.Pins then HM.Pins:Status() end
        if HM.Gather then HM.Gather:Report() else HM:Print("Gather modülü yüklü değil.") end
    elseif cmd == "becerim" or cmd == "beceri" then
        if HM.Gather then HM.Gather:SetSkillOnly(not HM.db.gatherSkillOnly) else HM:Print("Gather modülü yüklü değil.") end
    elseif cmd == "ah" or cmd == "auction" then
        -- /hm ah : seviyene göre AH alışveriş listesi (suffix'ler, baz adlar)
        -- /hm ah cloak : sadece belirli slot (helm/cloak/chest/wrist/hand/waist/legs/feet/ring/trinket/weapon/offhand/wand/neck/shoulder)
        if HM.AH then HM.AH:Report(rest ~= "" and rest or nil) else HM:Print("AH modülü yüklü değil.") end
    elseif cmd == "lfg" then
        -- /hm lfg : durum
        -- /hm lfg ac|on : aç   /hm lfg kapat|off : kapat
        -- /hm lfg mesaj <...> : şablon (içinde %d varsa seviyen yerleşir)
        -- /hm lfg sifirla : ping log'u temizle
        if not HM.LFG then HM:Print("LFG modülü yüklü değil."); return end
        local sub, arg = rest:match("^(%S*)%s*(.-)$")
        sub = (sub or ""):lower()
        if sub == "ac" or sub == "aç" or sub == "on" then
            HM.LFG:Toggle(true)
        elseif sub == "kapat" or sub == "off" then
            HM.LFG:Toggle(false)
        elseif sub == "mesaj" or sub == "msg" then
            HM.LFG:SetMessage(arg)
        elseif sub == "sifirla" or sub == "sıfırla" or sub == "reset" then
            HM.LFG:Reset()
        elseif sub == "tara" or sub == "scan" or sub == "test" then
            HM.LFG:Scan()
        elseif sub == "detay" or sub == "dump" or sub == "debug" then
            HM.LFG:Detay()
        else
            HM.LFG:Status()
        end
    elseif cmd == "kapat" then
        -- /hm kapat Plater : eklentiyi devre dışı bırak (reload gerekir)
        if rest == "" then HM:Print("Kullanım: /hm kapat Plater") return end
        local fn = (C_AddOns and C_AddOns.DisableAddOn) or DisableAddOn
        if fn then
            local ok = pcall(fn, rest)
            HM:Print(ok and (rest .. " devre dışı bırakıldı; /reload ile uygulanır.") or ("Eklenti bulunamadı: " .. rest))
        end
    elseif cmd == "ac" then
        if rest == "" then HM:Print("Kullanım: /hm ac Plater") return end
        local fn = (C_AddOns and C_AddOns.EnableAddOn) or EnableAddOn
        if fn then
            local ok = pcall(fn, rest)
            HM:Print(ok and (rest .. " etkinleştirildi; /reload ile uygulanır.") or ("Eklenti bulunamadı: " .. rest))
        end
    elseif cmd == "ne" then
        -- fare altındaki çerçeveyi ve üst çerçevelerini yaz (hata ayıklama)
        local f
        if GetMouseFoci then local ok, t = pcall(GetMouseFoci); if ok and type(t) == "table" then f = t[1] end
        elseif GetMouseFocus then local ok, r = pcall(GetMouseFocus); if ok then f = r end end
        if not f then HM:Print("Fare altında çerçeve yok.") return end
        local chain, guard = {}, 0
        while f and guard < 8 do
            local nm = (f.GetName and f:GetName()) or "(adsız)"
            local w = f.GetWidth and math.floor(f:GetWidth() or 0) or 0
            local h = f.GetHeight and math.floor(f:GetHeight() or 0) or 0
            chain[#chain + 1] = string.format("%s[%dx%d]", nm, w, h)
            f = f.GetParent and f:GetParent() or nil
            guard = guard + 1
        end
        HM:Print("Çerçeve: " .. table.concat(chain, " < "))
    elseif cmd == "makro" then
        HM:CreateMacros()
    elseif cmd == "grafik" then
        HM:Graphics(rest)
    elseif cmd == "uyari" or cmd == "uyarı" then
        if HM.Alerts then HM.Alerts:Command(rest) end
    elseif cmd == "notlar" or cmd == "not" then
        if HM.Alerts then HM.Alerts:PrintNotes(rest) end
    elseif cmd == "cast" or cmd == "buyu" then
        if HM.Alerts then HM.Alerts:PrintCastLog(rest ~= "" and rest or nil) end
    elseif cmd == "kilit" then
        -- EllesmereUI kilit açma (unlock) modunu aç/kapat: tüm çerçeveler sürüklenebilir kutular olarak görünür
        if EllesmereUI and EllesmereUI.ToggleUnlockMode then EllesmereUI:ToggleUnlockMode() else HM:Print("EllesmereUI yok.") end
    elseif cmd == "foto" then
        if Screenshot then pcall(Screenshot); HM:Print("Ekran görüntüsü alındı (Screenshots klasörü).") end
    elseif cmd == "dokum" then
        if HM.Layout then HM.Layout:DumpFrames(true) end
    elseif cmd == "cerceveler" then
        -- ekranın sol üst çeyreğindeki görünür ana çerçeveler (hata ayıklama)
        local sw, sh = UIParent:GetWidth(), UIParent:GetHeight()
        local f = EnumerateFrames and EnumerateFrames()
        local n = 0
        while f and n < 400 do
            local ok, shown = pcall(f.IsVisible, f)
            if ok and shown and f.GetParent and f:GetParent() == UIParent then
                local l, t, w, h = f:GetLeft(), f:GetTop(), f:GetWidth() or 0, f:GetHeight() or 0
                if l and t and w > 150 and h > 100 and w < sw * 0.8 and h < sh * 0.8 and l < sw * 0.25 and t > sh * 0.75 then
                    HM:Print(string.format("%s  %dx%d  sol=%d üst=%d  %s", (f.GetName and f:GetName()) or "(adsız)", w, h, l, t, f.GetFrameStrata and f:GetFrameStrata() or ""))
                    n = n + 1
                end
            end
            f = EnumerateFrames(f)
        end
        if n == 0 then HM:Print("Sol üstte büyük görünür çerçeve bulunamadı.") end
    elseif cmd == "gizle" then
        -- /hm gizle <ÇerçeveAdı> : adı verilen çerçeveyi gizle (girişte tekrar gizlenir)
        if rest == "" then HM:Print("Kullanım: /hm gizle ÇerçeveAdı (adı /hm ne ile bul)") return end
        local f = _G[rest]
        if not f or not f.Hide then HM:Print("Çerçeve bulunamadı: " .. rest) return end
        if f.IsProtected and f:IsProtected() and HM:InCombat() then HM:Print("Savaşta gizlenemez.") return end
        f:Hide()
        db.hiddenFrames = db.hiddenFrames or {}
        db.hiddenFrames[rest] = true
        if not f.hmHooked then
            f.hmHooked = true
            pcall(f.HookScript, f, "OnShow", function(fr) if HM.db.hiddenFrames and HM.db.hiddenFrames[rest] then pcall(fr.Hide, fr) end end)
        end
        HM:Print(rest .. " gizlendi. Geri açmak: /hm goster " .. rest)
    elseif cmd == "goster" then
        if rest == "" then HM:Print("Kullanım: /hm goster ÇerçeveAdı") return end
        if db.hiddenFrames then db.hiddenFrames[rest] = nil end
        local f = _G[rest]
        if f and f.Show then f:Show(); HM:Print(rest .. " gösterildi.") end
    elseif cmd == "duzen" then
        if HM.Layout then
            if rest == "sifirla" then HM.Layout:Reset() else HM.Layout:Apply(true) end
        end
    elseif cmd == "bolum" then
        local last
        for i, st in ipairs(ns.Route or {}) do
            if st.sec ~= last then
                last = st.sec
                HM:Print(string.format("%d: %s", i, st.sec or ""))
            end
        end
    elseif cmd == "egitmen" then
        if HM.Trainer then HM.Trainer:PointTrainer("class") end
    elseif cmd == "zindan" then
        if HM.Dungeons and rest ~= "" then HM.Dungeons:Command(rest)
        elseif HM.Dungeons then HM.Dungeons:List(); HM.Guide:ListDungeons()
        else HM.Guide:ListDungeons() end
    elseif cmd == "oto" then
        db.autoQuest = not db.autoQuest
        HM:Print("Otomatik görev " .. onoff(db.autoQuest))
    elseif cmd == "sat" then
        db.autoSell = not db.autoSell
        HM:Print("Gri eşya satışı " .. onoff(db.autoSell))
    elseif cmd == "tamir" then
        db.autoRepair = not db.autoRepair
        HM:Print("Otomatik tamir " .. onoff(db.autoRepair))
    elseif cmd == "egitim" then
        db.smartTrain = not db.smartTrain
        HM:Print("Akıllı büyü satın alma " .. onoff(db.smartTrain))
    elseif cmd == "atla" then
        if rest == "" then
            local names = {}
            local cd = ns.CD or ns.ClassData.MAGE
            local merged = {}
            for k, v in pairs(cd.skip) do merged[k] = v end
            for k, v in pairs(db.trainSkip) do merged[k] = v end
            for k, v in pairs(merged) do if v then names[#names + 1] = k end end
            table.sort(names)
            HM:Print("Atlanan büyüler: " .. table.concat(names, ", "))
        else
            local now = HM.Trainer and HM.Trainer.ShouldSkip(rest, nil)
            db.trainSkip[rest] = not now
            HM:Print(rest .. (db.trainSkip[rest] and " atlanacak" or " artık satın alınacak"))
        end
    elseif cmd == "hedef" then
        local n = tonumber(rest)
        if n then db.goldTarget = n end
        HM:Print("Binek altın hedefi: " .. db.goldTarget .. " altın")
    elseif cmd == "su" then
        local n = tonumber(rest)
        if n then db.waterMin = n end
        HM:Print("Minimum su: " .. db.waterMin)
    elseif cmd == "bez" then
        if HM.Bags then HM.Bags:ClothReport() end
    elseif cmd == "dps" or cmd == "denetim" then
        if HM.Dps then HM.Dps:Run() end
    elseif cmd == "proc" then
        if HM.Procs then HM.Procs:Command(rest) end
    elseif cmd == "tani" or cmd == "tanı" or cmd == "teshis" then
        if HM.Guide then HM.Guide:Diagnose() end
    elseif cmd == "talent" then
        local a = (rest or ""):lower()
        if HM.Talents and HM.Talents:Command(a) then
            -- oto | uygula | api
        elseif HM.Trainer then
            if a == "tum" or a == "tüm" or a == "liste" or a == "plan" then
                HM.Trainer:TalentPlan()
            elseif tonumber(a) then
                HM.Trainer:TalentHint(tonumber(a), true)
            else
                HM.Trainer:TalentHint(HM:Level(), true)
            end
        end
    elseif cmd == "rank" then
        if HM.Extras then HM.Extras:CheckRanks(true) end
    elseif cmd == "canta" then
        if rest == "duzen" or rest == "setup" or rest == "kurulum" then
            if HM.BagSort then HM.BagSort:Setup() end
        else
            if HM.Extras then HM.Extras:ReportCheapest(true) end
        end
    elseif cmd == "harita" or cmd == "map" then
        local a = (rest or ""):lower()
        if a == "isaret" or a == "işaret" or a == "waypoint" then
            db.nativeWaypoint = not db.nativeWaypoint
            HM:Print("Blizzard harita işareti " .. onoff(db.nativeWaypoint))
            if HM.Arrow then HM.Arrow:Refresh() end
        elseif HM.MapScale then
            HM.MapScale(rest)
        end
    elseif cmd == "ascii" then
        db.ascii = not db.ascii
        HM:Print("ASCII modu " .. onoff(db.ascii))
        if HM.Guide then HM.Guide:Refresh() end
    elseif cmd == "boyut" then
        local n = tonumber(rest)
        if n and n >= 0.5 and n <= 2 then
            db.frame.scale = n
            if HM.Guide then HM.Guide:ApplyScale() end
        else
            HM:Print("Kullanım: /hm boyut 0.9 (0.5-2)")
        end
    elseif cmd == "sifirla" then
        db.frame.point, db.frame.x, db.frame.y = DEFAULTS.frame.point, DEFAULTS.frame.x, DEFAULTS.frame.y
        db.arrow.point, db.arrow.x, db.arrow.y = DEFAULTS.arrow.point, DEFAULTS.arrow.x, DEFAULTS.arrow.y
        db.initialized = false
        db.questSkip = {}
        if HM.Guide then HM.Guide:Reposition(); HM.Guide:Sync() end
        if HM.Arrow then HM.Arrow:Reposition() end
        HM:Print("Konumlar ve adım seviyene göre sıfırlandı.")
    elseif cmd == "faire" or cmd == "darkmoon" then
        if HM.Faire then HM.Faire:Command(rest) end
    elseif cmd == "xp" then
        if HM.XpBuffs then HM.XpBuffs:Command(rest) end
    elseif cmd == "kamp" or cmd == "camp" then
        if HM.Camp then
            local okC, errC = pcall(HM.Camp.Command, HM.Camp, rest)
            if not okC then HM:Print("|cffff8080Kamp komutunda hata:|r " .. tostring(errC)) end
        else
            HM:Print("Kamp modülü yüklenmemiş. Oyunu tamamen kapatıp aç; yine olmazsa bana yaz.")
        end
    elseif cmd == "kitap" or cmd == "book" or cmd == "books" then
        if HM.Books then
            local okB, errB = pcall(HM.Books.Command, HM.Books, rest)
            if not okB then HM:Print("|cffff8080Kitap komutunda hata:|r " .. tostring(errB)) end
        else
            HM:Print("Kitap modülü yüklenmemiş. Oyunu tamamen kapatıp aç; yine olmazsa bana yaz.")
        end
    elseif cmd == "koord" or cmd == "coord" then
        if HM.ToggleMinimapCoords then HM.ToggleMinimapCoords() end
    elseif cmd == "buff" or cmd == "bufiste" then
        if HM.BuffReq then HM.BuffReq:Command(rest) end
    elseif cmd == "zindanpin" then
        if HM.Guide then HM.Guide:ToggleDungeonPins() end
    elseif cmd == "zincir" or cmd == "chain" or cmd == "endgame" then
        if HM.Chains then HM.Chains:Command(rest) end
    elseif cmd == "sirala" or cmd == "sort" then
        if HM.BagSort then HM.BagSort:Command(rest) end
    elseif cmd == "debug" then
        db.debug = not db.debug
        HM:Print("Hata ayıklama " .. onoff(db.debug))
    elseif cmd == "hata" or cmd == "hatalar" or cmd == "error" then
        HM:ShowErrors(rest)
    elseif cmd == "menu" or cmd == "menü" or cmd == "ayar" or cmd == "ayarlar" then
        if HM.Menu then HM.Menu:Toggle() else HM:Print("Menü modülü yüklenmemiş. Oyunu tamamen kapatıp aç.") end
    elseif cmd == "zzz" or cmd == "dinlenme" then
        if HM.Menu and HM.Menu.SetRested then HM.Menu:SetRested(nil, true) else HM:Print("Menü modülü yüklenmemiş. Oyunu tamamen kapatıp aç.") end
    else
        HM:Print("Bilinmeyen komut: " .. tostring(cmd) .. ". |cffffd100/hm menu|r tıklanabilir menüyü açar, |cffffd100/hm yardim|r tüm komutları listeler.")
    end
end

-- Komut çalışırken çıkan hata oyuncuya sessiz kalmasın: kaydet ve tek satır haber ver.
SlashCmdList["HIZLIMAGE"] = function(msg)
    local ok, err = xpcall(function() slashHandler(msg) end, function(e)
        local st = (debugstack and debugstack(2, 4, 0)) or ""
        return tostring(e) .. (st ~= "" and ("\n" .. st) or "")
    end)
    if not ok then
        HM:LogError("/hm " .. tostring(msg or ""), err)
        HM:Print("|cffff8080Bu komutta bir hata oluştu ve kaydedildi.|r Ayrıntı: |cffffd100/hm hata|r")
    end
end

---------------------------------------------------------------------------
-- Dünya haritası ölçeği ve minimap koordinatı (v2.10)
---------------------------------------------------------------------------
local mapAppliedScale = nil
local function applyMapScale()
    if not WorldMapFrame then return end
    local want = (HM.db and HM.db.mapScale) or 1.0
    if mapAppliedScale == want then return end
    local ok, err = pcall(function() WorldMapFrame:SetScale(want) end)
    if ok then
        mapAppliedScale = want
    else
        HM:Print("|cffff8080Harita ölçeği uygulanamadı:|r " .. tostring(err))
    end
end

function HM.MapScale(arg)
    arg = (arg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    local db = HM.db
    if arg == "" or arg == "durum" then
        HM:Print(string.format("Harita ölçeği: |cffffd100%.2f|r (|cffffd100/hm harita 1.3|r ayarlar, |cffffd100/hm harita kapat|r 1.0'a döner)", db.mapScale or 1.0))
        return
    end
    if arg == "kapat" or arg == "off" or arg == "1" or arg == "1.0" then
        db.mapScale = 1.0
    else
        local n = tonumber(arg)
        if not n then HM:Print("Sayı ver: /hm harita 1.3 (0.7–2.0 arası)"); return end
        if n < 0.7 then n = 0.7 end
        if n > 2.0 then n = 2.0 end
        db.mapScale = n
    end
    mapAppliedScale = nil
    applyMapScale()
    HM:Print(string.format("Harita ölçeği: |cffffd100%.2f|r", db.mapScale))
end

-- Minimap koordinatı
local coordFrame, coordFS
local function updateCoords()
    if not coordFS then return end
    if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition) then coordFS:SetText(""); return end
    local okM, map = pcall(C_Map.GetBestMapForUnit, "player")
    if not okM or not map or map == 0 then coordFS:SetText(""); return end
    local okP, pos = pcall(C_Map.GetPlayerMapPosition, map, "player")
    if not okP or not pos then coordFS:SetText(""); return end
    local x, y = pos:GetXY()
    if HM.IsSecret(x) or HM.IsSecret(y) or type(x) ~= "number" or type(y) ~= "number" then coordFS:SetText(""); return end
    coordFS:SetText(string.format("%.1f, %.1f", x * 100, y * 100))
end

local function setupMinimapCoords()
    if coordFrame then
        coordFrame:SetShown(HM.db.minimapCoords ~= false)
        return
    end
    if not Minimap then return end
    coordFrame = CreateFrame("Frame", "HM_MinimapCoords", Minimap)
    coordFrame:SetSize(48, 11)
    coordFrame:SetPoint("TOPRIGHT", Minimap, "TOPRIGHT", -4, -4)
    coordFrame:SetFrameStrata(Minimap:GetFrameStrata() or "MEDIUM")
    coordFrame:SetFrameLevel((Minimap:GetFrameLevel() or 0) + 10)
    local bg = coordFrame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.55)
    coordFS = coordFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    coordFrame.text = coordFS         -- test erişimi için (oyunda zararsız)
    coordFS:SetPoint("CENTER")
    coordFS:SetTextColor(1, 0.96, 0.41)
    if coordFS.SetFont then
        local f, _, flags = coordFS:GetFont()
        if f then pcall(coordFS.SetFont, coordFS, f, 9, flags or "OUTLINE") end
    end
    local elapsed = 0
    coordFrame:SetScript("OnUpdate", function(_, e)
        elapsed = elapsed + e
        if elapsed >= 0.5 then elapsed = 0; updateCoords() end
    end)
    coordFrame:SetShown(HM.db.minimapCoords ~= false)
    updateCoords()
end

function HM.ToggleMinimapCoords()
    HM.db.minimapCoords = not (HM.db.minimapCoords ~= false)
    setupMinimapCoords()
    HM:Print("Minimap koordinatı: " .. (HM.db.minimapCoords and "açık" or "kapalı"))
end

-- Harita ilk açıldığında ölçeği uygula (değiştikten sonra da)
local function hookWorldMap()
    if not WorldMapFrame or WorldMapFrame._hmHooked then return end
    WorldMapFrame._hmHooked = true
    if WorldMapFrame.HookScript then
        WorldMapFrame:HookScript("OnShow", function() C_Timer.After(0, applyMapScale) end)
    end
    applyMapScale()
end

HM:OnLogin(function()
    pcall(setupMinimapCoords)
    pcall(hookWorldMap)
    -- EllesmereUI gibi başka bir eklenti harita açtıktan sonra ölçeği sıfırlayabilir, 1 ve 3 sn sonra tekrar uygula
    C_Timer.After(1, function() mapAppliedScale = nil; pcall(applyMapScale) end)
    C_Timer.After(3, function() mapAppliedScale = nil; pcall(applyMapScale) end)
end)
