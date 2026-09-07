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

# Exercise the internal post-build gate with a harmless changed ELF (a trailing
# byte leaves its loader behavior intact). It must accept host-specific output,
# while the public cache gate above must still reject that same file.
verify_fresh_fixture() (
  source <(sed '/^if .*--verify-bundle/,$d' "$PREPARE")
  bundle_works "$TEST_ROOT" fresh-build
)
verify_fresh_fixture

rm -rf "$TEST_ROOT"
mkdir -p "$TEST_ROOT"
cp -a "$SOURCE_BUNDLE/." "$TEST_ROOT/"
cp /bin/true "$TEST_ROOT/libunexpected.so"
if "$PREPARE" --verify-bundle "$TEST_ROOT"; then
  echo 'unexpected native library was accepted' >&2
  exit 1
fi
if verify_fresh_fixture; then
  echo 'unexpected native library was accepted by fresh-build validation' >&2
  exit 1
fi

# There must be no stale-build promotion before the source fetch/build path.
if sed '/^missing=()/,$d' "$PREPARE" | grep -q '^if stage_bundle_from_build'; then
  echo 'unverified stale build promotion is enabled' >&2
  exit 1
fi
