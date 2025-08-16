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

# Show help when no target is provided
ifeq ($(MAKECMDGOALS),)
	.DEFAULT_GOAL := help
endif

# common-build:
SHELL := /bin/bash
OLD_REFERENCE_URL = https://raw.githubusercontent.com/ayumi-aiko/Tsukika/ref/ota-manifest.xml

# dont ask anything bud:
UBER_SIGNER_JAR = ./src/dependencies/bin/signer.jar
APKTOOL_JAR = ./src/dependencies/bin/apktool.jar

# apk/jar signing key: please use your own private key and be sure to not leak it:
# using Tsukika's private key:
MY_KEYSTORE_ALIAS = tsukika-public
MY_KEYSTORE_PASSWORD = theDawnJKSPass
MY_KEYSTORE_PATH = ./test-keys/tsukika.jks
MY_KEYSTORE_ALIAS_KEY_PASSWORD = theDawnJKSPass

# compiler and it's arguments.
CC = android-ndk-r27d/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android$(SDK)-clang
CFLAGS = -O3 -static -I./src/include

# Output binaries
SAVIOUR_OUTPUT = ./local_build/binaries/bootloopSaviour
STUPCUSTOMIZER_OUTPUT = ./local_build/binaries/setupCustomizer

# Source files for each target
SAVIOUR_SRCS = ./src/include/tsukika.c ./src/include/tsukikautils.c

# Main source path
SAVIOUR_MAIN = ./src/bootloopSaviour/main.c
STUPCUSTOMIZER_MAIN = ./src/setupCustomizer/main.c

# Error logs path
ERR_LOG = ./local_build/logs/compilerErrors.log

# Default: Build both
all: bootloop_saviour

# checks if given sdk version deprecated or not.
checkDeprecated:
	@if [ "$(SDK)" -le "27" ]; then \
		echo -e "\e[0;31mmake: Error: Any Android version, which is below than 8.0 Oreo is deprecated.\e[0;37m"; \
		echo -e "\e[0;31mmake: Error: Android 9.0 Pie and above are the targets that are supported.\e[0;37m"; \
		exit 1; \
	fi

# Checks if the android ndk compiler toolchain exists
check_compiler:
	@if [ ! -f "$(CC)" ]; then \
		echo -e "\e[0;31mmake: Error: Android clang is not found. Please install it or edit the makefile to proceed.\e[0;37m"; \
		exit 1; \
	fi

# Checks if the android ndk compiler toolchain exists
checkJava:
	@if ! command -v java >/dev/null 2>&1; then \
		echo -e "\e[0;31mmake: Error: Java is not found. Please install it.\e[0;37m"; \
		exit 1; \
	fi

checkKey:
	@if [ -z "$(MY_KEYSTORE_ALIAS)" ]; then echo -e "\e[0;31mmake: Error: MY_KEYSTORE_ALIAS is not set!\e[0;37m"; exit 1; fi
	@if [ -z "$(MY_KEYSTORE_PASSWORD)" ]; then echo -e "\e[0;31mmake: Error: MY_KEYSTORE_PASSWORD is not set!\e[0;37m"; exit 1; fi
	@if [ -z "$(MY_KEYSTORE_PATH)" ]; then echo -e "\e[0;31mmake: Error: MY_KEYSTORE_PATH is not set!\e[0;37m"; exit 1; fi
	@if [ -z "$(MY_KEYSTORE_ALIAS_KEY_PASSWORD)" ]; then echo -e "\e[0;31mmake: Error: MY_KEYSTORE_ALIAS_KEY_PASSWORD is not set!\e[0;37m"; exit 1; fi

bootloop_saviour: checkDeprecated check_compiler
	@rm -f $(ERR_LOG)
	@echo -e "\e[0;33mmake: Info: Building Bootloop Saviour\e[0;37m"
	@$(CC) $(CFLAGS) -std=c23 $(SAVIOUR_SRCS) $(SAVIOUR_MAIN) -o $(SAVIOUR_OUTPUT) >$(ERR_LOG) 2>&1 && \
	echo -e "\e[0;33mmake: Info: Build finished successfully\e[0;37m" || echo -e "\e[0;31mmake: Error: Compilation failed. Check $(ERR_LOG) for details.\e[0;37m";

setupCustomizer: checkDeprecated check_compiler
	@rm -f $(ERR_LOG)
	@echo -e "\e[0;33mmake: Info: Building setupCustomizer\e[0;37m"
	@$(CC) $(CFLAGS) -std=c23 $(SAVIOUR_SRCS) $(STUPCUSTOMIZER_MAIN) -o $(STUPCUSTOMIZER_OUTPUT) >$(ERR_LOG) 2>&1 && \
	echo -e "\e[0;33mmake: Info: Build finished successfully\e[0;37m" || echo -e "\e[0;31mmake: Error: Compilation failed. Check $(ERR_LOG) for details.\e[0;37m";

UN1CAUpdater: checkDeprecated checkKey checkJava
	@bash -c '\
		source ./src/misc/build_scripts/util_functions.sh && \
		[ -z "$${OTA_MANIFEST_URL}" ] && abort "- OTA_MANIFEST_URL is not mentioned, check the command again." "MAKE" "NULL"; \
		[ -z "$${SkipSign}" ] && abort "- SkipSign is not mentioned, either set it to true to skip signing or false to sign." "MAKE" "NULL"; \
		console_print "Building UN1CA updater for Tsukika.."; \
		tar -C ./src/tsukika/packages/TsukikaUpdater/ -xf ./src/tsukika/packages/TsukikaUpdater/TsukikaUpdaterSmaliFiles.tar 2>/dev/null || abort "Failed to extract the tar file to build the package."; \
		for file in ./src/tsukika/packages/TsukikaUpdater/smali_classes15/com/mesalabs/ten/update/ota/ROMUpdate\$$LoadUpdateManifest.smali ./src/tsukika/packages/TsukikaUpdater/smali_classes16/com/mesalabs/ten/update/ota/utils/Constants.smali; do \
			sed -i "s|$(OLD_REFERENCE_URL)|$${OTA_MANIFEST_URL}|g" "$${file}" || abort "- Failed to change manifest provider in $$file" "MAKE" "NULL"; \
		done; \
		java -jar $(APKTOOL_JAR) build "./src/tsukika/packages/TsukikaUpdater/" &>>$(ERR_LOG) || abort "- Failed to build the application. Please check $(ERR_LOG) for the logs." "MAKE" "NULL"; \
		if [ "$${SkipSign}" = "true" ]; then \
		 	console_print "Skipping signing process..."; \
		else \
			console_print "Signing the application..."; \
			java -jar $(UBER_SIGNER_JAR) \
			--verbose \
			--apk ./src/tsukika/packages/TsukikaUpdater/dist/TsukikaUpdater.apk \
			--ks $(MY_KEYSTORE_PATH) \
			--ksAlias $(MY_KEYSTORE_ALIAS) \
			--ksPass $(MY_KEYSTORE_PASSWORD) \
			--ksKeyPass $(MY_KEYSTORE_ALIAS_KEY_PASSWORD) &>/dev/null; \
			[ -f "./src/tsukika/packages/TsukikaUpdater/dist/TsukikaUpdater-aligned-signed.apk" ] && console_print "Signed APK: ./src/tsukika/packages/TsukikaUpdater/dist/TsukikaUpdater-aligned-signed.apk"; \
		fi; \
		exit 0; \
	'

# Test bootloopSaviour
test_bootloopsaviour:
	@if [ -f "$(SAVIOUR_OUTPUT)" ]; then \
		if "$(SAVIOUR_OUTPUT)" --test >/dev/null 2>&1; then \
			echo -e "\e[0;33mmake: Info: Test passed: $(SAVIOUR_OUTPUT) works as expected!\e[0;37m"; \
		else \
			echo -e "\e[0;31mmake: Error: Test failed: $(SAVIOUR_OUTPUT) may not be compatible with this system."; \
			echo -e "    Possible reasons:"; \
			echo -e "      - Running on a non-ARM machine"; \
			echo -e "      - Syntax Errors in the code (or) Build Failure\e[0;37m"; \
		fi; \
	else \
		echo -e "\e[0;31mmake: Error: $(SAVIOUR_OUTPUT) not found. Building it...\e[0;37m"; \
		$(MAKE) bootloop_saviour && $(MAKE) test_bootloopsaviour; \
	fi

# Test setupCustomizer
test_setupCustomizer:
	@if [ -f "$(STUPCUSTOMIZER_MAIN)" ]; then \
		if "$(STUPCUSTOMIZER_MAIN)" --test >/dev/null 2>&1; then \
			echo -e "\e[0;33mmake: Info: Test passed: $(STUPCUSTOMIZER_MAIN) works as expected!\e[0;37m"; \
		else \
			echo -e "\e[0;31mmake: Error: Test failed: $(STUPCUSTOMIZER_MAIN) may not be compatible with this system."; \
			echo -e "    Possible reasons:"; \
			echo -e "      - Running on a non-ARM machine"; \
			echo -e "      - Syntax Errors in the code (or) Build Failure\e[0;37m"; \
		fi; \
	else \
		echo -e "\e[0;31mmake: Error: $(STUPCUSTOMIZER_MAIN) not found. Building it...\e[0;37m"; \
		$(MAKE) setupCustomizer && $(MAKE) test_setupCustomizer; \
	fi

# help menu:
help:
	@echo -e "\e[1;36mUsage:\e[0m"
	@echo -e "  \e[1;33mmake <target> [VARIABLE=value]\e[0m"
	@echo -e ""
	@echo -e "\e[1;36mC Build Targets (requires SDK=<version>):\e[0m"
	@echo -e "  \e[1;32mall\e[0m                       Build all components"
	@echo -e "  \e[1;32mbootloop_saviour\e[0m          Build bootloopSaviour"
	@echo -e "  \e[1;32msetupCustomizer\e[0m           Build setupCustomizer"
	@echo -e ""
	@echo -e "\e[1;36mC Test Targets (requires SDK=<version>):\e[0m"
	@echo -e "  \e[1;32mtest\e[0m                      Test all C buildable programs"
	@echo -e "  \e[1;32mtest_bootloopsaviour\e[0m      Test bootloopSaviour"
	@echo -e "  \e[1;32mtest_setupCustomizer\e[0m      Test setupCustomizer"
	@echo -e ""
	@echo -e "\e[1;36mGeneral Targets:\e[0m"
	@echo -e "  \e[1;33mOTA_MANIFEST_URL=<url> SkipSign=true|false UN1CAUpdater\e[0m"
	@echo -e "                           Build UN1CA Updater with the provided OTA manifest URL\n"
	@echo -e "  \e[1;32mclean\e[0m                    Clean up build artifacts"
	@echo -e "  \e[1;32mhelp\e[0m                     Show this help message"
	@echo -e ""

# Build and test everything
test: test_bootloopsaviour

# Clean up
clean:
	@rm -f $(SAVIOUR_OUTPUT) $(ERR_LOG) $(STUPCUSTOMIZER_OUTPUT) ./src/tsukika/packages/TsukikaUpdater/dist/ ./src/tsukika/packages/TsukikaUpdater/original/ ./src/tsukika/packages/TsukikaUpdater/build/

.PHONY: all bootloop_saviour UN1CAUpdater test_bootloopsaviour check_compiler test clean help