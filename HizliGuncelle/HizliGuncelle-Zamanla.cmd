@echo off
REM Zamanlanmis guncelleme (Gorev Zamanlayici):
REM   HizliGuncelle        her Pazar 12:00  -> butun paket + HizliMage
REM   HizliGuncelle-Giris  her oturum acilisinda -> yalnizca HizliMage (birkac saniye)
REM Oturum acilisi gorevi yonetici yetkisi ister: bu dosyaya sag tikla, "Yonetici olarak calistir".
schtasks /Create /F /SC WEEKLY /D SUN /ST 12:00 /TN "HizliGuncelle" /TR "powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File \"%~dp0HizliGuncelle.ps1\" -Sessiz"
schtasks /Create /F /SC ONLOGON /TN "HizliGuncelle-Giris" /TR "powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File \"%~dp0HizliGuncelle.ps1\" -Sessiz -YalnizHizliMage"
echo.
echo Yukarida "SUCCESS" / "BASARILI" yaziyorsa gorev kuruldu. "Access is denied" / "Erisim engellendi"
echo yaziyorsa bu dosyayi sag tik ^> "Yonetici olarak calistir" ile yeniden ac.
echo Kaldirmak icin: schtasks /Delete /TN HizliGuncelle /F   ve   schtasks /Delete /TN HizliGuncelle-Giris /F
pause
