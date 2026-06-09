#!/bin/bash

# This script will install the latest miniil Karotz OS (Firmware)
# www.miniil.be

source /mnt/usbkey/functions.sh

LOG ""
LOG "[FIRMWARE] Start installing firmware"

LOG "[FIRMWARE] Copy USB files to tmp"
cp -f /mnt/usbkey/zImage /tmp
cp -f /mnt/usbkey/rootfs.miniilos02.img.gz /tmp
cp -f /mnt/usbkey/yaffs-12.07.19.00.tar.gz /tmp
LOG ""

# Flash zImage
LOG "[FIRMWARE] CHECK zImage and Flash"
if [ "87056626645e6f383a0db0b92e830317" = $(/bin/md5sum /tmp/zImage | cut -d ' ' -f1) ]; then
    LOG "Flashing zImage"
    /sbin/flash_eraseall /dev/mtd1
    /sbin/nandwrite -pm /dev/mtd1 /tmp/zImage    
else
    ERROR "MD5 Checksum Error in zImage"
    exit 1
fi

LOG ""

# Flash Rootfs
LOG "[FIRMWARE] CHECK rootfs and Flash"
if [ "926a1c5c8f04b31756c265824e1e7f2c" = $(/bin/md5sum /tmp/rootfs.miniilos02.img.gz | cut -d ' ' -f1) ]; then
    LOG "Flashing RootFs"
    /sbin/flash_eraseall /dev/mtd2
    /sbin/nandwrite -pm /dev/mtd2 /tmp/rootfs.miniilos02.img.gz
else
    ERROR "MD5 Checksum Error in RootFs"
    exit 1
fi

# Clean yaffs
LOG "Clean yaffs"
cleanup_yaffs

# Install yaffs
LOG "[FIRMWARE] Install yaffs"
/bin/gzip -d < /tmp/yaffs-12.07.19.00.tar.gz | tar xf - -C /usr/
cp -f /usr/install/sys_version /usr/etc/conf/sys_version
rm -rf /usr/install
rm -f /usr/yaffs*
[ -f "/usr/.install_yaffs_start" ] && rm -f /usr/.install_yaffs_start

LOG "[FIRMWARE] ENDED"