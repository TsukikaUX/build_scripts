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
#include <tsukika_modules.h>
#ifdef TSUKIKA_MODULES_H

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

bool isModuleInTheBlocklist(char *moduleName)
{
    // check if moduleName is in the list
    for(int i = 0; i < blocklistedModulesCount; i++) if(strcmp(blocklistedModules[i], moduleName) == 0) return true;
    return false;
}

void listModulesAndVerifyThem()
{
    tsukikaModule* module = {0};
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
        __freeThisPointer((void**)&name);
        strncpy(module->moduleVersion, version, sizeof(module->moduleVersion) - 1);
        __freeThisPointer((void**)&version);
        strncpy(module->moduleAuthor, author, sizeof(module->moduleAuthor) - 1);
        __freeThisPointer((void**)&author);
        // skip making others and just check if it's in the blocklist:
        if(isModuleInTheBlocklist((char *)module->moduleName))
        {
            consoleLog(LOG_LEVEL_INFO, "listModulesAndVerifyThem", "Module is in the blocklist, skipping fetching for it...");
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
        __freeThisPointer((void**)&minSDK);
        __freeThisPointer((void**)&maxSDK);
        __freeThisPointer((void**)&runState);
        verifyAndLogModule(module);
        __freeThisPointer((void**)&module);
    }
    closedir(baseDirectory);
}

void addModuleToBlocklist(char* moduleName)
{
    tsukikaProperty* __thisScopeStuffs = {0};
    __thisScopeStuffs->__propertyName = malloc(MAX_PROPERTY_NAME_LENGTH);
    if(!__thisScopeStuffs->__propertyName)
    {
        consoleLog(LOG_LEVEL_ERROR, "addModuleToBlocklist", "Failed to alloc heap for __thisScopeStuffs->__propertyName");
        exit(EXIT_FAILURE);
    }
    snprintf(__thisScopeStuffs->__propertyName, MAX_PROPERTY_NAME_LENGTH, "str.tsukika.modules.blocklists");
    __readProperty(&__thisScopeStuffs);
    if(strcmp(__thisScopeStuffs.value.__propertyStringValue, "NULL") == 0)
    {
        consoleLog(LOG_LEVEL_INFO, "addModuleToBlocklist", "Added %s to the blocklists", moduleName);
        __setProperty(__thisScopeStuffs.__propertyName, combineStringsFormatted("%s,", moduleName));
    }
    consoleLog(LOG_LEVEL_INFO, "addModuleToBlocklist", "Added %s to the blocklists", moduleName);
    __setProperty(__thisScopeStuffs.__propertyName, combineStringsFormatted("%s%s,", __thisScopeStuffs->value.__propertyStringValue, moduleName));
    return;
}

void runThisModule(void *thisModule)
{
    tsukikaModule* __thisModule = (tsukikaModule*)thisModule;
    const char *suffix;
    switch(__thisModule->moduleRunState)
    {
        case INIT: suffix = "init.sh"; break;
        case LATE_FS: suffix = "late-fs.sh"; break;
        case POST_FS: suffix = "post-fs.sh"; break;
        case POST_FS_DATA: suffix = "post-fs-data.sh"; break;
        case BOOT_COMPLETED: suffix = "boot-completed.sh"; break;
    }
    if(!suffix) 
    {
        consoleLog(LOG_LEVEL_ERROR, "runThisModule", "Invalid module state.");
        __freeThisPointer((void**)&__thisModule);
        return;
    }
    size_t lenOfStr = strlen(__thisModule->pathOfTheModule) + strlen(suffix) + 2;
    char *scriptPath = malloc(lenOfStr);
    if(!scriptPath)
    {
        consoleLog(LOG_LEVEL_ERROR, "runThisModule", "Failed to run this module due to unknown circumstances, please try again.");
        __freeThisPointer((void**)&__thisModule);
        return;
    }
    snprintf(scriptPath, lenOfStr, "%s/%s", __thisModule->pathOfTheModule, suffix);
    if(checkBlocklistedStringsNChar(scriptPath) != 0)
    {
        consoleLog(LOG_LEVEL_INFO, "runThisModule", "The script contains blocklisted words, blocklisting this module.");
        __freeThisPointer((void**)&scriptPath);
        __freeThisPointer((void**)&__thisModule);
        return;
    }
    // if the module state is not the current state, skip it now.
    if(__thisModule->moduleRunState != currentState)
    {
        __freeThisPointer((void**)&scriptPath);
        __freeThisPointer((void**)&__thisModule);
        return;
    } 
    /// execute the script and log the output lololollollololoololololololololloo.
    if(executeScripts(scriptPath, (char * const[]){scriptPath, NULL}, false) != 0) consoleLog(LOG_LEVEL_ERROR, "runThisModule", "Failed to run the module script.");
    __freeThisPointer((void**)&scriptPath);
    __freeThisPointer((void**)&__thisModule);
}

void __cleanModuleMetadata(void *__moduleMetadata)
{
    tsukikaModule* __moduleMetadata = (tsukikaModule*)__moduleMetadata;
    __moduleMetadata->moduleRunState = 0;
    __moduleMetadata->maxSDK = 0;
    __moduleMetadata->minSDK = 0;
    __moduleMetadata->moduleName = "";
    __moduleMetadata->moduleVersion = "";
    __moduleMetadata->moduleAuthor = "";
    __moduleMetadata->moduleExecutableName = "";
    __moduleMetadata->pathOfTheModule = "";
}

void __cleanPointers()
{
    for(int i = 0; i < blocklistedModulesCount; i++) __freeThisPointer((void**)&blocklistedModules[i]);
    __freeThisPointer((void**)&blocklistedModules);
}

void __cacheBlocklists()
{
    tsukikaProperty* __thisScopeStuffs = {0};
    if(!__thisScopeStuffs) return false;
    __thisScopeStuffs->__propertyName = malloc(MAX_PROPERTY_NAME_LENGTH);
    if(!__thisScopeStuffs->__propertyName) 
    { 
        __freeThisPointer((void**)&__thisScopeStuffs);
        return false;
    }
    snprintf(__thisScopeStuffs->__propertyName, MAX_PROPERTY_NAME_LENGTH, "str.tsukika.modules.blacklists");
    __readProperty(&__thisScopeStuffs);
    if(!__thisScopeStuffs->value.__propertyStringValue) return false;
    blocklistedModulesCount = 0;
    char *copy = strdup(__thisScopeStuffs->value.__propertyStringValue);
    char *token = strtok(copy, ",");
    while(token != NULL)
    {
        __freeThisPointer((void**)&blocklistedModules[blocklistedModulesCount]);
        blocklistedModules[blocklistedModulesCount] = strdup(token);
        if(!blocklistedModules[blocklistedModulesCount])
        {
            consoleLog(LOG_LEVEL_ERROR, "isModuleInTheBlocklist", "Failed to copy value to blocklistedModules[%d]", blocklistedModulesCount);
            __freeThisPointer((void**)&copy);
            __cleanPointers();
            exit(EXIT_FAILURE);
        }
        blocklistedModulesCount++;
        token = strtok(NULL, ",");
    }
    __freeThisPointer((void**)&copy);
}

void __init__modules()
{
    consoleLog(LOG_LEVEL_INFO, "__init__modules", "Init function triggered, starting up things...");
    __cacheBlocklists();
    listModulesAndVerifyThem();
}

void __deinit__modules()
{
    consoleLog(LOG_LEVEL_INFO, "__init__modules", "deinit function triggered, cleaning up things...");
    __cleanPointers();
}
#endif
