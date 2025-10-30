#!/usr/bin/env bash
#
# Copyright (C) 2025 ぼっち <ayumi.aiko@outlook.com>
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
debugPrint "KnoxPatch: Module URL: $(grep_prop "baseModuleURL" "$1")"
source "$2"

# implement your own actions from here:
sudo cp "${modulePath}/${SYSTEM_BLOBS[1]}" "${SYSTEM_DIR}/etc/permissions/"
setprop --system wlan.wfd.hdcp disable
console_print "KnoxPatch: Trying to apply WSM fix.."
for i in ${SYSTEM_DIR}/lib*/libhal.wsm.samsung.so; do
	[ -f "${i}" ] || continue
	sudo touch "${i}" && console_print "KnoxPatch: Finished applying WSM fix to ${i}..." || abort "Failed to apply WSM fix to ${i}" "KnoxPatch"
done

# copy that xml for that LSPosed module thing
verify256Checksum "${modulePath}/${SYSTEM_BLOBS[1]}" "${modulePath}/${SYSTEM_BLOBS_CHECKSUM[1]}" || \
	abort "Checksum of ${SYSTEM_BLOBS[1]} doesn't match, please clone this repo again." "KnoxPatch"

# copy blobs, patch em' and finish the j*b
# RESTORE ORIGINAL VOLD IF PATCHED AND STORED AS .bak ALREADY!
if [ -f "${SYSTEM_DIR}/bin/vold.bak" ]; then
    mv -f "${SYSTEM_DIR}/bin/vold.bak" "${SYSTEM_DIR}/bin/vold"
    [ -f "${SYSTEM_DIR}/lib/libepm.so.bak" ] && mv -f "${SYSTEM_DIR}/lib/libepm.so.bak" "${SYSTEM_DIR}/lib/libepm.so"
    [ -f "${SYSTEM_DIR}/lib64/libepm.so.bak" ] && mv -f "${SYSTEM_DIR}/lib64/libepm.so.bak" "${SYSTEM_DIR}/lib64/libepm.so"
	console_print "KnoxPatch: Restored original vold and epm blobs."
	exit 0
elif [[ "$BUILD_TARGET_SDK_VERSION" == "29" || "$BUILD_TARGET_SDK_VERSION" == "30" ]]; then
    if grep -q 'fileencryption' ${VENDOR_DIR}/etc/fstab.*; then
        if grep -q 'Knox protection required' ${SYSTEM_DIR}/bin/vold; then
            console_print "KnoxPatch: Trying to apply Secure Folder fix..."
            cp --preserve=all "${SYSTEM_DIR}/bin/vold" "${SYSTEM_DIR}/bin/vold.bak"
            PATCHED=false
            for i in "00e4006fea861a11 00e4006feabe0451" "08fa805200e4006f 0800805200e4006f" "08fa80520800ae72 080080520800ae72s" "09fa80520900ae72 090080520900ae72"; do
                magiskboot hexpatch "${SYSTEM_DIR}/bin/vold" "$(echo $i | awk '{print $1}')" "$(echo $i | awk '{print $2}')" && PATCHED=true
            done
            $PATCHED && console_print "KnoxPatch: Applied Secure Folder fix" || abort "Failed to apply patch" "KnoxPatch"
            setPerm "${SYSTEM_DIR}/bin/vold" 0 2000 0755 "u:object_r:vold_exec:s0"
        else
            console_print "KnoxPatch: No patches required for secure folder in this device."
        fi
    elif [[ "$BUILD_TARGET_SDK_VERSION" == "29" && "${BUILD_TARGET_ARCH}" == "ARM64" ]]; then
		if grep -q 'Device supports FBE!' /system/lib/libepm.so; then
			console_print "KnoxPatch: Trying to apply Secure Folder fix..."
			mv "${SYSTEM_DIR}/bin/vold" "${SYSTEM_DIR}/bin/vold.bak"
			verify256Checksum "${modulePath}/${SYSTEM_BLOBS[0]}" "${modulePath}/${SYSTEM_BLOBS_CHECKSUM[0]}" || abort "Checksum of ${SYSTEM_BLOBS[0]} doesn't match, please clone this repo again." "KnoxPatch"
			sudo cp -af "${modulePath}/${SYSTEM_BLOBS[0]}" "${SYSTEM_DIR}/bin/vold"
			setPerm "/system/bin/vold" 0 2000 0755 "u:object_r:vold_exec:s0"
			for i in "${modulePath}/${SYSTEM_BLOBS[2]}" "${modulePath}/${SYSTEM_BLOBS[3]}"; do 
				[ -f "${i}" ] || continue
				# BACK IT UP BEFORE COPYING IT!
				if echo "$i" | grep lib64; then
					verify256Checksum "${i}" "${modulePath}/${SYSTEM_BLOBS_CHECKSUM[3]}" || \
						abort "Checksum of ${SYSTEM_BLOBS[3]} doesn't match, please clone this repo again." "KnoxPatch"
					sudo mv "${SYSTEM_DIR}/lib64/$(basename $i)" "${SYSTEM_DIR}/lib64/$(basename $i).bak"
					copyDeviceBlobsSafely "${i}" "${SYSTEM_DIR}/lib64"
				else	
					verify256Checksum "${i}" "${modulePath}/${SYSTEM_BLOBS_CHECKSUM[2]}" || \
						abort "Checksum of ${SYSTEM_BLOBS[2]} doesn't match, please clone this repo again." "KnoxPatch"
					sudo mv "${SYSTEM_DIR}/lib/$(basename $i)" "${SYSTEM_DIR}/lib/$(basename $i).bak"
					copyDeviceBlobsSafely "${i}" "${SYSTEM_DIR}/lib"
				fi
				setPerm "${i}" 0 0 0644
			done
		else
			console_print "KnoxPatch: No patches required for secure folder in this device"
		fi
    fi
fi