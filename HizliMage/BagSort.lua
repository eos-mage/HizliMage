-- Çanta ve banka düzeni: Blizzard bag kategorileri, otomatik sıralama, Bagnon devre dışı.
-- Forever'ın yerleşik bag sistemi kategorilendirme yapıyor (Consumables, Trade Goods, Equipment vb.)
-- Bagnon bu kategorileri geçersiz kılıyor → Bagnon'u kapatıp Blizzard bag'ini kullanıyoruz.
-- /hm sirala, /hm sirala banka, /hm sirala oto, /hm canta duzen

local ADDON, ns = ...
local HM = ns.HM
local BagSort = {}
HM.BagSort = BagSort

local WARN = "|cffffd100!|r "

---------------------------------------------------------------------------
-- Çanta sıralama (Blizzard API)
---------------------------------------------------------------------------
function BagSort:SortBags()
    if HM:InCombat() then HM:Print("Savasta siralama yapilmaz."); return end
    if C_Container and C_Container.SortBags then
        C_Container.SortBags()
        HM:Print("|cff80ff80Canta siralandi.|r")
        return true
    end
    if SortBags then
        SortBags()
        HM:Print("|cff80ff80Canta siralandi.|r")
        return true
    end
    HM:Print("Siralama API'si bulunamadi.")
    return false
end

function BagSort:SortBank()
    if HM:InCombat() then HM:Print("Savasta siralama yapilmaz."); return end
    -- Banka açık mı: Blizzard penceresi ya da BANKFRAME_OPENED/CLOSED olayıyla tutulan işaret
    -- (banka penceresini başka bir eklenti çiziyorsa BankFrame görünmez).
    if not (BagSort.bankOpen or (BankFrame and BankFrame:IsShown())) then
        HM:Print("Once bankaciyla konus, sonra /hm sirala banka yaz.")
        return false
    end
    if C_Container and C_Container.SortBankBags then
        C_Container.SortBankBags()
        HM:Print("|cff80ff80Banka siralandi.|r")
        return true
    end
    if SortBankBags then
        SortBankBags()
        HM:Print("|cff80ff80Banka siralandi.|r")
        return true
    end
    HM:Print("Banka siralama API'si bulunamadi.")
    return false
end

---------------------------------------------------------------------------
-- Bagnon'u kapat, Blizzard bag kategorilerini aç
---------------------------------------------------------------------------
local function disableBagnon()
    -- Bagnon kurulu ve aktifse devre dışı bırak (sonraki reload'da etkili)
    local bagnon = "Bagnon"
    if C_AddOns and C_AddOns.GetAddOnInfo then
        local name, _, _, loadable, reason = C_AddOns.GetAddOnInfo(bagnon)
        if name and (loadable or reason == "DEMAND_LOADED" or reason == "DISABLED") then
            if C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded(bagnon) then
                if C_AddOns.DisableAddOn then
                    C_AddOns.DisableAddOn(bagnon)
                    return true, "Bagnon devre disi birakildi (reload'da etkili)."
                end
            end
        end
    elseif GetAddOnInfo then
        local name = GetAddOnInfo(bagnon)
        if name and IsAddOnLoaded and IsAddOnLoaded(bagnon) then
            if DisableAddOn then
                DisableAddOn(bagnon)
                return true, "Bagnon devre disi birakildi (reload'da etkili)."
            end
        end
    end
    return false, nil
end

local function enableBagCategories()
    -- Blizzard bag penceresinde kategori filtreleme ayarları
    -- SetBagSlotFlag: bag 0 (backpack) filtrelerini temizle → tüm kategoriler görünsün
    -- Bu Forever/Retail API'si; Classic'te olmayabilir
    if not (C_Container and C_Container.SetBagSlotFlag) then return false end

    -- Bag'lerin "Clean Up" (sıralama) yönü
    local sortRTL = C_Container.SetSortBagsRightToLeft or SetSortBagsRightToLeft
    local insertLTR = C_Container.SetInsertItemsLeftToRight or SetInsertItemsLeftToRight
    if sortRTL then pcall(sortRTL, true) end
    if insertLTR then pcall(insertLTR, false) end

    -- Bag filtreleri: her çanta sıralamaya dahil olsun ve hiçbir çanta tek bir eşya türüne
    -- ayrılmış olmasın. Bayraklar bit değerleridir (Enum.BagSlotFlags):
    -- 1 sıralama dışı, 2 ekipman, 4 tüketilebilir, 8 meslek malzemesi, 16 çöp, 32 görev eşyası, 128 reaktif.
    -- "Çöpü satma" (64) bayrağına dokunulmaz; o oyuncunun kendi tercihi.
    local F = Enum and Enum.BagSlotFlags or {}
    local flags = {
        F.DisableAutoSort or 1, F.ClassEquipment or 2, F.ClassConsumables or 4,
        F.ClassProfessionGoods or 8, F.ClassJunk or 16, F.ClassQuestItems or 32, F.ClassReagents or 128,
    }
    for bag = 0, 4 do
        for _, flag in ipairs(flags) do
            pcall(C_Container.SetBagSlotFlag, bag, flag, false)
        end
    end
    return true
end

---------------------------------------------------------------------------
-- Tam düzen kurulumu: /hm canta duzen
---------------------------------------------------------------------------
function BagSort:Setup()
    HM:Print("|cff33ccff— Canta duzeni ayarlaniyor —|r")

    -- 1) Bagnon'u kapat
    local disabled, msg = disableBagnon()
    if disabled then
        HM:Print("|cff80ff80" .. msg .. "|r")
        HM:Print(WARN .. "Blizzard'in kategorili canta sistemi aktif olacak (Totik'in videosundaki gibi).")
        HM:Print(WARN .. "Kategoriler: All Items, Consumables, Trade Goods, Equipment, Weapons, Adventure Prep, Reagent Bag")
    elseif _G.Bagnon then
        HM:Print("|cffffd100Bagnon suan yuklu ama devre disi birakilamadi. Elle kapat: /hm kapat Bagnon sonra /reload|r")
    else
        HM:Print("|cff80ff80Bagnon yuklu degil — Blizzard bag sistemi zaten aktif.|r")
    end

    -- 2) Bag kategorilerini ayarla
    local cats = enableBagCategories()
    if cats then HM:Print("|cff80ff80Bag filtre ayarlari yapildi.|r") end

    -- 3) Sırala
    self:SortBags()

    HM:Print("Ipucu: canta acikken sagdaki 'Categories' panelinden istedigin kategoriye tikla.")
    HM:Print("Ipucu: /hm sirala oto → satirsan/esya alinca otomatik siralar.")
end

---------------------------------------------------------------------------
-- Otomatik çanta sıralama
---------------------------------------------------------------------------
HM:On("BANKFRAME_OPENED", function() BagSort.bankOpen = true end)
HM:On("BANKFRAME_CLOSED", function() BagSort.bankOpen = false end)

HM:On("MERCHANT_CLOSED", function()
    C_Timer.After(0.5, function()
        if not HM:InCombat() and HM.db and HM.db.autoSort then
            pcall(BagSort.SortBags, BagSort)
        end
    end)
end)

local sortPending = false
HM:On("BAG_UPDATE_DELAYED", function()
    if not (HM.db and HM.db.autoSort) then return end
    if sortPending or HM:InCombat() then return end
    sortPending = true
    C_Timer.After(3, function()
        sortPending = false
        if not HM:InCombat() then
            pcall(function()
                if C_Container and C_Container.SortBags then C_Container.SortBags()
                elseif SortBags then SortBags() end
            end)
        end
    end)
end)

---------------------------------------------------------------------------
-- Girişte: kategorileri ayarla + çantayı sırala
---------------------------------------------------------------------------
HM:OnLogin(function()
    C_Timer.After(5, function()
        pcall(enableBagCategories)
    end)
    -- Her girişte çantayı otomatik sırala
    C_Timer.After(8, function()
        if HM:InCombat() then return end
        if not (HM.db and HM.db.autoSort) then return end
        pcall(function()
            if C_Container and C_Container.SortBags then C_Container.SortBags() end
        end)
    end)
end)

---------------------------------------------------------------------------
-- Komut: /hm sirala [banka|oto] veya /hm canta duzen
---------------------------------------------------------------------------
function BagSort:Command(arg)
    arg = (arg or ""):lower()
    if arg == "banka" or arg == "bank" then
        self:SortBank()
    elseif arg == "oto" then
        HM.db.autoSort = not (HM.db.autoSort or false)
        HM:Print("Otomatik canta siralama: " .. (HM.db.autoSort and "acik" or "kapali"))
    elseif arg == "duzen" or arg == "setup" or arg == "kurulum" then
        self:Setup()
    else
        self:SortBags()
    end
end
