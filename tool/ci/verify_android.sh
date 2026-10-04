#!/usr/bin/env bash
# Inside the emulator job: install the published build 31, use it, then
# install the new APK over it (same signature, data kept) and walk through
# the main screens, recording screenshots and any crash / Flutter error.
set -x
OUT=shots
PKG=com.alhuda.islamic.app
shot() { sleep "${2:-3}"; adb exec-out screencap -p > "$OUT/$1.png"; }
tap() { python3 tool/ci/ui.py tap "$1" | tee -a "$OUT/steps.txt"; }
launch() { adb shell am force-stop $PKG; adb shell am start -W -n $PKG/.MainActivity | tee -a "$OUT/steps.txt"; }

adb install -r -t old.apk | tee "$OUT/install_old.txt"
adb shell pm grant $PKG android.permission.POST_NOTIFICATIONS || true
adb logcat -c
launch; shot A1_launch 14
tap 'تخطي'; shot A2_permissions 3
tap 'ابدأ'; shot A3_home 6
python3 tool/ci/ui.py dump "$OUT/A3_labels.txt"
adb logcat -d > "$OUT/A_logcat.txt"

# Upgrade in place, exactly like a tester installing the new APK.
adb install -r -t new.apk | tee "$OUT/install_new.txt"
adb shell dumpsys package $PKG | grep -E "versionCode|versionName|lastUpdateTime" > "$OUT/package_after_upgrade.txt"
adb logcat -c
launch; shot B1_after_upgrade 14
python3 tool/ci/ui.py dump "$OUT/B1_labels.txt"
tap 'المصحف'; shot B2_mushaf 5
tap 'تخطي'; shot B3_mushaf_page 3
tap 'التسميع'; shot B4_tasmee 5
python3 tool/ci/ui.py dump "$OUT/B4_labels.txt"
adb shell input keyevent KEYCODE_BACK; sleep 2
tap 'الصلاة'; shot B5_prayer 4
tap 'الوسائط'; shot B6_media 4
tap 'القاهرة'; sleep 1; tap 'إذاعة القرآن الكريم من'; shot B7_radio 8
adb shell dumpsys media_session | grep -E "state=|description=" | head -20 > "$OUT/B7_media_session.txt"
tap 'الرئيسية'; shot B8_home 3
launch; shot B9_relaunch 12
adb logcat -d > "$OUT/B_logcat.txt"
grep -E "FATAL|AndroidRuntime: |E/flutter|Unhandled Exception|ALHUDA" "$OUT/A_logcat.txt" > "$OUT/A_errors.txt" || true
grep -E "FATAL|AndroidRuntime: |E/flutter|Unhandled Exception|ALHUDA" "$OUT/B_logcat.txt" > "$OUT/B_errors.txt" || true
exit 0
