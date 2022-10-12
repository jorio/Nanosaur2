#include "game.h"
#include <time.h>

#define kFileMenuMaxLabelLength 50

static MenuItem gFileMenu[MAX_SAVE_FILES+5];
static char gFileMenuLabelBuffer[MAX_SAVE_FILES][kFileMenuMaxLabelLength];

void RegisterFileScreen(int fileScreenMode)
{
	bool isSave = fileScreenMode == FILESCREEN_MODE_SAVE;

	memset(gFileMenu, 0, sizeof(gFileMenu));

	int menuIndex = 0;

	gFileMenu[menuIndex++].id = isSave? 'save': 'load';

//	gFileMenu[menuIndex++] = (MenuItem) { .type=kMILabel, .text=(isSave ? STR_SAVE_GAME : STR_LOAD_GAME) };
//	gFileMenu[menuIndex++] = (MenuItem) { .type=kMISpacer };

	for (int i = 0; i < MAX_SAVE_FILES; i++)
	{
		SaveGameType saveData;

		MenuItem* mi = &gFileMenu[menuIndex++];

		mi->id = (isSave? 'sf#0': 'lf#0') + i;
		mi->next = 'EXIT';
		mi->type = kMIPick;
		mi->text = STR_NULL;
		mi->customHeight = 0.7f;

		if (!LoadSavedGame(i, &saveData))
		{
			snprintf(gFileMenuLabelBuffer[i], kFileMenuMaxLabelLength,
					 "%s-%c: ------ %s ------",
					 Localize(STR_FILE),
					 'A' + i,
					 Localize(STR_EMPTY_SLOT));
		}
		else
		{
			time_t timestamp = (time_t) saveData.timestamp;
			struct tm *timeinfo = localtime(&timestamp);

			snprintf(gFileMenuLabelBuffer[i], kFileMenuMaxLabelLength,
					 "%s-%c: %s %d, %d %s %d",
					 Localize(STR_FILE),
					 'A' + i,
					 Localize(STR_LEVEL),
					 saveData.level+1,
					 timeinfo->tm_mday,
					 Localize(timeinfo->tm_mon + STR_JANUARY),
					 1900 + timeinfo->tm_year);
		}

		mi->rawText = gFileMenuLabelBuffer[i];
	}

	gFileMenu[menuIndex++].type = kMISpacer;

	if (isSave)
	{
		gFileMenu[menuIndex++] = (MenuItem) {kMIPick, STR_CONTINUE_WITHOUT_SAVING, .id='dont', .next='EXIT'};
	}
	else
	{
		gFileMenu[menuIndex++] = (MenuItem) {kMIPick, STR_BACK_SYMBOL, .next='BACK'};
	}

	gFileMenu[menuIndex++].id = 0;		// end sentinel

	GAME_ASSERT(menuIndex <= (int) (sizeof(gFileMenu)/sizeof(gFileMenu[0])));

	RegisterMenu(gFileMenu);
}
