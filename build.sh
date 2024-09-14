#!/usr/bin/env bash

# Note: this runs as-is, pretty much without external
# dependencies. The OpenWrt ImageBuilder contains the toolchain and
# everything that is needed to build the firmware images.

set -e

TARGET_ARCHITECTURE=$1
TARGET_VARIANT=$2
TARGET_DEVICE=$3

BUILD="$(dirname "${0}")/build/"
BUILD="$(readlink -f "${BUILD}")"

###
### chose a release
###
RELEASE="23.05.4"

IMGBUILDER_NAME="openwrt-imagebuilder-${RELEASE}-${TARGET_ARCHITECTURE}-${TARGET_VARIANT}.Linux-x86_64"
IMGBUILDER_DIR="${BUILD}/${IMGBUILDER_NAME}"
IMGBUILDER_ARCHIVE="${IMGBUILDER_NAME}.tar.xz"

IMGTEMPDIR="${BUILD}/image-extras"
IMGBUILDERURL="https://downloads.openwrt.org/releases/${RELEASE}/targets/${TARGET_ARCHITECTURE}/${TARGET_VARIANT}/${IMGBUILDER_ARCHIVE}"

if [ -z ${TARGET_DEVICE} ]; then
    echo "Usage: $0 architecture variant device-profile"
    echo " e.g.: $0 ath79 generic tplink_tl-wr1043nd-v1"
    echo "       $0 ath79 generic tplink_archer-c6-v2"
    echo "       $0 ath79 generic tplink_tl-wdr4300-v1"
    echo "       $0 bcm53xx generic dlink_dir-885l"
    echo " to get a list of supported devices issue a 'make info' in the OpenWRT image builder directory:"
    echo "   '${IMGBUILDER_DIR}'"
    kill -INT $$
fi

PREINSTALLED_PACKAGES="parted block-mount kmod-fs-ext4 blockdev blkid mount-utils swap-utils e2fsprogs fdisk wireless-tools firewall4 kmod-usb-storage-extras kmod-mmc ppp ppp-mod-pppoe ppp-mod-pppol2tp ppp-mod-pptp kmod-ppp kmod-pppoe luci kmod-mmc kmod-sdhci kmod-sdhci-mt7620"

mkdir -pv "${BUILD}"

rm -rf "${IMGTEMPDIR}"
cp -r image-extras/common/ "${IMGTEMPDIR}"
PER_PLATFORM_IMAGE_EXTRAS="image-extras/${TARGET_DEVICE}/"
if [ -e "${PER_PLATFORM_IMAGE_EXTRAS}" ]; then
    rsync -pr "${PER_PLATFORM_IMAGE_EXTRAS}" "${IMGTEMPDIR}/"
fi

if [ ! -e "${IMGBUILDER_DIR}" ]; then
    pushd "${BUILD}"
    wget --continue "${IMGBUILDERURL}"
    xz -d <"${IMGBUILDER_ARCHIVE}" | tar vx
    popd
fi

# Inject custom profile for generating factory image
CUSTOM_PROFILE_DIR="${IMGBUILDER_DIR}/target/linux/${TARGET_ARCHITECTURE}/image/"
CUSTOM_PROFILE_FILE="${CUSTOM_PROFILE_DIR}/glinet_gl-mt1300.mk"

mkdir -p "${CUSTOM_PROFILE_DIR}"
cat >"${CUSTOM_PROFILE_FILE}" <<EOL
define Device/glinet_gl-mt1300
  DEVICE_VENDOR := GL.iNet
  DEVICE_MODEL := GL-MT1300
  DEVICE_PACKAGES := kmod-mt7615-firmware kmod-usb3
  IMAGE_SIZE := 16064k
  SUPPORTED_DEVICES := glinet_gl-mt1300
  IMAGES += factory.bin
  IMAGE/factory.bin := append-ubi | append-metadata
  IMAGE/sysupgrade.bin := append-rootfs | append-metadata
endef
TARGET_DEVICES += glinet_gl-mt1300
EOL

pushd "${IMGBUILDER_DIR}"

# run make info to get a list of supported devices and extract gl-mt1300
# make info | grep "gl"

# Build firmware with both sysupgrade and factory images using the custom profile
make image PROFILE=glinet_gl-mt1300 PACKAGES="${PREINSTALLED_PACKAGES}" FILES=${IMGTEMPDIR}

# Check for the generated images
TARGET_DIR=$(find bin/targets/ -type d -name "${TARGET_ARCHITECTURE}" -print -quit)
if [ -d "${TARGET_DIR}" ]; then
    pushd "${TARGET_DIR}"
    ln -sf ../../../packages .
    # List recursively all generated images for verification
    ls -rla ~/work/openwrt-auto-extroot/openwrt-auto-extroot/build/openwrt-imagebuilder-23.05.4-ramips-mt7621.Linux-x86_64/bin/targets/ramips/mt7621/
    popd
else
    echo "Error: Target directory not found for architecture ${TARGET_ARCHITECTURE}"
    exit 1
fi

popd
