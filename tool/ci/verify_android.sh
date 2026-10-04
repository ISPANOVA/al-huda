#!/usr/bin/env bash
# Inside the emulator job: install the published build 31, use it, then
# install the new APK over it (same signature, data kept) and walk through
# the main screens, recording screenshots and any crash / Flutter error.
set -x
OUT=shots
PKG=com.alhuda.islamic.app
shot() { sleep "${2:-3}"; adb exec-out screencap -p > "$OUT/$1.png"; python3 tool/ci/ui.py dump "$OUT/$1_labels.txt"; }
tap() { python3 tool/ci/ui.py tap "$1" | tee -a "$OUT/steps.txt"; }
tapxy() { python3 tool/ci/ui.py tapxy "$1" "$2" | tee -a "$OUT/steps.txt"; }
launch() { adb shell am force-stop $PKG; adb shell am start -W -n $PKG/.MainActivity >> "$OUT/steps.txt"; }
adb emu geo fix 31.2357 30.0444 || true

# ---- Build 31, as testers have it now.
adb install -r -t old.apk | tee "$OUT/install_old.txt"
adb shell pm grant $PKG android.permission.POST_NOTIFICATIONS || true
adb logcat -c
launch; shot A1_launch 14
tap 'تخطي'; shot A2_permissions 3
tap 'ابدأ'; shot A3_home 6
# Second start of build 31 (does it ask for the location too?).
launch; shot A4_relaunch 14
adb logcat -d > "$OUT/A_logcat.txt"
# Allow the location from here on so no system prompt covers the screens.
adb shell pm grant $PKG android.permission.ACCESS_FINE_LOCATION || true
adb shell pm grant $PKG android.permission.ACCESS_COARSE_LOCATION || true

# ---- Upgrade in place, exactly like a tester installing the new APK.
adb install -r -t new.apk | tee "$OUT/install_new.txt"
adb shell dumpsys package $PKG | grep -E "versionCode|versionName|lastUpdateTime|granted=true" > "$OUT/package_after_upgrade.txt"
adb logcat -c
launch; shot B1_after_upgrade 14
tap 'المصحف'; shot B2_mushaf 5
tap 'تخطي'; shot B3_mushaf_page 3
tap 'التسميع'; shot B4_tasmee 5
tap 'الكلمة التالية'; shot B5_tasmee_hint 3
adb shell input keyevent KEYCODE_BACK; sleep 3
adb shell input keyevent KEYCODE_BACK; sleep 3
launch; sleep 12
tapxy 0.36 0.90; shot B6_tab_clock 4
tapxy 0.48 0.90; shot B7_tab_media 4
tap 'القاهرة'; sleep 1; tap 'إذاعة القرآن الكريم'; shot B8_radio 10
adb shell dumpsys media_session | grep -E "state=PlaybackState|description=" | head -12 > "$OUT/B8_media_session.txt"
tapxy 0.12 0.90; shot B9_tab_more 4
tap 'الإعدادات'; shot B10_settings 4
launch; shot B11_relaunch 12
# ---- Phone turned sideways: stays portrait with one page.
adb shell settings put system accelerometer_rotation 0
adb shell settings put system user_rotation 1
launch; sleep 12; tap 'المصحف'; shot C1_phone_landscape 5
# ---- Same emulator as a tablet (800dp wide): landscape two pages, portrait one.
adb shell wm size 1600x2560; adb shell wm density 320
launch; sleep 12; tap 'المصحف'; shot C2_tablet_landscape 5
adb shell settings put system user_rotation 0; shot C3_tablet_portrait 6
adb shell settings put system user_rotation 1; shot C4_tablet_landscape_again 6
# Open the app with the tablet already sideways (it must not start in portrait).
launch; sleep 12; shot C5_tablet_landscape_launch 2
adb shell wm size reset; adb shell wm density reset; adb shell settings put system user_rotation 0
adb logcat -d > "$OUT/B_logcat.txt"
for p in A B; do
  grep -E "FATAL|E/flutter| E flutter|Unhandled Exception|I flutter : [A-Z]" "$OUT/${p}_logcat.txt" | grep -v "I flutter : #" > "$OUT/${p}_errors.txt" || true
done
exit 0
