#!/usr/bin/env bash
set -euo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if grep -q "invokeMapMethod<String, dynamic>('getGpsPosition')" lib/main.dart; then
  echo "GPS-only Dart repair already applied."
  exit 0
fi
git apply --check tool/lib_main_gps_repair.patch
git apply tool/lib_main_gps_repair.patch
echo "Applied GPS-only Dart repair."
