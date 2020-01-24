#!/bin/bash

#   Created on 03.01.2020
#   Edited on 20.01.20
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

echo ""
echo "sign_zImage.sh"
echo ""

release="/home/uxce/Documents/release"

rm -rf signed_zImage
mkdir signed_zImage
cd signed_zImage

if [ ! -e ../zImage ]; then
echo ""
echo "Copy the \"zImage\" to the folder"
echo ""
echo "Aborting..."
rm -rf ../signed_zImage

exit 1
fi

echo "Creating IVT generator script"

cat <<EOT >genIVT.pl
#! /usr/bin/perl -w
use strict;
open(my \$out, '>:raw', 'ivt.bin') or die "Unable to open: ";
print \$out pack("V", 0x412000D1); # Signature
print \$out pack("V", 0x80800000); # Load Address (*load_address)
print \$out pack("V", 0x0); # Reserved
print \$out pack("V", 0x0); # DCD pointer
print \$out pack("V", 0x0); # Boot Data
print \$out pack("V", 0x80F62000); # Self Pointer (*ivt)
print \$out pack("V", 0x80F62020); # CSF Pointer (*csf)
print \$out pack("V", 0x0); # Reserved
close(\$out);

EOT

echo "Creating file csf_zImage.txt..."

cat <<EOT >csf_zImage.txt
# Illustrative Command Sequence File Description
[Header]
Version = 4.2
Hash Algorithm = sha256
Engine = CAAM
Engine Configuration = 0
Certificate Format = X509
Signature Format = CMS

[Install SRK]
File = "$release/crts/SRK_1_2_3_4_table.bin"
Source index = 0 # Index of the key location in the SRK table to be installed

[Install CSFK]
# Key used to authenticate the CSF data
File = "$release/crts/CSF1_1_sha256_1024_65537_v3_usr_crt.pem"

[Authenticate CSF]

[Install Key]
# Key slot index used to authenticate the key to be installed
Verification index = 0
# Target key slot in HAB key store where key will be installed
Target Index = 2
# Key to install
File= "$release/crts/IMG1_1_sha256_1024_65537_v3_usr_crt.pem"

[Authenticate Data]
# Key slot index used to authenticate the image data
Verification index = 2
#         Address     Offset    Length   Data File Path
Blocks = 0x80800000 0x00000000 0x762020 "zImage_pad_ivt.bin"    # Update as generated
EOT

echo "Creating File habzImagegen.sh"

cat <<EOT >habzImagegen.sh
#! /bin/bash

##############################################
#   Automatically created by sign_zImage.sh  #
##############################################

# Removing old data, if any
rm -f csf_zImage.bin ivt.bin zImage_pad.bin zImage_pad_ivt.bin zImage_signed

echo "Extend zImage to 0x762000..."
objcopy -I binary -O binary --pad-to 0x762000 --gap-fill=0x00 ../zImage zImage_pad.bin
echo "Length of (generated) padded zImage"
hexdump zImage_pad.bin | tail -n 1
echo ""

echo "generate IVT"
perl genIVT.pl
echo "ivt.bin dump:"
hexdump ivt.bin
echo ""

echo "Appending the ivt.bin file at the end of the padded zImage..."
cat zImage_pad.bin ivt.bin > zImage_pad_ivt.bin
echo "Length of padded zImage with ivt"
hexdump zImage_pad_ivt.bin | tail -n 1
echo ""

echo "Calling CST with the CSF input file..."
$release/linux64/bin/cst --o csf_zImage.bin --i csf_zImage.txt
echo "Length of CSF binary"
hexdump csf_zImage.bin | tail -n 1
echo ""

echo "Attaching the CSF binary to the end of the image..."
cat zImage_pad_ivt.bin csf_zImage.bin > zImage_signed
echo "Length of signed zImage"
hexdump zImage_signed | tail -n 1
EOT

echo "Signing zImage..."
bash habzImagegen.sh
echo ""
