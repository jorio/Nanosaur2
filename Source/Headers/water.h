//
// water.h
//

#ifndef WATER_H
#define WATER_H

#define	MAX_WATER_POINTS	100			// note:  cannot change this without breaking data files!!

enum
{
	WATER_FLAG_FIXEDHEIGHT	= (1)
};

enum
{
	WATER_TYPE_GREEN = 0,
	WATER_TYPE_BLUE,
	WATER_TYPE_LAVA,
	WATER_TYPE_LAVA_DIR0,
	WATER_TYPE_LAVA_DIR1,
	WATER_TYPE_LAVA_DIR2,
	WATER_TYPE_LAVA_DIR3,
	WATER_TYPE_LAVA_DIR4,
	WATER_TYPE_LAVA_DIR5,
	WATER_TYPE_LAVA_DIR6,
	WATER_TYPE_LAVA_DIR7,

	NUM_WATER_TYPES
};


typedef struct		// NOTE: MUST MATCH OREOTERRAIN DATA!!!
{
	u_short			type;							// type of water
	u_long			flags;							// flags
	long			height;							// height offset or hard-wired index
	short			numNubs;						// # nubs in water
	long			reserved;						// for future use
	OGLPoint2D		nubList[MAX_WATER_POINTS];		// nub list

	float			hotSpotX,hotSpotZ;				// hot spot coords
	Rect			bBox;							// bounding box of water area
}WaterDefType;


		/* EXTERN */

extern	long				gNumWaterPatches;
extern	WaterDefType		*gWaterList;
extern	MOVertexArrayData	gWaterTriMeshData[];
extern	OGLBoundingBox		gWaterBBox[];

//============================================

void PrimeTerrainWater(void);
void DisposeWater(void);
Boolean DoWaterCollisionDetect(ObjNode *theNode, float x, float y, float z, int *patchNum);
Boolean IsXZOverWater(float x, float z);
Boolean GetWaterY(float x, float z, float *y);

	/* RIPPLE */

void CreateNewRipple(const OGLPoint3D *where, float baseScale, float scaleSpeed, float fadeRate);
void CreateMultipleNewRipples(float x, float z, float baseScale, float scaleSpeed, float fadeRate, short numRipples);

#endif


