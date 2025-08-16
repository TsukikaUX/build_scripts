#include <tsukika.h>

// misc
char *LOGFILE = "/data/adb/Tsukika/logs/Tsukika.log";
bool useStdoutForAllLogs = false;

// resetprop path:
char *const resetprop = "/data/adb/Tsukika/bin/resetprop";

int main() {
    consoleLog(LOG_LEVEL_DEBUG, "setupCustomizer", "main(): Started initialization!");
    if(isSetupOver() == 1 && bootanimStillRunning()) {
        if(executeCommands("settings", (char *const[]){"settings", "put", "secure", "ui_night_mode", "1"}, false) == 0) consoleLog(LOG_LEVEL_DEBUG, "setupCustomizer", "main(): Attempt to set the theme to dark passed.");
        else consoleLog(LOG_LEVEL_DEBUG, "setupCustomizer", "main(): Attempt to set the theme to dark failed.");
        return 0;
    }
    char *propertyVariableNameStrSpoofs[] = {
        "ro.boot.vbmeta.device_state",
        "ro.boot.verifiedbootstate",
        "ro.boot.veritymode",
        "ro.build.type",
        "ro.build.tags",
        "vendor.boot.vbmeta.device_state",
        "vendor.boot.verifiedbootstate",
        "ro.secureboot.lockstate",
        "ro.boot.warranty_bit",
        "ro.boot.flash.locked",
        "ro.warranty_bit",
        "ro.debuggable",
        "ro.secure",
        "ro.adb.secure",
        "ro.vendor.boot.warranty_bit",
        "ro.vendor.warranty_bit"
    };
    char *propertyVariableValueStrSpoofs[] = {
        "locked",
        "green",
        "enforcing",
        "user",
        "release-keys",
        "locked",
        "green",
        "locked",
        "0",
        "1",
        "0",
        "0",
        "1",
        "1",
        "0",
        "0"
    };
    char *propertyVariableNameStrMB[] = {
        "ro.bootmode",
        "ro.boot.bootmode",
        "vendor.boot.bootmode"
    };
    char *propertiesToRemove[] = {
        "persist.log.tag.LSPosed",
        "persist.log.tag.LSPosed-Bridge",
        "ro.build.selinux"
    };
    consoleLog(LOG_LEVEL_DEBUG, "setupCustomizer", "main(): Trying to set properties for spoofing device locked status..");
    for(int i = 0; i < sizeof(propertyVariableNameStrSpoofs) / sizeof(propertyVariableNameStrSpoofs[0]); i++) {
        // int setprop(const char *property, void *propertyValue, enum expectedDataType Type);
        if(setprop(propertyVariableNameStrSpoofs[i], propertyVariableValueStrSpoofs[i], TYPE_STRING) != 0) consoleLog(LOG_LEVEL_ERROR, "setupCustomizer", "main(): Cannot set property %s to %s", propertyVariableNameStrSpoofs[i], propertyVariableValueStrSpoofs[i]);
    }
    consoleLog(LOG_LEVEL_DEBUG, "setupCustomizer", "main(): Trying to set properties for spoofing previous boot mode..");
    for(int i = 0; i < sizeof(propertyVariableNameStrMB) / sizeof(propertyVariableNameStrMB[0]); i++) {
        if(maybeSetProp(propertyVariableNameStrMB[i], "recovery", "unknown", TYPE_STRING) != 0) consoleLog(LOG_LEVEL_ERROR, "setupCustomizer", "main(): Cannot set property %s to %s", propertyVariableNameStrSpoofs[i], propertyVariableValueStrSpoofs[i]);
    }
    consoleLog(LOG_LEVEL_DEBUG, "setupCustomizer", "main(): Trying to delete LSPosed and misc properties..");
    for(int i = 0; i < sizeof(propertiesToRemove) / sizeof(propertiesToRemove[0]); i++) {
        if(removeProperty(propertiesToRemove[i]) != 0) consoleLog(LOG_LEVEL_ERROR, "setupCustomizer", "main(): Cannot set property %s to %s", propertiesToRemove[i], propertiesToRemove[i]);
    }
    system("for U in $(ls /data/user); do "
           "for C in \"auth.managed.admin.DeviceAdminReceiver\" \"mdm.receivers.MdmDeviceAdminReceiver\"; do "
           "pm disable --user $U com.google.android.gms/com.google.android.gms.$C; "
           "done; "
           "done");
    char *GMS0 = "\"com.google.android.gms\"";
    char cmd[1024];
    snprintf(cmd, sizeof(cmd),
             "STR1=\"allow-unthrottled-location package=%s\"; "
             "STR2=\"allow-ignore-location-settings package=%s\"; "
             "STR3=\"allow-in-power-save package=%s\"; "
             "STR4=\"allow-in-data-usage-save package=%s\"; "
             "find /data/adb/* -type f -iname \"*.xml\" -print | "
             "while IFS= read -r XML; do "
             "for X in $XML; do "
             "if grep -qE \"$STR1|$STR2|$STR3|$STR4\" $X 2>/dev/null; then "
             "sed -i \"/$STR1/d;/$STR2/d;/$STR3/d;/$STR4/d\" $X; "
             "fi; "
             "done; "
             "done",
             GMS0, GMS0, GMS0, GMS0);
    system(cmd);
    system("dumpsys deviceidle whitelist com.google.android.gms");
    consoleLog(LOG_LEVEL_DEBUG, "setupCustomizer", "main(): Finalized!");
}