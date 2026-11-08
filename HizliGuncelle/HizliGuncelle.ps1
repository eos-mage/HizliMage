# HizliGuncelle.ps1 - WoW Forever eklenti paketi guncelleyici (Melih & Claude)
# Once CurseForge (anahtar varsa), yoksa GitHub: eklentilerin Forever surumunu indirir,
# TOC'unu dogrular ve _forever_\Interface\AddOns klasorune kurar.
#
# CurseForge anahtari: ayni klasordeki HizliGuncelle.key dosyasina tek satir olarak yapistir.
# Kullanim:  HizliGuncelle.cmd (cift tik)   |   -Kontrol (sadece bak)   |   -Sadece Questie   |   -Sessiz
param(
    [switch]$Kontrol,
    [string]$Sadece = "",
    [switch]$Sessiz
)

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$WoW     = Split-Path -Parent $MyInvocation.MyCommand.Path
$AddOns  = Join-Path $WoW '_forever_\Interface\AddOns'
$State   = Join-Path $WoW 'HizliGuncelle.json'
$Log     = Join-Path $WoW 'HizliGuncelle.log'
$KeyFile = Join-Path $WoW 'HizliGuncelle.key'
$Tmp     = Join-Path $env:TEMP 'HizliGuncelle'
$CF      = 'https://api.curseforge.com'
$WOWGAME = 1

# Paket: cf = CurseForge adi/slug (arama ile bulunur, bulunan kimlik json'a yazilir), repo = GitHub yedegi
$Paket = @(
    @{ name = 'Questie';          cf = 'questie';                   repo = 'Questie/Questie' },
    @{ name = 'Auctionator';      cf = 'auctionator';               repo = 'Auctionator/Auctionator' },
    @{ name = 'AtlasLootClassic'; cf = 'AtlasLoot Classic Forever'; repo = 'Hoizame/AtlasLootClassic' },
    @{ name = 'Bagnon';           cf = 'bagnon';                    repo = 'tullamods/Bagnon' },
    @{ name = 'Details';          cf = 'details';                   repo = 'Tercioo/Details-Damage-Meter' },
    @{ name = 'Leatrix_Plus';     cf = 'leatrix-plus';              repo = 'leatrix/Leatrix_Plus' },
    @{ name = 'DialogueUI';       cf = 'dialogueui';                repo = 'Peterodox/DialogueUI' },
    @{ name = 'Plater';           cf = 'plater-nameplates';         repo = 'Tercioo/Plater-Nameplates' },
    @{ name = 'EllesmereUI';      cf = 'EllesmereUI' },
    @{ name = 'WhatsTraining';    cf = "What's Training" },
    @{ name = 'MapUtils';         cf = 'MapUtils' }
)

function Yaz($msg, $renk = 'Gray') {
    $satir = "{0:yyyy-MM-dd HH:mm}  {1}" -f (Get-Date), $msg
    Write-Host $msg -ForegroundColor $renk
    Add-Content -Path $Log -Value $satir -Encoding UTF8
}

# ---------------- CurseForge ----------------
$Key = $null
if (Test-Path $KeyFile) {
    # dosyadaki ilk anahtara benzeyen satir (yer tutucu ve bos satirlar atlanir)
    foreach ($satir in (Get-Content $KeyFile -ErrorAction SilentlyContinue)) {
        $aday = ("$satir").Trim()
        if ($aday.Length -ge 20 -and $aday -notmatch 'BURAYA' -and $aday -notmatch '\s') { $Key = $aday; break }
    }
}
# Anahtar yoksa ve ekran basindaysak: pencereye yapistir, dosyaya kaydedelim.
if (-not $Key -and -not $Sessiz) {
    Write-Host ""
    Write-Host "CurseForge API anahtarini buraya yapistir (sag tik ya da Ctrl+V) ve Enter'a bas." -ForegroundColor Yellow
    Write-Host "Yapistirma olmuyorsa: HizliAnahtar.cmd dosyasina cift tikla, Not Defteri acilir, Ctrl+V, kaydet, kapat." -ForegroundColor DarkGray
    Write-Host "Anahtar: console.curseforge.com > API keys > kopyala simgesi. Bos gecersen yalnizca GitHub kullanilir." -ForegroundColor DarkGray
    $giris = Read-Host "Anahtar"
    if ($giris) { $giris = $giris.Trim() }
    if ($giris -and $giris.Length -ge 20) {
        Set-Content -Path $KeyFile -Value $giris -Encoding ASCII
        $Key = $giris
        Write-Host "Kaydedildi: $KeyFile" -ForegroundColor Green
    }
}
function CfGet($yol) {
    return Invoke-RestMethod -Uri "$CF$yol" -Headers @{ 'x-api-key' = $Key; 'Accept' = 'application/json'; 'User-Agent' = 'HizliGuncelle' }
}
$ForeverTypeId = $null
$ForeverTypeName = $null
function CfForeverType {
    if ($script:ForeverTypeId) { return }
    try {
        $t = (CfGet "/v1/games/$WOWGAME/version-types").data
        $f = $t | Where-Object { $_.name -match 'Forever' } | Select-Object -First 1
        if ($f) { $script:ForeverTypeId = $f.id; $script:ForeverTypeName = $f.name; Yaz "CurseForge: Forever surum turu '$($f.name)' (id $($f.id))" 'DarkGray' }
        else { Yaz "CurseForge: 'Forever' adli surum turu yok; dosyalar TOC ile dogrulanacak" 'DarkGray' }
    } catch { Yaz "CurseForge surum turleri alinamadi: $($_.Exception.Message)" 'Yellow' }
}
function CfModBul($e, $durum) {
    $ad = $e.name
    if ($durum["$ad.cfId"]) { return [int]$durum["$ad.cfId"] }
    $slug = ($e.cf -replace "[^a-zA-Z0-9\-]", '').ToLower()
    $r = $null
    try { $r = (CfGet "/v1/mods/search?gameId=$WOWGAME&slug=$slug").data } catch { }
    if (-not $r -or $r.Count -eq 0) {
        $q = [uri]::EscapeDataString($e.cf)
        $r = (CfGet "/v1/mods/search?gameId=$WOWGAME&searchFilter=$q&sortField=2&sortOrder=desc&pageSize=10").data
        $kelimeler = ($e.cf -replace "[^a-zA-Z0-9 ]", ' ').ToLower().Split(' ', [StringSplitOptions]::RemoveEmptyEntries)
        $r = @($r | Where-Object { $n = $_.name.ToLower(); ($kelimeler | Where-Object { $n -notmatch [regex]::Escape($_) }).Count -eq 0 })
    }
    if (-not $r -or $r.Count -eq 0) { return $null }
    $mod = $r | Select-Object -First 1
    $durum["$ad.cfId"] = $mod.id
    $durum["$ad.cfName"] = $mod.name
    Yaz "$ad : CurseForge projesi '$($mod.name)' (id $($mod.id), $($mod.links.websiteUrl))" 'DarkGray'
    return [int]$mod.id
}
function CfDosyaSec($modId) {
    $yol = "/v1/mods/$modId/files?pageSize=50"
    if ($script:ForeverTypeId) { $yol += "&gameVersionTypeId=$($script:ForeverTypeId)" }
    $files = @((CfGet $yol).data)
    if ($files.Count -eq 0 -and $script:ForeverTypeId) { $files = @((CfGet "/v1/mods/$modId/files?pageSize=50").data) }
    if ($files.Count -eq 0) { return $null }
    # Forever'a isaretli (1.60.x ya da 'Forever' adli surum) en yeni dosya; yoksa adinda forever gecen; yoksa en yeni
    $f = $files | Where-Object { ($_.gameVersions -match '^1\.6\d') -or ($_.sortableGameVersions.gameVersionName -match 'Forever') } | Sort-Object fileDate -Descending | Select-Object -First 1
    if (-not $f) { $f = $files | Where-Object { $_.displayName -match 'forever' -or $_.fileName -match 'forever' } | Sort-Object fileDate -Descending | Select-Object -First 1 }
    if (-not $f) { $f = $files | Sort-Object fileDate -Descending | Select-Object -First 1 }
    return $f
}
function CfIndirUrl($f) {
    if ($f.downloadUrl) { return $f.downloadUrl }
    $id = [int]$f.id
    return "https://edge.forgecdn.net/files/$([math]::Floor($id / 1000))/$($id % 1000)/$($f.fileName)"
}

# ---------------- GitHub ----------------
function GitHubSon($repo) {
    $h = @{ 'User-Agent' = 'HizliGuncelle'; 'Accept' = 'application/vnd.github+json' }
    try { return Invoke-RestMethod -Uri "https://api.github.com/repos/$repo/releases/latest" -Headers $h } catch {
        try { $list = Invoke-RestMethod -Uri "https://api.github.com/repos/$repo/releases?per_page=5" -Headers $h; if ($list -and $list.Count -gt 0) { return $list[0] } } catch { }
        return $null
    }
}
function GhAssetSec($rel) {
    $zips = @($rel.assets | Where-Object { $_.name -like '*.zip' })
    if ($zips.Count -eq 0) { return $null }
    $f = $zips | Where-Object { $_.name -match 'forever' } | Select-Object -First 1
    if ($f) { return $f }
    $g = $zips | Where-Object { $_.name -notmatch '-(bcc|tbc|classic|vanilla|wrath|wotlk|cata|mists|mop|retail|mainline|era|sod|anniversary)' } | Select-Object -First 1
    if ($g) { return $g }
    return $zips[0]
}

# ---------------- ortak ----------------
function ForeverVar($klasor) {
    foreach ($t in (Get-ChildItem -Path $klasor -Recurse -Filter '*.toc' -ErrorAction SilentlyContinue)) {
        if ($t.Name -match '[_-]Forever\.toc$') { return $true }
        $ilk = Get-Content -Path $t.FullName -TotalCount 15 -ErrorAction SilentlyContinue
        if ($ilk -match '##\s*Interface:\s*.*\b16\d{3}\b') { return $true }
    }
    return $false
}
function Kur($ad, $zip, $kaynakZip) {
    $ac = Join-Path $Tmp ($ad + '_ac')
    if (Test-Path $ac) { Remove-Item $ac -Recurse -Force }
    Expand-Archive -Path $zip -DestinationPath $ac -Force
    $kokler = @(Get-ChildItem -Path $ac -Directory)
    if ($kaynakZip -and $kokler.Count -eq 1) { Rename-Item -Path $kokler[0].FullName -NewName $ad }
    $kokler = @(Get-ChildItem -Path $ac -Directory | Where-Object { Get-ChildItem $_.FullName -Filter '*.toc' -ErrorAction SilentlyContinue })
    if ($kokler.Count -eq 0) { throw "zip icinde eklenti klasoru yok" }
    if (-not (ForeverVar $ac)) { throw "bu dosyada Forever TOC'u yok, kurulmadi" }
    foreach ($k in $kokler) {
        $hedef = Join-Path $AddOns $k.Name
        if (Test-Path $hedef) { Remove-Item $hedef -Recurse -Force }
        Copy-Item -Path $k.FullName -Destination $hedef -Recurse -Force
    }
    return ($kokler.Name -join ', ')
}

if (-not (Test-Path $AddOns)) { Yaz "AddOns klasoru bulunamadi: $AddOns" 'Red'; if (-not $Sessiz) { Read-Host 'Enter' | Out-Null }; exit 1 }
New-Item -ItemType Directory -Force -Path $Tmp | Out-Null
$durum = @{}
if (Test-Path $State) { try { (Get-Content $State -Raw | ConvertFrom-Json).PSObject.Properties | ForEach-Object { $durum[$_.Name] = $_.Value } } catch { } }

Yaz "=== HizliGuncelle basladi ($AddOns) - kaynak: $(if ($Key) { 'CurseForge + GitHub' } else { 'GitHub (CurseForge anahtari yok: HizliGuncelle.key)' })" 'Cyan'
if ($Key) { CfForeverType }
$ozet = @()
foreach ($e in $Paket) {
    if ($Sadece -and $e.name -ne $Sadece) { continue }
    $ad = $e.name
    $kurulu = Test-Path (Join-Path $AddOns $ad)
    $yapildi = $false
    # 1) CurseForge
    if ($Key -and $e.cf) {
        try {
            $modId = CfModBul $e $durum
            if (-not $modId) { Yaz "$ad : CurseForge'da bulunamadi ('$($e.cf)')" 'Yellow' }
            else {
                $f = CfDosyaSec $modId
                if (-not $f) { Yaz "$ad : CurseForge'da dosya yok" 'Yellow' }
                else {
                    $etiket = "cf:$($f.id)"
                    if ($durum[$ad] -eq $etiket -and $kurulu) { Yaz "$ad : guncel ($($f.displayName))" 'DarkGray'; $ozet += "$ad guncel"; $yapildi = $true }
                    elseif ($Kontrol) { Yaz "$ad : yeni -> $($f.displayName) ($($f.fileDate))" 'Green'; $ozet += "$ad yeni"; $yapildi = $true }
                    else {
                        $zip = Join-Path $Tmp $f.fileName
                        Yaz "$ad : indiriliyor $($f.displayName) [$($f.gameVersions -join ' ')]" 'White'
                        Invoke-WebRequest -Uri (CfIndirUrl $f) -OutFile $zip -Headers @{ 'User-Agent' = 'HizliGuncelle' }
                        $k = Kur $ad $zip $false
                        $durum[$ad] = $etiket
                        Yaz "$ad : kuruldu -> $($f.displayName) ($k)" 'Green'; $ozet += "$ad kuruldu"; $yapildi = $true
                    }
                }
            }
        } catch { Yaz "$ad : CurseForge hatasi: $($_.Exception.Message)" 'Yellow' }
    }
    # 2) GitHub yedegi
    if (-not $yapildi -and $e.repo) {
        try {
            $rel = GitHubSon $e.repo
            if (-not $rel) { Yaz "$ad : GitHub'da surum yok" 'Yellow'; $ozet += "$ad bulunamadi"; continue }
            $tag = "gh:$($rel.tag_name)"
            if ($durum[$ad] -eq $tag -and $kurulu) { Yaz "$ad : guncel ($($rel.tag_name))" 'DarkGray'; $ozet += "$ad guncel"; continue }
            if ($Kontrol) { Yaz "$ad : yeni -> $($rel.tag_name)" 'Green'; $ozet += "$ad yeni"; continue }
            $asset = GhAssetSec $rel
            if ($asset) { $url = $asset.browser_download_url; $dosya = $asset.name } else { $url = $rel.zipball_url; $dosya = "$ad-kaynak.zip" }
            $zip = Join-Path $Tmp $dosya
            Yaz "$ad : GitHub $($rel.tag_name) indiriliyor ($dosya)" 'White'
            Invoke-WebRequest -Uri $url -OutFile $zip -Headers @{ 'User-Agent' = 'HizliGuncelle' }
            $k = Kur $ad $zip (-not $asset)
            $durum[$ad] = $tag
            Yaz "$ad : kuruldu -> $($rel.tag_name) ($k)" 'Green'; $ozet += "$ad kuruldu"
        } catch { Yaz "$ad : HATA $($_.Exception.Message)" 'Red'; $ozet += "$ad hata" }
    } elseif (-not $yapildi) {
        $ozet += "$ad elle"
        Yaz "$ad : yalnizca CurseForge'da; anahtar yoksa elle indir" 'Yellow'
    }
}
$durum | ConvertTo-Json | Set-Content -Path $State -Encoding UTF8
Yaz "=== Bitti. $($ozet -join ' | ')" 'Cyan'
Yaz "Oyundaysan /reload yeterli. HizliMage'i Claude dogrudan gunceller." 'Gray'
if (-not $Sessiz) { Read-Host 'Kapatmak icin Enter' | Out-Null }
