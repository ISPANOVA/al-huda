#!/usr/bin/env bash
# Inside the emulator job: behave like Android Auto and record what happens.
set -x
adb install -r -t build/app/outputs/flutter-apk/app-release.apk || adb install -r -t build/app/outputs/flutter-apk/app-debug.apk
adb shell pm grant com.alhuda.islamic.app android.permission.POST_NOTIFICATIONS || true
adb logcat -c
adb shell am start -n com.alhuda.islamic.app/com.alhuda.islamic.app.AutoProbeActivity
for t in 10 30 50 70 90 110; do
  sleep 20
  adb shell dumpsys media_session > shots/media_session_$t.txt
done
sleep 10
adb logcat -d > shots/logcat_full.txt
grep -E "AUTOPROBE|flutter|AudioService|ExoPlayer|AndroidRuntime|audio_service|MediaSession" shots/logcat_full.txt > shots/probe.txt
exit 0
