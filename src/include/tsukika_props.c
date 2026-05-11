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
#include <tsukika_props.h>

// the real reason i didn't put any error on the
// same value because it's pointless, if you add one
// it's just going to be some junk.
bool __setProperty(const char *__propertyName, const void *__propertyValue)
{
    __didAnyPropertyGetChanged = false;
    tsukikaProperty setProp = {0};
    setProp.__propertyName = malloc(MAX_PROPERTY_NAME_LENGTH);
    if(!setProp.__propertyName) {
        consoleLog(LOG_LEVEL_DEBUG, "__setProperty", "setProp.__propertyName: malloc");
        consoleLog(LOG_LEVEL_ERROR, "__setProperty", "Failed to set given property.");
        return false;
    }
    snprintf(setProp.__propertyName, MAX_PROPERTY_NAME_LENGTH, "%s", __propertyName);
    __readProperty(&setProp);
    if(setProp.__found == 0) {
        __freeThisPointer((void**)&__propertiesValue_cached[setProp.__propertyIndex]);
        __propertiesValue_cached[setProp.__propertyIndex] = malloc(MAX_PROPERTY_VALUE_LENGTH);
        if(!__propertiesValue_cached[setProp.__propertyIndex]) {
            consoleLog(LOG_LEVEL_DEBUG, "__setProperty", "__propertiesValue_cached[setProp.__propertyIndex]: malloc");
            consoleLog(LOG_LEVEL_ERROR, "__setProperty", "Failed to set given property.");
            __freeThisPointer((void**)&setProp.__propertyName);
            return false;
        }
        snprintf(__propertiesValue_cached[setProp.__propertyIndex], MAX_PROPERTY_VALUE_LENGTH, "%s", (const char *)__propertyValue);
        __didAnyPropertyGetChanged = true;
    }
    __freeThisPointer((void**)&setProp.__propertyName);
    //__freeThisPointer((void**)&__propertyValue);
    //__freeThisPointer((void**)&__propertyName);
    return __didAnyPropertyGetChanged;
}

void __readProperty(void *__cookie)
{
    tsukikaProperty* thisInstanceTsukika = (tsukikaProperty*)__cookie;
    if(!thisInstanceTsukika) return;
    // reset the property index to zero.
    thisInstanceTsukika->__propertyIndex = 0;
    thisInstanceTsukika->__found = 1;
    for(int i = 0; i < __properties_count; i++)
    {
        // set the value of __found to 0 and put the value to the __propertyValue if it's found to be with a value.
        if(__properties_cached[i] && strcmp(__properties_cached[i], thisInstanceTsukika->__propertyName) == 0)
        {
            if(strcmp(__propertiesValue_cached[i], "DELETED") == 0)
            {
                consoleLog(LOG_LEVEL_ERROR, "__readProperty", "Property is yet to be deleted after a sync, skipping fetching metadata for %s", __properties_cached[i]);
                return;
            }
            if(__propertiesValue_cached[i])
            {
                // set the property type, set string as the default case.
                thisInstanceTsukika->typeProp = CAST_TYPE_STRING;
                if(strstr(thisInstanceTsukika->__propertyName, "float")) thisInstanceTsukika->typeProp = CAST_TYPE_FLOAT;
                else if(strstr(thisInstanceTsukika->__propertyName, "int")) thisInstanceTsukika->typeProp = CAST_TYPE_INT;
                else if(strstr(thisInstanceTsukika->__propertyName, "bool")) thisInstanceTsukika->typeProp = CAST_TYPE_BOOL;
                thisInstanceTsukika->__found = 0;
                switch(thisInstanceTsukika->typeProp)
                {
                    case CAST_TYPE_INT:
                        thisInstanceTsukika->value.__propertyIntegerValue = atoi(__propertiesValue_cached[i]);
                    break;
                    case CAST_TYPE_FLOAT:
                        char *endptr;
                        thisInstanceTsukika->value.__propertyFloatValue = (float)strtof(__propertiesValue_cached[i], &endptr);
                    break;
                    case CAST_TYPE_BOOL:
                        thisInstanceTsukika->value.__propertyBoolValue = (strcmp(__propertiesValue_cached[i], "true") == 0 || strcmp(__propertiesValue_cached[i], "1") == 0);
                    break;
                    case CAST_TYPE_STRING:
                    default:
                        thisInstanceTsukika->value.__propertyStringValue = malloc(MAX_PROPERTY_VALUE_LENGTH);
                        if(thisInstanceTsukika->value.__propertyStringValue) 
                            snprintf(thisInstanceTsukika->value.__propertyStringValue, MAX_PROPERTY_VALUE_LENGTH, "%s", __propertiesValue_cached[i]);

                    break;
                }
                return;
            }
            else 
            {
                consoleLog(LOG_LEVEL_ERROR, "__readProperty", "Failed to fetch property value.");
                return;
            }
        }
        // increment the property index until we find the one ;)
        // this index helps us to fetch it faster.
        thisInstanceTsukika->__propertyIndex++;
    }
}

void __cacheProperties()
{
    // check if we can open the file and exit if we can't.
    FILE *propertyFilePointer = fopen(PROPERTY_FILE, "r");
    if(!propertyFilePointer)
    {
        consoleLog(LOG_LEVEL_ERROR, "__cacheProperties", "Failed to open up property file.");
        exit(EXIT_FAILURE);
    }
    // reset value back, just in case:
    __properties_count = 0;
    char cachedProp[1024];
    // I WAS STUPID AND I FORGOT TO DO THIS:
    __freeThisPointer((void **)&__properties_cached); // DEFAULT-free
    __freeThisPointer((void **)&__propertiesValue_cached); // DEFAULT-free
    // we can have this thing go up to a thousand.
    __properties_cached = malloc(sizeof(char*) * MAX_PROPERTIES);
    if(!__properties_cached) // DEFAULT
    {
        consoleLog(LOG_LEVEL_DEBUG, "__cacheProperties", "__properties_cached: malloc error.");
        consoleLog(LOG_LEVEL_ERROR, "__cacheProperties", "Failed to cache properties.");
        return;
    }
    __propertiesValue_cached = malloc(sizeof(char*) * MAX_PROPERTIES);
    if(!__propertiesValue_cached)  // DEFAULT
    {
        consoleLog(LOG_LEVEL_DEBUG, "__cacheProperties", "__propertiesValue_cached: malloc error.");
        consoleLog(LOG_LEVEL_ERROR, "__cacheProperties", "Failed to cache properties.");
        return;
    }
    // loop-read the file.
    while(fgets(cachedProp, sizeof(cachedProp), propertyFilePointer)) 
    {
        // freeing stuff BECAUSE WE NEED TO:
        // it is unnecessary to do that but we are doing just to be safe enough.
        // this will not crash the app btw.
        __freeThisPointer((void **)&__properties_cached[__properties_count]); // DEFAULT
        __freeThisPointer((void **)&__propertiesValue_cached[__properties_count]); // DEFAULT
        // check if we exceed the MAX_PROPERTIES cap and quit the application cuz we dont have- 
        // we can't do anything with this.
        if(__properties_count >= MAX_PROPERTIES) 
        {
            consoleLog(LOG_LEVEL_ERROR, "__cacheProperties", "Exceeded MAX_PROPERTIES limit, quitting the application...");
            exit(EXIT_FAILURE);
        }
        // anyways, malloc-cate the pointers so we can give it some value.
        __properties_cached[__properties_count] = malloc(MAX_PROPERTY_NAME_LENGTH);
        if(!__properties_cached[__properties_count]) 
        {
            // DEFAULT-index-malloc:check
            consoleLog(LOG_LEVEL_DEBUG, "__cacheProperties", "__properties_cached[%d]: malloc error.", __properties_count);
            consoleLog(LOG_LEVEL_ERROR, "__cacheProperties", "Failed to cache properties.");
            __deinit__properties(false);
        }
        __propertiesValue_cached[__properties_count] = malloc(MAX_PROPERTY_VALUE_LENGTH); // DEFAULT-malloc
        if(!__propertiesValue_cached[__properties_count]) 
        { 
            // DEFAULT-index-malloc:check
            consoleLog(LOG_LEVEL_DEBUG, "__cacheProperties", "__propertiesValue_cached[%d]: malloc error.", __properties_count);
            consoleLog(LOG_LEVEL_ERROR, "__cacheProperties", "Failed to cache properties.");
            __deinit__properties(false);
        }
        // copy the values to the thing.
        char *key = strtok(cachedProp, "=");
        char *value = strtok(NULL, "\n");
        // skip if the value itself is empty.
        if(!value) continue;
        snprintf(__properties_cached[__properties_count], MAX_PROPERTY_NAME_LENGTH, "%s", key);
        snprintf(__propertiesValue_cached[__properties_count], MAX_PROPERTY_VALUE_LENGTH, "%s", value);
        __properties_count++;
    }
}

void __saveState()
{
    // bail out if we didn't change any value.
    if(!__didAnyPropertyGetChanged) return;
    // open the file in write mode to erase the previous content.
    FILE *thisPropertyFile = fopen(PROPERTY_FILE, "w");
    if(!thisPropertyFile) {
        consoleLog(LOG_LEVEL_DEBUG, "__saveState", "thisPropertyFile: fopen");
        consoleLog(LOG_LEVEL_ERROR, "__saveState", "Failed to save the current state.");
        return;
    }
    // write the new content back to the file.
    for(int i = 0; i < __properties_count; i++)
    {
        if(!__properties_cached[i] || !__propertiesValue_cached[i]) continue;
        if(strcmp(__propertiesValue_cached[i], "DELETED") == 0) continue;
        fprintf(thisPropertyFile, "%s=%s\n", __properties_cached[i], __propertiesValue_cached[i]);
    }
    fclose(thisPropertyFile);
}

void __deleteProperty(const char *__propertyName)
{
    __setProperty(__propertyName, "DELETED");
    __didAnyPropertyGetChanged = true;
    consoleLog(LOG_LEVEL_INFO, "__deleteProperty", "Trying to save the property state...");
    __saveState();
}

void __init__properties()
{
    // before caching and all of that stuff, let's check some stuff.
    if(access(PROPERTY_FILE, F_OK) != 0) {
        consoleLog(LOG_LEVEL_DEBUG, "__init__properties", "access(PROPERTY_FILE, F_OK): %d", access(PROPERTY_FILE, F_OK));
        consoleLog(LOG_LEVEL_ERROR, "__init__properties", "Failed to initialize property stuff.");
        exit(EXIT_FAILURE);
    }
    // wipe the old logs because we don't want it to be like Epic- ifykyk.
    eraseFile(LOGFILE);
    __cacheProperties();
}

void __deinit__properties(bool saveTheProps)
{
    consoleLog(LOG_LEVEL_DEBUG, "__deinit__properties", "deinit started, savin' state and clearin' some stuff up.");
    if(saveTheProps) __saveState();
    for(int i = 0; i < __properties_count; i++)
    {
        __freeThisPointer((void **)&__properties_cached[i]);
        __freeThisPointer((void **)&__propertiesValue_cached[i]);
    }
    __freeThisPointer((void **)&__properties_cached);
    __freeThisPointer((void **)&__propertiesValue_cached);
}

void __wipeMetadata(void *__cookie)
{
    tsukikaProperty* __thisModule = (tsukikaProperty*)__cookie;
    __thisModule->__found = -1;
    __thisModule->__propertyIndex = -1;
    __thisModule->value.__propertyIntegerValue = -1;
    __thisModule->value.__propertyFloatValue = 1.0;
    __thisModule->value.__propertyBoolValue = false;
    __freeThisPointer((void*)__thisModule->__propertyName);
    __freeThisPointer((void*)__thisModule->value.__propertyStringValue);
    __thisModule->typeProp = CAST_NONE;
}

tsukikaProperty __getPropertyMetadata(const char *__propertyName)
{
    tsukikaProperty getprop = {0};
    getprop.__propertyName = malloc(MAX_PROPERTY_NAME_LENGTH);
    if(!getprop.__propertyName) {
        consoleLog(LOG_LEVEL_ERROR, "__getProperty::tsukikaProperty", "malloc failed for __propertyName");
        return getprop;
    }
    // copy the prop name for fetching info on struct.
    snprintf(getprop.__propertyName, MAX_PROPERTY_NAME_LENGTH, "%s", __propertyName);
    __readProperty(&getprop);
    // not found, ig
    if(getprop.__found != 0) {
        consoleLog(LOG_LEVEL_ERROR, "__getProperty::tsukikaProperty", "Property doesn't exist.");
        return getprop;
    }
    return getprop;
}
