#include <tsukika.h>

// extern variables
extern int currentState;

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
void addModuleToBlocklist(void* thisModule);
void runThisModule(void *thisModule);
