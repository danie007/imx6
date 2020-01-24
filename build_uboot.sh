#!/bin/bash

echo ""
echo "build_uboot.sh"
echo ""

DEFCONF=mx6ul_14x14_evk_defconfig
toolchain=~/tools/gcc-arm-8.3-2019.03-x86_64-arm-linux-gnueabihf/bin/arm-linux-gnueabihf-

LOG_FILE=build_$(date '+%y%^b%d_%H%M%S').log # output log format: build_yymmmdd_HHMMSS.log

if [ $# -eq 0 ]; then
    echo ""
    echo "Please provide a build directory"
    echo ""

    exit 1
else
    make distclean
    make mrproper

    rm -rf $1   # Clears the existing dir, if present

    make O=$1 distclean
    make O=$1 mrproper
    make O=$1 $DEFCONF
    echo ""
    echo "Select ARM architecture -> Support i.MX HAB features"
    echo ""
    make O=$1 ARCH=arm CROSS_COMPILE=$toolchain menuconfig
    make O=$1 ARCH=arm CROSS_COMPILE=$toolchain 2>&1 | tee $1/$LOG_FILE

    echo ""

    Echo "u-boot dump:"
    od -X -N 0x20 $1/u-boot-dtb.imx
fi
