#!/bin/bash

# Filename: yocto_req_check.sh
# Description: Script to check Yocto project requirements
# 
# Author: Daniel Selvan
# Updated on Apr 28 2020

############################ USAGE ######################################
#                                                                       #
#   bash yocto_req_check.sh               #
#                                                                       #
#   build_option:                                                       #
#   TODO              #
#                                                                       #
#########################################################################

k_OS_MIN_VERSION=14   # Minimum supported version in Ubuntu
k_MIN_SPACE=50200000  # 50.2GB in KB
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
    # if [[ "$(echo $HOSTNAME | cut -d' ' -f2 | cut -d. -f1)" -lt $k_OS_MIN_VERSION ]]; then
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

# Checking for minimum space requirements
if [[ "$(df -Pk . | awk 'NR==2 {print $4}')" -lt $k_MIN_SPACE ]]; then
    # ERR
    # TODO colorise
    echo "50 GB is not available in current disk ($(df -Pk . | awk 'NR==2 {print $1}'))"
    echo "Update storage or try in different disk to proceed"
    exit $ES_NO_SPC_ERR
fi

update_depen=()
for dependency in "${k_DEPEN_LIST[@]}"; do

    # Checking for dependencies
    which dependency &> /dev/null
    if [ $? -ne 0 ]; then
        # Filtering the dependiences to install
        update_depen+=( $dependency )
    fi
done

depen_count=${#update_depen[@]}

# Updating dependency count based on repo
which dependency &> /dev/null
if [ $? -ne 0 ]; then
    ((depen_count++))
fi

if [ "$depen_count" -ne 0 ];then

    # Checking for internet connection
    if ping -q -c 1 -W 1 $TEST_SITE &> /dev/null; then

        Downloading and installing repo tool
        run-in-user-session mkdir ~/bin 2> /dev/null
        run-in-user-session curl http://commondatastorage.googleapis.com/git-repo-downloads/repo > ~/bin/repo
        run-in-user-session chmod a+x ~/bin/repo

        run-in-user-session PATH=${PATH}:~/bin
        run-in-user-session source /etc/environment && export PATH

        echo "Updating repositories"
        apt update
        apt install -y "${update_depen[@]}"
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

# function to automatically detect the user and environment of a current session
function run-in-user-session() {
    _display_id=":$(find /tmp/.X11-unix/* | sed 's#/tmp/.X11-unix/X##' | head -n 1)"
    _username=$(who | grep "\(${_display_id}\)" | awk '{print $1}')
    _user_id=$(id -u "$_username")
    _environment=("DISPLAY=$_display_id" "DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$_user_id/bus")
    sudo -Hu "$_username" env "${_environment[@]}" "$@"
}

# Downloading and installing repo tool
# mkdir ~/bin 2> /dev/null
# curl http://commondatastorage.googleapis.com/git-repo-downloads/repo > ~/bin/repo
# chmod a+x ~/bin/repo

# DEFCONF=mx6ul_14x14_evk_defconfig
# toolchain=~/tools/gcc-arm-8.3-2019.03-x86_64-arm-linux-gnueabihf/bin/arm-linux-gnueabihf- # ARM Cross compiler
# err_str=Error   # Error keyword to be searched in the log file.

# reqcc=arm-linux-gnueabihf-gcc
# requiredver="6.2.0"

# LOG_FILE=$1/build_$(date '+%y%^b%d_%H%M%S').log # output log format: build_yymmmdd_HHMMSS.log
# boot_mode="default"

# GREEN='\e[1;32m'
# YELLOW='\e[1;33m'
# RED='\e[1;31m'
# NC='\e[0m'

# usage() {
#     echo -e "\n${RED}Usage: $0 build_directory [build_option]${NC}\n"
#     echo "build_option:"
#     echo "-s, --secure    Support i.MX HAB features"
#     echo "-e, --encrypt   Support the 'dek_blob' command"
#     echo "If no option specified build the default configuration of U-boot"
#     echo ""
#     echo "-h, --help      Displays this help message and exit"

#     exit 1
# }

# # Argument Parser
# if [ $# -eq 0 ]; then
#     usage
# # 1st paramater is mandatory, 2nd parameter is optional
# elif [ "$(printf '%s' "$1" | cut -c1)" != "-" ]; then
#     case $2 in
#     -s | --secure)
#         boot_mode="secured"
#         ;;
#     -e | --encrypt)
#         boot_mode="encrypted"
#         ;;
#     " " | "") ;;
#         # If second paramter is not present, pass
#     *)
#         usage
#         ;;
#     esac
# else
#     usage
# fi

# echo -e "${YELLOW}**WARNING** Script contains hard coded file names/directories, update them before execution.${NC}"

# echo -n "Checking dependencies... "
# for dep in make bison flex; do
#     [[ $(which $dep 2>/dev/null) ]] || {
#         echo -en "\n${YELLOW}$dep needs to be installed${NC}. Use 'sudo apt-get install $dep'"
#         deps=1
#     }
# done
# [[ $deps -ne 1 ]] && echo "OK" || {
#     echo -en "\nInstall the above and rerun this script\n"
#     exit 1
# }

# echo -n "Checking cross compiler... "
# cc="$(${toolchain}gcc --version | head -n 1 | cut -d " " -f1)"
# currentver="$(${toolchain}gcc -dumpversion 2>/dev/null)"
# if [ "$currentver" == "" ]; then
#     echo -e "\n${YELLOW}Kindly check the toolchain path or update the script${NC}"
#     CC=1
# elif [ "$(printf '%s\n' "$cc")" != "$reqcc" ]; then
#     echo -e "\n${YELLOW}No Compatible Linux hosted cross compiler found.${NC}"
#     CC=1
# elif [ "$(printf '%s\n' "$requiredver" "$currentver" | sort -V | head -n1)" != "$requiredver" ]; then
#     echo -e "\n${YELLOW}Kindly update your cross compiler version to minimum $requiredver${NC}"
#     CC=1
# fi
# [[ $CC -ne 1 ]] && echo "OK" || {
#     echo -en "\nFix cross compiler and rerun this script\n"
#     exit 1
# }

# make distclean
# make mrproper

# # Deletes the existing dir, if present
# if [ -d $1 ]; then
#     echo "$1 already present, removing..."
#     rm -rf $1
# fi

exit $ES_SUCCESS