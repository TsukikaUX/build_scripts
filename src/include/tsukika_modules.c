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

bool __isModuleInTheBlocklist(char *moduleName)
{
    tsukikaProperty* __thisScopeStuffs = NULL;
    __thisScopeStuffs->__propertyName = malloc(MAX_PROPERTY_NAME_LENGTH);
    if(!__thisScopeStuffs->__propertyName) 
    { 
        consoleLog(LOG_LEVEL_DEBUG, "__isModuleInTheBlocklist", "!__thisScopeStuffs->__propertyName");
        __wipeMetadata((void*)__thisScopeStuffs);
        return false;
    }
    snprintf(__thisScopeStuffs->__propertyName, MAX_PROPERTY_NAME_LENGTH, "str.tsukika.modules.blocklists");
    __readProperty(&__thisScopeStuffs);
    if(!__thisScopeStuffs->value.__propertyStringValue)
    {
        consoleLog(LOG_LEVEL_DEBUG, "__isModuleInTheBlocklist", "!__thisScopeStuffs->value.__propertyStringValue");
        __wipeMetadata((void*)__thisScopeStuffs);
        return false;
    }
    char *copy = strdup(__thisScopeStuffs->value.__propertyStringValue);
    char *token = strtok(copy, ",");
    consoleLog(LOG_LEVEL_INFO, "__isModuleInTheBlocklist", "Checking if %s is inside the blocklists...", moduleName);
    while(!token)
    {
        if(strcmp(token, moduleName))
        {
            __wipeMetadata((void*)__thisScopeStuffs);
            return true;
        }
        // look for others too ;)
        token = strtok(NULL, ",");
    }
    __wipeMetadata((void*)__thisScopeStuffs);
    return false;
}

void __addModuleToBlocklist(char* moduleName)
{
    tsukikaProperty* __thisScopeStuffs = NULL;
    __thisScopeStuffs->__propertyName = malloc(MAX_PROPERTY_NAME_LENGTH);
    if(!__thisScopeStuffs->__propertyName)
    {
        __cleanModuleMetadata((void *)moduleName);
        abort_instance("__addModuleToBlocklist", "Failed to alloc heap for __thisScopeStuffs->__propertyName");
    }
    snprintf(__thisScopeStuffs->__propertyName, MAX_PROPERTY_NAME_LENGTH, "str.tsukika.modules.blocklists");
    __readProperty(&__thisScopeStuffs);
    if(strcmp(__thisScopeStuffs->value.__propertyStringValue, "NULL") == 0)
    {
        consoleLog(LOG_LEVEL_INFO, "__addModuleToBlocklist", "Added %s to the blocklists", moduleName);
        __setProperty(__thisScopeStuffs->__propertyName, combineStringsFormatted("%s,", moduleName));
    }
    else
    {
        consoleLog(LOG_LEVEL_INFO, "__addModuleToBlocklist", "Added %s to the blocklists", moduleName);
        __setProperty(__thisScopeStuffs->__propertyName, combineStringsFormatted("%s%s,", __thisScopeStuffs->value.__propertyStringValue, moduleName));
    }
}

void __runThisModule(void *thisModule)
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
        consoleLog(LOG_LEVEL_ERROR, "__runThisModule", "Invalid module state.");
        __cleanModuleMetadata((void *)__thisModule);
        return;
    }
    // if the module state is not the current state, skip it now.
    if(__thisModule->moduleRunState != currentState)
    {
        __cleanModuleMetadata((void *)__thisModule);
        exit(EXIT_SUCCESS);
    } 
    size_t lenOfStr = strlen(__thisModule->pathOfTheModule) + strlen(suffix) + 2;
    char *scriptPath = malloc(lenOfStr);
    if(!scriptPath)
    {
        consoleLog(LOG_LEVEL_ERROR, "__runThisModule", "Failed to run this module due to unknown circumstances, please try again.");
        __cleanModuleMetadata((void *)__thisModule);
        return;
    }
    snprintf(scriptPath, lenOfStr, "%s/%s", __thisModule->pathOfTheModule, suffix);
    if(checkBlocklistedStringsNChar(scriptPath) != 0)
    {
        consoleLog(LOG_LEVEL_INFO, "__runThisModule", "The script contains blocklisted materials, blocklisting this module.");
        __addModuleToBlocklist(__thisModule->moduleName);
        __freeThisPointer((void**)&scriptPath);
        __cleanModuleMetadata((void *)__thisModule);
        return;
    }
    /// execute the script and log the output lol.
    if(executeScripts(scriptPath, (char * const[]){scriptPath, NULL}, false) != 0) consoleLog(LOG_LEVEL_ERROR, "__runThisModule", "Failed to run the module script.");
    __freeThisPointer((void**)&scriptPath);
    __cleanModuleMetadata((void *)__thisModule);
}

void __cleanModuleMetadata(void *__moduleMetadata__)
{
    tsukikaModule* __moduleMetadata = (tsukikaModule*)__moduleMetadata__;
    __moduleMetadata->moduleRunState = 0;
    __moduleMetadata->maxSDK = 0;
    __moduleMetadata->minSDK = 0;
    __freeThisPointer((void **)&__moduleMetadata->moduleName);
    __freeThisPointer((void **)&__moduleMetadata->moduleVersion);
    __freeThisPointer((void **)&__moduleMetadata->moduleAuthor);
    __freeThisPointer((void **)&__moduleMetadata->moduleCOAuthor);
    __freeThisPointer((void **)&__moduleMetadata->pathOfTheModule);
    __freeThisPointer((void **)&__moduleMetadata__);
}

void __verifyAndLogModule(void *runnableModule)
{
    int systemSDK = getSystemProperty__("ro.system.build.version.sdk");
    tsukikaModule* thisInstanceModule = (tsukikaModule*)runnableModule;
    // init state checks
    if(thisInstanceModule->moduleRunState != LATE_FS && thisInstanceModule->moduleRunState != POST_FS && thisInstanceModule->moduleRunState != POST_FS_DATA)
    {
        consoleLog(LOG_LEVEL_ERROR, "__verifyAndLogModule", "Module doesn't have a valid init state, returning back and verifying other modules...");
        return;
    }
    // sdk checks
    if(systemSDK > thisInstanceModule->maxSDK) 
    {
        consoleLog(LOG_LEVEL_ERROR, "__verifyAndLogModule", "Cannot run module: system SDK is higher than supported.");
        return;
    }
    else if(systemSDK < thisInstanceModule->minSDK) 
    {
        consoleLog(LOG_LEVEL_ERROR, "__verifyAndLogModule", "Cannot run module: system SDK is lower than required.");
        return;
    }
    // log stuffs now:
    consoleLog(LOG_LEVEL_INFO, "__verifyAndLogModule", "Name of the module: %s", thisInstanceModule->moduleName);
    consoleLog(LOG_LEVEL_INFO, "__verifyAndLogModule", "Version of the module: %s", thisInstanceModule->moduleVersion);
    consoleLog(LOG_LEVEL_INFO, "__verifyAndLogModule", "Author of the module: %s", thisInstanceModule->moduleAuthor);
    consoleLog(LOG_LEVEL_INFO, "__verifyAndLogModule", "Co-Author of the module: %s", thisInstanceModule->moduleCOAuthor);
    consoleLog(LOG_LEVEL_INFO, "__verifyAndLogModule", "Module will run shortly! Please wait...");
    __runThisModule((void *)runnableModule);
}

void *__listModulesAndVerifyThem(void *nullArg)
{
    if(!nullArg) consoleLog(LOG_LEVEL_DEBUG, "__listModulesAndVerifyThem", "nullArg is NULL");
    tsukikaModule* module = NULL;
    DIR *baseDirectory = opendir("/data/tsukika/modules");
    if(!baseDirectory) abort_instance("__listModulesAndVerifyThem", "Failed to open module directory.");
    struct dirent *directories;
    while((directories = readdir(baseDirectory)))
    {
        // skip . and ..
        if(strcmp(directories->d_name, ".") == 0 || strcmp(directories->d_name, "..") == 0) continue;
        // allocate module per entry
        module = calloc(1, sizeof(tsukikaModule));
        if(!module)
        {
            module = calloc(1, sizeof(tsukikaModule));
            consoleLog(LOG_LEVEL_ERROR, "__listModulesAndVerifyThem", "Failed to allocate blocks for module, if it gets failed again, this init state triggers will not run.");
            if(!module)
            {
                __cleanModuleMetadata((void *)module);
                closedir(baseDirectory);
                abort_instance("__listModulesAndVerifyThem", "Limited tries exhausted.");
            }
            continue;
        }
        // allocate and do misc stuff these shits:
        module->moduleName = malloc(MAX_MODULE_PROPERTY_NAME);
        module->moduleAuthor = malloc(MAX_MODULE_PROPERTY_AUTHOR);
        module->moduleCOAuthor = malloc(MAX_MODULE_PROPERTY_CO_AUTHOR);
        module->moduleVersion = malloc(MAX_MODULE_PROPERTY_VERSION);
        module->pathOfTheModule = malloc(MAX_MODULE_PATH);
        // check for malloc errors:
        if(!module->moduleName || !module->moduleVersion || !module->moduleAuthor || !module->moduleCOAuthor || !module->pathOfTheModule)
        {
            __cleanModuleMetadata((void *)module);
            __freeThisPointer((void **)&module);
            consoleLog(LOG_LEVEL_ERROR, "__listModulesAndVerifyThem", "Failed to allocate blocks for module metadata, skipping this module...");
            continue;
        }
        // necessary variables:
        char moduleProp[512];
        snprintf(module->pathOfTheModule, MAX_MODULE_PATH, "/data/tsukika/modules/%s", directories->d_name);
        snprintf(moduleProp, sizeof(moduleProp), "%s/module.prop", module->pathOfTheModule);
        // let's just grep the module name to see if it's in the blocklist
        module->moduleName = getpropFromFile("name", moduleProp);
        if(__isModuleInTheBlocklist(module->moduleName)) __cleanModuleMetadata((void *)module);
        module->moduleVersion = getpropFromFile("version", moduleProp);
        module->moduleAuthor = getpropFromFile("author", moduleProp);
        module->moduleCOAuthor = getpropFromFile("co-author", moduleProp);
        char *minSDK = getpropFromFile("minSDK", moduleProp);
        char *maxSDK = getpropFromFile("maxSDK", moduleProp);
        char *runState = getpropFromFile("runState", moduleProp);
        module->minSDK = minSDK ? atoi(minSDK) : -1;
        module->maxSDK = maxSDK ? atoi(maxSDK) : -1;
        module->moduleRunState = runState ? atoi(runState) : -1;
        // run and free these variables after.
        __verifyAndLogModule((void *)module);
        __cleanModuleMetadata((void *)module);
    }
    closedir(baseDirectory);
    return NULL;
}
