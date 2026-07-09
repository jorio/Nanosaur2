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

// EnemyKind is now a native Swift enum in GameEnums.swift - Enemy.c
// (its only real C user, via NUM_ENEMY_KINDS sizing gNumEnemyOfKind) was
// ported to Swift and deleted (verified 2026-07-07).



//=====================================================================
//=====================================================================
//=====================================================================


			/* ENEMY */





		/* RAPTOR */




				/* BRACH */



		/* RAMPHOR */




