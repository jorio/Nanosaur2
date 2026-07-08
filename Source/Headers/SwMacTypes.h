//
// SwMacTypes.h
//
// Replaces extern/Pomme/src/PommeTypes.h + a handful of enum constants from
// PommeEnums.h, now that this project no longer depends on Pomme. Only the
// subset actually used anywhere in this codebase is kept - Pomme's own
// Sound Manager (SndChannel/SndCommand/SCStatus/SndListHandle/...) and
// QuickDraw (Picture/PixMap/GrafPort/Palette/ColorTable/...) type
// declarations were dropped entirely (confirmed zero references anywhere in
// Source/ before removing them - this project's own native replacements
// for the Sound Manager and rendering never used Pomme's versions of these
// types to begin with).
//
// FSSpec.cName is a plain NUL-terminated C string, not a Pascal string,
// despite the Str255 typedef - see feedback_pomme_str255_not_pascal memory.
//

#pragma once

#include <stdbool.h>
#include <stdint.h>

#define SW_NORETURN [[ noreturn ]]

//-----------------------------------------------------------------------------
// Integer types

typedef int8_t                          SignedByte;
typedef int8_t                          SInt8;
typedef int16_t                         SInt16;
typedef int32_t                         SInt32;
typedef int64_t                         SInt64;

typedef uint8_t                         Byte;
typedef uint8_t                         UInt8;
typedef uint8_t                         Boolean;
typedef uint16_t                        UInt16;
typedef uint32_t                        UInt32;
typedef uint64_t                        UInt64;

#if __BIG_ENDIAN__
typedef struct { UInt32 hi, lo; } UnsignedWide;
#else
typedef struct { UInt32 lo, hi; } UnsignedWide;
#endif

//-----------------------------------------------------------------------------
// Fixed/fract types

typedef SInt32                          Fixed;
typedef SInt32                          Fract;
typedef UInt32                          UnsignedFixed;
typedef SInt16                          ShortFixed;

//-----------------------------------------------------------------------------
// Basic system types

typedef SInt16                          OSErr;
typedef SInt32                          OSStatus;
typedef SInt32                          Duration;
typedef UnsignedWide                    AbsoluteTime;
typedef UInt32                          FourCharCode;
typedef FourCharCode                    OSType;
typedef FourCharCode                    ResType;
typedef char*                           Ptr;            // Pointer to a non-relocatable block
typedef Ptr*                            Handle;         // Pointer to a master pointer to a relocatable block
typedef long                            Size;           // Number of bytes in a block (signed for historical reasons)

//-----------------------------------------------------------------------------
// (Pascal-named, but NOT pascal-string) string types

typedef char                            Str15[16];
typedef char                            Str31[32];
typedef char                            Str32[33];
typedef char                            Str63[64];
typedef char                            Str255[256];
typedef char*                           StringPtr;
typedef const char*                     ConstStr255Param;

//-----------------------------------------------------------------------------
// Point & Rect types

typedef struct Point { SInt16 v, h; } Point;
typedef struct Rect { SInt16 top, left, bottom, right; } Rect;

//-----------------------------------------------------------------------------
// FSSpec

typedef struct FSSpec
{
	// Volume reference number of the volume containing the specified file or directory.
	short vRefNum;

	// Parent directory ID of the specified file or directory (the directory ID of the directory containing the given file or directory).
	long parID;

	// The name of the specified file or directory.
	// WARNING: this is a C string encoded as UTF-8, NOT a pascal string.
	Str255 cName;
} FSSpec;

//-----------------------------------------------------------------------------
// 'vers' resource

#if __BIG_ENDIAN__
//BCD encoded, e.g. "4.2.1a3" is 0x04214003
typedef struct NumVersion
{
	UInt8               majorRev;               // 1st part of version number in BCD
	UInt8               minorAndBugRev;         // 2nd & 3rd part of version number share a byte
	UInt8               stage;                  // stage code: dev, alpha, beta, final
	UInt8               nonRelRev;              // revision level of non-released version
} NumVersion;
#else
typedef struct NumVersion
{
	UInt8               nonRelRev;              // revision level of non-released version
	UInt8               stage;                  // stage code: dev, alpha, beta, final
	UInt8               minorAndBugRev;         // 2nd & 3rd part of version number share a byte
	UInt8               majorRev;               // 1st part of version number in BCD
} NumVersion;
#endif

//-----------------------------------------------------------------------------
// File-permission and folder-type constants (from Pomme's PommeEnums.h)

// Named (not anonymous) so it imports into Swift as an enum type with
// .rawValue, matching Pomme's original `enum EFSPermissions` - call sites
// use fsRdPerm.rawValue etc.
enum EFSPermissions
{
	fsCurPerm = 0,
	fsRdPerm = 1,
	fsWrPerm = 2,
	fsRdWrPerm = 3,
};

enum
{
	kPreferencesFolderType = 'pref',
};

enum
{
	kOnSystemDisk = -32768L,
};
