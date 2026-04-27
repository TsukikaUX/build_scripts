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

// extern variables
extern int currentState;
extern int blocklistedModulesCount;
extern char**blocklistedModules;

// module identifier.
typedef struct {
	int moduleRunState;
	int maxSDK;
	int minSDK;
	char moduleName[50];
	char moduleVersion[16];
    char moduleAuthor[64];
	char moduleExecutableName[20];
	char pathOfTheModule[512];
} tsukikaModule;

// function declarations:
bool verifyAndLogModule(void *runnableModule);
bool isModuleInTheBlocklist(char *moduleNameAuthor);
void listModulesAndVerifyThem();
void addModuleToBlocklist(char* moduleName);
void runThisModule(void *thisModule);
void __cleanModuleMetadata(void *__moduleMetadata);
void __cleanPointers();
void __cacheBlocklists();
void __init__modules();
void __deinit__modules();
#endif 
