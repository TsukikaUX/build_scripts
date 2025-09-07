//
// Copyright (C) 2025 愛子あゆみ <ayumi.aiko@outlook.com>
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

#include <tsukikautils.h>

int executeCommands(const char *command, char *const args[], bool requiresOutput) {
    if(command && (strstr(command, ";") || strstr(command, "&&") || strstr(command, "|") || strstr(command, "`") || strstr(command, "$(") || strstr(command, "dd"))) abort_instance("executeCommands", "Malicious command detected: %s", command);
    pid_t ProcessID = fork();
    consoleLog(LOG_LEVEL_DEBUG, "executeCommands", "Trying to create a child process for a shell command: %s", command);
    consoleLog(LOG_LEVEL_DEBUG, "executeCommands", "Child process ID: %d", ProcessID);
    switch(ProcessID) {
        case -1:
            consoleLog(LOG_LEVEL_ERROR, "executeCommands", "Failed to fork process.");
            return 1;
        break;
        case 0:
            if(!requiresOutput) {
                int devNull = open("/dev/null", O_WRONLY);
                if(devNull == -1) exit(EXIT_FAILURE);
                dup2(devNull, STDOUT_FILENO);
                dup2(devNull, STDERR_FILENO);
                close(devNull);
            }
            execvp(command, args);
            consoleLog(LOG_LEVEL_ERROR, "executeCommands", "Failed to execute command: %s", command);
            return 1;
        break;
        default:
            consoleLog(LOG_LEVEL_DEBUG, "executeCommands", "Waiting for %s to finish it's process.", command);
            int exitStatus;
            wait(&exitStatus);
            consoleLog(LOG_LEVEL_DEBUG, "executeCommands", "%s successfully executed.", command);
            return (WIFEXITED(exitStatus)) ? WEXITSTATUS(exitStatus) : 1;
    }
}

int executeScripts(const char *script_file, char *const args[], bool requiresOutput) {
    // verify and execute.
    for(int i = 0; args[i] != NULL; i++) {
        if(strstr(args[i], ";") || strstr(args[i], "&&") || strstr(args[i], "|") || strstr(args[i], "$(")) abort_instance("executeScripts", "Malicious hijack attempts detected: %s", args[i]);
    }
    if(checkBlocklistedStringsNChar(script_file) != 0 && verifyScriptStatusUsingShell(script_file) != 0) abort_instance("executeScripts", "The given script either doesn't have executable permission or it contains malicious commands. Please report this issue immediately. (%s)", script_file);
    pid_t ProcessID = fork();
    consoleLog(LOG_LEVEL_DEBUG, "executeScripts", "Trying to create a child process for a shell script execution, path to the script: %s", script_file);
    consoleLog(LOG_LEVEL_DEBUG, "executeScripts", "Child process ID: %d", ProcessID);
    switch(ProcessID) {
        case -1:
            consoleLog(LOG_LEVEL_ERROR, "executeScripts", "Failed to fork process.");
            return 1;
        break;
        case 0:
            if(!requiresOutput) {
                int devNull = open("/dev/null", O_WRONLY);
                if(devNull == -1) exit(EXIT_FAILURE);
                dup2(devNull, STDOUT_FILENO);
                dup2(devNull, STDERR_FILENO);
                close(devNull);
            }
            execv(script_file, args);
            consoleLog(LOG_LEVEL_ERROR, "executeScripts", "Failed to execute %s", script_file);
            return 1;
        break;
        default:
            consoleLog(LOG_LEVEL_DEBUG, "executeScripts", "Waiting for script to finish it's process.");
            int exitStatus;
            wait(&exitStatus);
            consoleLog(LOG_LEVEL_DEBUG, "executeScripts", "Script successfully executed.");
            return (WIFEXITED(exitStatus)) ? WEXITSTATUS(exitStatus) : 1;
    }
}

// -----------------------------------------------------------------------------
// prevents bastards from running any malicious commands
// this searches some sensitive strings to ensure that the script is safe
// please verify your scripts before running it PLEASE 🙏
// -----------------------------------------------------------------------------
// Hi! i don't think i'm good at C, so please don't trash talk about me and just 
// help me to improve myself if you can or otherwise don't be a bad guy on me.
// -----------------------------------------------------------------------------
int searchBlockListedStrings(const char *filename, const char *search_str) {
    size_t sizeOfTheseCraps = strlen(filename) + strlen(search_str) + 3;
    char *command = malloc(sizeOfTheseCraps);
    // we failed to get the memory we want.
    if(!command) abort_instance("searchBlockListedStrings", "Failed to allocate memory for searching blocklisted strings.");
    // let's grab the shell exitCode from the command. it's better to use native C but- nvm let's just use native C instead.
    char boii[8000];
    FILE *fptr = fopen(filename, "r"); 
    if(!fptr) abort_instance("searchBlockListedStrings", "Failed to open file for reading: %s", filename);
    while(fgets(boii, sizeof(boii), fptr) != NULL) {
        boii[strcspn(boii, "\n")] = '\0';
        if(strstr(boii, search_str)) {
            fclose(fptr);
            consoleLog(LOG_LEVEL_ERROR, "searchBlockListedStrings", "Malicious code execution detected in the script file: %s", filename);
            return 1;
        }
    }
    fclose(fptr);
    return 0;
}

// yet another thing to protect good peoples from getting fucked
// this ensures that the chosen is a bash script and if it's not one
// it'll return 1 to make the program to stop from executing that bastard
int verifyScriptStatusUsingShell(const char *filename) {
    return executeCommands("file", (char *const[]) {"file", combineStringsFormatted("file %s | grep -q 'ASCII text executable'", filename), NULL}, false) == 0;
}

// Checks if a given string contains blacklisted substrings
int checkBlocklistedStringsNChar(const char *haystack) {
    static const char *blocklistedStrings[] = {
        "/xbl_config",
        "/fsc",
        "/fsg",
        "/modem",
        "/modemst1",
        "/modemst2",
        "/abl",
        "/keymaster",
        "/sda",
        "/sdb",
        "/sdc",
        "/sdd",
        "/sde",
        "/sdf",
        "/splash",
        "/dtbo",
        "/bluetooth",
        "/cust",
        "/xbl",
        "/persist",
        "/dev/block/bootdevice/by-name/",
        "/dev/block/by-name/",
        "/dev/block/",
        "/system/bin/dd",
        "/vendor/bin/dd",
        "dd",
        "/dev/block/mmcblk",
        "/dev/mmcblk"
    };
    for(int i = 0; i < sizeof(blocklistedStrings) / sizeof(blocklistedStrings[0]); i++) {
        if(searchBlockListedStrings(haystack, blocklistedStrings[i]) == 1) {
            consoleLog(LOG_LEVEL_ERROR, "checkBlocklistedStringsNChar", "checkBlocklistedStringsNChar(): Found Blocklisted string: %s", blocklistedStrings[i]);
            consoleLog(LOG_LEVEL_ERROR, "checkBlocklistedStringsNChar", "checkBlocklistedStringsNChar(): The script is not safe to execute! Stopping execution process...");
            return 1;
        }
    }
    return 0;
}

bool erase_file_content(const char *file) {
    FILE *fileConstantAgain = fopen(file, "w");
    if(!fileConstantAgain) return false;
    fclose(fileConstantAgain);
    return true;
}

char *cStringToLower(char *str) {
    int i = 0;
    while(str[i]) {
        str[i] = tolower((unsigned char)str[i]);
        i++;
    }
    return str;
}

char *cStringToUpper(char *str) {
    int i = 0;
    while(str[i]) {
        str[i] = toupper((unsigned char)str[i]);
        i++;
    }
    return str;
}

// NOTE: THIS FUNCTION RETURNS STACK AND SHOULD BE CLEARED!!
char *combineStringsFormatted(const char *format, ...) {
    va_list args;
    va_start(args, format);
    va_list args_copy;
    va_copy(args_copy, args);
    int len = vsnprintf(NULL, 0, format, args_copy);
    va_end(args_copy);
    if(len < 0) {
        va_end(args);
        return NULL;
    }
    char *result = malloc(len + 1);
    if(!result) {
        va_end(args);
        return NULL;
    }
    vsnprintf(result, len + 1, format, args);
    va_end(args);
    if(!result) return NULL;
    return result;
}

void abort_instance(const char *service, const char *format, ...) {
    va_list args;
    va_start(args, format);
    consoleLog(LOG_LEVEL_ERROR, "%s", "abort_instance(): %s %s", service, format, args);
    va_end(args);
    exit(EXIT_FAILURE);
}

void consoleLog(enum elogLevel loglevel, const char *service, const char *message, ...) {
    va_list args;
    va_start(args, message);
    FILE *out = NULL;
    bool toFile = false;
    if(useStdoutForAllLogs) {
        out = stdout;
        if(loglevel == LOG_LEVEL_ERROR || loglevel == LOG_LEVEL_WARN || loglevel == LOG_LEVEL_DEBUG) out = stderr;
    }
    else {
        out = fopen(LOGFILE, "a");
        if(!out) exit(EXIT_FAILURE);
        toFile = true;
    }
    switch(loglevel) {
        case LOG_LEVEL_INFO:
            if(!toFile) fprintf(out, "\033[2;30;47mINFO: ");
            else fprintf(out, "INFO: %s: ", service);
        break;
        case LOG_LEVEL_WARN:
            if(!toFile) fprintf(out, "\033[1;33mWARNING: ");
            else fprintf(out, "WARNING: %s: ", service);
        break;
        case LOG_LEVEL_DEBUG:
            if(!toFile) fprintf(out, "\033[0;36mDEBUG: ");
            else fprintf(out, "DEBUG: %s: ", service);
        break;
        case LOG_LEVEL_ERROR:
            if(!toFile) fprintf(out, "\033[0;31mERROR: ");
            else fprintf(out, "ERROR: %s: ", service);
        break;
    }
    vfprintf(out, message, args);
    if(!toFile) fprintf(out, "\033[0m\n");
    else fprintf(out, "\n");
    if(!useStdoutForAllLogs && out) fclose(out);
    va_end(args);
}