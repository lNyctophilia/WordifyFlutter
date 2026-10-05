@echo off
cd /d "%~dp0\.."
echo ===================================
echo   Wordify - Web Build ve Deploy
echo ===================================
echo.

REM 0. Versiyon Bilgisini Guncelle
echo [0/3] Versiyon bilgisi guncelleniyor...
call dart run scripts\update_version.dart
if errorlevel 1 (
    echo HATA: Versiyon guncelleme basarisiz!
    pause
    exit /b 1
)

REM 1. Flutter Web Build
echo [1/3] Flutter Web build aliniyor...
call flutter build web --release --no-tree-shake-icons --base-href "/WordifyFlutter/"
if errorlevel 1 (
    echo HATA: Flutter web build basarisiz!
    pause
    exit /b 1
)
echo Build basarili!
echo.

REM 2. docs klasorunu temizle ve yeni build'i kopyala
echo [2/3] Build dosyalari docs/ klasorune kopyalaniyor...
if exist docs rmdir /s /q docs
mkdir docs
xcopy build\web\* docs\ /s /e /q
type nul > docs\.nojekyll
call dart run scripts\update_version.dart --post-build
echo Kopyalama tamamlandi!
echo.

REM 3. Git ile commit ve push
echo [3/3] Git commit ve push yapiliyor...
git add docs/
git add -A
git commit -m "Wordify web build guncellendi - %date% %time:~0,5%"
git push origin main
echo.

echo ===================================
echo   WEB DEPLOY TAMAMLANDI!
echo   Site: https://lnyctophilia.github.io/WordifyFlutter/
echo ===================================
echo.
pause

