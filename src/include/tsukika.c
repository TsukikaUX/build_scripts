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
#include <tsukika.h>
#include <tsukikautils.h>

int isPackageInstalled(const char *packageName) {
    FILE *fptr = popen("pm list packages | cut -d ':' -f 2", "r");
    if(!fptr) return -1;
    char string[1024];
    while(fgets(string, sizeof(string), fptr) != NULL) {
        string[strcspn(string, "\n")] = '\0';
        if(strcmp(string, packageName) == 0) {
            fclose(fptr);
            return 0;
        }
    }
    fclose(fptr);
    return 1;
}

int getSystemProperty__(const char *propertyVariableName) {
    // Update: use native functions from android-ndk itself!
    const prop_info* pi = __system_property_find(propertyVariableName);
    if(pi) {
        PropertyHandler ctx = {0};
        __system_property_read_callback(pi, androidPropertyCallback, &ctx);
        return atoi(ctx.propertyValue);
    }
    else {
        consoleLog(LOG_LEVEL_ERROR, "getSystemProperty__", "%s not found in system, trying to gather property value from resetprop...", propertyVariableName);
        FILE *fptr = popen(combineStringsFormatted("%s %s", resetprop, propertyVariableName), "r");
        if(!fptr) {
            consoleLog(LOG_LEVEL_ERROR, "getSystemProperty__", "uh, major hiccup, failed to open resetprop in popen()");
            return -1;
        }
        char eval[PROP_VALUE_MAX];
        fgets(eval, sizeof(eval), fptr);
        // remove the dawn newline char to get a clear value.
        eval[strcspn(eval, "\n")] = '\0';
        fclose(fptr);
        return atoi(eval);
    }
    return -1;
}

int maybeSetProp(char* property, void* expectedPropertyValue, enum expectedDataType Type) {
    if(!property || !expectedPropertyValue) return -1;
    char buffer[PROP_VALUE_MAX];
    char* castValueStr = NULL;
    switch(Type) {
        case TYPE_INT: {
            int castValue = *(int*)expectedPropertyValue;
            snprintf(buffer, sizeof(buffer), "%d", castValue);
            castValueStr = buffer;
        }
        break;
        case TYPE_FLOAT: {
            float castValue = *(float*)expectedPropertyValue;
            snprintf(buffer, sizeof(buffer), "%g", castValue);
            castValueStr = buffer;
        }
        break;
        case TYPE_STRING:
        default: {
            castValueStr = (char*)expectedPropertyValue;
        }
    }
    char* currentValue = strdup(getSystemProperty(property));
    if(!currentValue) return -1;
    if(strcmp(currentValue, castValueStr) != 0) return executeCommands(resetprop, (char* const[]){ resetprop, (char*)property, (char*)castValueStr, NULL }, 0);
    else return -1;
}

int doWhenPropValueIsMatchedWithExpected(const char *property, void *expectedPropertyValue, enum expectedDataType Type) {
    char buffer[PROP_VALUE_MAX];
    switch(Type) {
        case TYPE_INT: {
            int castValue = *(int *)expectedPropertyValue;
            snprintf(buffer, sizeof(buffer), "%d", castValue);
            return (getSystemProperty(property) == buffer);
        }
        case TYPE_FLOAT: {
            float castValue = *(float *)expectedPropertyValue;
            snprintf(buffer, sizeof(buffer), "%.2f", castValue);
            return strcmp(getSystemProperty(property), buffer);
        }
        case TYPE_STRING:
        default:
            return strcmp(getSystemProperty(property), (const char *)expectedPropertyValue);
    }
    return 1;
}

int setprop(char *property, void *propertyValue, enum expectedDataType Type) {
    char buffer[PROP_VALUE_MAX];
    char *castValueStr = NULL;
    consoleLog(LOG_LEVEL_DEBUG, "setprop", "Trying to change the requested prop's value...");
    switch(Type) {
        case TYPE_INT: {
            int castValue = *(int *)propertyValue;
            snprintf(buffer, sizeof(buffer), "%d", castValue);
            castValueStr = buffer;
        }
        case TYPE_FLOAT: {
            float castValue = *(float *)propertyValue;
            snprintf(buffer, sizeof(buffer), "%.2f", castValue);
            castValueStr = buffer;
        }
        case TYPE_STRING:
        default:
            castValueStr = (char *)propertyValue;
    }
    if(executeCommands(resetprop, (char *const[]) {resetprop, property, castValueStr, NULL}, false) == 0) return 0;
    consoleLog(LOG_LEVEL_WARN, "setprop", "Failed to set requested property!");
    return 1;
}

int setpropIfDifferent(char *property, void *propertyValue, enum expectedDataType Type) {
    if(!property || !propertyValue) return -1;
    char buffer[PROP_VALUE_MAX];
    char* castValueStr = NULL;
    switch(Type) {
        case TYPE_INT: {
            int castValue = *(int*)propertyValue;
            snprintf(buffer, sizeof(buffer), "%d", castValue);
            castValueStr = buffer;
        }
        break;
        case TYPE_FLOAT: {
            float castValue = *(float*)propertyValue;
            snprintf(buffer, sizeof(buffer), "%g", castValue);
            castValueStr = buffer;
        }
        break;
        case TYPE_STRING:
        default: {
            castValueStr = (char*)propertyValue;
        }
    }
    char* currentValue = getSystemProperty(property);
    if(strcmp(currentValue, castValueStr) == 0) return 1;
    else return executeCommands(resetprop, (char* const[]){ resetprop, property, castValueStr, NULL }, 0);
}

int removeProperty(char *const property) {
    return executeCommands(resetprop, (char *const[]){resetprop, "-d", property}, false);
}

int getBatteryPercentage() {
    const char *blobPath;
    size_t sizeTea = sizeof((char *)batteryPercentageBlobFilePaths) / sizeof((char *)batteryPercentageBlobFilePaths[0]);
    for(size_t i = 0; i < sizeTea; i++) {
        if(access(batteryPercentageBlobFilePaths[i], F_OK) == 0) {
            blobPath = batteryPercentageBlobFilePaths[i];
            break;
        }
        // return -1 if we cannot find the correct blob.
        else if(i == sizeTea) return -1;
    }
    FILE *fptr = fopen(blobPath, "r");
    // return -1 if we cannot open the file.
    if(!fptr) return -1;
    // localhost@christian:~$ echo "10" | wc -c
    // 3
    // localhost@christian:~$ echo "100" | wc -c
    // 4
    // uh, 5-6 should be more than enough i guess...
    char percent[6];
    fgets(percent, sizeof(percent), fptr);
    percent[strcspn(percent, "\n")] = '\0';
    fclose(fptr);
    return atoi(percent);
}

int getPidOf(const char *proc) {
    FILE *fptr = popen(combineStringsFormatted("pidof %s", proc), "r");
    if(!fptr) return -1;
    char procID[8];
    fgets(procID, sizeof(procID), fptr);
    fclose(fptr);
    return atoi(procID);
}

bool killProcess(pid_t procID) {
    return (executeCommands("kill", (char *const[]) {"kill", combineStringsFormatted("%d", procID)}, false) == 0);
}

bool getDeviceState(enum expectedDeviceState exptx) {
    char *currentSetupWizardMode = getSystemProperty("ro.setupwizard.mode");
    if(!currentSetupWizardMode) return false;
    switch(exptx)
    {
        case DEVICE_SETUP_OVER:
            if(strcmp(getSystemProperty("persist.sys.setupwizard"), "FINISH") == 0 || strcmp(currentSetupWizardMode, "OPTIONAL")  == 0 || strcmp(currentSetupWizardMode, "DISABLED") == 0) return true;
        case BOOTANIMATION_RUNNING:
            return (getSystemProperty__("service.bootanim.progress") == 1);
        case BOOTANIMATION_EXITED:
            return (getSystemProperty__("service.bootanim.exit") == 1);
        case DEVICE_BOOT_COMPLETED:
            return (getSystemProperty__("sys.boot_completed") == 1);
        case DEVICE_TURNED_ON: {
            FILE *fp = popen("dumpsys power | grep 'Display Power'", "r");
            if(!fp) {
                consoleLog(LOG_LEVEL_ERROR, "getDeviceState", "Failed to open stdout to gather information about the device display power status.");
                return false;
            }
            char buffer[4];
            fgets(buffer, sizeof(buffer), fp);
            pclose(fp);
            return (strstr(buffer, "OFF") == NULL);
        }
    }
    return false;
}

// this is the one of the most lamest function here, thank me later!
bool setSystemSettings(enum systemTable table, char *name, char *value)
{
    char *state;
    switch(table)
    {
        case TABLE_GLOBAL:
            state = "global";
        break;    
        case TABLE_SECURE:
            state = "global";
        break;
        case TABLE_SYSTEM:
        default:
            state = "system";
        break;
    }
    // since we can only use cli for now, let's just abuse it for now. 
    // i know it sounds bad to pro people who could set up a literal 
    // socket to manage things between the system, i promise you
    // i will do that one day if i learn them, till then, peace ✌🏻
    return (executeCommands("settings", (char *const[]) {"settings", "put", (char *)state, name, value}, false) == 0);
}

// cast the value as an int, float or even a bool if you know wat you are getting.
char *getSystemSettings(enum systemTable table, char *name, bool skipNewlinesAtStart)
{
    int index = 0;
    char *state;
    char *command;
    char value[1024];
    switch(table)
    {
        case TABLE_GLOBAL:
            state = "global";
        break;    
        case TABLE_SECURE:
            state = "secure";
        break;
        case TABLE_SYSTEM:
        default:
            state = "system";
        break;
    }
    size_t sizeOfCommand = strlen(name) + strlen(state) + strlen("settings get ") + 2;
    command = malloc(sizeOfCommand);
    if(!command)
    {
        consoleLog(LOG_LEVEL_ERROR, "getSystemSettings", "Failed to get system settings value. Please try again.");
        consoleLog(LOG_LEVEL_DEBUG, "getSystemSettings", "!command");
        return NULL;
    }
    snprintf(command, sizeOfCommand, "settings get %s %s", state, name);
    FILE *fptr = popen(command, "r");
    if(!fptr)
    {
        __freeThisPointer((void**)&command);
        consoleLog(LOG_LEVEL_ERROR, "getSystemSettings", "Failed to get system settings value. Please try again.");
        consoleLog(LOG_LEVEL_DEBUG, "getSystemSettings", "!fptr");
        return NULL;
    }
    while(fgets(value, sizeof(value), fptr))
    {
        // if we suspect a NULL newline value at the beginning and sspecially in a certain circumstance, let's just put a useless warning and end the loop 
        // if and only the dev thinks that this is a weird unga bunga moment.
        if(skipNewlinesAtStart && index == 0 && strcspn(value, "\n") == 0)
        {
            __freeThisPointer((void**)&command);
            pclose(fptr);
            consoleLog(LOG_LEVEL_ERROR, "getSystemSettings", "Provided system table variable does not seem to have a value.");
            return NULL;
        }
        // we'll increment this just to not hit that if statement:
        index++;
    }
    __freeThisPointer((void**)&command);
    pclose(fptr);
    return strdup(value);
}

char *getSystemProperty(const char *propertyVariableName) {
    // Update: use native functions from android-ndk itself!
    const prop_info* pi = __system_property_find(propertyVariableName);
    static char globalPropertyValueBuffer[PROP_VALUE_MAX];
    if(pi) {
        PropertyHandler ctx = {0};
        __system_property_read_callback(pi, androidPropertyCallback, &ctx);
        snprintf(globalPropertyValueBuffer, PROP_VALUE_MAX, "%s", ctx.propertyValue);
        return globalPropertyValueBuffer;
    }
    else {
        consoleLog(LOG_LEVEL_ERROR, "getSystemProperty", "%s not found in system, trying to gather property value from resetprop...", propertyVariableName);
        FILE *fptr = popen(combineStringsFormatted("%s %s", resetprop, propertyVariableName), "r");
        if(!fptr) {
            consoleLog(LOG_LEVEL_ERROR, "getSystemProperty", "uh, major hiccup, failed to open resetprop in popen()");
            return NULL;
        }
        // remove the dawn newline char to get a clear value.
        fgets(globalPropertyValueBuffer, PROP_VALUE_MAX, fptr);
        globalPropertyValueBuffer[strcspn(globalPropertyValueBuffer, "\n")] = '\0';
        fclose(fptr);
        return globalPropertyValueBuffer;
    }
    return NULL;
}

void alertUser(char *message) {
    if(getDeviceState(DEVICE_BOOT_COMPLETED) != 0) return;
    if(isPackageInstalled("bellavita.toast") == 0) executeCommands("am", (char *const[]) {"am", "start", "-a", "android.intent.action.MAIN", "-e", "toasttext", message, "-n", "bellavita.toast/.MainActivity", NULL}, false);
    else executeCommands("cmd", (char *const[]) {"cmd", "notification", "post", "-S", "bigtext", "-t", "Tsukika", "Tag", message, NULL}, false);
}

void prepareStockRecoveryCommandFile(enum openRecoveryScriptNextCommand ors, char *actionArgOne, char *actionArgTwo) {
    makeDir("/cache/recovery");
    FILE *recoveryCommandFile = fopen("/cache/recovery/command", "w");
    if(!recoveryCommandFile) abort_instance("prepareStockRecoveryCommandFile", "Failed to open recovery command file to prepare given action on next boot.");
    if(ors == WIPE_DATA) fputs("--wipe_data\n", recoveryCommandFile);
    else if(ors == WIPE_CACHE) fputs("--wipe_cache\n", recoveryCommandFile);
    else if(ors == INSTALL_PACKAGE) fprintf(recoveryCommandFile, "--update_package=%s\n", actionArgOne);
    else if(ors == SWITCH_LOCALE) fprintf(recoveryCommandFile, "--locale=%s_%s\n", stringCase(actionArgOne, LOWER), stringCase(actionArgTwo, UPPER));
    fclose(recoveryCommandFile);
}

void daemonStateManager(enum setDaemonPropertyState daemonProp, char *daemonName) {
    if(daemonProp == DAEMON_START) {
        if(setprop("ctl.start", (void *)daemonName, TYPE_STRING) == 0) consoleLog(LOG_LEVEL_INFO, "startDaemon", "Daemon %s started successfully.", daemonName);
        else consoleLog(LOG_LEVEL_WARN, "daemonStateManager", "Failed to start %s daemon service.", daemonName);
    }
    else if(daemonProp == DAEMON_STOP) {
        if(setprop("ctl.stop", (void *)daemonName, TYPE_STRING) == 0) consoleLog(LOG_LEVEL_INFO, "stopDaemon", "Daemon %s stopped successfully.", daemonName);
        else consoleLog(LOG_LEVEL_WARN, "daemonStateManager", "Failed to stop %s daemon service.", daemonName);
    }
}

void androidPropertyCallback(void* cookie, const char* name, const char* value, uint32_t serial) {
    PropertyHandler* handler = (PropertyHandler*)cookie;
    if(handler == NULL) 
    {
        fprintf(stderr, "Error: Callback 'cookie' (PropertyHandler pointer) is NULL!\n");
        return;
    }
    snprintf(handler->propertyName, sizeof(handler->propertyName), "%s", name);
    snprintf(handler->propertyValue, sizeof(handler->propertyValue), "%s", value);
    handler->propertySerial = serial;
    handler->found = 1;
}
