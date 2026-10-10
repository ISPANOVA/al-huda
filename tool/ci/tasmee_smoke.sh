#!/usr/bin/env bash
# Inside the emulator: install the published build, upgrade it with the new
# APK, open the Tasmee and turn the on-device recogniser on.
set -x
OUT=shots
PKG=com.alhuda.islamic.app
shot() { sleep "${2:-3}"; adb exec-out screencap -p > "$OUT/$1.png"; python3 tool/ci/ui.py dump "$OUT/$1_labels.txt"; }
tap() { python3 tool/ci/ui.py tap "$1" | tee -a "$OUT/steps.txt"; }
tapxy() { python3 tool/ci/ui.py tapxy "$1" "$2" | tee -a "$OUT/steps.txt"; }
launch() { adb shell am force-stop $PKG; adb shell am start -W -n $PKG/.MainActivity >> "$OUT/steps.txt"; }
adb emu geo fix 31.2357 30.0444 || true
adb install -r -t old.apk | tee "$OUT/install_old.txt"
adb shell pm grant $PKG android.permission.POST_NOTIFICATIONS || true
launch; sleep 14
tap 'تخطي'; sleep 2; tap 'ابدأ'; sleep 5
adb install -r -t new.apk | tee "$OUT/install_new.txt"
adb shell pm grant $PKG android.permission.ACCESS_FINE_LOCATION || true
adb shell pm grant $PKG android.permission.RECORD_AUDIO || true
adb logcat -c
launch; shot T1_after_upgrade 14
tap 'لاحقًا'; sleep 2
tapxy 0.61 0.90; shot T2_mushaf 5
tap 'تخطي'; sleep 2
tap 'التسميع'; shot T3_tasmee 6
tap 'ابدأ التسميع بالميكروفون'; shot T4_mic_on 25
shot T5_listening 10
tap 'إيقاف الاستماع'; shot T6_stopped 4
tap 'إخفاء الآيات (اختبار الحفظ)'; shot T7_hidden 3
tap 'ابدأ التسميع بالميكروفون'; shot T8_mic_again 8
tap 'إيقاف الاستماع'; sleep 2
adb shell input keyevent KEYCODE_BACK; shot T9_summary 3
adb shell input keyevent KEYCODE_BACK; sleep 2
launch; shot T10_relaunch 12
adb shell dumpsys meminfo $PKG | head -40 > "$OUT/meminfo.txt"
adb logcat -d > "$OUT/logcat.txt"
grep -E "FATAL|E/flutter| E flutter|Unhandled Exception|sherpa|onnx|I flutter" "$OUT/logcat.txt" | head -200 > "$OUT/errors.txt" || true
exit 0
