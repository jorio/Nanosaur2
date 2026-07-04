//
// Skeleton.h
//

#ifndef __SKELOBJ
#define __SKELOBJ

#include "structs.h"

typedef enum SWIFT_ENUM_CLOSED SkeletonType
{
	SKELETON_TYPE_PLAYER SWIFT_NAME(player) = 0,
	SKELETON_TYPE_WORMHOLE SWIFT_NAME(wormhole),
	SKELETON_TYPE_RAPTOR SWIFT_NAME(raptor),
	SKELETON_TYPE_BONUSWORMHOLE SWIFT_NAME(bonusWormhole),
	SKELETON_TYPE_BRACH SWIFT_NAME(brach),
	SKELETON_TYPE_WORM SWIFT_NAME(worm),
	SKELETON_TYPE_RAMPHOR SWIFT_NAME(ramphor),

	MAX_SKELETON_TYPES SWIFT_NAME(_count)
} SkeletonType;


		/* ANIM EVENTS */

#define	MAX_ANIM_EVENTS		30

#define	MAX_ANIMEVENT_TYPES	7

// AnimDirection is now a plain Swift enum in GameEnums.swift - nothing in C touches it, so it's no longer declared here.


// AnimEventKind is now a plain Swift enum in GameEnums.swift - nothing in C touches it, so it's no longer declared here.

		/* ACCELERATION MODES */
// AccelerationMode is now a plain Swift enum in GameEnums.swift - nothing in C touches it, so it's no longer declared here.


#define	NUM_ACCELERATION_CURVE_NUBS		23						// THESE MUST MATCH BIO-OREO'S NUMBERS!!!
#define	SPLINE_POINTS_PER_NUB			100
#define CURVE_SIZE						((NUM_ACCELERATION_CURVE_NUBS-3)*SPLINE_POINTS_PER_NUB)



#define	NO_PREVIOUS_JOINT	(-1)

extern  float	gAccelerationCurve[CURVE_SIZE];
static inline float* GetAccelerationCurvePtr(void) { return gAccelerationCurve; }


//===============================











#endif