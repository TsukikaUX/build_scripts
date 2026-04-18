#!/usr/bin/env bash
#
# Copyright (C) 2025 —͟͞͞★ ɪᴋ𝘂ᵞο ᴋ𝖎𝘵𝕒 ★ <ayumi.aiko@outlook.com>
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
quotes=(
	"We are not what we know but what we are willing to learn."
	"Good people are good because they've come to wisdom through failure."
	"Your word is a lamp for my feet, a light for my path."
	"The first problem for all of us, men and women, is not to learn, but to unlearn."
	"Those who don't learn from the history are doomed to repeat it."
)
cloneSource=(
    "target_soc"
    "target_devices"
    "android_packages"
    "android_overlays"
    "android_binaries"
    "addon_modules"
    "patches"
    "ota_manifests"
)
cloneSourcePath=(
    "src/target/soc"
    "src/target/devices"
    "src/tsukika/android_packages"
    "src/tsukika/android_overlays"
    "src/tsukika/android_binaries"
    "src/outskirts/addon-modules"
    "src/tsukika/patches"
    "updaterConfigs"
)
dependencies=(
    "java"
    "openssl"
    "python3"
    "zip"
    "lz4"
    "tar"
    "file"
    "unzip"
    "simg2img"     # from android-sdk-libsparse-utils
    "xmlstarlet"
    "mkfs.erofs"
    "mkdtimg"
    "imjtool"
)
missing=()
randomQuote="${quotes[$RANDOM % ${#quotes[@]}]}"
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

# check if we are in the build_scripts repository or not
if [ ! -f "./make.sh" ]; then
    echo "- Please run this script inside the cloned build_scripts repository.";
    exit 1;
fi

# DAYUMMMMM
for i in $(seq 0 6); do
    rm -rf "${cloneSourcePath[$i]}"
    if ! git clone https://github.com/TsukikaUX/${cloneSource[$i]}.git ${cloneSourcePath[$i]}; then
        echo "- Failed to clone \"${cloneSource[$i]}\", please try again with a stable internet connection."
        exit 1;
    fi
done

# let's check if dependencies are found or not if the user did ask or idk
if [  -z "$1" ]; then
    echo ""
    echo "- Checking required dependencies..."
    for dep in "${dependencies[@]}"; do
        command -v "$dep" &> /dev/null || missing+=("$dep")
    done
    if [ ${#missing[@]} -ne 0 ]; then
        echo "- Missing dependencies:"
        for m in "${missing[@]}"; do
            echo "  • $m"
        done
        echo ""
        echo "- Please install them before continuing."
        exit 1
    else
        echo "- All dependencies are satisfied."
    fi
fi
