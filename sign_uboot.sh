#!/bin/bash

#   Created on 03.01.2020
#   Edited on 24.01.20
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

echo ""
echo "  sign_uboot.sh"
echo ""

rm -rf u-boot
mkdir u-boot
cd u-boot

if [ ! -e ../u-boot-dtb.imx ]; then
echo ""
echo "Copy the \"u-boot-dtb.imx\" to the folder"
echo ""
echo "Aborting..."
rm -rf ../u-boot

exit 1
fi

echo ""
echo "Creating csf_uBoot.txt"
echo ""

cat <<EOT >csf_uBoot.txt
[Header]
Version = 4.2
Hash Algorithm = sha256
Engine = CAAM
Engine Configuration = 0
Certificate Format = X509
Signature Format = CMS

[Install SRK]
# Index of the key location in the SRK table to be installed
File = "/home/uxce/Documents/release/crts/SRK_1_2_3_4_table.bin"
Source index = 0

[Install CSFK]
# Key used to authenticate the CSF data
File = "/home/uxce/Documents/release/crts/CSF1_1_sha256_1024_65537_v3_usr_crt.pem"

[Authenticate CSF]

[Install Key]
# Key slot index used to authenticate the key to be installed
Verification index = 0
# Target key slot in HAB key store where key will be installed
Target index = 2
# Key to install
File= "/home/uxce/Documents/release/crts/IMG1_1_sha256_1024_65537_v3_usr_crt.pem"


[Authenticate Data]
# Key slot index used to authenticate the image data
Verification index = 2
# 	        Address    Offset 	Length 	   Data_File_Path
Blocks = 0x877ff400 0x00000000 0x000a5c00 "../u-boot-dtb.imx"
EOT

echo ""
echo "Creating secure U-Boot image generation script"
echo ""

cat <<EOT >habimagegen.sh
#!/bin/bash

###########################################
#   Automatically created by gen_ubot.sh  #
###########################################

# Removing old data, if any
rm -f csf_uBoot.bin uboot_signed.imx

echo ""
echo "generating csf binary..."
echo ""

~/Documents/release/linux64/bin/cst --o csf_uBoot.bin --i csf_uBoot.txt
echo "Length of CSF binary:"
hexdump csf_uBoot.bin | tail -n 1

echo "Merging image and csf data..."
echo ""

cat ../u-boot-dtb.imx csf_uBoot.bin > uboot_signed.imx

echo \"uboot_signed.imx\" is ready
echo "Length of signed u-boot:"
hexdump uboot_signed.imx | tail -n 1

EOT

echo ""
echo "Running secure U-Boot image generation script..."
echo ""

bash habimagegen.sh
