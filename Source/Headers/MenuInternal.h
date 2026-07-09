#pragma once

#include "menu.h"
#include "uieffects.h"
#include "input.h"

// Internal types for the menu system - exposed to Swift via bridging header

#define MAX_MENU_ROWS			25
#define MAX_STACK_LENGTH		16
#define MAX_REGISTERED_MENUS	32

typedef enum SWIFT_ENUM_CLOSED MenuState
{
	kMenuStateOff SWIFT_NAME(off),
	kMenuStateFadeIn SWIFT_NAME(fadeIn),
	kMenuStateReady SWIFT_NAME(ready),
	kMenuStateFadeOut SWIFT_NAME(fadeOut),
	kMenuStateAwaitingKeyPress SWIFT_NAME(awaitingKeyPress),
	kMenuStateAwaitingPadPress SWIFT_NAME(awaitingPadPress),
	kMenuStateAwaitingMouseClick SWIFT_NAME(awaitingMouseClick),
} MenuState;

typedef enum SWIFT_ENUM_CLOSED MouseState
{
	kMouseOff SWIFT_NAME(off),
	kMouseWandering SWIFT_NAME(wandering),
	kMouseHovering SWIFT_NAME(hovering),
	kMouseGrabbing SWIFT_NAME(grabbing),
} MouseState;

typedef struct
{
	Boolean		muted;
	Byte		row;
	Byte		component;
	float		pulsateTimer;
	float		maxWidth;
} MenuNodeData;

_Static_assert(sizeof(MenuNodeData) <= MAX_SPECIAL_DATA_BYTES, "MenuNodeData doesn't fit in special area");

// MenuNodeData lives in the ObjNode's SpecialPadding scratch area (mirrors
// the GetMenuNodeData macro from the original Menu.c). Swift needs this C
// shim because SpecialPadding is a union member, and Swift's pointer(to:)
// returns nil at runtime for union members.
static inline MenuNodeData* _Nonnull GetMenuNodeDataPtr(ObjNode* _Nonnull node) { return (MenuNodeData*) node->SpecialPadding; }

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

typedef struct
{
	int menuID;
	int row;
} MenuHistoryEntry;

typedef struct
{
	int					menuID;
	const MenuItem*	_Nullable menu;
	MenuStyle			style;

	int					numRows;

	int					focusRow;
	int					focusComponent;

	float				menuRowYs[MAX_MENU_ROWS];
	float				menuFadeAlpha;
	MenuState			menuState;
	int					menuPick;
	ObjNode*	_Nullable	menuObjects[MAX_MENU_ROWS];

	MenuHistoryEntry	history[MAX_STACK_LENGTH];
	int					historyPos;

	MouseState			mouseState;
	int					mouseFocusComponent;

	float				idleTime;

	ObjNode*	_Nullable	arrowObjects[2];
	ObjNode*	_Nullable	darkenPane;

	float				sweepDelay;
	bool				sweepRTL;

	uint64_t			validSaveSlotMask;
} MenuNavigation;

// ---- Swift-compatible inline wrappers for C macros ----

static inline void SwFatal(const char* msg) { DoFatalAlert("%s", msg); }
static inline void SwFatal2(const char* a, const char* b) { DoFatalAlert("%s: %s", a, b); }

static inline bool SwIsKeyDown(long sc) { return GetKeyState((uint16_t)sc) == KEYSTATE_DOWN; }
static inline bool SwIsKeyHeld(long sc) { return GetKeyState((uint16_t)sc) == KEYSTATE_HELD; }
static inline bool SwIsKeyUp(long sc) { return GetKeyState((uint16_t)sc) == KEYSTATE_UP; }
static inline bool SwIsClickDown(long btn) { return GetClickState((int)btn) == KEYSTATE_DOWN; }
static inline bool SwIsClickHeld(long btn) { return GetClickState((int)btn) == KEYSTATE_HELD; }
static inline bool SwIsClickUp(long btn) { return GetClickState((int)btn) == KEYSTATE_UP; }
static inline bool SwIsNeedDown(long need, long player) { return GetNeedState((int)need, (int)player) == KEYSTATE_DOWN; }
static inline bool SwIsNeedHeld(long need, long player) { return GetNeedState((int)need, (int)player) == KEYSTATE_HELD; }
static inline bool SwIsNeedActive(long need, long player) { return (KEYSTATE_ACTIVE_BIT & GetNeedState((int)need, (int)player)) != 0; }
static inline bool SwIsNeedUp(long need, long player) { return GetNeedState((int)need, (int)player) == KEYSTATE_UP; }

static inline void SwGameAssert(bool cond) { if (!cond) DoFatalAlert("GAME_ASSERT failed"); }
static inline float SwGameClampF(float x, float lo, float hi) { return x < lo ? lo : (x > hi ? hi : x); }
static inline int SwGameClampI(int x, int lo, int hi) { return x < lo ? lo : (x > hi ? hi : x); }

// arrowObjects tuple accessor
static inline ObjNode* _Nullable Nav_GetArrow(MenuNavigation* nav, int i) { return nav->arrowObjects[i]; }
static inline void Nav_SetArrow(MenuNavigation* nav, int i, ObjNode* _Nullable v) { nav->arrowObjects[i] = v; }

// ---- Array accessors (Swift imports fixed-size C arrays as tuples) ----

static inline ObjNode* _Nullable Nav_GetMenuObject(MenuNavigation* nav, int i) { return nav->menuObjects[i]; }
static inline void Nav_SetMenuObject(MenuNavigation* nav, int i, ObjNode* _Nullable v) { nav->menuObjects[i] = v; }
static inline float Nav_GetMenuRowY(MenuNavigation* nav, int i) { return nav->menuRowYs[i]; }
static inline void Nav_SetMenuRowY(MenuNavigation* nav, int i, float v) { nav->menuRowYs[i] = v; }
static inline int Nav_GetHistoryMenuID(MenuNavigation* nav, int i) { return nav->history[i].menuID; }
static inline void Nav_SetHistoryMenuID(MenuNavigation* nav, int i, int v) { nav->history[i].menuID = v; }
static inline int Nav_GetHistoryRow(MenuNavigation* nav, int i) { return nav->history[i].row; }
static inline void Nav_SetHistoryRow(MenuNavigation* nav, int i, int v) { nav->history[i].row = v; }

// ---- Anonymous union accessors for MenuItem ----

static inline Byte* _Nullable MenuItem_GetCyclerValuePtr(const MenuItem* mi) { return mi->cycler.valuePtr; }
static inline bool MenuItem_GetCyclerDynamic(const MenuItem* mi) { return mi->cycler.isDynamicallyGenerated; }
static inline LocStrID MenuItem_GetCyclerChoiceText(const MenuItem* mi, int i) { return mi->cycler.choices[i].text; }
static inline uint8_t MenuItem_GetCyclerChoiceValue(const MenuItem* mi, int i) { return mi->cycler.choices[i].value; }
static inline int (* _Nullable MenuItem_GetGenNumChoices(const MenuItem* mi))(void) { return mi->cycler.generator.generateNumChoices; }
static inline const char* (* _Nullable MenuItem_GetGenChoiceString(const MenuItem* mi))(Byte) { return mi->cycler.generator.generateChoiceString; }

// ---- Setters for MenuCyclerData's anonymous union (Swift can't address these by name) ----

static inline void MenuCyclerData_SetChoiceText(MenuCyclerData* c, int i, LocStrID text) { c->choices[i].text = text; }
static inline void MenuCyclerData_SetChoiceValue(MenuCyclerData* c, int i, uint8_t value) { c->choices[i].value = value; }
static inline void MenuCyclerData_SetGeneratorNumChoices(MenuCyclerData* c, int (* _Nullable fn)(void)) { c->generator.generateNumChoices = fn; }
static inline void MenuCyclerData_SetGeneratorChoiceString(MenuCyclerData* c, const char* _Nonnull (* _Nullable fn)(Byte)) { c->generator.generateChoiceString = fn; }

static inline Byte* _Nullable MenuItem_GetSliderValuePtr(const MenuItem* mi) { return mi->slider.valuePtr; }
static inline Byte MenuItem_GetSliderEquilibrium(const MenuItem* mi) { return mi->slider.equilibrium; }
static inline Byte MenuItem_GetSliderMin(const MenuItem* mi) { return mi->slider.minValue; }
static inline Byte MenuItem_GetSliderMax(const MenuItem* mi) { return mi->slider.maxValue; }
static inline Byte MenuItem_GetSliderIncrement(const MenuItem* mi) { return mi->slider.increment; }
static inline bool MenuItem_GetSliderContinuous(const MenuItem* mi) { return mi->slider.continuousCallback; }

static inline int MenuItem_GetInputNeed(const MenuItem* mi) { return mi->inputNeed; }
static inline int MenuItem_GetFileSlot(const MenuItem* mi) { return mi->fileSlot; }

// ---- Anonymous struct accessors for MenuStyle bitfields ----

static inline bool MenuStyle_GetAsyncFadeOut(const MenuStyle* s) { return s->asyncFadeOut; }
static inline bool MenuStyle_GetFadeOutSceneOnExit(const MenuStyle* s) { return s->fadeOutSceneOnExit; }
static inline bool MenuStyle_GetStartButtonExits(const MenuStyle* s) { return s->startButtonExits; }
static inline bool MenuStyle_GetIsInteractive(const MenuStyle* s) { return s->isInteractive; }
static inline bool MenuStyle_GetCanBackOutOfRootMenu(const MenuStyle* s) { return s->canBackOutOfRootMenu; }

// ---- InputBinding indexed accessors (Swift imports fixed-size C arrays as tuples) ----

static inline int16_t InputBinding_GetKey(const InputBinding* b, int i) { return b->key[i]; }
static inline void InputBinding_SetKey(InputBinding* b, int i, int16_t v) { b->key[i] = v; }
static inline int8_t InputBinding_GetPadType(const InputBinding* b, int i) { return b->pad[i].type; }
static inline int8_t InputBinding_GetPadID(const InputBinding* b, int i) { return b->pad[i].id; }
static inline void InputBinding_SetPad(InputBinding* b, int i, int8_t type, int8_t id) { b->pad[i].type = type; b->pad[i].id = id; }

// Compound status-bit macro (Clang's macro-constant importer can't fold an OR of enum constants)
static const int32_t SwStatusBitsFor2D = STATUS_BITS_FOR_2D;
