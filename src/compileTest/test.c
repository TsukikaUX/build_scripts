#include <tsukika.h>
char *batteryPercentageBlobFilePaths[] = {NULL};
char *const resetprop = NULL;
char *LOGFILE = "hua";
bool useStdoutForAllLogs = true;
int main(void) {
    printf("TARGET_BUILD_SETUP_WIZARD_OUTRO_TEXT: %s\n", grep_prop("TARGET_BUILD_SETUP_WIZARD_OUTRO_TEXT", "./src/makeconfigs.prop"));
    return 0;
}
