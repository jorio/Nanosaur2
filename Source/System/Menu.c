// MENU.C
// (c)2022 Iliyas Jorio
// This file is part of Nanosaur 2. https://github.com/jorio/nanosaur2

/****************************/
/*    EXTERNALS             */
/****************************/

#include "game.h"
#include "uieffects.h"
#include <SDL3/SDL_time.h>

/****************************/
/*    PROTOTYPES            */
/****************************/

#define DECLARE_WORKBUF(buf, bufSize) char (buf)[256]; const int (bufSize) = 256
#define DECLARE_STATIC_WORKBUF(buf, bufSize) static char (buf)[256]; static const int (bufSize) = 256

typedef struct
{
	Boolean		muted;
	Byte		row;
	Byte		component;
	float		pulsateTimer;
	float		maxWidth;
} MenuNodeData;
_Static_assert(sizeof(MenuNodeData) <= MAX_SPECIAL_DATA_BYTES, "MenuNodeData doesn't fit in special area");
#define GetMenuNodeData(node) ((MenuNodeData*) (node)->SpecialPadding)

typedef struct
{
	ObjNode*	caption;
	ObjNode*	bar;
	ObjNode*	notch;
	ObjNode*	meter;
	ObjNode*	knob;
	float		vmin;
	float		vmax;
	float		xmin;
	float		xmax;
} SliderComponents;

static ObjNode* MakeText(const char* text, int row, int desiredCol, int flags);
static void ReplaceMenuText(LocStrID originalTextInMenuDefinition, LocStrID newText);

static void MoveMenuDriver(ObjNode* theNode);
static void CleanUpMenuDriver(ObjNode* theNode);

static const MenuItem* LookUpMenu(int menuID);
static void LayOutMenu(int menuID);

static ObjNode* LayOutCycler2ColumnsValueText(int row);
static ObjNode* LayOutCycler1Column(int row);
static ObjNode* LayOutCycler2Columns(int row);
static ObjNode* LayOutPick(int row);
static ObjNode* LayOutLabel(int row);
static ObjNode* LayOutKeyBinding(int row);
static ObjNode* LayOutPadBinding(int row);
static ObjNode* LayOutMouseBinding(int row);
static ObjNode* LayOutSlider(int row);
static ObjNode* LayOutFileSlot(int row);

static void NavigateMenuVertically(int delta);
static void NavigateMenuMouseHover(void);

static void NavigateCycler(const MenuItem* entry);
static void NavigatePick(const MenuItem* entry);
static void NavigateKeyBinding(const MenuItem* entry);
static void NavigatePadBinding(const MenuItem* entry);
static void NavigateMouseBinding(const MenuItem* entry);
static void NavigateSlider(const MenuItem* entry);

static float GetMenuItemHeight(int row);
static int GetCyclerNumChoices(const MenuItem* entry);
static int GetValueIndexInCycler(const MenuItem* entry, uint8_t value);

static SliderComponents GetSliderComponents(const MenuItem* entry, ObjNode* sliderRoot);
static float SliderKnobXToValue(const SliderComponents* info, float x);
static float SliderValueToKnobX(const SliderComponents* info, float v);

/****************************/
/*    CONSTANTS             */
/****************************/

#define USE_SDL_CURSOR			0

#define MAX_MENU_ROWS			25
#define MAX_STACK_LENGTH		16		// for history
#define CLEAR_BINDING_SCANCODE SDL_SCANCODE_X

#define MAX_REGISTERED_MENUS	32

#define kMouseHoverTolerance	5
#define kMinClickableWidth		80
#define kDefaultX				(640/2)
#define k2ColumnLeftX			(kDefaultX-220)
#define k2ColumnRightX			(kDefaultX+140)
#define kSfxCycle				EFFECT_GRABEGG
#define kTextMeshUserFlag_AltFont kTextMeshUserFlag1
const int16_t kJoystickDeadZone_BindingThreshold = (75 * 32767 / 100);

#define PlayEffectForMenu(x)		PlayEffect_Parms((x), FULL_CHANNEL_VOLUME/4, FULL_CHANNEL_VOLUME/4, NORMAL_CHANNEL_RATE)
#define PlayNavigateEffect()		PlayEffectForMenu(EFFECT_CHANGESELECT)
#define PlayConfirmEffect()			PlayEffectForMenu(EFFECT_MENUSELECT)
#define PlayBackEffect()			PlayEffectForMenu(EFFECT_CHANGEWEAPON)
#define PlayErrorEffect()			PlayEffectForMenu(EFFECT_BADSELECT)
#define PlayDeleteEffect()			PlayEffectForMenu(EFFECT_CRYSTALSHATTER)
#define PlayStartBindingEffect()	PlayEffectForMenu(EFFECT_GRABEGG)
#define PlayEndBindingEffect()		PlayEffectForMenu(EFFECT_MENUSELECT)

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

enum
{
	kMouseOff,			// the menu is being driven with the keyboard or gamepad
	kMouseWandering,	// the mouse is active, but it's not hovering over any interactable item
	kMouseHovering,		// the mouse is hovering over an interactable item
	kMouseGrabbing,		// the mouse button is held down and grabbing a draggable item
};

const MenuStyle kDefaultMenuStyle =
{
	.darkenPaneOpacity	= 0,
	.fadeInSpeed		= (1.0f / 0.3f),
	.fadeOutSpeed		= (1.0f / 0.2f),
	.asyncFadeOut		= true,
	.fadeOutSceneOnExit	= false,
	.standardScale		= 0.45f,		// Nanosaur 2 original value with old sprite system: 35 -- a bit smaller for source port
	.rowHeight			= 38.0f,		// Nanosaur 2 original value with old sprite system: 35*1.1
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

typedef struct
{
	float height;
	ObjNode* (*layOutCallback)(int row);
	void (*navigateCallback)(const MenuItem* menuItem);
} MenuItemClass;

static const MenuItemClass kMenuItemClasses[kMI_COUNT] =
{
	[kMISENTINEL]		= {0.0f, NULL, NULL },
	[kMILabel]			= {0.9f, LayOutLabel, NULL },
	[kMISpacer]			= {0.5f, NULL, NULL },
	[kMICycler1]		= {1.0f, LayOutCycler1Column, NavigateCycler },
	[kMICycler2]		= {1.0f, LayOutCycler2Columns, NavigateCycler },
	[kMISlider]			= {1.0f, LayOutSlider, NavigateSlider },
	[kMIPick]			= {1.0f, LayOutPick, NavigatePick },
	[kMIKeyBinding]		= {0.8f, LayOutKeyBinding, NavigateKeyBinding },
	[kMIPadBinding]		= {0.8f, LayOutPadBinding, NavigatePadBinding },
	[kMIMouseBinding]	= {0.8f, LayOutMouseBinding, NavigateMouseBinding },
	[kMIFileSlot]		= {1.0f, LayOutFileSlot, NavigatePick },
};

/*********************/
/*    VARIABLES      */
/*********************/

typedef struct
{
	int					menuID;
	const MenuItem*		menu;
	MenuStyle			style;

	int					numRows;

	int					focusRow;
	int					focusComponent;

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

	int					mouseState;
	int					mouseFocusComponent;
#if USE_SDL_CURSOR
	SDL_Cursor*			handCursor;
	SDL_Cursor*			standardCursor;
#endif

	float				idleTime;

	ObjNode*			arrowObjects[2];
	ObjNode*			darkenPane;

	float				sweepDelay;
	bool				sweepRTL;

	uint64_t			validSaveSlotMask;
} MenuNavigation;

static MenuNavigation* gNav = NULL;

int gMenuOutcome = 0;

static int gNumMenusRegistered = 0;
const MenuItem* gMenuRegistry[MAX_REGISTERED_MENUS];

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

	SDL_memcpy(&nav->style, &kDefaultMenuStyle, sizeof(MenuStyle));
	nav->menuPick = -1;
	nav->menuState = kMenuStateOff;
	nav->mouseState = kMouseOff;
	nav->mouseFocusComponent = -1;

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
		nav->arrowObjects[i] = TextMesh_New(i == 0 ? "(" : ")", 0, &arrowDef);
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
	return gNav ? gNav->menuID : 0;
}

float GetMenuIdleTime(void)
{
	return gNav->idleTime;
}

bool IsMenuMouseControlled(void)
{
	return gNav? gNav->mouseState != kMouseOff: false;
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
	if (gNav->focusRow < 0)
		return -1;

	return gNav->menu[gNav->focusRow].id;
}

ObjNode* GetCurrentMenuItemObject(void)
{
	if (gNav->focusRow < 0)
		return NULL;

	return gNav->menuObjects[gNav->focusRow];
}

ObjNode* GetCurrentInteractableMenuItemObject(void)
{
	ObjNode* obj = GetCurrentMenuItemObject();

	if (!obj)
		return NULL;

	switch (gNav->menu[gNav->focusRow].type)
	{
		case kMIKeyBinding:
		case kMIPadBinding:
			return GetNthChainedNode(obj, gNav->focusComponent, NULL);

		case kMIMouseBinding:
		case kMICycler2:
		case kMIFileSlot:
			return GetNthChainedNode(obj, 1, NULL);
			break;

		case kMISlider:
			return GetNthChainedNode(obj, 4, NULL);

		default:
			return obj;
	}
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
		return mi->getLayoutFlags(mi);
	else
		return 0;
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

static const char* GetMenuItemText(const MenuItem* entry)
{
	if (entry->rawText)
		return entry->rawText;
	else
		return Localize(entry->text);
}

static OGLColorRGBA PulsateColor(float* time)
{
	*time += gFramesPerSecondFrac;
	float intensity = (1.0f + sinf(*time * 10.0f)) * 0.5f;
	return (OGLColorRGBA) {1,1,1,intensity};
}

static void SetMaxTextWidth(ObjNode* textNode, float maxWidth)
{
	GetMenuNodeData(textNode)->maxWidth = maxWidth;

	// Reset X scaling if we've squeezed the same node previously
	textNode->Scale.x = textNode->Scale.y;

	// If max width <=0, let it expand
	if (maxWidth <= EPS)
		return;

	OGLRect extents = TextMesh_GetExtents(textNode);
	float extentsWidth = extents.right - extents.left;
	if (extentsWidth > maxWidth)
	{
		textNode->Scale.x *= maxWidth / extentsWidth;
		UpdateObjectTransforms(textNode);
	}
}

static void SetMinClickableWidth(ObjNode* textNode, float minWidth)
{
	OGLRect extents = TextMesh_GetExtents(textNode);
	float extentsWidth = extents.right - extents.left;
	if (extentsWidth < minWidth)
	{
		float padding = 0.5f * (minWidth - extentsWidth);
		textNode->LeftOff -= padding;
		textNode->RightOff += padding;
	}
}

#pragma mark - Input binding utilities

static InputBinding* GetBindingAtRow(int row)
{
	return &gGamePrefs.bindings[gNav->menu[row].inputNeed];
}

// Our font doesn't have glyphs for every symbol on the keyboard,
// so this function provides more verbose descriptions of some scancodes.
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
		case SDL_SCANCODE_SLASH:			return "Slash";
		case SDL_SCANCODE_LEFTBRACKET:		return "Left Bracket";
		case SDL_SCANCODE_RIGHTBRACKET:		return "Right Bracket";
		case SDL_SCANCODE_EQUALS:			return "Equals";
		case SDL_SCANCODE_MINUS:			return "Dash";
		case SDL_SCANCODE_PERIOD:			return "Period";
		case SDL_SCANCODE_KP_PLUS:			return "Keypad Plus";
		case SDL_SCANCODE_KP_MINUS:			return "Keypad Minus";
		case SDL_SCANCODE_KP_DIVIDE:		return "Keypad Slash";
		case SDL_SCANCODE_KP_MULTIPLY:		return "Keypad Star";
		case SDL_SCANCODE_KP_PERIOD:		return "Keypad Period";
		case SDL_SCANCODE_NONUSBACKSLASH:	return "ISO Extra Key";
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
				case SDL_GAMEPAD_BUTTON_INVALID:		return Localize(STR_UNBOUND_PLACEHOLDER);
				case SDL_GAMEPAD_BUTTON_SOUTH:			return Localize(STR_GAMEPAD_BUTTON_A);
				case SDL_GAMEPAD_BUTTON_EAST:			return Localize(STR_GAMEPAD_BUTTON_B);
				case SDL_GAMEPAD_BUTTON_WEST:			return Localize(STR_GAMEPAD_BUTTON_X);
				case SDL_GAMEPAD_BUTTON_NORTH:			return Localize(STR_GAMEPAD_BUTTON_Y);
				case SDL_GAMEPAD_BUTTON_LEFT_SHOULDER:	return Localize(STR_GAMEPAD_BUTTON_LEFT_SHOULDER);
				case SDL_GAMEPAD_BUTTON_RIGHT_SHOULDER:	return Localize(STR_GAMEPAD_BUTTON_RIGHT_SHOULDER);
				case SDL_GAMEPAD_BUTTON_LEFT_STICK:		return Localize(STR_GAMEPAD_BUTTON_LEFT_STICK);
				case SDL_GAMEPAD_BUTTON_RIGHT_STICK:	return Localize(STR_GAMEPAD_BUTTON_RIGHT_STICK);
				case SDL_GAMEPAD_BUTTON_DPAD_UP:		return Localize(STR_GAMEPAD_BUTTON_DPAD_UP);
				case SDL_GAMEPAD_BUTTON_DPAD_DOWN:		return Localize(STR_GAMEPAD_BUTTON_DPAD_DOWN);
				case SDL_GAMEPAD_BUTTON_DPAD_LEFT:		return Localize(STR_GAMEPAD_BUTTON_DPAD_LEFT);
				case SDL_GAMEPAD_BUTTON_DPAD_RIGHT:		return Localize(STR_GAMEPAD_BUTTON_DPAD_RIGHT);
				default:
					return SDL_GetGamepadStringForButton(pb->id);
			}
			break;

		case kInputTypeAxisPlus:
			switch (pb->id)
			{
				case SDL_GAMEPAD_AXIS_INVALID:			return Localize(STR_UNBOUND_PLACEHOLDER);
				case SDL_GAMEPAD_AXIS_LEFTX:			return Localize(STR_GAMEPAD_AXIS_LEFT_STICK_RIGHT);
				case SDL_GAMEPAD_AXIS_LEFTY:			return Localize(STR_GAMEPAD_AXIS_LEFT_STICK_DOWN);
				case SDL_GAMEPAD_AXIS_RIGHTX:			return Localize(STR_GAMEPAD_AXIS_RIGHT_STICK_RIGHT);
				case SDL_GAMEPAD_AXIS_RIGHTY:			return Localize(STR_GAMEPAD_AXIS_RIGHT_STICK_DOWN);
				case SDL_GAMEPAD_AXIS_LEFT_TRIGGER:		return Localize(STR_GAMEPAD_AXIS_LEFT_TRIGGER);
				case SDL_GAMEPAD_AXIS_RIGHT_TRIGGER:	return Localize(STR_GAMEPAD_AXIS_RIGHT_TRIGGER);
				default:
					return SDL_GetGamepadStringForAxis(pb->id);
			}
			break;

		case kInputTypeAxisMinus:
			switch (pb->id)
			{
				case SDL_GAMEPAD_AXIS_INVALID:			return Localize(STR_UNBOUND_PLACEHOLDER);
				case SDL_GAMEPAD_AXIS_LEFTX:			return Localize(STR_GAMEPAD_AXIS_LEFT_STICK_LEFT);
				case SDL_GAMEPAD_AXIS_LEFTY:			return Localize(STR_GAMEPAD_AXIS_LEFT_STICK_UP);
				case SDL_GAMEPAD_AXIS_RIGHTX:			return Localize(STR_GAMEPAD_AXIS_RIGHT_STICK_LEFT);
				case SDL_GAMEPAD_AXIS_RIGHTY:			return Localize(STR_GAMEPAD_AXIS_RIGHT_STICK_UP);
				case SDL_GAMEPAD_AXIS_LEFT_TRIGGER:		return Localize(STR_GAMEPAD_AXIS_LEFT_TRIGGER);
				case SDL_GAMEPAD_AXIS_RIGHT_TRIGGER:	return Localize(STR_GAMEPAD_AXIS_RIGHT_TRIGGER);
				default:
					return SDL_GetGamepadStringForAxis(pb->id);
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
			SDL_snprintf(buf, bufSize, "%s %d", Localize(STR_BUTTON), binding->mouseButton);
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

	ObjNode* node = MakeText(kbName, row, 1+keyNo, kTextMeshSmallCaps | kTextMeshAlignCenter);
	SetMinClickableWidth(node, kMinClickableWidth);
	SetMaxTextWidth(node, 110);
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

	ObjNode* node = MakeText(pbName, row, 1+btnNo, kTextMeshSmallCaps | kTextMeshAlignCenter);
	SetMinClickableWidth(node, kMinClickableWidth);
	SetMaxTextWidth(node, 110);
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

	ObjNode* node = MakeText(mbName, row, 1, kTextMeshAllCaps | kTextMeshAlignCenter);
	SetMinClickableWidth(node, kMinClickableWidth);
	SetMaxTextWidth(node, 110);
	return node;
}

#pragma mark - Twitch effects

static void TwitchSelectionInOrOut(bool scaleIn)
{
	ObjNode* obj = GetCurrentInteractableMenuItemObject();

	if (!obj)
		return;

	float xSquish = obj->Scale.x / obj->Scale.y;

	float s = GetMenuItemHeight(gNav->focusRow) * gNav->style.standardScale;
	obj->Scale.x = s * (scaleIn? 1.1: 1) * xSquish;
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

static void TwitchSelectionNopeWiggle(void)
{
	MakeTwitch(GetCurrentInteractableMenuItemObject(), kTwitchPreset_MenuSelect);
	MakeTwitch(gNav->arrowObjects[0], kTwitchPreset_PadlockWiggle);
	MakeTwitch(gNav->arrowObjects[1], kTwitchPreset_PadlockWiggle);
	PlayErrorEffect();
}

/****************************/
/*    DARKEN PANE           */
/****************************/
#pragma mark - Darken pane

static void DrawDarkenPane(ObjNode* node)
{
	OGL_PushState();

	SetInfobarSpriteState(0, 1);
	OGL_DisableTexture2D();
	OGL_EnableBlend();
	OGL_EnableCullFace();

	glBegin(GL_QUADS);

	float s = node->Scale.y;//node->SpecialF[2];

	float menuTop = node->Coord.y - s /2 ;
	float menuBottom = node->Coord.y + s /2;
	float taper = 16;

	OGLColorRGBA c = node->ColorFilter;

	glColor4f(c.r,c.g,c.b,0);
	glVertex2f(gLogicalRect.right, menuTop-taper);
	glVertex2f(gLogicalRect.left, menuTop-taper);
	glColor4f(c.r,c.g,c.b,c.a);
	glVertex2f(gLogicalRect.left, menuTop);
	glVertex2f(gLogicalRect.right, menuTop);

	glVertex2f(gLogicalRect.right, menuTop);
	glVertex2f(gLogicalRect.left, menuTop);
	glVertex2f(gLogicalRect.left, menuBottom);
	glVertex2f(gLogicalRect.right, menuBottom);

	glVertex2f(gLogicalRect.right, menuBottom);
	glVertex2f(gLogicalRect.left, menuBottom);
	glColor4f(c.r,c.g,c.b,0);
	glVertex2f(gLogicalRect.left, menuBottom+taper);
	glVertex2f(gLogicalRect.right, menuBottom+taper);

	glEnd();

	OGL_PopState();
}

static void MoveDarkenPane(ObjNode* node)
{
	float t = node->Timer + gFramesPerSecondFrac * 5;
	if (t > 1)
		t = 1;
	node->Scale.y = node->SpecialF[0]*(1-t) + node->SpecialF[1]*t;
	node->Timer = t;
}

static void RescaleDarkenPane(ObjNode* node, float totalHeight)
{
	node->SpecialF[0] = node->SpecialF[1];
	node->SpecialF[1] = totalHeight;
	node->Timer = 0;
}

static ObjNode* MakeDarkenPane(void)
{
	ObjNode* pane;

	NewObjectDefinitionType def =
	{
		.genre = CUSTOM_GENRE,
		.flags = STATUS_BITS_FOR_2D | STATUS_BIT_MOVEINPAUSE,
		.slot = gNav->style.textSlot-1,
		.scale = 1,
		.coord = {640/2, gNav->style.yOffset, 0},
		.moveCall = MoveDarkenPane,
		.drawCall = DrawDarkenPane,
	};

	pane = MakeNewObject(&def);
	pane->Scale.y = EPS;
	pane->ColorFilter = (OGLColorRGBA) {0, 0, 0, gNav->style.darkenPaneOpacity};
	SendNodeToOverlayPane(pane);

	return pane;
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
	if (GetMenuNodeData(node)->row == gNav->focusRow)
		node->ColorFilter = gNav->style.highlightColor;
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

	if (data->row == gNav->focusRow && data->component == gNav->focusComponent)
	{
		if (gNav->menuState == pulsatingState)
		{
			node->ColorFilter = PulsateColor(&data->pulsateTimer);
		}
		else
		{
			node->ColorFilter = gNav->style.highlightColor;
		}
	}
	else
	{
		node->ColorFilter = gNav->style.idleColor;
	}

	MoveGenericMenuItem(node, node->ColorFilter.a);
}

/****************************/
/*    MENU HISTORY          */
/****************************/
#pragma mark - Menu history

static void SaveSelectedRowInHistory(void)
{
	gNav->history[gNav->historyPos].row = gNav->focusRow;
}

static void GoBackInHistory(void)
{
	MyFlushEvents();

	if (gNav->historyPos != 0)
	{
		PlayBackEffect();
		gNav->historyPos--;

		gNav->sweepRTL = true;
		LayOutMenu(gNav->history[gNav->historyPos].menuID);
		gNav->sweepRTL = false;
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

/****************************/
/*    MENU NAVIGATION       */
/****************************/
#pragma mark - General menu navigation

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
		NavigateMenuVertically(-1);
		SaveSelectedRowInHistory();
		gNav->mouseState = kMouseOff;
	}
	else if (IsNeedDown(kNeed_UIDown, ANY_PLAYER))
	{
		NavigateMenuVertically(1);
		SaveSelectedRowInHistory();
		gNav->mouseState = kMouseOff;
	}
	else
	{
		NavigateMenuMouseHover();
	}

	const MenuItem* entry = &gNav->menu[gNav->focusRow];
	const MenuItemClass* cls = &kMenuItemClasses[entry->type];

	if (cls->navigateCallback)
	{
		cls->navigateCallback(entry);
	}
}

static void UpdateArrows(void)
{
	ObjNode* snapTo = NULL;
	ObjNode* chainRoot = GetCurrentMenuItemObject();

	bool visible[2] = {false, false};

	const MenuItem* entry = &gNav->menu[gNav->focusRow];

	snapTo = GetCurrentInteractableMenuItemObject();

	switch (entry->type)
	{
		case kMICycler1:
		case kMICycler2:
		{
			int index = GetValueIndexInCycler(entry, *entry->cycler.valuePtr);
			visible[0] = (index != 0);
			visible[1] = (index != GetCyclerNumChoices(entry)-1);
			break;
		}

		case kMIKeyBinding:
		case kMIPadBinding:
			visible[0] = true;
			visible[1] = true;
			switch (gNav->menuState)
			{
				case kMenuStateAwaitingKeyPress:
				case kMenuStateAwaitingPadPress:
				case kMenuStateAwaitingMouseClick:
					visible[0] = false;
					visible[1] = false;
			}
			break;

		case kMISlider:
			visible[0] = *entry->slider.valuePtr != entry->slider.minValue;
			visible[1] = *entry->slider.valuePtr != entry->slider.maxValue;
			snapTo = chainRoot->ChainNode;  // bar
			break;

		case kMIMouseBinding:
		default:
			snapTo = NULL;
			break;
	}

	if (gNav->mouseState != kMenuStateOff)
	{
		snapTo = NULL;
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

		arrowObj->Coord.x = i==0? (extents.left - spacing): (extents.right + spacing);
		arrowObj->Coord.y = snapTo->Coord.y;
		arrowObj->Scale = snapTo->Scale;

		arrowObj->ColorFilter.a = visible[i] ? 1 : 0;
	}

	// Finally, update object transforms
	for (int i = 0; i < 2; i++)
	{
		UpdateObjectTransforms(gNav->arrowObjects[i]);
	}
}

static void NavigateMenuVertically(int delta)
{
	bool makeSound = gNav->focusRow >= 0;
	int browsed = 0;
	bool skipEntry = false;

	TwitchOutSelection();

	do
	{
		gNav->focusRow += delta;
		gNav->focusRow = PositiveModulo(gNav->focusRow, (unsigned int)gNav->numRows);

		skipEntry = !IsMenuItemSelectable(&gNav->menu[gNav->focusRow]);

		if (browsed++ > gNav->numRows)
		{
			// no entries are selectable
			return;
		}
	} while (skipEntry);

	gNav->idleTime = 0;

	if (makeSound)
	{
		PlayNavigateEffect();
		TwitchSelection();
	}
}

static void NavigateMenuMouseHover(void)
{
	if (gNav->mouseState == kMouseGrabbing)
	{
		return;
	}

	static OGLPoint2D cursor = { -1, -1 };

	if (cursor.x == gCursorCoord.x && cursor.y == gCursorCoord.y)
	{
		// Mouse didn't move from last time
		return;
	}

	cursor = gCursorCoord;

	gNav->mouseState = kMouseWandering;
	gNav->mouseFocusComponent = -1;

	for (int row = 0; row < gNav->numRows; row++)
	{
		if (!IsMenuItemSelectable(&gNav->menu[row]))
		{
			continue;
		}

		OGLRect fullExtents;
		fullExtents.top		= fullExtents.left	= 100000;
		fullExtents.bottom	= fullExtents.right	= -100000;

		ObjNode* textNode = gNav->menuObjects[row];
		int focusedComponent = -1;

		for (int component = 0; textNode; component++, textNode=textNode->ChainNode)
		{
			OGLRect extents = TextMesh_GetExtents(textNode);
			if (extents.top		< fullExtents.top	) fullExtents.top		= extents.top;
			if (extents.left	< fullExtents.left	) fullExtents.left		= extents.left;
			if (extents.bottom	> fullExtents.bottom) fullExtents.bottom	= extents.bottom;
			if (extents.right	> fullExtents.right	) fullExtents.right		= extents.right;

			if (cursor.y >= extents.top
				&& cursor.y <= extents.bottom
				&& cursor.x >= extents.left - kMouseHoverTolerance
				&& cursor.x <= extents.right + kMouseHoverTolerance)
			{
				focusedComponent = component;
				// Don't break -- if several components overlap, we want to focus on the one with the highest component number
			}
		}

		if (cursor.y >= fullExtents.top &&
			cursor.y <= fullExtents.bottom &&
			cursor.x >= fullExtents.left - kMouseHoverTolerance &&
			cursor.x <= fullExtents.right + kMouseHoverTolerance)
		{
			gNav->mouseState = kMouseHovering;
			gNav->mouseFocusComponent = focusedComponent;

#if USE_SDL_CURSOR
			SetHandMouseCursor();				// set hand cursor
#endif

			if (gNav->focusRow != row)
			{
				gNav->idleTime = 0;
				TwitchSelectionInOrOut(false);
				gNav->focusRow = row;
				PlayNavigateEffect();
				TwitchSelectionInOrOut(true);
			}

			return;
		}
	}

	GAME_ASSERT(gNav->mouseState == kMouseWandering);		// if we got here, we're not hovering over anything

#if USE_SDL_CURSOR
	SetStandardMouseCursor();					// restore standard cursor
#endif
}

#pragma mark - Widget: Label

static ObjNode* LayOutLabel(int row)
{
	const MenuItem* entry = &gNav->menu[row];

	ObjNode* label = MakeText(GetMenuItemText(entry), row, 0, kTextMeshSmallCaps | kTextMeshUserFlag_AltFont);
	label->ColorFilter = gNav->style.labelColor;
	label->MoveCall = MoveLabel;
	SetMaxTextWidth(label, 620);

	return label;
}

#pragma mark - Widget: Pick

static ObjNode* LayOutPick(int row)
{
	const MenuItem* entry = &gNav->menu[row];

	ObjNode* obj = MakeText(GetMenuItemText(entry), row, 0, 0);
	obj->MoveCall = MoveAction;

	SetMinClickableWidth(obj, 80);

	return obj;
}

static void NavigatePick(const MenuItem* entry)
{
	bool validClick = (gNav->mouseState == kMouseHovering && IsClickDown(SDL_BUTTON_LEFT));

	if (IsNeedDown(kNeed_UIConfirm, ANY_PLAYER) || validClick)
	{
		if (!validClick)
			gNav->mouseState = kMouseOff;		// exit mouse control if didn't get click

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

#pragma mark - Widget: Cycler

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

static ObjNode* LayOutCycler2ColumnsValueText(int row)
{
	ObjNode* node2 = MakeText(GetCyclerValueText(row), row, 1, kTextMeshAlignCenter);
	node2->MoveCall = MoveAction;
	SetMinClickableWidth(node2, kMinClickableWidth);
	SetMaxTextWidth(node2, 150);
	return node2;
}

static ObjNode* LayOutCycler2Columns(int row)
{
	DECLARE_WORKBUF(buf, bufSize);

	const MenuItem* entry = &gNav->menu[row];

	SDL_snprintf(buf, bufSize, "%s:", GetMenuItemText(entry));

	ObjNode* node1 = MakeText(buf, row, 0, kTextMeshAlignLeft | kTextMeshSmallCaps | kTextMeshUserFlag_AltFont);
	node1->Coord.x = k2ColumnLeftX;
	node1->MoveCall = MoveAction;
	SetMaxTextWidth(node1, 230);
	UpdateObjectTransforms(node1);

	ObjNode* node2 = LayOutCycler2ColumnsValueText(row);
	node2->Coord.x = k2ColumnRightX;
	UpdateObjectTransforms(node2);

	return node1;
}

static ObjNode* LayOutCycler1Column(int row)
{
	DECLARE_WORKBUF(buf, bufSize);

	const MenuItem* entry = &gNav->menu[row];

	if (entry->text == STR_NULL && entry->rawText == NULL)
		SDL_snprintf(buf, bufSize, "%s", GetCyclerValueText(row));
	else
		SDL_snprintf(buf, bufSize, "%s: %s", GetMenuItemText(entry), GetCyclerValueText(row));

	ObjNode* node = MakeText(buf, row, 0, kTextMeshSmallCaps);
	node->MoveCall = MoveAction;

	return node;
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

	if (IsNeedDown(kNeed_UIPrev, ANY_PLAYER))
	{
		delta = -1;
		gNav->mouseState = kMouseOff;
	}
	else if (IsNeedDown(kNeed_UINext, ANY_PLAYER))
	{
		delta = 1;
		gNav->mouseState = kMouseOff;
	}
	else if (IsNeedDown(kNeed_UIConfirm, ANY_PLAYER))
	{
		gNav->mouseState = kMouseOff;
		TwitchSelectionNopeWiggle();
		return;
	}
	else if (gNav->mouseState == kMouseHovering)
	{
		if (IsClickDown(SDL_BUTTON_LEFT))
		{
			delta = 1;
			allowWrap = true;
		}
		else if (IsClickDown(SDL_BUTTON_RIGHT))
		{
			delta = -1;
			allowWrap = true;
		}
		else if (IsClickDown(SDL_BUTTON_WHEELDOWN) || IsClickDown(SDL_BUTTON_WHEELLEFT))
		{
			delta = -1;
		}
		else if (IsClickDown(SDL_BUTTON_WHEELUP) || IsClickDown(SDL_BUTTON_WHEELRIGHT))
		{
			delta = 1;
		}
	}

	if (delta != 0)
	{
		gNav->idleTime = 0;
		gNav->sweepRTL = (delta == -1);

		if (entry->cycler.valuePtr)
		{
			int index = GetValueIndexInCycler(entry, *entry->cycler.valuePtr);

			if (!allowWrap)
			{
				if ((index == 0 && delta < 0) ||
					(index == GetCyclerNumChoices(entry)-1 && delta > 0))
				{
					TwitchSelectionNopeWiggle();
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

		if (entry->type == kMICycler1)
			LayOutCycler1Column(gNav->focusRow);
		else
			LayOutCycler2ColumnsValueText(gNav->focusRow);

		if (delta < 0)
			MakeTwitch(gNav->arrowObjects[0], kTwitchPreset_DisplaceLTR);
		else
			MakeTwitch(gNav->arrowObjects[1], kTwitchPreset_DisplaceRTL);
	}
}

#pragma mark - Widget: Slider

static SliderComponents GetSliderComponents(const MenuItem* entry, ObjNode* sliderRoot)
{
	GAME_ASSERT(entry->type == kMISlider);

	ObjNode* nodes[5] = {NULL};
	nodes[0] = sliderRoot;
	for (int i = 1; i < (int)(sizeof(nodes)/sizeof(nodes[0])); i++)
	{
		nodes[i] = nodes[i-1]->ChainNode;
		GAME_ASSERT(nodes[i]);
	}

	SliderComponents sliderInfo =
	{
		.caption		= nodes[0],
		.bar			= nodes[1],
		.notch			= nodes[2],
		.meter			= nodes[3],
		.knob			= nodes[4],
	};

	OGLRect barExtents = TextMesh_GetExtents(sliderInfo.bar);

	sliderInfo.vmin = entry->slider.minValue;
	sliderInfo.vmax = entry->slider.maxValue;
	sliderInfo.xmin = barExtents.left;
	sliderInfo.xmax = barExtents.right;

	return sliderInfo;
}

static float SliderKnobXToValue(const SliderComponents* info, float x)
{
	float v = RangeTranspose(x, info->xmin, info->xmax, info->vmin, info->vmax);
	v = GAME_CLAMP(v, info->vmin, info->vmax);
	return v;
}

static float SliderValueToKnobX(const SliderComponents* info, float v)
{
	return RangeTranspose(v, info->vmin, info->vmax, info->xmin, info->xmax);
}

static ObjNode* LayOutSlider(int row)
{
	DECLARE_WORKBUF(buf, bufSize);
	const MenuItem* entry = &gNav->menu[row];
	const MenuSliderData* sliderData = &entry->slider;

	GAME_ASSERT(sliderData->valuePtr);
	GAME_ASSERT(sliderData->increment != 0);
	GAME_ASSERT(sliderData->equilibrium >= entry->slider.minValue);
	GAME_ASSERT(sliderData->equilibrium <= entry->slider.maxValue);

	int chain = 0;

	// Caption
	SDL_snprintf(buf, bufSize, "%s:", GetMenuItemText(entry));
	ObjNode* rootNode = MakeText(buf, row, chain++, kTextMeshAlignLeft | kTextMeshSmallCaps | kTextMeshUserFlag_AltFont);
	ObjNode* node = rootNode;
	node->Coord.x = k2ColumnLeftX;
	SetMaxTextWidth(node, 230);

	// Bar (glyph U+00A2 in green font -- 0xC2A2 in UTF-8)
	node = MakeText("\xC2\xA2", row, chain++, kTextMeshAlignCenter);
	node->Coord.x = k2ColumnRightX;

	// Notch (glyph U+00A3 in green font -- 0xC2A3 in UTF-8)
	node = MakeText("\xC2\xA3", row, chain++, kTextMeshAlignCenter);
	node->Coord.x = k2ColumnRightX;
	node->ColorFilter.a = 0.5f;

	// Meter
	SDL_snprintf(buf, bufSize, "%d ", *sliderData->valuePtr);
	node = MakeText(buf, row, chain++, kTextMeshAlignCenter);
	node->Scale.x /= 3;
	node->Scale.y /= 3;
	node->Coord.y -= 12;

	// Knob  (glyph '#' in green font)
	node = MakeText("#", row, chain++, kTextMeshAlignCenter);

	SliderComponents parts = GetSliderComponents(entry, rootNode);
	float knobX = SliderValueToKnobX(&parts, (float) *sliderData->valuePtr);
	parts.notch->Coord.x = SliderValueToKnobX(&parts, (float) sliderData->equilibrium);
	parts.knob->Coord.x = knobX;
	parts.meter->Coord.x = knobX;

	for (ObjNode* chainNode = rootNode; chainNode; chainNode = chainNode->ChainNode)
	{
		chainNode->MoveCall = MoveAction;
		UpdateObjectTransforms(chainNode);
	}

	return rootNode;
}

static float SetNewSliderValue(const MenuItem* entry, SliderComponents* parts, float mouseValue)
{
	float knobX = SliderValueToKnobX(parts, mouseValue);			// clamp X

	parts->knob->Coord.x = knobX;
	parts->meter->Coord.x = knobX;

	char meterBuf[8];
	SDL_snprintf(meterBuf, sizeof(meterBuf), "%d ", (int)mouseValue);
	TextMesh_Update(meterBuf, kTextMeshAlignCenter, parts->meter);

	UpdateObjectTransforms(parts->knob);
	UpdateObjectTransforms(parts->meter);

	Byte byteValue = (Byte) mouseValue;
	if (*entry->slider.valuePtr != byteValue)
	{
		int mouseValueInt = (int) mouseValue;
		mouseValueInt = GAME_CLAMP(mouseValueInt, entry->slider.minValue, entry->slider.maxValue);
		*entry->slider.valuePtr = (Byte) mouseValueInt;

		if (entry->callback && entry->slider.continuousCallback)
		{
			entry->callback();
		}
	}

	return knobX;
}

static void NavigateSlider(const MenuItem* entry)
{
	// the state can be static because we can only drag one slider at a time
	static float prevTickX = -1;
	static float grabOffset = -1;
	static float heldCooldown = -1;
	static bool beingDragged = false;
	static bool didRamEdge = false;

	ObjNode* sliderRoot = GetCurrentMenuItemObject();
	SliderComponents parts = GetSliderComponents(entry, sliderRoot);

	if (gNav->mouseState == kMouseHovering && IsClickDown(SDL_BUTTON_LEFT))
	{
		switch (gNav->mouseFocusComponent)
		{
			case 1:		// bar
			{
				// Snap knob to mouse pos and start grabbing it
				float value = SliderKnobXToValue(&parts, gCursorCoord.x);
				SetNewSliderValue(entry, &parts, value);
				beingDragged = true;
				break;
			}

			case 3:		// meter text
			case 4:		// knob
				// Start grabbing knob
				beingDragged = true;
				break;
		}

		if (beingDragged)
		{
			prevTickX = parts.knob->Coord.x;
			grabOffset = gCursorCoord.x - parts.knob->Coord.x;
			gNav->mouseState = kMouseGrabbing;			// lock mouse to this widget

			PlayStartBindingEffect();
			TwitchSelection();
		}
	}
	else if (beingDragged && IsClickHeld(SDL_BUTTON_LEFT))
	{
		float knobX = gCursorCoord.x - grabOffset;
		float mouseValue = SliderKnobXToValue(&parts, knobX);
		knobX = SetNewSliderValue(entry, &parts, mouseValue);

		if (fabsf(prevTickX - knobX) >= 7)
		{
			float pitch = RangeTranspose(mouseValue, parts.vmin, parts.vmax, 0.5f, 0.9f);
			PlayEffect_Parms(EFFECT_CHANGESELECT, FULL_CHANNEL_VOLUME/3, FULL_CHANNEL_VOLUME/3, NORMAL_CHANNEL_RATE * pitch );

			PlayNavigateEffect();
			prevTickX = knobX;
			TwitchSelection();
		}
	}
	else if (beingDragged
		&& (IsClickUp(SDL_BUTTON_LEFT) || IsNeedUp(kNeed_UIPrev, ANY_PLAYER) || IsNeedUp(kNeed_UINext, ANY_PLAYER)))
	{
		beingDragged = false;

		if (gNav->mouseState == kMouseGrabbing)		// unlock mouse from this widget
			gNav->mouseState = kMouseWandering;

		PlayConfirmEffect();
		if (entry->callback)
			entry->callback();
	}
	else if (IsNeedDown(kNeed_UIConfirm, ANY_PLAYER))
	{
		MakeTwitch(GetCurrentInteractableMenuItemObject(), kTwitchPreset_MenuSelect);
		MakeTwitch(gNav->arrowObjects[0], kTwitchPreset_PadlockWiggle);
		MakeTwitch(gNav->arrowObjects[1], kTwitchPreset_PadlockWiggle);
		PlayErrorEffect();
	}
	else if (IsNeedActive(kNeed_UIPrev, ANY_PLAYER) || IsNeedActive(kNeed_UINext, ANY_PLAYER))
	{
		int direction = IsNeedActive(kNeed_UIPrev, ANY_PLAYER)? -1: 1;
		int need = direction < 0? kNeed_UIPrev : kNeed_UINext;

		bool didJustPress = IsNeedDown(need, ANY_PLAYER);

		if (didJustPress)
		{
			didRamEdge = false;
		}
		else
		{
			heldCooldown -= gFramesPerSecondFrac * 12 * (GetNeedAnalogValue(kNeed_UIPrev, ANY_PLAYER) + GetNeedAnalogValue(kNeed_UINext, ANY_PLAYER));

			if (heldCooldown > 0)
			{
				return;
			}
		}

		if ((direction < 0 && *entry->slider.valuePtr == entry->slider.minValue)
			|| (direction > 0 && *entry->slider.valuePtr == entry->slider.maxValue))
		{
			if (!didRamEdge)
			{
				MakeTwitch(GetCurrentInteractableMenuItemObject(), kTwitchPreset_MenuSelect);
				MakeTwitch(gNav->arrowObjects[0], kTwitchPreset_PadlockWiggle);
				MakeTwitch(gNav->arrowObjects[1], kTwitchPreset_PadlockWiggle);
				PlayErrorEffect();
				didRamEdge = true;
			}
		}
		else
		{
			gNav->mouseState = kMouseOff;

			int increment = entry->slider.increment;

			float v = *entry->slider.valuePtr;

			v = increment * roundf(v / (float)increment);	// first, snap value to the nearest multiple of the increment
			v += direction * increment;
			v = roundf(v);
			v = GAME_CLAMP(v, entry->slider.minValue, entry->slider.maxValue);

			SetNewSliderValue(entry, &parts, v);

			float pitch = RangeTranspose(v, parts.vmin, parts.vmax, 0.5f, 0.9f);
			PlayEffect_Parms(EFFECT_CHANGESELECT, FULL_CHANNEL_VOLUME/3, FULL_CHANNEL_VOLUME/3, NORMAL_CHANNEL_RATE * pitch );

			PlayNavigateEffect();
			TwitchSelection();

			beingDragged = true;
			heldCooldown = didJustPress? 2.5f: 1;			// longer delay on first iteration

			// twitch arrows
			if (direction < 0)
				MakeTwitch(gNav->arrowObjects[0], kTwitchPreset_DisplaceLTR);
			else
				MakeTwitch(gNav->arrowObjects[1], kTwitchPreset_DisplaceRTL);
		}
	}
}

#pragma mark - Widget: File slot

static ObjNode* LayOutFileSlot(int row)
{
	DECLARE_WORKBUF(buf, bufSize);
	char dateBuf[64];

	const MenuItem* entry = &gNav->menu[row];

	SDL_snprintf(buf, bufSize, "%s %d", GetMenuItemText(entry), 1+entry->fileSlot);
	ObjNode* node1 = MakeText(buf, row, 0, kTextMeshAlignLeft | kTextMeshSmallCaps | kTextMeshUserFlag_AltFont);
	node1->Coord.x = k2ColumnLeftX;
	node1->MoveCall = MoveAction;
	SetMaxTextWidth(node1, 100);
	UpdateObjectTransforms(node1);

	SaveGameType saveData;

	bool validSave = LoadSavedGame(entry->fileSlot, &saveData);

	if (validSave)
	{
		gNav->validSaveSlotMask |= (1ul << entry->fileSlot);
	}

	if (!validSave)
	{
		SDL_snprintf(buf, bufSize, "---------------- %s ----------------", Localize(STR_EMPTY_SLOT));
	}
	else
	{
		SDL_DateTime dt = {0};
		SDL_TimeToDateTime(saveData.timestamp * 1e9, &dt, true);
		const char* month = Localize(dt.month - 1 + STR_JANUARY);
		int day = dt.day;
		int year = dt.year;

		switch (gGamePrefs.language)
		{
			case LANGUAGE_ENGLISH:
				SDL_snprintf(dateBuf, sizeof(dateBuf), "%s %d, %d", month, day, year);
				break;
			case LANGUAGE_GERMAN:
				SDL_snprintf(dateBuf, sizeof(dateBuf), "%d. %s %d", day, month, year);
				break;
			case LANGUAGE_RUSSIAN:
				SDL_snprintf(dateBuf, sizeof(dateBuf), "%d %s %d \u0433.", day, month, year);
				break;
			default:
				SDL_snprintf(dateBuf, sizeof(dateBuf), "%d %s %d", day, month, year);
				break;
		}

		SDL_snprintf(buf, bufSize, "%s %d   %s", Localize(STR_LEVEL), saveData.level + 1, dateBuf);
	}

	ObjNode* node2 = MakeText(buf, row, 1, kTextMeshAlignLeft | kTextMeshSmallCaps);
	node2->Coord.x = k2ColumnLeftX + 120;
	node2->MoveCall = MoveAction;
	UpdateObjectTransforms(node2);

	return node1;
}

int DisableEmptyFileSlots(const MenuItem* mi)
{
	bool isValid = (gNav->validSaveSlotMask >> mi->fileSlot) & 1;
	return isValid? 0: kMILayoutFlagDisabled;
}

#pragma mark - Widget: Key/Pad/Mouse Binding

static ObjNode* LayOutKeyBinding(int row)
{
	DECLARE_WORKBUF(buf, bufSize);
	const MenuItem* entry = &gNav->menu[row];

	SDL_snprintf(buf, bufSize, "%s:", Localize(STR_KEYBINDING_DESCRIPTION_0 + entry->inputNeed));

	ObjNode* label = MakeText(buf, row, 0, kTextMeshAlignLeft | kTextMeshSmallCaps | kTextMeshUserFlag_AltFont);
	label->Coord.x = 100;
	label->ColorFilter = gNav->style.labelColor;
	label->MoveCall = MoveAction;
	SetMaxTextWidth(label, 110);
	UpdateObjectTransforms(label);

	for (int j = 0; j < MAX_USER_BINDINGS_PER_NEED; j++)
	{
		ObjNode* keyNode = MakeKbText(row, j);
		keyNode->Coord.x = 300 + j * 170 ;
		keyNode->MoveCall = MoveControlBinding;
		UpdateObjectTransforms(keyNode);
	}

	return label;
}

static ObjNode* LayOutPadBinding(int row)
{
	DECLARE_WORKBUF(buf, bufSize);
	const MenuItem* entry = &gNav->menu[row];

	SDL_snprintf(buf, bufSize, "%s:", Localize(STR_KEYBINDING_DESCRIPTION_0 + entry->inputNeed));

	ObjNode* label = MakeText(buf, row, 0, kTextMeshAlignLeft | kTextMeshSmallCaps | kTextMeshUserFlag_AltFont);
	label->Coord.x = 100;
	label->ColorFilter = gNav->style.labelColor;
	label->MoveCall = MoveAction;
	SetMaxTextWidth(label, 110);
	UpdateObjectTransforms(label);

	for (int j = 0; j < MAX_USER_BINDINGS_PER_NEED; j++)
	{
		ObjNode* keyNode = MakePbText(row, j);
		keyNode->Coord.x = 300 + j * 170;
		keyNode->MoveCall = MoveControlBinding;
		UpdateObjectTransforms(keyNode);
	}

	return label;
}

static ObjNode* LayOutMouseBinding(int row)
{
	DECLARE_WORKBUF(buf, bufSize);
	const MenuItem* entry = &gNav->menu[row];

	SDL_snprintf(buf, bufSize, "%s:", Localize(STR_KEYBINDING_DESCRIPTION_0 + entry->inputNeed));

	ObjNode* label = MakeText(buf, row, 0, kTextMeshAlignLeft | kTextMeshSmallCaps | kTextMeshUserFlag_AltFont);
	label->Coord.x = k2ColumnLeftX;
	label->ColorFilter = gNav->style.labelColor;
	label->MoveCall = MoveAction;
	SetMaxTextWidth(label, 150);
	UpdateObjectTransforms(label);

	ObjNode* keyNode = MakeMbText(row);
	keyNode->Coord.x = k2ColumnRightX;
	keyNode->MoveCall = MoveControlBinding;
	SetMinClickableWidth(keyNode, 70);
	UpdateObjectTransforms(keyNode);

	return label;
}

static void NavigateKeyBinding(const MenuItem* entry)
{
	int keyNo = gNav->focusComponent - 1;
	keyNo = PositiveModulo(keyNo, MAX_USER_BINDINGS_PER_NEED);
	gNav->focusComponent = keyNo + 1;

	int row = gNav->focusRow;

	if (gNav->mouseState == kMouseHovering
		&& (gNav->mouseFocusComponent == 1 || gNav->mouseFocusComponent == 2)
		&& (keyNo != gNav->mouseFocusComponent - 1))
	{
		keyNo = gNav->mouseFocusComponent - 1;
		TwitchOutSelection();
		gNav->idleTime = 0;
		gNav->focusComponent = keyNo + 1;
		PlayNavigateEffect();
		TwitchSelection();
		return;
	}

	if (IsNeedDown(kNeed_UIPrev, ANY_PLAYER))
	{
		TwitchOutSelection();
		keyNo = PositiveModulo(keyNo - 1, MAX_USER_BINDINGS_PER_NEED);
		gNav->idleTime = 0;
		gNav->focusComponent = keyNo + 1;
		PlayNavigateEffect();
		gNav->mouseState = kMouseOff;
		TwitchSelection();
		return;
	}

	if (IsNeedDown(kNeed_UINext, ANY_PLAYER))
	{
		TwitchOutSelection();
		keyNo = PositiveModulo(keyNo + 1, MAX_USER_BINDINGS_PER_NEED);
		gNav->idleTime = 0;
		gNav->focusComponent = keyNo + 1;
		PlayNavigateEffect();
		gNav->mouseState = kMouseOff;
		TwitchSelection();
		return;
	}

	if (IsNeedDown(kNeed_UIDelete, ANY_PLAYER)
		|| IsKeyDown(CLEAR_BINDING_SCANCODE)
		|| (gNav->mouseState == kMouseHovering && IsClickDown(SDL_BUTTON_MIDDLE)))
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
		|| (gNav->mouseState == kMouseHovering && IsClickDown(SDL_BUTTON_LEFT)))
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
	int btnNo = gNav->focusComponent - 1;
	btnNo = PositiveModulo(btnNo, MAX_USER_BINDINGS_PER_NEED);
	gNav->focusComponent = btnNo + 1;

	int row = gNav->focusRow;

	if (gNav->mouseState == kMouseHovering
		&& (gNav->mouseFocusComponent == 1 || gNav->mouseFocusComponent == 2)
		&& (btnNo != gNav->mouseFocusComponent - 1))
	{
		btnNo = gNav->mouseFocusComponent - 1;
		TwitchOutSelection();
		gNav->idleTime = 0;
		gNav->focusComponent = btnNo + 1;
		PlayNavigateEffect();
		TwitchSelection();
		return;
	}

	if (IsNeedDown(kNeed_UIPrev, ANY_PLAYER))
	{
		TwitchOutSelection();
		btnNo = PositiveModulo(btnNo - 1, MAX_USER_BINDINGS_PER_NEED);
		gNav->focusComponent = btnNo + 1;
		gNav->idleTime = 0;
		gNav->mouseState = kMouseOff;
		PlayNavigateEffect();
		TwitchSelection();
		return;
	}

	if (IsNeedDown(kNeed_UINext, ANY_PLAYER))
	{
		TwitchOutSelection();
		btnNo = PositiveModulo(btnNo + 1, MAX_USER_BINDINGS_PER_NEED);
		gNav->focusComponent = btnNo + 1;
		gNav->idleTime = 0;
		gNav->mouseState = kMouseOff;
		PlayNavigateEffect();
		TwitchSelection();
		return;
	}

	if (IsNeedDown(kNeed_UIDelete, ANY_PLAYER)
		|| IsKeyDown(CLEAR_BINDING_SCANCODE)
		|| (gNav->mouseState == kMouseHovering && IsClickDown(SDL_BUTTON_MIDDLE)))
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
		|| (gNav->mouseState == kMouseHovering && IsClickDown(SDL_BUTTON_LEFT)))
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
	int row = gNav->focusRow;
	gNav->focusComponent = 1;

	if (IsNeedDown(kNeed_UIDelete, ANY_PLAYER)
		|| IsKeyDown(CLEAR_BINDING_SCANCODE)
		|| (gNav->mouseState == kMouseHovering && IsClickDown(SDL_BUTTON_MIDDLE)))
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
		|| (gNav->mouseState == kMouseHovering && IsClickDown(SDL_BUTTON_LEFT)))
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

/****************************/
/* INPUT BINDING CALLBACKS  */
/****************************/
#pragma mark - Input binding callbacks

static void UnbindScancodeFromAllRemappableInputNeeds(int16_t sdlScancode)
{
	for (int row = 0; row < gNav->numRows; row++)
	{
		if (gNav->menu[row].type != kMIKeyBinding)
			continue;

		InputBinding* binding = GetBindingAtRow(row);

		for (int j = 0; j < MAX_USER_BINDINGS_PER_NEED; j++)
		{
			if (binding->key[j] == sdlScancode)
			{
				binding->key[j] = 0;
				MakeText(Localize(STR_UNBOUND_PLACEHOLDER), row, j+1, kTextMeshAllCaps | kTextMeshAlignCenter);
			}
		}
	}
}

static void UnbindPadButtonFromAllRemappableInputNeeds(int8_t type, int8_t id)
{
	for (int row = 0; row < gNav->numRows; row++)
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
				MakeText(Localize(STR_UNBOUND_PLACEHOLDER), row, j+1, kTextMeshAllCaps | kTextMeshAlignCenter);
			}
		}
	}
}

static void UnbindMouseButtonFromAllRemappableInputNeeds(int8_t id)
{
	for (int row = 0; row < gNav->numRows; row++)
	{
		if (gNav->menu[row].type != kMIMouseBinding)
			continue;

		InputBinding* binding = GetBindingAtRow(row);

		if (binding->mouseButton == id)
		{
			binding->mouseButton = 0;
			MakeText(Localize(STR_UNBOUND_PLACEHOLDER), row, 1, kTextMeshAllCaps | kTextMeshAlignCenter);
		}
	}
}

static void AwaitKeyPress(void)
{
	int row = gNav->focusRow;
	int keyNo = gNav->focusComponent - 1;
	GAME_ASSERT(keyNo >= 0);
	GAME_ASSERT(keyNo < MAX_USER_BINDINGS_PER_NEED);

	bool doWiggle = false;

	if (IsKeyDown(SDL_SCANCODE_ESCAPE)
		|| IsClickDown(SDL_BUTTON_LEFT)
		|| IsClickDown(SDL_BUTTON_RIGHT))
	{
		doWiggle = true;
		goto updateText;
	}

	for (int16_t scancode = 0; scancode < SDL_SCANCODE_COUNT; scancode++)
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
	ReplaceMenuText(STR_CONFIGURE_KEYBOARD_HELP, STR_CONFIGURE_KEYBOARD_HELP);

	if (doWiggle)
		TwitchSelectionNopeWiggle();
}

static bool AwaitGamepadPress(SDL_Gamepad* controller)
{
	int row = gNav->focusRow;
	int btnNo = gNav->focusComponent - 1;
	GAME_ASSERT(btnNo >= 0);
	GAME_ASSERT(btnNo < MAX_USER_BINDINGS_PER_NEED);

	bool doWiggle = false;

	if (IsKeyDown(SDL_SCANCODE_ESCAPE)
		|| SDL_GetGamepadButton(controller, SDL_GAMEPAD_BUTTON_START)
		|| IsClickDown(SDL_BUTTON_LEFT)
		|| IsClickDown(SDL_BUTTON_RIGHT))
	{
		doWiggle = true;
		goto updateText;
	}

	InputBinding* binding = GetBindingAtRow(gNav->focusRow);

	for (int8_t button = 0; button < SDL_GAMEPAD_BUTTON_COUNT; button++)
	{
#if 0	// uncomment to prevent binding d-pad
		switch (button)
		{
			case SDL_GAMEPAD_BUTTON_DPAD_UP:			// prevent binding those
			case SDL_GAMEPAD_BUTTON_DPAD_DOWN:
			case SDL_GAMEPAD_BUTTON_DPAD_LEFT:
			case SDL_GAMEPAD_BUTTON_DPAD_RIGHT:
				continue;
		}
#endif

		if (SDL_GetGamepadButton(controller, button))
		{
			PlayEndBindingEffect();
			UnbindPadButtonFromAllRemappableInputNeeds(kInputTypeButton, button);
			binding->pad[btnNo].type = kInputTypeButton;
			binding->pad[btnNo].id = button;
			goto updateText;
		}
	}

	for (int8_t axis = 0; axis < SDL_GAMEPAD_AXIS_COUNT; axis++)
	{
#if 0	// uncomment to prevent binding LS/RS
		switch (axis)
		{
			case SDL_GAMEPAD_AXIS_LEFTX:				// prevent binding those
			case SDL_GAMEPAD_AXIS_LEFTY:
			case SDL_GAMEPAD_AXIS_RIGHTX:
			case SDL_GAMEPAD_AXIS_RIGHTY:
				continue;
		}
#endif

		int16_t axisValue = SDL_GetGamepadAxis(controller, axis);
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

	if (doWiggle)
		TwitchSelectionNopeWiggle();

	return true;
}

static void AwaitMetaGamepadPress(void)
{
	int row = gNav->focusRow;
	int btnNo = gNav->focusComponent - 1;
	GAME_ASSERT(btnNo >= 0);
	GAME_ASSERT(btnNo < MAX_USER_BINDINGS_PER_NEED);

	// Wait for user to let go of confirm button before accepting a new button binding.
	if (IsNeedActive(kNeed_UIConfirm, ANY_PLAYER) && !IsNeedDown(kNeed_UIConfirm, ANY_PLAYER))
	{
		return;
	}

	bool anyGamepadFound = false;

	for (int i = 0; i < MAX_PLAYERS; i++)
	{
		SDL_Gamepad* gamepad = GetGamepad(i);
		if (gamepad)
		{
			anyGamepadFound = true;
			if (AwaitGamepadPress(gamepad))
			{
				return;
			}
		}
	}

	if (!anyGamepadFound)
	{
		gNav->menuState = kMenuStateReady;
		gNav->idleTime = 0;
		MakePbText(row, btnNo);	// update text after state changed back to Ready
		ReplaceMenuText(STR_CONFIGURE_GAMEPAD_HELP, STR_NO_GAMEPAD_DETECTED);
		TwitchSelectionNopeWiggle();
	}
}

static bool AwaitMouseClick(void)
{
	bool doWiggle = false;

	if (IsKeyDown(SDL_SCANCODE_ESCAPE)
		|| IsNeedDown(kNeed_UIConfirm, ANY_PLAYER)
		|| IsNeedDown(kNeed_UIBack, ANY_PLAYER))
	{
		doWiggle = true;
		goto updateText;
	}

	InputBinding* binding = GetBindingAtRow(gNav->focusRow);

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
	MakeMbText(gNav->focusRow);		// update text after state changed back to Ready
//	ReplaceMenuText(STR_CONFIGURE_MOUSE_HELP_CANCEL, STR_CONFIGURE_MOUSE_HELP);

	if (doWiggle)
		TwitchSelectionNopeWiggle();

	return true;
}

/****************************/
/*    PAGE LAYOUT           */
/****************************/
#pragma mark - General Page Layout

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

static ObjNode* MakeText(const char* text, int row, int chainItem, int textMeshFlags)
{
	ObjNode* chainHead = gNav->menuObjects[row];
	GAME_ASSERT(GetNodeChainLength(chainHead) >= chainItem);

	ObjNode* node = GetNthChainedNode(chainHead, chainItem, NULL);

	int fontAtlas = gNav->style.fontAtlas;
	if (textMeshFlags & kTextMeshUserFlag_AltFont)
		fontAtlas = gNav->style.fontAtlas2;

	if (node)
	{
		// Recycling existing text lets us keep the move call, color and specials.
		TextMesh_Update(text, textMeshFlags, node);

		// Restore max text width
		SetMaxTextWidth(node, GetMenuNodeData(node)->maxWidth);
	}
	else
	{
		NewObjectDefinitionType def =
		{
			.coord = (OGLPoint3D) { kDefaultX, gNav->menuRowYs[row], 0 },
			.scale = GetMenuItemHeight(row) * gNav->style.standardScale,
			.group = fontAtlas,
			.slot = gNav->style.textSlot + chainItem,  // chained node must be after their parent!
			.flags = STATUS_BIT_MOVEINPAUSE,
		};

		node = TextMesh_New(text, textMeshFlags, &def);

		SendNodeToOverlayPane(node);

		if (chainHead)
		{
			AppendNodeToChain(chainHead, node);
		}
		else
		{
			gNav->menuObjects[row] = node;
		}
	}

#if 0
	if (gNav->style.uniformXExtent)
	{
		if (-gNav->style.uniformXExtent < node->LeftOff)
			node->LeftOff = -gNav->style.uniformXExtent;
		if (gNav->style.uniformXExtent > node->RightOff)
			node->RightOff = gNav->style.uniformXExtent;
	}
#endif

	MenuNodeData* data = GetMenuNodeData(node);
	data->row = row;
	data->component = chainItem;

	// Fade in / side sweep
	if (gNav->sweepDelay >= 0)
	{
		Twitch* fadeEffect = MakeTwitch(node, kTwitchPreset_MenuFadeIn);
		if (fadeEffect)
		{
			fadeEffect->delay = gNav->sweepDelay * fadeEffect->duration;

			Twitch* displaceEffect = MakeTwitch(node, kTwitchPreset_MenuSweep | kTwitchFlags_Chain);
			if (displaceEffect)
			{
				displaceEffect->delay = fadeEffect->delay;
				displaceEffect->amplitude *= (gNav->sweepRTL ? 1 : -1);
				displaceEffect->amplitude *= (1.0 + displaceEffect->delay);
			}
		}
	}

	return node;
}

static void ReplaceMenuText(LocStrID originalTextInMenuDefinition, LocStrID newText)
{
	for (int i = 0; i < MAX_MENU_ROWS && gNav->menu[i].type != kMISENTINEL; i++)
	{
		if (gNav->menu[i].text == originalTextInMenuDefinition)
		{
			MakeText(Localize(newText), i, 0, kTextMeshSmallCaps);
		}
	}
}

static void LayOutMenu(int menuID)
{
	const MenuItem* menuStartSentinel = LookUpMenu(menuID);
	GAME_ASSERT(menuStartSentinel->id == menuID);
	GAME_ASSERT(menuStartSentinel->type == kMISENTINEL);

	if (!menuStartSentinel)
	{
		DoFatalAlert("Menu not registered: '%s'", FourccToString(menuID));
		return;
	}

	// Get first item in menu
	const MenuItem* menu = menuStartSentinel+1;

	// Remember we've been in this menu
	gNav->history[gNav->historyPos].menuID = menuID;

	gNav->menu				= menu;
	gNav->menuID			= menuID;
	gNav->menuPick			= -1;
	gNav->numRows			= 0;
	gNav->idleTime			= 0;
	gNav->validSaveSlotMask	= 0;

	DeleteAllText();

	// Count rows before calling any layout callbacks
	for (int row = 0; menu[row].type != kMISENTINEL; row++)
	{
		gNav->numRows++;
		GAME_ASSERT(gNav->numRows <= MAX_MENU_ROWS);
	}

	// Compute total height
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

	for (int row = 0; menu[row].type != kMISENTINEL; row++)
	{
		gNav->menuRowYs[row] = y;

		const MenuItem* entry = &menu[row];
		const MenuItemClass* cls = &kMenuItemClasses[entry->type];

		if (GetLayoutFlags(entry) & kMILayoutFlagHidden)
		{
			continue;
		}

		if (cls->layOutCallback)
		{
			ObjNode* node = cls->layOutCallback(row);

			// Make translucent if item disabled
			if (GetLayoutFlags(entry) & kMILayoutFlagDisabled)
			{
				for (ObjNode* chainNode = node; chainNode; chainNode = chainNode->ChainNode)
					GetMenuNodeData(chainNode)->muted = true;
			}
		}

		y += GetMenuItemHeight(row) * gNav->style.rowHeight;

		if (entry->type != kMISpacer)
		{
			gNav->sweepDelay += .2f;
		}
	}

	gNav->sweepDelay = 0.0f;

	// Restore old focus row from history
	gNav->focusRow = gNav->history[gNav->historyPos].row;

	// If there was no valid focus row in history, fall back to first interactable row
	if (gNav->focusRow <= 0
		|| !IsMenuItemSelectable(&gNav->menu[gNav->focusRow]))	// we had selected this item when we last were in this menu, but it's been disabled since then
	{
		// Scroll down to first pickable entry
		gNav->focusRow = -1;
		NavigateMenuVertically(1);
	}

	TwitchSelection();

	// Now that the contents of the menu have been laid out,
	// call start sentinel's callback, if any
	if (menuStartSentinel->callback)
	{
		menuStartSentinel->callback();
	}
}

void LayoutCurrentMenuAgain(bool animate)
{
	GAME_ASSERT(gNav);
	GAME_ASSERT(gNav->menu);

	gNav->sweepDelay = animate? 0: -100000;

	SaveSelectedRowInHistory();

	LayOutMenu(gNav->menuID);
}

#pragma mark - Menu registry

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

//			SDL_Log("Registered menu '%s'\n", FourccToString(menuItem->id));
		}
	}
}

static const MenuItem* LookUpMenu(int menuID)
{
	for (int i = 0; i < gNumMenusRegistered; i++)
	{
		if (gMenuRegistry[i]->id == menuID)
			return gMenuRegistry[i];
	}

	return NULL;
}

#pragma mark - Menu driver ObjNode

ObjNode* MakeMenu(const MenuItem* menu, const MenuStyle* style)
{
#if USE_SDL_CURSOR
	bool cursorStateBeforeMenu = SDL_CursorVisible();
	SDL_ShowCursor();
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
	gNav->focusRow			= -1;

	if (style)
		SDL_memcpy(&gNav->style, style, sizeof(*style));

	gNav->sweepDelay	= 0;
	gNav->sweepRTL		= false;

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
			else if (IsNeedDown(kNeed_UIBack, ANY_PLAYER) || IsNeedDown(kNeed_UIPause, ANY_PLAYER))
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
			RescaleDarkenPane(gNav->darkenPane, EPS);
			//gNav->darkenPane->MoveCall = nil;
			MakeTwitch(gNav->darkenPane, kTwitchPreset_MenuFadeOut | kTwitchFlags_KillPuppet);
			//MakeTwitch(gNav->darkenPane, kTwitchPreset_MenuDarkenPaneVanish | kTwitchFlags_Chain);
		}

		// Neutralize move calls in all rows and fade out
		for (int row = 0; row < MAX_MENU_ROWS; row++)
		{
			for (ObjNode* chainNode = gNav->menuObjects[row]; chainNode; chainNode = chainNode->ChainNode)
			{
				chainNode->MoveCall = nil;
				MakeTwitch(chainNode, kTwitchPreset_MenuFadeOut | kTwitchFlags_KillPuppet);
			}
		}

		SDL_memset(gNav->menuObjects, 0, sizeof(gNav->menuObjects));
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
	if (cursorStateBeforeMenu)
		SDL_ShowCursor();
	else
		SDL_HideCursor();
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
