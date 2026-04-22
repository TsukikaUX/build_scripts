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
#ifndef TSUKIKA_PROPS_H
#define TSUKIKA_PROPS_H
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <tsukikautils.h>

// variables to use to cache the properties.
extern bool __didAnyPropertyGetChanged;
extern char **__properties_cached;
extern char **__propertiesValue_cached;

// macro:
#define PROPERTY_FILE "thisProperty"
#define MAX_PROPERTY_NAME_LENGTH 30
#define MAX_PROPERTY_VALUE_LENGTH 26

// enum for __getProperty().
enum propertyFetchType {
    PROPERTY_FROM_CACHE,
    PROPERTY_FROM_FILE
};

// enum for casting property value.
enum propertyCastType {
    CAST_TYPE_INT,
    CAST_TYPE_FLOAT,
    CAST_TYPE_STRING,
    CAST_TYPE_BOOL
};

// struct that is used for property stuffs like
// returning it's value or finding the index and type
typedef struct {
    int __found;
    int __propertyIndex;
    char *__propertyName;
    union {
        int __propertyIntegerValue;
        float __propertyFloatValue;
        bool __propertyBoolValue;
        char *__propertyStringValue;
    } value; 
    enum propertyCastType typeProp;
} tsukikaProperty;

// functions:
bool __setProperty(const char *__propertyName, const void *__propertyValue);
void __readProperty(void *__cookie);
void __cacheProperties();
void __saveState();
void __deleteProperty(const char *__propertyName);
void __init();
void __deinit();
void __freeThisPointer(void **thisPointer);
tsukikaProperty __getProperty(const char *__propertyName, enum propertyFetchType thisProperty);
#endif
