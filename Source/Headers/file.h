//
// file.h
//

#pragma once

#include "input.h"

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

#define	MAX_HTTP_NOTES	1000

#define	CURRENT_PREFS_VERS	0x0300

typedef struct
{
	Boolean	showScreenModeDialog;
	short	depth;
	int		screenWidth;
	int		screenHeight;
	double	hz;
	Boolean	lowRenderQuality;
	Byte	language;
//	DateTimeRec	lastVersCheckDate;
	Byte	didThisNote[MAX_HTTP_NOTES];
	Boolean	hasConfiguredISpControls;

	HIDControlSettingsType	controlSettings;

	Byte	splitScreenMode;

	Byte	stereoGlassesMode;
	Boolean	anaglyphColor;
	short	anaglyphCalibrationRed;
	short	anaglyphCalibrationGreen;
	short	anaglyphCalibrationBlue;
	Boolean doAnaglyphChannelBalancing;

	Boolean	showTargetingCrosshairs;

	uint32_t	version;

	Boolean kiddieMode;
	Boolean dontUseHID;

	Byte	antialiasingLevel;

	int		reserved[8];
}PrefsType;



//=================================================

SkeletonDefType *LoadSkeletonFile(short skeletonType, OGLSetupOutputType *setupInfo);
extern	OSErr LoadPrefs(PrefsType *prefBlock);
void SavePrefs(void);

void LoadPlayfield(FSSpec *specPtr, OGLSetupOutputType *setupInfo);
OSErr DrawPictureIntoGWorld(FSSpec *myFSSpec, GWorldPtr *theGWorld, short depth);
void GetDemoTimer(void);
void SaveDemoTimer(void);
void SetDefaultDirectory(void);

Boolean SaveGame(void);
Boolean LoadSavedGame(void);


void DecompressJPEGToGWorld(ImageDescriptionHandle imageDesc, Ptr compressedData, GWorldPtr gworld, Rect *srcRect);

void LoadLevelArt(OGLSetupOutputType *setupInfo);


Ptr LoadDataFile(const char* path, long* outLength);
char* LoadTextFile(const char* path, long* outLength);

char* CSVIterator(char** csvCursor, bool* eolOut);
