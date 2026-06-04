#!/usr/bin/env bash
set -euo pipefail

REF="${1:-v25.12.0}"
REPO_URL="${IMMORTALWRT_REPO:-https://github.com/immortalwrt/immortalwrt.git}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC_DIR="${ROOT_DIR}/openwrt"
INCLUDE_QMODEM="${INCLUDE_QMODEM:-false}"
INCLUDE_PASSWALL="${INCLUDE_PASSWALL:-false}"
INCLUDE_MOSDNS="${INCLUDE_MOSDNS:-false}"
INCLUDE_UPNP="${INCLUDE_UPNP:-false}"
INCLUDE_HOMEPROXY="${INCLUDE_HOMEPROXY:-false}"

if [ -d "${SRC_DIR}/.git" ]; then
  echo "更新已有 ImmortalWrt 源码：${REF}"
  git -C "${SRC_DIR}" fetch --tags --depth=1 origin "${REF}"
  git -C "${SRC_DIR}" checkout --detach FETCH_HEAD
else
  echo "克隆 ImmortalWrt 源码：${REF}"
  git clone --depth=1 --branch "${REF}" "${REPO_URL}" "${SRC_DIR}"
fi

echo "应用 H5000M 设备适配"
python3 "${ROOT_DIR}/scripts/apply-h5000m.py" "${SRC_DIR}"

for patch in "${ROOT_DIR}"/patches/optional/*.patch; do
  [ -e "${patch}" ] || continue
  if git -C "${SRC_DIR}" apply --check "${patch}" >/dev/null 2>&1; then
    git -C "${SRC_DIR}" apply "${patch}"
    echo "已应用可选补丁：$(basename "${patch}")"
  else
    echo "跳过不兼容的可选补丁：$(basename "${patch}")"
  fi
done

cp "${ROOT_DIR}/configs/h5000m.seed" "${SRC_DIR}/.config"

append_feed_once() {
  local feed_line="$1"
  local feed_name
  feed_name="$(printf '%s\n' "${feed_line}" | awk '{print $2}')"
  if ! grep -Eq "^src-git[[:space:]]+${feed_name}[[:space:]]" "${SRC_DIR}/feeds.conf.default"; then
    printf '%s\n' "${feed_line}" >> "${SRC_DIR}/feeds.conf.default"
  fi
}

append_config() {
  cat >> "${SRC_DIR}/.config"
}

if [ "${INCLUDE_QMODEM}" = "true" ]; then
  echo "启用 QModem 相关包"
  append_feed_once "src-git qmodem https://github.com/FUjr/QModem.git"
  append_config <<'EOF'
CONFIG_PACKAGE_qmodem=y
CONFIG_PACKAGE_luci-app-qmodem-next=y
CONFIG_PACKAGE_luci-app-qmodem-monitor=y
CONFIG_PACKAGE_luci-app-qmodem-ttlfw4=y
CONFIG_PACKAGE_qmodem_monitor=y
CONFIG_PACKAGE_modem_scan=y
CONFIG_PACKAGE_ubus-at-daemon=y
CONFIG_PACKAGE_tom_modem=y
CONFIG_PACKAGE_sms-tool_q=y
CONFIG_PACKAGE_sms-forwarder-next=y
CONFIG_PACKAGE_qfirehose=y
CONFIG_PACKAGE_ndisc6=y
CONFIG_PACKAGE_quectel-CM-5G-M=y
CONFIG_PACKAGE_kmod-pcie_mhi=y
CONFIG_PACKAGE_kmod-qmi_wwan_q=y
CONFIG_PACKAGE_kmod-qmi_wwan_f=y
CONFIG_PACKAGE_kmod-qmi_wwan_s=y
# CONFIG_PACKAGE_luci-app-qmodem is not set
# CONFIG_PACKAGE_luci-app-qmodem-sms is not set
# CONFIG_PACKAGE_luci-app-qmodem-ttl is not set
# CONFIG_PACKAGE_luci-app-qmodem-mwan is not set
# CONFIG_PACKAGE_luci-app-qmodem-hc is not set
# CONFIG_PACKAGE_sms-forwarder is not set
EOF
fi

if [ "${INCLUDE_PASSWALL}" = "true" ]; then
  echo "启用 PassWall"
  append_config <<'EOF'
CONFIG_PACKAGE_luci-app-passwall=y
EOF
fi

if [ "${INCLUDE_MOSDNS}" = "true" ]; then
  echo "启用 MosDNS"
  append_config <<'EOF'
CONFIG_PACKAGE_luci-app-mosdns=y
CONFIG_PACKAGE_mosdns=y
EOF
fi

if [ "${INCLUDE_UPNP}" = "true" ]; then
  echo "启用 UPnP"
  append_config <<'EOF'
CONFIG_PACKAGE_luci-app-upnp=y
EOF
fi

if [ "${INCLUDE_HOMEPROXY}" = "true" ]; then
  echo "启用 HomeProxy"
  append_config <<'EOF'
CONFIG_PACKAGE_luci-app-homeproxy=y
EOF
fi

echo "写入默认 LAN IP、root 密码和软件源清理脚本"
mkdir -p "${SRC_DIR}/files/etc/uci-defaults"
cp "${ROOT_DIR}/files/etc/uci-defaults/99-h5000m-defaults" \
  "${SRC_DIR}/files/etc/uci-defaults/99-h5000m-defaults"

echo "ImmortalWrt 源码已准备完成：${SRC_DIR}"
echo "当前源码版本：${REF}"
echo "后续本地编译步骤："
echo "  cd ${SRC_DIR}"
echo "  ./scripts/feeds update -a"
echo "  ./scripts/feeds install -a"
echo "  make defconfig"
echo "  make download -j\$(nproc)"
echo "  make -j\$(nproc)"
