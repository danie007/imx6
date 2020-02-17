#!/bin/bash

FILE=u-boot-dtb.imx

echo ""
echo "U-Boot dump:"
# od -X -N 0x20 $FILE   # Raw dump with padded 20 bytes

echo "IVT Header: 0x$(hexdump -e '/4 "%X""\n"' -s 0 -n 4 $FILE)"
echo "U-Boot entry point: 0x$(hexdump -e '/4 "%X""\n"' -s 4 -n 4 $FILE)"
echo "DCD PTR: 0x$(hexdump -e '/4 "%X""\n"' -s 12 -n 4 $FILE)"
echo "Boot Data PTR: 0x$(hexdump -e '/4 "%X""\n"' -s 16 -n 4 $FILE)"

IVT_SELF=$(hexdump -e '/4 "%X""\n"' -s 20 -n 4 $FILE)
echo "IVT Self Address: 0x$IVT_SELF"

CSF_PTR=$(hexdump -e '/4 "%X""\n"' -s 24 -n 4 $FILE)
echo "CSF PTR: 0x$CSF_PTR"

echo ""
IMG_LEN=$(printf '%X\n' $((0x$CSF_PTR - 0x$IVT_SELF)))
echo "Image length: CSF PTR – IVT Self = 0x$IMG_LEN"
echo ""
