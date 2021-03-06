# WARRIOR:
```bash
repo init -u https://source.codeaurora.org/external/imx/imx-manifest -b imx-linux-warrior -m imx-4.19.35-1.1.0.xml

repo sync -j3

git clone -b warrior https://github.com/mendersoftware/meta-mender.git

MACHINE=imx6ulevk DISTRO=fslc-framebuffer source setup-environment mender_build

bitbake-layers add-layer ../sources/meta-mender/meta-mender-core

bitbake -e core-image-full-cmdline | egrep '^PREFERRED_PROVIDER_(virtual/bootloader|u-boot)='

vim ../sources/meta-freescale/recipes-bsp/u-boot/u-boot-fslc_2019.07.bb

code conf/local.conf conf/bblayers.conf

bitbake -c compile -f core-image-full-cmdline && time bitbake core-image-full-cmdline; alarm
```

`~/warrior_yocto/mender_build/conf/local.conf`
```conf
# IP of local server
MENDER_DEMO_HOST_IP_ADDRESS = "192.168.1.6"

MENDER_STORAGE_DEVICE = "/dev/mmcblk1"
MENDER_STORAGE_TOTAL_SIZE_MB = "7416"

# Parallism settings
BB_NUMBER_THREADS = "3"
PARALLEL_MAKE = "-j 3"

MENDER_ARTIFACT_NAME = "release-1"

INHERIT += "mender-full"
MENDER_FEATURES_ENABLE_append = " mender-uboot mender-image-sd"

MACHINE ??= 'imx6ulevk'
DISTRO ?= 'fslc-xwayland'
PACKAGE_CLASSES ?= 'package_rpm'
EXTRA_IMAGE_FEATURES ?= "debug-tweaks"
USER_CLASSES ?= "buildstats image-mklibs image-prelink"
PATCHRESOLVE = "noop"
BB_DISKMON_DIRS ??= "\
    STOPTASKS,${TMPDIR},1G,100K \
    STOPTASKS,${DL_DIR},1G,100K \
    STOPTASKS,${SSTATE_DIR},1G,100K \
    STOPTASKS,/tmp,100M,100K \
    ABORT,${TMPDIR},100M,1K \
    ABORT,${DL_DIR},100M,1K \
    ABORT,${SSTATE_DIR},100M,1K \
    ABORT,/tmp,10M,1K"
PACKAGECONFIG_append_pn-qemu-system-native = " sdl"
PACKAGECONFIG_append_pn-nativesdk-qemu = " sdl"
CONF_VERSION = "1"

DL_DIR ?= "/home/ux/.yocto/warrior/downloads/"
ACCEPT_FSL_EULA = "1"
```

`~/warrior_yocto/mender_build/conf/local.conf`
```conf
LCONF_VERSION = "7"

BBPATH = "${TOPDIR}"
BSPDIR := "${@os.path.abspath(os.path.dirname(d.getVar('FILE', True)) + '/../..')}"

BBFILES ?= ""
BBLAYERS = " \
  ${BSPDIR}/sources/poky/meta \
  ${BSPDIR}/sources/poky/meta-poky \
  ${BSPDIR}/sources/meta-openembedded/meta-oe \
  ${BSPDIR}/sources/meta-openembedded/meta-multimedia \
  ${BSPDIR}/sources/meta-freescale \
  ${BSPDIR}/sources/meta-freescale-3rdparty \
  ${BSPDIR}/sources/meta-freescale-distro \
  ${BSPDIR}/sources/meta-mender/meta-mender-core \
  "
```

`~/warrior_yocto/sources/meta-freescale/recipes-bsp/u-boot/u-boot-fslc_2019.07.bb`
```bitbake
require recipes-bsp/u-boot/u-boot.inc
require u-boot-fslc-common_${PV}.inc
require recipes-bsp/u-boot/u-boot-mender.inc

DESCRIPTION = "U-Boot based on mainline U-Boot used by FSL Community BSP in \
order to provide support for some backported features and fixes, or because it \
was submitted for revision and it takes some time to become part of a stable \
version, or because it is not applicable for upstreaming."

DEPENDS_append = " bc-native dtc-native"

PROVIDES += "u-boot"
RPROVIDES_${PN} += "u-boot"

# FIXME: Allow linking of 'tools' binaries with native libraries
#        used for generating the boot logo and other tools used
#        during the build process.
EXTRA_OEMAKE += 'HOSTCC="${BUILD_CC} ${BUILD_CPPFLAGS}" \
                 HOSTLDFLAGS="${BUILD_LDFLAGS}" \
                 HOSTSTRIP=true'

PACKAGE_ARCH = "${MACHINE_ARCH}"
COMPATIBLE_MACHINE = "(mxs|mx5|mx6|mx7|vf|use-mainline-bsp)"
```

### machine.conf:
`~/warrior_yocto/sources/meta-freescale/conf/machine/imx6ulevk.conf`


_WARNING_:
KERNEL_DEVICETREE = " imx6ul-14x14-evk.dtb"


## 19.05.2020

1. Enabling Secure Boot Option:  
    Add the following lines in `~/warrior_yocto/mender_build/tmp/work/imx6ulevk-fslc-linux-gnueabi/u-boot-fslc/v2019.07+gitAUTOINC+ca0ab15271-r0/git/configs/mx6ul_14x14_evk_defconfig`
    ```conf
    CONFIG_SECURE_BOOT=y
    CONFIG_CMD_DEKBLOB=y
    CONFIG_IMX_CAAM_DEK_ENCAP=y
    CONFIG_CMD_PRIBLOB=y
    CONFIG_FSL_CAAM=y
    CONFIG_SYS_FSL_HAS_SEC=y
    CONFIG_SYS_FSL_SEC_COMPAT=4
    CONFIG_SHA_HW_ACCEL=y
    ```

2. Making u-boot.imx

    To determine the u-boot provider enter the command:
    ```bash
    bitbake -e core-image-full-cmdline | egrep '^PREFERRED_PROVIDER_(virtual/bootloader|u-boot)='
    ```

    Create `u-boot-fslc_2019.07.bbappend` in `~/warrior_yocto/sources/meta-freescale/recipes-bsp/u-boot` with following lines as content (It'll produce `.imx` image):
    ```bitbake
    do_compile_append() {
        if [ -n "${UBOOT_CONFIG}" ]
        then
            unset i j
            for config in ${UBOOT_MACHINE}; do
                i=$(expr $i + 1);
                for type in ${UBOOT_CONFIG}; do
                    j=$(expr $j + 1);
                    if [ $j -eq $i ]
                    then
                        dd if="${B}/${config}/SPL" of="${B}/${config}/u-boot-${type}.imx"
                        dd if="${B}/${config}/u-boot.img" of="${B}/${config}/u-boot-${type}.imx" obs=1K seek=68
                    fi
                done
                unset  j
            done
            unset  i
        else
            dd if="${B}/SPL" of="${B}/u-boot.imx"
            dd if="${B}/u-boot.img" of="${B}/u-boot.imx" obs=1K seek=68
        fi

    }

    do_deploy_append () {
        if [ -n "${UBOOT_CONFIG}" ]
        then
            for config in ${UBOOT_MACHINE}; do
                i=$(expr $i + 1);
                for type in ${UBOOT_CONFIG}; do
                    j=$(expr $j + 1);
                    if [ $j -eq $i ]
                    then
                        install -d ${DEPLOYDIR}
                        install -m 644 ${B}/${config}/u-boot-${type}.imx ${DEPLOYDIR}/u-boot-${type}-${PV}-${PR}.imx
                        cd ${DEPLOYDIR}
                        ln -sf u-boot-${type}-${PV}-${PR}.imx u-boot-${type}.imx
                        ln -sf u-boot-${type}-${PV}-${PR}.imx u-boot.imx
                    fi
                done
                unset  j
            done
            unset  i
        else
            install -d ${DEPLOYDIR}
            install -m 644 ${B}/u-boot.imx ${DEPLOYDIR}/u-boot-${PV}-${PR}.imx
            cd ${DEPLOYDIR}
            rm -f u-boot*.imx
            ln -sf u-boot-${PV}-${PR}.imx u-boot.imx

    fi

    }
    ```

3. Adding u-boot.imx

    Edit the `conf/local.conf` with following lines
    ```sh
    MENDER_IMAGE_BOOTLOADER_BOOTSECTOR_OFFSET = "2"
    MENDER_IMAGE_BOOTLOADER_FILE = "u-boot.imx"
    ```

4. Compile
    ```bash
    bitbake -c compile -f u-boot-fslc; time bitbake core-image-full-cmdline; alarm
    ```

## 29.05.2020:

1. Changing u-boot provider to u-boot-imx

    Open `MACHINE.conf` file at `~/warrior_yocto/sources/meta-freescale/conf/machine/imx6ulevk.conf`
    Change the following:
    ```sh
    UBOOT_SUFFIX = "imx"
    # SPL_BINARY = "SPL"
    WKS_FILE = "imx-uboot-bootpart.wks.in"
    ```
    Open `~/warrior_yocto/sources/meta-freescale/conf/machine/include/imx-base.inc`
    Change the following:
    ```bitbake
    IMX_DEFAULT_BOOTLOADER_mx6ul = "u-boot-imx" # Add
    IMX_DEFAULT_KERNEL_mx6ul = "linux-imx"  # Replace
    ```
    Open `~/warrior_yocto/sources/poky/meta/recipes-bsp/u-boot/u-boot.inc`
    Add the following in `do_compile` function after `oe_runmake`
    ```sh
    if [ -f ${B}/${config}/u-boot-dtb.imx ]; then
        ln -sf ${B}/${config}/u-boot-dtb.imx ${B}/${config}/u-boot.imx
    fi
    ```


2. Adding mender support in u-boot:

    Open `~/warrior_yocto/sources/meta-mender/meta-mender-core/recipes-bsp/u-boot/patches/` and

    a. Replace the contents of `0003-Integration-of-Mender-boot-code-into-U-Boot.patch`
    ```patch
    include/env_default.h     | 3 +++
    scripts/Makefile.autoconf | 3 ++-
    2 files changed, 5 insertions(+), 1 deletion(-)

    diff --git a/include/env_default.h b/include/env_default.h
    index 54d8124..9cf272c 100644
    --- a/include/env_default.h
    +++ b/include/env_default.h
    @@ -9,6 +9,7 @@
    */
    
    #include <env_callback.h>
    +#include <env_mender.h>
    
    #ifdef DEFAULT_ENV_INSTANCE_EMBEDDED
    env_t environment __UBOOT_ENV_SECTION__ = {
    @@ -22,6 +23,7 @@
    #else
    const uchar default_environment[] = {
    #endif
    +	MENDER_ENV_SETTINGS
    #ifdef	CONFIG_ENV_CALLBACK_LIST_DEFAULT
        ENV_CALLBACK_VAR "=" CONFIG_ENV_CALLBACK_LIST_DEFAULT "\0"
    #endif
    diff --git a/scripts/Makefile.autoconf b/scripts/Makefile.autoconf
    index 00b8fb3..e312c80 100644
    --- a/scripts/Makefile.autoconf
    +++ b/scripts/Makefile.autoconf
    @@ -111,7 +111,8 @@ define filechk_config_h
        echo \#include \<configs/$(CONFIG_SYS_CONFIG_NAME).h\>;		\
        echo \#include \<asm/config.h\>;				\
        echo \#include \<linux/kconfig.h\>;				\
    -	echo \#include \<config_fallbacks.h\>;)
    +	echo \#include \<config_fallbacks.h\>;				\
    +	echo \#include \<config_mender.h\>;)
    endef
    
    include/config.h: scripts/Makefile.autoconf create_symlink FORCE
    -- 
    2.7.4

    ```
    b. Create a file named `0005-fw_env_main.c-Fix-incorrect-size-for-malloc-ed-strin.patch` with following contents.
    ```patch
    From 17236152bf80436567bf3f1f27af3915364ec0b6 Mon Sep 17 00:00:00 2001
    From: Kristian Amlie <kristian.amlie@northern.tech>
    Date: Wed, 4 Apr 2018 10:01:04 +0200
    Subject: [PATCH 5/5] fw_env_main.c: Fix incorrect size for malloc'ed string.

    Using sizeof gives the size of the pointer only, not the string.

    Signed-off-by: Kristian Amlie <kristian.amlie@northern.tech>
    ---
    tools/env/fw_env_main.c | 2 +-
    1 file changed, 1 insertion(+), 1 deletion(-)

    diff --git a/tools/env/fw_env_main.c b/tools/env/fw_env_main.c
    index 6fdf41c..f8e3f07 100644
    --- a/tools/env/fw_env_main.c
    +++ b/tools/env/fw_env_main.c
    @@ -239,7 +239,7 @@ int main(int argc, char *argv[])
        argv += optind;
    
        if (env_opts.lockname) {
    -		lockname = malloc(sizeof(env_opts.lockname) +
    +		lockname = malloc(strlen(env_opts.lockname) +
                    sizeof(CMD_PRINTENV) + 10);
            if (!lockname) {
                fprintf(stderr, "Unable allocate memory");
    -- 
    2.7.4

    ```

    Open `u-boot-imx_2018.03.bb` in `~/warrior_yocto/sources/meta-freescale/recipes-bsp/u-boot/u-boot-imx_2018.03.bb`
    Add the following lines:
    ```bitbake
    require recipes-bsp/u-boot/u-boot-mender.inc
    RPROVIDES_${PN} += "u-boot"

    SRC_URI_append = " file://0005-fw_env_main.c-Fix-incorrect-size-for-malloc-ed-strin.patch"
    ```

    Open `u-boot-mender-common.inc` persent in `~/warrior_yocto/sources/meta-mender/meta-mender-core/recipes-bsp/u-boot/`
    Add the following line at top:
    ```sh
    MENDER_UBOOT_PRE_SETUP_COMMANDS = "setenv kernel_addr_r \${loadaddr}"
    ```


3. Adding mender certificate in build:

    Create a mender bbappend file in `/home/ux/warrior_yocto/sources/meta-mender/meta-mender-core/recipes-mender/mender/mender_%.bbappend` with following contents,
    ```bitbake
    FILESEXTRAPATHS_prepend := "${THISDIR}/files:"
    SRC_URI_append = " file://server.crt"
    ```
    Copy your `server.crt` to: `~/warrior_yocto/sources/meta-mender/meta-mender-core/recipes-mender/mender/files/`


4. Bringing up network with rc.local file

    As a workaround we can include `fsl-rc-local` in the build and configure it to bring network in each restart.
    Append the following lines in your `conf/local.conf`
    ```sh
    # Adding support for rc.local script
    # It'll be used to auto run script at reboot
    IMAGE_INSTALL_append = " fsl-rc-local"
    ```
    Edit the `~/warrior_yocto/sources/meta-freescale-distro/recipes-fsl/fsl-rc-local/fsl-rc-local/rc.local.etc`
    ```bash
    # Edited by Daniel on 09.06.2020
    # Command to manually start network interfaces
    # Added -n option to exit udhcpc after failure
    # Otherwise it'll looping in reconnect state hindering boot
    udhcpc -i eth1 -n
    ```


5. local configuration

    Append the following:
    ```sh
    # The name of the image or update that will be built
    # This is what the device will report that it is running
    # and different updates must have different names
    MENDER_ARTIFACT_NAME = "release-1"

    # REQUIRED:
    # Adding support for rc.local script
    # It'll be used to auto run script at reboot
    IMAGE_INSTALL_append = " fsl-rc-local"

    # MENDER_FEATURES settings and the inherit of mender-full
    INHERIT += "mender-full"

    # The storage device holding all partitions
    # See https://docs.mender.io/2.3/devices/yocto-project/partition-configuration#configuring-storage
    # for more information
    MENDER_STORAGE_DEVICE = "/dev/mmcblk1"

    # OPTIONAL:
    # Build for Mender demo server
    #
    # https://docs.mender.io/getting-started/on-premise-installation/create-a-test-environment
    #
    # Update IP address to match the machine running the
    # Mender demo server
    MENDER_DEMO_HOST_IP_ADDRESS = "192.168.1.31"

    # Total size of the medium, expressed in MB
    # Default value is 1024 MB
    # MENDER_STORAGE_TOTAL_SIZE_MB = "7416"

    # This sets the offset where the bootloader should be placed,
    # counting from the start of the storage medium
    # The offset is specified in units of 512-byte sectors
    MENDER_IMAGE_BOOTLOADER_BOOTSECTOR_OFFSET = "2"

    # File to be written directly into the boot sector
    MENDER_IMAGE_BOOTLOADER_FILE = "u-boot.imx"

    # See https://docs.mender.io/2.3/artifacts/yocto-project/image-configuration/features
    # for details
    MENDER_FEATURES_ENABLE_append = " mender-uboot mender-image-sd"

    MENDER_FEATURES_DISABLE_append = " mender-growfs-data"
    MENDER_FEATURES_DISABLE_append = " mender-grub mender-image-uefi"
    ```


6. Encryption support
    Open `uboot_auto_patch.sh` in `~/warrior_yocto/sources/meta-mender/meta-mender-core/recipes-bsp/u-boot/files/uboot_auto_patch.sh`
    Add the following:
    ```bash
    # Top
    ENCR_BOOT=1

    # Somewhere in middle
    _add_definition() {
        defconfig=configs/$CONFIG
        
        # backing up original configuration
        if [ ! -f $defconfig.orig ]; then
            cp $defconfig $defconfig.orig
        fi

        # Removing configuration, if any and rewritng the file
        if [ grep -q "$1" "$defconfig" ]; then
            grep -v "$1" $defconfig.orig > $defconfig
        fi

        echo "$1=y" >> $defconfig
    }

    # Edited by Daniel on 30.05.2020
    # Adding support for encrypted boot(signed) in U-Boot
    # Tested on imx-linux 2018
    patch_encrypted_boot() {

        # Secure Boot
        _add_definition 'CONFIG_SECURE_BOOT'

        # Encrypted Boot options
        _add_definition 'CONFIG_CMD_DEKBLOB'
        _add_definition 'CONFIG_IMX_CAAM_DEK_ENCAP'
        _add_definition 'CONFIG_CMD_PRIBLOB'
        _add_definition 'CONFIG_FSL_CAAM'
        _add_definition 'CONFIG_SYS_FSL_HAS_SEC'
        _add_definition 'CONFIG_SYS_FSL_SEC_COMPAT'
        _add_definition 'CONFIG_SHA_HW_ACCEL'
    }

    # Bottom
    if [ $ENCR_BOOT = 1 ]; then
        patch_encrypted_boot
    fi
    ```


7. (_Optional_) Changing kernel version:

    By default Warrior Yocto builds kernel version **4.9** and if you want to change that to **4.19** paste the following in
    `~/warrior_yocto/sources/meta-freescale/recipes-kernel/linux/linux-imx_4.9.123.bb`

    _It is advisible to save a copy of original file contents as it'll be required to build 4.9 kernel if needed._
    ```bitbake
    # Modified by Daniel on 30.05.2020
    # Builds kernel version 4.19.35

    SUMMARY = "Linux Kernel provided and supported by NXP"
    DESCRIPTION = "Linux Kernel provided and supported by NXP with focus on \
    i.MX Family Reference Boards. It includes support for many IPs such as GPU, VPU and IPU."

    require recipes-kernel/linux/linux-imx.inc

    LICENSE = "GPLv2"
    LIC_FILES_CHKSUM = "file://COPYING;md5=bbea815ee2795b2f4230826c0c6b8814"
    DEPENDS += "lzop-native bc-native"

    SRCBRANCH = "imx_4.19.35_1.1.0"
    LOCALVERSION = "-1.1.0"
    KERNEL_SRC ?= "git://source.codeaurora.org/external/imx/linux-imx.git;protocol=https"
    SRC_URI = "${KERNEL_SRC};branch=${SRCBRANCH}"
    SRCREV = "0f9917c56d5995e1dc3bde5658e2d7bc865464de"

    S = "${WORKDIR}/git"

    DEFAULT_PREFERENCE = "1"

    DEFCONFIG     = "defconfig"
    DEFCONFIG_mx6 = "imx_v7_defconfig"
    DEFCONFIG_mx7 = "imx_v7_defconfig"

    do_preconfigure_prepend() {
        # meta-freescale/classes/fsl-kernel-localversion.bbclass requires
        # defconfig in ${WORKDIR}
        install -d ${B}
        cp ${S}/arch/${ARCH}/configs/${DEFCONFIG} ${WORKDIR}/defconfig
    }

    COMPATIBLE_MACHINE = "(mx6|mx7|mx8)"
    ```

    **NOTE**: This method is not perfect as the kernel name still the old(4.9)

    Original `~/warrior_yocto/sources/meta-freescale/recipes-kernel/linux/linux-imx_4.9.123.bb` file content:
    ```bitbake
    # Copyright (C) 2013-2016 Freescale Semiconductor
    # Copyright 2017-2018 NXP
    # Copyright 2018 (C) O.S. Systems Software LTDA.
    # Released under the MIT license (see COPYING.MIT for the terms)

    SUMMARY = "Linux Kernel provided and supported by NXP"
    DESCRIPTION = "Linux Kernel provided and supported by NXP with focus on \
    i.MX Family Reference Boards. It includes support for many IPs such as GPU, VPU and IPU."

    require recipes-kernel/linux/linux-imx.inc

    DEPENDS += "lzop-native bc-native"

    SRCBRANCH = "imx_4.9.123_imx8mm_ga"
    LOCALVERSION = "-imx"
    SRCREV = "6a71cbc089755afd6a86c005c22a1af6eab24a70"

    DEFAULT_PREFERENCE = "1"

    COMPATIBLE_MACHINE = "(mx6|mx7|mx8)"

    ```


8. (_Optional_) signing mender artifact:

    a. generating keys

    RSA with recommended key length of at least 3072 bits
    ```bash
    openssl genpkey -algorithm RSA -out private.key -pkeyopt rsa_keygen_bits:3072
    openssl rsa -in private.key -out private.key
    openssl rsa -in private.key -out public.key -pubout
    mv public.key artifact-verify-key.pem
    ```
    b. Adding public key to Yocto build

    Copy the generated `artifact-verify-key.pem` to `~/warrior_yocto/sources/meta-mender/meta-mender-core/recipes-mender/mender/files/`

    Modify the mender bbappend file in `~/warrior_yocto/sources/meta-mender/meta-mender-core/recipes-mender/mender/mender_%.bbappend` with following contents,
    ```bitbake
    SRC_URI_append = " \
        file://server.crt \
        file://artifact-verify-key.pem \
    "
    ```
    c. Signing artifact

    ```bash
    # Creating mender artifact from rootfs with signing
    mender-artifact --compression lzma write rootfs-image -t imx6ulevk -n release-2 -f core-image-full-cmdline-imx6ulevk-20200605060411.ext4 -k private.key -o core-image-full-cmdline-imx6ulevk-r2s.mender

    # Signing a mender artifact
    mender-artifact sign core-image-full-cmdline-imx6ulevk-r2.mender -k private.key -o core-image-full-cmdline-imx6ulevk-r2-signed.mender
    ```

    d. Validating mender artifact:

    In terminal run, 
    ```shell
    mender-artifact validate core-image-full-cmdline-imx6ulevk-r2-signed.mender -k artifact-verify-key.pem
    ``` 
    If succeed you'll get '_mender-artifact validate succeed_' or '_crypto/rsa: verification error_' on error.


9. build

    Can be built with any of the following commands.
    Ensure **MACHINE=imx6ulevk** & **DISTRO=fslc-framebuffer** in `warrior_yocto/mender_build/conf/local.conf`
    ```bash
    time bitbake core-image-full-cmdline
    bitbake -c cleanall core-image-full-cmdline # Clean build
    bitbake -c compile -f core-image-full-cmdline & time bitbake core-image-full-cmdline # Fore re-compile all the source & builds image
    bitbake -c cleansstate linux-imx core-image-full-cmdline && bitbake core-image-full-cmdline # Clean kernal & builds image
    ```


## 05.06.2020

 - Modifying mender parameters in rootfs before `.mender` file creation:
```bash
mount -o loop core-image-full-cmdline-imx6ulevk.ext4 /mnt/rootfs/

cd /mnt/rootfs/

vim etc/mender/artifact_info # Inc release for updation

mkdir -p usr/share/mender/modules/v3

cat > home/root/release_info << EOF
Kernel version: 4.19.35
Release version: release-2s
Date modified: 09.06.2020
Modified by: Daniel Selvan D, Jasmin Infotech
EOF

echo "$IP_OF_MENDER_SERVER_FROM_DEVICE docker.mender.io s3.docker.mender.io" | tee -a etc/hosts

cat > etc/mender/mender.conf << EOF
{   
    "ClientProtocol": "https",
    "ArtifactVerifyKey": "/etc/mender/artifact-verify-key.pem",
    "HttpsClient": {
        "Certificate": "",
        "Key": "",
        "SkipVerify": false
    },
    "RootfsPartA": "/dev/mmcblk1p1",
    "RootfsPartB": "/dev/mmcblk1p2",
    "DeviceTypeFile": "/var/lib/mender/device_type",
    "UpdatePollIntervalSeconds": 5,
    "InventoryPollIntervalSeconds": 5,
    "RetryPollIntervalSeconds": 30,
    "StateScriptTimeoutSeconds": 0,
    "StateScriptRetryTimeoutSeconds": 0,
    "StateScriptRetryIntervalSeconds": 0,
    "ModuleTimeoutSeconds": 0,
    "ServerCertificate": "/etc/mender/server.crt",
    "ServerURL": "",
    "UpdateLogPath": "",
    "TenantToken": "",
    "Servers": [
        {   
            "ServerURL": "https://docker.mender.io"
        }
    ]
}
EOF

cd && umount /mnt/rootfs # Changes will be saved in .ext4 file
```
 - `.mender` file creation command:
```bash
mender-artifact --compression lzma write rootfs-image -t imx6ulevk -n release-2 -f core-image-full-cmdline-imx6ulevk-20200605060411.ext4 -o core-image-full-cmdline-imx6ulevk-r2.mender
```
 - `dek_blob` creation command in U-Boot: (_Modified for mender integrated file system_)
```sh
# In U-Boot prompt
=> load mmc 1 0x80800000 boot/dek.bin
=> dek_blob 0x80800000 0x80801000 128
=> ext4write mmc 1:1 0x80801000 /boot/dek_blob.bin 0x48
```
