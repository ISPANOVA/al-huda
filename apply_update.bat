@echo off
chcp 65001 >nul
cd /d E:\al_huda
set "PATH=E:\flutter\bin;%PATH%"
set "ANDROID_HOME=E:\SDKAndroid"
set "ANDROID_SDK_ROOT=E:\SDKAndroid"
set "JAVA_HOME=E:\Android\jbr"
set "LOG=E:\al_huda\build_log.txt"
echo ==== UPDATE %date% %time% > "%LOG%"
if exist update.zip tar -xf update.zip >> "%LOG%" 2>&1
echo ==== STEP move obsolete files >> "%LOG%"
if not exist _obsolete mkdir _obsolete
for %%F in (
  lib\features\quran\presentation\pages\quran_home_page.dart
  lib\features\quran\presentation\pages\surah_reader_page.dart
  lib\features\quran\presentation\widgets\ayah_card.dart
  lib\features\quran\presentation\cubit\quran_reader_cubit.dart
  lib\features\quran\data\datasources\quran_remote_data_source.dart
  lib\features\quran\data\datasources\quran_local_data_source.dart
) do if exist "%%F" move /Y "%%F" "_obsolete\%%~nF.dart.bak" >> "%LOG%" 2>&1
echo ==== STEP pub get >> "%LOG%"
call flutter pub get >> "%LOG%" 2>&1
echo ==== STEP launcher icons >> "%LOG%"
call dart run flutter_launcher_icons >> "%LOG%" 2>&1
echo ==== STEP configure >> "%LOG%"
call dart run tool/configure_platforms.dart >> "%LOG%" 2>&1
echo ==== STEP analyze >> "%LOG%"
call flutter analyze --no-fatal-infos --no-fatal-warnings >> "%LOG%" 2>&1
echo ==== STEP build >> "%LOG%"
call flutter build apk --release >> "%LOG%" 2>&1
echo ==== BUILD EXIT %errorlevel% >> "%LOG%"
echo ==== DONE >> "%LOG%"
