#pragma once

#include "localization.h"

#define MAX_MENU_CYCLER_CHOICES		8

typedef enum SWIFT_ENUM_CLOSED MenuItemType
{
	kMISENTINEL SWIFT_NAME(sentinel),
	kMIPick SWIFT_NAME(pick),
	kMILabel SWIFT_NAME(label),
	kMISpacer SWIFT_NAME(spacer),
	kMICycler1 SWIFT_NAME(cycler1),
	kMICycler2 SWIFT_NAME(cycler2),
	kMISlider SWIFT_NAME(slider),
	kMIKeyBinding SWIFT_NAME(keyBinding),
	kMIPadBinding SWIFT_NAME(padBinding),
	kMIMouseBinding SWIFT_NAME(mouseBinding),
	kMIFileSlot SWIFT_NAME(fileSlot),
	kMI_COUNT SWIFT_NAME(_count)
} MenuItemType;

typedef struct
{
	Byte*			valuePtr;

	bool			isDynamicallyGenerated;

	union
	{
		struct
		{
			LocStrID	text;
			uint8_t		value;
		} choices[MAX_MENU_CYCLER_CHOICES];

		struct
		{
			int				(* _Nullable generateNumChoices)(void);
			const char*		(* _Nullable generateChoiceString)(Byte value);
		} generator;
	};
} MenuCyclerData;

typedef struct
{
	Byte*			valuePtr;
	Byte			equilibrium;
	Byte			minValue;
	Byte			maxValue;
	Byte			increment;
	bool			continuousCallback;
} MenuSliderData;

typedef struct MenuItem
{
	MenuItemType			type;
	LocStrID				text;
	const char*				_Nullable rawText;
	int32_t					id;			// value stored in gMenuOutcome when exiting menu
	int32_t					next;		// next menu, or one of 'EXIT', 'BACK' or 0 (no-op)

	void					(* _Nullable callback)(void);
	int						(* _Nullable getLayoutFlags)(const struct MenuItem* mi);

	union
	{
		int 					inputNeed;
		int						fileSlot;
		MenuCyclerData			cycler;
		MenuSliderData			slider;
	};

	float					customHeight;
} MenuItem;

enum	// Returned by getLayoutFlags
{
	kMILayoutFlagDisabled = 1 << 0,
	kMILayoutFlagHidden = 1 << 1,
};

typedef struct MenuStyle
{
	float			darkenPaneOpacity;
	float			fadeInSpeed;		// Menu will ignore input during 1.0/fadeInSpeed seconds after booting
	float			fadeOutSpeed;
	float			standardScale;
	float			rowHeight;
	short			textSlot;
	float			yOffset;
	int				fontAtlas;
	int				fontAtlas2;

	OGLColorRGBA	labelColor;
	OGLColorRGBA	idleColor;
	OGLColorRGBA	highlightColor;
	OGLColorRGBA	arrowColor;
	struct
	{
		bool			asyncFadeOut : 1;
		bool			fadeOutSceneOnExit : 1;
		bool			startButtonExits : 1;
		bool			isInteractive : 1;
		bool			canBackOutOfRootMenu : 1;
	};

	void			(* _Nullable exitCall)(int);
} MenuStyle;

extern const MenuStyle kDefaultMenuStyle;

void RegisterMenu(const MenuItem* _Nonnull menus);

ObjNode* _Nonnull MakeMenu(const MenuItem* _Nonnull menu, const MenuStyle* _Nullable style);

void LayoutCurrentMenuAgain(bool animate);
int GetCurrentMenu(void);
int GetCurrentMenuItemID(void);
bool IsMenuMouseControlled(void);
ObjNode* _Nullable GetCurrentMenuItemObject(void);
float GetMenuIdleTime(void);
void KillMenu(int returnCode);
bool IsMenuTreeEndSentinel(const MenuItem* _Nonnull menuItem);
int DisableEmptyFileSlots(const MenuItem* _Nonnull menuItem);
