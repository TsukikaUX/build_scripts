//
// Copyright (C) 2025 ぼっち <ayumi.aiko@outlook.com>
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.
//
#ifndef TSUKIKA
#define TSUKIKA
#include <string.h>
#include <stdio.h>
#include <stdbool.h>
#include <stdlib.h>
#include <unistd.h>
#include <stdint.h>
#include <sys/system_properties.h>
#include <tsukikautils.h>

// extern variables.
extern int batteryPercentageBlobIndex;
extern char *_Nonnull codenameForThisBinary;
extern char *_Nonnull batteryPercentageBlobFilePaths[];
extern char *_Nonnull const resetprop;

/*
It's worth noting a historical caveat about popen in Android NDK:
    - in very old Android versions (pre-ICS, around Android 4.0), popen() could be buggy due to its use of vfork(),
      potentially causing stack corruption. Modern Android versions and NDK releases have addressed this, so it should be safe to use now.
    
    - While it's technically supported, remember that direct execution of shell commands via popen()
      should be used with caution and only when strictly necessary, as it can introduce security vulnerabilities if not handled carefully.
*/

typedef struct {
    int found; // Hey google, shut it up!
    uint32_t propertySerial;
    char propertyName[PROP_NAME_MAX];
    char propertyValue[PROP_VALUE_MAX];
} PropertyHandler;

// used for verifying if we are in a expected state.
enum expectedDeviceState {
	DEVICE_SETUP_OVER,
	BOOTANIMATION_RUNNING,
	BOOTANIMATION_EXITED,
	DEVICE_BOOT_COMPLETED,
	DEVICE_TURNED_ON
};

// used for stopping/starting the daemon given.
enum setDaemonPropertyState {
	DAEMON_START,
	DAEMON_STOP
};

// used for preparing open recovery script.
enum openRecoveryScriptNextCommand {
	WIPE_DATA,
	WIPE_CACHE,
	INSTALL_PACKAGE,
	SWITCH_LOCALE
};

// used for tracking the current init state- no, it's not
// it's repurposed for tsukika_modules now
enum bootTraceState {
	LATE_FS,
	INIT,
	POST_FS,
	POST_FS_DATA,
	BOOT_COMPLETED,
};

// used for manipulating the system settings configs:
enum systemTable {
	TABLE_SECURE,
	TABLE_GLOBAL,
	TABLE_SYSTEM
};

// for managing/manipulating properties.
enum propertyTinkerState {
    MAYBE_SETPROP,
    SET_IF_DIFF, 
    REMOVE_PROPERTY, 
    SETPROP,
    MATCHED_WITH_EXPECTED
};

// function declarations.
int isPackageInstalled(const char *_Nonnull packageName);
int getBatteryPercentage();
bool manageProperty(char *_Nonnull property, void*_Nullable expressivePropertyValue, enum propertyTinkerState propertyState);
bool getDeviceState(enum expectedDeviceState exptx);
bool setSystemSettings(enum systemTable table, char *_Nonnull name, char *_Nullable value);
char *_Nullable getSystemSettings(enum systemTable table, char *_Nonnull name, bool skipNewlinesAtStart);
char *_Nullable getSystemProperty(const char *_Nonnull propertyVariableName);
void alertUser(char *_Nonnull message);
void prepareStockRecoveryCommandFile(enum openRecoveryScriptNextCommand ors, char * _Nullable actionArgOne, char * _Nullable actionArgTwo);
void daemonStateManager(enum setDaemonPropertyState daemonProp, char *_Nonnull daemonName);
void androidPropertyCallback(void*_Nonnull cookie, const char*_Nonnull name, const char*_Nonnull value, uint32_t serial);
#endif
