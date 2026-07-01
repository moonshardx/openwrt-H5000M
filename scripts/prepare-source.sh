#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC_DIR="${OPENWRT_SRC_DIR:-${ROOT_DIR}/openwrt}"
REF="${1:-${OPENWRT_REF:-v25.12.5}}"
REPO_URL="${OPENWRT_REPO:-https://github.com/openwrt/openwrt.git}"

INCLUDE_QMODEM_ORIGINAL="${INCLUDE_QMODEM_ORIGINAL:-${INCLUDE_QMODEM:-false}}"
INCLUDE_QMODEM_NEXT="${INCLUDE_QMODEM_NEXT:-false}"
INCLUDE_PASSWALL2="${INCLUDE_PASSWALL2:-${INCLUDE_PASSWALL:-false}}"
INCLUDE_MOSDNS="${INCLUDE_MOSDNS:-false}"
INCLUDE_UPNP="${INCLUDE_UPNP:-false}"
INCLUDE_HOMEPROXY="${INCLUDE_HOMEPROXY:-false}"
INCLUDE_NIKKI="${INCLUDE_NIKKI:-false}"

git config --global --unset-all http.proxy >/dev/null 2>&1 || true
git config --global --unset-all https.proxy >/dev/null 2>&1 || true
git config --global http.version HTTP/1.1
git config --global http.lowSpeedLimit 0
git config --global http.postBuffer 524288000

if [ -d "${SRC_DIR}/.git" ]; then
  echo "更新已有 OpenWrt 官方源码：${REF}"
  git -C "${SRC_DIR}" remote set-url origin "${REPO_URL}"
  git -C "${SRC_DIR}" reset --hard HEAD
  if git -C "${SRC_DIR}" rev-parse --verify --quiet "refs/tags/${REF}^{commit}" >/dev/null; then
    git -C "${SRC_DIR}" checkout --detach "refs/tags/${REF}^{commit}"
  else
    git -C "${SRC_DIR}" fetch --tags --depth=1 origin "${REF}"
    git -C "${SRC_DIR}" checkout --detach FETCH_HEAD
  fi
else
  echo "克隆 OpenWrt 官方源码：${REF}"
  mkdir -p "$(dirname "${SRC_DIR}")"
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

# OpenWrt 25.x may carry the optional video feed. H5000M does not use it, and
# GitHub-side TLS interruptions on this feed can fail the whole feed update.
sed -i '/^[[:space:]]*src-git[[:space:]]\+video[[:space:]]/d' "${SRC_DIR}/feeds.conf.default"

append_feed_once() {
  local feed_line="$1"
  local feed_name
  feed_name="$(printf '%s\n' "${feed_line}" | awk '{print $2}')"
  if ! grep -Eq "^src-git[[:space:]]+${feed_name}[[:space:]]" "${SRC_DIR}/feeds.conf.default"; then
    printf '%s\n' "${feed_line}" >> "${SRC_DIR}/feeds.conf.default"
  fi
}

need_small_package=false
if [ "${INCLUDE_PASSWALL2}" = "true" ] || \
   [ "${INCLUDE_MOSDNS}" = "true" ] || \
   [ "${INCLUDE_HOMEPROXY}" = "true" ]; then
  need_small_package=true
fi

if [ "${INCLUDE_QMODEM_ORIGINAL}" = "true" ] && [ "${INCLUDE_QMODEM_NEXT}" = "true" ]; then
  echo "QModem 原版和 QModem Next 只能二选一，请关闭其中一个。"
  exit 1
fi

if [ "${INCLUDE_QMODEM_ORIGINAL}" = "true" ] || [ "${INCLUDE_QMODEM_NEXT}" = "true" ]; then
  echo "添加 QModem 第三方 feed：FUjr/QModem"
  append_feed_once "src-git qmodem https://github.com/FUjr/QModem.git"
fi

if [ "${need_small_package}" = "true" ]; then
  echo "添加 kenzok8/small-package 插件 feed"
  append_feed_once "src-git small_package https://github.com/kenzok8/small-package.git"
fi

if [ "${INCLUDE_NIKKI}" = "true" ]; then
  echo "添加 Nikki 第三方 feed：nikkinikki-org/OpenWrt-nikki"
  append_feed_once "src-git nikki https://github.com/nikkinikki-org/OpenWrt-nikki.git"
fi

echo "克隆 Argon 主题到 package/（Argon 仓库 Makefile 在根目录，无法作为 src-git feed 使用）"
clone_package() {
  local name="$1" url="$2" attempt
  rm -rf "${SRC_DIR}/package/${name}"
  for attempt in 1 2 3; do
    if git clone --depth=1 "${url}" "${SRC_DIR}/package/${name}"; then
      return 0
    fi
    echo "克隆 ${name} 失败，重试：${attempt}/3"
    rm -rf "${SRC_DIR}/package/${name}"
    sleep 5
  done
  echo "克隆 ${name} 失败。"
  exit 1
}
clone_package luci-theme-argon https://github.com/jerrykuku/luci-theme-argon.git
clone_package luci-app-argon-config https://github.com/jerrykuku/luci-app-argon-config.git

echo "写入默认 LAN IP、root 密码、WAN 优先级和软件源清理脚本"
mkdir -p "${SRC_DIR}/files"
cp -a "${ROOT_DIR}/files/." "${SRC_DIR}/files/"

echo "写入 H5000M 自定义软件包"
rm -rf "${SRC_DIR}/package/h5000m-custom"
mkdir -p "${SRC_DIR}/package/h5000m-custom"
cp -a "${ROOT_DIR}/packages/." "${SRC_DIR}/package/h5000m-custom/"

echo "OpenWrt 官方源码已准备完成：${SRC_DIR}"
echo "当前源码版本：${REF}"
echo "后续本地编译步骤："
echo "  cd ${SRC_DIR}"
echo "  ./scripts/feeds update -a"
echo "  ./scripts/feeds install -a"
echo "  INCLUDE_QMODEM_ORIGINAL=${INCLUDE_QMODEM_ORIGINAL} INCLUDE_QMODEM_NEXT=${INCLUDE_QMODEM_NEXT} INCLUDE_PASSWALL2=${INCLUDE_PASSWALL2} INCLUDE_MOSDNS=${INCLUDE_MOSDNS} INCLUDE_UPNP=${INCLUDE_UPNP} INCLUDE_HOMEPROXY=${INCLUDE_HOMEPROXY} INCLUDE_NIKKI=${INCLUDE_NIKKI} bash ${ROOT_DIR}/scripts/apply-package-options.sh"
echo "  make defconfig"
echo "  make download -j\$(nproc)"
echo "  make -j\$(nproc)"
