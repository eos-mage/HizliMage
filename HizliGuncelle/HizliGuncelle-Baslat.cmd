@echo off
REM HizliMage'i denetleyip oyunu baslatir. HizliGuncelle.ps1 ile ayni klasorde durur (WoW ana klasoru).
REM GitHub'daki surum bilgisayardakinden YENIYSE kurar; ayni ya da eskiyse hicbir dosyaya dokunmaz.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0HizliGuncelle.ps1" -YalnizHizliMage -Sessiz -Baslat
