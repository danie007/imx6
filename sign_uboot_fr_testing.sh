#!/bin/bash

#   Created on 03.01.2020
#   Edited on 05.02.20
#   CHANGELOG:
#   Added file extensions for compatibility
#   20.01.2020:
#   Added conditions to seperate secure boot & encrypted boot
#   05.02.20:
#   Added recursive image creation for testing
#
#   Daniel D, Jamsin Infotech

###############################################################################
#                                                                             #
#                                   Secured Boot                              #
#                                                                             #
###############################################################################

CST=~/Documents/release

echo ""
echo "Running sign_uboot.sh..."
echo ""

if [ ! -e u-boot-dtb.imx ]; then
echo ""
echo "Copy the \"u-boot-dtb.imx\" to the folder to continue"
echo "Stopping..."

exit 1
fi

rm -rf signed_uboot_fr_tst
mkdir signed_uboot_fr_tst
cd signed_uboot_fr_tst

cp ../u-boot-dtb.imx ./

addr=$(hexdump -e '/4 "%X""\n"' -s 20 -n 4 u-boot-dtb.imx)
offst=00

CSF_PTR=$(hexdump -e '/4 "%X""\n"' -s 24 -n 4 u-boot-dtb.imx)
size=$(printf '%X\n' $((0x$CSF_PTR - 0x$addr)))

echo "Creating uboot.csf"
echo ""

for ((srk_idx = 0; srk_idx < 4; srk_idx++)); do
for csf_pos in 1 2 3 4; do
for ver_idx in 0 2 3 4; do
for tar_idx in 2 3 4; do
for img_pos in 1 2 3 4; do
cat << EOT > uboot.$srk_idx$csf_pos$ver_idx$tar_idx$img_pos.csf 2> /dev/null
[Header]
Version = 4.2
Hash Algorithm = sha256
Engine = CAAM
Engine Configuration = 0
Certificate Format = X509
Signature Format = CMS

[Install SRK]
File = "$CST/crts/SRK_1_2_3_4_table.bin"
Source index = $srk_idx

[Install CSFK]
File = "$CST/crts/CSF${csf_pos}_1_sha256_1024_65537_v3_usr_crt.pem"

[Authenticate CSF]

[Install Key]
Verification index = $ver_idx
Target index = $tar_idx
File= "$CST/crts/IMG${img_pos}_1_sha256_1024_65537_v3_usr_crt.pem"

[Authenticate Data]
Verification index = $tar_idx
Blocks = 0x$addr 0x$offst 0x$size "u-boot-dtb.imx"
EOT
done; done; done; done; done

echo "Creating secure U-Boot image generation script"
echo ""

cat << EOT >signed_uboot_generator.sh
#!/bin/bash

#############################################
#   Automatically created by sign_uboot.sh  #
#############################################

rm -rf signed_uboot
ls uboot.*.csf > csf.list

while read csf; do
base_name=\${csf%.*}

$CST/linux64/bin/cst -i \$csf -o csf_uboot.bin
cat u-boot-dtb.imx csf_uboot.bin > uboot_\${base_name##*.}.sign

rm -rf *.bin
done < csf.list

rm csf.list

mkdir signed_uboot && mv uboot_*.sign signed_uboot/
echo ""
echo "All combinations of signed boot are availble in \$(pwd)/signed_uboot"
EOT

echo "Running secure U-Boot image generation script..."
echo ""

bash signed_uboot_generator.sh
