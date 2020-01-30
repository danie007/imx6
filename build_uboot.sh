#! /bin/bash

echo ""
echo "Running build_uboot.sh..."
echo ""

DEFCONF=mx6ul_14x14_evk_defconfig
toolchain=~/tools/gcc-arm-8.3-2019.03-x86_64-arm-linux-gnueabihf/bin/arm-linux-gnueabihf-

LOG_FILE=build_$(date '+%y%^b%d_%H%M%S').log # output log format: build_yymmmdd_HHMMSS.log

if [ $# -eq 0 ]; then
    echo "Please provide a build directory"
    echo "Aborting..."

    exit 1
else
    make distclean
    make mrproper

    rm -rf $1   # Deletes the existing dir, if present

    make O=$1 ARCH=arm CROSS_COMPILE=$toolchain distclean 2>&1 | tee $1/$LOG_FILE
    make O=$1 ARCH=arm CROSS_COMPILE=$toolchain mrproper 2>&1 | tee $1/$LOG_FILE
    make O=$1 ARCH=arm CROSS_COMPILE=$toolchain $DEFCONF 2>&1 | tee $1/$LOG_FILE
    echo ""
    echo "Select ARM architecture -> Support i.MX HAB features" 2>&1 | tee $1/$LOG_FILE
    echo ""
    echo "Select ARM architecture -> Support the 'dek_blob' command" 2>&1 | tee $1/$LOG_FILE
    echo ""
    make O=$1 ARCH=arm CROSS_COMPILE=$toolchain menuconfig
    make O=$1 ARCH=arm CROSS_COMPILE=$toolchain 2>&1 | tee $1/$LOG_FILE

    mkdir $1/build_files
    shopt -s extglob
    # mv !(*.log|*.imx) $1/build_files/ 2> /dev/null
    # mv !(*.log|*.imx|*.sh) build_files/ 2> /dev/null

    echo ""
    echo "U-Boot dump:"
    # od -X -N 0x20 $1/u-boot-dtb.imx

    echo "IVT Header: 0x$(hexdump -e '/4 "%X""\n"' -s 0 -n 4 $1/u-boot-dtb.imx)"
    echo "U-Boot entry point: 0x$(hexdump -e '/4 "%X""\n"' -s 4 -n 4 $1/u-boot-dtb.imx)"
    echo "DCD PTR: 0x$(hexdump -e '/4 "%X""\n"' -s 12 -n 4 $1/u-boot-dtb.imx)"
    echo "Boot Data PTR: 0x$(hexdump -e '/4 "%X""\n"' -s 16 -n 4 $1/u-boot-dtb.imx)"

    IVT_SELF=$(hexdump -e '/4 "%X""\n"' -s 20 -n 4 $1/u-boot-dtb.imx)
    echo "IVT Self Address: 0x$IVT_SELF"

    CSF_PTR=$(hexdump -e '/4 "%X""\n"' -s 24 -n 4 $1/u-boot-dtb.imx)
    echo "CSF PTR: 0x$CSF_PTR"

    echo ""
    IMG_LEN=$(printf '%X\n' $((0x$CSF_PTR - 0x$IVT_SELF)))
    echo "Image length: CSF PTR – IVT Self = 0x$IMG_LEN"
    echo ""
fi
