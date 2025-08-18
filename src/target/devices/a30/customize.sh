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

# device blob path and etc...
BUILD_TARGET_BLOB_PATH="./src/target/devices/a30/stock_blobs"
stockCameraLibPath="${VENDOR_DIR}/lib/libexynoscamera3.so"
selected_lib="$BUILD_TARGET_BLOB_PATH/vendor/lib/libexynoscamera3_apr17.so"
REGEX="^(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec) (([[:digit:]]| )[[:digit:]]) ([[:digit:]][[:digit:]][[:digit:]][[:digit:]])$"
declare -A months=(
    [Jan]="01" [Feb]="02" [Mar]="03" [Apr]="04"
    [May]="05" [Jun]="06" [Jul]="07" [Aug]="08"
    [Sep]="09" [Oct]="10" [Nov]="11" [Dec]="12"
)

if [[ "$(grep_prop "ro.product.vendor.device" "$TSUKIKA_VENDOR_PROPERTY_FILE")" == *"a30"* && -f "${VENDOR_DIR}/etc/fstab.exynos7904" ]]; then
    console_print "Customizing experience for your Galaxy A30..."
    if ! grep -q f2fs ${VENDOR_DIR}/etc/fstab.exynos7904; then
        console_print "Vendor doesn't have f2fs mount configuaration, trying to add it..."
        echo -e "\n\n# ${BUILD_USERNAME} - ${BUILD_TARGET_CUSTOM_BRAND_NAME}\n/dev/block/platform/13500000.dwmmc0/by-name/cache /cache f2fs nosuid,nodev,noatime,inline_xattr wait,check,formattable\n/dev/block/platform/13500000.dwmmc0/by-name/userdata /data f2fs nosuid,nodev,noatime,inline_xattr,data_flush,fsync_mode=nobarrier latemount,wait,check,encryptable=footer,quota" >> ${VENDOR_DIR}/etc/fstab.exynos7904 && console_print "Added F2FS mount flags, you may now convert your data partition to F2FS" || warns "Failed to add F2FS mount flag, you CANNOT boot the rom without F2FS flags in your ROM if your data and cache is in F2FS" "customize.sh:device"
    fi
    setprop --custom "${VENDOR_DIR}/default.prop" "log.tag.stats_log" "D"
    setprop --custom "${VENDOR_DIR}/default.prop" "persist.sys.usb.config" "mtp,adb"
    [ "${BUILD_TARGET_REPLACE_REQUIRED_PROPERTIES}" == "true" ] && replaceTargetBuildProperties "a30"
    if [ "${BUILD_TARGET_ADD_PATCHED_CAMERA_LIBRARY_FILE}" == "true" ]; then
        console_print "Copying pre-patched camera library file for \"RAW\" support..."
        if [ -z "$(grep_prop "ro.vendor.build.date.utc" "$TSUKIKA_VENDOR_PROPERTY_FILE")" ]; then
            lib_date=$(strings $stockCameraLibPath | grep -o -E "$REGEX")
            year=${lib_date: -4}
            month_abbr=${lib_date:0:3}
            month="${months[$month_abbr]}"
            day=${lib_date:4:2}
            day="${day/ /0}"
            timestamp=$(date -d "$year-$month-$day" +%s)
        fi
        [ "$timestamp" -gt 1630458000 ] && selected_lib="$BUILD_TARGET_BLOB_PATH/vendor/lib/libexynoscamera3_oct15.so"
        [ -z $timestamp ] && warns "Failed to get timestamp from libexynoscamera3.so, please check the file." "timestampFromLib()" || \
            copyDeviceBlobsSafely "$selected_lib" "$stockCameraLibPath" && debugPrint "customize.sh:device: Added libraries for raw support." || debugPrint "customize.sh:device: Failed to add libraries for raw support."
    fi
    if [ "${BUILD_TARGET_ADD_FRAMEWORK_OVERLAY_TO_FIX_CUTOUT}" == "true" ]; then 
        console_print "Trying to build framework overlay app for applying device cutout fix..."
        buildAndSignThePackage "./target/devices/a30/android_overlay/framework-res/" "${VENDOR_DIR}/overlay/" && console_print "Successfully built framework overlay app for applying device cutout fix." || warns "Failed to build framework overlay app for applying device cutout fix, please check the log." "customize.sh:device"
    fi
else
    warns "Unknown device, cannot proceed with the customization" "customize.sh:device"
fi