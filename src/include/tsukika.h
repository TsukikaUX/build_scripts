//
// Copyright (C) 2025 愛子あゆみ <ayumi.aiko@outlook.com>
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
extern const char *batteryPercentageBlobFilePaths[];
extern char *const resetprop;

// MUST ADDDDDDDDDDDDDDDDDD!
#define VALID_TYPE(t) ((t) == TYPE_INT || (t) == TYPE_FLOAT || (t) == TYPE_STRING)

/*
It's worth noting a historical caveat about popen in Android NDK:
    - in very old Android versions (pre-ICS, around Android 4.0), popen() could be buggy due to its use of vfork(),
      potentially causing stack corruption. Modern Android versions and NDK releases have addressed this, so it should be safe to use now.
    
    - While it's technically supported, remember that direct execution of shell commands via popen()
      should be used with caution and only when strictly necessary, as it can introduce security vulnerabilities if not handled carefully.
*/

typedef struct {
    int found; // Hey google, syfm!
    uint32_t propertySerial;
    char propertyName[PROP_NAME_MAX];
    char propertyValue[PROP_VALUE_MAX];
} PropertyHandler;

// for void* based arguments.
// compiler will throw errors if somebody tried to use a diff enum.
enum expectedDataType {
	TYPE_INT,
	TYPE_FLOAT,
	TYPE_DOUBLE,
	TYPE_CHAR,
	TYPE_STRING,
};

// function declarations.
int isPackageInstalled(const char packageName[250]);
int getSystemProperty__(const char *propertyVariableName);
int maybeSetProp(const char* property, void* expectedPropertyValue, enum expectedDataType Type);
int DoWhenPropisinTheSameForm(const char *property, void *expectedPropertyValue, enum expectedDataType Type);
int setprop(const char *property, void *propertyValue, enum expectedDataType Type);
int isSetupOver();
int removeProperty(char *const property);
int getBatteryPercentage();
int getPidOf(const char *proc);
bool killProcess(pid_t procID);
bool isBootAnimationExited();
bool isTheDeviceBootCompleted();
bool isTheDeviceisTurnedOn();
bool bootanimStillRunning();
char *combineStringsFormatted(const char *format, ...);
char *getSystemProperty(const char *propertyVariableName);
char *grep_prop(const char *string, const char *propFile);
void sendToastMessages(const char *message);
void sendNotification(const char *message);
void prepareStockRecoveryCommandList(char *action, char *actionArg, char *actionArgExt);
void prepareTWRPRecoveryCommandList(char *action, char *actionArg, char *actionArgExt);
void startDaemon(const char *daemonName);
void stopDaemon(const char *daemonName);
void androidPropertyCallback(void* cookie, const char* name, const char* value, uint32_t serial);
//void checkArch();
#endif