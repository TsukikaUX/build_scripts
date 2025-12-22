#include <tsukika.h>
char *batteryPercentageBlobFilePaths[] = {NULL};
char *const resetprop = NULL;
char *LOGFILE = "hua";
bool useStdoutForAllLogs = true;
int main(void) {
    printf("TARGET_BUILD_SETUP_WIZARD_OUTRO_TEXT: %s\n", getpropFromFile("TARGET_BUILD_SETUP_WIZARD_OUTRO_TEXT", "./src/makeconfigs.prop"));
    prepareStockRecoveryCommandFile(SWITCH_LOCALE, "en", "mx");
    printf("the pidof mysqld: %d\n", getPidOf("mysqld"));
    return 0;
}
