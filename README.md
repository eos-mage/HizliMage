# HizliMage

Quest-by-quest 1–60 leveling guide addon for **World of Warcraft: Forever** (Horde), plus **HizliGuncelle**, a small PowerShell updater that keeps a personal set of Forever addons current on one PC.

## HizliMage (addon)
- Routes for three characters (Orc mage, Tauren druid, Skyborne warrior), generated from QuestieDB's Forever data: ~1200–1300 steps each. Steps advance automatically from quest-log events.
- Direction arrow, auto accept/turn-in for route quests only, smart trainer purchases, talent plan, XP/gold tracking, camp and XP-buff reminders, dungeon notes and interrupt/dispel alerts.
- **Clickable menu** (`/hm menu`, or the "Menü" button on the guide window): every toggle in one place, no commands to remember.
- **World map pins**: rare mobs (level, approximate respawn window, when this character last saw it alive or dead), treasure chest spawn points and route flight points, drawn with the client's own small map icons. A pin size setting (small / medium / large) scales them all. Pins are placed the way the client places its own pins (frame level from the map's pin level manager, counter-scaled to the canvas).
- **Rare item card**: clicking a rare pin opens a card with its level, respawn window and drops. Hovering an item row shows the item's own tooltip (with comparison to what you wear), clicking pins that tooltip, Shift-click links the item in chat. The drop list needs the companion data addon (see below).
- **Herb and ore nodes** (need the companion data addon): small dots on the world map (or icons, or hidden) and on the minimap for the area it shows; round, square and rotating minimaps are supported. Optional chat ping when you get near a node, and an "only what I can gather" filter that hides nodes above your skill.
- Rare alert when a rare is targeted, moused over or its nameplate appears; mob level warning for grey/orange/red/skull targets.
- **Class-coloured player names**: a menu toggle for the game's friendly player nameplates (name only), so nearby players' names show in their class colour.
- Error log: caught Lua errors are stored in SavedVariables and shown by `/hm hata`.
- Install: copy the `HizliMage` folder into `_forever_\Interface\AddOns\`. A new version with new files needs a full client restart, not just `/reload`. Commands: `/hm yardim`.
- UI language: Turkish.

### Data that is not in this repository
Rare drop tables and herb/ore node positions come from third-party sources and are kept in a separate, local-only companion addon (`HizliMage_Veri`); they are not redistributed here. Without it the pins still work; rare tooltips and cards simply have no drop list and there are no herb/ore pins on the map or minimap.

### Licence of the data files
The addon's code is MIT. `Route_*.lua` and `PinsData.lua` are generated from [QuestieDB](https://github.com/Questie) (Forever data) and [cmangos classic-db](https://github.com/cmangos/classic-db); both sources are GPL-3.0, so those generated data files are distributed under GPL-3.0.

## HizliGuncelle (updater)
- `HizliGuncelle.ps1` downloads the latest **Forever-flavored** file of each listed addon (CurseForge API with your own key, GitHub releases as fallback), verifies the Forever TOC inside the zip and installs it into `_forever_\Interface\AddOns`.
- HizliMage itself is handled by a separate, careful step: it is installed only when the version in this repository is **newer** than the installed one. Same or older: nothing is touched. Before installing, the old folder is backed up (`HizliMage-Yedek`, last three kept); no file is ever deleted; an incomplete download is refused and a failed copy is rolled back from the backup.
- Options: `-Kontrol` (check only), `-YalnizHizliMage` (skip the other addons), `-Sadece <name>`, `-Sessiz`, `-Baslat` (start the game afterwards). `HizliGuncelle-Baslat.cmd` = check HizliMage, then start the game.
- Personal, single-PC use: nothing is re-hosted or redistributed; projects whose authors disable third-party downloads are skipped.
- `HizliGuncelle.cmd` runs it, `HizliAnahtar.cmd` stores your CurseForge API key in `HizliGuncelle.key`, `HizliGuncelle-Zamanla.cmd` schedules weekly runs.
- Publishing order for a new HizliMage version: upload every other file first and the two `.toc` files last. The version number lives in the TOC, so a half-uploaded version is never picked up.

Author: Melih Gümüş (with Claude). License: MIT (code); see the note on data files above.

---

# HizliMage (Türkçe)

**World of Warcraft: Forever** (Horde) için görev-görev 1–60 kasma rehberi eklentisi ve tek PC'de Forever eklentilerini güncel tutan küçük bir PowerShell güncelleyici (**HizliGuncelle**).

## HizliMage (eklenti)
- Üç karakter için rota (Orc mage, Tauren druid, Skyborne warrior); QuestieDB'nin Forever verisinden üretildi: karakter başına ~1200–1300 adım. Adımlar görev günlüğündeki olaylarla kendiliğinden ilerler.
- Yön oku, yalnızca rotadaki görevler için otomatik al/teslim, akıllı eğitmen alışverişi, talent planı, XP/altın takibi, kamp ve XP buff hatırlatmaları, zindan notları ve kesme/çözme uyarıları.
- **Tıklanabilir menü** (`/hm menu` ya da rehber penceresindeki "Menü" düğmesi): bütün aç/kapat ayarları tek yerde, komut ezberlemek gerekmez.
- **Dünya haritası pinleri**: rare moblar (seviye, yaklaşık yeniden doğma aralığı, bu karakterin en son ne zaman canlı/ölü gördüğü), hazine sandığı noktaları ve rotadaki uçuş noktaları; oyunun kendi küçük harita simgeleriyle çizilir. Pin boyutu ayarı (küçük / orta / büyük) hepsini birlikte ölçekler.
- **Rare eşya kartı**: rare pinine tıklayınca seviye, yeniden doğma aralığı ve düşen eşyaların olduğu kart açılır. Eşya satırının üstüne gelince eşyanın kendi ipucu (kuşandığınla karşılaştırmalı) çıkar, tıklayınca ipucu sabitlenir, Shift+tık eşyayı sohbete bağlar. Eşya listesi için yardımcı veri eklentisi gerekir (aşağıya bakın).
- **Ot ve maden noktaları** (yardımcı veri eklentisi gerekir): dünya haritasında küçük nokta (ya da simge, ya da gizli) ve minimap'in gösterdiği alanda minimap'te; yuvarlak, kare ve dönen minimap desteklenir. İsteğe bağlı olarak noktaya yaklaşınca sohbete haber düşer; "yalnızca toplayabildiklerim" süzgeci becerinin yetmediği düğümleri gizler.
- Rare hedef alındığında, fareyle üstüne gelindiğinde ya da isim plakası göründüğünde haber; gri/turuncu/kırmızı/kafatası hedefler için seviye uyarısı.
- **Sınıf renkli oyuncu adları**: oyunun dost oyuncu isim plakalarını (yalnız ad) menüden açıp kapatır; çevredeki oyuncuların adı sınıf renginde görünür.
- Hata kaydı: yakalanan Lua hataları saklanır, `/hm hata` ile görülür.
- Kurulum: `HizliMage` klasörünü `_forever_\Interface\AddOns\` içine kopyala. Yeni dosya içeren sürümde `/reload` yetmez, oyunu kapatıp aç. Komutlar: `/hm yardim`.

### Bu depoda olmayan veri
Rare'lerin düşürdüğü eşyalar ile ot/maden noktaları üçüncü taraf kaynaklardan gelir ve ayrı, yalnızca yerelde duran yardımcı eklentide (`HizliMage_Veri`) tutulur; burada yeniden dağıtılmaz. O eklenti yokken pinler yine çalışır; rare ipucunda ve kartında eşya listesi, haritada ve minimap'te ot/maden noktası olmaz.

### Veri dosyalarının lisansı
Eklentinin kodu MIT. `Route_*.lua` ve `PinsData.lua`, QuestieDB (Forever verisi) ve cmangos classic-db'den üretilir; iki kaynak da GPL-3.0 olduğundan bu üretilmiş veri dosyaları GPL-3.0 koşullarıyla dağıtılır.

## HizliGuncelle (güncelleyici)
- `HizliGuncelle.ps1` listedeki her eklentinin en yeni **Forever** dosyasını indirir (kendi CurseForge anahtarınla API; yedek olarak GitHub sürümleri), zip içindeki Forever TOC'unu doğrular ve `_forever_\Interface\AddOns` klasörüne kurar.
- HizliMage için ayrı ve dikkatli bir adım vardır: yalnızca bu depodaki sürüm kurulu olandan **yeniyse** kurulur. Aynıysa ya da eskiyse hiçbir dosyaya dokunulmaz. Kurmadan önce eski klasör yedeklenir (`HizliMage-Yedek`, son üç yedek); hiçbir dosya silinmez; eksik indirilen paket kurulmaz, doğrulanamayan kopya yedekten geri alınır.
- Seçenekler: `-Kontrol` (yalnızca bak), `-YalnizHizliMage` (diğer eklentileri atla), `-Sadece <ad>`, `-Sessiz`, `-Baslat` (sonra oyunu başlat). `HizliGuncelle-Baslat.cmd` = HizliMage'i denetle, sonra oyunu başlat.
- Kişisel, tek PC kullanımı: hiçbir dosya yeniden barındırılmaz ya da dağıtılmaz; yazarı üçüncü taraf indirmeyi kapatmış projeler atlanır.
- `HizliGuncelle.cmd` çalıştırır, `HizliAnahtar.cmd` CurseForge anahtarını `HizliGuncelle.key` dosyasına kaydeder, `HizliGuncelle-Zamanla.cmd` haftalık çalışmayı zamanlar.
- Yeni HizliMage sürümünü yayımlama sırası: önce diğer bütün dosyalar, en son iki `.toc` dosyası. Sürüm numarası TOC'ta durduğu için yarım yüklenmiş sürüm kurulmaz.

Yazar: Melih Gümüş (Claude ile). Lisans: MIT (kod); veri dosyaları için yukarıdaki nota bakın.
