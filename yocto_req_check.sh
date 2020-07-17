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
k_RECOM_SPACE=120000000 # 120 GB in KB - RECOMmended SPACE in Ubuntu 
k_MIN_SPACE=50200000    # 50.2GB in KB - MINimum required SPACE
k_KB_TO_GB_CON=1000000  # Constant to convert KB to GB (KB/1000000)

# Dependiences of Yocto build
k_DEPEN_LIST=(
    gawk
    wget
    git
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
    repo
)

# Exit Status
ES_SUCCESS=0            # Success
ES_PERM_ERR=1           # PERMission ERRor
ES_VER_MM_ERR=2         # VERsion MisMatch ERRor
ES_NO_SPC_ERR=3         # NO SPaCe ERRor
ES_UNMET_DEPEN_ERR=4    # UNMET DEPENdencies ERRor

YW='\e[0;33m'   # Yellow
RD='\e[0;31m'   # Red
BI='\e[1;7m'    # Bold inverted
RS='\e[0m'      # Reset

ERR='\e[1;31mERROR\e[0m'    # Error dialog
WARN='\e[1;33mWARNING\e[0m' # Warning dialog
SUCS='\e[1;32mSUCCESS\e[0m' # Success dialog

# Check for root previlages
if [[ $EUID -ne 0 ]]; then
    echo -e "\n${ERR}: ${RD}Run the ${!#} as root${RS}\n"
    exit $ES_PERM_ERR
fi

# ping site to check internet connection
TEST_SITE=google.com

# Getting the static hostname of runtime
HOSTNAME=$(hostnamectl | grep -i "operating system" | cut -d' ' -f5-)

# Retrieving Operating System
echo -ne "\n${BI}Checking OS Compatibility...${RS} "
OS_NAME="$(echo $HOSTNAME | cut -d' ' -f1)"
if [ "$OS_NAME" = "Ubuntu" ]; then
    
    # Comparing major version
    if [ "$(echo $HOSTNAME | cut -d' ' -f2 | cut -d. -f1)" -lt $k_OS_MIN_VERSION ]; then
        echo -e "\n${ERR}: ${RD}The minimum supported $OS_NAME version is $k_OS_MIN_VERSION, but you're running on $HOSTNAME.${RS}\nKindly update your OS and try again.\n"
        exit $ES_VER_MM_ERR
    fi
    echo -e "${SUCS}"
else
    echo -e "\n${WARN}: ${YW}Kindly check at https://www.yoctoproject.org/docs/3.1/ref-manual/ref-manual.html#detailed-supported-distros for $OS_NAME support before proceed${RS}\n"
fi

# Getting available space in disk
available_space=$(df -Pk . | awk 'NR==2 {print $4}')

# Checking for minimum space requirements
echo -ne "\n${BI}Checking space requirements...${RS} "
if [ "$available_space" -lt $k_MIN_SPACE ]; then
    echo -e "\n${ERR}: ${RD}$(($k_MIN_SPACE/$k_KB_TO_GB_CON))GB is not available in current disk ($(df -Pk . | awk 'NR==2 {print $1}')) (available: $(($available_space/$k_KB_TO_GB_CON))GB)\nUpdate storage or try in different disk to proceed${RS}\n"
    exit $ES_NO_SPC_ERR
fi

echo -e "${SUCS}"
if [ "$available_space" -lt $k_RECOM_SPACE ]; then
    echo -e "\n${WARN}: ${YW}It is recommended to have $(($k_RECOM_SPACE/$k_KB_TO_GB_CON))GB for hassle free build, but $(($available_space/$k_KB_TO_GB_CON))GB is just sufficient.${RS}\n"
fi

update_dependencies() {

    # Checking & installing repo tool
    if [ "$(which repo)" = "" ]; then
        curl https://storage.googleapis.com/git-repo-downloads/repo > /usr/bin/repo
        chmod 755 /usr/bin/repo
    fi

    echo -ne "\n${BI}Checking dependencies...${RS} "

    update_depen=()
    for dependency in "${k_DEPEN_LIST[@]}"; do

        # Checking for dependencies
        dpkg -l | grep -w "$dependency" > /dev/null
        if [ $? -ne 0 ]; then
            # Filtering the dependiences to install
            update_depen+=( $dependency )
        fi
    done

    if [ "${#update_depen[@]}" -ne 0 ];then

        # Checking for internet connection
        if ping -q -c 1 -W 1 $TEST_SITE &> /dev/null; then
            echo -e "\n\n${BI}Installing dependencies...${RS}\n"
            apt update
            apt install -y "${update_depen[@]}"
            update_dependencies
        else
            echo -e "\n${ERR}: ${RD}No internet connection is available.\nUnable to update following dependencies:"
            for dependency in "${update_depen[@]}"; do
                echo $dependency
            done

            echo -e "${RS}Enable internet or manually install the dependencies to continue\n"
            exit $ES_UNMET_DEPEN_ERR
        fi
    else
        echo -e "${SUCS}\n"
        exit $ES_SUCCESS
    fi
}

update_dependencies

exit -1  # Program never should reach this point
