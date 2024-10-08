#!/sbin/sh

# functions:
function grep_prop() {
    [[ -z "$1" || -z "$2" || ! -f "$2" ]] && return 1
    grep -E "^$1=" "$2" | cut -d '=' -f2- | tr -d '"'
}

function amiMountedOrNot() {
    grep -q "$1" /proc/mounts
}

function unmountPartitions() {
    for partitions in system system_root vendor odm product prism optics; do
        amiMountedOrNot "${partitions}" && umount /${partitions}
    done
}

function debugPrint() {
    # stderr/debug/log message in magisk.
    echo "$1: $2" > /proc/self/fd/2
}

function consolePrint() {
    if [ "$1" == "--common" ]; then
        echo -e "ui_print $(grep_prop "$2" "/tmp/common.lang")\nui_print" > /proc/self/fd/1
    else
        echo -e "ui_print $@\nui_print" > /proc/self/fd/1
    fi
}

function abortInstance() {
    if [ "$1" == "--common" ]; then
        echo -e "ui_print $(grep_prop "$2" "/tmp/common.lang")\nui_print" > /proc/self/fd/2
    else
        echo -e "ui_print $@\nui_print" > /proc/self/fd/2
    fi
    unmountPartitions
    rm -rf /tmp/*
    exit 1
}

# Usage: getAromaProp <property> <property_file_name>
function getAromaProp() {
    local prop="$1"
    local propFileName="$2"
    cat ${propFileName} | grep ${prop} | cut -d '=' -f2 | xargs
}

# Usage: findActualBlock <block name, ex: system>
function findActualBlock() {
    local blockname="$1"
    local block
    for commonDeviceBlocks in /dev/block/bootdevice/by-name /dev/block/by-name /dev/block/platform/*/by-name; do
        [ ! -f "${commonDeviceBlocks}/${blockname}" ] && continue
        [ -f "${commonDeviceBlocks}/${blockname}" ] && block=$(readlink -f "${commonDeviceBlocks}/${blockname}");
        [ -z "${block}" ] || echo "${block}"
    done
}

# Usage: installImages <image file name in the zip, ex: system.img> <block name, ex: system>
function installImages() {
    local imageName="$1"
    local blockname="$2"
    local imageType="$3"
    case "${imageType}" in
        "sparse")
            unzip -o "${ZIPFILE}" "${imageName}" -d $IMAGES
            consolePrint "Trying to install ${imageName} to ${blockname}..."
            simg2img "${IMAGES}/${blockname}.img" $(findActualBlock "${blockname}") || abort "Failed to install ${imageName} to ${blockname}!"
            consolePrint "Successfully installed ${blockname}!"
            rm -rf ${IMAGES}/
        ;;
        "raw")
            consolePrint "Trying to install ${imageName} to ${blockname}..."
            unzip -o "${ZIPFILE}" "${imageName}" -d ${blockname} || abort "Failed to install ${imageName}!"
            consolePrint "Successfully installed ${blockname}!"
        ;;
    esac
}
# functions: