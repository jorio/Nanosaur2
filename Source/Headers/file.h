//
// file.h
//

#pragma once

#include "input.h"

		/* POSIX I/O for FileSystem.swift's native file I/O */
		//
		// Hand-declared instead of #include <fcntl.h>/<unistd.h>/<sys/stat.h>/
		// <time.h>: those headers belong to the SDK's "Darwin" Clang module,
		// and pulling in any part of that module from the bridging header
		// (which Swift's ClangImporter always validates using real Clang
		// modules, even for a textual -import-objc-header) forces validation
		// of the WHOLE Darwin module - including its own MacTypes.h, whose
		// Point/Rect/Boolean/FSSpec definitions collide with this project's
		// own (see Source/Headers/SwMacTypes.h - same root cause as the
		// SwiftPM migration's CoreServices blocker). The symbols themselves
		// are already linked in via libSystem, so a bare prototype is enough.
extern int open(const char* path, int flags, ...); // variadic - unusable from Swift directly, see SwOpen below
extern long read(int fd, void* buf, unsigned long count);
extern long write(int fd, const void* buf, unsigned long count);
extern int close(int fd);
extern long long lseek(int fd, long long offset, int whence);
extern int mkdir(const char* path, unsigned short mode);
extern int unlink(const char* path);
extern int access(const char* path, int mode);
extern long time(long* tloc); // time_t is a typedef for a signed integer; long matches its size on this platform

// Swift can't call variadic C functions - this non-variadic wrapper always
// passes a mode (harmless when SwO_CREAT isn't set, since it's ignored).
static inline int SwOpen(const char* path, int flags, unsigned short mode) { return open(path, flags, mode); }

#define SwO_RDONLY   0x0000
#define SwO_RDWR     0x0002
#define SwO_CREAT    0x0200
#define SwSEEK_SET   0
#define SwSEEK_CUR   1
#define SwSEEK_END   2
#define SwF_OK       0

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

		/* NATIVE FILE I/O (FileSystem.swift) */
		//
		// Replaces Pomme's FSMakeFSSpec/FSpOpenDF/FSRead/FSWrite/FSClose/
		// GetEOF/FSpDelete/FindFolder/DirCreate (Files/HostVolume Mac-toolbox
		// emulation). SwHostPathToFSSpec is called once at boot (Boot.cpp) to
		// build gDataSpec from a real host path; everything else mirrors the
		// Pomme functions it replaces so callers only need a Sw-prefixed
		// rename.

FSSpec SwHostPathToFSSpec(const char* cFullPath);
OSErr SwFSMakeFSSpec(short vRefNum, long parID, const char* cstrFileName, FSSpec* spec);
OSErr SwFSpOpenDF(const FSSpec* spec, char permission, short* refNum);
OSErr SwFSRead(short refNum, long* count, Ptr buffPtr);
OSErr SwFSWrite(short refNum, long* count, Ptr buffPtr);
OSErr SwFSClose(short refNum);
OSErr SwGetEOF(short refNum, long* logEOF);
OSErr SwFSpDelete(const FSSpec* spec);
OSErr SwFindFolder(short vRefNum, OSType folderType, char createFolder, short* foundVRefNum, long* foundDirID);
OSErr SwDirCreate(short vRefNum, long parentDirID, const char* cstrDirectoryName, long* createdDirID);

// creator/fileType/scriptTag are ignored (classic Mac creator-code metadata,
// meaningless on a modern filesystem) - just creates an empty file.
OSErr SwFSpCreate(const FSSpec* spec, OSType creator, OSType fileType, short scriptTag);

