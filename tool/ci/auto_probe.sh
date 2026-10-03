#!/usr/bin/env bash
# Inside the emulator job: behave like Android Auto and record what happens,
# first with the app closed (car starts it), then with the app open.
set -x
bash tool/ci/push_shots.sh boot
adb install -r -t build/app/outputs/flutter-apk/app-release.apk || adb install -r -t build/app/outputs/flutter-apk/app-debug.apk
adb shell pm grant com.alhuda.islamic.app android.permission.POST_NOTIFICATIONS || true
run() {
  name=$1
  adb logcat -c
  adb shell am start -n com.alhuda.islamic.app/com.alhuda.islamic.app.AutoProbeActivity
  for t in 30 60 90; do
    sleep 30
    adb shell dumpsys media_session > shots/${name}_media_session_$t.txt
  done
  sleep 30
  adb logcat -d > shots/${name}_logcat.txt
  grep -E "AUTOPROBE|ALHUDA|System.err|flutter|AudioService|ExoPlayer|AndroidRuntime|audio_service|MediaSession|MediaBrowser" shots/${name}_logcat.txt > shots/${name}_probe.txt
  bash tool/ci/push_shots.sh "$name"
}
run closed
adb shell am force-stop com.alhuda.islamic.app
adb shell am start -n com.alhuda.islamic.app/.MainActivity
sleep 15
adb exec-out screencap -p > shots/app_open.png
run open
exit 0
