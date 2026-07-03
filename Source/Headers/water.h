//
// water.h
//

#pragma once

#define	MAX_WATER_POINTS	100			// note:  cannot change this without breaking data files!!

enum
{
	WATER_FLAG_FIXEDHEIGHT	= (1)
};

typedef enum SWIFT_ENUM_CLOSED WaterType
{
	WATER_TYPE_GREEN SWIFT_NAME(green) = 0,
	WATER_TYPE_BLUE SWIFT_NAME(blue),
	WATER_TYPE_LAVA SWIFT_NAME(lava),
	WATER_TYPE_LAVA_DIR0 SWIFT_NAME(lavaDir0),
	WATER_TYPE_LAVA_DIR1 SWIFT_NAME(lavaDir1),
	WATER_TYPE_LAVA_DIR2 SWIFT_NAME(lavaDir2),
	WATER_TYPE_LAVA_DIR3 SWIFT_NAME(lavaDir3),
	WATER_TYPE_LAVA_DIR4 SWIFT_NAME(lavaDir4),
	WATER_TYPE_LAVA_DIR5 SWIFT_NAME(lavaDir5),
	WATER_TYPE_LAVA_DIR6 SWIFT_NAME(lavaDir6),
	WATER_TYPE_LAVA_DIR7 SWIFT_NAME(lavaDir7),

	NUM_WATER_TYPES SWIFT_NAME(_count)
} WaterType;


typedef struct		// NOTE: MUST MATCH OREOTERRAIN DATA!!!
{
	uint16_t		type;							// type of water
	uint32_t		flags;							// flags
	int32_t			height;							// height offset or hard-wired index
	int16_t			numNubs;						// # nubs in water
	int32_t			reserved;						// for future use
	OGLPoint2D		nubList[MAX_WATER_POINTS];		// nub list

	float			hotSpotX,hotSpotZ;				// hot spot coords
	Rect			bBox;							// bounding box of water area
}WaterDefType;


//============================================

void PrimeTerrainWater(void);
void DisposeWater(void);
Boolean DoWaterCollisionDetect(ObjNode * _Nonnull theNode, float x, float y, float z, int * _Nullable patchNum);
Boolean IsXZOverWater(float x, float z);
Boolean GetWaterY(float x, float z, float * _Nonnull y);

	/* RIPPLE */

void CreateNewRipple(const OGLPoint3D * _Nonnull where, float baseScale, float scaleSpeed, float fadeRate);
void CreateMultipleNewRipples(float x, float z, float baseScale, float scaleSpeed, float fadeRate, short numRipples);
