#!/bin/bash

#   enc_uboot.sh
#   Created on 27.01.2020
#   Updated on 29.07.2020
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

OP_DIR=encrypted_uboot
BOOT_IMG=u-boot.imx

[ ! -e $BOOT_IMG ] && {
    echo "\n${YELLOW}Copy the \"$BOOT_IMG\" to  the folder${NC}"
    echo "${RED}Aborting...${NC}"

    exit 1
}

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

CSF_pad_size=8192 # CSF padded size 0x2000
UBOOT_SIZE_d=$(expr $(stat -c%s "$BOOT_IMG"))
IVT_start_d=$(echo $((16#$IVT_start)))
DEK_BLOB_addr_d=$(expr $IVT_start_d + $UBOOT_SIZE_d + $CSF_pad_size)

DEK_BLOB_addr=$(printf '%x\n' $DEK_BLOB_addr_d)

entry_pt=$(hexdump -e '/4 "%X""\n"' -s 4 -n 4 $BOOT_IMG)

MAC_bytes=16
keylen=128

DEK_BINARY=dek.bin
DEK_BLOB=dek_blob.bin

cat <<EOT >csf_enc.txt
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
# This Authenticate Data command covers the IVT and DCD Data
# The image file referenced will remain unmodified by CST
Blocks = 0x$IVT_start 0x00 0x$dcd_size "$BOOT_IMG"

[Install Secret Key]
# Install the blobs
Verification index = 0
Target index = 0
Key = "$DEK_BINARY"
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

cat <<EOT >csf_sign_enc.txt
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
Key = "$DEK_BINARY.dummy"
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

cat <<EOT >gen_dek.sh
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

[ ! -e u-boot.imx.orig ] && {
    echo -e "\\n\${YELLOW}Copy the \"u-boot.imx.orig\" to the folder\${NC}"
    echo -e "\${RED}Aborting...\${NC}"

    exit 1
}

echo "Copying $BOOT_IMG..."
cp $BOOT_IMG.orig $BOOT_IMG
cp $BOOT_IMG.orig u-boot-enc.imx
cp $BOOT_IMG.orig $BOOT_IMG.dummy

echo "Generating encrypted CSF binary..."

csf_status=\$($CST/linux64/bin/cst -i csf_enc.txt -o csf_enc.bin)
if echo "\$csf_status" | grep -qi 'invalid\|error'; then
    echo -e "\${RED}\$csf_status\${NC}"

    exit 1
fi
echo \$csf_status

echo -e "\${GREEN}\"$DEK_BINARY\" successfully created\${NC}"

echo ""
if [[ -e ../$DEK_BLOB || -e $DEK_BLOB ]]; then
    if [ ! -e $DEK_BLOB ]; then
        cp ../$DEK_BLOB .
    fi
    bash uboot_encryptor.sh
else
    echo "Paste the \"\$(pwd)/$DEK_BINARY\" to SD Card's boot folder"
    echo ""
    echo "Issue the following commands in i.MX6UL EVK U-boot"
    echo ""
    echo "=> load mmc 1 0x80800000 boot/$DEK_BINARY"
    echo "=> dek_blob 0x80800000 0x80801000 $keylen"
    echo "=> ext4write mmc 1:1 0x80801000 /boot/dek_blob.bin 0x48"
    echo ""
    echo -e "\${YELLOW}Paste the \"dek_blob.bin\" from SD Card's boot folder & run uboot_encryptor.sh\${NC}"
fi
EOT

cat <<EOT >uboot_encryptor.sh
#!/bin/bash

###############################################
#    Automatically created by enc_uboot.sh    #
###############################################

YELLOW='$YELLOW'
RED='$RED'
GREEN='$GREEN'
NC='$NC'

DEK_BLOB=$DEK_BLOB

[ ! -e \$DEK_BLOB ] && {
    echo -e "\${YELLOW}Paste \$DEK_BLOB from SD Card to continue\${NC}"
    echo ""
    echo "Steps to create \$DEK_BLOB:"
    echo "  Issue the following command in i.MX6 EVK"
    echo ""
    echo "=> load mmc 1 0x80800000 boot/$DEK_BINARY"
    echo "=> dek_blob 0x80800000 0x80801000 $keylen"
    echo "=> ext4write mmc 1:1 0x80801000 /boot/\$DEK_BLOB 0x48"
    echo ""
    echo -e "\${RED}Stopping...\${NC}"
    exit 1
}

# Removing old data, if any
rm -f tmp.*

print_len() {
    echo "Length of \"\$1\": 0x\$(hexdump \$1 | tail -n 1)"
}

echo "Signing the encrypted CSF binary..."
csf_status=\$($CST/linux64/bin/cst -i csf_sign_enc.txt -o csf_sign_enc.bin)
if echo "\$csf_status" | grep -qi 'invalid\|error'; then
    echo -e "\${RED}\$csf_status\${NC}"

    exit 1
fi
echo \$csf_status

# Removing the dummy files
rm -rf *.dummy

nonce_mac_size=\$((12 + $MAC_bytes + 8)) # Nonce/MAC size (bytes) = Nonce size + MAC bytes + CSF header for Nonce/Mac
csf_enc_size=\$(du -b csf_enc.bin | cut -f1)
mac_offset=\$((\$csf_enc_size - \$nonce_mac_size)) # MAC offset = csf_enc.bin size - Nonce/MAC size

echo "Replacing the nonce..."
dd if=csf_enc.bin of=tmp.noncemac bs=1 skip=\$mac_offset count=\$nonce_mac_size
dd if=tmp.noncemac of=csf_sign_enc.bin bs=1 seek=\$mac_offset count=\$nonce_mac_size

print_len \$DEK_BLOB

echo "Padding CSF to 0x$(printf '%x\n' $CSF_pad_size)..."
objcopy -I binary -O binary --pad-to 0x$(printf '%x\n' $CSF_pad_size) --gap-fill=0xff csf_sign_enc.bin tmp.csf_sign_enc_padded
print_len tmp.csf_sign_enc_padded

echo "Merging image and csf data..."
cat u-boot-enc.imx tmp.csf_sign_enc_padded > tmp.uboot_encrypted_no_dek
print_len tmp.uboot_encrypted_no_dek

# Pad binary
echo "Ensuring image size from zero padding..."
objcopy -I binary -O binary --pad-to 0x$(printf "%x\n" $((0x$UBOOT_SIZE + 0x2000))) --gap-fill=0x00 tmp.uboot_encrypted_no_dek tmp.uboot_encrypted_no_dek_padded
print_len tmp.uboot_encrypted_no_dek_padded

echo "Concatenating u-boot binary and dek_blob..."
cat tmp.uboot_encrypted_no_dek_padded \$DEK_BLOB > uboot-enc.imx

echo -e "\${GREEN}\"uboot-enc.imx\" is ready\${NC}"
print_len uboot-enc.imx

# Download to SD card
echo ""
cat /proc/partitions | grep "sd" | awk '{print \$4}' | grep -v '[0-9]'
echo ""

read -t 10 -p "Enter the partition to be flashed (Press return to abort): " SD

echo ""
if [ "\$SD" != "" ] && [ -e /dev/\$SD ]; then
    echo "Copying the U-boot to SD Card"
    sudo dd if=uboot-enc.imx of=/dev/\$SD bs=1K seek=1 && sync
else
    echo "Command to copy U-boot to SD Card:"
    echo "sudo dd if=\$(pwd)/uboot-enc.imx of=/dev/sdc bs=1K seek=1 && sync"
fi
EOT

chmod 755 uboot_encryptor.sh

echo "Running Device Encryption Key(DEK) generation script..."
bash gen_dek.sh
