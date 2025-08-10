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

remove_apps() {
    local app_list=("$@")
    local base_dir="$1"
    shift
    local app_names=("$@")   
    for app_name in "${app_names[@]}"; do
        full_path="${base_dir}/${app_name}"
        debugPrint "debloat_the_crap(): Trying to remove ${full_path}..."
        if [ -d "${full_path}" ]; then
            rm -rf "${full_path}" 2>>"${thisConsoleTempLogFile}"
        else
            debugPrint "debloat_the_crap(): Couldn't find ${app_name}, don't worry, I will debloat it somehow :D"
        fi
    done
}

debloat_the_crap() {
    local app=(
        "ANTPlusTest"
        "ATTMessage_ATT"
        "AutomationTest_FB"
        "BluetoothTest"
        "Chrome"
        "ChromeCustomizations"
        "DictDiotekForSec"
        "DuoStub"
        "EasymodeContactsWidget81"
        "Facebook_stub"
        "FBAppManager_NS"
        "FactoryAirCommandManager"
        "FactoryCameraFB"
        "Foundation"
        "GoogleTTS"
        "GalaxyResourceUpdater"
        "KidsHome_Installer"
        "Maps"
        "MAPSAgent"
        "MDMApp"
        "MinusOnePage"
        "MyATTWebLink"
        "MnoDmViewer"
        "MnoDmClient"
        "Notes40"
        "Netflix_activationCommon"
        "Netflix_stub"
        "OpenCalendar"
        "PhotoTable"
        "PartnerBookmarksProvider"
        "PlayAutoInstallConfig"
        "SamsungOne"
        "SecFactoryPhoneTest"
        "SmartSwitchAgent"
        "SLocation"
        "WebManual"
        "VZMessages"
        "WlanTest"
        "YouTube"
    )

    local privilaged_apps=(
        "APNWidgetBaseRoot_ATT"
        "ATTAPNWidget_ATT"
        "AttTvMode"
        "AppUpdateCenter"
        "DeviceBasedServiceConsent"
        "DeviceQualityAgent"
        "DeviceTest"
        "DynamicLockscreen"
        "DumpCollector"
        "EasySetup"
        "FactoryTestProvider"
        "FBInstaller_NS"
        "Fast"
        "Fmm"
        "FotaAgent"
        "GooglePartnerSetup"
        "GoogleRestore"
        "HuxPlatform"
        "HwModuleTest"
        "LTETest"
        "ModemServiceMode"
        "MemorySaver_O_Refresh"
        "NSDSWebApp"
        "NetworkDiagnostic"
        "PreloadInstaller"
        "PhoneErrService"
        "SNP"
        "SOAgent"
        "SPPPushClient"
        "SamsungSmartSuggestions"
        "SamsungCoreServices-Stub"
        "SettingsBixby"
        "SetupWizard_USA"
        "SmartSwitchAssistant"
        "SoftphoneAccount"
        "SsuService"
        "serviceModeApp_FB"
        "StoryService"
        "SmartEpdgTestApp"
        "TADownloader"
        "Velvet"
        "UserDictionaryProvider"
        "YourPhone_Stub"
        "VzCloud"
    )

    local system_extra_privilaged_apps=(
        "GoogleFeedback"
    )

    local product_apps=(
        "Chrome"
        "DuoStub"
        "Maps"
        "YouTube"
    )

    local product_privilaged_apps=(
        "GooglePartnerSetup"
        "Velvet"
        "GoogleRestore"
    )

    # bomb.
    remove_apps "${SYSTEM_DIR}/app" "${app[@]}"
    remove_apps "${SYSTEM_DIR}/priv-app" "${privilaged_apps[@]}"
    remove_apps "${SYSTEM_EXT_DIR}/priv-app" "${system_extra_privilaged_apps[@]}"
    remove_apps "${PRODUCT_DIR}/app" "${product_apps[@]}"
    remove_apps "${PRODUCT_DIR}/priv-app" "${product_privilaged_apps[@]}"
    for unknown in $(echo ${SYSTEM_DIR}/app/SBrowser*) $(echo ${SYSTEM_DIR}/app/SamsungTTS*) $(echo ${SYSTEM_DIR}/priv-app/BixbyVisionFramework*) \
    $(echo ${SYSTEM_DIR}/priv-app/GalaxyAppsWidget*) $(echo ${SYSTEM_DIR}/priv-app/GalaxyApps*) $(echo ${SYSTEM_DIR}/priv-app/OneDrive*) \
    $(echo ${SYSTEM_DIR}/priv-app/SecCalculator*) $(echo ${SYSTEM_DIR}/priv-app/UltraDataSaving*) $(echo ${PRODUCT_DIR}/app/Gmail*); do
        debugPrint "debloat_the_crap(): Removing ${unknown}..."
        [ -d "${unknown}" ] && rm -rf "${unknown}" 2>>"${thisConsoleTempLogFile}"
    done
}

nuke_or_ignore_these_stuffs() {
    local app=(
        "AASAservice" # 0
        "AllShareAware" # 1
        "AllshareFileShare" # 2
        "AllshareMediaShare" # 3
        "ARCore" # 4
        "ARZone" # 5
        "StickerCenter" # 6
        "PrintSpooler" # 7
        "GooglePrintRecommendationService" # 8
    )
    local privilaged_apps=(
        "AREmoji" # 0
        "AREmojiEditor" # 1
        "sticker" # 2
        "ThemeCenter" # 3
        "BuiltInPrintService" # 4
        "LiveStickers" # 5
        "StickerFaceARAvatar" # 6
        "SecureFolder" # 7
        "SamsungDeviceHealthManagerService" # 8
        "ShareLive" # 9
        "Turbo" # 10
    )

    # ogioudheiufheiuvh
    console_print "Trying to debloat your samsung!"
    console_print "  - Type 'y' to remove and type 'n' to keep them" --clear
    ask "Do you want to remove Samsung Weather app" && rm -rf "${SYSTEM_DIR}/app/SamsungWeather" 2>./error_ring.log 

    if ask "Do you want to remove Samsung Sharing tools"; then
        for ((i = 0; i < 4; i++)); do
            rm -rf "${SYSTEM_DIR}/app/${app[$i]}"
        done
        rm -rf "${SYSTEM_DIR}/priv-app/ShareLive"
    fi

    if ask "Do you want to remove Samsung AR Camera Plugins"; then
        for ((i = 4; i < 7; i++)); do
            rm -rf "${SYSTEM_DIR}/app/${app[$i]}"
        done
        for ((i = 5; i < 7; i++)); do
            rm -rf "${SYSTEM_DIR}/priv-app/${privilaged_apps[$i]}"
        done
    fi

    if ask "Do you want to remove printing tools from your system"; then
        for ((i = 7; i < 9; i++)); do
            rm -rf "${SYSTEM_DIR}/app/${app[$i]}"
        done
        rm -rf "${SYSTEM_DIR}/priv-app/${privilaged_apps[4]}"
    fi

    ask "Do you want to nuke Finder [heavy ram consuption, used to search apps in homescreen]" && rm -rf "${SYSTEM_DIR}/priv-app/Finder"

    if ask "Do you want to nuke Game Launcher and Game Tools [performance will be doomed if you let it cook]"; then
        rm -rf "${SYSTEM_DIR}/priv-app/GameHome" 2>./error_ring.log
        rm -rf "${SYSTEM_DIR}/priv-app/GameOptimizingService" 2>./error_ring.log
        rm -rf ${SYSTEM_DIR}/priv-app/GameTools* 2>./error_ring.log
    fi

    ask "Do you want to nuke Device Care Plugin [performance will be doomed if you let it cook]" && rm -rf "${SYSTEM_DIR}/priv-app/${privilaged_apps[8]}"
    ask "Do you want to nuke Carrier Services such as ESIM and Wifi-Calling" && rm -rf "${SYSTEM_DIR}/priv-app/${privilaged_apps[10]}"
    console_print "Trying to remove requested stuffs..."
}

case "${BUILD_TARGET_SDK_VERSION}" in
    30|31|32|33|34|35)
        debloat_the_crap
        nuke_or_ignore_these_stuffs
    ;;
    29)
        debloat_the_crap
        nuke_or_ignore_these_stuffs
    ;;
    28)
        console_print "The list haven't really focused for Android Pie because no one uses it nowadays, sorry.."
        debloat_the_crap
        nuke_or_ignore_these_stuffs
    ;;
    *)
        console_print "This version of android is not supported, please do a pr if you can."
    ;;
esac