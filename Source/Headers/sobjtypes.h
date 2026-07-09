//
// sobjtypes.h
//

// ATLAS_GROUP_FONT1/FONT2 are used directly in Source/System/Menu.c
// (kDefaultMenuStyle's compound literal), so that enum block must stay
// C-visible. SPRITE_GROUP_*/MAX_SPRITE_GROUPS is no longer C-referenced
// (Sprites.c, its only real C user, was ported to Swift and deleted
// 2026-07-07) but is left as a plain C enum since it's harmless and
// already usable directly from Swift as bare Int32 constants. Every other
// enum that used to live in this file (all *_SObjType_* sprite indices,
// ~134 constants) had zero C usage (verified 2026-07-07) and moved to
// native Swift constants in Source/System/SObjTypes.swift.

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
