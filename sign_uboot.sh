#!/bin/bash

#   Created on 03.01.2020
#   Edited on 06.02.20
#   CHANGELOG:
#   Added file extensions for compatibility
#   20.01.2020:
#   Added conditions to seperate secure boot & encrypted boot
#
#   Daniel D, Jamsin Infotech

#####################################################################################################
#                                                                                                   #
#                                   Secured Boot                                                    #
#                                                                                                   #
#####################################################################################################

CST=~/Documents/release

echo ""
echo "Running sign_uboot.sh..."
echo ""

if [ ! -e u-boot-dtb.imx ]; then
echo ""
echo "Copy the \"u-boot-dtb.imx\" to the folder"
echo ""
echo "Stopping..."

exit 1
fi

rm -rf signed_uboot
mkdir signed_uboot
cd signed_uboot

cp ../u-boot-dtb.imx ./

addr=$(hexdump -e '/4 "%X""\n"' -s 20 -n 4 u-boot-dtb.imx)
offst=00

CSF_PTR=$(hexdump -e '/4 "%X""\n"' -s 24 -n 4 u-boot-dtb.imx)
size=$(printf '%X\n' $((0x$CSF_PTR - 0x$addr)))

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
# Index of the key location in the SRK table to be installed
File = "$CST/crts/SRK_1_2_3_4_table.bin"
Source index = 0

[Install CSFK]
# Key used to authenticate the CSF data
File = "$CST/crts/CSF1_1_sha256_1024_65537_v3_usr_crt.pem"

[Authenticate CSF]

[Install Key]
# Key slot index used to authenticate the key to be installed
Verification index = 0
# Target key slot in HAB key store where key will be installed
Target index = 2
# Key to install
File= "$CST/crts/IMG1_1_sha256_1024_65537_v3_usr_crt.pem"

[Authenticate Data]
# Key slot index used to authenticate the image data
Verification index = 2
# 	     Address  Offset   Length  Data_File_Path
Blocks = 0x$addr 0x$offst 0x$size "u-boot-dtb.imx"
EOT

echo "Creating secure U-Boot image generation script"
echo ""

cat << EOT >habimagegen.sh
#!/bin/bash

#############################################
#   Automatically created by sign_uboot.sh  #
#############################################

# Removing old data, if any
rm -f csf_uBoot.bin uboot_signed.imx

echo "Length of u-boot-dtb.imx: \$(hexdump ../u-boot-dtb.imx | tail -n 1)"
echo ""

echo "Generating CSF binary..."
$CST/linux64/bin/cst --o csf_uBoot.bin --i csf_uBoot.txt
echo "Length of CSF binary: \$(hexdump csf_uBoot.bin | tail -n 1)"
echo ""

echo "Merging image and csf data..."
cat u-boot-dtb.imx csf_uBoot.bin > uboot_signed.imx
echo ""

echo \"uboot_signed.imx\" is ready
echo "Length of signed u-boot: \$(hexdump uboot_signed.imx | tail -n 1)"

echo ""
if [[ -d "/media/$(whoami)/boot" ]]; then
    echo "Copying the U-boot to SD Card"
    sudo dd if=uboot_signed.imx of=/dev/sdc bs=1K seek=1 && sync

    sudo umount /media/$(whoami)/*
else
    echo "Command to copy U-boot to SD Card:"
    echo "sudo dd if=uboot_signed.imx of=/dev/sdc bs=1K seek=1 && sync"
fi
EOT

echo "Running secure U-Boot image generation script..."
echo ""

bash habimagegen.sh
