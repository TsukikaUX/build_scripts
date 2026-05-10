#!/bin/bash
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

# source the functions script:
chmod +x $GITHUB_WORKSPACE/src/misc/util_functions.sh
source $GITHUB_WORKSPACE/src/misc/util_functions.sh

# dependencies urls:
apktool="https://api.github.com/repos/iBotPeaches/Apktool/releases/latest"
uberApkSigner="https://api.github.com/repos/patrickfav/uber-apk-signer/releases/latest"

# latest version of the dependencies from the respective GitHub repositories:
apktoolVersion=$(curl -s "$apktool" | grep -oP '"tag_name": "\K(.*)(?=")')
uberApkSignerVersion=$(curl -s "$uberApkSigner" | grep -oP '"tag_name": "\K(.*)(?=")' | sed 's/[^0-9.]//g')

# local version of those dependencies:
apktoolLocalVersion=v$(java -jar "$GITHUB_WORKSPACE/src/dependencies/bin/apktool.jar" --version 2>/dev/null)
uberApkSignerLocalVersion=$(java -jar "$GITHUB_WORKSPACE/src/dependencies/bin/signer.jar" --version 2>/dev/null | sed 's/[^0-9.]//g')

if [ "$1" == "--update-dependencies" ]; then
    if [[ "${apktoolVersion}" == "${apktoolLocalVersion}" ]]; then
        console_print "Apktool is up to date with the repo."
    else
        console_print "Trying to update Apktool from ${apktoolLocalVersion} to ${apktoolVersion}..."
        downloadRequestedFile "$(getLatestReleaseFromGithub "${apktool}")" "$GITHUB_WORKSPACE/src/dependencies/bin/apktool.jarNEW" || abort "Failed to update Apktool."
        # Only compare hashes if the original exists; otherwise always replace
        original="$GITHUB_WORKSPACE/src/dependencies/bin/apktool.jar"
        new="$GITHUB_WORKSPACE/src/dependencies/bin/apktool.jarNEW"
        mv "$new" "$original"
        git add "$original"
        textAppend[0]="apktool updated from ${apktoolLocalVersion} to ${apktoolVersion}"
    fi
    if [[ "${uberApkSignerVersion}" == "${uberApkSignerLocalVersion}" ]]; then
        console_print "Uber Apk Signer is up to date with the repo."
    else
        console_print "Trying to update Uber Apk Signer from ${uberApkSignerLocalVersion} to ${uberApkSignerVersion}..."
        downloadRequestedFile "$(getLatestReleaseFromGithub "${uberApkSigner}")" "$GITHUB_WORKSPACE/src/dependencies/bin/signer.jarNEW" || abort "Failed to update Uber Apk Signer."
        original="$GITHUB_WORKSPACE/src/dependencies/bin/signer.jar"
        new="$GITHUB_WORKSPACE/src/dependencies/bin/signer.jarNEW"
        mv "$new" "$original"
        git add "$original"
        textAppend[1]="uber-apk-signer updated from ${uberApkSignerLocalVersion} to ${uberApkSignerVersion}"
    fi
    if git diff --cached --quiet; then
        console_print "No changes to commit."
    else
        git config --global user.name "—͟͞͞★ ɪᴋ𝘂ᵞο ᴋ𝖎𝘵𝕒 ★"
        git config --global user.email "171214813+ikuyo-kita07@users.noreply.github.com"
        console_print "Committing changes..."
        joined=$(IFS=', '; echo "${textAppend[*]}")
        git commit -m "github-actions: dependencies: ${joined}"
        console_print "Trying to push changes to the repository..."
        git push -u origin main || abort "Failed to push changes to the repository."
        console_print "Changes pushed successfully."
        console_print "Workflow completed successfully."
    fi
fi

# cleanup:
rm -f "$GITHUB_WORKSPACE/src/dependencies/bin/apktool.jarNEW" "$GITHUB_WORKSPACE/src/dependencies/bin/signer.jarNEW"

# fix failure:
exit 0