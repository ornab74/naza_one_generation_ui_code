#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PREPARE="$ROOT/tool/prepare_linux_llamadart_native.sh"
SOURCE_BUNDLE="$ROOT/third_party/bin/linux-x64"
TEST_ROOT="$(mktemp -d /tmp/naza-llamadart-security.XXXXXX)"
trap 'rm -rf "$TEST_ROOT"' EXIT

"$PREPARE" --verify-bundle "$SOURCE_BUNDLE"

cp -a "$SOURCE_BUNDLE/." "$TEST_ROOT/"
printf x >>"$TEST_ROOT/libllamadart.so"
if "$PREPARE" --verify-bundle "$TEST_ROOT"; then
  echo 'tampered LlamaDart library was accepted' >&2
  exit 1
fi

rm -rf "$TEST_ROOT"
mkdir -p "$TEST_ROOT"
cp -a "$SOURCE_BUNDLE/." "$TEST_ROOT/"
cp /bin/true "$TEST_ROOT/libunexpected.so"
if "$PREPARE" --verify-bundle "$TEST_ROOT"; then
  echo 'unexpected native library was accepted' >&2
  exit 1
fi
