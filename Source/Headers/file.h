//
// file.h
//

#pragma once

#include "input.h"

#define PREFS_FOLDER_NAME	"Nanosaur2"
#define PREFS_MAGIC			"Nanosaur2 Prefs v0"
#define PREFS_FILENAME		"Preferences"
#define SAVEGAME_MAGIC		"Nanosaur2 Save v0"


		/***********************/
		/* RESOURCE STURCTURES */
		/***********************/

			/* Hedr */

typedef struct
{
	int16_t	version;			// 0xaa.bb
	int16_t	numAnims;			// gNumAnims
	int16_t	numJoints;			// gNumJoints
	int16_t	num3DMFLimbs;		// gNumLimb3DMFLimbs
}SkeletonFile_Header_Type;

			/* Bone resource */
			//
			// matches BoneDefinitionType except missing
			// point and normals arrays which are stored in other resources.
			// Also missing other stuff since arent saved anyway.

typedef struct
{
	int32_t				parentBone;			 		// index to previous bone
	char				name[32];					// text string name for bone
	OGLPoint3D			coord;						// absolute coord (not relative to parent!)
	uint16_t			numPointsAttachedToBone;	// # vertices/points that this bone has
	uint16_t			numNormalsAttachedToBone;	// # vertex normals this bone has
	uint32_t			reserved[8];				// reserved for future use
}File_BoneDefinitionType;


			/* TERRAIN ITEM ENTRY TYPE */
			//
			// when we read this in, some additional data is calculated and store in the TerrainItemEntryType stuct
			//

typedef struct
{
	uint32_t						x,y;
	uint16_t						type;
	uint8_t							parm[4];
	uint16_t						flags;
}File_TerrainItemEntryType;



			/* AnHd */

typedef struct
{
	Str32	animName;
	short	numAnimEvents;
}SkeletonFile_AnimHeader_Type;



		/* PREFERENCES */

typedef struct
{
	Boolean	lowRenderQuality;
	Byte	language;

	Byte	displayNum;
	Boolean	fullscreen;
	Boolean	vsync;
	Byte	antialiasingLevel;
	Boolean	cutsceneSubtitles;

	Byte	splitScreenMode;
	Boolean	force4x3HUD;
	Byte	hudScale;

	Byte	stereoGlassesMode;
	Byte	anaglyphCalibrationRed;
	Byte	anaglyphCalibrationGreen;
	Byte	anaglyphCalibrationBlue;
	Boolean doAnaglyphChannelBalancing;

	Boolean	showTargetingCrosshairs;

	Boolean kiddieMode;

	Boolean	invertVerticalSteering;
	Byte	mouseSensitivityLevel;

	Byte	musicVolumePercent;
	Byte	sfxVolumePercent;

	Byte	rumbleIntensity;

	InputBinding	bindings[NUM_CONTROL_NEEDS];
}PrefsType;



		/* SAVE GAME */

// SaveGameType is now a native Swift struct (File.swift) - nothing in
// any .c file touches it (verified 2026-07-07: no extern globals, no
// static-inline functions, no C-side construction).




//=================================================

#define IsStereoAnaglyphColor() (gGamePrefs.stereoGlassesMode == STEREO_GLASSES_MODE_ANAGLYPH_COLOR)
#define IsStereoAnaglyphMono() (gGamePrefs.stereoGlassesMode == STEREO_GLASSES_MODE_ANAGLYPH_MONO)
#define IsStereoAnaglyph() (gGamePrefs.stereoGlassesMode == STEREO_GLASSES_MODE_ANAGLYPH_COLOR || gGamePrefs.stereoGlassesMode == STEREO_GLASSES_MODE_ANAGLYPH_MONO)
#define IsStereoShutter() (gGamePrefs.stereoGlassesMode == STEREO_GLASSES_MODE_SHUTTER)
#define IsStereo() (gGamePrefs.stereoGlassesMode != STEREO_GLASSES_MODE_OFF)

OSErr LoadPrefs(void);

