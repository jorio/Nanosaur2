//
// enemy.h
//

#pragma once

#include "terrain.h"
#include "splineitems.h"


#define	DEFAULT_ENEMY_COLLISION_CTYPES	(CTYPE_MISC|CTYPE_HURTENEMY|CTYPE_ENEMY|CTYPE_TRIGGER2|CTYPE_FENCE|CTYPE_SOLIDTOENEMY)
#define	DEATH_ENEMY_COLLISION_CTYPES	(CTYPE_FENCE)

#define ENEMY_GRAVITY		6500.0f
#define	ENEMY_SLOPE_ACCEL		3000.0f


#define	EnemyWaterRippleTimer	SpecialF[4]
#define	EnemyRegenerate			Flag[3]


		/* ENEMY KIND */

typedef enum SWIFT_ENUM_CLOSED EnemyKind
{
	ENEMY_KIND_RAPTOR SWIFT_NAME(raptor) = 0,
	ENEMY_KIND_BRACH SWIFT_NAME(brach),
	ENEMY_KIND_RAMPHOR SWIFT_NAME(ramphor),

	NUM_ENEMY_KINDS SWIFT_NAME(_count)
} EnemyKind;



//=====================================================================
//=====================================================================
//=====================================================================


			/* ENEMY */





		/* RAPTOR */




				/* BRACH */



		/* RAMPHOR */




