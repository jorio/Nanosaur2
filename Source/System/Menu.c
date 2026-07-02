// MENU.C
// Global variable definitions for menu system
// All function implementations are now in Menu.swift

#include "game.h"
#include "MenuInternal.h"
#include <SDL3/SDL_time.h>

// Menu state global
MenuNavigation* gNav = NULL;

// Menu outcome global (used by other modules)
int gMenuOutcome = 0;

// Menu registry globals
int gNumMenusRegistered = 0;
const MenuItem* gMenuRegistry[MAX_REGISTERED_MENUS];

// Default menu style (declared extern in menu.h)
const MenuStyle kDefaultMenuStyle =
{
	.darkenPaneOpacity	= 0,
	.fadeInSpeed		= (1.0f / 0.3f),
	.fadeOutSpeed		= (1.0f / 0.2f),
	.asyncFadeOut		= true,
	.fadeOutSceneOnExit	= false,
	.standardScale		= 0.45f,
	.rowHeight			= 38.0f,
	.startButtonExits	= false,
	.isInteractive		= true,
	.canBackOutOfRootMenu	= false,
	.textSlot			= MENU_SLOT,
	.yOffset			= 480/2,
	.fontAtlas			= ATLAS_GROUP_FONT1,
	.fontAtlas2			= ATLAS_GROUP_FONT2,

	.highlightColor		= {1.0f, 1.0f, 1.0f, 1.0f},
	.arrowColor			= {1.0f, 1.0f, 1.0f, 1.0f},
	.idleColor			= {0.7f, 0.6f, 0.6f, 1.0f},
	.labelColor			= {1.0f, 1.0f, 1.0f, 1.0f},
};

// Input binding types needed for binding functions
// (defined in input.h, accessible via bridging header)