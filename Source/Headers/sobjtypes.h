//
// sobjtypes.h
//

// MAX_SPRITE_GROUPS sizes real extern-global arrays in Source/3D/Sprites.c
// (`gSpriteGroupList`/`gNumSpritesInGroupList`, also extern-declared in
// game.h); ATLAS_GROUP_FONT1/FONT2 are used directly in Source/System/Menu.c
// and Source/Screens/Settings.c. Both enum blocks below must stay
// C-visible. Every other enum that used to live in this file (all
// *_SObjType_* sprite indices, ~134 constants) had zero C usage (verified
// 2026-07-07) and moved to native Swift constants in
// Source/System/SObjTypes.swift.

enum
{
	ATLAS_GROUP_NULL				=	0,
	ATLAS_GROUP_FONT1				,
	ATLAS_GROUP_FONT2				,
	ATLAS_GROUP_FONT3				,
	MAX_ATLASES
};

enum
{
	SPRITE_GROUP_NULL				=	0,
	SPRITE_GROUP_SPHEREMAPS 		,
	SPRITE_GROUP_INFOBAR			,
	SPRITE_GROUP_CURSOR				,
	SPRITE_GROUP_PARTICLES			,
	SPRITE_GROUP_GLOBAL				,
	SPRITE_GROUP_LEVELSPECIFIC		,
	SPRITE_GROUP_OVERHEADMAP		,
	SPRITE_GROUP_P2SKIN				,
	MAX_SPRITE_GROUPS
};
