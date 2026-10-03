#!/usr/bin/env bash
# Boots an Android emulator on the CI runner and takes widget screenshots.
set -x
SDK=${ANDROID_SDK_ROOT:-$ANDROID_HOME}
export PATH="$SDK/cmdline-tools/latest/bin:$SDK/emulator:$SDK/platform-tools:$PATH"
IMG="system-images;android-33;default;x86_64"
yes | sdkmanager --licenses > /dev/null
sdkmanager "emulator" "platform-tools" "$IMG" | tail -3
echo no | avdmanager create avd -n shots -k "$IMG" -d pixel_6 --force
avdmanager list avd
export ANDROID_AVD_HOME=$(dirname "$(find "$HOME" -maxdepth 5 -name shots.avd | head -1)")
echo "AVD home: $ANDROID_AVD_HOME"
ls -la /dev/kvm
emulator -avd shots -no-window -no-boot-anim -gpu swiftshader_indirect -no-snapshot -camera-back none -accel on > shots/emulator_log.txt 2>&1 &
sleep 20
tail -20 shots/emulator_log.txt
for i in $(seq 1 150); do
  [ "$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = "1" ] && break
  sleep 5
done
adb shell getprop sys.boot_completed
adb shell settings put global window_animation_scale 0
adb shell settings put global transition_animation_scale 0
bash tool/ci/${PROBE_SCRIPT:-widget_shots.sh}
adb emu kill || true
