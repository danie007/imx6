#!/bin/bash

# Filename: yocto_req_check.sh
# Description: Script to check Yocto project requirements
# 
# Author: Daniel Selvan
# Updated on Apr 29 2020

############################ USAGE ############################
#                                                             #
#   sudo bash yocto_req_check.sh                              #
#                                                             #
###############################################################

k_OS_MIN_VERSION=16     # Minimum supported version in Ubuntu
k_RECOM_SPACE=120000000 # 120 GB in KB - REcommended Space in Ubuntu 
k_MIN_SPACE=50200000    # 50.2GB in KB - Minumum required space
k_KB_TO_GB_CON=1000000  # Constant to convert KB to GB (KB/1000000)
# k_MIN_SPACE=20200000  # Testing - 20.2GB in KB

# Dependiences of Yocto build
k_DEPEN_LIST=(
    gawk
    wget
    git-core
    diffstat
    unzip
    texinfo
    gcc-multilib
    build-essential
    chrpath
    socat
    cpio
    python
    python3
    python3-pip
    python3-pexpect
    xz-utils
    debianutils
    iputils-ping
    python3-git
    python3-jinja2
    libegl1-mesa
    libsdl1.2-dev
    pylint3
    xterm
    make
    xsltproc
    docbook-utils
    fop
    dblatex
    xmlto
    u-boot-tools
)

# Exit Status
ES_SUCCESS=0            # Success
ES_PERM_ERR=1           # Permission Error
ES_VER_MM_ERR=2         # Version MisMatch Error
ES_NO_SPC_ERR=3         # NO SPaCe Error
ES_UNMET_DEPEN_ERR=4    # UNMET DEPENdencies ERRor

# Check for root previlages
if [[ $EUID -ne 0 ]]; then
    echo "run the ${!#} as root"
    exit $ES_PERM_ERR
fi

# ping site to check internet connection
TEST_SITE=google.com

# Getting the static hostname of runtime
HOSTNAME=$(hostnamectl | grep -i "operating system" | cut -d' ' -f5-)

# Retrieving Operating System
OS_NAME="$(echo $HOSTNAME | cut -d' ' -f1)"
if [ "$OS_NAME" = "Ubuntu" ]; then
    
    # Comparing major version
    if [ "$(echo $HOSTNAME | cut -d' ' -f2 | cut -d. -f1)" -lt $k_OS_MIN_VERSION ]; then
        # ERR
        # TODO colorise
        echo "The minimum version supported in $k_OS_MIN_VERSION. Kindly update your OS and try again."
        exit $ES_VER_MM_ERR
    fi
else
    # Warning
    # TODO colorise
    echo "Kindly check https://www.yoctoproject.org/docs/3.1/ref-manual/ref-manual.html#detailed-supported-distros for $OS_NAME support before proceed"
fi

# Getting available space in disk
available_space=$(df -Pk . | awk 'NR==2 {print $4}')

# Checking for minimum space requirements
if [ "$available_space" -lt $k_MIN_SPACE ]; then
    # ERR
    # TODO colorise
    echo "$(($k_MIN_SPACE/$k_KB_TO_GB_CON))GB is not available in current disk ($(df -Pk . | awk 'NR==2 {print $1}'))"
    echo "Update storage or try in different disk to proceed"
    exit $ES_NO_SPC_ERR
elif [ "$available_space" -lt $k_RECOM_SPACE ]; then
    # Warning
    # TODO colorise
    echo "It is recommended to have $(($k_RECOM_SPACE/$k_KB_TO_GB_CON))GB for hassle free build, but $available_space is just sufficient"
fi

update_depen=()
for dependency in "${k_DEPEN_LIST[@]}"; do

    # Checking for dependencies
    dpkg --list | grep $dependency > /dev/null
    if [ $? -ne 0 ]; then
        # Filtering the dependiences to install
        update_depen+=( $dependency )
    fi
done

depen_count=${#update_depen[@]}

# Updating dependency count based on repo
which repo &> /dev/null
if [ $? -ne 0 ]; then
    ((depen_count++))
fi

# function to automatically detect the user and environment of a current session
function run-in-user-session() {
    _display_id=":$(find /tmp/.X11-unix/* | sed 's#/tmp/.X11-unix/X##' | head -n 1)"
    _username=$(who | grep "\(${_display_id}\)" | awk '{print $1}')
    _user_id=$(id -u "$_username")
    _environment=("DISPLAY=$_display_id" "DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$_user_id/bus")
    sudo -Hu "$_username" env "${_environment[@]}" "$@"
}

if [ "$depen_count" -ne 0 ];then

    # Checking for internet connection
    if ping -q -c 1 -W 1 $TEST_SITE &> /dev/null; then
        echo "Updating repositories"
        apt update
        apt install -y "${update_depen[@]}"

        REPO_PATH=/home/$(sudo -u $SUDO_USER whoami)/bin

        # Downloading and installing repo tool
        run-in-user-session mkdir $REPO_PATH 2> /dev/null
        run-in-user-session curl http://commondatastorage.googleapis.com/git-repo-downloads/repo > $REPO_PATH/repo
        chmod a+x $REPO_PATH/repo

        grep "$REPO_PATH" /etc/environment > /dev/null
        if [ $? -ne 0 ]; then
            sed -i "s|$|:${REPO_PATH}|" /etc/environment && source /etc/environment
        fi
    else
        # ERR
        # TODO colorise
        echo "No internet connection is available."
        echo "Unable to update following dependencies:"
        for dependency in "${update_depen[@]}"; do
            echo $dependency
        done

        echo "Enable internet or manually install the dependencies to continue"
        exit $ES_UNMET_DEPEN_ERR
    fi
fi

exit $ES_SUCCESS