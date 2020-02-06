#!/usr/bin/env bash

#   enc_uboot.sh
#   Created on 27.01.2020
#
#   Daniel D, Jamsin Infotech

#####################################################################################################
#                                                                                                   #
#                                   Encrypted & Secured Boot                                        #
#                                                                                                   #
#####################################################################################################

CST=~/Documents/release

echo ""
echo "Running enc_uboot.sh"
echo ""

rm -rf enc_uboot
mkdir enc_uboot
cd enc_uboot

if [ ! -e ../u-boot-dtb.imx ]; then
echo ""
echo "Copy the \"u-boot-dtb.imx\" to the folder"
echo "Aborting..."
rm -rf ../enc_uboot

exit 1
fi

echo "Creating csf_enc_uBoot.txt"
echo ""

cat <<EOT >cal_blob_addr.sh
#! /bin/bash

IVT_start=$(hexdump -e '/4 "%x""\n"' -s 20 -n 4 ../u-boot-dtb.imx)
IVT_start_decimal=$(echo $((16#$IVT_start)))
echo "IVT start address: $IVT_start"

UBOOT_SIZE_decimal=$(expr $(stat -c%s "../u-boot-dtb.imx"))
echo "SIZE of u-boot: \$(hexdump ../u-boot-dtb.imx | tail -n 1)"

# CSF padded size 0x2000
CSF_pad_size=8192
DEK_BLOB_addr_decimal=$(expr $IVT_start_decimal + $UBOOT_SIZE_decimal + $CSF_pad_size)

DEK_BLOB_addr=$(printf '%x\n' $DEK_BLOB_addr_decimal)
echo ""
# DEK blob address in CSF = IVT start address + SIZE of u-boot + Padded CSF (0x2000)
echo "DEK blob address in CSF: $DEK_BLOB_addr"

EOT

cat <<EOT >csf_enc_uBoot.txt
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
# 	        Address    Offset 	Length 	   Data_File_Path
Blocks = 0x877ff400 0x00000000 0xc00 "../u-boot-dtb.imx"

[Install Secret Key]
Verification index = 0
Target index = 0
Key = "dek.bin"
Key Length = 192
Blob Address = 0x878a8000

[Decrypt Data]
Verification index = 0
Mac Bytes = 16
# 	      Address  Offset  Length 	 Data_File_Path
Blocks = 0x87800000 0xc00 0xa6000 "../u-boot-dtb.imx"
EOT

echo "Creating secure U-Boot image generation script"
echo ""

cat <<EOT >hab_enc_image_gen.sh
#!/bin/bash

###########################################
#   Automatically created by gen_ubot.sh  #
###########################################

# Removing old data, if any
rm -rf *.bin *.imx

echo "Generating csf binary..."
~/Documents/jan24/enc_boot/uboot-imx/enc_build/cst_enc/cst-3.3.0/linux64/bin/cst --o csf_enc_uBoot.bin --i csf_enc_uBoot.txt

echo "Padding CSF to 0x2000..."
echo ""
objcopy -I binary -O binary --pad-to 0x2000 --gap-fill=0xff csf_enc_uBoot.bin csf_enc_uBoot_pad.bin

echo "Length of padded CSF binary: \$(hexdump csf_enc_uBoot_pad.bin | tail -n 1)"
echo ""

echo "Merging image and csf data..."
echo ""
cat ../u-boot-dtb.imx csf_enc_uBoot_pad.bin > uBoot_encrypted_no_dek.bin

echo "Length of encrypted U-boot: \$(hexdump uBoot_encrypted_no_dek.bin | tail -n 1)"
echo ""

echo "Filling encrypted U-boot"
echo ""
objcopy -I binary -O binary --pad-to 0xa6c00 --gap-fill=0x00 uBoot_encrypted_no_dek.bin uBoot_encrypted_no_dek_padded.bin

echo "Length of encrypted, padded U-boot: \$(hexdump uBoot_encrypted_no_dek_padded.bin | tail -n 1)"
echo ""

if [ ! -e dek.bin ]; then
echo "dek.bin is not generated, check the CST"
echo "Aborting..."
rm -rf ../enc_uboot

exit 1
fi

echo "Length of DEK blob: \$(hexdump dek.bin | tail -n 1)"
echo ""

echo "Concatenate u-boot binary and dek"
echo ""
cat uBoot_encrypted_no_dek_padded.bin dek.bin > uboot_encrypted.imx

echo \"uboot_encrypted.imx\" is ready
echo "Length of signed u-boot: \$(hexdump uboot_encrypted.imx | tail -n 1)"
echo ""

# Download to SD card
# sudo dd if=uboot_encrypted.imx of=/dev/sdc bs=512 seek=2 conv=fsync

EOT

# bash cal_blob_addr.sh

echo "Running secure U-Boot image generation script..."
echo ""

bash hab_enc_image_gen.sh
