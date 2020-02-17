#!/bin/bash

#   enc_uboot.sh
#   Created on 27.01.2020
#   Updated on 14.02.20
#
#   Daniel D, Jamsin Infotech

#####################################################################################################
#                                                                                                   #
#                                   Encrypted & Secured Boot                                        #
#                                                                                                   #
#####################################################################################################

CST=~/Documents/release

YELLOW='\e[1;33m'
RED='\e[1;31m'
GREEN='\e[1;32m'
NC='\e[0m'
echo -e "${YELLOW}**WARNING** Script contains hard coded file names/directories, update them before execution.${NC}\n"

OP_DIR=enc_uboot
BOOT_IMG=u-boot-dtb.imx

if [ ! -e $BOOT_IMG ]; then
echo ""
echo "${YELLOW}Copy the \"$BOOT_IMG\" to  the folder${NC}"
echo "${RED}Aborting...${NC}"

exit 1
fi

rm -rf $OP_DIR
mkdir $OP_DIR
cd $OP_DIR

echo "Copying $BOOT_IMG..."
cp ../$BOOT_IMG ./
cp $BOOT_IMG $BOOT_IMG.orig

echo "Creating csf_enc.txt & csf_sign_enc.txt ..."

IVT_start=$(hexdump -e '/4 "%x""\n"' -s 20 -n 4 $BOOT_IMG)

UBOOT_SIZE=$(hexdump $BOOT_IMG | tail -n 1)
dcd_size=c00
boot_size=$(printf "%x\n" $((0x$UBOOT_SIZE - 0x$dcd_size)))

CSF_pad_size=8192   # CSF padded size 0x2000
UBOOT_SIZE_d=$(expr $(stat -c%s "$BOOT_IMG"))
IVT_start_d=$(echo $((16#$IVT_start)))
DEK_BLOB_addr_d=$(expr $IVT_start_d + $UBOOT_SIZE_d + $CSF_pad_size)

DEK_BLOB_addr=$(printf '%x\n' $DEK_BLOB_addr_d)

entry_pt=$(hexdump -e '/4 "%X""\n"' -s 4 -n 4 $BOOT_IMG)

MAC_bytes=16
keylen=128

cat << EOT >csf_enc.txt
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
# This Authenticate Data command covers the IVT and DCD Data
# The image file referenced will remain unmodified by CST
Blocks = 0x$IVT_start 0x00 0x$dcd_size "$BOOT_IMG"

[Install Secret Key]
# Install the blob
Verification index = 0
Target index = 0
Key = "dek.bin"
Key Length = $keylen
# Start address + padding(0x2000) + length
Blob Address = 0x$DEK_BLOB_addr # 0x878a8000

[Decrypt Data]
# The decrypt data command below causes CST to modify the input
# file and encrypt the specified block of data. This image file
# is a copy of the file used for the authentication command above
Verification index = 0
Mac Bytes = $MAC_bytes
Blocks = 0x$entry_pt 0x$dcd_size 0x$boot_size "u-boot-enc.imx"
EOT

cat << EOT >csf_sign_enc.txt
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
# This Authenticate Data command covers both clear and encrypted data.
# The image file referenced will remain unmodified by CST.
# Key slot index used to authenticate the image data
Verification index = 2
#       Address Offset Length File
Blocks = 0x$IVT_start 0x00 0x$UBOOT_SIZE "u-boot-enc.imx"

[Install Secret Key]
# Install the blob - This will manage a new key that will not be used in
# the final image, so the file name has to be different
Verification index = 0
Target index = 0
Key = "dek.bin.dummy"
key Length = $keylen
# Start address + padding(0x2000) + length
Blob Address = 0x$DEK_BLOB_addr

[Decrypt Data]
# The decrypt Data command is a place holder to ensure the
# CSF includes the decrypt data command from the first pass.
# The file that CST will encrypt will not be used, so the file
# name has to be different.
Verification index = 0
Mac Bytes = $MAC_bytes
Blocks = 0x$entry_pt 0x$dcd_size 0x$boot_size "$BOOT_IMG.dummy"
EOT

echo ""
echo "Creating encrypted U-Boot generation scripts..."

cat << EOT > gen_dek.sh
#!/bin/bash

###############################################
#    Automatically created by enc_uboot.sh    #
###############################################

YELLOW='$YELLOW'
RED='$RED'
GREEN='$GREEN'
NC='$NC'

# Removing old data, if any
rm -rf *.bin *.imx *.dummy

if [ ! -e $BOOT_IMG.orig ]; then
echo ""
echo -e "\${YELLOW}Copy the \"$BOOT_IMG.orig\" to the folder\${NC}"
echo -e "\${RED}Aborting...\${NC}"

exit 1
fi

echo "Copying $BOOT_IMG..."
cp $BOOT_IMG.orig $BOOT_IMG
cp $BOOT_IMG.orig u-boot-enc.imx
cp $BOOT_IMG.orig $BOOT_IMG.dummy

echo "Generating encrypted CSF binary..."
$CST/linux64/bin/cst -i csf_enc.txt -o csf_enc.bin
echo -e "\${GREEN}\"dek.bin\" successfully created\${NC}"

echo ""
if [[ -d "/media/$(whoami)/boot" ]]; then
    sudo rm -f /media/$(whoami)/boot/dek.bin 2> /dev/null   # remove the old dek.bin, if present
    echo -e "\${GREEN}Copying \"dek.bin\" to SD Card's boot\${NC}"
    sudo cp -v dek.bin /media/$(whoami)/boot/
else
    echo "Paste the \"dek.bin\" to SD Card's boot folder"
fi
echo ""
echo "Issue the following commands in i.MX6UL EVK U-boot"
echo ""
echo "=> fatload mmc 1:1 0x80800000 dek.bin"
echo "=> dek_blob 0x80800000 0x80801000 $keylen"
echo "=> fatwrite mmc 1:1 0x80801000 dek_blob.bin 0x48"
echo ""
echo -e "\${YELLOW}Paste the \"dek_blob.bin\" from SD Card's boot folder & run uboot_encryptor.sh\${NC}"
EOT

cat << EOT > uboot_encryptor.sh
#!/bin/bash

###############################################
#    Automatically created by enc_uboot.sh    #
###############################################

YELLOW='$YELLOW'
RED='$RED'
GREEN='$GREEN'
NC='$NC'

DEK_BLOB=dek_blob.bin

if [ ! -e \$DEK_BLOB ]; then
echo -e "\${YELLOW}Paste \$DEK_BLOB from SD Card to continue\${NC}"
echo ""
echo "Steps to create \$DEK_BLOB:"
echo "  Issue the following command in i.MX6 EVK"
echo ""
echo "=> fatload mmc 1:1 0x80800000 dek.bin"
echo "=> dek_blob 0x80800000 0x80801000 $keylen"
echo "=> fatwrite mmc 1:1 0x80801000 \$DEK_BLOB 0x48"
echo ""
echo -e "\${RED}Stopping...\${NC}"
exit 1
fi

# Removing old data, if any
rm -f csf_sign_enc_padded.bin uboot_encrypted.imx u-boot_encrypted_no_dek.bin u-boot_encrypted_no_dek_padded.bin

print_len() {
    echo "Length of \"\$1\": 0x\$(hexdump \$1 | tail -n 1)"
}

echo "Signing the encrypted CSF binary..."
$CST/linux64/bin/cst -i csf_sign_enc.txt -o csf_sign_enc.bin

# Removing the dummy files
rm -rf *.dummy

nonce_mac_size=\$((12 + $MAC_bytes + 8)) # Nonce/MAC size (bytes) = Nonce size + MAC bytes + CSF header for Nonce/Mac
csf_enc_size=\$(du -b csf_enc.bin | cut -f1)
mac_offset=\$((\$csf_enc_size - \$nonce_mac_size)) # MAC offset = csf_enc.bin size - Nonce/MAC size

echo "Replacing the nonce..."
dd if=csf_enc.bin of=noncemac.bin bs=1 skip=\$mac_offset count=\$nonce_mac_size
dd if=noncemac.bin of=csf_sign_enc.bin bs=1 seek=\$mac_offset count=\$nonce_mac_size

print_len \$DEK_BLOB

echo "Padding CSF to 0x2000..."
objcopy -I binary -O binary --pad-to 0x2000 --gap-fill=0xff csf_sign_enc.bin csf_sign_enc_padded.bin
print_len csf_sign_enc_padded.bin

echo "Merging image and csf data..."
cat u-boot-enc.imx csf_sign_enc_padded.bin > u-boot_encrypted_no_dek.bin
print_len u-boot_encrypted_no_dek.bin

# Pad binary
echo "Ensuring image size from zero padding..."
objcopy -I binary -O binary --pad-to 0x$(printf "%x\n" $((0x$UBOOT_SIZE + 0x2000))) --gap-fill=0x00 u-boot_encrypted_no_dek.bin u-boot_encrypted_no_dek_padded.bin
print_len u-boot_encrypted_no_dek_padded.bin

echo "Concatenating u-boot binary and dek_blob..."
cat u-boot_encrypted_no_dek_padded.bin \$DEK_BLOB > u-boot_encrypted.bin

echo -e "\${GREEN}\"u-boot_encrypted.bin\" is ready\${NC}"
print_len u-boot_encrypted.bin

# Download to SD card
echo ""
cat /proc/partitions | grep "sd"
echo ""

read -t 10 -p "Enter the partition to be flashed (Press return to abort): " SD

echo ""
if [ "\$SD" != "" ] && [ -e /dev/\$SD ]; then
    echo "Copying the U-boot to SD Card"
    sudo dd if=u-boot_encrypted.bin of=/dev/\$SD bs=1K seek=1 && sync
else
    echo "Command to copy U-boot to SD Card:"
    echo "sudo dd if=u-boot_encrypted.bin of=/dev/\$SD bs=1K seek=1 && sync"
fi
EOT

echo "Running Device Encryption Key(DEK) generation script..."
bash gen_dek.sh
