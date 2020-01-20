#!/bin/bash

#   Created on 03.01.2020
#   Edited on 20.01.20
#   CHANGELOG:
#   Added file extensions for compatibility
#   20.01.2020:
#   Added conditions to seperate secure boot & encrypted boot
#
#   Daniel D, Jamsin Infotech

if [ ! $# -eq 0 ]; then
if [ "$1" = "s" ]; then
#####################################################################################################
#                                                                                                   #
#                                   Secured Boot                                                    #
#                                                                                                   #
#####################################################################################################
rm -rf u-boot
mkdir u-boot
cd u-boot

if [ ! -e ../u-boot-dtb.imx ]; then
echo ""
echo "Copy the \"u-boot-dtb.imx\" to the relese folder"
echo ""
rm -rf ../u-boot

exit 1
fi
cp ../u-boot-dtb.imx ./

echo ""
echo "Creating u-boot.csf"
echo ""

cat <<EOT >u-boot.csf
[Header]
Version = 4.2
Hash Algorithm = sha256
Engine=ANY
Engine Configuration = 0
Certificate Format = X509
Signature Format = CMS

[Install SRK]
# Index of the key location in the SRK table to be installed
File = "../crts/SRK_1_2_3_4_table.bin"
Source index = 0

[Install CSFK]
# Key used to authenticate the CSF data
File = "../crts/CSF1_1_sha256_1024_65537_v3_usr_crt.pem"

[Authenticate CSF]

[Install Key]
# Key slot index used to authenticate the key to be installed
Verification index = 0
# Target key slot in HAB key store where key will be installed
Target index = 2
# Key to install
File= "../crts/IMG1_1_sha256_1024_65537_v3_usr_crt.pem"


[Authenticate Data]
# Key slot index used to authenticate the image data
Verification index = 2
# 	        Address    Offset 	Length 	   Data_File_Path
Blocks = 0x877ff400 0x00000000 0x00081c00 "u-boot-dtb.imx"  # Update as generated

# Optional
[Authenticate Data]
# Key slot index used to authenticate the image data
Verification index = 2
# 	        Address    Offset 	Length 	   Data_File_Path
Blocks = 0x00910000 0x0000002c 0x000001e8 "u-boot-dtb.imx"  # Update as generated
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
rm -f  u-boot_csf.bin u-boot-signed.imx

echo ""
echo "generating csf binary..."
echo ""

../linux64/bin/cst --o u-boot_csf.bin --i u-boot.csf    # Updated as generated

echo ""
echo "Merging image and csf data..."
echo ""

cat u-boot-dtb.imx u-boot_csf.bin > u-boot-signed.imx    # Updated as generated

echo ""
echo "$(pwd)/u-boot-signed.imx  is ready"
echo ""
EOT

echo ""
echo "Running secure U-Boot image generation script..."
echo ""

bash habimagegen.sh

#
# TODO: Update scripts and values
#

elif [ "$1" = "e" ]; then
#####################################################################################################
#                                                                                                   #
#                                   Secured & Encrypted Boot                                        #
#                                                                                                   #
#####################################################################################################
rm -rf uImage
mkdir uImage
cd uImage

echo "Creating IVT generator script"

cat <<EOT >genIVT.pl
#! /usr/bin/perl -w
use strict;

open(my \$out, '>:raw', 'ivt.bin') or die "Unable to open: $!";
print \$out pack("V", 0x402000D1); # Signature
print \$out pack("V", 0x10801000); # Jump Location
print \$out pack("V", 0x0); # Reserved
print \$out pack("V", 0x0); # DCD pointer
print \$out pack("V", 0x0); # Boot Data
print \$out pack("V", 0x10BFDFE0); # Self Pointer
print \$out pack("V", 0x10BFE000); # CSF Pointer
print \$out pack("V", 0x0); # Reserved
close(\$out);
EOT

echo "Creating File habUimagegen.sh"

cat <<EOT >habUimagegen.sh
#! /bin/bash

echo "extend uImage to 0x3FDFE0..."
objcopy -I binary -O binary --pad-to 0x3fdfe0 --gap-fill=0x5A uImage uImage-pad.bin

echo "generate IVT"
perl genIVT.pl

echo "attach IVT..."
cat uImage-pad.bin ivt.bin > uImage-pad-ivt.bin

echo "generate csf data..."
../osx/bin/cst -o uImage_csf.bin -i uImage.csf

echo "merge image and csf data..."
cat uImage-pad-ivt.bin uImage_csf.bin > uImage-signed.bin

echo "extend final image to 0x400000..."
objcopy -I binary -O binary --pad-to 0x400000 --gap-fill=0x5A uImage-signed.bin uImage-signed-pad.bin
EOT

echo "Creating file uImage.csf"

cat <<EOT >uImage.csf
[Header]
    Version = 4.1   # Defines a version 4.1 CSF description
    Hash Algorithm = SHA256
    Engine Configuration = 0
    Certificate Format = X509
    Signature Format = CMS
    Engine = CAAM
    Engine Configuration = 0

[Install SRK]
    File = "../crts/SRK_1_2_3_4_table.bin"
    Source index = 0

[Install CSFK]
    File = "../crts/CSF1_1_sha256_4096_65537_v3_usr_crt.der"    # Update as generated

[Authenticate CSF]

[Install Key]
    Verification index = 0
    Target index = 2
    File = "../crts/IMG1_1_sha256_4096_65537_v3_usr_crt.der"    # Update as generated

[Authenticate data]
    Verification index = 2
    Blocks = 0x27800400 0x400 800 "u-boot-mx6q-arm2_padded.bin"    # Update as generated

[Install Secret Key]
    Verification index = 0
    Target index = 0
    Key = "dek.bin"    # Update as generated
    Key Length = 128
    Blob address = 0x27831000

[Decrypt Data]
    Verification index = 0
    Mac Bytes = 16
    Blocks = 0x27800720 0x720 0x2E8E0 "u-boot-mx6q-arm2_padded.bin"    # Update as generated
EOT

echo "Building uImage"
bash habUimagegen.sh
else
echo ""
echo "Usage: Provide s for secure boot or e for encrypted boot"
echo ""
exit 1
fi

else
echo ""
echo "Usage: Provide s for secure boot or e for encrypted boot"
echo ""
exit 1
fi
