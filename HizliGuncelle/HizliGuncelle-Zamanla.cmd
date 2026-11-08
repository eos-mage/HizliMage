@echo off
REM Her Pazar 12:00 ve her oturum acilisinda sessiz guncelleme (Gorev Zamanlayici)
schtasks /Create /F /SC WEEKLY /D SUN /ST 12:00 /TN "HizliGuncelle" /TR "powershell -NoProfile -ExecutionPolicy Bypass -File \"%~dp0HizliGuncelle.ps1\" -Sessiz"
schtasks /Create /F /SC ONLOGON /TN "HizliGuncelle-Giris" /TR "powershell -NoProfile -ExecutionPolicy Bypass -File \"%~dp0HizliGuncelle.ps1\" -Sessiz"
echo Zamanlanmis gorevler kuruldu. Kaldirmak icin: schtasks /Delete /TN HizliGuncelle /F
pause
