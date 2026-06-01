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
#ifndef TSUKIKAUTILS_H
#define TSUKIKAUTILS_H
#include <string.h>
#include <stdbool.h>
#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/wait.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <ctype.h>
#include <fcntl.h>
#include <stdarg.h>

// log levels:
enum elogLevel {
    LOG_LEVEL_INFO,
    LOG_LEVEL_WARN,
    LOG_LEVEL_ERROR,
    LOG_LEVEL_DEBUG,
    LOG_LEVEL_ABORT
};

// string convert case:
enum stringCases {
    LOWER,
    UPPER,
    BLEH
};

// extern vars. VERY IMPORTANT!!
extern char *_Nonnull tsukikaLogFile;
extern bool useStdoutForAllLogs;

// macro function(s):
#define makeDir(thisDirectory) executeCommands("mkdir", (char * const[]) {"mkdir", "-p", thisDirectory}, false);

// function declarations.
int executeCommands(const char *_Nonnull command, char * const _Nonnull args[_Nonnull], bool requiresOutput);
int executeScripts(const char *_Nonnull scriptFile, char * const _Nonnull args[_Nonnull], bool requiresOutput);
int searchBlockListedStrings(const char *_Nonnull filename, const char *_Nonnull search_str);
int verifyScriptStatusUsingShell(const char *_Nonnull filename);
int checkBlocklistedStringsNChar(const char *_Nonnull haystack);
bool eraseFile(const char *_Nonnull file);
char *_Nullable combineStringsFormatted(const char *_Nonnull format, ...);
char *_Nonnull stringCase(char *_Nonnull string, enum stringCases thisStringCase);
char *_Nullable getpropFromFile(const char *_Nonnull variableName, const char *_Nonnull propFile);
void abort_instance(const char *_Nonnull service, const char *_Nonnull message, ...);
void consoleLog(enum elogLevel loglevel, const char *_Nonnull service, const char *_Nonnull message, ...);
void __freeThisPointer(void *_Nonnull*_Nonnull thisPointer);
#endif
