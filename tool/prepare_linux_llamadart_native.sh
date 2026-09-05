#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TAG="b10075"
EXPECTED_COMMIT="0ba009799d7b88ea2851cff4c273a41aa7137224"
SRC="$ROOT/third_party/llamadart-native-$TAG"
BUILD="$SRC/build/linux-x64-full"
BUNDLE="$ROOT/third_party/bin/linux-x64"
JOBS="${JOBS:-$(nproc 2>/dev/null || echo 4)}"

if [[ "$(uname -s)" != "Linux" ]]; then
  exit 0
fi
case "$(uname -m)" in
  x86_64|amd64) ;;
  *) echo "NAZA: local LlamaDart runtime currently targets Linux x86_64." >&2; exit 1 ;;
esac

bundle_works() {
  local required
  for required in libllamadart.so libllama.so libllama-common.so libggml.so libggml-base.so libggml-cpu.so libmtmd.so; do
    [[ -f "$BUNDLE/$required" ]] || return 1
  done
  local lib report="/tmp/naza-llamadart-ldd.$$"
  while IFS= read -r -d '' lib; do
    if ! ldd "$lib" >"$report" 2>&1; then
      rm -f "$report"
      return 1
    fi
    if grep -Eq 'not found|version `GLIBC_[0-9.]+' "$report"; then
      rm -f "$report"
      return 1
    fi
  done < <(find "$BUNDLE" -maxdepth 1 -type f -name '*.so*' -print0)
  rm -f "$report" || true
}

copy_runtime_family() {
  local canonical="$1" source="" soname=""
  source="$(find "$BUILD" -type f \( -name "$canonical" -o -name "$canonical.*" \) -print 2>/dev/null | sort -V | head -n 1 || true)"
  if [[ -z "$source" ]]; then
    echo "NAZA: native build did not produce $canonical." >&2
    return 1
  fi
  cp -f "$source" "$BUNDLE/$canonical"
  soname="$(readelf -d "$BUNDLE/$canonical" 2>/dev/null | sed -n 's/.*(SONAME).*\[\([^]]*\)\].*/\1/p' | head -n 1 || true)"
  if [[ -n "$soname" && "$soname" != "$canonical" ]]; then
    ln -sfn "$canonical" "$BUNDLE/$soname"
  fi
}

stage_bundle_from_build() {
  [[ -d "$BUILD" ]] || return 1
  rm -rf "$BUNDLE"
  mkdir -p "$BUNDLE"
  local required=(
    libllamadart.so
    libllama.so
    libllama-common.so
    libggml.so
    libggml-base.so
    libggml-cpu.so
    libmtmd.so
  )
  local name
  for name in "${required[@]}"; do
    if ! copy_runtime_family "$name"; then
      rm -rf "$BUNDLE"
      return 1
    fi
  done
  if ! bundle_works; then
    echo "NAZA: staged native bundle has unresolved dependencies." >&2
    rm -rf "$BUNDLE"
    return 1
  fi
}

finish_success() {
  # LlamaDart's b10075 asset map includes these versioned aliases even when
  # a host build emits an unversioned SONAME. Replace upstream .0 binaries as
  # well, so the final bundle cannot mix incompatible runtime families.
  ln -sfn libllamadart.so "$BUNDLE/libllamadart.so.0"
  ln -sfn libggml-cpu.so "$BUNDLE/libggml-cpu.so.0"
  local max_glibc
  max_glibc="$(readelf --version-info "$BUNDLE"/*.so 2>/dev/null | grep -oE 'GLIBC_[0-9]+\.[0-9]+' | sort -Vu | tail -1 || true)"
  echo "NAZA: pinned LlamaDart runtime ready at $BUNDLE"
  echo "NAZA: highest referenced GLIBC symbol: ${max_glibc:-not detected}"
}

if bundle_works; then
  finish_success
  exit 0
fi

if stage_bundle_from_build; then
  finish_success
  exit 0
fi

missing=()
for command_name in git cmake ninja pkg-config python3 c++ readelf; do
  command -v "$command_name" >/dev/null 2>&1 || missing+=("$command_name")
done
if [[ "${#missing[@]}" -ne 0 ]]; then
  echo "NAZA: missing native build tools: ${missing[*]}" >&2
  echo "Install the tools explicitly, then rebuild. This script never invokes sudo or a package manager." >&2
  exit 1
fi

mkdir -p "$ROOT/third_party" "$ROOT/third_party/bin"
if [[ ! -d "$SRC/.git" ]]; then
  rm -rf "$SRC"
  git clone --filter=blob:none --no-checkout https://github.com/leehack/llamadart-native.git "$SRC"
fi
git -C "$SRC" fetch --depth 1 origin "$EXPECTED_COMMIT"
git -C "$SRC" checkout --detach "$EXPECTED_COMMIT"
actual_commit="$(git -C "$SRC" rev-parse HEAD)"
if [[ "$actual_commit" != "$EXPECTED_COMMIT" ]]; then
  echo "NAZA: LlamaDart source identity mismatch: $actual_commit" >&2
  exit 1
fi

git -C "$SRC" submodule sync --recursive
git -C "$SRC" submodule update --init --recursive --depth 1

rm -rf "$BUILD"
(
  cd "$SRC"
  cmake --preset linux-x64-full \
    -DGGML_BLAS=OFF \
    -DGGML_VULKAN=OFF \
    -DGGML_OPENCL=OFF \
    -DGGML_CUDA=OFF \
    -DGGML_HIP=OFF \
    -DGGML_ZENDNN=OFF \
    -DGGML_OPENMP=OFF \
    -DGGML_CPU_KLEIDIAI=OFF
  cmake --build --preset linux-x64-full --parallel "$JOBS"
)

if ! stage_bundle_from_build; then
  echo "NAZA: native runtime build completed but packaging failed." >&2
  exit 1
fi
finish_success
