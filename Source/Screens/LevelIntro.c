/****************************/
/*   LEVEL INTRO SCREEN.C   */
/* By Brian Greenstone      */
/* (c)2003 Pangea Software  */
/* (c)2022 Iliyas Jorio     */
/****************************/

// Everything else is now in LevelIntro.swift. MakeLevelIntroSaveSprites'
// menu tree (and the getLayoutFlags callback it embeds by designated
// initializer) stays here; see LevelIntroInternal.h.

#include "game.h"
#include "LevelIntroInternal.h"

static int GetLevelSpecificMenuLayoutFlags(const MenuItem* mi)
{
	int id = mi->id;
	if ((gLevelNum == 1 && id == 'lvl1') || (gLevelNum == 2 && id == 'lvl2'))
	{
		return 0;
	}
	return kMILayoutFlagHidden | kMILayoutFlagDisabled;
}

void MakeLevelIntroSaveSprites(void)
{
	static const MenuItem saveMenuTree[] =
	{
		{ .id='lvin'},
		{ .type=kMIPick, .text=STR_SAVE_GAME, .next='save', .customHeight=1, },
		{ .type=kMIPick, .text=STR_CONTINUE_WITHOUT_SAVING, .customHeight=1, .id='nosv', .next='EXIT' },

		{.id='save'},
		{kMILabel, .text=STR_ENTERING_LEVEL_2, .id='lvl1', .getLayoutFlags=GetLevelSpecificMenuLayoutFlags},
		{kMILabel, .text=STR_ENTERING_LEVEL_3, .id='lvl2', .getLayoutFlags=GetLevelSpecificMenuLayoutFlags},
		{kMIFileSlot, STR_FILE, .id='sf#0', .fileSlot=0, .next='EXIT'},
		{kMIFileSlot, STR_FILE, .id='sf#1', .fileSlot=1, .next='EXIT'},
		{kMIFileSlot, STR_FILE, .id='sf#2', .fileSlot=2, .next='EXIT'},
		{kMIFileSlot, STR_FILE, .id='sf#3', .fileSlot=3, .next='EXIT'},
		{kMIFileSlot, STR_FILE, .id='sf#4', .fileSlot=4, .next='EXIT'},
		{kMIPick, STR_CONTINUE_WITHOUT_SAVING, .id='nosv', .next='EXIT' },
		{kMISpacer, .customHeight=1.5f},

		{ .id=0 }
	};


	MenuStyle style = kDefaultMenuStyle;
	style.darkenPaneOpacity = 0.6f;
	style.yOffset = 400;
	style.standardScale *= 0.75f;
	style.rowHeight *= 0.75f;
	MakeMenu(saveMenuTree, &style);

	MakeMouseCursorObject();
}
