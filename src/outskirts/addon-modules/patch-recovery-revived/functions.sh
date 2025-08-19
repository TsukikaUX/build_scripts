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

# FUCC
shopt -s expand_aliases
set -e

# Function to get total number of patches
function get_patch_count() {
    echo ${#HEX_PATCHES[@]}
}

# Function to get a specific patch by index
function get_patch_by_index() {
    local index=$1
    [[ $index -ge 0 && $index -lt ${#HEX_PATCHES[@]} ]] && echo "${HEX_PATCHES[$index]}"
}

# Function to list all patches (for debugging)
function list_all_patches() {
    local i=0
    for patch in "${HEX_PATCHES[@]}"; do
        echo "[$i] $patch"
        ((i++))
    done
}

function extractRecoveryImage() {
    debugPrint "extractRecoveryImage(): Trying to extract given recovery image..."
    set +e
    cp -ar $expectedRecoveryFilePath $BOOT_EDITOR
    logInterpreter "Trying to unpack the recovery image.." "r_unpack" || abort "Failed to unpack the recovery image, please try again." "patch-recovery-revived:extractRecoveryImage()"
    # i guess ravindu is trying to extract the whole recovery by using that tool. MAGISKBOOT DOES THE J*B THO WTF????
    rm -rf ./local_build/custom_recovery_with_fastbootd/{base,ramdisk} &>/dev/null && mkdir -p ./local_build/custom_recovery_with_fastbootd/{base,ramdisk}
    {
        cd "./local_build/custom_recovery_with_fastbootd/base"
        magiskboot unpack -i $expectedRecoveryFilePath
        if [ ! -f "ramdisk.cpio" ]; then
            cd ..
            rm -rf ./* ../{base,ramdisk} &>/dev/null
            console_print "Cannot find ramdisk.cpio in the unpacked recovery image. This recovery image may not be compatible with this script."
        fi
        cd ../ramdisk
        magiskboot cpio ramdisk.cpio extract
        if [ ! -f "./system/bin/recovery" ]; then
            cd ..
            rm -rf ./* ../{base,ramdisk} &>/dev/null
            console_print "Cannot find recovery binary in the unpacked ramdisk. This recovery image may not be compatible with this script."
        fi
        if [ ! -f "./system/bin/fastbootd" ]; then
            cd ..
            rm -rf ./* ../{base,ramdisk} &>/dev/null
            console_print "Your recovery does not have a fastbootd binary. Patching would be useless. Aborting.."
        fi
        FASTBOOTD="$(realpath "../fastbootd")"
        export PATCHING_TARGET="$(realpath "../recovery")"
        rm -rf "../ramdisk"
    }
}

function apply_hex_patches() {
    local binary_file="$1"
    local patches_applied=0
    local total_patches=${#HEX_PATCHES[@]}
    
    # Temporarily disable exit on error for individual patch attempts
    console_print "Trying to apply hex patches to ${binary_file}..."
    set +e
    for patch in "${HEX_PATCHES[@]}"; do
        # Split the patch string into search and replace patterns
        local search_pattern="${patch%%:*}"
        local replace_pattern="${patch##*:}"
        debugPrint "apply_hex_patches(): Trying to apply patch: ${search_pattern} -> ${replace_pattern}"

        # Apply the patch and capture the exit code
        if magiskboot hexpatch "${binary_file}" "${search_pattern}" "${replace_pattern}"; then
            debugPrint "apply_hex_patches(): Patch applied successfully: ${search_pattern} -> ${replace_pattern}"
            ((patches_applied++))
        else
            debugPrint "apply_hex_patches(): Patch failed: ${search_pattern} -> ${replace_pattern}"
            warns "Failed to apply patch: ${search_pattern} -> ${replace_pattern}\n" "apply_hex_patches"
        fi
    done
    # Re-enable exit on error
    set -e
    console_print "Applied ${patches_applied}/${total_patches} patches\n"
    
    # Return success if at least one patch was applied
    [ $patches_applied -gt 0 ]
}

# Hex patch the "recovery" binary to get fastbootd mode back
function hexpatchRecoveryImage() {
    # Apply hex patches and check result
    apply_hex_patches "${expectedRecoveryFilePath}" || abort "Failed to apply hex patches to the recovery image, cannot continue." "patch-recovery-revived:hexpatchRecoveryImage()"
}

# Repack the fastbootd patched recovery image
function repackRecoveryImage() {
    {
        cd "./local_build/custom_recovery_with_fastbootd/base"
        # add MODE ENTRY INFILE
        magiskboot cpio ramdisk.cpio "add 0755 system/bin/fastbootd ${FASTBOOTD}"
        magiskboot cpio ramdisk.cpio "add 0755 system/bin/recovery ${PATCHING_TARGET}"
        magiskboot repack ${expectedRecoveryFilePath} ../patched-recovery.img
    }
}

function createTarFileWhenAsked() {
    if ask "Do you want to get a compressed tar for the patched recovery file?"; then
        lz4 -B6 --content-size ${patchedRecoveryFilePath} ${patchedRecoveryFilePath}.lz4 && rm ${patchedRecoveryFilePath}
        tar -cvf "Fastbootd-patched-recovery.tar" ${patchedRecoveryFilePath}.lz4 && rm ${patchedRecoveryFilePath}.lz4
        console_print "Created Fastbootd-patched-recovery.tar in the ${patchedRecoveryFilePath}"
    fi
}

function initPatchRecovery() {
    debugPrint "initPatchRecovery(): Initializing patch recovery module..."
    # Install the requirements for building the kernel when running the script for the first time
    yes | sudo apt update -y &>/dev/null
    yes | sudo apt install -y lz4 git device-tree-compiler lz4 xz-utils zlib1g-dev openjdk-17-jdk gcc g++ python3 python-is-python3 p7zip-full android-sdk-libsparse-utils erofs-utils &>/dev/null
}