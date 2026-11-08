@echo off
echo CurseForge anahtarini acilan Not Defteri'ne yapistir (Ctrl+V), kaydet (Ctrl+S) ve Not Defteri'ni kapat.
echo Not Defteri kapaninca guncelleme kendiliginden baslar.
notepad "%~dp0HizliGuncelle.key"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0HizliGuncelle.ps1"
