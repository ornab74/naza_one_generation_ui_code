# Naza Route Engine v7.0.77 — GPS-only repair

This repaired source package keeps the public version name **7.0.77** and
advances the Android/Flutter build number to **8**.

## Fixed

- Android Flutter location requests now use the app-native `GPS_PROVIDER` bridge
  instead of the Google Play Services fused provider.
- Native background offer analysis reads only `LocationManager.GPS_PROVIDER`.
- Native background analysis can request one fresh GPS/GNSS fix (up to 8 seconds)
  when the cached satellite fix is stale.
- Wi-Fi/network location providers are not enumerated or used.
- The Android manifest explicitly removes `NEARBY_WIFI_DEVICES`,
  `ACCESS_WIFI_STATE`, `CHANGE_WIFI_STATE`, and `CHANGE_WIFI_MULTICAST_STATE` if
  any transitive dependency attempts to merge them.
- The UI wording `Scanning live radar` was changed to `Fetching live radar` to
  avoid confusing internet radar downloads with device Wi-Fi scanning.
- Added `tool/verify_gps_only.sh` and wired it into CI to catch regressions.

## Expected Android behavior

Keep normal Android Location/GPS enabled and grant Naza precise location. Wi-Fi
scanning may remain disabled. Naza should use satellite/GNSS positioning. If a
GPS fix cannot be obtained (commonly indoors), location-dependent analysis may
be unavailable or use the configured ZIP fallback; Naza should not ask you to
enable Wi-Fi scanning.
