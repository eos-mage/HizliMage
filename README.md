# HizliMage

Quest-by-quest 1–60 leveling guide addon for **World of Warcraft: Forever** (Horde), plus **HizliGuncelle**, a small PowerShell updater that keeps a personal set of Forever addons current on one PC.

## HizliMage (addon)
- Routes for three characters (Orc mage, Tauren druid, Skyborne warrior), generated from QuestieDB's Forever data: ~1300 steps, 430–490 quests each.
- Step kinds: travel, flight point, hearth, trainer, accept, objectives, turn-in, grind. Steps advance automatically from quest-log events.
- Direction arrow, auto accept/turn-in for route quests only, smart trainer purchases, XP/gold tracking, interact-key binding (`/hm tus F`).
- Install: copy the `HizliMage` folder into `_forever_\Interface\AddOns\`. Commands: `/hm yardim`.
- UI language: Turkish.

## HizliGuncelle (updater)
- `HizliGuncelle.ps1` downloads the latest **Forever-flavored** file of each listed addon (CurseForge API with your own key, GitHub releases as fallback), verifies the Forever TOC inside the zip and installs it into `_forever_\Interface\AddOns`.
- Personal, single-PC use: nothing is re-hosted or redistributed; projects whose authors disable third-party downloads are skipped.
- `HizliGuncelle.cmd` runs it, `HizliAnahtar.cmd` stores your CurseForge API key in `HizliGuncelle.key`, `HizliGuncelle-Zamanla.cmd` schedules weekly runs.

Author: Melih Gümüş (with Claude). License: MIT.

---

# HizliMage (Türkçe)

**World of Warcraft: Forever** (Horde) için görev-görev 1–60 kasma rehberi eklentisi ve tek PC'de Forever eklentilerini güncel tutan küçük bir PowerShell güncelleyici (**HizliGuncelle**).

## HizliMage (eklenti)
- Üç karakter için rota (Orc mage, Tauren druid, Skyborne warrior); QuestieDB'nin Forever verisinden üretildi: ~1300 adım, 430–490 görev.
- Adım türleri: git, uçuş noktası, hearth, eğitmen, görev al, hedefler, teslim, kas. Adımlar görev günlüğündeki olaylarla kendiliğinden ilerler.
- Yön oku, yalnızca rotadaki görevler için otomatik al/teslim, akıllı eğitmen alışverişi, XP/altın takibi, etkileşim tuşu (`/hm tus F`).
- Kurulum: `HizliMage` klasörünü `_forever_\Interface\AddOns\` içine kopyala. Komutlar: `/hm yardim`.

## HizliGuncelle (güncelleyici)
- `HizliGuncelle.ps1` listedeki her eklentinin en yeni **Forever** dosyasını indirir (kendi CurseForge anahtarınla API; yedek olarak GitHub sürümleri), zip içindeki Forever TOC'unu doğrular ve `_forever_\Interface\AddOns` klasörüne kurar.
- Kişisel, tek PC kullanımı: hiçbir dosya yeniden barındırılmaz ya da dağıtılmaz; yazarı üçüncü taraf indirmeyi kapatmış projeler atlanır.
- `HizliGuncelle.cmd` çalıştırır, `HizliAnahtar.cmd` CurseForge anahtarını `HizliGuncelle.key` dosyasına kaydeder, `HizliGuncelle-Zamanla.cmd` haftalık çalışmayı zamanlar.

Yazar: Melih Gümüş (Claude ile). Lisans: MIT.
