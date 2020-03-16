#!/bin/bash

# Filename: build_uboot.sh
# Description: Build script for uboot-imx
#              git clone https://source.codeaurora.org/external/imx/uboot-imx -b imx_v2019.04_4.19.35_1.1.0
# Author: Daniel Selvan
# Updated on Mar 16 2020

############################ USAGE ######################################
#                                                                       #
#   bash build_uboot.sh build_directory [build_option]                  #
#                                                                       #
#   build_option:                                                       #
#   -s, --secure    Support i.MX HAB features                           #
#   -e, --encrypt   Support the 'dek_blob' command                      #
#   If no option specified build the default configuration of U-boot    #
#                                                                       #
#   -h, --help      Displays this help message and exit                 #
#                                                                       #
#########################################################################

DEFCONF=mx6ul_14x14_evk_defconfig
toolchain=~/tools/gcc-arm-8.3-2019.03-x86_64-arm-linux-gnueabihf/bin/arm-linux-gnueabihf- # ARM Cross compiler
err_str=Error   # Error keyword to be searched in the log file.

reqcc=arm-linux-gnueabihf-gcc
requiredver="6.2.0"

LOG_FILE=$1/build_$(date '+%y%^b%d_%H%M%S').log # output log format: build_yymmmdd_HHMMSS.log
boot_mode="default"

GREEN='\e[1;32m'
YELLOW='\e[1;33m'
RED='\e[1;31m'
NC='\e[0m'

usage() {
    echo -e "\n${RED}Usage: $0 build_directory [build_option]${NC}\n"
    echo "build_option:"
    echo "-s, --secure    Support i.MX HAB features"
    echo "-e, --encrypt   Support the 'dek_blob' command"
    echo "If no option specified build the default configuration of U-boot"
    echo ""
    echo "-h, --help      Displays this help message and exit"

    exit 1
}

# Argument Parser
if [ $# -eq 0 ]; then
    usage
# 1st paramater is mandatory, 2nd parameter is optional
elif [ "$(printf '%s' "$1" | cut -c1)" != "-" ]; then
    case $2 in
    -s | --secure)
        boot_mode="secured"
        ;;
    -e | --encrypt)
        boot_mode="encrypted"
        ;;
    " " | "") ;;
        # If second paramter is not present, pass
    *)
        usage
        ;;
    esac
else
    usage
fi

echo -e "${YELLOW}**WARNING** Script contains hard coded file names/directories, update them before execution.${NC}"

echo -n "Checking dependencies... "
for dep in make bison flex; do
    [[ $(which $dep 2>/dev/null) ]] || {
        echo -en "\n${YELLOW}$dep needs to be installed${NC}. Use 'sudo apt-get install $dep'"
        deps=1
    }
done
[[ $deps -ne 1 ]] && echo "OK" || {
    echo -en "\nInstall the above and rerun this script\n"
    exit 1
}

echo -n "Checking cross compiler... "
cc="$(${toolchain}gcc --version | head -n 1 | cut -d " " -f1)"
currentver="$(${toolchain}gcc -dumpversion 2>/dev/null)"
if [ "$currentver" == "" ]; then
    echo -e "\n${YELLOW}Kindly check the toolchain path or update the script${NC}"
    CC=1
elif [ "$(printf '%s\n' "$cc")" != "$reqcc" ]; then
    echo -e "\n${YELLOW}No Compatible Linux hosted cross compiler found.${NC}"
    CC=1
elif [ "$(printf '%s\n' "$requiredver" "$currentver" | sort -V | head -n1)" != "$requiredver" ]; then
    echo -e "\n${YELLOW}Kindly update your cross compiler version to minimum $requiredver${NC}"
    CC=1
fi
[[ $CC -ne 1 ]] && echo "OK" || {
    echo -en "\nFix cross compiler and rerun this script\n"
    exit 1
}

make distclean
make mrproper

# Deletes the existing dir, if present
if [ -d $1 ]; then
    echo "$1 already present, removing..."
    rm -rf $1
fi

make O=$1 ARCH=arm CROSS_COMPILE=$toolchain distclean
make O=$1 ARCH=arm CROSS_COMPILE=$toolchain mrproper 2>&1 | tee -a $LOG_FILE
make O=$1 ARCH=arm CROSS_COMPILE=$toolchain $DEFCONF 2>&1 | tee -a $LOG_FILE

if [ "$boot_mode" == "encrypted" ]; then
    echo "Enabling encryption settings..."
    echo "ARM architecture -> Support i.MX HAB features"
    echo "ARM architecture -> Support the 'dek_blob' command"

    cat <<EOT >encrypt.patch
--- normal.txt	2020-02-13 09:44:11.691279385 +0530
+++ encr.txt	2020-02-13 09:46:03.788224928 +0530
@@ -152,7 +152,7 @@
 # CONFIG_ARCH_ASPEED is not set
 CONFIG_SYS_TEXT_BASE=0x87800000
 CONFIG_SYS_MALLOC_F_LEN=0x400
-# CONFIG_SECURE_BOOT is not set
+CONFIG_SECURE_BOOT=y
 CONFIG_MX6=y
 CONFIG_MX6UL=y
 CONFIG_LDO_BYPASS_CHECK=y
@@ -247,10 +247,11 @@
 # CONFIG_IMX_BOOTAUX is not set
 # CONFIG_USE_IMXIMG_PLUGIN is not set
 CONFIG_CMD_BMODE=y
-# CONFIG_CMD_DEKBLOB is not set
-# CONFIG_IMX_CAAM_DEK_ENCAP is not set
+CONFIG_CMD_DEKBLOB=y
+CONFIG_IMX_CAAM_DEK_ENCAP=y
 # CONFIG_IMX_OPTEE_DEK_ENCAP is not set
 # CONFIG_IMX_SECO_DEK_ENCAP is not set
+CONFIG_CMD_PRIBLOB=y
 # CONFIG_CMD_HDMIDETECT is not set
 # CONFIG_DBG_MONITOR is not set
 # CONFIG_NXP_BOARD_REVISION is not set
@@ -737,9 +738,11 @@
 # Hardware crypto devices
 #
 # CONFIG_CAAM_KB_SELF_TEST is not set
-# CONFIG_FSL_CAAM is not set
+CONFIG_FSL_CAAM=y
+CONFIG_SYS_FSL_HAS_SEC=y
 CONFIG_SYS_FSL_SEC_COMPAT_4=y
 # CONFIG_SYS_FSL_SEC_BE is not set
+CONFIG_SYS_FSL_SEC_COMPAT=4
 CONFIG_SYS_FSL_SEC_LE=y
 # CONFIG_IMX8M_DRAM is not set
 # CONFIG_IMX8M_LPDDR4 is not set
@@ -1365,7 +1368,8 @@
 #
 # CONFIG_SHA1 is not set
 # CONFIG_SHA256 is not set
-# CONFIG_SHA_HW_ACCEL is not set
+CONFIG_SHA_HW_ACCEL=y
+# CONFIG_SHA_PROG_HW_ACCEL is not set
 
 #
 # Compression Support
EOT
    patch -u -b $1/.config -i encrypt.patch 2>&1 | tee -a $LOG_FILE
    rm -f encrypt.patch

elif [ "$boot_mode" == "secured" ]; then

    echo "Adding ARM architecture -> Support i.MX HAB features"

    cat <<EOT >secure.patch
--- normal.txt	2020-02-13 09:44:11.691279385 +0530
+++ auth.txt	2020-02-13 09:45:15.811829236 +0530
@@ -152,7 +152,7 @@
 # CONFIG_ARCH_ASPEED is not set
 CONFIG_SYS_TEXT_BASE=0x87800000
 CONFIG_SYS_MALLOC_F_LEN=0x400
-# CONFIG_SECURE_BOOT is not set
+CONFIG_SECURE_BOOT=y
 CONFIG_MX6=y
 CONFIG_MX6UL=y
 CONFIG_LDO_BYPASS_CHECK=y
@@ -251,6 +251,7 @@
 # CONFIG_IMX_CAAM_DEK_ENCAP is not set
 # CONFIG_IMX_OPTEE_DEK_ENCAP is not set
 # CONFIG_IMX_SECO_DEK_ENCAP is not set
+# CONFIG_CMD_PRIBLOB is not set
 # CONFIG_CMD_HDMIDETECT is not set
 # CONFIG_DBG_MONITOR is not set
 # CONFIG_NXP_BOARD_REVISION is not set
@@ -737,9 +738,11 @@
 # Hardware crypto devices
 #
 # CONFIG_CAAM_KB_SELF_TEST is not set
-# CONFIG_FSL_CAAM is not set
+CONFIG_FSL_CAAM=y
+CONFIG_SYS_FSL_HAS_SEC=y
 CONFIG_SYS_FSL_SEC_COMPAT_4=y
 # CONFIG_SYS_FSL_SEC_BE is not set
+CONFIG_SYS_FSL_SEC_COMPAT=4
 CONFIG_SYS_FSL_SEC_LE=y
 # CONFIG_IMX8M_DRAM is not set
 # CONFIG_IMX8M_LPDDR4 is not set
@@ -1365,7 +1368,8 @@
 #
 # CONFIG_SHA1 is not set
 # CONFIG_SHA256 is not set
-# CONFIG_SHA_HW_ACCEL is not set
+CONFIG_SHA_HW_ACCEL=y
+# CONFIG_SHA_PROG_HW_ACCEL is not set
 
 #
 # Compression Support
EOT
    patch -u -b $1/.config -i secure.patch 2>&1 | tee -a $LOG_FILE
    rm -f secure.patch
fi
make O=$1 ARCH=arm CROSS_COMPILE=$toolchain -j$(nproc) 2>&1 | tee -a $LOG_FILE

# Checking for build errors
if grep -q $err_str $LOG_FILE; then
    echo -e "\n${RED}Build error has occurred. Look into $LOG_FILE for more details.${NC}\n" 2>&1 | tee -a $LOG_FILE
    exit 1
fi

echo "" 2>&1 | tee -a $LOG_FILE
echo -e "${GREEN}*** U-Boot dump ***${NC}" 2>&1 | tee -a $LOG_FILE
# od -X -N 0x20 $1/u-boot-dtb.imx

echo "IVT Header:         0x$(hexdump -e '/4 "%X""\n"' -s 0 -n 4 $1/u-boot-dtb.imx)" 2>&1 | tee -a $LOG_FILE
echo "U-Boot entry point: 0x$(hexdump -e '/4 "%X""\n"' -s 4 -n 4 $1/u-boot-dtb.imx)" 2>&1 | tee -a $LOG_FILE
echo "DCD PTR:            0x$(hexdump -e '/4 "%X""\n"' -s 12 -n 4 $1/u-boot-dtb.imx)" 2>&1 | tee -a $LOG_FILE
echo "Boot Data PTR:      0x$(hexdump -e '/4 "%X""\n"' -s 16 -n 4 $1/u-boot-dtb.imx)" 2>&1 | tee -a $LOG_FILE

IVT_SELF=$(hexdump -e '/4 "%X""\n"' -s 20 -n 4 $1/u-boot-dtb.imx)
echo "IVT Self Address:   0x$IVT_SELF" 2>&1 | tee -a $LOG_FILE

CSF_PTR=$(hexdump -e '/4 "%X""\n"' -s 24 -n 4 $1/u-boot-dtb.imx)
echo "CSF PTR:            0x$CSF_PTR" 2>&1 | tee -a $LOG_FILE

echo "" 2>&1 | tee -a $LOG_FILE
if [ "$boot_mode" == "default" ]; then
    echo "Image length:       0x$(hexdump $1/u-boot-dtb.imx | tail -n 1)" 2>&1 | tee -a $LOG_FILE
else
    IMG_LEN=$(printf '%X\n' $((0x$CSF_PTR - 0x$IVT_SELF)))
    echo "Image length: CSF PTR – IVT Self = 0x$IMG_LEN" 2>&1 | tee -a $LOG_FILE
fi

mkdir $1/build_files
mv $1/.* $1/build_files/ 2>/dev/null
mv $1/* $1/build_files/ 2>/dev/null # Moving all files to the build_files directory
mv $1/build_files/*.log $1/ && mv $1/build_files/*.imx $1/ && mv $1/build_files/*.sh $1/ 2>/dev/null
cp $1/u-boot-dtb.imx $1/u-boot-dtb.imx.orig
echo ""
