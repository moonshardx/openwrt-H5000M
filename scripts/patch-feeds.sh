#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC_DIR="${ROOT_DIR}/openwrt"

patch_tcping() {
  local makefile="${SRC_DIR}/package/feeds/small_package/tcping/Makefile"

  [ -f "${makefile}" ] || return 0

  if grep -q 'STRIP=true' "${makefile}"; then
    echo "tcping feed patch already applied."
    return 0
  fi

  sed -i 's|LDFLAGS="$(TARGET_LDFLAGS)"|LDFLAGS="$(TARGET_LDFLAGS)" STRIP=true|' "${makefile}"
  echo "Patched tcping feed package to skip upstream strip."
}

patch_tcping
