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

# shutt up
CC_ROOT="/home/ayumi/android-ndk-r27d/toolchains/llvm/prebuilt/linux-x86_64/bin"
CFLAGS="-std=c23 -O3 -static -Wall -Wextra -Werror -pedantic \
        -Wshadow -Wconversion -Wsign-conversion -Wpointer-arith -Wcast-qual \
        -Wmissing-prototypes -Wstrict-prototypes -Wformat=2 -Wundef"
BUILD_LOGFILE="./local_build/logs/makeErrors.log"
OLD_REFERENCE_URL="https://raw.githubusercontent.com/ayumi-aiko/Tsukika/ref/ota-manifest.xml"
UBER_SIGNER_JAR="./src/dependencies/bin/signer.jar"
APKTOOL_JAR="./src/dependencies/bin/apktool.jar"
HEADER_PATH="./src/include"
HEADER_SOURCES="./src/include/tsukika.c ./src/include/tsukikautils.c"
SOURCES=("./src/tsukika/android_binaries/c/compileTest/test.c" "./src/tsukika/android_binaries/c/BootRecon/main.c")
SOURCE_BUILD_OUTPUT_PATH=("./src/tsukika/android_binaries/c/compileTest/hawksnext" "./src/tsukika/android_binaries/c/BootRecon/bootrecon")
SKIPSIGN=""
OTA_MANIFEST_URL=""
SDK=""
CC=""

# first of all, let's just switch to the directory of this script temporarily.
if ! cd "$(realpath "$(dirname "$0")")"; then
    printf "\033[0;31mmake: Error: Failed to switch to the directory of this script, please try again.\033[0m\n"
    exit 1;
fi

function buildTargets() {
    if [ ! -x "$CC" ]; then
        printf "\033[0;31mmake: Error: Compiler '%s' not found or not executable. Please check the path or install it.\033[0m\n" "$(basename $CC)";
        exit 1;
    fi
    echo -e "\e[0;35mmake: Info: Trying to build $(basename ${SOURCE_BUILD_OUTPUT_PATH[${SOURCE_INDEX}]})..\033[0m"
    if ! "${CC}" ${CFLAGS} -I"${HEADER_PATH}" ${HEADER_SOURCES} "${SOURCES[${SOURCE_INDEX}]}" -o ${SOURCE_BUILD_OUTPUT_PATH[${SOURCE_INDEX}]} &>${BUILD_LOGFILE}; then
        echo -e "\033[0;31mmake: Error: Failed to build $(basename ${SOURCE_BUILD_OUTPUT_PATH[${SOURCE_INDEX}]})\033[0m, please kindly send the logs to me :)"
        [ -f "${SOURCE_BUILD_OUTPUT_PATH[${SOURCE_INDEX}]}" ] && rm -rf "${SOURCE_BUILD_OUTPUT_PATH[${SOURCE_INDEX}]}"
        exit 1
    fi
    echo -e "\e[0;35mmake: Info: Finished building $(basename ${SOURCE_BUILD_OUTPUT_PATH[${SOURCE_INDEX}]}), the built binary is located at: ${SOURCE_BUILD_OUTPUT_PATH[${SOURCE_INDEX}]}\033[0m"
}

# just make the dir 
mkdir -p "$(dirname "${BUILD_LOGFILE}")"
for args in "$@"; do
    lowerCaseArgument=$(echo "${args}" | tr '[:upper:]' '[:lower:]')
    [[ -z "${SDK}" && "${lowerCaseArgument}" == sdk=* ]] && SDK="${lowerCaseArgument#sdk=}"
    [[ -z "${OTA_MANIFEST_URL}" && "${lowerCaseArgument}" == ota_manifest_url=* ]] && OTA_MANIFEST_URL="${lowerCaseArgument#ota_manifest_url=}"
    [[ -z "${SKIPSIGN}" && "${lowerCaseArgument}" == skipsign=* ]] && SKIPSIGN="${lowerCaseArgument#skipsign=}"
    if [[ -z "${CC}" && -n "${SDK}" ]]; then
        case "${lowerCaseArgument}" in
            arch=arm)
                CC="${CC_ROOT}/armv7a-linux-androideabi${SDK}-clang"
                continue;
            ;;
            arch=arm64)
                CC="${CC_ROOT}/aarch64-linux-android${SDK}-clang"
                continue;
            ;;
            arch=x86)
                CC="${CC_ROOT}/i686-linux-android${SDK}-clang"
                continue;
            ;;
            arch=x86_64)
                CC="${CC_ROOT}/x86_64-linux-android${SDK}-clang"
                continue;
            ;;
        esac
    fi
    case "${lowerCaseArgument}" in
        "unicaupdater")
            source ./src/misc/util_functions.sh
            source ./src/makeconfigs.prop
            [ -z "${OTA_MANIFEST_URL}" ] && abort "- OTA_MANIFEST_URL is not mentioned, check the command again." "MAKE" "NULL";
            [ -z "${SKIPSIGN}" ] && abort "- SKIPSIGN is not mentioned, either set it to true to skip signing or false to sign." "MAKE" "NULL";
            echo -e "\e[0;35mmake: Info: Building UN1CA updater for Tsukika..\e[0;37m";
            if [ ! -f "./src/tsukika/android_packages/TsukikaUpdater/smali" ]; then
                tar -C ./src/tsukika/android_packages/TsukikaUpdater/ -xf ./src/tsukika/android_packages/TsukikaUpdater/TsukikaOTASmaliFiles.tar 2>/dev/null || abort "Failed to extract the tar file to build the package." "MAKE" "NULL";
            fi
            echo -e "\e[0;35mmake: Info: Trying to change the default URL in the smali files..\e[0;37m";
            for file in ./src/tsukika/android_packages/TsukikaUpdater/smali_classes15/com/mesalabs/ten/update/ota/ROMUpdate\$LoadUpdateManifest.smali ./src/tsukika/android_packages/TsukikaUpdater/smali_classes16/com/mesalabs/ten/update/ota/utils/Constants.smali; do
                sed -i "s|$OLD_REFERENCE_URL|${OTA_MANIFEST_URL}|g" "${file}" || abort "Failed to change manifest provider in $file" "MAKE" "NULL";
            done
            echo -e "\e[0;35mmake: Info: Changed the default URL in the smali files, starting to build the UN1CA updater...\e[0;37m";
            java -jar "${APKTOOL_JAR}" build "./src/tsukika/android_packages/TsukikaUpdater/" &>>$BUILD_LOGFILE || abort "Failed to build the application. Please check $BUILD_LOGFILE for the logs." "MAKE" "NULL";
            if [ "${SKIPSIGN}" == "true" ]; then
                echo -e "\e[0;35mmake: Info: Skipping signing process..\e[0;37m";
            else
                echo -e "\e[0;35mmake: Info: Signing the application..\e[0;37m";
                java -jar "$UBER_SIGNER_JAR" \
                --verbose \
                --apk ./src/tsukika/android_packages/TsukikaUpdater/dist/TsukikaUpdater.apk \
                --ks "$MY_KEYSTORE_PATH" \
                --ksAlias "$MY_KEYSTORE_ALIAS" \
                --ksPass "$MY_KEYSTORE_PASSWORD" \
                --ksKeyPass "$MY_KEYSTORE_ALIAS_KEY_PASSWORD" &>>$BUILD_LOGFILE; \
                if [ -f "./src/tsukika/android_packages/TsukikaUpdater/dist/TsukikaUpdater-aligned-signed.apk" ]; then
                    echo -e "\e[0;35mmake: Info: Signed APK: ./src/tsukika/android_packages/TsukikaUpdater/dist/TsukikaUpdater-aligned-signed.apk\e[0;37m"
                else 
                    abort "- Failed to sign the application, please try again..." "MAKE" "NULL";
                fi
            fi
        ;;
        "clean")
            sudo rm -rf "./src/tsukika/android_packages/TsukikaUpdater/dist" "./src/tsukika/android_packages/TsukikaUpdater/smali" ./src/tsukika/android_packages/TsukikaUpdater/smali_* "./src/tsukika/android_packages/TsukikaUpdater/build" "${BUILD_LOGFILE}" "${SOURCE_BUILD_OUTPUT_PATH[0]}" "${SOURCE_BUILD_OUTPUT_PATH[1]}"
	        echo -e "\033[0;32mmake: Info: Clean complete.\033[0m"
        ;;
        "headertest"|"bootrecon")
            [ "${lowerCaseArgument}" == "headertest" ] && SOURCE_INDEX=0 || SOURCE_INDEX=1
            buildTargets;
        ;;
        "all")
            for i in $(seq 0 1); do
                SOURCE_INDEX="$i"
                buildTargets
            done
        ;;
    esac
done