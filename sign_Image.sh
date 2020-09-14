#!/bin/bash

#   Created on 03.01.2020
#   Edited on 14.09.20
#   CHANGELOG:
#   Added file extensions for compatibility
#   14.09.2020:
#   Modified script to sign i.MX 8M Mini EVK
#   Changed kernel image name
#
#   Daniel Selvan D

#####################################################################################################
#                                                                                                   #
#                                   Image Signing                                                  #
#                                                                                                   #
#####################################################################################################

CST=~/imx8/cst_33
# CST=~/Downloads/cst-3.3.0 # For testing

OP_DIR=signed_Image
KERNEL_IMG=Image

YELLOW='\e[1;33m'
RED='\e[1;31m'
GREEN='\e[1;32m'
NC='\e[0m'

echo -e "\n${YELLOW}**WARNING** Script contains hard coded file names/directories, update them before execution.${NC}\n"

if [ ! -e $KERNEL_IMG ]; then
    echo ""
    echo -e "${YELLOW}Copy the \"$KERNEL_IMG\" to the folder${NC}"
    echo ""
    echo -e "${RED}Stopping...${NC}"

    exit 1
fi

# size specified in the Image header
KERNEL_SIZE=$(hexdump -e '/4 "%X"' -s 12 -n 8 $KERNEL_IMG)

rm -rf $OP_DIR
mkdir $OP_DIR
cd $OP_DIR

ivt_pad_size=20
CSF_pad_size=2000

# Can be obtained from U-Boot by running => printenv loadaddr
loadaddr=40480000

ivt=$(printf '%X\n' $((0x$loadaddr + 0x$KERNEL_SIZE)))
img_size=$(printf '%X\n' $((0x$KERNEL_SIZE + 0x$ivt_pad_size)))
csf=$(printf '%X\n' $((0x$loadaddr + 0x$img_size)))

echo "Creating IVT generator script"

cat <<EOT >genIVT.pl
#! /usr/bin/perl -w
##############################################
#   Automatically created by sign_Image.sh  #
##############################################
use strict;
open(my \$out, '>:raw', 'ivt.bin') or die "Unable to open: ";
print \$out pack("V", 0x412000D1); # Signature
print \$out pack("V", 0x$loadaddr); # Load Address (*load_address)
print \$out pack("V", 0x0); # Reserved
print \$out pack("V", 0x0); # DCD pointer
print \$out pack("V", 0x0); # Boot Data
print \$out pack("V", 0x$ivt); # Self Pointer (*ivt)
print \$out pack("V", 0x$csf); # CSF Pointer (*csf)
print \$out pack("V", 0x0); # Reserved
close(\$out);
EOT

echo "Creating csf_Image.txt..."

cat <<EOT >csf_Image.txt
[Header]
    Version = 4.3
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
    File = "$CST/crts/CSF1_1_sha256_3072_65537_v3_usr_crt.pem"

[Authenticate CSF]

[Install Key]
    # Key slot index used to authenticate the key to be installed
    Verification index = 0
    # Target key slot in HAB key store where key will be installed
    Target index = 2
    # Key to install
    File = "$CST/crts/IMG1_1_sha256_3072_65537_v3_usr_crt.pem"

[Authenticate Data]
    # Key slot index used to authenticate the image data
    Verification index = 2
    # Authenticate Start Address, Offset, Length and file
    Blocks = 0x$loadaddr 0x00 0x$img_size "Image_pad_ivt.bin"
EOT

echo "Creating File habImagegen.sh"

cat <<EOT >habImagegen.sh
#!/bin/bash
##############################################
#   Automatically created by sign_Image.sh  #
##############################################
YELLOW='$YELLOW'
RED='$RED'
GREEN='$GREEN'
NC='$NC'
if [ ! -e ../$KERNEL_IMG ]; then
echo ""
echo -e "\${YELLOW}Copy the \"$KERNEL_IMG\" to the parent folder\${NC}"
echo ""
echo -e "\${RED}Stopping...\${NC}"
exit 1
fi
# Removing old data, if any
rm -f csf_Image.bin ivt.bin Image_pad.bin Image_pad_ivt.bin Image_signed

echo "Extend $KERNEL_IMG to 0x$KERNEL_SIZE..."
objcopy -I binary -O binary --pad-to 0x$KERNEL_SIZE --gap-fill=0x00 ../$KERNEL_IMG Image_pad.bin
echo "Length of (generated) padded $KERNEL_IMG: \$(hexdump Image_pad.bin | tail -n 1)"
echo ""

echo "generate IVT"
perl genIVT.pl

echo "ivt.bin dump:"
hexdump ivt.bin

echo "Padding ivt.bin to 0x$ivt_pad_size ..."
objcopy -I binary -O binary --pad-to 0x$ivt_pad_size --gap-fill=0x00 ivt.bin ivt_padded.bin
echo "Length of CSF binary: \$(hexdump ivt_padded.bin | tail -n 1)"

echo ""
echo "Appending the ivt_padded.bin file at the end of the padded $KERNEL_IMG..."
cat Image_pad.bin ivt_padded.bin > Image_pad_ivt.bin
echo "Length of padded $KERNEL_IMG with ivt: \$(hexdump Image_pad_ivt.bin | tail -n 1)"

echo ""
echo "Calling CST with the CSF input file ..."
csf_status=\$($CST/linux64/bin/cst -o csf_Image.bin -i csf_Image.txt)
if echo "\$csf_status" | grep -qi 'invalid\|error'; then
    echo -e "\${RED}\$csf_status\${NC}"

    exit 1
fi
echo -e "\${GREEN}\$csf_status\${NC}"

echo ""
echo "Padding CSF to 0x$CSF_pad_size ..."
objcopy -I binary -O binary --pad-to 0x$CSF_pad_size --gap-fill=0xff csf_Image.bin csf_Image_padded.bin
echo "Length of CSF binary: \$(hexdump csf_Image_padded.bin | tail -n 1)"

echo ""
echo "Attaching the CSF binary to the end of the image..."
cat Image_pad_ivt.bin csf_Image_padded.bin > Image_signed
echo "Length of signed $KERNEL_IMG: \$(hexdump Image_signed | tail -n 1)"
echo ""
if [[ -d "/media/$(whoami)/boot" ]]; then
    echo "Copying the U-boot to SD Card ..."
    echo "Removing the original $KERNEL_IMG"
    sudo rm -f /media/$(whoami)/boot/$KERNEL_IMG
    
    echo "Copying the signed $KERNEL_IMG to SD Card"
    sudo cp Image_signed /media/$(whoami)/boot/$KERNEL_IMG
else
    echo "Command to copy U-boot to SD Card:"
    echo "sudo rm -f /media/$(whoami)/boot/$KERNEL_IMG"
    echo "sudo cp \$(pwd)/Image_signed /media/$(whoami)/boot/$KERNEL_IMG"
fi
echo -e "\${GREEN}The provided $KERNEL_IMG signed successfully\${NC}"
EOT

echo ""
echo "Signing $KERNEL_IMG..."
bash habImagegen.sh
