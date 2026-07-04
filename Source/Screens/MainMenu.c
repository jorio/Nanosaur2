/****************************/
/*   	MAINMENU SCREEN.C	*/
/* By Brian Greenstone      */
/* (c)2003 Pangea Software  */
/* (c)2022 Iliyas Jorio     */
/****************************/

// Everything else is now in MainMenu.swift. The main menu tree (and the
// callbacks it embeds by designated initializer) stays here; see
// MainMenuInternal.h.

#include "game.h"
#include "MainMenuInternal.h"

Boolean	gPlayNow = false;

OGLPoint2D	gCursorCoord;						// screen coords based on 640x480 system

static void CheckForLevelCheat(void);
static void DeleteFileSlot(void);

// This menu tree MUST NOT BE CONST because CheckForLevelCheat needs to change
// a specific MenuItem's .next on the fly!
static MenuItem gMainMenuTree[] =
{
		{ .id='root' },
		{kMIPick, STR_PLAY_GAME,	.next='play', },
		{kMIPick, STR_SETTINGS,		.next='sett', },
		{kMIPick, STR_INFO,			.next='info', },
		{kMIPick, STR_QUIT,			.id='quit', .next='EXIT', },

		{ .id='play' },
		{kMIPick, STR_ADVENTURE,	.next='EXIT', .id='adve', .callback=CheckForLevelCheat},
		{kMIPick, STR_NANO_VS_NANO,	.next='bttl' },
		{kMIPick, STR_SAVED_GAMES,	.next='load'},
		{kMIPick, STR_BACK_SYMBOL,	.next='BACK' },

		{ .id='info' },
		{kMIPick, STR_STORY,			.id='intr',	.next='EXIT' },
		{kMIPick, STR_STORY_SUBTITLED,	.id='ints',	.next='EXIT' },
		{kMIPick, STR_CREDITS,			.id='cred',	.next='EXIT' },
		{kMIPick, STR_BACK_SYMBOL,		.next='BACK' },

		{ .id='bttl' },
		{kMIPick, STR_RACE1,			.id='rac1',	.next='EXIT' },
		{kMIPick, STR_RACE2,			.id='rac2',	.next='EXIT' },
		{kMISpacer, .customHeight=.3f},
		{kMIPick, STR_BATTLE1,			.id='bat1',	.next='EXIT' },
		{kMIPick, STR_BATTLE2,			.id='bat2',	.next='EXIT' },
		{kMISpacer, .customHeight=.3f},
		{kMIPick, STR_CAPTURE1,			.id='cap1',	.next='EXIT' },
		{kMIPick, STR_CAPTURE2,			.id='cap2',	.next='EXIT' },
		{kMISpacer, .customHeight=.3f},
		{kMIPick, STR_BACK_SYMBOL,		.next='BACK' },

		{ .id='chea' },
		{kMILabel, .rawText="CHEAT MENU!"},
		{kMIPick, .rawText="LEVEL 1: FOREST",	.id='cht1',	.next='EXIT' },
		{kMIPick, .rawText="LEVEL 2: DESERT",	.id='cht2',	.next='EXIT' },
		{kMIPick, .rawText="LEVEL 3: SWAMP",	.id='cht3',	.next='EXIT' },
		{kMIPick, STR_BACK_SYMBOL,		.next='BACK' },

		{.id='load'},
		{kMIFileSlot, STR_FILE, .id='lf#0', .fileSlot=0, .getLayoutFlags=DisableEmptyFileSlots, .next='EXIT'},
		{kMIFileSlot, STR_FILE, .id='lf#1', .fileSlot=1, .getLayoutFlags=DisableEmptyFileSlots, .next='EXIT'},
		{kMIFileSlot, STR_FILE, .id='lf#2', .fileSlot=2, .getLayoutFlags=DisableEmptyFileSlots, .next='EXIT'},
		{kMIFileSlot, STR_FILE, .id='lf#3', .fileSlot=3, .getLayoutFlags=DisableEmptyFileSlots, .next='EXIT'},
		{kMIFileSlot, STR_FILE, .id='lf#4', .fileSlot=4, .getLayoutFlags=DisableEmptyFileSlots, .next='EXIT'},
		{kMIPick, STR_DELETE_A_FILE, .next='dele'},
		{kMIPick, STR_BACK_SYMBOL,		.next='BACK' },

		{.id='dele'},
		{kMILabel, .text=STR_DELETE_WHICH, .customHeight=1.5f},
		{kMIFileSlot, STR_DELETE, .id='df#0', .fileSlot=0, .getLayoutFlags=DisableEmptyFileSlots, .callback=DeleteFileSlot, .next='BACK'},
		{kMIFileSlot, STR_DELETE, .id='df#1', .fileSlot=1, .getLayoutFlags=DisableEmptyFileSlots, .callback=DeleteFileSlot, .next='BACK'},
		{kMIFileSlot, STR_DELETE, .id='df#2', .fileSlot=2, .getLayoutFlags=DisableEmptyFileSlots, .callback=DeleteFileSlot, .next='BACK'},
		{kMIFileSlot, STR_DELETE, .id='df#3', .fileSlot=3, .getLayoutFlags=DisableEmptyFileSlots, .callback=DeleteFileSlot, .next='BACK'},
		{kMIFileSlot, STR_DELETE, .id='df#4', .fileSlot=4, .getLayoutFlags=DisableEmptyFileSlots, .callback=DeleteFileSlot, .next='BACK'},
		{kMIPick, STR_BACK_SYMBOL,		.next='BACK' },

		{ .id=0 }
};

MenuItem* GetMainMenuTree(void)
{
	return gMainMenuTree;
}

/********* CHECK FOR LEVEL CHEAT KEY AS PLAYER ENTERS ADVENTURE *********/

static void CheckForLevelCheat(void)
{
			/* SCAN FOR 'ADVENTURE' MENU ITEM */

	for (int i = 0; !IsMenuTreeEndSentinel(&gMainMenuTree[i]); i++)
	{
		if (gMainMenuTree[i].id == 'adve')
		{
			if (IsKeyHeld(SDL_SCANCODE_F10))
			{
				gMainMenuTree[i].next = 'chea';
			}
			else
			{
				gMainMenuTree[i].next = 'EXIT';
			}

			break;
		}
	}
}

/********************* DELETE FILE SLOT ******************/

static void DeleteFileSlot(void)
{
	int id = GetCurrentMenuItemID();

	switch (id)
	{
		case 'df#0':
		case 'df#1':
		case 'df#2':
		case 'df#3':
		case 'df#4':
		case 'df#5':
		case 'df#6':
		case 'df#7':
		case 'df#8':
		case 'df#9':
			DeleteSavedGame(id - 'df#0');
			break;

		default:
			DoAlert("DeleteFileSlot: illegal menu item ID");
	}
}
