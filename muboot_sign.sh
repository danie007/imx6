#!/bin/bash

# muboot_sign.sh
# Created on 03.01.2020
# Edited on 02.07.20
# CHANGELOG:
# Added file extensions for compatibility
# - 20.01.2020:
#   Added conditions to seperate secure boot & encrypted boot
# - 02.07.2020
#   Added colors to outputs
#   Cheching output of CST, before proceeding
#   Modified partition based on Mender
# 
# Daniel D, Jamsin Infotech

#####################################################################################################
#                                                                                                   #
#                                   Secured Boot                                                    #
#                                                                                                   #
#####################################################################################################

CST=~/Documents/release

OP_DIR=signed_uboot
BOOT_IMG=u-boot.imx

YELLOW='\e[1;33m'
RED='\e[1;31m'
GREEN='\e[1;32m'
NC='\e[0m'

echo -e "${YELLOW}**WARNING** Script contains hard coded file names/directories, update them before execution.${NC}"

echo ""
echo "Running sign_uboot.sh..."
echo ""

if [ ! -e $BOOT_IMG ]; then
    echo ""
    echo -e "${YELLOW}Copy the \"$BOOT_IMG\" to the folder${NC}"
    echo ""
    echo -e "${RED}Stopping...${NC}"

	exit 1
fi

rm -rf $OP_DIR
mkdir $OP_DIR
cd $OP_DIR

cp ../$BOOT_IMG ./

OFFSET=00
IVT_ADDR=$(hexdump -e '/4 "%X""\n"' -s 20 -n 4 $BOOT_IMG)

CSF_PTR=$(hexdump -e '/4 "%X""\n"' -s 24 -n 4 $BOOT_IMG)
size=$(printf '%X\n' $((0x$CSF_PTR - 0x$IVT_ADDR)))

echo "Creating csf_uBoot.txt"
echo ""

cat << EOT >csf_uBoot.txt
[Header]
Version = 4.2
Hash Algorithm = sha256
Engine = CAAM
Engine Configuration = 0
Certificate Format = X509
Signature Format = CMS

[Install SRK]
File = "$CST/crts/SRK_1_2_3_4_table.bin"
# Index of the key location in the SRK table to be installed
Source index = 0

[Install CSFK]
# Key used to authenticate the CSF data
File = "$CST/crts/CSF1_1_sha256_1024_65537_v3_usr_crt.pem"

[Authenticate CSF]

[Install Key]
# Key slot index used to authenticate the key to be installed
Verification index = 0
# Target key slot in HAB key store where key will be installed
Target Index = 2
# Key to install
File= "$CST/crts/IMG1_1_sha256_1024_65537_v3_usr_crt.pem"

[Authenticate Data]
# Key slot index used to authenticate the image data
Verification index = 2
# 	      Address  Offset Length  Data_File_Path
Blocks = 0x$IVT_ADDR 0x$OFFSET 0x$size "$BOOT_IMG"
EOT

# Creating secure U-Boot image generation script
cat << EOT >habimagegen.sh
#!/bin/bash

#############################################
#   Automatically created by sign_uboot.sh  #
#############################################

YELLOW='$YELLOW'
RED='$RED'
GREEN='$GREEN'
NC='$NC'

# Removing old data, if any
rm -f csf_uBoot.bin uboot_signed.imx

echo "Length of $BOOT_IMG: \$(hexdump ../$BOOT_IMG | tail -n 1)"

echo ""
echo "Generating CSF binary..."

# Calling CST with the CSF input file
cst_status=\$($CST/linux64/bin/cst --o csf_uBoot.bin --i csf_uBoot.txt)
if echo "\$cst_status" | grep -qi 'invalid\|error'; then
    echo -e "\${RED}\$cst_status\${NC}"

    exit 1
fi
echo -e "\${GREEN}\$cst_status\${NC}"

echo "Length of CSF binary: \$(hexdump csf_uBoot.bin | tail -n 1)"

# Merging image and csf data
cat $BOOT_IMG csf_uBoot.bin > uboot_signed.imx

echo -e "\n\${GREEN}\"uboot_signed.imx\" is ready\${NC}"

echo "Length of signed u-boot: \$(hexdump uboot_signed.imx | tail -n 1)"

if [[ -d "/media/$(whoami)/data" ]]; then
    echo "Copying the U-boot to SD Card"

    # Download to SD card
    echo ""
    cat /proc/partitions | grep "sd" | awk '{print \$4}' | grep -v '[0-9]'
    echo ""

    read -t 10 -p "Enter the partition to be flashed (Press return to abort): " SD

    echo ""
    if [ "\$SD" != "" ] && [ -e /dev/\$SD ]; then
        sudo dd if=uboot_signed.imx of=/dev/\$SD bs=1K seek=1 && sync

        echo -e "\n\${GREEN}\"uboot_signed.imx\" is successfully flashed to /dev/\$SD\${NC}"
    fi

    exit 0
fi

echo "Command to copy U-boot to SD Card:"
echo "sudo dd if=uboot_signed.imx of=/dev/sdc bs=1K seek=1 && sync"
EOT

echo "Running secure U-Boot image generation script..."
echo ""

bash habimagegen.sh
