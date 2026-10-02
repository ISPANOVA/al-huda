@echo off
REM Al-Huda one-shot setup for Windows
cd /d "%~dp0"
echo ==^> flutter create
call flutter create --org com.alhuda.islamic --project-name al_huda --platforms android . || goto :error
echo ==^> flutter pub get
call flutter pub get || goto :error
echo ==^> Configure native projects
call dart run tool/configure_platforms.dart || goto :error
echo ==^> Launcher icons
call dart run flutter_launcher_icons -f flutter_launcher_icons_android.yaml || goto :error
echo.
echo Done. Run the app with:  flutter run
goto :eof
:error
echo Setup failed with error %errorlevel%.
exit /b %errorlevel%
