#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_dir"

test -f pubspec.lock
flutter pub get --enforce-lockfile
dart format --output=none --set-exit-if-changed \
  lib/security/aion_*.dart \
  test/aion_*_test.dart
flutter analyze lib/security test/aion_*_test.dart
flutter test \
  test/aion_broker_key_schedule_test.dart \
  test/aion_broker_protocol_test.dart \
  test/aion_entropy_federation_test.dart \
  test/aion_virtual_msl_test.dart \
  test/aion_chaos_observatory_test.dart \
  test/aion_fuzz_test.dart

if [[ "$(uname -s)" == "Linux" ]]; then
  sandbox_build_dir="$(mktemp -d /tmp/naza-aion-sandbox.XXXXXX)"
  tool/aion_broker/build_linux_sandbox.sh "$sandbox_build_dir"
  rm "$sandbox_build_dir/aion_linux_sandbox"
  rmdir "$sandbox_build_dir"
fi
