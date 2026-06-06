include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-h5000m-fancontrol
PKG_VERSION:=1.0.0
PKG_RELEASE:=1

LUCI_TITLE:=H5000M fan control
LUCI_DEPENDS:=+luci-base +kmod-hwmon-pwmfan
LUCI_PKGARCH:=all

include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature
