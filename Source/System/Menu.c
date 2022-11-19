// MENU.C
// (c)2022 Iliyas Jorio
// This file is part of Cro-Mag Rally. https://github.com/jorio/cromagrally

/****************************/
/*    EXTERNALS             */
/****************************/

#include "game.h"
#include "uieffects.h"

#include <SDL.h>
#include <SDL_opengl.h>
#include <math.h>
#include <string.h>

#define DECLARE_WORKBUF(buf, bufSize) char (buf)[256]; const int (bufSize) = 256
#define DECLARE_STATIC_WORKBUF(buf, bufSize) static char (buf)[256]; static const int (bufSize) = 256

#define USE_SDL_CURSOR 0

#define CYCLER_ARROW_PADDING 80
#define CYCLER_ARROW_INSET 30

/****************************/
/*    PROTOTYPES            */
/****************************/

static ObjNode* MakeText(const char* text, int row, int col, int flags);

static void MoveMenuDriver(ObjNode* theNode);
static void CleanUpMenuDriver(ObjNode* theNode);

static const MenuItem* LookUpMenu(int menuID);
static void LayOutMenu(int menuID);

static ObjNode* LayOutCycler2ValueText(int row);
static ObjNode* LayOutFloatRangeValueText(int row);

static ObjNode* LayOutCycler1(int row);
static ObjNode* LayOutCycler2(int row);
static ObjNode* LayOutPick(int row);
static ObjNode* LayOutLabel(int row);
static ObjNode* LayOutKeyBinding(int row);
static ObjNode* LayOutPadBinding(int row);
static ObjNode* LayOutMouseBinding(int row);
static ObjNode* LayOutFloatRange(int row);

static void NavigateCycler(const MenuItem* entry);
static void NavigatePick(const MenuItem* entry);
static void NavigateKeyBinding(const MenuItem* entry);
static void NavigatePadBinding(const MenuItem* entry);
static void NavigateMouseBinding(const MenuItem* entry);
static void NavigateFloatRange(const MenuItem* entry);

static float GetMenuItemHeight(int row);
static int GetCyclerNumChoices(const MenuItem* entry);
static int GetValueIndexInCycler(const MenuItem* entry, uint8_t value);

typedef struct
{
	Boolean		muted;
	Byte		row;
	Byte		col;
	float		pulsateTimer;
//	float		incrementCooldown;
//	int			nIncrements;
} MenuNodeData;
_Static_assert(sizeof(MenuNodeData) <= MAX_SPECIAL_DATA_BYTES, "MenuNodeData doesn't fit in special area");
#define GetMenuNodeData(node) ((MenuNodeData*) (node)->SpecialPadding)

/****************************/
/*    CONSTANTS             */
/****************************/

#define MAX_MENU_ROWS	25
#define MAX_STACK_LENGTH 16
#define CLEAR_BINDING_SCANCODE SDL_SCANCODE_X

#define kDefaultX			(640/2)

#define kSfxCycle			EFFECT_GRABEGG

#define PlayEffectForMenu(x)		PlayEffect_Parms((x), FULL_CHANNEL_VOLUME/4, FULL_CHANNEL_VOLUME/4, NORMAL_CHANNEL_RATE)
#define PlayNavigateEffect()		PlayEffectForMenu(EFFECT_CHANGESELECT)
#define PlayConfirmEffect()			PlayEffectForMenu(EFFECT_MENUSELECT)
#define PlayBackEffect()			PlayEffectForMenu(EFFECT_CHANGEWEAPON)
#define PlayErrorEffect()			PlayEffectForMenu(EFFECT_BADSELECT)
#define PlayDeleteEffect()			PlayEffectForMenu(EFFECT_CRYSTALSHATTER)
#define PlayStartBindingEffect()	PlayEffectForMenu(EFFECT_GRABEGG)
#define PlayEndBindingEffect()		PlayEffectForMenu(EFFECT_MENUSELECT)

const int16_t kJoystickDeadZone_BindingThreshold = (75 * 32767 / 100);

enum
{
	kMenuStateOff,
	kMenuStateFadeIn,
	kMenuStateReady,
	kMenuStateFadeOut,
	kMenuStateAwaitingKeyPress,
	kMenuStateAwaitingPadPress,
	kMenuStateAwaitingMouseClick,
};

const MenuStyle kDefaultMenuStyle =
{
	.darkenPaneOpacity	= 0,
	.fadeInSpeed		= (1.0f / 0.3f),
	.fadeOutSpeed		= (1.0f / 0.2f),
	.asyncFadeOut		= true,
	.fadeOutSceneOnExit	= false,
	.standardScale		= (35 / (64/2.0)) / 2,		// Nanosaur 2 original value with old sprite system: 35
	.rowHeight			= (35 * 1.1),				// Nanosaur 2 original value with old sprite system: 35*1.1
	.uniformXExtent		= 0,
	.startButtonExits	= false,
	.isInteractive		= true,
	.canBackOutOfRootMenu	= false,
	.textSlot			= MENU_SLOT,
	.yOffset			= 480/2,
	.fontAtlas			= SPRITE_GROUP_FONT1,

	.highlightColor		= {1.0f, 1.0f, 1.0f, 1.0f},
	.arrowColor			= {0.7f, 0.7f, 0.7f, 1.0f},
	.idleColor			= {0.7f, 0.6f, 0.6f, 1.0f},
	.labelColor			= {1.0f, 1.0f, 1.0f, 1.0f},
};

typedef struct
{
	float height;
	ObjNode* (*layOutCallback)(int row);
	void (*navigateCallback)(const MenuItem* menuItem);
} MenuItemClass;

static const MenuItemClass kMenuItemClasses[kMI_COUNT] =
{
	[kMISENTINEL]		= {0.0f, NULL, NULL },
	[kMILabel]			= {0.5f, LayOutLabel, NULL },
	[kMISpacer]			= {0.5f, NULL, NULL },
	[kMICycler1]		= {1.0f, LayOutCycler1, NavigateCycler },
	[kMICycler2]		= {1.0f, LayOutCycler2, NavigateCycler },
	[kMIFloatRange]		= {0.6f, LayOutFloatRange, NavigateFloatRange },
	[kMIPick]			= {1.0f, LayOutPick, NavigatePick },
	[kMIKeyBinding]		= {0.5f, LayOutKeyBinding, NavigateKeyBinding },
	[kMIPadBinding]		= {0.5f, LayOutPadBinding, NavigatePadBinding },
	[kMIMouseBinding]	= {0.5f, LayOutMouseBinding, NavigateMouseBinding },
};

/*********************/
/*    VARIABLES      */
/*********************/

typedef struct
{
	int					menuID;
	const MenuItem*		menu;
	MenuStyle			style;

	int					numMenuEntries;

	int					menuRow;
	int					menuCol;

	float				menuRowYs[MAX_MENU_ROWS];
	float				menuFadeAlpha;
	int					menuState;
	int					menuPick;
	ObjNode*			menuObjects[MAX_MENU_ROWS];

	struct
	{
		int menuID;
		int row;
	} history[MAX_STACK_LENGTH];
	int					historyPos;

	bool				mouseControl;
	bool				mouseHoverValid;
	int					mouseHoverColumn;
#if USE_SDL_CURSOR
	SDL_Cursor*			handCursor;
	SDL_Cursor*			standardCursor;
#endif

	float				idleTime;

	ObjNode*			arrowObjects[2];
	ObjNode*			darkenPane;

	signed char			mouseArrowHoverState;
} MenuNavigation;

static MenuNavigation* gNav = NULL;

static float gTempInitialSweepFactor = 0;
static bool gTempForceSwipeRTL = false;

int gMenuOutcome = 0;

/***********************************/
/*    MENU NAVIGATION STRUCT       */
/***********************************/
#pragma mark - Navigation struct

static void InitMenuNavigation(void)
{
	MenuNavigation* nav = NULL;

	GAME_ASSERT(gNav == NULL);
	nav = (MenuNavigation*) AllocPtrClear(sizeof(MenuNavigation));
	gNav = nav;

	memcpy(&nav->style, &kDefaultMenuStyle, sizeof(MenuStyle));
	nav->menuPick = -1;
	nav->menuState = kMenuStateOff;
	nav->mouseHoverColumn = -1;
	nav->mouseControl = true;

#if USE_SDL_CURSOR
	nav->standardCursor = SDL_CreateSystemCursor(SDL_SYSTEM_CURSOR_ARROW);
	nav->handCursor = SDL_CreateSystemCursor(SDL_SYSTEM_CURSOR_HAND);
#endif

	NewObjectDefinitionType arrowDef =
	{
		.scale = 1,
		.slot = nav->style.textSlot,
		.group = nav->style.fontAtlas,
		.flags = STATUS_BIT_MOVEINPAUSE,
	};

	for (int i = 0; i < 2; i++)
	{
		nav->arrowObjects[i] = TextMesh_New(i == 0 ? "<" : ">", 0, &arrowDef);
		nav->arrowObjects[i]->ColorFilter = nav->style.arrowColor;
		SendNodeToOverlayPane(nav->arrowObjects[i]);
	}
}

static void DisposeMenuNavigation(void)
{
	MenuNavigation* nav = gNav;

	for (int i = 0; i < 2; i++)
	{
		if (nav->arrowObjects[i] != NULL)
		{
			DeleteObject(nav->arrowObjects[i]);
			nav->arrowObjects[i] = NULL;
		}
	}

#if USE_SDL_CURSOR
	if (nav->standardCursor != NULL)
	{
		SDL_FreeCursor(nav->standardCursor);
		nav->standardCursor = NULL;
	}

	if (nav->handCursor != NULL)
	{
		SDL_FreeCursor(nav->handCursor);
		nav->handCursor = NULL;
	}
#endif

	SafeDisposePtr((Ptr) nav);

	gNav = nil;
}

int GetCurrentMenu(void)
{
	return gNav->menuID;
}

float GetMenuIdleTime(void)
{
	return gNav->idleTime;
}

void KillMenu(int returnCode)
{
	if (gNav->menuState == kMenuStateReady)
	{
		gNav->menuPick = returnCode;
		gNav->menuState = kMenuStateFadeOut;
	}
}

#if USE_SDL_CURSOR
static void SetStandardMouseCursor(void)
{
	if (gNav->standardCursor != NULL &&
		gNav->standardCursor != SDL_GetCursor())
	{
		SDL_SetCursor(gNav->standardCursor);
	}
}

static void SetHandMouseCursor(void)
{
	if (gNav->handCursor != NULL &&
		gNav->handCursor != SDL_GetCursor())
	{
		SDL_SetCursor(gNav->handCursor);
	}
}
#endif

int GetCurrentMenuItemID(void)
{
	if (gNav->menuRow < 0)
		return -1;

	return gNav->menu[gNav->menuRow].id;
}

ObjNode* GetCurrentMenuItemObject(void)
{
	if (gNav->menuRow < 0)
		return NULL;

	return gNav->menuObjects[gNav->menuRow];
}

bool IsMenuTreeEndSentinel(const MenuItem* menuItem)
{
	return menuItem->id == 0 && menuItem->type == kMISENTINEL;
}

/****************************/
/*    MENU UTILITIES        */
/****************************/
#pragma mark - Utilities

static const char* FourccToString(int fourCC)
{
	static char string[5];
	string[0] = (fourCC >> 24) & 0xFF;
	string[1] = (fourCC >> 16) & 0xFF;
	string[2] = (fourCC >> 8) & 0xFF;
	string[3] = (fourCC) & 0xFF;
	string[4] = 0;
	return string;
}

static int GetLayoutFlags(const MenuItem* mi)
{
	if (mi->getLayoutFlags)
		return mi->getLayoutFlags();
	else
		return 0;
}

static OGLColorRGBA PulsateColor(float* time)
{
	*time += gFramesPerSecondFrac;
	float intensity = (1.0f + sinf(*time * 10.0f)) * 0.5f;
	return (OGLColorRGBA) {1,1,1,intensity};
}

static InputBinding* GetBindingAtRow(int row)
{
	return &gGamePrefs.bindings[gNav->menu[row].inputNeed];
}

static const char* GetKeyBindingName(int row, int col)
{
	int16_t scancode = GetBindingAtRow(row)->key[col];

	switch (scancode)
	{
		case 0:								return Localize(STR_UNBOUND_PLACEHOLDER);
		case SDL_SCANCODE_APOSTROPHE:		return "Apostrophe";
		case SDL_SCANCODE_BACKSLASH:		return "Backslash";
		case SDL_SCANCODE_GRAVE:			return "Backtick";
		case SDL_SCANCODE_SEMICOLON:		return "Semicolon";
		default:							return SDL_GetScancodeName(scancode);
	}
}

static const char* GetPadBindingName(int row, int col)
{
	const PadBinding* pb = &GetBindingAtRow(row)->pad[col];

	switch (pb->type)
	{
		case kInputTypeUnbound:
			return Localize(STR_UNBOUND_PLACEHOLDER);

		case kInputTypeButton:
			switch (pb->id)
			{
				case SDL_CONTROLLER_BUTTON_INVALID:			return Localize(STR_UNBOUND_PLACEHOLDER);
				case SDL_CONTROLLER_BUTTON_A:				return Localize(STR_CONTROLLER_BUTTON_A);
				case SDL_CONTROLLER_BUTTON_B:				return Localize(STR_CONTROLLER_BUTTON_B);
				case SDL_CONTROLLER_BUTTON_X:				return Localize(STR_CONTROLLER_BUTTON_X);
				case SDL_CONTROLLER_BUTTON_Y:				return Localize(STR_CONTROLLER_BUTTON_Y);
				case SDL_CONTROLLER_BUTTON_LEFTSHOULDER:	return Localize(STR_CONTROLLER_BUTTON_LEFTSHOULDER);
				case SDL_CONTROLLER_BUTTON_RIGHTSHOULDER:	return Localize(STR_CONTROLLER_BUTTON_RIGHTSHOULDER);
				case SDL_CONTROLLER_BUTTON_LEFTSTICK:		return Localize(STR_CONTROLLER_BUTTON_LEFTSTICK);
				case SDL_CONTROLLER_BUTTON_RIGHTSTICK:		return Localize(STR_CONTROLLER_BUTTON_RIGHTSTICK);
				case SDL_CONTROLLER_BUTTON_DPAD_UP:			return Localize(STR_CONTROLLER_BUTTON_DPAD_UP);
				case SDL_CONTROLLER_BUTTON_DPAD_DOWN:		return Localize(STR_CONTROLLER_BUTTON_DPAD_DOWN);
				case SDL_CONTROLLER_BUTTON_DPAD_LEFT:		return Localize(STR_CONTROLLER_BUTTON_DPAD_LEFT);
				case SDL_CONTROLLER_BUTTON_DPAD_RIGHT:		return Localize(STR_CONTROLLER_BUTTON_DPAD_RIGHT);
				default:
					return SDL_GameControllerGetStringForButton(pb->id);
			}
			break;

		case kInputTypeAxisPlus:
			switch (pb->id)
			{
				case SDL_CONTROLLER_AXIS_INVALID:			return Localize(STR_UNBOUND_PLACEHOLDER);
				case SDL_CONTROLLER_AXIS_LEFTX:				return Localize(STR_CONTROLLER_AXIS_LEFTSTICK_RIGHT);
				case SDL_CONTROLLER_AXIS_LEFTY:				return Localize(STR_CONTROLLER_AXIS_LEFTSTICK_DOWN);
				case SDL_CONTROLLER_AXIS_RIGHTX:			return Localize(STR_CONTROLLER_AXIS_RIGHTSTICK_RIGHT);
				case SDL_CONTROLLER_AXIS_RIGHTY:			return Localize(STR_CONTROLLER_AXIS_RIGHTSTICK_DOWN);
				case SDL_CONTROLLER_AXIS_TRIGGERLEFT:		return Localize(STR_CONTROLLER_AXIS_LEFTTRIGGER);
				case SDL_CONTROLLER_AXIS_TRIGGERRIGHT:		return Localize(STR_CONTROLLER_AXIS_RIGHTTRIGGER);
				default:
					return SDL_GameControllerGetStringForAxis(pb->id);
			}
			break;

		case kInputTypeAxisMinus:
			switch (pb->id)
			{
				case SDL_CONTROLLER_AXIS_INVALID:			return Localize(STR_UNBOUND_PLACEHOLDER);
				case SDL_CONTROLLER_AXIS_LEFTX:				return Localize(STR_CONTROLLER_AXIS_LEFTSTICK_LEFT);
				case SDL_CONTROLLER_AXIS_LEFTY:				return Localize(STR_CONTROLLER_AXIS_LEFTSTICK_UP);
				case SDL_CONTROLLER_AXIS_RIGHTX:			return Localize(STR_CONTROLLER_AXIS_RIGHTSTICK_LEFT);
				case SDL_CONTROLLER_AXIS_RIGHTY:			return Localize(STR_CONTROLLER_AXIS_RIGHTSTICK_UP);
				case SDL_CONTROLLER_AXIS_TRIGGERLEFT:		return Localize(STR_CONTROLLER_AXIS_LEFTTRIGGER);
				case SDL_CONTROLLER_AXIS_TRIGGERRIGHT:		return Localize(STR_CONTROLLER_AXIS_RIGHTTRIGGER);
				default:
					return SDL_GameControllerGetStringForAxis(pb->id);
			}
			break;

		default:
			return "???";
	}
}

static const char* GetMouseBindingName(int row)
{
	DECLARE_STATIC_WORKBUF(buf, bufSize);

	InputBinding* binding = GetBindingAtRow(row);

	switch (binding->mouseButton)
	{
		case 0:							return Localize(STR_UNBOUND_PLACEHOLDER);
		case SDL_BUTTON_LEFT:			return Localize(STR_MOUSE_BUTTON_LEFT);
		case SDL_BUTTON_MIDDLE:			return Localize(STR_MOUSE_BUTTON_MIDDLE);
		case SDL_BUTTON_RIGHT:			return Localize(STR_MOUSE_BUTTON_RIGHT);
		case SDL_BUTTON_WHEELUP:		return Localize(STR_MOUSE_WHEEL_UP);
		case SDL_BUTTON_WHEELDOWN:		return Localize(STR_MOUSE_WHEEL_DOWN);
		case SDL_BUTTON_WHEELLEFT:		return Localize(STR_MOUSE_WHEEL_LEFT);
		case SDL_BUTTON_WHEELRIGHT:		return Localize(STR_MOUSE_WHEEL_RIGHT);
		default:
			snprintf(buf, bufSize, "%s %d", Localize(STR_BUTTON), binding->mouseButton);
			return buf;
	}
}

static ObjNode* MakeKbText(int row, int keyNo)
{
	const char* kbName;

	if (gNav->menuState == kMenuStateAwaitingKeyPress)
	{
		kbName = Localize(STR_PRESS);
	}
	else
	{
		kbName = GetKeyBindingName(row, keyNo);
	}

	ObjNode* node = MakeText(kbName, row, 1+keyNo, kTextMeshAllCaps | kTextMeshAlignLeft);
	GetMenuNodeData(node)->col = keyNo;
	return node;
}

static ObjNode* MakePbText(int row, int btnNo)
{
	const char* pbName;

	if (gNav->menuState == kMenuStateAwaitingPadPress)
	{
		pbName = Localize(STR_PRESS);
	}
	else
	{
		pbName = GetPadBindingName(row, btnNo);
	}

	ObjNode* node = MakeText(pbName, row, 1+btnNo, kTextMeshAllCaps | kTextMeshAlignLeft);
	GetMenuNodeData(node)->col = btnNo;
	return node;
}

static ObjNode* MakeMbText(int row)
{
	const char* mbName;

	if (gNav->menuState == kMenuStateAwaitingMouseClick)
	{
		mbName = Localize(STR_CLICK);
	}
	else
	{
		mbName = GetMouseBindingName(row);
	}

	ObjNode* node = MakeText(mbName, row, 1, kTextMeshAllCaps | kTextMeshAlignLeft);
	GetMenuNodeData(node)->col = 0;
	return node;
}

static bool IsMenuItemSelectable(const MenuItem* mi)
{
	switch (mi->type)
	{
		case kMISpacer:
		case kMILabel:
			return false;

		default:
			return !(GetLayoutFlags(mi) & (kMILayoutFlagHidden | kMILayoutFlagDisabled));
	}

}

static void ReplaceMenuText(LocStrID originalTextInMenuDefinition, LocStrID newText)
{
	for (int i = 0; i < MAX_MENU_ROWS && gNav->menu[i].type != kMISENTINEL; i++)
	{
		if (gNav->menu[i].text == originalTextInMenuDefinition)
		{
			MakeText(Localize(newText), i, 0, 0);
		}
	}
}

static void SaveSelectedRowInHistory(void)
{
	gNav->history[gNav->historyPos].row = gNav->menuRow;
}

static void TwitchSelectionInOrOut(bool scaleIn)
{
	ObjNode* obj = GetCurrentMenuItemObject();

	switch (gNav->menu[gNav->menuRow].type)
	{
		case kMIKeyBinding:
		case kMIPadBinding:
		case kMIMouseBinding:
			obj = GetNthChainedNode(obj, 1+gNav->menuCol, NULL);
			break;

		case kMIFloatRange:
			obj = GetNthChainedNode(obj, 1, NULL);
			break;

		default:
			break;
	}

	if (!obj)
		return;


	float s = GetMenuItemHeight(gNav->menuRow) * gNav->style.standardScale;
	obj->Scale.x = s * (scaleIn? 1.1: 1);
	obj->Scale.y = s * (scaleIn? 1.1: 1);

	MakeTwitch(obj, (scaleIn ? kTwitchPreset_MenuSelect : kTwitchPreset_MenuDeselect) | kTwitchFlags_Chain);
}

static void TwitchSelection(void)
{
	TwitchSelectionInOrOut(true);
}

static void TwitchOutSelection(void)
{
	TwitchSelectionInOrOut(false);
}

/****************************/
/*    DARKEN PANE           */
/****************************/
#pragma mark - Move calls

static void MoveDarkenPane(ObjNode* node)
{
	SOFTIMPME;

#if 0
	node->Scale.x = gGameViewInfoPtr->panes[GetOverlayPaneNumber()].logicalWidth * (1.0f / 4.0f);
	UpdateObjectTransforms(node);
#endif
}

static void RescaleDarkenPane(ObjNode* node, float totalHeight)
{
	SOFTIMPME;

#if 0
	float prevScale = node->Scale.y;
	float newScale = 1.3f * totalHeight / GetSpriteInfo(SPRITE_GROUP_INFOBAR, INFOBAR_SObjType_OverlayBackground)->yadv;

	node->Coord.y = gNav->style.yOffset;
	node->Scale.y = newScale;
	UpdateObjectTransforms(gNav->darkenPane);

	Twitch* scaleEffect = MakeTwitch(gNav->darkenPane, kTwitchPreset_MenuDarkenPaneResize);
	if (scaleEffect)
	{
		scaleEffect->amplitude = prevScale/newScale;
	}
#endif
}

static ObjNode* MakeDarkenPane(void)
{
	SOFTIMPME;
	return NULL;

#if 0
	ObjNode* pane;

	NewObjectDefinitionType def =
	{
		.genre = CUSTOM_GENRE,
		.flags = STATUS_BITS_FOR_2D | STATUS_BIT_MOVEINPAUSE,
		.slot = gNav->style.textSlot-1,
		.scale = EPS,
		.group = SPRITE_GROUP_INFOBAR,
		.type = INFOBAR_SObjType_OverlayBackground,
		.coord = {0, gNav->style.yOffset, 0},
		.moveCall = MoveDarkenPane,
	};

	pane = MakeSpriteObject(&def);
	pane->ColorFilter = (OGLColorRGBA) {0, 0, 0, gNav->style.darkenPaneOpacity};
	SendNodeToOverlayPane(pane);

	return pane;
#endif
}

/****************************/
/*    MENU MOVE CALLS       */
/****************************/
#pragma mark - Move calls

static void MoveGenericMenuItem(ObjNode* node, float baseAlpha)
{
	MenuNodeData* data = GetMenuNodeData(node);

	if (data->muted)
	{
		baseAlpha *= .5f;
	}

	node->ColorFilter.a = baseAlpha;

	// Don't mix gNav->menuFadeAlpha -- it's only useful when fading OUT,
	// in which case we're using a different move call for all menu items
}

static void MoveLabel(ObjNode* node)
{
	MoveGenericMenuItem(node, 1);
}

static void MoveAction(ObjNode* node)
{
	if (GetMenuNodeData(node)->row == gNav->menuRow)
		node->ColorFilter = gNav->style.highlightColor; //TwinkleColor();
	else
		node->ColorFilter = gNav->style.idleColor;

	MoveGenericMenuItem(node, 1);
}

static void MoveControlBinding(ObjNode* node)
{
	MenuNodeData* data = GetMenuNodeData(node);

	int pulsatingState = 0;
	switch (gNav->menu[data->row].type)
	{
		case kMIKeyBinding:
			pulsatingState = kMenuStateAwaitingKeyPress;
			break;

		case kMIPadBinding:
			pulsatingState = kMenuStateAwaitingPadPress;
			break;

		case kMIMouseBinding:
			pulsatingState = kMenuStateAwaitingMouseClick;
			break;

		default:
			DoFatalAlert("MoveControlBinding: unknown MI type");
	}

	if (data->row == gNav->menuRow && data->col == gNav->menuCol)
	{
		if (gNav->menuState == pulsatingState)
		{
			node->ColorFilter = PulsateColor(&data->pulsateTimer);
		}
		else
		{
			node->ColorFilter = gNav->style.highlightColor; //TwinkleColor();
		}
	}
	else
	{
		node->ColorFilter = gNav->style.idleColor;
	}

	MoveGenericMenuItem(node, node->ColorFilter.a);
}

/****************************/
/*    MENU NAVIGATION       */
/****************************/
#pragma mark - Menu navigation

static void GoBackInHistory(void)
{
	MyFlushEvents();

	if (gNav->historyPos != 0)
	{
		PlayBackEffect();
		gNav->historyPos--;

		gTempForceSwipeRTL = true;
		LayOutMenu(gNav->history[gNav->historyPos].menuID);
		gTempForceSwipeRTL = false;
	}
	else if (gNav->style.canBackOutOfRootMenu)
	{
		PlayBackEffect();
		gNav->menuState = kMenuStateFadeOut;
	}
	else
	{
		PlayErrorEffect();
	}
}

static void UpdateArrows(void)
{
	ObjNode* snapTo = NULL;
	ObjNode* chainRoot = GetCurrentMenuItemObject();

	bool visible[2] = {false, false};

	const MenuItem* entry = &gNav->menu[gNav->menuRow];
	switch (entry->type)
	{
		case kMICycler1:
		{
			snapTo = chainRoot;

			int index = GetValueIndexInCycler(entry, *entry->cycler.valuePtr);

			visible[0] = (index != 0);
			visible[1] = (index != GetCyclerNumChoices(entry)-1);
			break;
		}

		case kMICycler2:
		case kMIFloatRange:
			visible[0] = true;
			visible[1] = true;
			snapTo = GetNthChainedNode(chainRoot, 1, NULL);
			break;

		case kMIKeyBinding:
		case kMIPadBinding:
		case kMIMouseBinding:
			visible[0] = true;
			visible[1] = true;
			switch (gNav->menuState)
			{
				case kMenuStateAwaitingKeyPress:
				case kMenuStateAwaitingPadPress:
				case kMenuStateAwaitingMouseClick:
					break;
				default:
					snapTo = GetNthChainedNode(chainRoot, 1 + gNav->menuCol, NULL);
			}
			break;

		default:
			snapTo = NULL;
			break;
	}

	// If no objnode to snap arrows to, hide them and bail
	if (!snapTo)
	{
		for (int i = 0; i < 2; i++)
		{
			SetObjectVisible(gNav->arrowObjects[i], false);
		}
		return;
	}

	OGLRect extents = TextMesh_GetExtents(snapTo);

	float spacing = 45 * snapTo->Scale.x;

	for (int i = 0; i < 2; i++)
	{
		ObjNode* arrowObj = gNav->arrowObjects[i];
		SetObjectVisible(arrowObj, true);

		arrowObj->Coord.x = i==0? extents.left - spacing: extents.right + spacing;
		arrowObj->Coord.y = snapTo->Coord.y;
		arrowObj->Scale = snapTo->Scale;

		arrowObj->ColorFilter.a = visible[i] ? 1 : 0;
	}

	if (entry->type == kMICycler1)
	{
		gNav->arrowObjects[0]->Coord.x += CYCLER_ARROW_INSET;
		gNav->arrowObjects[1]->Coord.x -= CYCLER_ARROW_INSET;

		float mid = extents.left + 0.5f * (extents.right - extents.left);

		float s = snapTo->Scale.x;
		float s1 = s * 0.7f;
		float s2 = s * 1.3f;

		if (!gNav->mouseHoverValid || !gNav->mouseControl)
		{
			gNav->arrowObjects[0]->Scale = (OGLVector3D){ s, s, s };
			gNav->arrowObjects[1]->Scale = (OGLVector3D){ s, s, s };
			gNav->mouseArrowHoverState = 0;
		}
		else if (gCursorCoord.x < mid)
		{
			gNav->arrowObjects[0]->ColorFilter.a = 1;		// override alpha (don't hide arrows if mouse control)
			gNav->arrowObjects[1]->ColorFilter.a = 1;
			gNav->arrowObjects[0]->Scale = (OGLVector3D){ s2, s2, s2 };
			gNav->arrowObjects[1]->Scale = (OGLVector3D){ s1, s1, s1 };
			gNav->mouseArrowHoverState = -1;
		}
		else
		{
			gNav->arrowObjects[0]->ColorFilter.a = 1;		// override alpha (don't hide arrows if mouse control)
			gNav->arrowObjects[1]->ColorFilter.a = 1;
			gNav->arrowObjects[0]->Scale = (OGLVector3D){ s1, s1, s1 };
			gNav->arrowObjects[1]->Scale = (OGLVector3D){ s2, s2, s2 };
			gNav->mouseArrowHoverState = 1;
		}
	}

	// Finally, update object transforms
	for (int i = 0; i < 2; i++)
	{
		UpdateObjectTransforms(gNav->arrowObjects[i]);
	}
}

static void NavigateSettingEntriesVertically(int delta)
{
	bool makeSound = gNav->menuRow >= 0;
	int browsed = 0;
	bool skipEntry = false;

	TwitchOutSelection();

	do
	{
		gNav->menuRow += delta;
		gNav->menuRow = PositiveModulo(gNav->menuRow, (unsigned int)gNav->numMenuEntries);

		skipEntry = !IsMenuItemSelectable(&gNav->menu[gNav->menuRow]);

		if (browsed++ > gNav->numMenuEntries)
		{
			// no entries are selectable
			return;
		}
	} while (skipEntry);

	gNav->idleTime = 0;
//	gNav->mouseHoverValid = false;

	if (makeSound)
	{
		PlayNavigateEffect();
		TwitchSelection();
	}
}

static void NavigateSettingEntriesMouseHover(void)
{
	static OGLPoint2D cursor = { -1, -1 };

	if (cursor.x == gCursorCoord.x && cursor.y == gCursorCoord.y)
	{
		// Mouse didn't move from last time
		return;
	}

	cursor = gCursorCoord;

	gNav->mouseControl = true;
	gNav->mouseHoverValid = false;
	gNav->mouseHoverColumn = -1;

	for (int row = 0; row < gNav->numMenuEntries; row++)
	{
		if (!IsMenuItemSelectable(&gNav->menu[row]))
		{
			continue;
		}

		OGLRect fullExtents;
		fullExtents.top		= fullExtents.left	= 100000;
		fullExtents.bottom	= fullExtents.right	= -100000;

		ObjNode* textNode = gNav->menuObjects[row];
		for (int col = 0; textNode; col++, textNode=textNode->ChainNode)
		{
			OGLRect extents = TextMesh_GetExtents(textNode);
			if (extents.top		< fullExtents.top	) fullExtents.top		= extents.top;
			if (extents.left	< fullExtents.left	) fullExtents.left		= extents.left;
			if (extents.bottom	> fullExtents.bottom) fullExtents.bottom	= extents.bottom;
			if (extents.right	> fullExtents.right	) fullExtents.right		= extents.right;

			if (cursor.y >= extents.top
				&& cursor.y <= extents.bottom
				&& cursor.x >= extents.left - 10
				&& cursor.x <= extents.right + 10)
			{
				gNav->mouseHoverColumn = col;
			}
		}

		if (cursor.y >= fullExtents.top &&
			cursor.y <= fullExtents.bottom &&
			cursor.x >= fullExtents.left - 10 &&
			cursor.x <= fullExtents.right + 10)
		{
			gNav->mouseHoverValid = true;

#if USE_SDL_CURSOR
			SetHandMouseCursor();				// set hand cursor
#endif

			if (gNav->menuRow != row)
			{
				gNav->idleTime = 0;
				TwitchSelectionInOrOut(false);
				gNav->menuRow = row;
				PlayNavigateEffect();
				TwitchSelectionInOrOut(true);
			}

			return;
		}
	}

	GAME_ASSERT(!gNav->mouseHoverValid);		// if we got here, we're not hovering over anything

#if USE_SDL_CURSOR
	SetStandardMouseCursor();					// restore standard cursor
#endif
}

static void NavigatePick(const MenuItem* entry)
{
	bool validClick = (gNav->mouseHoverValid && IsClickDown(SDL_BUTTON_LEFT));

	if (IsNeedDown(kNeed_UIConfirm, ANY_PLAYER) || validClick)
	{
		gNav->mouseControl = validClick;		// exit mouse control if didn't get click

		if (entry->next != 'BACK')
			PlayConfirmEffect();

		gNav->idleTime = 0;
		gNav->menuPick = entry->id;

		if (entry->callback)
		{
			entry->callback();
		}

		switch (entry->next)
		{
			case 0:
			case 'NOOP':
				TwitchSelection();
				break;

			case 'EXIT':
				gNav->menuState = kMenuStateFadeOut;
				break;

			case 'BACK':
				GoBackInHistory();
				break;

			default:
				SaveSelectedRowInHistory();  // remember which row we were on

				// advance history
				gNav->historyPos++;
				gNav->history[gNav->historyPos].menuID = entry->next;
				gNav->history[gNav->historyPos].row = 0;  // don't reuse stale row value

				LayOutMenu(entry->next);
		}
	}
}

static int GetCyclerNumChoices(const MenuItem* entry)
{
	if (entry->cycler.isDynamicallyGenerated)
	{
		return entry->cycler.generator.generateNumChoices();
	}

	for (int i = 0; i < MAX_MENU_CYCLER_CHOICES; i++)
	{
		if (entry->cycler.choices[i].text == STR_NULL)
			return i;
	}

	return MAX_MENU_CYCLER_CHOICES;
}

static int GetValueIndexInCycler(const MenuItem* entry, uint8_t value)
{
	if (entry->cycler.isDynamicallyGenerated)
	{
		return value;
	}

	for (int i = 0; i < MAX_MENU_CYCLER_CHOICES; i++)
	{
		if (entry->cycler.choices[i].text == STR_NULL)
			break;

		if (entry->cycler.choices[i].value == value)
			return i;
	}

	return -1;
}

static Byte GetCyclerValueForIndex(const MenuItem* entry, int index)
{
	if (entry->cycler.isDynamicallyGenerated)
	{
		return index;
	}
	else
	{
		return entry->cycler.choices[index].value;
	}
}

static void NavigateCycler(const MenuItem* entry)
{
	int delta = 0;
	bool allowWrap = false;

	if (gNav->mouseHoverValid
		&& gNav->mouseArrowHoverState != 0
		&& (IsClickDown(SDL_BUTTON_LEFT) || IsClickDown(SDL_BUTTON_RIGHT)))
	{
		delta = gNav->mouseArrowHoverState * (IsClickDown(SDL_BUTTON_LEFT)? 1: -1);
		allowWrap = true;
		gNav->mouseControl = true;
	}
	else if (IsNeedDown(kNeed_UILeft, ANY_PLAYER)
		|| IsNeedDown(kNeed_UIPrev, ANY_PLAYER)
		|| (gNav->mouseHoverValid && IsClickDown(SDL_BUTTON_WHEELDOWN))
		|| (gNav->mouseHoverValid && IsClickDown(SDL_BUTTON_WHEELLEFT))
		)
	{
		delta = -1;
		gNav->mouseControl = false;
	}
	else if (IsNeedDown(kNeed_UIRight, ANY_PLAYER)
		|| IsNeedDown(kNeed_UINext, ANY_PLAYER)
		|| (gNav->mouseHoverValid && IsClickDown(SDL_BUTTON_WHEELUP))
		|| (gNav->mouseHoverValid && IsClickDown(SDL_BUTTON_WHEELRIGHT))
		)
	{
		delta = 1;
		gNav->mouseControl = false;
	}
	else if (IsNeedDown(kNeed_UIConfirm, ANY_PLAYER))
	{
		gNav->mouseControl = false;

		MakeTwitch(GetCurrentMenuItemObject(), kTwitchPreset_MenuSelect);
		MakeTwitch(gNav->arrowObjects[0], kTwitchPreset_PadlockWiggle);
		MakeTwitch(gNav->arrowObjects[1], kTwitchPreset_PadlockWiggle);
		PlayErrorEffect();
		return;
	}

	if (delta != 0)
	{
		gNav->idleTime = 0;

		if (entry->cycler.valuePtr)
		{
			int index = GetValueIndexInCycler(entry, *entry->cycler.valuePtr);

			if (!allowWrap)
			{
				if ((index == 0 && delta < 0) ||
					(index == GetCyclerNumChoices(entry)-1 && delta > 0))
				{
					PlayErrorEffect();
					MakeTwitch(GetCurrentMenuItemObject(), kTwitchPreset_MenuWiggle);
					MakeTwitch(gNav->arrowObjects[0], kTwitchPreset_PadlockWiggle);
					MakeTwitch(gNav->arrowObjects[1], kTwitchPreset_PadlockWiggle);
					return;
				}
			}

			if (index >= 0)
				index = PositiveModulo(index + delta, GetCyclerNumChoices(entry));
			else
				index = 0;

			*entry->cycler.valuePtr = GetCyclerValueForIndex(entry, index);
//			PlayEffect_Parms(kSfxCycle, FULL_CHANNEL_VOLUME/3, FULL_CHANNEL_VOLUME/3, NORMAL_CHANNEL_RATE / 2 + 4096 * index);
			PlayEffect_Parms(kSfxCycle, FULL_CHANNEL_VOLUME/4, FULL_CHANNEL_VOLUME/4, NORMAL_CHANNEL_RATE);
		}
		else
		{
			PlayEffect_Parms(kSfxCycle, FULL_CHANNEL_VOLUME/4, FULL_CHANNEL_VOLUME/4, NORMAL_CHANNEL_RATE * 2/3 + (RandomFloat2() * 0x3000));
		}

		if (entry->callback)
		{
			entry->callback();
		}

		gTempForceSwipeRTL = (delta == -1);

		if (entry->type == kMICycler1)
			LayOutCycler1(gNav->menuRow);
		else
			LayOutCycler2ValueText(gNav->menuRow);

		if (delta < 0)
			MakeTwitch(gNav->arrowObjects[0], kTwitchPreset_DisplaceLTR);
		else
			MakeTwitch(gNav->arrowObjects[1], kTwitchPreset_DisplaceRTL);
	}
}

static void NavigateFloatRange(const MenuItem* entry)
{
	(void) entry;
	SOFTIMPME;
#if 0
enum
{
	kSaneIncrement = 0,
	kInsaneIncrement = 20,
	kSuperInsaneIncrement = 59,
};

	int delta = 0;

	if (IsNeedActive(kNeed_UILeft, ANY_PLAYER)
		|| IsNeedActive(kNeed_UIPrev, ANY_PLAYER)
		|| (gNav->mouseHoverValid && IsClickDown(SDL_BUTTON_RIGHT)))
	{
		delta = -1;
	}
	else if (IsNeedActive(kNeed_UIRight, ANY_PLAYER)
		|| IsNeedActive(kNeed_UINext, ANY_PLAYER)
		|| (gNav->mouseHoverValid && IsClickDown(SDL_BUTTON_LEFT)))
	{
		delta = 1;
	}
	else if (IsNeedDown(kNeed_UIConfirm, ANY_PLAYER))
	{
		MakeTwitch(GetCurrentMenuItemObject(), kTwitchPreset_MenuSelect);
		MakeTwitch(gNav->arrowObjects[0], kTwitchPreset_PadlockWiggle);
		MakeTwitch(gNav->arrowObjects[1], kTwitchPreset_PadlockWiggle);
		PlayErrorEffect();
		return;
	}

	MenuNodeData* data = GetMenuNodeData(GetCurrentMenuItemObject());

	if (delta == 0)
	{
		data->incrementCooldown = 0;
		data->nIncrements = 0;
	}
	else
	{
		gNav->idleTime = 0;

		data->incrementCooldown -= gFramesPerSecondFrac;

		if (data->incrementCooldown > 0)
		{
			// Wait for cooldown to go negative to increment/decrement value
			return;
		}

		float deltaFrac = delta * entry->floatRange.incrementFrac;

		if (data->nIncrements > kSuperInsaneIncrement)
			deltaFrac *= 20;

		float valueFrac = *entry->floatRange.valuePtr / *entry->floatRange.equilibriumPtr;
		valueFrac += deltaFrac;

		// If possible, round fraction to 0% or 100%, to avoid floating-point drift
		// when the user sets values back to 0% or 100% manually.
		if (fabsf(valueFrac - 1.0f) < 0.001f)		// Round to 100%
			valueFrac = 1.0f;
		else if (fabsf(valueFrac) < 0.001f)			// Round to 0%
			valueFrac = 0.0f;

		float newValue = valueFrac * *entry->floatRange.equilibriumPtr;

		// Set value
		*entry->floatRange.valuePtr = newValue;

		// Invoke callback
		if (entry->callback)
			entry->callback(entry);


		// Play sound
		float pitch = 0.5f;
		pitch += GAME_MIN(6, data->nIncrements) * (1.0f/6.0f) * 0.5f;
		pitch += RandomFloat() * 0.2f;
		PlayEffect_Parms(kSfxFloatRange, FULL_CHANNEL_VOLUME, FULL_CHANNEL_VOLUME, NORMAL_CHANNEL_RATE * pitch);

		// Prepare to lay out new value text
		gTempInitialSweepFactor = .5f;
		gTempForceSwipeRTL = delta > 0;

		// Lay out new value text
		LayOutFloatRangeValueText(gNav->menuRow);

		// Restore sweep params
		gTempInitialSweepFactor = 0;
		gTempForceSwipeRTL = false;

		// Adjust arrows
		if (delta < 0)
			MakeTwitch(gNav->arrowObjects[0], kTwitchPreset_DisplaceLTR);
		else
			MakeTwitch(gNav->arrowObjects[1], kTwitchPreset_DisplaceRTL);

		// Update cooldown timer
		if (valueFrac == 1.0f || valueFrac == 0.0f)		// Force speed bump at 0% and 100%
		{
			data->incrementCooldown = .3f;
			data->nIncrements = 0;
		}
		else
		{
			const float kCooldownProgression[] = {.4f, .3f, .25f, .2f, .175f, .15f, .125f, .1f};
			const int nCooldowns = sizeof(kCooldownProgression) / sizeof(kCooldownProgression[0]);

			data->incrementCooldown = kCooldownProgression[ GAME_MIN(data->nIncrements, nCooldowns-1) ];

			if (data->nIncrements > kSuperInsaneIncrement)
				data->incrementCooldown = 1/30.0f;
			else if (data->nIncrements > kInsaneIncrement)
				data->incrementCooldown = 1/15.0f;

			data->nIncrements++;
		}
	}
#endif
}

static void NavigateKeyBinding(const MenuItem* entry)
{
	gNav->menuCol = PositiveModulo(gNav->menuCol, MAX_USER_BINDINGS_PER_NEED);
	int keyNo = gNav->menuCol;
	int row = gNav->menuRow;

	if (gNav->mouseHoverValid
		&& (gNav->mouseHoverColumn == 1 || gNav->mouseHoverColumn == 2)
		&& (keyNo != gNav->mouseHoverColumn - 1))
	{
		keyNo = gNav->mouseHoverColumn - 1;
		TwitchOutSelection();
		gNav->idleTime = 0;
		gNav->menuCol = keyNo;
		PlayNavigateEffect();
		TwitchSelection();
		return;
	}

	if (IsNeedDown(kNeed_UILeft, ANY_PLAYER) || IsNeedDown(kNeed_UIPrev, ANY_PLAYER))
	{
		TwitchOutSelection();
		keyNo = PositiveModulo(keyNo - 1, MAX_USER_BINDINGS_PER_NEED);
		gNav->idleTime = 0;
		gNav->menuCol = keyNo;
		PlayNavigateEffect();
		gNav->mouseHoverValid = false;
		TwitchSelection();
		return;
	}

	if (IsNeedDown(kNeed_UIRight, ANY_PLAYER) || IsNeedDown(kNeed_UINext, ANY_PLAYER))
	{
		TwitchOutSelection();
		keyNo = PositiveModulo(keyNo + 1, MAX_USER_BINDINGS_PER_NEED);
		gNav->idleTime = 0;
		gNav->menuCol = keyNo;
		PlayNavigateEffect();
		gNav->mouseHoverValid = false;
		TwitchSelection();
		return;
	}

	if (IsNeedDown(kNeed_UIDelete, ANY_PLAYER)
		|| IsKeyDown(CLEAR_BINDING_SCANCODE)
		|| (gNav->mouseHoverValid && IsClickDown(SDL_BUTTON_MIDDLE)))
	{
		TwitchOutSelection();
		gNav->idleTime = 0;
		gGamePrefs.bindings[entry->inputNeed].key[keyNo] = 0;
		PlayDeleteEffect();
		MakeKbText(row, keyNo);
		TwitchSelection();
		return;
	}

	if (IsKeyDown(SDL_SCANCODE_RETURN)
		|| IsKeyDown(SDL_SCANCODE_KP_ENTER)
		|| (gNav->mouseHoverValid && IsClickDown(SDL_BUTTON_LEFT)))
	{
		PlayStartBindingEffect();
		InvalidateAllInputs();
		gNav->idleTime = 0;
		gNav->menuState = kMenuStateAwaitingKeyPress;

		MakeKbText(row, keyNo);		// It'll show "PRESS!" because we're in kMenuStateAwaitingKeyPress
		TwitchSelection();

		// Change subtitle to help message
		ReplaceMenuText(STR_CONFIGURE_KEYBOARD_HELP, STR_CONFIGURE_KEYBOARD_HELP_CANCEL);
		return;
	}
}

static void NavigatePadBinding(const MenuItem* entry)
{
	gNav->menuCol = PositiveModulo(gNav->menuCol, MAX_USER_BINDINGS_PER_NEED);
	int btnNo = gNav->menuCol;
	int row = gNav->menuRow;

	if (gNav->mouseHoverValid
		&& (gNav->mouseHoverColumn == 1 || gNav->mouseHoverColumn == 2)
		&& (btnNo != gNav->mouseHoverColumn - 1))
	{
		btnNo = gNav->mouseHoverColumn - 1;
		TwitchOutSelection();
		gNav->idleTime = 0;
		gNav->menuCol = btnNo;
		PlayNavigateEffect();
		TwitchSelection();
		return;
	}

	if (IsNeedDown(kNeed_UILeft, ANY_PLAYER) || IsNeedDown(kNeed_UIPrev, ANY_PLAYER))
	{
		TwitchOutSelection();
		btnNo = PositiveModulo(btnNo - 1, MAX_USER_BINDINGS_PER_NEED);
		gNav->menuCol = btnNo;
		gNav->idleTime = 0;
		gNav->mouseHoverValid = false;
		PlayNavigateEffect();
		TwitchSelection();
		return;
	}

	if (IsNeedDown(kNeed_UIRight, ANY_PLAYER) || IsNeedDown(kNeed_UINext, ANY_PLAYER))
	{
		TwitchOutSelection();
		btnNo = PositiveModulo(btnNo + 1, MAX_USER_BINDINGS_PER_NEED);
		gNav->menuCol = btnNo;
		gNav->idleTime = 0;
		gNav->mouseHoverValid = false;
		PlayNavigateEffect();
		TwitchSelection();
		return;
	}

	if (IsNeedDown(kNeed_UIDelete, ANY_PLAYER)
		|| IsKeyDown(CLEAR_BINDING_SCANCODE)
		|| (gNav->mouseHoverValid && IsClickDown(SDL_BUTTON_MIDDLE)))
	{
		TwitchOutSelection();
		gNav->idleTime = 0;
		gGamePrefs.bindings[entry->inputNeed].pad[btnNo].type = kInputTypeUnbound;
		PlayDeleteEffect();
		MakePbText(row, btnNo);
		TwitchSelection();
		return;
	}

	if (IsNeedDown(kNeed_UIConfirm, ANY_PLAYER)
		|| IsKeyDown(SDL_SCANCODE_KP_ENTER)
		|| (gNav->mouseHoverValid && IsClickDown(SDL_BUTTON_LEFT)))
	{
		// Unlike keyboard bindings, don't call InvalidateAllInputs() here,
		// because we don't keep a shadow array of all gamepad button states,
		// so we have to query SDL for a new button directly.
		// AwaitMetaGamepadPress will wait for the user to let go of kNeed_UIConfirm.

		PlayStartBindingEffect();

		gNav->idleTime = 0;
		gNav->menuState = kMenuStateAwaitingPadPress;

		MakePbText(row, btnNo);			// It'll show "PRESS!" because we're in MenuStateAwaitingPadPress
		TwitchSelection();

		// Change subtitle to help message
		ReplaceMenuText(STR_CONFIGURE_GAMEPAD_HELP, STR_CONFIGURE_GAMEPAD_HELP_CANCEL);

		return;
	}
}

static void NavigateMouseBinding(const MenuItem* entry)
{
	int row = gNav->menuRow;

	if (IsNeedDown(kNeed_UIDelete, ANY_PLAYER)
		|| IsKeyDown(CLEAR_BINDING_SCANCODE)
		|| (gNav->mouseHoverValid && IsClickDown(SDL_BUTTON_MIDDLE)))
	{
		gNav->idleTime = 0;
		gGamePrefs.bindings[entry->inputNeed].mouseButton = 0;
		PlayDeleteEffect();
		MakeMbText(row);
		TwitchSelection();
		return;
	}

	if (IsNeedDown(kNeed_UIConfirm, ANY_PLAYER)
		|| IsKeyDown(SDL_SCANCODE_KP_ENTER)
		|| (gNav->mouseHoverValid && IsClickDown(SDL_BUTTON_LEFT)))
	{
		PlayStartBindingEffect();

		gNav->idleTime = 0;
		gNav->menuState = kMenuStateAwaitingMouseClick;

		MakeMbText(row);			// It'll show "PRESS!" because we're in MenuStateAwaitingMouseClick
		TwitchSelection();
		InvalidateAllInputs();

		return;
	}
}

static void NavigateMenu(void)
{
	GAME_ASSERT(gNav->style.isInteractive);

	if (IsNeedDown(kNeed_UIBack, ANY_PLAYER)
		|| IsClickDown(SDL_BUTTON_X1))
	{
		GoBackInHistory();
		return;
	}

	if (IsNeedDown(kNeed_UIUp, ANY_PLAYER))
	{
		NavigateSettingEntriesVertically(-1);
		SaveSelectedRowInHistory();
		gNav->mouseControl = false;
	}
	else if (IsNeedDown(kNeed_UIDown, ANY_PLAYER))
	{
		NavigateSettingEntriesVertically(1);
		SaveSelectedRowInHistory();
		gNav->mouseControl = false;
	}
	else
	{
		NavigateSettingEntriesMouseHover();
	}

	const MenuItem* entry = &gNav->menu[gNav->menuRow];
	const MenuItemClass* cls = &kMenuItemClasses[entry->type];

	if (cls->navigateCallback)
	{
		cls->navigateCallback(entry);
	}
}

/****************************/
/* INPUT BINDING CALLBACKS  */
/****************************/
#pragma mark - Input binding callbacks

static void UnbindScancodeFromAllRemappableInputNeeds(int16_t sdlScancode)
{
	for (int row = 0; row < gNav->numMenuEntries; row++)
	{
		if (gNav->menu[row].type != kMIKeyBinding)
			continue;

		InputBinding* binding = GetBindingAtRow(row);

		for (int j = 0; j < MAX_USER_BINDINGS_PER_NEED; j++)
		{
			if (binding->key[j] == sdlScancode)
			{
				binding->key[j] = 0;
				MakeText(Localize(STR_UNBOUND_PLACEHOLDER), row, j+1, kTextMeshAllCaps | kTextMeshAlignLeft);
			}
		}
	}
}

static void UnbindPadButtonFromAllRemappableInputNeeds(int8_t type, int8_t id)
{
	for (int row = 0; row < gNav->numMenuEntries; row++)
	{
		if (gNav->menu[row].type != kMIPadBinding)
			continue;

		InputBinding* binding = GetBindingAtRow(row);

		for (int j = 0; j < MAX_USER_BINDINGS_PER_NEED; j++)
		{
			if (binding->pad[j].type == type && binding->pad[j].id == id)
			{
				binding->pad[j].type = kInputTypeUnbound;
				binding->pad[j].id = 0;
				MakeText(Localize(STR_UNBOUND_PLACEHOLDER), row, j+1, kTextMeshAllCaps | kTextMeshAlignLeft);
			}
		}
	}
}

static void UnbindMouseButtonFromAllRemappableInputNeeds(int8_t id)
{
	for (int row = 0; row < gNav->numMenuEntries; row++)
	{
		if (gNav->menu[row].type != kMIMouseBinding)
			continue;

		InputBinding* binding = GetBindingAtRow(row);

		if (binding->mouseButton == id)
		{
			binding->mouseButton = 0;
			MakeText(Localize(STR_UNBOUND_PLACEHOLDER), row, 1, kTextMeshAllCaps | kTextMeshAlignLeft);
		}
	}
}

static void AwaitKeyPress(void)
{
	int row = gNav->menuRow;
	int keyNo = gNav->menuCol;
	GAME_ASSERT(keyNo >= 0);
	GAME_ASSERT(keyNo < MAX_USER_BINDINGS_PER_NEED);

	if (IsKeyDown(SDL_SCANCODE_ESCAPE)
		|| IsClickDown(SDL_BUTTON_LEFT)
		|| IsClickDown(SDL_BUTTON_RIGHT))
	{
		PlayErrorEffect();
		goto updateText;
	}

	for (int16_t scancode = 0; scancode < SDL_NUM_SCANCODES; scancode++)
	{
		if (IsKeyDown(scancode))
		{
			UnbindScancodeFromAllRemappableInputNeeds(scancode);
			GetBindingAtRow(row)->key[keyNo] = scancode;

			PlayEndBindingEffect();
			goto updateText;
		}
	}
	return;

updateText:
	gNav->menuState = kMenuStateReady;
	gNav->idleTime = 0;
	MakeKbText(row, keyNo);		// update text after state changed back to Ready
//	();
	ReplaceMenuText(STR_CONFIGURE_KEYBOARD_HELP, STR_CONFIGURE_KEYBOARD_HELP);
}

static bool AwaitGamepadPress(SDL_GameController* controller)
{
	int row = gNav->menuRow;
	int btnNo = gNav->menuCol;
	GAME_ASSERT(btnNo >= 0);
	GAME_ASSERT(btnNo < MAX_USER_BINDINGS_PER_NEED);

	if (IsKeyDown(SDL_SCANCODE_ESCAPE)
		|| SDL_GameControllerGetButton(controller, SDL_CONTROLLER_BUTTON_START)
		|| IsClickDown(SDL_BUTTON_LEFT)
		|| IsClickDown(SDL_BUTTON_RIGHT))
	{
		PlayErrorEffect();
		goto updateText;
	}

	InputBinding* binding = GetBindingAtRow(gNav->menuRow);

	for (int8_t button = 0; button < SDL_CONTROLLER_BUTTON_MAX; button++)
	{
#if 0	// uncomment to prevent binding d-pad
		switch (button)
		{
			case SDL_CONTROLLER_BUTTON_DPAD_UP:			// prevent binding those
			case SDL_CONTROLLER_BUTTON_DPAD_DOWN:
			case SDL_CONTROLLER_BUTTON_DPAD_LEFT:
			case SDL_CONTROLLER_BUTTON_DPAD_RIGHT:
				continue;
		}
#endif

		if (SDL_GameControllerGetButton(controller, button))
		{
			PlayEndBindingEffect();
			UnbindPadButtonFromAllRemappableInputNeeds(kInputTypeButton, button);
			binding->pad[btnNo].type = kInputTypeButton;
			binding->pad[btnNo].id = button;
			goto updateText;
		}
	}

	for (int8_t axis = 0; axis < SDL_CONTROLLER_AXIS_MAX; axis++)
	{
#if 0	// uncomment to prevent binding LS/RS
		switch (axis)
		{
			case SDL_CONTROLLER_AXIS_LEFTX:				// prevent binding those
			case SDL_CONTROLLER_AXIS_LEFTY:
			case SDL_CONTROLLER_AXIS_RIGHTX:
			case SDL_CONTROLLER_AXIS_RIGHTY:
				continue;
		}
#endif

		int16_t axisValue = SDL_GameControllerGetAxis(controller, axis);
		if (abs(axisValue) > kJoystickDeadZone_BindingThreshold)
		{
			PlayEndBindingEffect();
			int axisType = axisValue < 0 ? kInputTypeAxisMinus : kInputTypeAxisPlus;
			UnbindPadButtonFromAllRemappableInputNeeds(axisType, axis);
			binding->pad[btnNo].type = axisType;
			binding->pad[btnNo].id = axis;
			goto updateText;
		}
	}

	return false;

updateText:
	gNav->menuState = kMenuStateReady;
	gNav->idleTime = 0;
	MakePbText(row, btnNo);		// update text after state changed back to Ready
	ReplaceMenuText(STR_CONFIGURE_GAMEPAD_HELP, STR_CONFIGURE_GAMEPAD_HELP);
	return true;
}

static void AwaitMetaGamepadPress(void)
{
	// Wait for user to let go of confirm button before accepting a new button binding.
	if (IsNeedActive(kNeed_UIConfirm, ANY_PLAYER) && !IsNeedDown(kNeed_UIConfirm, ANY_PLAYER))
	{
		return;
	}

	bool anyGamepadFound = false;

	for (int i = 0; i < MAX_PLAYERS; i++)
	{
		SDL_GameController* controller = GetController(i);
		if (controller)
		{
			anyGamepadFound = true;
			if (AwaitGamepadPress(controller))
			{
				return;
			}
		}
	}

	if (!anyGamepadFound)
	{
		gNav->menuState = kMenuStateReady;
		gNav->idleTime = 0;
		MakePbText(gNav->menuRow, gNav->menuCol);	// update text after state changed back to Ready
		PlayErrorEffect();
		ReplaceMenuText(STR_CONFIGURE_GAMEPAD_HELP, STR_NO_GAMEPAD_DETECTED);
	}
}

static bool AwaitMouseClick(void)
{
	if (IsKeyDown(SDL_SCANCODE_ESCAPE))
	{
		PlayErrorEffect();
		goto updateText;
	}

	InputBinding* binding = GetBindingAtRow(gNav->menuRow);

	for (int8_t mouseButton = 0; mouseButton < NUM_SUPPORTED_MOUSE_BUTTONS; mouseButton++)
	{
		if (IsClickDown(mouseButton))
		{
			UnbindMouseButtonFromAllRemappableInputNeeds(mouseButton);
			binding->mouseButton = mouseButton;
			PlayEndBindingEffect();
			goto updateText;
		}
	}

	return false;

updateText:
	gNav->menuState = kMenuStateReady;
	gNav->idleTime = 0;
	MakeMbText(gNav->menuRow);		// update text after state changed back to Ready
//	ReplaceMenuText(STR_CONFIGURE_MOUSE_HELP_CANCEL, STR_CONFIGURE_MOUSE_HELP);
	return true;
}

/****************************/
/*    PAGE LAYOUT           */
/****************************/
#pragma mark - Page Layout

static void DeleteAllText(void)
{
	for (int row = 0; row < MAX_MENU_ROWS; row++)
	{
		if (gNav->menuObjects[row])
		{
			DeleteObject(gNav->menuObjects[row]);
			gNav->menuObjects[row] = nil;
		}
	}
}

static float GetMenuItemHeight(int row)
{
	const MenuItem* menuItem = &gNav->menu[row];

	if (GetLayoutFlags(menuItem) & kMILayoutFlagHidden)
		return 0;
	else if (menuItem->customHeight > 0)
		return menuItem->customHeight;
	else
		return kMenuItemClasses[menuItem->type].height;
}

static ObjNode* MakeText(const char* text, int row, int desiredCol, int textMeshFlags)
{
	ObjNode* chainHead = gNav->menuObjects[row];
	ObjNode* pNode = NULL;
	GAME_ASSERT(GetNodeChainLength(chainHead) >= desiredCol);

	ObjNode* node = GetNthChainedNode(chainHead, desiredCol, &pNode);

	if (node)
	{
		// Recycling existing text lets us keep the move call, color and specials
		TextMesh_Update(text, textMeshFlags, node);
	}
	else
	{
		NewObjectDefinitionType def =
		{
			.coord = (OGLPoint3D) { kDefaultX, gNav->menuRowYs[row], 0 },
			.scale = GetMenuItemHeight(row) * gNav->style.standardScale,
			.group = gNav->style.fontAtlas,
			.slot = gNav->style.textSlot + desiredCol,  // chained node must be after their parent!
			.flags = STATUS_BIT_MOVEINPAUSE,
		};

		node = TextMesh_New(text, textMeshFlags, &def);

		SendNodeToOverlayPane(node);

		if (pNode)
		{
			pNode->ChainHead = chainHead;
			pNode->ChainNode = node;
		}
		else
		{
			gNav->menuObjects[row] = node;
		}
	}

	if (gNav->style.uniformXExtent)
	{
		if (-gNav->style.uniformXExtent < node->LeftOff)
			node->LeftOff = -gNav->style.uniformXExtent;
		if (gNav->style.uniformXExtent > node->RightOff)
			node->RightOff = gNav->style.uniformXExtent;
	}

	MenuNodeData* data = GetMenuNodeData(node);
	data->row = row;
	data->col = desiredCol;

	Twitch* fadeEffect = MakeTwitch(node, kTwitchPreset_MenuFadeIn);
	if (fadeEffect)
	{
		fadeEffect->delay = -gTempInitialSweepFactor * fadeEffect->duration;

		Twitch* displaceEffect = MakeTwitch(node, kTwitchPreset_MenuSweep | kTwitchFlags_Chain);
		if (displaceEffect)
		{
			displaceEffect->delay = fadeEffect->delay;
			displaceEffect->amplitude *= (gTempForceSwipeRTL ? 1 : -1);
			displaceEffect->amplitude *= (1.0 + displaceEffect->delay);
		}
	}

	return node;
}

static const char* GetMenuItemLabel(const MenuItem* entry)
{
	if (entry->rawText)
		return entry->rawText;
	else
		return Localize(entry->text);
}

static const char* GetCyclerValueText(int row)
{
	const MenuItem* entry = &gNav->menu[row];

	if (entry->cycler.isDynamicallyGenerated)
	{
		return entry->cycler.generator.generateChoiceString(*entry->cycler.valuePtr);
	}

	int index = GetValueIndexInCycler(entry, *entry->cycler.valuePtr);
	if (index >= 0)
		return Localize(entry->cycler.choices[index].text);
	return "VALUE NOT FOUND???";
}

static ObjNode* LayOutLabel(int row)
{
	const MenuItem* entry = &gNav->menu[row];

	int atlasBackup = gNav->style.fontAtlas;
	gNav->style.fontAtlas = SPRITE_GROUP_FONT2;

	ObjNode* label = MakeText(GetMenuItemLabel(entry), row, 0, 0);
	label->ColorFilter = gNav->style.labelColor;
	label->MoveCall = MoveLabel;

	gNav->style.fontAtlas = atlasBackup;

	return label;
}

static ObjNode* LayOutPick(int row)
{
	const MenuItem* entry = &gNav->menu[row];

	ObjNode* obj = MakeText(GetMenuItemLabel(entry), row, 0, 0);
	obj->MoveCall = MoveAction;

	return obj;
}

static ObjNode* LayOutCycler2ValueText(int row)
{
	ObjNode* node2 = MakeText(GetCyclerValueText(row), row, 1, 0);
	node2->MoveCall = MoveAction;
	return node2;
}

static ObjNode* LayOutCycler2(int row)
{
	DECLARE_WORKBUF(buf, bufSize);

	const MenuItem* entry = &gNav->menu[row];

	snprintf(buf, bufSize, "%s:", GetMenuItemLabel(entry));

	ObjNode* node1 = MakeText(buf, row, 0, kTextMeshAlignLeft);
	node1->Coord.x -= 120;
	node1->MoveCall = MoveAction;

	ObjNode* node2 = LayOutCycler2ValueText(row);
	node2->Coord.x += 100;

	return node1;
}

static ObjNode* LayOutCycler1(int row)
{
	DECLARE_WORKBUF(buf, bufSize);

	const MenuItem* entry = &gNav->menu[row];

	if (entry->text == STR_NULL && entry->rawText == NULL)
		snprintf(buf, bufSize, "%s", GetCyclerValueText(row));
	else
		snprintf(buf, bufSize, "%s: %s", GetMenuItemLabel(entry), GetCyclerValueText(row));

	ObjNode* node = MakeText(buf, row, 0, 0);
	node->MoveCall = MoveAction;
	node->LeftOff -= CYCLER_ARROW_PADDING;
	node->RightOff += CYCLER_ARROW_PADDING;

	return node;
}

static ObjNode* LayOutFloatRangeValueText(int row)
{
	const MenuItem* entry = &gNav->menu[row];
	DECLARE_WORKBUF(buf, bufSize);

	float percent = *entry->floatRange.valuePtr / *entry->floatRange.equilibriumPtr;
	percent *= 100.0f;

	snprintf(buf, bufSize, "%d%%", (int)roundf(percent));
	ObjNode* node2 = MakeText(buf, row, 1, kTextMeshAlignRight);
	node2->MoveCall = MoveAction;
	return node2;
}

static ObjNode* LayOutFloatRange(int row)
{
	DECLARE_WORKBUF(buf, bufSize);
	const MenuItem* entry = &gNav->menu[row];

	snprintf(buf, bufSize, "%s:", GetMenuItemLabel(entry));
	ObjNode* node1 = MakeText(buf, row, 0, kTextMeshAlignLeft);
	node1->MoveCall = MoveAction;
	node1->Coord.x -= entry->floatRange.xSpread;

	ObjNode* node2 = LayOutFloatRangeValueText(row);
	node2->Coord.x += entry->floatRange.xSpread;
	UpdateObjectTransforms(node2);

	return node1;
}

static ObjNode* LayOutKeyBinding(int row)
{
	DECLARE_WORKBUF(buf, bufSize);
	const MenuItem* entry = &gNav->menu[row];

	snprintf(buf, bufSize, "%s:", Localize(STR_KEYBINDING_DESCRIPTION_0 + entry->inputNeed));

	int atlasBackup = gNav->style.fontAtlas;
	gNav->style.fontAtlas = SPRITE_GROUP_FONT2;

	ObjNode* label = MakeText(buf, row, 0, kTextMeshAlignLeft);
	label->Coord.x = 100;
	label->ColorFilter = gNav->style.labelColor;
	label->MoveCall = MoveLabel;

	gNav->style.fontAtlas = atlasBackup;

	for (int j = 0; j < MAX_USER_BINDINGS_PER_NEED; j++)
	{
		ObjNode* keyNode = MakeKbText(row, j);
		keyNode->Coord.x = 300 + j * 170 ;
		keyNode->MoveCall = MoveControlBinding;
		GetMenuNodeData(keyNode)->col = j;
	}

	return label;
}

static ObjNode* LayOutPadBinding(int row)
{
	DECLARE_WORKBUF(buf, bufSize);
	const MenuItem* entry = &gNav->menu[row];

	snprintf(buf, bufSize, "%s:", Localize(STR_KEYBINDING_DESCRIPTION_0 + entry->inputNeed));

	int atlasBackup = gNav->style.fontAtlas;
	gNav->style.fontAtlas = SPRITE_GROUP_FONT2;

	ObjNode* label = MakeText(buf, row, 0, kTextMeshAlignLeft);
	label->Coord.x = 100;
	label->ColorFilter = gNav->style.labelColor;
	label->MoveCall = MoveLabel;

	gNav->style.fontAtlas = atlasBackup;

	for (int j = 0; j < MAX_USER_BINDINGS_PER_NEED; j++)
	{
		ObjNode* keyNode = MakePbText(row, j);
		keyNode->Coord.x = 300 + j * 170;
		keyNode->MoveCall = MoveControlBinding;
		GetMenuNodeData(keyNode)->col = j;
	}

	return label;
}

static ObjNode* LayOutMouseBinding(int row)
{
	DECLARE_WORKBUF(buf, bufSize);
	const MenuItem* entry = &gNav->menu[row];

	snprintf(buf, bufSize, "%s:", Localize(STR_KEYBINDING_DESCRIPTION_0 + entry->inputNeed));

	int atlasBackup = gNav->style.fontAtlas;
	gNav->style.fontAtlas = SPRITE_GROUP_FONT2;

	ObjNode* label = MakeText(buf, row, 0, kTextMeshAlignLeft);
	label->Coord.x = 100;
	label->ColorFilter = gNav->style.labelColor;
	label->MoveCall = MoveLabel;

	gNav->style.fontAtlas = atlasBackup;

	ObjNode* keyNode = MakeText(GetMouseBindingName(row), row, 1, kTextMeshAlignLeft);
	keyNode->Coord.x = 300;
	keyNode->MoveCall = MoveControlBinding;
	GetMenuNodeData(keyNode)->col = 0;

	return label;
}

static void LayOutMenu(int menuID)
{
	const MenuItem* menu = LookUpMenu(menuID);

	if (!menu)
	{
		DoFatalAlert("Menu not registered: '%s'", FourccToString(menuID));
		return;
	}

	// Remember we've been in this menu
	gNav->history[gNav->historyPos].menuID = menuID;

	gNav->menu				= menu;
	gNav->menuID			= menuID;
	gNav->numMenuEntries	= 0;
	gNav->menuPick			= -1;
	gNav->idleTime			= 0;

	// Restore old row
	gNav->menuRow = gNav->history[gNav->historyPos].row;

	DeleteAllText();

	float totalHeight = 0;
	float firstHeight = 0;
	for (int row = 0; menu[row].type != kMISENTINEL; row++)
	{
		float height = GetMenuItemHeight(row);
		if (firstHeight == 0)
			firstHeight = height;
		totalHeight += height * gNav->style.rowHeight;
	}

	float y = -totalHeight*.5f + gNav->style.yOffset;
	y += firstHeight * gNav->style.rowHeight / 2.0f;

	// Fit darken pane to new menu height
	if (gNav->darkenPane)
	{
		RescaleDarkenPane(gNav->darkenPane, totalHeight);
	}

	gTempInitialSweepFactor = 0.0f;

	for (int row = 0; menu[row].type != kMISENTINEL; row++)
	{
		gNav->menuRowYs[row] = y;

		const MenuItem* entry = &menu[row];
		const MenuItemClass* cls = &kMenuItemClasses[entry->type];

		if (GetLayoutFlags(entry) & kMILayoutFlagHidden)
		{
			gNav->numMenuEntries++;
			continue;
		}

		if (cls->layOutCallback)
		{
			ObjNode* node = cls->layOutCallback(row);

			// Make translucent if item disabled
			if (GetLayoutFlags(entry) & kMILayoutFlagDisabled)
			{
				GetMenuNodeData(node)->muted = true;
			}
		}

		y += GetMenuItemHeight(row) * gNav->style.rowHeight;

		if (entry->type != kMISpacer)
		{
			gTempInitialSweepFactor -= .2f;
		}

		gNav->numMenuEntries++;
		GAME_ASSERT(gNav->numMenuEntries < MAX_MENU_ROWS);
	}

	gTempInitialSweepFactor = 0.0f;

	if (gNav->menuRow <= 0
		|| !IsMenuItemSelectable(&gNav->menu[gNav->menuRow]))	// we had selected this item when we last were in this menu, but it's been disabled since then
	{
		// Scroll down to first pickable entry
		gNav->menuRow = -1;
		NavigateSettingEntriesVertically(1);
	}

	TwitchSelection();
}

void LayoutCurrentMenuAgain(void)
{
	GAME_ASSERT(gNav->menu);
	LayOutMenu(gNav->menuID);
}

#define MAX_REGISTERED_MENUS 32

int gNumMenusRegistered = 0;
const MenuItem* gMenuRegistry[MAX_REGISTERED_MENUS];

void RegisterMenu(const MenuItem* menuTree)
{
	for (const MenuItem* menuItem = menuTree; menuItem->type || menuItem->id; menuItem++)
	{
		if (menuItem->type == 0)
		{
			if (menuItem->id == 0)			// end sentinel
			{
				break;
			}

			if (LookUpMenu(menuItem->id))	// already registered
			{
				continue;
			}

			GAME_ASSERT(gNumMenusRegistered < MAX_REGISTERED_MENUS);
			gMenuRegistry[gNumMenusRegistered] = menuItem;
			gNumMenusRegistered++;

//			printf("Registered menu '%s'\n", FourccToString(menuItem->id));
		}
	}
}

static const MenuItem* LookUpMenu(int menuID)
{
	for (int i = 0; i < gNumMenusRegistered; i++)
	{
		if (gMenuRegistry[i]->id == menuID)
			return gMenuRegistry[i] + 1;
	}

	return NULL;
}

#pragma mark - Menu driver ObjNode

ObjNode* MakeMenu(const MenuItem* menu, const MenuStyle* style)
{
#if USE_SDL_CURSOR
	int cursorStateBeforeMenu = SDL_ShowCursor(-1);
	SDL_ShowCursor(1);
#endif

			/* CREATE MENU DRIVER */

	NewObjectDefinitionType driverDef =
	{
		.coord = {0,0,0},
		.scale = 1,
		.slot = MENU_SLOT,
		.genre = EVENT_GENRE,
		.flags = STATUS_BIT_MOVEINPAUSE | STATUS_BIT_DONTCULL,
		.moveCall = MoveMenuDriver,
	};
	ObjNode* driverNode = MakeNewObject(&driverDef);

			/* INITIALIZE MENU STATE */

	gNumMenusRegistered = 0;
	RegisterMenu(menu);

	InitMenuNavigation();

	gMenuOutcome = 0;

	gNav->menuState			= kMenuStateFadeIn;
	gNav->menuFadeAlpha		= 0;
	gNav->menuRow			= -1;

	if (style)
		memcpy(&gNav->style, style, sizeof(*style));

	gTempInitialSweepFactor	= 0;
	gTempForceSwipeRTL		= false;

			/* LAY OUT MENU COMPONENTS */

	gNav->darkenPane = nil;
	if (gNav->style.darkenPaneOpacity > 0.0f)
	{
		gNav->darkenPane = MakeDarkenPane();
	}

	LayOutMenu(menu->id);

	return driverNode;
}

static void MoveMenuDriver(ObjNode* theNode)
{
	if (gNav->menuState == kMenuStateOff)
	{
		return;
	}

	gNav->idleTime += gFramesPerSecondFrac;

	if (IsNeedDown(kNeed_UIStart, ANY_PLAYER)
		&& gNav->style.startButtonExits
		&& gNav->style.canBackOutOfRootMenu
		&& gNav->menuState != kMenuStateAwaitingPadPress
		&& gNav->menuState != kMenuStateAwaitingKeyPress
		&& gNav->menuState != kMenuStateAwaitingMouseClick)
	{
		gNav->menuState = kMenuStateFadeOut;
	}

	switch (gNav->menuState)
	{
		case kMenuStateFadeIn:
			gNav->menuFadeAlpha += gFramesPerSecondFrac * gNav->style.fadeInSpeed;
			if (gNav->menuFadeAlpha >= 1.0f)
			{
				gNav->menuFadeAlpha = 1.0f;
				gNav->menuState = kMenuStateReady;
			}
			break;

		case kMenuStateFadeOut:
			if (gNav->style.asyncFadeOut)
			{
				gNav->menuState = kMenuStateOff;		// exit loop
			}
			else
			{
				gNav->menuFadeAlpha -= gFramesPerSecondFrac * gNav->style.fadeOutSpeed;
				if (gNav->menuFadeAlpha <= 0.0f)
				{
					gNav->menuFadeAlpha = 0.0f;
					gNav->menuState = kMenuStateOff;
				}
			}
			break;

		case kMenuStateReady:
			if (gNav->style.isInteractive)
			{
				NavigateMenu();
			}
			else if (UserWantsOut())
			{
				GoBackInHistory();
			}
			break;

		case kMenuStateAwaitingKeyPress:
			AwaitKeyPress();
			break;

		case kMenuStateAwaitingPadPress:
		{
			AwaitMetaGamepadPress();
			break;
		}

		case kMenuStateAwaitingMouseClick:
			AwaitMouseClick();
			break;

		default:
			break;
	}

	UpdateArrows();

	if (gNav->menuState == kMenuStateOff)
	{
		CleanUpMenuDriver(theNode);
	}
}

static void CleanUpMenuDriver(ObjNode* theNode)
{
			/* FADE OUT */

	if (gNav->style.fadeOutSceneOnExit)
	{
		OGL_FadeOutScene(DrawObjects, NULL);
	}



			/* CLEANUP */

	if (gNav->style.asyncFadeOut)
	{
		if (gNav->darkenPane)
		{
			gNav->darkenPane->MoveCall = nil;
			MakeTwitch(gNav->darkenPane, kTwitchPreset_MenuFadeOut | kTwitchFlags_KillPuppet);
			MakeTwitch(gNav->darkenPane, kTwitchPreset_MenuDarkenPaneVanish | kTwitchFlags_Chain);
		}

		for (int row = 0; row < MAX_MENU_ROWS; row++)
		{
			if (gNav->menuObjects[row])
			{
				gNav->menuObjects[row]->MoveCall = nil;
				MakeTwitch(gNav->menuObjects[row], kTwitchPreset_MenuFadeOut | kTwitchFlags_KillPuppet);
			}
		}

		memset(gNav->menuObjects, 0, sizeof(gNav->menuObjects));
	}
	else
	{
		DeleteAllText();

		if (gNav->darkenPane)
		{
			DeleteObject(gNav->darkenPane);
			gNav->darkenPane = nil;
		}
	}

	DoSDLMaintenance();
	MyFlushEvents();

#if USE_SDL_CURSOR
	SetStandardMouseCursor();
	SDL_ShowCursor(cursorStateBeforeMenu);
#endif

	// Save some stuff before deleting
	void (*exitCall)(int) = gNav->style.exitCall;
	gMenuOutcome = gNav->menuPick;

	DisposeMenuNavigation();
	DeleteObject(theNode);

	if (exitCall)
	{
		exitCall(gMenuOutcome);
	}
}
