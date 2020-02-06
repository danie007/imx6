#!/usr/bin/env bash

#   Created on 03.01.2020
#   Edited on 03.02.20
#   CHANGELOG:
#   Added file extensions for compatibility
#   20.01.2020:
#   Added conditions to seperate secure boot & encrypted boot
#
#   Daniel D, Jamsin Infotech

#####################################################################################################
#                                                                                                   #
#                                   zImage Signing                                                  #
#                                                                                                   #
#####################################################################################################

CST=~/Documents/release

echo ""
echo "Running sign_zImage.sh"
echo ""

if [ ! -e zImage ]; then
echo ""
echo "Copy the \"zImage\" to the folder"
echo ""
echo "Stopping..."

exit 1
fi

size=$(hexdump zImage | tail -n 1)

rm -rf signed_zImage
mkdir signed_zImage
cd signed_zImage

rem=$(printf '%x\n' $(($(printf "%d\n" 0x$size) % 4096)))   # Getting reminder ( / 0x1000)
padded_size=$(printf '%X\n' $((0x$size - 0x$rem + 0x1000)))  # Padding to next 0x1000

load_address=80800000
ivt=$(printf '%X\n' $((0x$load_address + 0x$padded_size)))
img_size=$(printf '%X\n' $((0x$padded_size + 0x20)))
csf=$(printf '%X\n' $((0x$load_address + 0x$img_size)))

echo "Creating IVT generator script"

cat << EOT > genIVT.pl
#! /usr/bin/perl -w

##############################################
#   Automatically created by sign_zImage.sh  #
##############################################

use strict;
open(my \$out, '>:raw', 'ivt.bin') or die "Unable to open: ";
print \$out pack("V", 0x412000D1); # Signature
print \$out pack("V", 0x$load_address); # Load Address (*load_address)
print \$out pack("V", 0x0); # Reserved
print \$out pack("V", 0x0); # DCD pointer
print \$out pack("V", 0x0); # Boot Data
print \$out pack("V", 0x$ivt); # Self Pointer (*ivt)
print \$out pack("V", 0x$csf); # CSF Pointer (*csf)
print \$out pack("V", 0x0); # Reserved
close(\$out);
EOT

echo "Creating csf_zImage.txt..."

cat << EOT > csf_zImage.txt
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
#        Address Offset Length Data File Path
Blocks = 0x$load_address 0x00 0x$img_size "zImage_pad_ivt.bin"
EOT

echo "Creating File habzImagegen.sh"

cat << EOT > habzImagegen.sh
#! /usr/bin/env bash

##############################################
#   Automatically created by sign_zImage.sh  #
##############################################

if [ ! -e ../zImage ]; then
echo ""
echo "Copy the \"zImage\" to the parent folder"
echo ""
echo "Stopping..."

exit 1
fi

# Removing old data, if any
rm -f csf_zImage.bin ivt.bin zImage_pad.bin zImage_pad_ivt.bin zImage_signed

echo "Extend zImage to 0x$padded_size..."
objcopy -I binary -O binary --pad-to 0x$padded_size --gap-fill=0x00 ../zImage zImage_pad.bin
echo "Length of (generated) padded zImage: \$(hexdump zImage_pad.bin | tail -n 1)"
echo ""

echo "generate IVT"
perl genIVT.pl
echo "ivt.bin dump:"
hexdump ivt.bin
echo ""

echo "Appending the ivt.bin file at the end of the padded zImage..."
cat zImage_pad.bin ivt.bin > zImage_pad_ivt.bin
echo "Length of padded zImage with ivt: \$(hexdump zImage_pad_ivt.bin | tail -n 1)"
echo ""

echo "Calling CST with the CSF input file..."
$CST/linux64/bin/cst --o csf_zImage.bin --i csf_zImage.txt
echo "Length of CSF binary: \$(hexdump csf_zImage.bin | tail -n 1)"
echo ""

echo "Attaching the CSF binary to the end of the image..."
cat zImage_pad_ivt.bin csf_zImage.bin > zImage_signed
echo "Length of signed zImage: \$(hexdump zImage_signed | tail -n 1)"
EOT

echo "Signing zImage..."
bash habzImagegen.sh
echo ""
