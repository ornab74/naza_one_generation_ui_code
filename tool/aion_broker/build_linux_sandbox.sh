#!/usr/bin/env bash
set -euo pipefail

source_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
output_dir="${1:-$source_dir/build}"
mkdir -p "$output_dir"

cc -std=c17 -O2 -fPIE -fstack-protector-strong -D_FORTIFY_SOURCE=3 \
  -Wall -Wextra -Werror -Wformat=2 -Wconversion -Wshadow \
  -Wl,-z,relro,-z,now,-z,noexecstack -pie \
  "$source_dir/aion_linux_sandbox.c" \
  -o "$output_dir/aion_linux_sandbox"

"$output_dir/aion_linux_sandbox" --self-test
sha256sum "$output_dir/aion_linux_sandbox"
