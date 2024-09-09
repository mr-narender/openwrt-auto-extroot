# What

This script builds a customized OpenWrt firmware image using ImageBuilder.

If the generated image is flashed on a router, the boot process will attempt to set up extroot on any storage device plugged into the USB port or MMC device. It unconditionally reformats /dev/sda or /dev/mmcblk0 if it fails to mount an extroot early in the boot process.

# Why

This allows users (e.g., customers) to buy a router, download and flash custom firmware, plug in a USB drive or MMC card, and manage their SIP (telephony) node from a web app.

This script was extracted from an auto-provision project, generalized for public use, and has worked reliably on my own routers for years.

# How

You can learn more about OpenWrt's ImageBuilder and extroot setup from the OpenWrt wiki and ImageBuilder frontends.

## Device Detection
The script now supports both USB and MMC devices for setting up extroot. It defaults to /dev/sda for USB devices and automatically switches to /dev/mmcblk0 if an MMC card is detected.


```
# Default device paths for USB

DEFAULT_DEVICE_PATH="/dev/sda"
DEFAULT_DEVICE_FIRST_PARTITION_PATH="${DEFAULT_DEVICE_PATH}1"
DEFAULT_DEVICE_SECOND_PARTITION_PATH="${DEFAULT_DEVICE_PATH}2"
DEFAULT_DEVICE_THIRD_PARTITION_PATH="${DEFAULT_DEVICE_PATH}3"

# Use MMC device paths if detected

if [ -e "/dev/mmcblk0" ]; then
DEFAULT_DEVICE_PATH="/dev/mmcblk0"
DEFAULT_DEVICE_FIRST_PARTITION_PATH="${DEFAULT_DEVICE_PATH}p1"
    DEFAULT_DEVICE_SECOND_PARTITION_PATH="${DEFAULT_DEVICE_PATH}p2"
DEFAULT_DEVICE_THIRD_PARTITION_PATH="${DEFAULT_DEVICE_PATH}p3"
fi
```

# Build Instructions
OpenWrt's ImageBuilder only works on Linux x86_64. To build a firmware, use the following command:

```
./build.sh architecture variant device-profile
```


Example builds:
```
./build.sh ath79 generic tplink_tl-wr1043nd-v1
./build.sh ath79 generic tplink_archer-c6-v2
./build.sh ath79 generic tplink_tl-wdr4300-v1
./build.sh bcm53xx generic dlink_dir-885l
```

The results will be under build/openwrt-imagebuilder-${release}-${architecture}-${variant}.Linux-x86_64/bin/.

To list available targets, run make info in the ImageBuilder directory.

If you want to change the OpenWrt version used, modify the relevant variable(s) in build.sh.

# Setup Stages
The boot process has multiple stages indicated by blinking LEDs. The following describes the stages during extroot setup.

## Stage 1: Setup Extroot

When the firmware first boots, the autoprovision script waits for a storage device (USB or MMC) at /dev/sda or /dev/mmcblk0 with at least 512MB. If found, the device will be erased, and partitions for swap, extroot, and data will be set up. Then, the system reboots.

## Stage 2: Install Packages

After rebooting into the new extroot, the script will continuously attempt to install OpenWrt packages until an internet connection is established. This must be done manually via SSH or LuCI (OpenWrt's web UI).

## Stage 3 (Optional)

There is an optional third stage written in Python, which is commented out by default. Check for autoprovision-stage3.py in the code for more details.

## Login
The default router IP is `192.168.1.1`. The root password is not set initially, allowing telnet access. To set a password, edit the `autoprovision-stage2.sh` script.

Once a password is set, telnet is disabled, and SSH will be available using keys specified in `authorized_keys`.

Use logread -f to monitor logs.

## Status

This script serves as a template, but has been used on home routers for years. Customize as needed by searching for CUSTOMIZE in the code. Ensure that a password is set and SSH keys are added to `image-extras/common/etc/dropbear/authorized_keys`.

The script is `hardware-agnostic` except for setLedAttribute, which provides progress feedback using LEDs. This only works on certain routers, mainly ath79, but does not affect functionality if unavailable.

# Troubleshooting

## Which Firmware File to Flash?

Refer to OpenWrt's documentation. The generated firmware files can be found under:

```
./build/openwrt-imagebuilder-${release}-${architecture}-${variant}.Linux-x86_64/bin/targets/${architecture}/${variant}/
```

Choose the correct file for your hardware version (-factory.bin for first-time installs, -sysupgrade.bin for upgrades).

## No Firmware File Generated?

If the build does not generate a firmware file, it might be due to insufficient space in the device's flash memory. Remove unnecessary packages from the build.sh script and try again.

## Extroot Issues After sysupgrade

If the extroot does not mount after upgrading, delete /etc/.extroot-uuid on the mounted extroot. More details can be found in this issue and the related blog post.

For further information, consult the OpenWrt wiki.
