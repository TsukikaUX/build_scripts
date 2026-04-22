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
    const char *inputStr = (const char *)__propertyValue;
    if(setProp.__found == 0) {
        __freeThisPointer((void**)&__propertiesValue_cached[setProp.__propertyIndex]);
        __propertiesValue_cached[setProp.__propertyIndex] = malloc(MAX_PROPERTY_VALUE_LENGTH);
        if(!__propertiesValue_cached[setProp.__propertyIndex]) {
            consoleLog(LOG_LEVEL_DEBUG, "__setProperty", "__propertiesValue_cached[setProp.__propertyIndex]: malloc");
            consoleLog(LOG_LEVEL_ERROR, "__setProperty", "Failed to set given property.");
            return false;
        }
        char buffer[MAX_PROPERTY_VALUE_LENGTH];
        switch(setProp.typeProp) {
            case CAST_TYPE_INT:
                snprintf(buffer, sizeof(buffer), "%d", atoi(inputStr));
            break;
            case CAST_TYPE_FLOAT:
                snprintf(buffer, sizeof(buffer), "%f", atof(inputStr));
            break;
            case CAST_TYPE_BOOL:
                snprintf(buffer, sizeof(buffer), "%s", (strcmp(inputStr, "true") == 0 || strcmp(inputStr, "1") == 0) ? "true" : "false");
            break;
            case CAST_TYPE_STRING:
            default:
                snprintf(buffer, sizeof(buffer), "%s", inputStr);
            break;
        }
        snprintf(__propertiesValue_cached[setProp.__propertyIndex], MAX_PROPERTY_VALUE_LENGTH, "%s", (const char *)__propertyValue);
        __didAnyPropertyGetChanged = true;
    }
    free(setProp.__propertyName);
    return __didAnyPropertyGetChanged;
}

void __readProperty(void *__cookie)
{
    tsukikaProperty* thisInstanceTsukika = (tsukikaProperty*)__cookie;
    if(thisInstanceTsukika == NULL) return;
    FILE *propertyFilePointer = fopen(PROPERTY_FILE, "r");
    if(!propertyFilePointer) return;
    // reset the property index to zero.
    thisInstanceTsukika->__propertyIndex = 0;
    thisInstanceTsukika->__found = 1;
    char cachedProp[1024];
    while(fgets(cachedProp, sizeof(cachedProp), propertyFilePointer)) 
    {
        // set the value of __found to 0 and put the value to the __propertyValue if it's found to be with a value.
        if(strncmp(cachedProp, thisInstanceTsukika->__propertyName, strlen(thisInstanceTsukika->__propertyName)) == 0)
        {
            strtok(cachedProp, "=");
            char *value = strtok(NULL, "\n");
            if(value) 
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
                        thisInstanceTsukika->value.__propertyIntegerValue = atoi(value);
                    break;
                    case CAST_TYPE_FLOAT:
                        char *endptr;
                        thisInstanceTsukika->value.__propertyFloatValue = (float)strtof(value, &endptr);
                    break;
                    case CAST_TYPE_BOOL:
                        thisInstanceTsukika->value.__propertyBoolValue = (strcmp(value, "true") == 0 || strcmp(value, "1") == 0);
                    break;
                    case CAST_TYPE_STRING:
                    default:
                        thisInstanceTsukika->value.__propertyStringValue = malloc(MAX_PROPERTY_VALUE_LENGTH);
                        if(thisInstanceTsukika->value.__propertyStringValue) 
                            snprintf(thisInstanceTsukika->value.__propertyStringValue, MAX_PROPERTY_VALUE_LENGTH, "%s", value);

                    break;
                }
                fclose(propertyFilePointer);
                return;
            }
        }
        // increment the property index until we find the one ;)
        // this index helps us to fetch it faster.
        thisInstanceTsukika->__propertyIndex++;
    }
    fclose(propertyFilePointer);
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
    // stupid thing, put the index to zero.
    int i = 0;
    char cachedProp[1024];
    // I WAS STUPID AND I FORGOT TO DO THIS:
    __freeThisPointer((void **)&__properties_cached);
    __freeThisPointer((void **)&__propertiesValue_cached);
    // we can have this thing go up to a lot.
    __properties_cached = malloc(3040);
    if(!__properties_cached) {
        consoleLog(LOG_LEVEL_DEBUG, "__cacheProperties", "__properties_cached: malloc error.");
        consoleLog(LOG_LEVEL_ERROR, "__cacheProperties", "Failed to cache properties.");
        return;
    }
    __propertiesValue_cached = malloc(3040);
    if(!__propertiesValue_cached) {
        consoleLog(LOG_LEVEL_DEBUG, "__cacheProperties", "__propertiesValue_cached: malloc error.");
        consoleLog(LOG_LEVEL_ERROR, "__cacheProperties", "Failed to cache properties.");
        return;
    }
    // loop-read the file.
    while(fgets(cachedProp, sizeof(cachedProp), propertyFilePointer)) {
        // freeing stuff BECAUSE WE NEED TO:
        // it is unnecessary to do that but we are doing just to be safe enough.
        // this will not crash the app btw.
        __freeThisPointer((void **)&__properties_cached[i]);
        __freeThisPointer((void **)&__propertiesValue_cached[i]);
        // anyways, malloc-cate the pointers so we can give it some value.
        __properties_cached[i] = malloc(MAX_PROPERTY_NAME_LENGTH);
        if(!__properties_cached[i]) {
            consoleLog(LOG_LEVEL_DEBUG, "__cacheProperties", "__properties_cached[%d]: malloc error.", i);
            consoleLog(LOG_LEVEL_ERROR, "__cacheProperties", "Failed to cache properties.");
            return;
        }
        __propertiesValue_cached[i] = malloc(MAX_PROPERTY_VALUE_LENGTH);
        if(!__propertiesValue_cached[i]) {
            consoleLog(LOG_LEVEL_DEBUG, "__cacheProperties", "__propertiesValue_cached[%d]: malloc error.", i);
            consoleLog(LOG_LEVEL_ERROR, "__cacheProperties", "Failed to cache properties.");
            __freeThisPointer((void **)&__properties_cached[i]);
            return;
        }
        // copy the values to the thing.
        strtok(cachedProp, "=");
        char *value = strtok(NULL, "\n");
        if(!value) continue;
        snprintf(__properties_cached[i], MAX_PROPERTY_NAME_LENGTH, "%s", cachedProp);
        snprintf(__propertiesValue_cached[i], MAX_PROPERTY_VALUE_LENGTH, "%s", value);
        i++;
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
    for(int i = 0; __properties_cached[i] != NULL; i++) fprintf(thisPropertyFile, "%s=%s\n", __properties_cached[i], __propertiesValue_cached[i]);
    fclose(thisPropertyFile);
}

void __deleteProperty(const char *__propertyName)
{
    __setProperty(__propertyName, "DELETED");
    __didAnyPropertyGetChanged = true;
    consoleLog(LOG_LEVEL_INFO, "__deleteProperty", "Trying to save the property state...");
    __saveState();
}

void __init()
{
    // before caching and all of that stuff, let's check some stuff.
    if(access(PROPERTY_FILE, F_OK) != 0) {
        consoleLog(LOG_LEVEL_DEBUG, "__init", "access(PROPERTY_FILE, F_OK): %d", access(PROPERTY_FILE, F_OK));
        consoleLog(LOG_LEVEL_ERROR, "__init", "Failed to initialize property stuff.");
        exit(EXIT_FAILURE);
    }
    // wipe the old logs because we don't want it to be like Epic- ifykyk.
    eraseFile(LOGFILE);
    __cacheProperties();
}

void __deinit()
{
    consoleLog(LOG_LEVEL_DEBUG, "__deinit", "deinit started, savin' state and clearin' some stuff up.");
    __saveState();
    __freeThisPointer((void **)&__properties_cached);
    __freeThisPointer((void **)&__propertiesValue_cached);
}

void __freeThisPointer(void **thisPointer)
{    
    if(thisPointer && *thisPointer) {
        free(*thisPointer);
        *thisPointer = NULL;
    }
}

tsukikaProperty __getProperty(const char *__propertyName, enum propertyFetchType thisProperty)
{
    tsukikaProperty getprop = {0};
    getprop.__propertyName = malloc(MAX_PROPERTY_NAME_LENGTH);
    if(!getprop.__propertyName) {
        consoleLog(LOG_LEVEL_ERROR, "__getProperty", "malloc failed for __propertyName");
        return getprop;
    }
    // copy the prop name for fetching info on struct.
    snprintf(getprop.__propertyName, MAX_PROPERTY_NAME_LENGTH, "%s", __propertyName);
    __readProperty(&getprop);
    // not found, ig
    if(getprop.__found != 0) {
        __freeThisPointer((void **)&getprop.__propertyName);
        return getprop;
    }
    void *dataSource = NULL;
    if(thisProperty == PROPERTY_FROM_CACHE) dataSource = __propertiesValue_cached[getprop.__propertyIndex];
    else dataSource = getprop.value.__propertyStringValue;
    if(!dataSource) {
        __freeThisPointer((void **)&getprop.__propertyName);
        return getprop;
    }
    switch(getprop.typeProp)
    {
        case CAST_TYPE_INT:
            getprop.value.__propertyIntegerValue = atoi((char *)dataSource);
        break;
        case CAST_TYPE_FLOAT:
            getprop.value.__propertyFloatValue = (float)atof((char *)dataSource);
        break;
        case CAST_TYPE_BOOL:
            getprop.value.__propertyBoolValue = (strcmp((char *)dataSource, "true") == 0 || strcmp((char *)dataSource, "1") == 0);
        break;
        case CAST_TYPE_STRING:
        default:
            getprop.value.__propertyStringValue = (char *)dataSource;
        break;
    }
    __freeThisPointer((void **)&getprop.__propertyName);
    return getprop;
}
