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

# misc variables
BUILD_USERNAME="$2"
[ -z "${BUILD_USERNAME}" ] && BUILD_USERNAME="$(tr '[:lower:]' '[:upper:]' <<< "$(id -un | cut -c1-1)")$(id -un | cut -c2-)"
sudo rm -rf ./local_build/logs/*
TMPDIR="$(mktemp -d)"
TMPFILE="$(mktemp)"
argOne="$1"
# no need to worry cuz it checks the uuid and everything before build.
# if it fails to match with the previous uuid, it considers the package as new.
[[ -f "./local_build/etc/FirmwareZipDownloadedWithoutErrors" && -f "./local_build/etc/downloadedContents/firmware.zip" ]] && argOne="./local_build/etc/downloadedContents/firmware.zip"
loggedFloatingFeaturePATH="no"
quotes=(
	"We are not what we know but what we are willing to learn."
	"Good people are good because they've come to wisdom through failure."
	"Your word is a lamp for my feet, a light for my path."
	"The first problem for all of us, men and women, is not to learn, but to unlearn."
)
randomQuote="${quotes[$RANDOM % ${#quotes[@]}]}"
BUILD_START_TIME=$(date +%s)
sameOldFirmwarePackage=false
TSUKIKA_BUILD_NUMBER=$(date +%Y%m%d)

# Trap the SIGINT signal (Ctrl+C) and call handle_sigint when it's caught
trap 'abort "Aborting the build....."' SIGINT

# jst execve ts 2 fix bugs:
for i in ./src/misc/build_scripts/util_functions.sh ./src/makeconfigs.prop ./src/monika.conf; do
	if [ ! -f "$i" ]; then
		echo -e "\e[0;31mCan't find $i file, please try again later...\e[0;37m"
		sleep 0.5
		exit 1
	else
		debugPrint "build.sh: Executing ${i}.."
		source "$i"
	fi
done

# ok, fbans dropped!
for dependenciesRequiredForTheBuild in java python3 zip lz4 tar file unzip simg2img make xmlstarlet mkfs.erofs aria2c openssl; do
	command -v "${dependenciesRequiredForTheBuild}" &>/dev/null || abort "${dependenciesRequiredForTheBuild} is not found in the build environment, please check the guide again.."
done

# mkdir:
for i in system/product/priv-app system/product/etc system/product/overlay \
		system/etc/permissions system/product/etc/permissions custom_recovery_with_fastbootd/ \
		system/etc/init/ tmp/tsuki/ etc/extract/super_extract etc/imageSetup/product etc/imageSetup/system etc/imageSetup/vendor etc/imageSetup/optics etc/downloadedContents \
		etc/buildedContents etc/buildNInfo; do
			mkdir -p "./local_build/$i"
			debugPrint "build.sh: Making ./local_build/${i} directory.."
done

# TODO: export this to call binaries without having to deal with wrong paths and stuff.
export PATH="$PATH:$(dirname "$(realpath "$0")")/src/dependencies/bin"

# bruh
sleep 5
clear
echo -e "\033[0;31m╔─────────────────────────────────────────────────────╗
│████████╗███████╗██╗   ██╗██╗  ██╗██╗██╗  ██╗ █████╗ │
│╚══██╔══╝██╔════╝██║   ██║██║ ██╔╝██║██║ ██╔╝██╔══██╗│
│   ██║   ███████╗██║   ██║█████╔╝ ██║█████╔╝ ███████║│
│   ██║   ╚════██║██║   ██║██╔═██╗ ██║██╔═██╗ ██╔══██║│
│   ██║   ███████║╚██████╔╝██║  ██╗██║██║  ██╗██║  ██║│
│   ╚═╝   ╚══════╝ ╚═════╝ ╚═╝  ╚═╝╚═╝╚═╝  ╚═╝╚═╝  ╚═╝│
╚─────────────────────────────────────────────────────╝\033[0m"
for ((i = 0; i <= $(echo "$randomQuote" | wc -c); i++)); do printf "#"; done
echo -e "\n$randomQuote"
for ((i = 0; i <= $(echo "$randomQuote" | wc -c); i++)); do printf "#"; done
echo ""
compareDefaultMakeConfigs
console_print "Starting to build Tsukika - ${CODENAME} on ${BUILD_USERNAME}'s computer..."
console_print "Build started at $(date +%I:%M%p) on $(date +%d\ %B\ %Y)"

# sets sameOldFirmwarePackage to "true" to skip some extraction steps.
[ "$(unzip -p "$argOne" ".uuid" 2>/dev/null)" == "$(grep_prop "previousBuildZipUUID" "./local_build/etc/buildNInfo/build.prop" 2>/dev/null)" ] && sameOldFirmwarePackage="true"

# check:
if [ -n "$argOne" ]; then
	if stringFormat --lower "$(file $argOne)" | grep -q zip; then
		if unzip -l "$argOne" | grep -qE "AP_|HOME_CSC"; then
			# skip extracting if the archives were found.
			if [[ -f "$(echo -e ./local_build/etc/extract/AP_*.tar.md5)" && -f "$(echo -e ./local_build/etc/extract/HOME_CSC_*.tar.md5)" && "${sameOldFirmwarePackage}" == "true" ]]; then
				console_print "Skipping firmware extraction, target firmware files are already extracted and saved."
				extractedAPFilePath="$(echo -e ./local_build/etc/extract/AP_*.tar.md5)"
				extractedHomeCSCFilePath="$(echo -e ./local_build/etc/extract/HOME_CSC_*.tar.md5)"
			elif [[ "$(grep_prop "buildExtractedStuff_archive" "./local_build/etc/buildNInfo/build.prop")" == "HOME_CSC" && "${sameOldFirmwarePackage}" == "true" ]]; then
				console_print "Previous build was forcefully closed for some reason, extracting HOME_CSC again..."
				extractedAPFilePath="$(echo -e ./local_build/etc/extract/AP_*.tar.md5)"
				extractedHomeCSCFilePath="$(unzip -o $argOne $(unzip -l $argOne | grep HOME_CSC | awk '{print $4}') -d ./local_build/etc/extract/ | grep inflating | awk '{print $2}')"
				[ -z "${extractedHomeCSCFilePath}" ] && abort "Failed to extract HOME_CSC from $argOne" "build.sh"
			elif [[ -f "./localFirmwareBuildPending" && "${sameOldFirmwarePackage}" == "true" ]]; then
				for COMMON_FIRMWARE_BLOCKS in ./local_build/etc/extract/super_extract/*.img; do
					echo "$(basename "${COMMON_FIRMWARE_BLOCKS}" .img)" | grep -qE "system|vendor|product" || continue
					mountPath="./local_build/etc/imageSetup/$(basename ${COMMON_FIRMWARE_BLOCKS} .img)"
					mkdir -p "${mountPath}"
					if stringFormat -l "$(file "${COMMON_FIRMWARE_BLOCKS}")" | grep -q "sparse"; then
						simg2img "${COMMON_FIRMWARE_BLOCKS}" "${COMMON_FIRMWARE_BLOCKS}_rawFactor" &>/dev/null || abort "Failed to convert $(basename ${COMMON_FIRMWARE_BLOCKS} .img) into an raw image, please try again later.."
						sudo rm -rf "${COMMON_FIRMWARE_BLOCKS}"
						sudo mv "${COMMON_FIRMWARE_BLOCKS}_rawFactor" "${COMMON_FIRMWARE_BLOCKS}"
					fi
					setupLocalImage "${COMMON_FIRMWARE_BLOCKS}" "${mountPath}"
				done
				for images in ./local_build/etc/extract/*.img; do
					echo $images | grep -qE "system|vendor|product|optics" || continue
					console_print "Setting up previous iteration.."
					logInterpreter "Trying to extract ${images}.img from an LZ4 archive..." "lz4 -d ./local_build/etc/extract/${images}.img.lz4 ./local_build/etc/extract/${images}.img" || abort "Failed to extract $images from an lz4 archive." "build.sh"
					sudo rm -rf ./local_build/etc/extract/${images}.img.lz4
					logInterpreter "Converting $images from sparse to raw image factor...." "simg2img ./local_build/etc/extract/${images}.img ./local_build/etc/extract/${images}_raw.img"
					sudo rm ./local_build/etc/extract/${images}.img
					sudo mv ./local_build/etc/extract/${images}_raw.img ./local_build/etc/extract/${images}.img
					setupLocalImage ./local_build/etc/extract/${images}.img ./local_build/etc/imageSetup/${images}
				done
			else
				# generate a uuid value to identify a file:
				logInterpreter "Trying to generate a uuid hash for $argOne" "uuidgen > .uuid" || abort "Failed to generate uuid hash for the zip file? check if uuidgen exists or not."
				zip -q "$argOne" -j ".uuid" || abort "Failed to add uuid hash into the $argOne file."
				setprop --custom "./local_build/etc/buildNInfo/build.prop" "previousBuildZipUUID" "$(cat .uuid)"
				sudo rm .uuid
				# unzip -o test.zip nos/README_Kernel.txt -d nos | grep inflating | awk '{print $2}'
				[[ "$(grep_prop "buildExtractedStuff_archive" "./local_build/etc/buildNInfo/build.prop")" == "AP" && "${sameOldFirmwarePackage}" == "true" ]] && console_print "Previous build was forcefully closed for some reason, extracting everything again..."
				console_print "Trying to extract $(unzip -l $argOne | grep AP_ | awk '{print $4}') from the archive...."
				extractedAPFilePath=$(setprop --custom "./local_build/etc/buildNInfo/build.prop" "buildExtractedStuff_archive" "AP"; unzip -o $argOne $(unzip -l $argOne | grep AP_ | awk '{print $4}') -d ./local_build/etc/extract/ | grep inflating | awk '{print $2}')
				[ -z "${extractedAPFilePath}" ] && abort "Failed to extract AP from $argOne" "build.sh"
				debugPrint "Processing AP tar file from the given firmware package...."
				tar -tf "$extractedAPFilePath" | grep -qE "system|super|vendor|optics" || abort "The $extractedAPFilePath doesn't have system, vendor, optics or even super. Try again with a samfw.com dump!" "build.sh"
				console_print "Trying to extract $(unzip -l $argOne | grep HOME_CSC | awk '{print $4}') from the archive...."
				extractedHomeCSCFilePath=$(setprop --custom "./local_build/etc/buildNInfo/build.prop" "buildExtractedStuff_archive" "HOME_CSC"; unzip -o $argOne $(unzip -l $argOne | grep HOME_CSC | awk '{print $4}') -d ./local_build/etc/extract/ | grep inflating | awk '{print $2}')
				[ -z "${extractedHomeCSCFilePath}" ] && abort "Failed to extract HOME_CSC from $argOne" "build.sh"
			fi
			# ight, so, basically even if we have both of these on our firmware, wwe dont need to worry cuz ive made sure that CSC features sets to omc/*/conf/cscfeature.xml
			# like product/omc/*/conf/cscfeature.xml and optics/omc/*/conf/cscfeature.xml *ONLY* if that XML file was found!
			for cscStuff in product optics; do
				tar -tf "$extractedHomeCSCFilePath" | grep -q "${cscStuff}.img.lz4" || continue
				console_print "Extracting ${cscStuff}..."
				tar -C ./local_build/etc/extract/ -xf $extractedHomeCSCFilePath ${cscStuff}.img.lz4 &>> ${thisConsoleTempLogFile}
				logInterpreter "Trying to extract ${cscStuff}.img from an LZ4 archive..." "lz4 -d ./local_build/etc/extract/${cscStuff}.img.lz4 ./local_build/etc/extract/${cscStuff}.img" || abort "Failed to extract $cscStuff from an lz4 archive." "logInterpreter"
				sudo rm -rf ./local_build/etc/extract/${cscStuff}.img.lz4
				# TODO: convert images into raw if not already:
				logInterpreter "Converting $cscStuff from sparse to raw image factor...." "simg2img ./local_build/etc/extract/${cscStuff}.img ./local_build/etc/extract/${cscStuff}_raw.img"
				sudo rm ./local_build/etc/extract/${cscStuff}.img
				sudo mv ./local_build/etc/extract/${cscStuff}_raw.img ./local_build/etc/extract/${cscStuff}.img
				setupLocalImage ./local_build/etc/extract/${cscStuff}.img ./local_build/etc/imageSetup/${cscStuff}
			done
			for androidOS in super system vendor; do
				if [ "${androidOS}" == "super" ]; then
					tar -tf "$extractedAPFilePath" | grep -q "super.img.lz4" || continue
					if [ ! -f "./local_build/lpunpack_and_lpmake" ]; then
						checkInternetConnection &>/dev/null || abort "Please proceed with an active internet connection to build LonelyFool's lptools from source."
						cd ./local_build/
						branchToFork=android10
						ask "Your build SDK version is above or equal to 30 right?" && branchToFork=android11
						git clone --branch $branchToFork "https://github.com/LonelyFool/lpunpack_and_lpmake.git"
						cd lpunpack_and_lpmake
						chmod +x ./make.sh
						console_print "Building LonelyFool's lptools from source, this might take sometime..."
						console_print "This is a one time build, future builds won't rebuild the tool or require internet connection to build."
						./make.sh &>/dev/null || abort "Failed to build lptools, please try again.." "build.sh"
						cd ../
						# we are outside local_build
						sudo mv ./local_build/lpunpack_and_lpmake/bin/* ./src/dependencies/bin/
					fi
					console_print "Extracting super..."
					tar -C "./local_build/etc/extract/" -xf "$extractedAPFilePath" "super.img.lz4" &>> ${thisConsoleTempLogFile} || abort "Failed to extract super.img.lz4 from the tar file." "build.sh"
					logInterpreter "Trying to extract super.img from an LZ4 archive..." "lz4 -d ./local_build/etc/extract/super.img.lz4 ./local_build/etc/extract/" || abort "Failed to extract super image from an lz4 archive." "build.sh"
					sudo rm -rf ./local_build/etc/extract/super.img.lz4
					lpdump "./local_build/etc/extract/super.img" > ./local_build/etc/dumpOfTheSuperBlock &>>$thisConsoleTempLogFile || abort "Failed to dump metadata from super.img" "build.sh"
					lpunpack "./local_build/etc/extract/super.img" "./local_build/etc/extract/super_extract/" &>>$thisConsoleTempLogFile || abort "Failed to unpack super.img" "build.sh"
					for COMMON_FIRMWARE_BLOCKS in ./local_build/etc/extract/super_extract/*.img; do 
						echo "$(basename "${COMMON_FIRMWARE_BLOCKS}" .img)" | grep -qE "system|vendor|product" || continue
						mountPath="./local_build/etc/imageSetup/$(basename ${COMMON_FIRMWARE_BLOCKS} .img)"
						# TODO: convert images into raw if required:
						# i dont think super would have an raw image inside it, because for whatever reason i decided it 
						# would be a great idea to do such thing as below:
						if stringFormat -l "$(file "${COMMON_FIRMWARE_BLOCKS}")" | grep -q "sparse"; then
							simg2img "${COMMON_FIRMWARE_BLOCKS}" "${COMMON_FIRMWARE_BLOCKS}_rawFactor" &>/dev/null || abort "Failed to convert $(basename ${COMMON_FIRMWARE_BLOCKS} .img) into an raw image, please try again later.."
							sudo rm -rf "${COMMON_FIRMWARE_BLOCKS}"
							sudo mv "${COMMON_FIRMWARE_BLOCKS}_rawFactor" "${COMMON_FIRMWARE_BLOCKS}"
						fi
						setupLocalImage "${COMMON_FIRMWARE_BLOCKS}" "${mountPath}"
					done
					break
				else
					console_print "Extracting $androidOS..."
					tar -tf "$extractedAPFilePath" | grep -q "${androidOS}.img.lz4" && tar -C ./local_build/etc/extract -xf $extractedAPFilePath ${androidOS}.img.lz4 &>> ${thisConsoleTempLogFile} || abort "Failed to extract $androidOS from an tar file." "build.sh"
					logInterpreter "Trying to extract ${androidOS}.img from an LZ4 archive..." "lz4 -d ./local_build/etc/extract/${androidOS}.img.lz4 ./local_build/etc/extract/${androidOS}.img" || abort "Failed to extract $androidOS from an lz4 archive." "build.sh"
					sudo rm -rf ./local_build/etc/extract/${androidOS}.img.lz4
					# TODO: convert images into raw if not already:
					logInterpreter "Converting $androidOS from sparse to raw image factor...." "simg2img ./local_build/etc/extract/${androidOS}.img ./local_build/etc/extract/${androidOS}_raw.img"
					rm ./local_build/etc/extract/${androidOS}.img
					sudo mv ./local_build/etc/extract/${androidOS}_raw.img ./local_build/etc/extract/${androidOS}.img
					setupLocalImage ./local_build/etc/extract/${androidOS}.img ./local_build/etc/imageSetup/${androidOS}
				fi
			done
			if [[ "$BUILD_TARGET_INCLUDE_FASTBOOTD_PATCH" == "true" || "$BUILD_TARGET_ENABLE_DISPLAY_OVERCLOCKING" == "true" ]]; then
				for patchableImages in recovery.img.lz4 dtbo.img.lz4; do
					tar -C ./local_build/etc/extract "${extractedAPFilePath}" "${patchableImages}" &>>${thisConsoleTempLogFile} || abort "Failed to extract ${patchableImages} from the archive." "build.sh"
					logInterpreter "Trying to extract $(basename ${patchableImages} .lz4) from an LZ4 archive..." "lz4 -d ./local_build/etc/extract/dtbo.img.lz4 ./local_build/etc/extract/$(basename ${patchableImages} .lz4)" || abort "Failed to extract $(basename ${patchableImages} .img.lz4) image from an lz4 archive." "build.sh"
				done
				# to update the file path:
				for propertyFiles in ./src/genericTargetProperties.conf ./src/target/*/buildTargetProperties.conf; do
					[ -f "${propertyFiles}" ] || continue
					setprop --custom "./local_build/etc/buildNInfo/build.prop" "${propertyFiles}" "BUILD_TARGET_DTBO_IMAGE_PATH" "./local_build/etc/extract/dtbo.img"
					setprop --custom "./local_build/etc/buildNInfo/build.prop" "${propertyFiles}" "BUILD_TARGET_RECOVERY_IMAGE_PATH" "./local_build/etc/extract/recovery.img"
				done
			fi
			# TODO: switch to device config if the ro.product.system.device is supported
			# source the props again to replace the values.
			source "./src/makeconfigs.prop"
			touch ./localFirmwareBuildPending
		elif echo "$argOne" | grep -qE "samfw|samfwpremium"; then
			checkInternetConnection &>/dev/null || abort "I don't have internet access to download given samfw firmware package." "build.sh"
			downloadRequestedFile "${argOne}" "./local_build/etc/downloadedContents/firmware.zip" && touch ./local_build/etc/FirmwareZipDownloadedWithoutErrors
			# re-exec because we alr have code to manage with zip files.
			./src/build.sh "./local_build/etc/downloadedContents/firmware.zip"
		fi
	fi
else
	# TODO: Check system,vendor before modding stuffs:
	[[ -f "${SYSTEM_DIR}/build.prop" && -f "${VENDOR_DIR}/build.prop" ]] || abort "System or vendor partition is not a valid partition!" "build.sh"
fi

# Locate build.prop files
TSUKIKA_PRODUCT_PROPERTY_FILE="$(checkBuildProp "${PRODUCT_DIR}")"
TSUKIKA_SYSTEM_PROPERTY_FILE="$(checkBuildProp "${SYSTEM_DIR}")"
TSUKIKA_SYSTEM_EXT_PROPERTY_FILE="$(checkBuildProp "${SYSTEM_EXT_DIR}")"
TSUKIKA_VENDOR_PROPERTY_FILE="$(checkBuildProp "${VENDOR_DIR}")"

# Locate overlay paths
if [ -d "${PRODUCT_DIR}/overlay" ]; then
    TSUKIKA_PRODUCT_OVERLAY="${PRODUCT_DIR}/overlay"
elif [ -d "${SYSTEM_DIR}/product/overlay" ]; then
    TSUKIKA_PRODUCT_OVERLAY="${SYSTEM_DIR}/product/overlay"
fi
TSUKIKA_VENDOR_OVERLAY="${VENDOR_DIR}/overlay"
TSUKIKA_FALLBACK_OVERLAY_PATH=$([ -d "${TSUKIKA_PRODUCT_OVERLAY}" ] && echo "${TSUKIKA_PRODUCT_OVERLAY}" || echo "${TSUKIKA_VENDOR_OVERLAY}")

# fix: "grep: /build.prop: No such file or directory" moved to build.sh to fix that error.
BUILD_TARGET_ANDROID_VERSION=$(grep_prop "ro.build.version.release" "${TSUKIKA_SYSTEM_PROPERTY_FILE}")
BUILD_TARGET_SDK_VERSION=$(grep_prop "ro.build.version.sdk" "${TSUKIKA_SYSTEM_PROPERTY_FILE}")
BUILD_TARGET_VENDOR_SDK_VERSION=$(grep_prop "ro.vndk.version" "${TSUKIKA_VENDOR_PROPERTY_FILE}")
BUILD_TARGET_MODEL="$(grep_prop "ro.product.system.model" "${TSUKIKA_SYSTEM_PROPERTY_FILE}")"
TARGET_BUILD_PRODUCT_NAME="$(grep_prop "ro.product.system.device" "${TSUKIKA_SYSTEM_PROPERTY_FILE}")"

# COMMON DEVICE VARIABLES: do not edit!
BUILD_TARGET_ARCH=$(
    arch="ARM" # default
    for props in "$TSUKIKA_PRODUCT_PROPERTY_FILE" \
                 "$TSUKIKA_SYSTEM_PROPERTY_FILE" \
                 "$TSUKIKA_VENDOR_PROPERTY_FILE"; do
        [ -f "$props" ] || continue
        if grep -q 'arm64-v8a' "$props"; then
    		echo "ARM64"
            break
        fi
    done
)

# device specific customization:
if [ -d "./target/${TARGET_BUILD_PRODUCT_NAME}" ]; then
	debugPrint "build.sh: Device specific config and blobs are found, customizing the rom...."
	source "./src/target/${TARGET_BUILD_PRODUCT_NAME}/buildTargetProperties.conf"
else
	debugPrint "build.sh: Using genericTargetProperties.conf for configs..."
	source "./src/genericTargetProperties.conf"
fi

# TODO: install framework for better overlay compilation.
logInterpreter "Unpacking Android ${BUILD_TARGET_ANDROID_VERSION} framework..." "java -jar ./src/dependencies/bin/apktool.jar install-framework ${SYSTEM_DIR}/framework/framework-res.apk" || abort "Failed to unpack framework app."

# TODO: decode the CSC files:
console_print "Trying to decode the CSC files...."
tinkerWithCSCFeaturesFile --decode || abort "Failed to decode the CSC files!"

# warn users about test key
[ "$MY_KEYSTORE_PATH" == "./test-keys/tsukika.jks" ] && warns "NOTE: You are using Tsukika's test-key! This is not safe for public builds. Use your own key!" "TEST_KEY_WARNS"

if [[ $BUILD_TARGET_ANDROID_VERSION -eq 14 ]]; then
	sudo rm -rf ${SYSTEM_DIR}/etc/permissions/privapp-permissions-com.samsung.android.kgclient.xml ${SYSTEM_DIR}/etc/public.libraries-wsm.samsung.txt \
	${SYSTEM_DIR}/lib/libhal.wsm.samsung.so ${SYSTEM_DIR}/lib/vendor.samsung.hardware.security.wsm.service-V1-ndk.so \
	${SYSTEM_DIR}/lib64/libhal.wsm.samsung.so ${SYSTEM_DIR}/lib64/vendor.samsung.hardware.security.wsm.service-V1-ndk.so ${SYSTEM_DIR}/priv-app/KnoxGuard
fi

if [[ "$TARGET_REMOVE_USELESS_SAMSUNG_APPLICATIONS_STUFFS" == "true" && -f "./target/${TARGET_BUILD_PRODUCT_NAME}/debloater.sh" ]]; then
	. "./target/${TARGET_BUILD_PRODUCT_NAME}/debloater.sh"
elif [[ "$TARGET_REMOVE_USELESS_SAMSUNG_APPLICATIONS_STUFFS" == "true" ]]; then
	. "${SCRIPTS[5]}"
fi

# misc - unlimited photos backups
[ "$TARGET_INCLUDE_UNLIMITED_BACKUP" == "true" ] && . "${SCRIPTS[0]}"

if [ "$BUILD_TARGET_REQUIRES_BLUETOOTH_LIBRARY_PATCHES" == "true" ]; then
	[ -f "${SYSTEM_DIR}/lib64/libbluetooth_jni.so" ] || abort "The \"libbluetooth_jni.so\" file from the system/lib64 wasn't found" "build.sh"
	magiskboot hexpatch "${SYSTEM_DIR}/lib64/libbluetooth_jni.so" "6804003528008052" "2b00001428008052" || warns "Failed to patch the bluetooth library, please try again!" "BLUETOOTH_PATCH_FAIL"
fi

# patches - fastbootd in stock recovery
[ "$BUILD_TARGET_INCLUDE_FASTBOOTD_PATCH" == "true" ] && runModule "patch-recovery-revived"

# lockscreen - disables none option
[ "$TARGET_REMOVE_NONE_SECURITY_OPTION" == "true" ] && changeXMLValues "config_hide_none_security_option" "true" "./src/tsukika/overlay_packages/settings/tsukika.autogenerated_rro/res/values/bools.xml"

# lockscreen - disables swipe option
[ "$TARGET_REMOVE_SWIPE_SECURITY_OPTION" == "true" ] && changeXMLValues "config_hide_swipe_security_option" "true" "./src/tsukika/overlay_packages/settings/tsukika.autogenerated_rro/res/values/bools.xml"

# builds and deploys the overlay
[[ "$TARGET_REMOVE_NONE_SECURITY_OPTION" == "true" || "$TARGET_REMOVE_SWIPE_SECURITY_OPTION" == "true" ]] && buildAndSignThePackage "${DECODEDAPKTOOLPATHS[0]}" "$TSUKIKA_FALLBACK_OVERLAY_PATH" "false"

# misc - additional animation scales
[ "$TARGET_ADD_EXTRA_ANIMATION_SCALES" == "true" ] && buildAndSignThePackage "${DECODEDAPKTOOLPATHS[1]}" "$TSUKIKA_FALLBACK_OVERLAY_PATH"

# misc - rounded corners on pip window
[[ "$TARGET_ADD_ROUNDED_CORNERS_TO_THE_PIP_WINDOWS" == "true" && $BUILD_TARGET_ANDROID_VERSION -eq 11 ]] && buildAndSignThePackage "${DECODEDAPKTOOLPATHS[2]}" "$TSUKIKA_FALLBACK_OVERLAY_PATH" "false"

# enables game launcher.
if [ "$TARGET_FLOATING_FEATURE_INCLUDE_GAMELAUNCHER_IN_THE_HOMESCREEN" == "true" ]; then
	addFloatXMLValues "SEC_FLOATING_FEATURE_GRAPHICS_SUPPORT_DEFAULT_GAMELAUNCHER_ENABLE" "true"
else
	addFloatXMLValues "SEC_FLOATING_FEATURE_GRAPHICS_SUPPORT_DEFAULT_GAMELAUNCHER_ENABLE" "FALSE"
fi

if [ "$BUILD_TARGET_HAS_HIGH_REFRESH_RATE_MODES" == "true" ]; then
	addFloatXMLValues "SEC_FLOATING_FEATURE_LCD_CONFIG_HFR_DEFAULT_REFRESH_RATE" "${BUILD_TARGET_DEFAULT_SCREEN_REFRESH_RATE}"
else
	addFloatXMLValues "SEC_FLOATING_FEATURE_LCD_CONFIG_HFR_DEFAULT_REFRESH_RATE" "60"
fi

# Adds spotify as an option in the clock app
[ "$TARGET_FLOATING_FEATURE_INCLUDE_SPOTIFY_AS_ALARM" == "true" ] && addFloatXMLValues "SEC_FLOATING_FEATURE_CLOCK_CONFIG_ALARM_SOUND" "spotify"

if [ "$TARGET_FLOATING_FEATURE_BATTERY_SUPPORT_BSOH_SETTINGS" == "true" ]; then
	console_print "This feature needs some patches to work on some roms, if you dont"
	console_print "see anything in the settings, please remove this on the next build."
	addFloatXMLValues "SEC_FLOATING_FEATURE_BATTERY_SUPPORT_BSOH_SETTINGS" "true"
fi

if [ "$TARGET_FLOATING_FEATURE_INCLUDE_CLOCK_LIVE_ICON" == "true" ]; then
	addFloatXMLValues "SEC_FLOATING_FEATURE_LAUNCHER_SUPPORT_CLOCK_LIVE_ICON" "true"
else
	addFloatXMLValues "SEC_FLOATING_FEATURE_LAUNCHER_SUPPORT_CLOCK_LIVE_ICON" "FALSE"
fi

if [ "$TARGET_FLOATING_FEATURE_INCLUDE_EASY_MODE" == "true" ]; then
	addFloatXMLValues "SEC_FLOATING_FEATURE_SETTINGS_SUPPORT_EASY_MODE" "true"
else
	addFloatXMLValues "SEC_FLOATING_FEATURE_SETTINGS_SUPPORT_EASY_MODE" "FALSE"
fi

if [ "$TARGET_FLOATING_FEATURE_ENABLE_BLUR_EFFECTS" == "true" ]; then
	for blur_effects in SEC_FLOATING_FEATURE_GRAPHICS_SUPPORT_PARTIAL_BLUR SEC_FLOATING_FEATURE_GRAPHICS_SUPPORT_CAPTURED_BLUR SEC_FLOATING_FEATURE_GRAPHICS_SUPPORT_3D_SURFACE_TRANSITION_FLAG; do
		addFloatXMLValues "$blur_effects" "true"
	done
	if [ -f "${VENDOR_DIR}/etc/fstab.qcom" ]; then
		if echo "${BUILD_TARGET_SDK_VERSION}" | grep -qE "33|34"; then
			cp -a "./src/target/soc/snapdragon/${BUILD_TARGET_SDK_VERSION}/system/bin/surfaceflinger" "${SYSTEM_DIR}/bin/surfaceflinger"
			cp -a "./src/target/soc/snapdragon/${BUILD_TARGET_SDK_VERSION}/system/lib/libgui.so" "${SYSTEM_DIR}/lib/libgui.so"
			cp -a "./src/target/soc/snapdragon/${BUILD_TARGET_SDK_VERSION}/system/lib64/libgui.so" "${SYSTEM_DIR}/lib64/libgui.so"
		else
			console_print "SDK ${BUILD_TARGET_SDK_VERSION} is not supported for enabling Live blur for now."
		fi
	elif [[ -f ${VENDOR_DIR}/etc/fstab.exynos* || -f "${VENDOR_DIR}/bin/vaultkeeperd" ]]; then
		if echo "${BUILD_TARGET_SDK_VERSION}" | grep -qE "28|29|30|31|33|34"; then
			cp -a "./src/target/soc/exynos/${BUILD_TARGET_SDK_VERSION}/system/bin/surfaceflinger" "${SYSTEM_DIR}/bin/surfaceflinger"
			cp -a "./src/target/soc/exynos/${BUILD_TARGET_SDK_VERSION}/system/lib/libgui.so" "${SYSTEM_DIR}/lib/libgui.so"
			cp -a "./src/target/soc/exynos/${BUILD_TARGET_SDK_VERSION}/system/lib64/libgui.so" "${SYSTEM_DIR}/lib64/libgui.so"
		else
			console_print "SDK ${BUILD_TARGET_SDK_VERSION} is not supported for enabling Live blur for now."
		fi
	fi
fi

if [ "$TARGET_FLOATING_FEATURE_ENABLE_ENHANCED_PROCESSING" == "true" ]; then
	for enhanced_gaming in SEC_FLOATING_FEATURE_SYSTEM_SUPPORT_LOW_HEAT_MODE SEC_FLOATING_FEATURE_COMMON_SUPPORT_HIGH_PERFORMANCE_MODE SEC_FLOATING_FEATURE_SYSTEM_SUPPORT_ENHANCED_CPU_RESPONSIVENESS; do
		addFloatXMLValues "${enhanced_gaming}" "true"
	done
fi

if [ "$TARGET_FLOATING_FEATURE_ENABLE_EXTRA_SCREEN_MODES" == "true" ]; then
	for led_modes in SEC_FLOATING_FEATURE_LCD_SUPPORT_MDNIE_HW SEC_FLOATING_FEATURE_LCD_SUPPORT_WIDE_COLOR_GAMUT; do
		addFloatXMLValues "${led_modes}" "FALSE"
	done
fi

if [ "$BUILD_TARGET_SUPPORTS_WIRELESS_POWER_SHARING" == "true" ]; then
	for wireless_power_sharing_core in SEC_FLOATING_FEATURE_BATTERY_SUPPORT_HV SEC_FLOATING_FEATURE_BATTERY_SUPPORT_WIRELESS_HV SEC_FLOATING_FEATURE_BATTERY_SUPPORT_WIRELESS_NIGHT_MODE \
		SEC_FLOATING_FEATURE_BATTERY_SUPPORT_WIRELESS_TX; do
		addFloatXMLValues "${wireless_power_sharing_core}" "true"
	done
fi

[ "$TARGET_FLOATING_FEATURE_ENABLE_ULTRA_POWER_SAVING" == "true" ] && addFloatXMLValues "SEC_FLOATING_FEATURE_COMMON_SUPPORT_ULTRA_POWER_SAVING" "true"

if [ "$TARGET_FLOATING_FEATURE_DISABLE_SMART_SWITCH" == "true" ]; then
	addFloatXMLValues "SEC_FLOATING_FEATURE_COMMON_SUPPORT_SMART_SWITCH" "FALSE"
	applyDiffPatches "${SYSTEM_DIR}/etc/init/init.rilcommon.rc" "${DIFF_UNIFIED_PATCHES[21]}"
fi

if [ "$TARGET_FLOATING_FEATURE_SUPPORTS_DOLBY_IN_GAMES" == "true" ]; then
	for dolby_in_games in SEC_FLOATING_FEATURE_AUDIO_SUPPORT_DEFAULT_ON_DOLBY_IN_GAME SEC_FLOATING_FEATURE_AUDIO_SUPPORT_DOLBY_GAME_PROFILE; do
		addFloatXMLValues "${dolby_in_games}" "true"
	done
fi

# let's download goodlook modules from corsicanu's repo.
debugPrint "build.sh: Starting to check and try to download goodlook modules, logs can be seen below if any errors spawn upon the process"
[ "$TARGET_INCLUDE_SAMSUNG_THEMING_MODULES" == "true" ] && downloadGLmodules 2>> $thisConsoleTempLogFile

# custom wallpaper-res resources_info.json generator.
if [ "$CUSTOM_WALLPAPER_RES_JSON_GENERATOR" == "true" ]; then
	command -v java &>/dev/null || abort "\e[1;36m - Please install openjdk or any java toolchain to continue.\e[0;37m" "build.sh"
	debugPrint "build.sh: Java path: $(command -v java)"
	special_index=00
	the_homescreen_wallpaper_has_been_set=false
	the_lockscreen_wallpaper_has_been_set=false
	printf "\e[1;36m - How many wallpapers do you need to add to the Wallpaper App?\e[0;37m "
	read wallpaper_count
	debugPrint "build.sh: User requested ${wallpaper_count} metadata to generate for wallpaper-res"
	[[ "$wallpaper_count" =~ ^[0-9]+$ ]] && abort "\e[0;31m - Invalid input. Please enter a valid number. Exiting...\e[0;37m" "build.sh"
	clear
	sudo rm -rf ./src/tsukika/packages/flosspaper_purezza/raw/resources_info.json
	echo -e "{\n\t\"version\": \"0.0.1\",\n\t\"phone\": [" > ./src/tsukika/packages/flosspaper_purezza/raw/resources_info.json
	for ((i = 1; i <= wallpaper_count; i++)); do
		[ "${i}" -ge "10" ] && special_index=0
		printf "\e[0;36m - Adding configurations for wallpaper_${special_index}${i}.png.\e[0;37m\n"
		special_symbol=$(
			if [[ $i -eq $wallpaper_count ]]; then
				echo ","
			else
				echo ""
			fi
		)
		if [[ "$the_lockscreen_wallpaper_has_been_set" == "true" && "$the_homescreen_wallpaper_has_been_set" == "true" ]]; then
			addTheWallpaperMetadata "${special_index}${i}" "additional" "$i"
		else
			clear
			echo -e "\e[1;36m - What do you want to do with wallpaper_${special_index}${i}.png?\e[0;37m"
			[[ "$the_lockscreen_wallpaper_has_been_set" == false ]] && echo "[1] - Set as default lockscreen wallpaper"
			[[ "$the_homescreen_wallpaper_has_been_set" == false ]] && echo "[2] - Set as default homescreen wallpaper"
			echo "[3] - Include in additional wallpapers"
			printf "\e[1;36mType your choice: \e[0;37m"
			read user_choice
			case $user_choice in
				1)
					if [ "$the_lockscreen_wallpaper_has_been_set" == "false" ]; then
						the_lockscreen_wallpaper_has_been_set="true"
						addTheWallpaperMetadata "${special_index}${i}" "lock" "$i"
					else
						addTheWallpaperMetadata "${special_index}${i}" "additional" "$i"
					fi
				;;
				2) 
					if [ "$the_homescreen_wallpaper_has_been_set" == "false" ]; then
						the_homescreen_wallpaper_has_been_set="true"
						addTheWallpaperMetadata "${special_index}${i}" "home" "$i"
					else
						addTheWallpaperMetadata "${special_index}${i}" "additional" "$i"
					fi
				;;
				3)
					addTheWallpaperMetadata "${special_index}${i}" "additional" "$i"
				;;
				*)
					echo -e "\e[0;31m Invalid response! Exiting...\e[0;37m";
					exit 1
				;;
			esac
		fi
	done
	echo -e "  ]\n}" >> ./src/tsukika/packages/TsukikaWallpapers/raw/resources_info.json
	sudo rm -rf ${SYSTEM_DIR}/priv-app/wallpaper-res/*
	buildAndSignThePackage "${DECODEDAPKTOOLPATHS[3]}" "${SYSTEM_DIR}/priv-app/wallpaper-res/" "false"
	chmod 644 "${SYSTEM_DIR}/priv-app/wallpaper-res/tsukika-cust-wallpapers.apk"
	chown root:root "${SYSTEM_DIR}/priv-app/wallpaper-res/tsukika-cust-wallpapers.apk"
	chcon u:object_r:system_file:s0 "${SYSTEM_DIR}/priv-app/wallpaper-res/tsukika-cust-wallpapers.apk"
	echo -e "- Please check \" ./src/tsukika/packages/TsukikaWallpapers/raw/resources_info.json\" if you're concerned about issues.\e[0;37m"
fi

# removes useless samsung stuffs from the vendor partition.
if [ "$TARGET_REMOVE_USELESS_VENDOR_STUFFS" == "true" ]; then
    if [[ ${BUILD_TARGET_SDK_VERSION} -ge 29 && ${BUILD_TARGET_SDK_VERSION} -le 35 ]]; then
        if grep_prop "ro.product.vendor.model" "${TSUKIKA_VENDOR_PROPERTY_FILE}" | grep -E 'G97([035][FNUW0]|7[BNUW])|N97([05][FNUW0]|6[BNQ0]|1N)|T860|F90(0[FN]|7[BN])|M[23]15F'; then
            for cass in ${SYSTEM_DIR}/../init.rc ${VENDOR_DIR}/etc/init/cass.rc; do
                sed -i -e 's/^[^#].*cass.*$/# &/' -re '/\/(system|vendor)\/bin\/cass/,/^#?$/s/^[^#]*$/#&/' "${cass}"
            done
        fi
        if [ "${BUILD_TARGET_USES_DYNAMIC_PARTITIONS}" == false ]; then
            for useless_service_def in ${VENDOR_DIR}/etc/vintf/manifest.xml ${SYSTEM_DIR}/etc/vintf/compatibility_matrix.device.xml ${VENDOR_DIR}/etc/vintf/manifest/vaultkeeper_manifest.xml; do
                removeAttributes "${useless_service_def}" "vendor.samsung.hardware.security.vaultkeeper"
                removeAttributes "${useless_service_def}" "vendor.samsung.hardware.security.proca"
                removeAttributes "${useless_service_def}" "vendor.samsung.hardware.security.wsm"
            done
            for vk in ${SYSTEM_DIR}/etc/init/vk*.rc ${VENDOR_DIR}/etc/init/vk*.rc ${VENDOR_DIR}/etc/init/vaultkeeper*.rc; do
                [ -f "${vk}" ] && sed -i -e 's/^[^#].*$/# &/' ${vk} && console_print "Disabled VaultKeeper service."
            done
            for proca in ${VENDOR_DIR}/etc/init/pa_daemon*.rc; do
                [ -f "${proca}" ] && sed -i -e 's/^[^#]/# &/' ${proca} && console_print "Disabled Proca (Process Authenticator) service."
            done
        fi
        sudo rm -rf "${VENDOR_DIR}/overlay/AccentColorBlack" "${VENDOR_DIR}/overlay/AccentColorCinnamon" "${VENDOR_DIR}/overlay/AccentColorGreen" \
        "${VENDOR_DIR}/overlay/AccentColorOcean" "${VENDOR_DIR}/overlay/AccentColorOrchid" "${VENDOR_DIR}/overlay/AccentColorPurple" \
        "${VENDOR_DIR}/etc/init/boringssl_self_test.rc" "${VENDOR_DIR}/etc/init/dumpstate-default.rc" "${VENDOR_DIR}/etc/init/vendor_flash_recovery.rc" \
		"${VENDOR_DIR}/etc/vintf/manifest/dumpstate-default.xml" "${VENDOR_DIR}/overlay/AccentColorSpace" &>/dev/null
        if [ "${TARGET_DISABLE_FILE_BASED_ENCRYPTION}" == "true" ]; then
            for fstab__ in ${VENDOR_DIR}/etc/fstab.*; do
				[ "${fstab__}" == "fstab.ramplus" ] && continue
                sed -i -e 's/^\([^#].*\)fileencryption=[^,]*\(.*\)$/# &\n\1encryptable\2/g' ${fstab__}
            done
        fi
    fi
	console_print "Finished removing useless vendor stuff(s)"
fi

# nukes display refresh rate overrides on some video platforms.
[[ "$BUILD_TARGET_DISABLE_DISPLAY_REFRESH_RATE_OVERRIDE" == "true" && $BUILD_TARGET_SDK_VERSION -ge 33 ]] && setprop --custom "${VENDOR_DIR}/default.prop" "ro.surface_flinger.enable_frame_rate_override" "false"	

# disables DRC shit
if [ "$BUILD_TARGET_DISABLE_DYNAMIC_RANGE_COMPRESSION" == "true" ]; then
	if [ -f "${VENDOR_DIR}/etc/audio_policy_configuration.xml" ]; then
		sed -i 's/speaker_drc_enabled="true"/speaker_drc_enabled="false"/g' "${VENDOR_DIR}/etc/audio_policy_configuration.xml"
		debugPrint "build.sh: Disabled speaker DRC in audio_policy_configuration.xml"
	else
		abort "Error: audio_policy_configuration.xml not found!" "build.sh"
	fi
fi

# disables samsung asks
[ "$TARGET_DISABLE_SAMSUNG_ASKS_SIGNATURE_VERFICATION" == "true" ] && setprop --system ro.build.official.release false

[[ ${BUILD_TARGET_SDK_VERSION} == 35 && -n "${roynaWhat}" ]] && buildAndSignThePackage "${DECODEDAPKTOOLPATHS[4]}" "$TSUKIKA_FALLBACK_OVERLAY_PATH" "false"

if [ "$TARGET_BUILD_REMOVE_SYSTEM_LOGGING" == "true" ]; then
	addFloatXMLValues "SEC_FLOATING_FEATURE_SYSTEM_CONFIG_SYSINT_DQA_LOGLEVEL" '3'
	setprop --system "logcat.live" "disable"
	setprop --system "sys.dropdump.on" "Off"
	setprop --system "persist.debug.atrace.boottrace" '0'
	setprop --system "persist.log.ewlogd" '0'
	setprop --system "sys.lpdumpd" '0'
	setprop --system "persist.device_config.global_settings.sys_traced" '0'
	setprop --system "persist.traced.enable" '0'
	setprop --system "persist.sys.lmk.reportkills" "false"
	setprop --system "log.tag.ConnectivityManager" "S"
	setprop --system "log.tag.ConnectivityService" "S"
	setprop --system "log.tag.NetworkLogger" "S"
	setprop --system "log.tag.IptablesRestoreController" "S"
	setprop --system "log.tag.ClatdController" "S"
	debugPrint "build.sh: Patching atrace, dumpstate, and logd for SDK ${BUILD_TARGET_SDK_VERSION} if possible...."
	case ${BUILD_TARGET_SDK_VERSION} in
		28)
			applyDiffPatches "${SYSTEM_DIR}/etc/init/dumpstate.rc" "${DIFF_UNIFIED_PATCHES[6]}"
			applyDiffPatches "${SYSTEM_DIR}/etc/init/atrace.rc" "${DIFF_UNIFIED_PATCHES[0]}"
			applyDiffPatches "${SYSTEM_DIR}/etc/init/logd.rc" "${DIFF_UNIFIED_PATCHES[9]}"
		;;
		29)
			applyDiffPatches "${SYSTEM_DIR}/etc/init/dumpstate.rc" "${DIFF_UNIFIED_PATCHES[7]}"
			applyDiffPatches "${SYSTEM_DIR}/etc/init/atrace.rc" "${DIFF_UNIFIED_PATCHES[1]}"
			applyDiffPatches "${SYSTEM_DIR}/etc/init/logd.rc" "${DIFF_UNIFIED_PATCHES[10]}"
		;;
		30)
			applyDiffPatches "${SYSTEM_DIR}/etc/init/dumpstate.rc" "${DIFF_UNIFIED_PATCHES[8]}"
			applyDiffPatches "${SYSTEM_DIR}/etc/init/atrace.rc" "${DIFF_UNIFIED_PATCHES[2]}"
			applyDiffPatches "${SYSTEM_DIR}/etc/init/logd.rc" "${DIFF_UNIFIED_PATCHES[11]}"
		;;
		31)
			applyDiffPatches "${SYSTEM_DIR}/etc/init/dumpstate.rc" "${DIFF_UNIFIED_PATCHES[9]}"
			applyDiffPatches "${SYSTEM_DIR}/etc/init/atrace.rc" "${DIFF_UNIFIED_PATCHES[3]}"
			applyDiffPatches "${SYSTEM_DIR}/etc/init/logd.rc" "${DIFF_UNIFIED_PATCHES[12]}"
		;;
		33)
			applyDiffPatches "${SYSTEM_DIR}/etc/init/atrace.rc" "${DIFF_UNIFIED_PATCHES[24]}"
			applyDiffPatches "${SYSTEM_DIR}/etc/init/dumpstate.rc" "${DIFF_UNIFIED_PATCHES[26]}"
			applyDiffPatches "${SYSTEM_DIR}/etc/init/logd.rc" "${DIFF_UNIFIED_PATCHES[27]}"
		;;
		34)
			applyDiffPatches "${SYSTEM_DIR}/etc/init/atrace.rc" "${DIFF_UNIFIED_PATCHES[28]}"
			applyDiffPatches "${SYSTEM_DIR}/etc/init/dumpstate.rc" "${DIFF_UNIFIED_PATCHES[30]}"
			applyDiffPatches "${SYSTEM_DIR}/etc/init/logd.rc" "${DIFF_UNIFIED_PATCHES[31]}"
		;;
		35)
			applyDiffPatches "${SYSTEM_DIR}/etc/init/atrace.rc" "${DIFF_UNIFIED_PATCHES[32]}"
			applyDiffPatches "${SYSTEM_DIR}/etc/init/dumpstate.rc" "${DIFF_UNIFIED_PATCHES[34]}"
			applyDiffPatches "${SYSTEM_DIR}/etc/init/logd.rc" "${DIFF_UNIFIED_PATCHES[35]}"
		;;
	esac
fi

# brings mobile data toggle in the power menu:
[ "$TARGET_BUILD_ADD_MOBILE_DATA_TOGGLE_IN_POWER_MENU" == "true" ] && addCSCxmlValues "CscFeature_Framework_SupportDataModeSwitchGlobalAction" "true"

# enables 5 network bars:
[ "$TARGET_BUILD_FORCE_FIVE_BAR_NETICON" == "true" ] && addCSCxmlValues "CscFeature_SystemUI_ConfigMaxRssiLevel" "5"

# Forces the system to not close music apps while recording a video
[ "$TARGET_BUILD_FORCE_SYSTEM_TO_PLAY_MUSIC_WHILE_RECORDING" == "true" ] && addCSCxmlValues "CscFeature_Camera_CamcorderDoNotPauseMusic" "true"

# Enables network speed bar in qs:
if [ "$TARGET_BUILD_ADD_NETWORK_SPEED_WIDGET" == "true" ]; then
	addCSCxmlValues "CscFeature_Setting_SupportRealTimeNetworkSpeed" "true"
	[ "$BUILD_TARGET_SDK_VERSION" -ge "34" ] && addCSCxmlValues "CscFeature_Common_SupportZProjectFunctionInGlobal" "true"
fi

# forces system to not close the camera app while calling
[ "$TARGET_BUILD_FORCE_SYSTEM_TO_NOT_CLOSE_CAMERA_WHILE_CALLING" == "true" ] && addCSCxmlValues "CscFeature_Camera_EnableCameraDuringCall" "true"

# Adds call recording feature in samsung dialer
[ "$TARGET_BUILD_ADD_CALL_RECORDING_IN_SAMSUNG_DIALER" == "true" ] && addCSCxmlValues "CscFeature_VoiceCall_ConfigRecording" "RecordingAllowedByMenu"

if [ "$BUILD_TARGET_DISABLE_KNOX_PROPERTIES" == "true" ]; then
	setprop --system "ro.securestorage.knox" "false"
	setprop --system "ro.security.vaultkeeper.native" "0"
	# Thanks salvo!
	if [ "$BUILD_TARGET_SDK_VERSION" == "34" ]; then
		for properties in security.mdf.result security.mdf ro.security.mdf.ver ro.security.mdf.release ro.security.wlan.ver ro.security.wlan.release ro.security.bt.ver \
			ro.security.bt.release ro.security.bio.ver ro.security.bio.release ro.security.mdf.ux ro.security.fips_bssl.ver ro.security.fips_skc.ver ro.security.fips_scrypto.ver; do
				setprop --force-delete "${TSUKIKA_SYSTEM_PROPERTY_FILE}" "${properties}"
			done
		setprop --system "ro.security.fips.ux" "Disabled"
	fi
	addCSCxmlValues "CscFeature_Knox_SupportKnoxGuard" "FALSE"
fi

# Disables Wifi calling
if [ "$TARGET_BUILD_DISABLE_WIFI_CALLING" == "true" ]; then
	addCSCxmlValues "CscFeature_Setting_SupportWifiCall" "FALSE"
	addCSCxmlValues "CscFeature_Setting_SupportWiFiCallingMenu" "FALSE"
fi

# removes junk on setup:
if [ "$TARGET_BUILD_SKIP_SETUP_JUNKS" == "true" ]; then
	addCSCxmlValues "CscFeature_Setting_SkipWifiActvDuringSetupWizard" "FALSE"
	addCSCxmlValues "CscFeature_Setting_SkipStepsDuringSamsungSetupWizard" "true"
fi

# Blocks notification sounds on playbacks:
[ "$BLOCK_NOTIFICATION_SOUNDS_DURING_PLAYBACK" == "true" ] && addCSCxmlValues "CscFeature_Video_BlockNotiSoundDuringStreaming" "true"

# Forces the system to play media while call
[ "$TARGET_BUILD_FORCE_SYSTEM_TO_PLAY_SMTH_WHILE_CALL" == "true" ] && addCSCxmlValues "CscFeature_Video_SupportPlayDuringCall" "true"

# Forces samsung video player to work on pop-up window
[ "$FORCE_ENABLE_POP_UP_PLAYER_ON_SVP" == "true" ] && addCSCxmlValues "CscFeature_Video_EnablePopupPlayer" "true"

# critical - disables setup wizard:
[ "$TARGET_BUILD_FORCE_DISABLE_SETUP_WIZARD" == "true" ] && addCSCxmlValues "CscFeature_SetupWizard_DisablePrivacyPolicyAgreement" "true"

if [ "$TARGET_BUILD_MAKE_DEODEXED_ROM" == "true" ]; then
	for deletableO_VDexFiles in ${SYSTEM_DIR}/app/*/*/*.odex ${SYSTEM_DIR}/app/*/*/*.vdex ${SYSTEM_DIR}/priv-app/*/*/*.odex ${SYSTEM_DIR}/priv-app/*/*/*.vdex \
		${PRODUCT_DIR}/app/*/*/*.odex ${PRODUCT_DIR}/priv-app/*/*/*.vdex \
		${VENDOR_DIR}/app/*/*/*.odex ${VENDOR_DIR}/priv-app/*/*/*.vdex \
		$SYSTEM_EXT_DIR/app/*/*/*.odex $SYSTEM_EXT_DIR/app/*/*/*.vdex $SYSTEM_EXT_DIR/priv-app/*/*/*.odex $SYSTEM_EXT_DIR/priv-app/*/*/*.vdex; do
		[ -f "${deletableO_VDexFiles}" ] && sudo rm -rf "${deletableO_VDexFiles}"
	done
fi

# should enable voice Memo on Samsung Notes:
[[ "${TARGET_FLOATING_FEATURE_ENABLE_VOICE_MEMO_ON_NOTES}" == "true" && ${BUILD_TARGET_SDK_VERSION} == 35 ]] && addFloatXMLValues "SEC_FLOATING_FEATURE_VOICERECORDER_CONFIG_DEF_MODE" "normal,interview,voicememo"

# verify if the device is capable of running Generative AI and it's related actions.
if [ "${BUILD_TARGET_IS_CAPABLE_FOR_GENERATIVE_AI}" == "true" ]; then
	sudo rm -rf "${SYSTEM_DIR}/priv-app/PhotoEditor_Full/PhotoEditor_Full.apk"
	makeAFuckingDirectory "${SYSTEM_DIR}/priv-app/PhotoEditor_AIFull" "root" "root"
	cp "${SYSTEMREPLACABLEASSETS[0]}" "${SYSTEM_DIR}/priv-app/PhotoEditor_AIFull/"
	chmod 644 "${SYSTEM_DIR}/priv-app/PhotoEditor_AIFull/PhotoEditor_AIFull.apk"
	chown root:root "${SYSTEM_DIR}/priv-app/PhotoEditor_AIFull/PhotoEditor_AIFull.apk"
	chcon u:object_r:system_file:s0 "${SYSTEM_DIR}/priv-app/PhotoEditor_AIFull/PhotoEditor_AIFull.apk"
	if [[ "${BUILD_TARGET_SUPPORTS_GENERATIVE_AI_SHADOW_ERASER}" == "true" ]]; then
		makeAFuckingDirectory "${SYSTEM_DIR}/app/GalleryReflectionEraser ${SYSTEM_DIR}/app/GalleryShadowEraser" "root" "root"
		APP_NAMES=("GalleryReflectionEraser" "GalleryShadowEraser")
		for i in "${!APP_NAMES[@]}"; do
			APP="${APP_NAMES[$i]}"
			ASSET="${SYSTEMREPLACABLEASSETS[$((i + 1))]}"
			TARGET_DIR="${SYSTEM_DIR}/app/${APP}"
			TARGET_APK="${TARGET_DIR}/${APP}.apk"
			cp "$ASSET" "$TARGET_DIR/"
			chmod 644 "$TARGET_APK"
			chown root:root "$TARGET_APK"
			chcon u:object_r:system_file:s0 "$TARGET_APK"
		done
	fi
	echo -e "\n\nlibhumantracking.arcsoft.so\nlibPortraitDistortionCorrection.arcsoft.so\nlibPortraitDistortionCorrectionCali.arcsoft.so\nlibface_landmark.arcsoft.so\nlibFacialStickerEngine.arcsoft.so\nlibveengine.arcsoft.so\nlibimage_enhancement.arcsoft.so\nliblow_light_hdr.arcsoft.so\nlibhigh_dynamic_range.arcsoft.so\nlibFacialAttributeDetection.arcsoft.so\nlibobjectcapture.arcsoft.so\nlibobjectcapture_jni.arcsoft.so" >> public.libraries-arcsoft.txt
	addFloatXMLValues "BUILD_TARGET_SUPPORTS_GENERATIVE_AI_OBJECT_ERASER" "$(stringFormat -u ${BUILD_TARGET_SUPPORTS_GENERATIVE_AI_OBJECT_ERASER})"
	addFloatXMLValues "BUILD_TARGET_SUPPORTS_GENERATIVE_AI_REFLECTION_ERASER" "$(stringFormat -u ${BUILD_TARGET_SUPPORTS_GENERATIVE_AI_REFLECTION_ERASER})"
	addFloatXMLValues "BUILD_TARGET_SUPPORTS_GENERATIVE_AI_UPSCALER" "$(stringFormat -u ${BUILD_TARGET_SUPPORTS_GENERATIVE_AI_UPSCALER})"
fi

# Use xmlstarlet to update the version inside vendor-ndk
if [ "${TARGET_BUILD_FIX_ANDROID_SYSTEM_DEVICE_WARNING}" == "true" ]; then
	console_print "Fixing android warning after boot..."
	xmlstarlet ed -L -u "/manifest/vendor-ndk/version" -v "${BUILD_TARGET_VENDOR_SDK_VERSION}" "${SYSTEM_EXT_DIR}/etc/vintf/manifest.xml" || abort "Failed to fix android warning, please try again" "build.sh"
fi

if [ "${TARGET_BUILD_ENABLE_SEARCLE}" == "true" ]; then
	touch "$SYSTEM_DIR/etc/sysconfig/google_searcle.xml"
	{
		echo "<?xml version=\"1.0\" encoding=\"utf-8\"?>"
		echo "<config>"
		echo "    <!-- This is for update Searcle for Samsung from play store -->"
		echo "    <feature name=\"com.samsung.feature.EXPERIENCE_CTS\" />"
		echo "</config>"
	} >> "$SYSTEM_DIR/etc/sysconfig/google_searcle.xml"
	setPerm "$SYSTEM_DIR/etc/sysconfig/google_searcle.xml" 0 0 644 u:object_r:system_file:s0
	setprop --custom "${PRODUCT_DIR}/etc/build.prop" "ro.com.google.cdb.spa1" "bsxasm1Add"
	setprop --custom "${PRODUCT_DIR}/etc/build.prop" "ro.bbt.support.circle2search" "true"
fi

if [ "${TARGET_BUILD_ADD_SCREENRESOLUTION_CHANGER}" == "true" ]; then
	[[ -z ${BUILD_TARGET_SCREEN_WIDTH} || -z "${BUILD_TARGET_SCREEN_HEIGHT}" ]] && abort "The screen resolution is not specified on the property file."
	if [[ ${BUILD_TARGET_SCREEN_WIDTH} =~ ^[0-9]+$ && ${BUILD_TARGET_SCREEN_HEIGHT} =~ ^[0-9]+$ && ${BUILD_TARGET_SCREEN_WIDTH} -eq 1080 && ${BUILD_TARGET_SCREEN_HEIGHT} -eq 2340 ]]; then
		console_print "Trying to add screenResolution controller app into the device..."
		. "${SCRIPTS[1]}"
		sudo rm -rf "${SYSTEM_DIR}/priv-app/screenResolution"
		makeAFuckingDirectory "${SYSTEM_DIR}/priv-app/screenResolution" "root" "root"
		[ -f "${DECODEDAPKTOOLPATHS[5]}" ] || logInterpreter "Trying to extract the screenResolution app.." "tar -C ./src/tsukika/packages/ -xf ${DECODEDAPKTOOLPATHS[5]}.tar"
		buildAndSignThePackage "${DECODEDAPKTOOLPATHS[5]}" "${SYSTEM_DIR}/priv-app/screenResolution/screenResolution.apk" "false" || abort "Failed to build screenResolution, please try again" "build.sh"
		sudo chmod 644 ${SYSTEM_DIR}/priv-app/screenResolution/*.apk
		sudo chown root:root ${SYSTEM_DIR}/priv-app/screenResolution/*.apk
		sudo chcon u:object_r:system_file:s0 ${SYSTEM_DIR}/priv-app/screenResolution/*.apk
		console_print "Finished adding screenResolution!"
	else
		console_print "Your display resolution is not valid for adding screen resolution controller app, skipping the building process..."
	fi
fi

if [[ "${BUILD_TARGET_SDK_VERSION}" =~ ^(34|35)$ && "$BRINGUP_CN_SMARTMANAGER_DEVICE" == "true" ]]; then
	mkdir -p "./local_build/etc/permissions/" "./local_build/etc/app/SmartManager_v6_DeviceSecurity" \
	"./local_build/etc/app/SmartManager_v6_DeviceSecurity_CN" "./local_build/etc/priv-app/SmartManager_v5" "./local_build/etc/priv-app/SmartManager_v6_DeviceSecurity" \
	"./local_build/etc/priv-app/SmartManagerCN" "./local_build/etc/priv-app/SmartManager_v6_DeviceSecurity_CN" "./local_build/etc/priv-app/SAppLock" "./local_build/etc/priv-app/Firewall";
	{
		debugPrint "build.sh: Moving SmartManager and Device Care to a temporary directory.."
		# now move these for a quick revert if anything goes wrong.
		# xmls
		sudo mv "${SYSTEM_DIR}/etc/permissions/privapp-permissions-com.samsung.android.lool.xml" "./local_build/etc/permissions/"
		sudo mv "${SYSTEM_DIR}/etc/permissions/signature-permissions-com.samsung.android.lool.xml" "./local_build/etc/permissions/"
		sudo mv "${SYSTEM_DIR}/etc/permissions/privapp-permissions-com.samsung.android.sm.devicesecurity_v6.xml" "./local_build/etc/permissions/"
		sudo mv "${SYSTEM_DIR}/etc/permissions/privapp-permissions-com.samsung.android.sm_cn.xml" "./local_build/etc/permissions/"
		sudo mv "${SYSTEM_DIR}/etc/permissions/signature-permissions-com.samsung.android.sm_cn.xml" "./local_build/etc/permissions/"
		sudo mv "${SYSTEM_DIR}/etc/permissions/privapp-permissions-com.samsung.android.sm.devicesecurity.tcm_v6.xml" "./local_build/etc/permissions/"
		sudo mv "${SYSTEM_DIR}/etc/permissions/privapp-permissions-com.samsung.android.applock.xml" "./local_build/etc/permissions/"
		sudo mv "${SYSTEM_DIR}/etc/permissions/privapp-permissions-com.sec.android.app.firewall.xml" "./local_build/etc/permissions/"
		# actual thing
		sudo mv ${SYSTEM_DIR}/app/SmartManager_v6_DeviceSecurity/* "./local_build/etc/app/SmartManager_v6_DeviceSecurity"
		sudo mv ${SYSTEM_DIR}/app/SmartManager_v6_DeviceSecurity_CN/* "./local_build/etc/app/SmartManager_v6_DeviceSecurity_CN"
		sudo mv ${SYSTEM_DIR}/priv-app/SmartManager_v5/* "./local_build/etc/priv-app/SmartManager_v5"
		sudo mv ${SYSTEM_DIR}/priv-app/SmartManager_v6_DeviceSecurity/* "./local_build/etc/priv-app/SmartManager_v6_DeviceSecurity"
		sudo mv ${SYSTEM_DIR}/priv-app/SmartManagerCN/* "./local_build/etc/priv-app/SmartManagerCN"
		sudo mv ${SYSTEM_DIR}/priv-app/SmartManager_v6_DeviceSecurity_CN/* "./local_build/etc/priv-app/SmartManager_v6_DeviceSecurity_CN"
		sudo mv ${SYSTEM_DIR}/priv-app/SAppLock/* "./local_build/etc/priv-app/SAppLock"
		sudo mv ${SYSTEM_DIR}/priv-app/Firewall/* "./local_build/etc/priv-app/Firewall"
	} &>>$thisConsoleTempLogFile
	debugPrint "build.sh: Moved SmartManager and Device Care to a temporary directory.."
	for i in ${SMARTMANAGER_CN_DOWNLOADABLE_CONTENTS[@]}; do
		for j in ${SYSTEM_DIR}/${SMARTMANAGER_CN_DOWNLOADABLE_CONTENTS_SAVE_PATHS[@]}; do
			downloadRequestedFile "${i}" "${j}" || {
				{
					debugPrint "build.sh: looks like one of the loop is failed, restoring the backup..."
					# actual thing
					sudo mv ./local_build/etc/priv-app/Firewall/* "${SYSTEM_DIR}/priv-app/Firewall/"
					sudo mv ./local_build/etc/priv-app/SAppLock/* "${SYSTEM_DIR}/priv-app/SAppLock/"
					sudo mv ./local_build/etc/priv-app/SmartManager_v6_DeviceSecurity_CN/* "${SYSTEM_DIR}/priv-app/SmartManager_v6_DeviceSecurity_CN/"
					sudo mv ./local_build/etc/priv-app/SmartManagerCN/* "${SYSTEM_DIR}/priv-app/SmartManagerCN/"
					sudo mv ./local_build/etc/priv-app/SmartManager_v6_DeviceSecurity/* "${SYSTEM_DIR}/priv-app/SmartManager_v6_DeviceSecurity/"
					sudo mv ./local_build/etc/priv-app/SmartManager_v5/* "${SYSTEM_DIR}/priv-app/SmartManager_v5/"
					sudo mv ./local_build/etc/app/SmartManager_v6_DeviceSecurity_CN/* "${SYSTEM_DIR}/app/SmartManager_v6_DeviceSecurity_CN/"
					sudo mv ./local_build/etc/app/SmartManager_v6_DeviceSecurity/* "${SYSTEM_DIR}/app/SmartManager_v6_DeviceSecurity/"
					# xmls
					sudo mv "./local_build/etc/permissions/privapp-permissions-com.sec.android.app.firewall.xml" "${SYSTEM_DIR}/etc/permissions/"
					sudo mv "./local_build/etc/permissions/privapp-permissions-com.samsung.android.applock.xml" "${SYSTEM_DIR}/etc/permissions/"
					sudo mv "./local_build/etc/permissions/privapp-permissions-com.samsung.android.sm.devicesecurity.tcm_v6.xml" "${SYSTEM_DIR}/etc/permissions/"
					sudo mv "./local_build/etc/permissions/signature-permissions-com.samsung.android.sm_cn.xml" "${SYSTEM_DIR}/etc/permissions/"
					sudo mv "./local_build/etc/permissions/privapp-permissions-com.samsung.android.sm_cn.xml" "${SYSTEM_DIR}/etc/permissions/"
					sudo mv "./local_build/etc/permissions/privapp-permissions-com.samsung.android.sm.devicesecurity_v6.xml" "${SYSTEM_DIR}/etc/permissions/"
					sudo mv "./local_build/etc/permissions/signature-permissions-com.samsung.android.lool.xml" "${SYSTEM_DIR}/etc/permissions/"
					sudo mv "./local_build/etc/permissions/privapp-permissions-com.samsung.android.lool.xml" "${SYSTEM_DIR}/etc/permissions/"
					debugPrint "build.sh: Seems like i did restore those files? didn't i?"
					warns "Failed to download stuffs from @saadelasfur github repo, moved everything to their places!" "FAILED_TO_DOWNLOAD_SMARTMANAGER"
					break
				} &>>$thisConsoleTempLogFile
			}
		done
	done
	# change float values, as per updater-script from @saadelasfur/SmartManager/Installers/SmartManagerCN/updater-script.
	# https://github.com/saadelasfur/SmartManager/blob/5a547850d8049ce0bfd6528d660b2735d6a18291/Installers/SmartManagerCN/updater-script#L87
	#                                                          -                                                                           #
	# https://github.com/saadelasfur/SmartManager/blob/5a547850d8049ce0bfd6528d660b2735d6a18291/Installers/SmartManagerCN/updater-script#L99
	addFloatXMLValues "SEC_FLOATING_FEATURE_SMARTMANAGER_CONFIG_PACKAGE_NAME" "com.samsung.android.sm_cn"
	addFloatXMLValues "SEC_FLOATING_FEATURE_SECURITY_CONFIG_DEVICEMONITOR_PACKAGE_NAME" "com.samsung.android.sm.devicesecurity.tcm"
	addFloatXMLValues "SEC_FLOATING_FEATURE_COMMON_SUPPORT_NAL_PRELOADAPP_REGULATION" "true"
fi

if [ "${BUILD_TARGET_ENABLE_DISPLAY_OVERCLOCKING}" == "true" ]; then
	if [[ -z "${DTBO_IMAGE_PATH}" || ! -f "${DTBO_IMAGE_PATH}" ]]; then
		warns "Can't patch dtbo because the dtbo image path is inaccessable." "DTBO_PATCH_FAILED"
	else
		. "${SCRIPTS[6]}"
	fi
fi

# refer ts: https://www.reddit.com/r/technology/comments/1iy19yt/a_new_android_feature_is_scanning_your_photos_for/
if [ "${TARGET_INCLUDE_SAFETYCORESTUB}" == "true" ]; then
	makeAFuckingDirectory "$SYSTEM_DIR/app/SafetyCoreStub/" root root
	buildAndSignThePackage "./src/tsukika/packages/SafetyCoreStub" "$SYSTEM_DIR/app/SafetyCoreStub/" "false" --skip-editing-version-info
fi

# setup wizard customization
if [ "$TARGET_BUILD_CUSTOMIZE_SETUP_WIZARD_STRINGS" == "true" ]; then
	xmlstarlet sel -t -v "//string[@name='intro_upper_title']" ./src/tsukika/overlay_packages/setupWizard/res/values/strings.xml | grep -q '^".*"$' && \
		xmlstarlet ed -L -u '//string[@name="intro_upper_title"]' -v "\"${TARGET_BUILD_SETUP_WIZARD_INTRO_TEXT}\"" ./src/tsukika/overlay_packages/setupWizard/res/values/strings.xml || \
		xmlstarlet ed -L -u '//string[@name="intro_upper_title"]' -v "${TARGET_BUILD_SETUP_WIZARD_INTRO_TEXT}" ./src/tsukika/overlay_packages/setupWizard/res/values/strings.xml
	xmlstarlet sel -t -v "//string[@name='outro_title']" ./src/tsukika/overlay_packages/setupWizard/res/values/strings.xml | grep -q '^".*"$' && \
		xmlstarlet ed -L -u '//string[@name="outro_title"]' -v "\"${TARGET_BUILD_SETUP_WIZARD_OUTRO_TEXT}\"" ./src/tsukika/overlay_packages/setupWizard/res/values/strings.xml || \
		xmlstarlet ed -L -u '//string[@name="outro_title"]' -v "${TARGET_BUILD_SETUP_WIZARD_OUTRO_TEXT}" ./src/tsukika/overlay_packages/setupWizard/res/values/strings.xml
	logInterpreter "Building overlay package..." "buildAndSignThePackage ./src/tsukika/overlay_packages/setupWizard ${TSUKIKA_FALLBACK_OVERLAY_PATH}/" "false" || abort "Failed to build overlay package."
fi

# oh boy.
if [[ "${TARGET_BUILD_ADD_RAM_MANAGEMENT_FIX}" == "true" && "${BUILD_TARGET_SDK_VERSION}" -ge 29 ]]; then
	sudo touch "${SYSTEM_DIR}/etc/init/init.drmgmt.rc" || abort "Failed to create a file in ${SYSTEM_DIR}/etc/init" "build.sh"
	{
		echo -ne "# taken from: https://github.com/crok/crokrammgmtfix\n"
		echo -ne "on post-fs-data\n"
		echo -ne "\texec_background -- /system/bin/cmd device_config put activity_manager max_cached_processes 256\n"
		echo -ne "\texec_background -- /system/bin/cmd device_config put activity_manager max_phantom_processes 2147483647\n"
		echo -ne "\texec_background -- /system/bin/cmd device_config put activity_manager max_empty_time_millis 43200000\n"
		echo -ne "\texec_background -- /system/bin/cmd settings put global settings_enable_monitor_phantom_procs false\n"
		echo -ne "\texec_background -- /system/bin/cmd device_config set_sync_disabled_for_tests persistent"
	} > "${SYSTEM_DIR}/etc/init/init.drmgmt.rc"
	sudo chmod 644 "${SYSTEM_DIR}/etc/init/init.drmgmt.rc"
	sudo chown 0 "${SYSTEM_DIR}/etc/init/init.drmgmt.rc"
	sudo chgrp 0 "${SYSTEM_DIR}/etc/init/init.drmgmt.rc"
	sudo chcon u:object_r:system_file:s0 "${SYSTEM_DIR}/etc/init/init.drmgmt.rc"
fi

# ota implementation.
if [[ "${TARGET_BUILD_ADD_DEPRECATED_UNICA_UPDATER}" == "true" && ! -z "${TARGET_BUILD_UNICA_UPDATER_OTA_MANIFEST_URL}" && "${BUILD_TARGET_SDK_VERSION}" -ge "29" ]]; then
	makeAFuckingDirectory "${SYSTEM_DIR}/app/TsukikaUpdater" "root" "root"
	make UN1CAUpdater OTA_MANIFEST_URL="${TARGET_BUILD_UNICA_UPDATER_OTA_MANIFEST_URL}" SkipSign=false
	sudo cp "./src/tsukika/packages/TsukikaUpdater/dist/TsukikaUpdater-aligned-signed.apk" "${SYSTEM_DIR}/app/TsukikaUpdater" || abort "Failed to copy the updater app into the ROM" "build.sh"
	sudo cp "./src/tsukika/packages/ETC/permissions/privapp_whitelist_com.mesalabs.ten.update.xml" "${SYSTEM_DIR}/etc/permissions/"
	sudo cp "./src/tsukika/packages/ETC/default-permissions/default-permissions_com.mesalabs.ten.update.xml" "${SYSTEM_DIR}/etc/default-permissions/"
	console_print "Successfully added updater app into the rom."
	console_print "Trying to mod SecSettings.."
	if [[ -f "./src/diff_patches/system/priv-app/SecSettings/${BUILD_TARGET_SDK_VERSION}_sec_software_info_settings.xml" && \ 
		"./src/diff_patches/system/priv-app/SecSettings/${BUILD_TARGET_SDK_VERSION}_sec_top_level_settings.xml" ]]; then
			java -jar ./src/dependencies/bin/apktool.jar if ${SYSTEM_DIR}/framework/framework-res.apk &>/dev/null
			java -jar ./src/dependencies/bin/apktool.jar --only-main-classes decode ${SYSTEM_DIR}/priv-app/SecSettings/SecSettings.apk -o ./SecSettingsMOD &>/dev/null || abort "Failed to decompile the System Settings app" "build.sh"
			cp -af "./src/diff_patches/system/priv-app/SecSettings/${BUILD_TARGET_SDK_VERSION}_sec_software_info_settings.xml" ./SecSettingsMOD/res/xml/sec_software_info_settings.xml
			cp -af "./src/diff_patches/system/priv-app/SecSettings/${BUILD_TARGET_SDK_VERSION}_sec_top_level_settings.xml" ./SecSettingsMOD/res/xml/sec_top_level_settings.xml
			# change the default placeholder values
			xmlstarlet ed -L -N a="http://schemas.android.com/apk/res/android" -N s="http://schemas.android.com/apk/res-auto" \ 
				-u "//*[@a:key='tsukika_changelogs']/*[@a:data]/@a:data" -v "https://github.com/ayumi-aiko/Tsukika/updaterConfigs/changelogs/${TSUKIKA_BUILD_NUMBER}/CHANGELOGS.md" "./SecSettingsMOD/res/xml/sec_software_info_settings.xml"
			xmlstarlet ed -L -N a="http://schemas.android.com/apk/res/android" -u "//*[@a:key='tsukika_codename']/@a:summary" -v "${CODENAME}" \
				-u "//*[@a:key='tsukika_version']/@a:summary" -v "${CODENAME_VERSION_REFERENCE_ID}" \
				-u "//*[@a:key='tsukika_builder']/@a:summary" -v "${BUILD_USERNAME}" \
				-u "//*[@a:key='tsukika_build_number']/@a:summary" -v "${TSUKIKA_BUILD_NUMBER}" "./SecSettingsMOD/res/xml/sec_top_level_settings.xml"
			for i in "./SecSettingsMOD/res/xml/sec_top_level_settings.xml" "./SecSettingsMOD/res/xml/sec_software_info_settings.xml"; do
				xmllint --noout ${i} &>/dev/null || abort "$(basename $i) has bad XML structure" "build.sh"
			done
			buildAndSignThePackage "./SecSettingsMOD/" "${SYSTEM_DIR}/priv-app/SecSettings/SecSettings.apk" false --skip-editing-version-info
	else
		console_print "Can't modify system settings, required modified XML files are not found!"
	fi
fi

# knoxpatch
if [[ "${TARGET_BUILD_ADD_KNOXPATCH}" == "true" ]]; then
	console_print "Trying to run KnoxPatch module..."
	runModule "KnoxPatch" && console_print "Ran KnoxPatch module successfully!" || console_print "Failed to run KnoxPatch module."
fi

# device customization script
[ -f "./src/target/${TARGET_BUILD_PRODUCT_NAME}/customize.sh" ] && . "./src/target/${TARGET_BUILD_PRODUCT_NAME}/customize.sh"

# let's extend audio offload buffer size to 256kb and plug some of our things.
debugPrint "build.sh: End of the script, running misc stuffs.."
addCSCxmlValues "CscFeature_Setting_InfinitySoftwareUpdate" "true"
addCSCxmlValues "CscFeature_Setting_DisableMenuSoftwareUpdate" "true"
addCSCxmlValues "CscFeature_Settings_GOTA" "true"
addCSCxmlValues "CscFeature_Settings_FOTA" "FALSE"
setprop --system ro.config.iccc_version "iccc_disabled"
setprop --system ro.config.dmverity "false"
for defaultTsukikaAlertSounds in "ro.config.notification_sound Bling.ogg" "ro.config.notification_sound_2 Pop.ogg"; do
	setprop --vendor "$(echo "${defaultTsukikaAlertSounds}" | awk '{print $1}')" "$(echo "${defaultTsukikaAlertSounds}" | awk '{print $2}')"
done
if [[ -n "${BUILD_TARGET_BOOT_ANIMATION_FPS}" && "${BUILD_TARGET_BOOT_ANIMATION_FPS}" -le "60" && -n "${BUILD_TARGET_SHUTDOWN_ANIMATION_FPS}" && "${BUILD_TARGET_SHUTDOWN_ANIMATION_FPS}" -le "60" ]]; then
	setprop --system "boot.fps" "${BUILD_TARGET_BOOT_ANIMATION_FPS}"
	setprop --system "shutdown.fps" "${BUILD_TARGET_SHUTDOWN_ANIMATION_FPS}"
fi
changeDefaultLanguageConfiguration ${NEW_DEFAULT_LANGUAGE_ON_PRODUCT} ${NEW_DEFAULT_LANGUAGE_COUNTRY_ON_PRODUCT}
addFloatXMLValues "SEC_FLOATING_FEATURE_LAUNCHER_CONFIG_ANIMATION_TYPE" "${TARGET_FLOATING_FEATURE_LAUNCHER_CONFIG_ANIMATION_TYPE}"
setprop --vendor "vendor.audio.offload.buffer.size.kb" "256"
# tbh i dont like the way im about to do rn:
for i in $TSUKIKA_PRODUCT_PROPERTY_FILE $TSUKIKA_SYSTEM_PROPERTY_FILE $TSUKIKA_SYSTEM_EXT_PROPERTY_FILE $TSUKIKA_VENDOR_PROPERTY_FILE; do
	[ -f "$i" ] || continue 
	setprop --custom "${i}" "wlan.wfd.hdcp" "disable"
	setprop --custom "${i}" "wifi.interface" "wlan0"
done
[ -f "${SYSTEM_DIR}/system_dlkm/etc/build.prop" ] && setprop --custom "${SYSTEM_DIR}/system_dlkm/etc/build.prop" "wifi.interface "wlan0" || setprop --vendor "wifi.interface "wlan0"
sudo rm -rf "${SYSTEM_DIR}/hidden" "${SYSTEM_DIR}/preload" "${SYSTEM_DIR}/recovery-from-boot.p" "${SYSTEM_DIR}/bin/install-recovery.sh"
cp -af ./src/misc/etc/ringtones_and_etc/media/audio/* "${SYSTEM_DIR}/media/audio/"
addFloatXMLValues "SEC_FLOATING_FEATURE_COMMON_SUPPORT_SAMSUNG_MARKETING_INFO" "FALSE"
[ "$TARGET_INCLUDE_CUSTOM_BRAND_NAME" == "true" ] && addFloatXMLValues "SEC_FLOATING_FEATURE_SETTINGS_CONFIG_BRAND_NAME" "${BUILD_TARGET_CUSTOM_BRAND_NAME}"
for i in "logcat.live disable" "sys.dropdump.on Off" "profiler.force_disable_err_rpt 1" "profiler.force_disable_ulog 1" \
		 "sys.lpdumpd 0" "persist.device_config.global_settings.sys_traced 0" "persist.traced.enable 0" "persist.sys.lmk.reportkills false" \
		 "log.tag.ConnectivityManager S" "log.tag.ConnectivityService S" "log.tag.NetworkLogger S" \
		 "log.tag.IptablesRestoreController S" "log.tag.ClatdController S"; do
		setprop --system "$(echo "${i}" | awk '{printf $1}')" "$(echo "${i}" | awk '{printf $2}')"
done

case "${BUILD_TARGET_SDK_VERSION}" in
    28)
        applyDiffPatches "${VENDOR_DIR}/etc/init/wifi.rc" "${DIFF_UNIFIED_PATCHES[4]}"
    ;;
    29)
        applyDiffPatches "${VENDOR_DIR}/etc/init/wifi.rc" "${DIFF_UNIFIED_PATCHES[5]}"
        applyDiffPatches "${SYSTEM_DIR}/etc/init/bootchecker.rc" "${DIFF_UNIFIED_PATCHES[14]}"
    ;;
    30)
        applyDiffPatches "${VENDOR_DIR}/etc/init/wifi.rc" "${DIFF_UNIFIED_PATCHES[17]}"
        applyDiffPatches "${SYSTEM_DIR}/etc/init/uncrypt.rc" "${DIFF_UNIFIED_PATCHES[20]}"
        applyDiffPatches "${SYSTEM_DIR}/etc/init/vold.rc" "${DIFF_UNIFIED_PATCHES[22]}"
        applyDiffPatches "${SYSTEM_DIR}/etc/init/bootchecker.rc" "${DIFF_UNIFIED_PATCHES[15]}"
    ;;
    31)
        applyDiffPatches "${VENDOR_DIR}/etc/init/wifi.rc" "${DIFF_UNIFIED_PATCHES[17]}"
        applyDiffPatches "${SYSTEM_DIR}/etc/init/bootchecker.rc" "${DIFF_UNIFIED_PATCHES[16]}"
    ;;
	33)
        applyDiffPatches "${SYSTEM_DIR}/etc/init/bootchecker.rc" "${DIFF_UNIFIED_PATCHES[25]}"
	;;
	34)
        applyDiffPatches "${SYSTEM_DIR}/etc/init/bootchecker.rc" "${DIFF_UNIFIED_PATCHES[29]}"
	;;
	35)
        applyDiffPatches "${SYSTEM_DIR}/etc/init/bootchecker.rc" "${DIFF_UNIFIED_PATCHES[33]}"
	;;
esac

[[ ${BUILD_TARGET_SDK_VERSION} -ge 28 && ${BUILD_TARGET_SDK_VERSION} -le 30 ]] && applyDiffPatches "${SYSTEM_DIR}/etc/init/freecess.rc" "${DIFF_UNIFIED_PATCHES[23]}"
[[ ${BUILD_TARGET_SDK_VERSION} -ge 28 && ${BUILD_TARGET_SDK_VERSION} -le 34 ]] && applyDiffPatches "${SYSTEM_DIR}/etc/init/init.rilcommon.rc" "${DIFF_UNIFIED_PATCHES[21]}"
[[ ${BUILD_TARGET_SDK_VERSION} -ge 29 && ${BUILD_TARGET_SDK_VERSION} -le 35 ]] && applyDiffPatches "${SYSTEM_DIR}/etc/restart_radio_process.sh" "${DIFF_UNIFIED_PATCHES[19]}"
if [ "${BUILD_TARGET_ENABLE_VULKAN_UI_RENDERING}" == "true" ]; then
	case ${BUILD_TARGET_GPU_VULKAN_VERSION} in
		0x00401000|0x00401001) # Vulkan 1.1 and 1.1.1
				console_print "Your $(stringFormat -u ${TARGET_BUILD_PRODUCT_NAME}) does have Vulkan (API v1.1/1.1.1) rendering support, but it may not perform well in UI."
				if ask "Are you sure you want to enable Vulkan for UI rendering?"; then
					setprop --vendor "ro.hwui.use_vulkan" "true"
					setprop --system "ro.hwui.use_vulkan" "true"
				fi
			;;
		0x00402000|0x004020A2|0x00403000|0x004030105) # Vulkan 1.2, 1.2.162, 1.3, 1.3.261
				warns "Your device met the requirements of ui rendering in vulkan. It could render UI elements via Vulkan but may cause performance issues." "FORCE_VULKAN_UI_SHADING"
				setprop --vendor "ro.hwui.use_vulkan" "true"
				setprop --system "ro.hwui.use_vulkan" "true"
			;;
		*) # Unknown or unsupported Vulkan version
				warns "Unsupported or unknown Vulkan version detected: ${BUILD_TARGET_GPU_VULKAN_VERSION}." "FORCE_VULKAN_UI_SHADING"
			;;
	esac
fi
# Controls the default frame rate override of game applications. Ideally, game applications set
# desired frame rate via setFrameRate() API. However, to cover the scenario when the game didn't
# have a set frame rate, we introduce the default frame rate. The priority of this override is the
# lowest among setFrameRate() and game intervention override.
#prop {
#    api_name: "game_default_frame_rate_override"
#    type: Integer
#    scope: Public
#    access: Readonly
#    prop_name: "ro.surface_flinger.game_default_frame_rate_override"
#}
# to be honest it would work on games which doesn't have it's max frame rate set.
[[ ${BUILD_TARGET_SDK_VERSION} -eq 35 && ! -z "${BUILD_TARGET_HIGHEST_DEVICE_REFRESH_RATE}" ]] && setprop --vendor "ro.surface_flinger.game_default_frame_rate_override" "$BUILD_TARGET_HIGHEST_DEVICE_REFRESH_RATE"
tinkerWithCSCFeaturesFile --encode
debugPrint "CSC feature file(s) successfully encoded."
sudo rm -rf "$TMPDIR"

if [ -f "./localFirmwareBuildPending" ]; then
	if [ -f "./local_build/etc/extract/super_extract/system" ]; then
		repackSuperFromDump "./local_build/etc/buildedContents/super.img" 
		console_print "Super image can be found at: \"./local_build/etc/buildedContents/super.img\""
		buildImage "./local_build/etc/imageSetup/optics" "/optics" 
	else
		buildImage "./local_build/etc/imageSetup/system" "/"
		buildImage "./local_build/etc/imageSetup/vendor" "/vendor"
		buildImage "./local_build/etc/imageSetup/product" "/product"
	fi
fi
BUILD_END_TIME=$(date +%s)
BUILD_DURATION=$((BUILD_END_TIME - BUILD_START_TIME))
console_print "Build ended at $(date +%I:%M%p) on $(date +%d\ %B\ %Y)"
console_print "Total build time: $(printf '%02d:%02d:%02d' $((BUILD_DURATION/3600)) $((BUILD_DURATION%3600/60)) $((BUILD_DURATION%60))) (hh:mm:ss)"
console_print "Please verify if the requested features were available or not."