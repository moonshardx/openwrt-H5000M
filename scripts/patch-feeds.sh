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

patch_python_build_backend() {
  local makefile="$1"
  local package_name="$2"

  [ -f "${makefile}" ] || return 0

  if grep -q '^PKG_BUILD_DEPENDS=.*python-setuptools/host' "${makefile}"; then
    echo "${package_name} feed patch already applied."
    return 0
  fi

  sed -i '/^include \.\.\/pypi\.mk$/i PKG_BUILD_DEPENDS:=python-setuptools/host' "${makefile}"
  echo "Patched ${package_name} feed package to provide setuptools build backend."
}

patch_tcping
patch_python_build_backend "${SRC_DIR}/package/feeds/packages/python-pyserial/Makefile" "python-pyserial"
patch_python_build_backend "${SRC_DIR}/package/feeds/packages/python-websockets/Makefile" "python-websockets"
