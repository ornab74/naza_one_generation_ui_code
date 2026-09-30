#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

fail=0

# Application code must not call Wi-Fi scanning / SSID / BSSID APIs.
if grep -RInE --exclude-dir=build --exclude-dir=.dart_tool --exclude='verify_gps_only.sh' \
  '(WifiManager|startScan\(|getScanResults\(|SSID|BSSID|wifi_scan|connectivity_plus|NEARBY_WIFI_DEVICES)' \
  lib android/app/src/main/kotlin android/app/src/main/java 2>/dev/null; then
  echo 'ERROR: Wi-Fi scanning/network-identification code detected.' >&2
  fail=1
fi

# Flutter Android location must use the native GPS-only bridge rather than FusedLocationProviderClient.
if ! grep -q "invokeMapMethod<String, dynamic>('getGpsPosition')" lib/main.dart; then
  echo 'ERROR: Flutter Android location is not using the native GPS-only bridge.' >&2
  fail=1
fi
if ! grep -q '"getGpsPosition"' android/app/src/main/kotlin/com/qroadsan/routengine/MainActivity.kt; then
  echo 'ERROR: Native GPS-only bridge is missing.' >&2
  fail=1
fi

# Native background location must be GPS provider only.
if ! grep -q 'getLastKnownLocation(LocationManager.GPS_PROVIDER)' \
  android/app/src/main/kotlin/com/qroadsan/routengine/OnlineDecisionPipeline.kt; then
  echo 'ERROR: Native pipeline is not pinned to GPS_PROVIDER.' >&2
  fail=1
fi
if ! grep -q 'getCurrentLocation(' android/app/src/main/kotlin/com/qroadsan/routengine/MainActivity.kt || \
   ! grep -q 'LocationManager.GPS_PROVIDER' android/app/src/main/kotlin/com/qroadsan/routengine/MainActivity.kt; then
  echo 'ERROR: Foreground location bridge is not pinned to GPS_PROVIDER.' >&2
  fail=1
fi
if grep -q 'getProviders(true)' \
  android/app/src/main/kotlin/com/qroadsan/routengine/OnlineDecisionPipeline.kt; then
  echo 'ERROR: Native pipeline still enumerates network/fused providers.' >&2
  fail=1
fi

# Manifest must actively remove Wi-Fi permissions if dependencies try to merge them.
for permission in \
  android.permission.NEARBY_WIFI_DEVICES \
  android.permission.ACCESS_WIFI_STATE \
  android.permission.CHANGE_WIFI_STATE \
  android.permission.CHANGE_WIFI_MULTICAST_STATE; do
  if ! grep -A2 -F "android:name=\"$permission\"" android/app/src/main/AndroidManifest.xml | grep -q 'tools:node="remove"'; then
    echo "ERROR: $permission is not explicitly removed by manifest merger." >&2
    fail=1
  fi
done

if (( fail != 0 )); then
  exit 1
fi

echo 'GPS-only privacy guard passed: no app Wi-Fi scanning path detected.'
