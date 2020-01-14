#!/bin/bash

DEFCONF=mx6ul_14x14_evk_defconfig
LOG_FILE=build_$(date '+%y%^b%d_%H%M%S').log   # output log format: build_yymmmdd_HHMMSS.log

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
    make O=$1 ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- 2>&1 | tee $LOG_FILE

    echo ""

    od -X -N 0x20 $1/u-boot-dtb.imx
fi
