@echo off
REM Hizli paket guncelleyici: cift tikla. Haftalik otomatik icin HizliGuncelle-Zamanla.cmd
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0HizliGuncelle.ps1" %*
