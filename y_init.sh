#!/bin/bash
#
# It must be run as root
# apt update; apt install -y curl; apt -y upgrade; curl https://raw.githubusercontent.com/danie007/imx6/master/y_init.sh > ~/y_init && source ~/y_init
# Install Yocto dependencies and perform a initial build
# Created on 17.07.2020
# Daniel, Jasmin Infotech
#
mkdir -p /yocto

if [ ! -f "/yocto/yocto_req_check.sh" ]; then
    curl https://raw.githubusercontent.com/danie007/imx6/master/yocto_req_check.sh >/yocto/yocto_req_check.sh
fi
chmod 700 /yocto/yocto_req_check.sh && source /yocto/yocto_req_check.sh

if test $status -eq 0; then

    mkdir -p /yocto/warrior
    mkdir -p /yocto/downloads
    mkdir -p /yocto/sstate_cache

    cd yocto/warrior

    if [ "$which lala" = "" ]; then
        echo "repo is not setup. Exiting..."

        exit 1
    fi

    repo init -u https://source.codeaurora.org/external/imx/imx-manifest -b imx-linux-warrior
    repo sync

    DISTRO=fsl-imx-x11 MACHINE=imx6ulevk source fsl-setup-release.sh -b test_build

    cd /yocto/warrior

    # Generalising downloads and sstate_cache for later use
    sed -i '/DL_DIR ?= /c\DL_DIR ?= "/yocto/downloads"' /yocto/warrior/test_build/conf/local.conf
    echo '"SSTATE_DIR" ?= "/yocto/sstate_cache"' >>/yocto/warrior/test_build/conf/local.conf

    source setup-environment test_build

    # building image
    time bitbake fsl-image-gui

    exit 0
fi

exit 1
