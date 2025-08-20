#!/usr/bin/env bash
#
# Copyright (C) 2025 愛子あゆみ <ayumi.aiko@outlook.com>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

# COMMON
console_print "$(grep_prop "name" "$1")"
console_print "Made by: $(grep_prop "author" "$1")"
console_print "Based on: v$(grep_prop "version" "$1") | $(grep_prop "source" "$1")"
console_print "License Template: v$(grep_prop "license" "$1")"
debugPrint "PatchRecoveryRevived: Module URL: $(grep_prop "baseModuleURL" "$1")"
console_print "Trying to unpack the recovery image.."

# elite ball knowledge. I dont usually put comments but i thought i think i REALLY need to do that here.

# variables:
export expectedRecoveryFilePath="$(realpath ./local_build/etc/extract/recovery.img)"
export patchedRecoveryFilePath="$(realpath ./local_build/custom_recovery_with_fastbootd/patched-recovery.img)"

# check the daawn var vals
if [ ! -f $expectedRecoveryFilePath ]; then
    expectedRecoveryFilePath="${BUILD_TARGET_RECOVERY_IMAGE_PATH}"
    [ -z "${expectedRecoveryFilePath}" ] && abort "The expected recovery image path is not set. Please set the BUILD_TARGET_RECOVERY_IMAGE_PATH variable." "patch-recovery-revived:customize.sh"
fi

# check if the expected file is available or not.
[ -f "${expectedRecoveryFilePath}" ] && console_print "Recovery image found at: ${expectedRecoveryFilePath}" || \
    abort "Expected recovery image not found at: ${expectedRecoveryFilePath}" "patch-recovery-revived:customize.sh"

# we need a temporary working dir and we need to switch it to the module directory AFTER running inside "scope"
# firstScope:
{
    # initial scope setup fuckery
    export thisConsoleTempLogFile="$(mktemp)"
    zapzapzapzap=$thisConsoleTempLogFile
    rm -rf "./local_build/custom_recovery_with_fastbootd/base" &>/dev/null || mkdir -p ./local_build/custom_recovery_with_fastbootd/base
    cd ./local_build/custom_recovery_with_fastbootd/base
    logInterpreter "Trying to unpack the recovery image with magiskboot.." "magiskboot unpack -h ${expectedRecoveryFilePath}" && \
        debugPrint "patch-recovery-revived:firstScope:customize.sh" || abort "Failed to unpack the given recovery image.." "patch-recovery-revived:firstScope:customize.sh"
    [ ! -f "ramdisk.cpio" ] && abort "Cannot find ramdisk.cpio in the unpacked recovery image. This recovery image may not be compatible with this script." "patch-recovery-revived:firstScope:customize.sh"
    
    # verify if the files are present or not in the ramdisk before being a moron and fucking the recovery image up.
    magiskboot cpio "./ramdisk.cpio" "exists system/bin/recovery" || abort "The \'recovery\' binary was not present in the ramdisk from the recovery? weird image, try again with an actual image." "patch-recovery-revived:firstScope:customize.sh"
    magiskboot cpio "./ramdisk.cpio" "exists system/bin/fastbootd" || abort "This recovery image doesn't natively have fastboot binaries, please try again with a supported recovery image." "patch-recovery-revived:firstScope:customize.sh"
    
    # now extract it and be a bitch
    console_print "Trying to extract the recovery binary file from the ramdisk.."
    magiskboot cpio "./ramdisk.cpio" "extract system/bin/recovery" && console_print "Successfully extracted the recovery & fastbootd binaries from the recovery ramdisk." || \
        abort "Failed to extract the recovery binary from the ramdisk, please try again." "patch-recovery-revived:firstScope:customize.sh"
    applyHexPatches "./system/bin/recovery"
    magiskboot cpio ./ramdisk.cpio "add 0755 system/bin/recovery ./recovery" &>$thisConsoleTempLogFile || abort "Failed to add the patched recovery binary into the recovery image, please try again." "patch-recovery-revived:firstScope:customize.sh"
    magiskboot repack "${expectedRecoveryFilePath}" "${patchedRecoveryFilePath}" &>$thisConsoleTempLogFile || \
        abort "Failed to repack the recovery image, please try again." "patch-recovery-revived:firstScope:customize.sh"
    console_print "Successfully repacked the recovery image with the patched recovery binary."
    console_print "The patched recovery image is available at: ${patchedRecoveryFilePath}"
}

# out:
export thisConsoleTempLogFile="./local_build/logs/tsuki_build.log"
cat "${zapzapzapzap}" >> "${thisConsoleTempLogFile}" 
rm -rf ${zapzapzapzap}
if ask "Do you want to get a compressed tar for the patched recovery file?"; then
    lz4 -B6 --content-size ${patchedRecoveryFilePath} ${patchedRecoveryFilePath}.lz4 && rm ${patchedRecoveryFilePath} &>/dev/null || \
        abort "Failed to compress the patched recovery image, please try again." "patch-recovery-revived:out:customize.sh"
    console_print "Successfully compressed the patched recovery image to: ${patchedRecoveryFilePath}.lz4"
    # create a tar file
    tar -cvf "Fastbootd-patched-recovery.tar" ${patchedRecoveryFilePath}.lz4 && rm ${patchedRecoveryFilePath}.lz4 &>/dev/null || \
        abort "Failed to create a tar file for the patched recovery image, please try again." "patch-recovery-revived:out:customize.sh"
    console_print "Created Fastbootd-patched-recovery.tar in the ${patchedRecoveryFilePath}"
fi