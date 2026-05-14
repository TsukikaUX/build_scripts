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
#ifndef TSUKIKA_MODULES_H
#define TSUKIKA_MODULES_H
#include <tsukika.h>
#include <tsukika_props.h>

// max prop length:
#define MAX_MODULE_PROPERTY_NAME 50
#define MAX_MODULE_PROPERTY_VERSION 16 
#define MAX_MODULE_PROPERTY_AUTHOR 20
#define MAX_MODULE_PROPERTY_CO_AUTHOR 64 
#define MAX_MODULE_PATH 512

// extern variables
extern int currentState;

// module identifier.
typedef struct {
	int moduleRunState;
	int maxSDK;
	int minSDK;
	char *moduleName;
	char *moduleVersion;
    char *moduleAuthor;
    char *moduleCOAuthor;
	char *pathOfTheModule;
} tsukikaModule;

// function declarations:
bool __isModuleInTheBlocklist(char *moduleNameAuthor);
void __addModuleToBlocklist(char* moduleName);
void __runThisModule(void *thisModule);
void __cleanModuleMetadata(void *__moduleMetadata__);
void __cleanPointers();
void __verifyAndLogModule(void *runnableModule);
void *__listModulesAndVerifyThem(void *nullArg);
#endif
