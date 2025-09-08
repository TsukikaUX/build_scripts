#include <dirent.h>
#include <tsukika.h>
const char *filesToRemoveBeforeReboot[] = {
    "/cache/.system_booting",
    "/data/unencrypted/.system_booting",
    "/metadata/.system_booting",
    "/persist/.system_booting",
    "/mnt/vendor/persist/.system_booting"
};
const char *batteryPercentageBlobFilePaths[] = {
    "/sys/bus/platform/devices/battery/power_supply/battery/capacity", 
    NULL
};
char *LOGFILE = "/data/adb/Tsukika/logs/Tsukika.log";
char *const resetprop = "/data/adb/Tsukika/bin/resetprop";
const char *base_path = "/data/adb/modules/";
const char *suffix = "/disable";
bool useStdoutForAllLogs = false;

void disableMagiskModules() {
    DIR *dirptr = opendir("/data/adb/modules/");
    if(!dirptr) abort_instance("bootloopSaviour", "Failed to open module directory!");
    struct dirent *entry;
    while((entry = readdir(dirptr)) != NULL) {
        if(entry->d_type == DT_DIR) {
            if(strcmp(entry->d_name, "..") == 0 || strcmp(entry->d_name, ".") == 0) continue;
            size_t sizeOfTheString = strlen(base_path) + strlen(entry->d_name) + strlen(suffix) + 1;
            char *alllocatedChar = malloc(sizeOfTheString);
            if(!alllocatedChar) {
                consoleLog(LOG_LEVEL_ERROR, "bootloopSaviour", "disableMagiskModules(): Failed to allocate memory for locating module path!");
                continue;
            }
            int written = snprintf(alllocatedChar, sizeOfTheString, "%s%s%s", base_path, entry->d_name, suffix);
            if(written < 0 || (size_t)written >= sizeOfTheString) {
                consoleLog(LOG_LEVEL_WARN, "bootloopSaviour", "disableMagiskModules(): Path creation failed for module: %s", entry->d_name);
                free(alllocatedChar);
                continue;
            }
            erase_file_content(alllocatedChar);
            free(alllocatedChar);
        }
    }
    closedir(dirptr);
    for(int i = 0; i < sizeof(filesToRemoveBeforeReboot) / sizeof(filesToRemoveBeforeReboot[0]); i++) remove(filesToRemoveBeforeReboot[i]);
    executeCommands("reboot", (char *const[]) {"reboot", NULL}, false);
}

int main() {
    int zygote_pid = getSystemProperty__("init.svc_debug_pid.zygote");
    consoleLog(LOG_LEVEL_DEBUG, "bootloopSaviour", "main(): Sleeping for 5s to get the new or old zygote pid....");
    sleep(5);
    int zygote_pid2 = getSystemProperty__("init.svc_debug_pid.zygote");
    consoleLog(LOG_LEVEL_DEBUG, "bootloopSaviour", "main(): Zygote PID: %d", zygote_pid);
    sleep(5);
    int zygote_pid3 = getSystemProperty__("init.svc_debug_pid.zygote");
    if(zygote_pid <= 1) disableMagiskModules();
    if(zygote_pid != zygote_pid2 || zygote_pid2 != zygote_pid3) {
        sleep(15);
        int zygote_pid4 = getSystemProperty__("init.svc_debug_pid.zygote");
        if(zygote_pid3 != zygote_pid4) disableMagiskModules();
    }
    consoleLog(LOG_LEVEL_DEBUG, "bootloopSaviour", "main(): BootloopSaviour has finished its job, exiting now.");
    return 0;
}