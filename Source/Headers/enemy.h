//
// enemy.h
//

#include "terrain.h"
#include "splineitems.h"


#define	DEFAULT_ENEMY_COLLISION_CTYPES	(CTYPE_MISC|CTYPE_HURTENEMY|CTYPE_ENEMY|CTYPE_TRIGGER2|CTYPE_FENCE|CTYPE_SOLIDTOENEMY)
#define	DEATH_ENEMY_COLLISION_CTYPES	(CTYPE_FENCE)

#define ENEMY_GRAVITY		6500.0f
#define	ENEMY_SLOPE_ACCEL		3000.0f


#define	EnemyWaterRippleTimer	SpecialF[4]
#define	EnemyRegenerate			Flag[3]


		/* ENEMY KIND */

enum
{
	ENEMY_KIND_RAPTOR = 0,
	ENEMY_KIND_BRACH,
	ENEMY_KIND_RAMPHOR,

	NUM_ENEMY_KINDS
};



//=====================================================================
//=====================================================================
//=====================================================================


			/* ENEMY */

ObjNode *MakeEnemySkeleton(Byte skeletonType, short animNum, float x, float z, float scale, float rot, void *moveCall);
extern	void DeleteEnemy(ObjNode *theEnemy);
Boolean DoEnemyCollisionDetect(ObjNode *theEnemy, unsigned long ctype, Boolean useBBoxBottom);
void EnemyTouchedPlayer(ObjNode *enemy, ObjNode *player);
extern	void UpdateEnemy(ObjNode *theNode);
extern	void InitEnemyManager(void);
void DetachEnemyFromSpline(ObjNode *theNode, void *moveCall);
ObjNode *FindClosestEnemy(OGLPoint3D *pt, float *dist);
Boolean	IsWaterInFrontOfEnemy(float r);
void MoveEnemySkipChunk(ObjNode *chunk);




		/* RAPTOR */

Boolean AddEnemy_Raptor(TerrainItemEntryType *itemPtr, float x, float z);
Boolean PrimeEnemy_Raptor(long splineNum, SplineItemType *itemPtr);



				/* BRACH */

Boolean AddEnemy_Brach(TerrainItemEntryType *itemPtr, float x, float z);
Boolean PrimeEnemy_Brach(long splineNum, SplineItemType *itemPtr);


		/* RAMPHOR */

Boolean PrimeEnemy_Ramphor(long splineNum, SplineItemType *itemPtr);



