#include <tsukika_modules.h>

bool verifyAndLogModule(void *runnableModule)
{
    int systemSDK = getSystemProperty__("ro.system.build.version.sdk");
    tsukikaModule* thisInstanceModule = (tsukikaModule*)runnableModule;
    // init state checks
    if(thisInstanceModule->moduleRunState != LATE_FS && thisInstanceModule->moduleRunState != POST_FS && thisInstanceModule->moduleRunState != POST_FS_DATA)
    {
        consoleLog(LOG_LEVEL_ERROR, "verifyAndLogModule", "Module doesn't have a valid init state, returning back and verifying other modules...");
        return false;
    }
    // sdk checks
    if(systemSDK > thisInstanceModule->maxSDK) {
        consoleLog(LOG_LEVEL_ERROR, "verifyAndLogModule", "Cannot run module: system SDK is higher than supported.");
        return false;
    }
    else if(systemSDK < thisInstanceModule->minSDK) {
        consoleLog(LOG_LEVEL_ERROR, "verifyAndLogModule", "Cannot run module: system SDK is lower than required.");
        return false;
    }
    // log stuffs now:
    consoleLog(LOG_LEVEL_INFO, "verifyAndLogModule", "Name of the module: %s", thisInstanceModule->moduleName);
    consoleLog(LOG_LEVEL_INFO, "verifyAndLogModule", "Version of the module %s", thisInstanceModule->moduleVersion);
    consoleLog(LOG_LEVEL_INFO, "verifyAndLogModule", "Author of the module %s", thisInstanceModule->moduleAuthor);
    consoleLog(LOG_LEVEL_INFO, "verifyAndLogModule", "Module will run shortly! Please wait...");
    currentState = thisInstanceModule->moduleRunState;
    runThisModule(runnableModule);
    return true;
}

bool isModuleInTheBlocklist(char *moduleNameAuthor)
{
    FILE *fptr = fopen("/system/etc/init/modules/tsukika/module.blocklists", "r");
    char thisContent[1028];
    while(fgets(thisContent, sizeof(thisContent), fptr))
    {
        thisContent[strcspn(thisContent, "\n")] = '\0';
        if(strcmp(moduleNameAuthor, thisContent) == 0) 
        {
            fclose(fptr);
            return 0;
        }
    }
    fclose(fptr);
    return 1;
}

void listModulesAndVerifyThem()
{
    tsukikaModule* module;
    DIR *baseDirectory = opendir("/system/etc/init/modules/tsukika");
    if(!baseDirectory)
    {
        consoleLog(LOG_LEVEL_ERROR, "listModulesAndVerifyThem", "Failed to open module directory.");
        return;
    }
    struct dirent *directories;
    while((directories = readdir(baseDirectory)))
    {
        // skip . and ..
        if(strcmp(directories->d_name, ".") == 0 || strcmp(directories->d_name, "..") == 0) continue;
        // allocate module per entry
        module = calloc(1, sizeof(tsukikaModule));
        if(!module) continue;
        char moduleProp[512];
        char modulePath[512];
        snprintf(modulePath, sizeof(modulePath), "/system/etc/init/modules/tsukika/modules/%s", directories->d_name);
        snprintf(moduleProp, sizeof(moduleProp), "%s/module.prop", modulePath);
        // check if the module is disabled or not
        if(access(combineStringsFormatted(modulePath, "/.disabled"), F_OK) == 0) 
        {
            consoleLog(LOG_LEVEL_INFO, "listModulesAndVerifyThem", "Module is disabled, skipping fetching for it...");
            continue;
        }
        // get values safely
        char *name = getpropFromFile("name", moduleProp);
        char *version = getpropFromFile("version", moduleProp);
        char *author = getpropFromFile("author", moduleProp);
        // let's prevent nonsensical issues.
        if(!name || !version || !author)
        {
            consoleLog(LOG_LEVEL_ERROR, "listModulesAndVerifyThem", "Internal fetching error, skipping this module...");
            continue;
        }
        strncpy(module->moduleName, name, sizeof(module->moduleName) - 1);
        free(name);
        strncpy(module->moduleVersion, version, sizeof(module->moduleVersion) - 1);
        free(version);
        strncpy(module->moduleAuthor, author, sizeof(module->moduleAuthor) - 1);
        free(author);
        // skip making others and just check if it's in the blocklist:
        if(isModuleInTheBlocklist((char *)module->moduleName))
        {
            consoleLog(LOG_LEVEL_INFO, "listModulesAndVerifyThem", "Module is in the blocklist, skipping fetching for it...");
            free(version);
            free(author);
            free(module);
            continue;
        }
        char *minSDK = getpropFromFile("minSDK", moduleProp);
        char *maxSDK = getpropFromFile("maxSDK", moduleProp);
        char *runState = getpropFromFile("runState", moduleProp);
        // again, if things go south.
        if(!minSDK || !maxSDK || !runState)
        {
            consoleLog(LOG_LEVEL_ERROR, "listModulesAndVerifyThem", "Internal fetching error, skipping this module...");
            continue;
        }
        module->minSDK = minSDK ? atoi(minSDK) : 0;
        module->maxSDK = maxSDK ? atoi(maxSDK) : 0;
        module->moduleRunState = runState ? atoi(runState) : 0;
        snprintf(module->pathOfTheModule, sizeof(module->pathOfTheModule), "/system/etc/init/modules/tsukika/modules/%s", directories->d_name);
        free(minSDK);
        free(maxSDK);
        free(runState);
        verifyAndLogModule(module);
        free(module);
    }
    closedir(baseDirectory);
}

void addModuleToBlocklist(void* thisModule)
{
    FILE *fptr;
    tsukikaModule* __thisModule = (tsukikaModule*)thisModule;
    if(access("/system/etc/init/modules/tsukika/module.blocklists", F_OK) != 0) fptr = fopen("/system/etc/init/modules/tsukika/module.blocklists", "w");
    else fptr = fopen("/system/etc/init/modules/tsukika/module.blocklists", "a");
    // write the module name with the author name.
    if(!fptr) abort_instance("addModuleToBlocklist", "Failed to blocklist this module, please try again.");
    fprintf(fptr, "%s - %s\n", __thisModule->moduleName, __thisModule->moduleAuthor);
    fclose(fptr);
}

void runThisModule(void *thisModule)
{
    tsukikaModule* __thisModule = (tsukikaModule*)thisModule;
    char *scriptPath = malloc(sizeof(__thisModule->pathOfTheModule) + 19);
    if(!scriptPath)
    {
        consoleLog(LOG_LEVEL_ERROR, "runThisModule", "Failed to run this module due to unknown circumstances, please try again.");
        return;
    }
    switch(__thisModule->moduleRunState)
    {
        case INIT:
            snprintf(scriptPath, sizeof(__thisModule->pathOfTheModule), "%s/init.sh", __thisModule->pathOfTheModule);
        break;
        case LATE_FS:
            snprintf(scriptPath, sizeof(__thisModule->pathOfTheModule), "%s/late-fs.sh", __thisModule->pathOfTheModule);
        break;
        case POST_FS:
            snprintf(scriptPath, sizeof(__thisModule->pathOfTheModule), "%s/post-fs.sh", __thisModule->pathOfTheModule);
        break;
        case POST_FS_DATA:
            snprintf(scriptPath, sizeof(__thisModule->pathOfTheModule), "%s/post-fs-data.sh", __thisModule->pathOfTheModule);
        break;
        case BOOT_COMPLETED:
            snprintf(scriptPath, sizeof(__thisModule->pathOfTheModule), "%s/boot-completed.sh", __thisModule->pathOfTheModule);
        break;
        default:
            consoleLog(LOG_LEVEL_ERROR, "runThisModule", "Unknown state.");
    }
    if(checkBlocklistedStringsNChar(scriptPath) != 0)
    {
        consoleLog(LOG_LEVEL_INFO, "runThisModule", "The script contains blocklisted words, blocklisting this module.");
        free(scriptPath);
        return;
    }
    // if the module state is not the current state, skip it now.
    if(__thisModule->moduleRunState != currentState) return;
    /// execute the script and log the output lololollollololoololololololololloo.
    if(executeScripts(scriptPath, (char * const[]){scriptPath, NULL}, false) != 0) consoleLog(LOG_LEVEL_ERROR, "runThisModule", "Failed to run the module script.");
    free(scriptPath);
}
