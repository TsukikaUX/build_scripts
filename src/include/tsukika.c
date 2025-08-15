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

#include <tsukika.h>
#include <tsukikautils.h>

int isPackageInstalled(const char *packageName) {
    // Prevents command injection attempts
    if(strchr(packageName, ';') != NULL || strcmp(packageName, "&&") == 0 || strcmp(packageName, "||") == 0) abort_instance("isPackageInstalled(): Malicious intent in the given argument detected!");
    FILE *fptr = popen("pm list packages | cut -d ':' -f 2", "r");
    if(!fptr) return -1;
    char string[1000];
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
        /* - THIS WAS INTENDED FOR DEBUGGING! PLEASE DONT UN-COMMENT THESE UNLESS YOU KNOW WHAT ARE YOU DOING!
        consoleLog(LOG_LEVEL_DEBUG, "###########################");
        consoleLog(LOG_LEVEL_DEBUG, "Requested property details:");
        consoleLog(LOG_LEVEL_DEBUG, "NAME: %d", handler.propertyName);
        consoleLog(LOG_LEVEL_DEBUG, "VALUE: %d", handler.propertyValue);
        consoleLog(LOG_LEVEL_DEBUG, "SERIAL: %d", handler.propertySerial);
        consoleLog(LOG_LEVEL_DEBUG, "###########################");
        */
        return atoi(ctx.propertyValue);
    }
    else {
        consoleLog(LOG_LEVEL_ERROR, "%s not found in system, trying to gather property value from resetprop...", propertyVariableName);
        FILE *fptr = popen(combineStringsFormatted("/system/bin/resetprop %s", propertyVariableName), "r");
        if(!fptr) {
            consoleLog(LOG_LEVEL_ERROR, "uh, major hiccup, failed to open resetprop in popen()");
            return -1;
        }
        char eval[1000];
        // remove the dawn newline char to get a clear value.
        while(fgets(eval, sizeof(eval), fptr) != NULL) eval[strcspn(eval, "\n")] = '\0';
        fclose(fptr);
        return atoi(eval);
    }
    return -1;
}

int maybeSetProp(const char *property, void *expectedPropertyValue, void *typeShyt, enum expectedDataType Type) {
    char buffer[PROP_VALUE_MAX];
    const char *castValueStr = NULL;
    switch(Type) {
        case TYPE_INT: {
            int castValue = *(int *)expectedPropertyValue;
            snprintf(buffer, sizeof(buffer), "%d", castValue);
            castValueStr = buffer;
        }
        break;
        case TYPE_FLOAT: {
            float castValue = *(float *)expectedPropertyValue;
            snprintf(buffer, sizeof(buffer), "%.2f", castValue);
            castValueStr = buffer;
        }
        break;
        case TYPE_STRING: {
            castValueStr = (const char *)expectedPropertyValue;
        }
        break;
        default:
            _Static_assert(VALID_TYPE(TYPE_INT), "Requested type must be valid, this leads to an undefined behaviour.");
            for(int i = 10; i < 0; i--) consoleLog(LOG_LEVEL_DEBUG, "maybeSetProp(): Undefined behaviour!!!!!!!!! crashing the application in: %d", i);
            abort_instance("maybeSetProp(): Force crash due to undefined behaviour, hope abort cleans the memory.");
    }
    if(strcmp(getSystemProperty(property), castValueStr) == 0) return executeCommands(resetprop, (char *const[]){resetprop, (char *)typeShyt, NULL}, 0);
    return 1;
}

int DoWhenPropisinTheSameForm(const char *property, void *expectedPropertyValue, enum expectedDataType Type) {
    char buffer[PROP_VALUE_MAX];
    const char *castValueStr = NULL;
    switch(Type) {
        case TYPE_INT: {
            int castValue = *(int *)expectedPropertyValue;
            snprintf(buffer, sizeof(buffer), "%d", castValue);
            castValueStr = buffer;
        }
        break;
        case TYPE_FLOAT: {
            float castValue = *(float *)expectedPropertyValue;
            snprintf(buffer, sizeof(buffer), "%.2f", castValue);
            castValueStr = buffer;
        }
        break;
        case TYPE_STRING: {
            castValueStr = (const char *)expectedPropertyValue;
        }
        break;
        default:
            _Static_assert(VALID_TYPE(TYPE_INT), "Requested type must be valid, this leads to an undefined behaviour.");
            for(int i = 10; i < 0; i--) consoleLog(LOG_LEVEL_DEBUG, "maybeSetProp(): Undefined behaviour!!!!!!!!! crashing the application in: %d", i);
            abort_instance("maybeSetProp(): Force crash due to undefined behaviour, hope abort cleans the memory.");
    }
    return strcmp(getSystemProperty(property), castValueStr);
}

int setprop(const char *property, void *propertyValue, enum expectedDataType Type) {
    char buffer[PROP_VALUE_MAX];
    const char *castValueStr = NULL;
    consoleLog(LOG_LEVEL_DEBUG, "setprop(): Trying to change the requested prop's value...");
    switch(Type) {
        case TYPE_INT: {
            int castValue = *(int *)propertyValue;
            snprintf(buffer, sizeof(buffer), "%d", castValue);
            castValueStr = buffer;
            consoleLog(LOG_LEVEL_DEBUG, "setprop(): %s with %d", property, castValueStr);
        }
        break;
        case TYPE_FLOAT: {
            float castValue = *(float *)propertyValue;
            snprintf(buffer, sizeof(buffer), "%.2f", castValue);
            castValueStr = buffer;
            consoleLog(LOG_LEVEL_DEBUG, "setprop(): %s with %.2f", property, castValueStr);
        }
        break;
        case TYPE_STRING: {
            castValueStr = (const char *)propertyValue;
            consoleLog(LOG_LEVEL_DEBUG, "setprop(): %s with %s", property, castValueStr);
        }
        break;
        default:
            _Static_assert(VALID_TYPE(TYPE_INT), "Requested type must be valid, this leads to an undefined behaviour.");
            for(int i = 10; i < 0; i--) consoleLog(LOG_LEVEL_DEBUG, "maybeSetProp(): Undefined behaviour!!!!!!!!! crashing the application in: %d", i);
            abort_instance("maybeSetProp(): Force crash due to undefined behaviour, hope abort cleans the memory.");
    }
    if(executeCommands(resetprop, (char *const[]) {resetprop, (char *)property, (char *)castValueStr, NULL}, false) == 0) return 0;
    consoleLog(LOG_LEVEL_WARN, "setprop(): Failed to set requested property!");
    return 1;
}

int isSetupOver() {
    char *currentSetupWizardMode = getSystemProperty("ro.setupwizard.mode");
    if(strcmp(getSystemProperty("persist.sys.setupwizard"), "FINISH") == 0) {
        if(strcmp(currentSetupWizardMode, "OPTIONAL" == 0 || strcmp(currentSetupWizardMode, "DISABLED" == 0) return 0;
    }
    return 1;
}

int removeProperty(const char *property) {
    return executeCommands(resetprop, (char *const[]){resetprop, "-d", property}, false);
}

bool isTheDeviceBootCompleted() {
    if(getSystemProperty__("sys.boot_completed") == 1) return true;
    return false;
}

bool isBootAnimationExited() {
    if(getSystemProperty__("service.bootanim.exit") == 1) return true;
    return false;
}

bool bootanimStillRunning() {
    if(getSystemProperty__("service.bootanim.progress") == 1) return true;
    return false;
}

bool isTheDeviceisTurnedOn() {
    FILE *fp = popen("dumpsys power | grep 'Display Power'", "r"); 
    if(!fp) {
        consoleLog(LOG_LEVEL_ERROR, "isTheDeviceisTurnedOn(): Failed to open stdout to gather information about the device display power status.");
        return false;
    }
    char buffer[4];
    fgets(buffer, sizeof(buffer), fp);
    pclose(fp);
    return (strstr(buffer, "OFF") == NULL);
}

char *getSystemProperty(const char *propertyVariableName) {
    // Update: use native functions from android-ndk itself!
    const prop_info* pi = __system_property_find(propertyVariableName);
    static char global_property_value_buffer[PROP_VALUE_MAX];
    if(pi) {
        PropertyHandler ctx = {0};
        __system_property_read_callback(pi, androidPropertyCallback, &ctx);
        /* - THIS WAS INTENDED FOR DEBUGGING! PLEASE DONT UN-COMMENT THESE UNLESS YOU KNOW WHAT ARE YOU DOING!
        consoleLog(LOG_LEVEL_DEBUG, "###########################");
        consoleLog(LOG_LEVEL_DEBUG, "Requested property details:");
        consoleLog(LOG_LEVEL_DEBUG, "NAME: %d", handler.propertyName);
        consoleLog(LOG_LEVEL_DEBUG, "VALUE: %d", handler.propertyValue);
        consoleLog(LOG_LEVEL_DEBUG, "SERIAL: %d", handler.propertySerial);
        consoleLog(LOG_LEVEL_DEBUG, "###########################");
        */
        snprintf(global_property_value_buffer, sizeof(global_property_value_buffer), "%s", ctx.propertyValue);
        return global_property_value_buffer;
    }
    else {
        consoleLog(LOG_LEVEL_ERROR, "%s not found in system, trying to gather property value from resetprop...", propertyVariableName);
        FILE *fptr = popen(combineStringsFormatted("%s %s", resetprop, propertyVariableName), "r");
        if(!fptr) {
            consoleLog(LOG_LEVEL_ERROR, "uh, major hiccup, failed to open resetprop in popen()");
            return NULL;
        }
        // remove the dawn newline char to get a clear value.
        while(fgets(global_property_value_buffer, sizeof(global_property_value_buffer), fptr) != NULL) global_property_value_buffer[strcspn(global_property_value_buffer, "\n")] = '\0';
        fclose(fptr);
        return global_property_value_buffer;
    }
    return NULL;
}

char *grep_prop(const char *variableName, const char *propFile) {
    FILE *filePointer = fopen(propFile, "r");
    if(!filePointer) {
        consoleLog(LOG_LEVEL_ERROR, "grep_prop(): Failed to open properties file: %s", propFile);
        return "NULL";
    }
    char theLine[8000];
    size_t lengthOfTheString = strlen(variableName);
    while(fgets(theLine, sizeof(theLine), filePointer)) {
        if(strncmp(theLine, variableName, lengthOfTheString) == 0) {
            strtok(theLine, "=");
            char *value = strtok(NULL, "\n");
            fclose(filePointer);
            return value;
        }
    }
    fclose(filePointer);
    return "NULL";
}

void sendToastMessages(const char *message) {
    if(isPackageInstalled("bellavita.toast") == 0) executeCommands("am", (char *const[]) {"am", "start", "-a", "android.intent.action.MAIN", "-e", "toasttext", (char *)message, "-n", "bellavita.toast/.MainActivity", NULL}, false);
}

void sendNotification(const char *message) {
    executeCommands("cmd", (char *const[]) {"cmd", "notification", "post", "-S", "bigtext", "-t", "Tsukika", "Tag", (char *)message, NULL}, false);
}

void prepareStockRecoveryCommandList(char *action, char *actionArg, char *actionArgExt) {
    mkdir("/cache/recovery/", 0755);
    FILE *recoveryCommand = fopen("/cache/recovery/command", "w");
    if(!recoveryCommand) abort_instance("prepareStockRecoveryCommandList(): Failed to open recovery command file for writing to prepare command list.");
    if(strcmp(action, "wipe") == 0 && strcmp(actionArg, "cache") == 0) fputs("--wipe_cache\n", recoveryCommand);
    else if(strcmp(action, "wipe") == 0 && strcmp(actionArg, "data") == 0) fputs("--wipe_data\n", recoveryCommand);
    else if(strcmp(action, "install") == 0) fprintf(recoveryCommand, "--update_package=%s\n", actionArg);
    else if(strcmp(action, "switchLocale") == 0) fprintf(recoveryCommand, "--locale=%s_%s\n", cStringToLower(actionArg), cStringToUpper(actionArgExt));
    fclose(recoveryCommand);
}

void prepareTWRPRecoveryCommandList(char *action, char *actionArg, char *actionArgExt) {
    mkdir("/cache/recovery/", 0755);
    FILE *recoveryCommand = fopen("/cache/recovery/openrecoveryscript", "a");
    if(!recoveryCommand) abort_instance("prepareTWRPRecoveryCommandList(): Failed to open recovery command file for writing to prepare command list.");
    if(strcmp(action, "wipe") == 0 && strcmp(actionArg, "cache") == 0) fputs("wipe cache\n", recoveryCommand);
    else if(strcmp(action, "wipe") == 0 && strcmp(actionArg, "data") == 0) fputs("wipe data\n", recoveryCommand);
    else if(strcmp(action, "format data") == 0) fputs("format data\n", recoveryCommand);
    else if(strcmp(action, "reboot") == 0 && (strcmp(actionArg, "recovery") == 0 || strcmp(actionArg, "poweroff") == 0 || strcmp(actionArg, "download") == 0 || strcmp(actionArg, "bootloader") == 0 || strcmp(actionArg, "edl") == 0)) fprintf(recoveryCommand, "reboot %s\n", actionArg);
    else if(strcmp(action, "install") == 0) fprintf(recoveryCommand, "install %s\n", actionArg);
    fclose(recoveryCommand);
}

void startDaemon(const char *daemonName) {
    if(setprop("ctl.start", (void *)daemonName, TYPE_STRING) == 0) consoleLog(LOG_LEVEL_INFO, "startDaemon(): Daemon %s started successfully.", daemonName);
    else consoleLog(LOG_LEVEL_WARN, "startDaemon(): Failed to start daemon %s.", daemonName);
}

void stopDaemon(const char *daemonName) {
    if(setprop("ctl.stop", (void *)daemonName, TYPE_STRING) == 0) consoleLog(LOG_LEVEL_INFO, "stopDaemon(): Daemon %s stopped successfully.", daemonName);
    else consoleLog(LOG_LEVEL_WARN, "stopDaemon(): Failed to stop daemon %s.", daemonName);
}

void androidPropertyCallback(void* cookie, const char* name, const char* value, uint32_t serial) {
    PropertyHandler* handler = (PropertyHandler*)cookie;
    if(handler == NULL) fprintf(stderr, "Error: Callback 'cookie' (PropertyHandler pointer) is NULL!\n");
    snprintf(handler->propertyName, sizeof(handler->propertyName), "%s", name);
    snprintf(handler->propertyValue, sizeof(handler->propertyValue), "%s", value);
    handler->propertySerial = serial;
    handler->found = 1;
}