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
# shellcheck disable=SC2154
# shellcheck disable=SC1091
# shellcheck disable=SC2086

# source the debloat list file
source ./src/misc/etc/bloatList/bloatList.prop

if [ "${BUILD_TARGET_SDK_VERSION}" -ge "29" ]; then
    [ "${BUILD_TARGET_SDK_VERSION}" == "28" ] && \
        console_print "The list hasn't really focused for Android Pie because no one uses it nowadays, sorry.."
    removeApps "${SYSTEM_DIR}/app" "${app[@]}"
    removeApps "${SYSTEM_DIR}/priv-app" "${privilagedApps[@]}"
    removeApps "${SYSTEM_EXT_DIR}/priv-app" "${systemExtraPrivilagedApps[@]}"
    removeApps "${PRODUCT_DIR}/app" "${productApps[@]}"
    removeApps "${PRODUCT_DIR}/priv-app" "${productPrivilagedApps[@]}"
    for unknown in $(echo ${SYSTEM_DIR}/app/SBrowser*) $(echo ${SYSTEM_DIR}/app/SamsungTTS*) $(echo ${SYSTEM_DIR}/priv-app/BixbyVisionFramework*) \
        $(echo ${SYSTEM_DIR}/priv-app/GalaxyAppsWidget*) $(echo ${SYSTEM_DIR}/priv-app/GalaxyApps*) $(echo ${SYSTEM_DIR}/priv-app/OneDrive*) \
        $(echo ${SYSTEM_DIR}/priv-app/SecCalculator*) $(echo ${SYSTEM_DIR}/priv-app/UltraDataSaving*) $(echo ${PRODUCT_DIR}/app/Gmail*); do
            debugPrint "debloaterUnified.sh: Removing ${unknown}..."
            [ -d "${unknown}" ] && rm -rf "${unknown}" 2>>"${thisConsoleTempLogFile}"
    done
    console_print "Trying to debloat your samsung!"
    console_print "  - Type 'y' to remove and type 'n' to keep them" --clear
    ask "Do you want to remove Samsung Weather app" && rm -rf "${SYSTEM_DIR}/app/SamsungWeather" 2>"${thisConsoleTempLogFile}" 
    if ask "Do you want to remove Samsung Sharing tools"; then
        for ((i = 0; i < 4; i++)); do
            rm -rf "${SYSTEM_DIR}/app/${optApp[$i]}"
        done
        rm -rf "${SYSTEM_DIR}/priv-app/ShareLive"
    fi
    if ask "Do you want to remove Samsung AR Camera Plugins"; then
        for ((i = 4; i < 7; i++)); do
            rm -rf "${SYSTEM_DIR}/app/${optApp[$i]}"
        done
        for ((i = 5; i < 7; i++)); do
            rm -rf "${SYSTEM_DIR}/priv-app/${optPrivilagedApps[$i]}"
        done
    fi
    if ask "Do you want to remove printing tools from your system"; then
        for ((i = 7; i < 9; i++)); do
            rm -rf "${SYSTEM_DIR}/app/${optApp[$i]}"
        done
        rm -rf "${SYSTEM_DIR}/priv-app/${optPrivilagedApps[4]}"
    fi
    ask "Do you want to nuke Finder [heavy ram consuption, used to search apps in homescreen]" && rm -rf "${SYSTEM_DIR}/priv-app/Finder"
    if ask "Do you want to nuke Game Launcher and Game Tools [performance will be doomed if you let it cook]"; then
        rm -rf "${SYSTEM_DIR}/priv-app/GameHome" 2>"${thisConsoleTempLogFile}"
        rm -rf "${SYSTEM_DIR}/priv-app/GameOptimizingService" 2>"${thisConsoleTempLogFile}"
        rm -rf ${SYSTEM_DIR}/priv-app/GameTools* 2>"${thisConsoleTempLogFile}"
    fi
    ask "Do you want to nuke Device Care Plugin [performance will be doomed if you let it cook]" && rm -rf "${SYSTEM_DIR}/priv-app/${optPrivilagedApps[8]}"
    ask "Do you want to nuke Carrier Services such as ESIM and Wifi-Calling" && rm -rf "${SYSTEM_DIR}/priv-app/${optPrivilagedApps[10]}"
    console_print "Trying to remove requested stuffs..."
else
    console_print "This version of android is not supported, please do a pr if you can."
    debugPrint "debloaterUnified.sh: Unsupported android version."
    return 1;
fi