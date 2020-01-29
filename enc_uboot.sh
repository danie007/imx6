#! /usr/bin/env bash

#   enc_uboot.sh
#   Created on 27.01.2020
#   Updated on 29.01.20
#
#   Daniel D, Jamsin Infotech

#####################################################################################################
#                                                                                                   #
#                                   Encrypted & Secured Boot                                        #
#                                                                                                   #
#####################################################################################################

CST=~/Documents/release

echo "Running enc_uboot.sh..."

rm -rf enc_uboot
mkdir enc_uboot
cd enc_uboot

echo "Copying u-boot-dtb.imx..."
cp ../u-boot-dtb.imx ./

if [ ! -e ../u-boot-dtb.imx ]; then
echo ""
echo "Copy the \"u-boot-dtb.imx\" to  parent folder"
echo "Aborting..."
rm -rf ../enc_uboot

exit 1
fi

echo "Creating csf_enc_uBoot.txt..."

IVT_start=$(hexdump -e '/4 "%x""\n"' -s 20 -n 4 u-boot-dtb.imx)
IVT_start_decimal=$(echo $((16#$IVT_start)))
echo "IVT start address: 0x$IVT_start"

UBOOT_SIZE_decimal=$(expr $(stat -c%s "u-boot-dtb.imx"))
echo "SIZE of u-boot: 0x$(hexdump u-boot-dtb.imx | tail -n 1)"

# CSF padded size 0x2000
CSF_pad_size=8192
DEK_BLOB_addr_decimal=$(expr $IVT_start_decimal + $UBOOT_SIZE_decimal + $CSF_pad_size)

DEK_BLOB_addr=$(printf '%x\n' $DEK_BLOB_addr_decimal)
echo ""
# DEK blob address in CSF = IVT start address + SIZE of u-boot + Padded CSF (0x2000)
echo "DEK blob address in CSF: 0x$DEK_BLOB_addr"

cat << EOT >csf_enc_uBoot.txt
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
Blocks = 0x877ff400 0x00000000 0xc00 "u-boot-dtb.imx"

# Encrypt the boot image and create a DEK
[Install Secret Key]
Verification index = 0
Target index = 0
Key = "dek.bin"
Key Length = 128
Blob Address = 0x$DEK_BLOB_addr # 0x878a8000

[Decrypt Data]
Verification index = 0
Mac Bytes = 16
# 	      Address  Offset  Length 	 Data_File_Path
Blocks = 0x87800000 0xc00 0xa6000 "u-boot-dtb.imx"
EOT

echo ""
echo "Creating encrypted U-Boot generation scripts..."

cat << EOT > gen_dek.sh
#! /usr/bin/env bash

###############################################
#    Automatically created by enc_uboot.sh    #
###############################################

# Removing old data, if any
rm -rf *.bin *.imx

echo "Copying u-boot-dtb.imx..."
cp ../u-boot-dtb.imx ./

if [ ! -e u-boot-dtb.imx ]; then
echo ""
echo "Copy the \"u-boot-dtb.imx\" to the folder"
echo "Aborting..."

exit 1
fi

echo "Generating CSF binary..."
$CST/linux64/bin/cst --o csf_enc_uBoot.bin --i csf_enc_uBoot.txt
echo "\"dek.bin\" successfully created"
echo ""

echo "Paste the \"dek.bin\" to SD Card's boot folder"

echo ""
echo "Issue the following commands in i.MX6 EVK"
echo ""
echo "=> fatload mmc 1:1 0x87870000 dek.bin"
echo "=> dek_blob 0x87870000 0x87871000 128"
echo "=> fatwrite mmc 1:1 0x87871000 dek_blob.bin 0x48"
echo ""

echo "Paste the \"dek_blob.bin\" from SD Card's boot folder & run uboot_encryptor.sh"
EOT

cat << EOT > uboot_encryptor.sh
#! /usr/bin/env bash

###############################################
#    Automatically created by enc_uboot.sh    #
###############################################

if [ ! -e dek_blob.bin ]; then
echo "Paste dek_blob.bin from SD Card to continue"

echo ""
echo "Steps to create dek_blob.bin:"
echo "  Issue the following command in i.MX6 EVK"
echo ""
echo "=> fatload mmc 1:1 0x87870000 dek.bin"
echo "=> dek_blob 0x87870000 0x87871000 128"
echo "=> fatwrite mmc 1:1 0x87871000 dek_blob.bin 0x48"
echo ""

echo "Stopping..."

exit 1
fi

# Removing old data, if any
rm -f csf_enc_uBoot_pad.bin uboot_encrypted.imx uBoot_encrypted_no_dek.bin uBoot_encrypted_no_dek_padded.bin 2> /dev/null

print_len() {
    echo "Length of \"\$1\": 0x\$(hexdump \$1 | tail -n 1)"
}

print_len dek_blob.bin

echo "Padding CSF to 0x2000..."
objcopy -I binary -O binary --pad-to 0x2000 --gap-fill=0xff csf_enc_uBoot.bin csf_enc_uBoot_pad.bin

print_len csf_enc_uBoot_pad.bin

echo "Merging image and csf data..."
cat u-boot-dtb.imx csf_enc_uBoot_pad.bin > uBoot_encrypted_no_dek.bin

print_len uBoot_encrypted_no_dek.bin

# Pad binary
echo "Ensuring image size from zero padding..."
objcopy -I binary -O binary --pad-to 0xa8c00 --gap-fill=0x00 uBoot_encrypted_no_dek.bin uBoot_encrypted_no_dek_padded.bin

print_len uBoot_encrypted_no_dek_padded.bin

echo "Concatenating u-boot binary and dek_blob..."
cat uBoot_encrypted_no_dek_padded.bin dek_blob.bin > uboot_encrypted.imx

echo "\"uboot_encrypted.imx\" is ready"
print_len uboot_encrypted.imx

# Download to SD card
echo ""
echo "Paste the encrypted u-boot in SD Card"
echo "$ sudo dd if=uboot_encrypted.imx of=/dev/sdc bs=512 seek=2 conv=fsync"
EOT

echo "Running Device Encryption Key(DEK) generation script..."
bash gen_dek.sh
