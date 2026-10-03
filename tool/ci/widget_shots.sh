#!/usr/bin/env bash
# Runs inside the emulator job: installs the debug APK and screenshots the
# widget preview screen (solid, transparent, half).
set -x
timeout 60 adb wait-for-device
adb shell getprop sys.boot_completed
adb install -r -t build/app/outputs/flutter-apk/app-debug.apk || adb install -r -t -g build/app/outputs/flutter-apk/app-debug.apk
adb shell pm list packages | grep alhuda
for o in 1 0 0.5; do
  for p in 0 1; do
    adb shell am force-stop com.alhuda.islamic.app
    timeout 60 adb shell am start -W -n com.alhuda.islamic.app/com.alhuda.islamic.app.WidgetPreviewActivity --ef opacity $o --ei page $p
    sleep 7
    adb exec-out screencap -p > shots/w_${p}_${o}.png
  done
done
adb logcat -d AndroidRuntime:E *:S > shots/crash.txt
adb logcat -d -t 600 > shots/logcat.txt
exit 0
