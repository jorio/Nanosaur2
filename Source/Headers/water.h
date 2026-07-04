//
// water.h
//

#pragma once

#define	MAX_WATER_POINTS	100			// note:  cannot change this without breaking data files!!

enum
{
	WATER_FLAG_FIXEDHEIGHT	= (1)
};

// WaterType is now a plain Swift enum in GameEnums.swift - nothing in C touches it, so it's no longer declared here.


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


	/* RIPPLE */

