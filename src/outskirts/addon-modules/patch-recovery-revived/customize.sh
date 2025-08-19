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
source "$2"

# module-based codes:
export expectedRecoveryFilePath="$(realpath ./local_build/etc/extract/recovery.img)"
export patchedRecoveryFilePath="$(realpath ./local_build/custom_recovery_with_fastbootd/patched-recovery.img)"

# callbacks...
initPatchRecovery
extractRecoveryImage
hexpatchRecoveryImage
repackRecoveryImage
createTarFileWhenAsked || console_print "Recovery image can be found at ${patchedRecoveryFilePath}"