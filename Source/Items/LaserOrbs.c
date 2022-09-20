/****************************/
/*   	LASER ORBS.C	    */
/* (c)2004 Pangea Software  */
/* By Brian Greenstone      */
/****************************/


/****************************/
/*    EXTERNALS             */
/****************************/


#include "game.h"

extern	float				gFramesPerSecondFrac,gFramesPerSecond,gTerrainPolygonSize;
extern	OGLPoint3D			gCoord;
extern	OGLVector3D			gDelta;
extern	NewObjectDefinitionType	gNewObjectDefinition;
extern	OGLBoundingBox 		gObjectGroupBBoxList[MAX_BG3D_GROUPS][MAX_OBJECTS_IN_GROUP];
extern	OGLSetupOutputType	*gGameViewInfoPtr;
extern	u_long				gAutoFadeStatusBits,gGlobalMaterialFlags;
extern	SparkleType	gSparkles[MAX_SPARKLES];
extern	short				gNumEnemies;
extern	SpriteType	*gSpriteGroupList[];
extern	AGLContext		gAGLContext;
extern	Byte				gCurrentSplitScreenPane;


/****************************/
/*    PROTOTYPES            */
/****************************/

static ObjNode *MakeLaserOrb(float  x, float z);
static void MoveLaserOrb(ObjNode *theNode);
static void MoveLaserOrbOnSpline(ObjNode *theNode);
static Boolean LaserOrbHitByWeaponCallback(ObjNode *bullet, ObjNode *theNode, OGLPoint3D *hitCoord, OGLVector3D *hitTriangleNormal);
static void ExplodeLaserOrb(ObjNode *theNode);
static void DrawOrbLaserBeam(ObjNode *beam, const OGLSetupOutputType *setupInfo);
static Boolean CalcLaserVectorToPlayer(ObjNode *orb, short p);
static void UpdateLaserOrbSparkles(ObjNode *orb);


/****************************/
/*    CONSTANTS             */
/****************************/

#define	LASER_ORB_SCALE	4.0f

#define	LASER_ORB_SHOOT_DIST	3700.0f

#define	LASER_DAMAGE		.15		 // per second of exposure

enum
{
	ORB_MODE_SEEKING,
	ORB_MODE_SHOOTING
};

#define	LASER_BEAM_SIZE	20.0f


#define	ORB_RING_YOFF		(LASER_ORB_SCALE * 67.0f)
#define	ORB_RING_DIAMETER	(LASER_ORB_SCALE * 21.0f)


/*********************/
/*    VARIABLES      */
/*********************/

#define	LaserDistance	SpecialF[0]


/************************* ADD LASER ORB *********************************/

Boolean AddLaserOrb(TerrainItemEntryType *itemPtr, float  x, float z)
{
ObjNode	*newObj;

	if (gGamePrefs.kiddieMode)						// dont add these in kiddie mode
		return(false);

	newObj = MakeLaserOrb(x,z);

	newObj->TerrainItemPtr = itemPtr;								// keep ptr to item list
	newObj->MoveCall = MoveLaserOrb;

	return(true);													// item was added
}


/************************* MAKE LASER ORB *********************************/

static ObjNode *MakeLaserOrb(float  x, float z)
{
ObjNode	*newObj, *green, *laser;

				/*************/
				/* MAKE BODY */
				/*************/

	gNewObjectDefinition.group 		= MODEL_GROUP_GLOBAL;
	gNewObjectDefinition.type 		= GLOBAL_ObjType_LaserOrb;
	gNewObjectDefinition.scale 		= LASER_ORB_SCALE;
	gNewObjectDefinition.coord.x 	= x;
	gNewObjectDefinition.coord.z 	= z;
	gNewObjectDefinition.coord.y 	= GetTerrainY(x,z);
	gNewObjectDefinition.flags 		= gAutoFadeStatusBits;
	gNewObjectDefinition.slot 		= SLOT_OF_DUMB-2;
	gNewObjectDefinition.moveCall 	= nil;
	gNewObjectDefinition.rot 		= RandomFloat() * PI2;
	newObj = MakeNewDisplayGroupObject(&gNewObjectDefinition);

	newObj->Health 	= .4f;
	newObj->Mode	= ORB_MODE_SEEKING;

			/* SET COLLISION STUFF */

	newObj->CType 				= CTYPE_MISC | CTYPE_WEAPONTEST | CTYPE_PLAYERTEST | CTYPE_AUTOTARGETWEAPON;
	newObj->CBits				= CBITS_ALLSOLID;
	CreateCollisionBoxFromBoundingBox(newObj, 1, 1);

	newObj->HitByWeaponHandler 	= LaserOrbHitByWeaponCallback;

	newObj->HeatSeekHotSpotOff.x = 0;
	newObj->HeatSeekHotSpotOff.y = 40.0f;
	newObj->HeatSeekHotSpotOff.z = 0;


			/********************/
			/* MAKE GREEN THING */
			/********************/

	gNewObjectDefinition.type 		= GLOBAL_ObjType_LaserOrbGreen;
	gNewObjectDefinition.flags 		= gAutoFadeStatusBits | STATUS_BIT_UVTRANSFORM;
	gNewObjectDefinition.slot++;
	green = MakeNewDisplayGroupObject(&gNewObjectDefinition);

	green->CType 				= CTYPE_MISC | CTYPE_WEAPONTEST | CTYPE_PLAYERTEST | CTYPE_AUTOTARGETWEAPON;
	green->CBits				= CBITS_ALLSOLID;
	CreateCollisionBoxFromBoundingBox(green, 1, 1);

	green->HitByWeaponHandler 	= LaserOrbHitByWeaponCallback;



				/* ATTACH SHADOW */

	AttachShadowToObject(newObj, SHADOW_TYPE_CIRCULAR, 7, 7, false);


			/********************************************/
			/* MAKE DUMMY OBJECT FOR DRAWING LASER BEAM */
			/********************************************/

	gNewObjectDefinition.genre		= CUSTOM_GENRE;
	gNewObjectDefinition.slot 		= PARTICLE_SLOT + 2;
	gNewObjectDefinition.moveCall 	= nil;
	gNewObjectDefinition.flags 		= STATUS_BIT_DOUBLESIDED|STATUS_BIT_DONTCULL|STATUS_BIT_GLOW|STATUS_BIT_NOLIGHTING|STATUS_BIT_NOFOG|
									STATUS_BIT_NOZWRITES;

	laser = MakeNewObject(&gNewObjectDefinition);
	laser->CustomDrawFunction = DrawOrbLaserBeam;


	newObj->ChainNode = green;
	green->ChainHead = newObj;

	green->ChainNode = laser;
	laser->ChainHead = green;

	return(newObj);
}



/********************** MOVE LASER ORB ***********************/
//
// This is also called by the spline move function, so be careful!
//

static void MoveLaserOrb(ObjNode *theNode)
{
float			fps = gFramesPerSecondFrac;
float			dist;
short			p;
u_long			ctypes;
OGLRay 			ray;
OGLPoint3D 		worldHitCoord;
OGLVector3D 	hitNormal;
ObjNode			*hitObj;
Boolean			hit;
ObjNode			*green;

		/* SEE IF GONE */

	if (!(theNode->StatusBits & STATUS_BIT_ONSPLINE))
	{
		if (TrackTerrainItem(theNode))
		{
			DeleteObject(theNode);
			return;
		}
	}


	switch(theNode->Mode)
	{
				/************************************/
				/* LOOKING FOR A PLAYER TO SHOOT AT */
				/************************************/

		case	ORB_MODE_SEEKING:

						/* SEE IF PLAYER IN RANGE */

				dist = CalcDistanceToClosestPlayer(&theNode->Coord, &p);							// calc dist to player

				if (dist <= LASER_ORB_SHOOT_DIST)
				{
					theNode->TargetOff.x = RandomFloat2() * 150.0f;						// set random aim
					theNode->TargetOff.y = RandomFloat2() * 150.0f;
					theNode->TargetOff.z = RandomFloat2() * 150.0f;

					theNode->PlayerNum = p;
					theNode->Mode = ORB_MODE_SHOOTING;
					theNode->Timer = .3f + RandomFloat() * 1.5f;
					goto update_collision;
				}
				break;


				/******************/
				/* SHOOTING LASER */
				/******************/

		case	ORB_MODE_SHOOTING:

					/* SEE IF DONE */

				theNode->Timer -= fps;
				if (theNode->Timer <= 0.0f)
				{
					theNode->Mode = ORB_MODE_SEEKING;
				}

					/* UPDATE COLLISION */

				else
				{
update_collision:
					if (CalcLaserVectorToPlayer(theNode, theNode->PlayerNum))
					{
						theNode->Mode = ORB_MODE_SEEKING;
						goto update;
					}


					ray.direction 	= theNode->MotionVector;

					ray.origin.x 	= theNode->Coord.x + ray.direction.x * ORB_RING_DIAMETER;
					ray.origin.y 	= theNode->Coord.y + ORB_RING_YOFF;
					ray.origin.z 	= theNode->Coord.z + ray.direction.z * ORB_RING_DIAMETER;


							/* DO RAY COLLISION */

					HideObjectChain(theNode);													// temporarily hide so we don't collide with ourselves

					ctypes = CTYPE_SOLIDTOENEMY |CTYPE_MISC | CTYPE_FENCE | CTYPE_TERRAIN |		// set CTYPE mask to find what we're looking for
							 CTYPE_PLAYER1 | CTYPE_PLAYER2 | CTYPE_ENEMY | CTYPE_WEAPONTEST;

					hit = HandleRayCollision(&ray, &hitObj, &worldHitCoord, &hitNormal, &ctypes);

					ShowObjectChain(theNode);


							/* WE HIT SOMETHING */

					if (hit)
					{
						theNode->LaserDistance = ray.distance;						// get dist to target from the returned ray info

						if (hitObj && (hitObj != theNode))							// did we hit an objNode (but not ourselves)
						{
							theNode->Damage = LASER_DAMAGE * fps;					// set special damage
							if (hitObj->HitByWeaponHandler)							// see if there is a handler for this object
								hitObj->HitByWeaponHandler(theNode, hitObj, &worldHitCoord, &hitNormal);
						}
					}
					else
						theNode->LaserDistance = 10000.0f;							// set as "infinite"

				}
				break;

	}


			/***********************/
			/* UPDATE OTHER THINGS */
			/***********************/

update:

	if (theNode->CType == INVALID_NODE_FLAG)		// see if already deleted
		DoFatalAlert("MoveLaserOrb: orb got nixed mid-stream!");

	theNode->Rot.y -= fps * 1.8f;
	UpdateObjectTransforms(theNode);
	UpdateShadow(theNode);
	CalcObjectBoxFromNode(theNode);
	UpdateLaserOrbSparkles(theNode);


			/* ANIMATE GREEN THING */

	green = theNode->ChainNode;

	green->TextureTransformU 	-= fps * 2.5f;
	green->Coord 				= theNode->Coord;
	green->BaseTransformMatrix 	= theNode->BaseTransformMatrix;
	SetObjectTransformMatrix(green);
}



/******************** CALC LASER VECTOR TO PLAYER **********************/
//
// Returns true if angle is too steep
//

static Boolean CalcLaserVectorToPlayer(ObjNode *orb, short p)
{
OGLVector3D	v;
float	x, y, z;
float	px,py,pz;
float	dot;

	px = gPlayerInfo[p].coord.x + orb->TargetOff.x;				// get player coords with offset
	py = gPlayerInfo[p].coord.y + orb->TargetOff.y;
	pz = gPlayerInfo[p].coord.z + orb->TargetOff.z;

	x 	= orb->Coord.x;											// get coords of center of laser ring
	y 	= orb->Coord.y + ORB_RING_YOFF;
	z 	= orb->Coord.z;

	v.x = (px - x);													// calc vector to player
	v.y = (py - y);
	v.z = (pz - z);
	FastNormalizeVector(v.x, v.y, v.z, &v);

	x 	+= v.x * ORB_RING_DIAMETER;									// adjust vector from point on laser ring
	z 	+= v.z * ORB_RING_DIAMETER;

	v.x = (px - x);													// calc better vector to player
	v.y = (py - y);
	v.z = (pz - z);
	FastNormalizeVector(v.x, v.y, v.z, &orb->MotionVector);


				/* SEE IF ANGLE IS TOO STEEP */

	dot = OGLVector3D_Dot(&gUp, &orb->MotionVector);
	if ((dot > .5f) || (dot < -.5f))
		return(true);

	else
		return(false);

}


#pragma mark -

/*************************** LASER ORB HIT BY WEAPON CALLBACK *****************************/
//
// Returns true if object should stop bullet.
//

static Boolean LaserOrbHitByWeaponCallback(ObjNode *bullet, ObjNode *theNode, OGLPoint3D *hitCoord, OGLVector3D *hitTriangleNormal)
{
#pragma unused (hitCoord, hitTriangleNormal)

		/* FIND BASE OBJECT */

	while(theNode->ChainHead)
		theNode = theNode->ChainHead;


		/* CAUSE DAMAGE */

	theNode->Health -= bullet->Damage;
	if (theNode->Health <= 0.0f)
	{
		ExplodeLaserOrb(theNode);
	}

	return(true);
}


/********************* EXPLODE LASER ORB ***********************/

static void ExplodeLaserOrb(ObjNode *theNode)
{
long					pg,i;
OGLVector3D				d;
OGLPoint3D				pt;
NewParticleDefType		newParticleDef;
float					x,y,z, q;

	PlayEffect_Parms3D(EFFECT_TURRETEXPLOSION, &theNode->Coord, NORMAL_CHANNEL_RATE, 2.0);


	MakeFireRing(theNode->Coord.x, theNode->Coord.y + (LASER_ORB_SCALE * 60.0f), theNode->Coord.z);


		/*****************/
		/* MAKE FIREBALL */
		/*****************/

	x = theNode->Coord.x;
	y = theNode->Coord.y;
	z = theNode->Coord.z;

	gNewParticleGroupDef.magicNum				= 0;
	gNewParticleGroupDef.type					= PARTICLE_TYPE_FALLINGSPARKS;
	gNewParticleGroupDef.flags					= PARTICLE_FLAGS_DONTCHECKGROUND;
	gNewParticleGroupDef.gravity				= -50;
	gNewParticleGroupDef.magnetism				= 0;
	gNewParticleGroupDef.baseScale				= 20;
	gNewParticleGroupDef.decayRate				=  -5.0;
	gNewParticleGroupDef.fadeRate				= .7;
	gNewParticleGroupDef.particleTextureNum		= PARTICLE_SObjType_Fire;
	gNewParticleGroupDef.srcBlend				= GL_SRC_ALPHA;
	gNewParticleGroupDef.dstBlend				= GL_ONE;
	pg = NewParticleGroup(&gNewParticleGroupDef);
	if (pg != -1)
	{
		for (i = 0; i < 150; i++)
		{
			d.y = RandomFloat2() * 100.0f;
			d.x = RandomFloat2() * 100.0f;
			d.z = RandomFloat2() * 100.0f;

			pt.x = x + d.x * .8f;
			pt.y = y + RandomFloat() * (LASER_ORB_SCALE * 70.0f);
			pt.z = z + d.z * .8f;

			newParticleDef.groupNum		= pg;
			newParticleDef.where		= &pt;
			newParticleDef.delta		= &d;
			newParticleDef.scale		= RandomFloat() + 1.0f;
			newParticleDef.rotZ			= RandomFloat() * PI2;
			newParticleDef.rotDZ		= RandomFloat2() * 8.0f;
			newParticleDef.alpha		= 1.0f - (RandomFloat() * .3f);
			AddParticleToGroup(&newParticleDef);
		}
	}


		/***************/
		/* MAKE SPARKS */
		/***************/

	gNewParticleGroupDef.magicNum				= 0;
	gNewParticleGroupDef.type					= PARTICLE_TYPE_FALLINGSPARKS;
	gNewParticleGroupDef.flags					= PARTICLE_FLAGS_DONTCHECKGROUND;
	gNewParticleGroupDef.gravity				= 0;
	gNewParticleGroupDef.magnetism				= 0;
	gNewParticleGroupDef.baseScale				= 15;
	gNewParticleGroupDef.decayRate				=  .5;
	gNewParticleGroupDef.fadeRate				= 1.0;
	gNewParticleGroupDef.particleTextureNum		= PARTICLE_SObjType_WhiteSpark4;
	gNewParticleGroupDef.srcBlend				= GL_SRC_ALPHA;
	gNewParticleGroupDef.dstBlend				= GL_ONE;
	pg = NewParticleGroup(&gNewParticleGroupDef);
	if (pg != -1)
	{
		for (i = 0; i < 220; i++)
		{
			q = RandomFloat() * PI2;
			d.x = sin(q) * 800.0f;
			d.y = RandomFloat2() * 20.0f;
			d.z = cos(q) * 800.0f;

			pt.x = x + d.x * .05f;
			pt.y = y + (LASER_ORB_SCALE * 60.0f);
			pt.z = z + d.z * .05f;

			newParticleDef.groupNum		= pg;
			newParticleDef.where		= &pt;
			newParticleDef.delta		= &d;
			newParticleDef.scale		= RandomFloat() + 1.0f;
			newParticleDef.rotZ			= 0;
			newParticleDef.rotDZ		= 0;
			newParticleDef.alpha		= 1.0f + (RandomFloat() * .3f);
			AddParticleToGroup(&newParticleDef);
		}
	}


		/* FRAGMENT */

	ExplodeGeometry(theNode, 600, SHARD_MODE_FROMORIGIN, 3, 1.0);




			/* DELETE  */

	theNode->TerrainItemPtr = nil;				// dont ever come back
	DeleteObject(theNode);

}

#pragma mark -

/*************************** DRAW ORB LASER BEAM ***************************/

static void DrawOrbLaserBeam(ObjNode *beam, const OGLSetupOutputType *setupInfo)
{
ObjNode	*orb = beam->ChainHead->ChainHead;

		/***********************/
		/* DRAW THE LASER BEAM */
		/***********************/

	if (orb->Mode == ORB_MODE_SHOOTING)
	{
		OGLTextureCoord	uv[4];
		OGLPoint3D	p[4];
		OGLVector3D	side;
		float		x,y,z,dist;
		float		vx,vy,vz, u;
		AGLContext 	agl_ctx = setupInfo->drawContext;

		MO_DrawMaterial(gSpriteGroupList[SPRITE_GROUP_GLOBAL][GLOBAL_SObjType_LaserOrbBeam].materialObject, setupInfo);		// activate material
		OGL_SetColor4f(1,1,1,orb->Timer * 2.0f);

		dist =  orb->LaserDistance;


		u = orb->TextureTransformU -= gFramesPerSecondFrac * 8.0f;

		uv[0].u = u;
		uv[0].v = 0;
		uv[1].u = u;
		uv[1].v = 1;
		uv[2].u = u + dist * .007f;
		uv[2].v = 1;
		uv[3].u = u + dist * .007f;
		uv[3].v = 0;



				/* GET INFO */

		vx = orb->MotionVector.x;
		vy = orb->MotionVector.y;
		vz = orb->MotionVector.z;

		x 	= orb->Coord.x + vx * ORB_RING_DIAMETER;
		y 	= orb->Coord.y + ORB_RING_YOFF;
		z 	= orb->Coord.z + vz * ORB_RING_DIAMETER;


			/* DRAW VERTICAL QUAD */

		p[0].x = x;
		p[0].y = y - LASER_BEAM_SIZE;
		p[0].z = z;

		p[1].x = x;
		p[1].y = y + LASER_BEAM_SIZE;
		p[1].z = z;

		p[2].x = x 		+ vx * dist;
		p[2].y = p[1].y + vy * dist;
		p[2].z = z 		+ vz * dist;

		p[3].x = p[2].x;
		p[3].y = p[0].y + vy * dist;
		p[3].z = p[2].z;

		glBegin(GL_QUADS);

		glTexCoord2fv((GLfloat *)&uv[0]);	glVertex3fv((GLfloat *)&p[0]);
		glTexCoord2fv((GLfloat *)&uv[1]);	glVertex3fv((GLfloat *)&p[1]);
		glTexCoord2fv((GLfloat *)&uv[2]);	glVertex3fv((GLfloat *)&p[2]);
		glTexCoord2fv((GLfloat *)&uv[3]);	glVertex3fv((GLfloat *)&p[3]);

		glEnd();

			/* DRAW HORIZONTAL QUAD */

		OGLVector3D_Cross(&gUp, &orb->MotionVector, &side);					// calc side x-axis vector

		p[0].x = x + side.x * LASER_BEAM_SIZE;
		p[0].y = y;
		p[0].z = z + side.z * LASER_BEAM_SIZE;

		p[1].x = x - side.x * LASER_BEAM_SIZE;
		p[1].y = y;
		p[1].z = z - side.z * LASER_BEAM_SIZE;

		p[2].x = p[1].x	+ vx * dist;
		p[2].y = y + vy * dist;
		p[2].z = p[1].z	+ vz * dist;

		p[3].x = p[0].x	+ vx * dist;
		p[3].y = p[2].y;
		p[3].z = p[0].z	+ vz * dist;

		glBegin(GL_QUADS);

		glTexCoord2fv((GLfloat *)&uv[0]);	glVertex3fv((GLfloat *)&p[0]);
		glTexCoord2fv((GLfloat *)&uv[1]);	glVertex3fv((GLfloat *)&p[1]);
		glTexCoord2fv((GLfloat *)&uv[2]);	glVertex3fv((GLfloat *)&p[2]);
		glTexCoord2fv((GLfloat *)&uv[3]);	glVertex3fv((GLfloat *)&p[3]);

		glEnd();

	}
}



/********************* UPDATE LASER ORB SPARKLES **************************/

static void UpdateLaserOrbSparkles(ObjNode *orb)
{
short	i;

		/* SEE IF NIX SPARKLES */

	if (orb->Mode == ORB_MODE_SEEKING)
	{
		i = orb->Sparkles[0];
		if (i != -1)
		{
			DeleteSparkle(i);
			orb->Sparkles[0] = -1;
		}

		i = orb->Sparkles[1];
		if (i != -1)
		{
			DeleteSparkle(i);
			orb->Sparkles[1] = -1;
		}

			/* ALSO BE SURE NO SFX */

		if (orb->EffectChannel != -1)
			StopAChannel(&orb->EffectChannel);

	}


			/*******************/
			/* UPDATE SPARKLES */
			/*******************/
	else
	{
		float	vx,vy,vz,x,y,z;

				/* GET INFO */

		vx = orb->MotionVector.x;
		vy = orb->MotionVector.y;
		vz = orb->MotionVector.z;

		x 	= orb->Coord.x + vx * ORB_RING_DIAMETER;
		y 	= orb->Coord.y + ORB_RING_YOFF;
		z 	= orb->Coord.z + vz * ORB_RING_DIAMETER;


			/* SOURCE SPARKLE */

		i = orb->Sparkles[0];
		if (i != -1)							// do we alredy have one?
		{
			gSparkles[i].where.x = x;			// just update the coord
			gSparkles[i].where.y = y;
			gSparkles[i].where.z = z;
		}
		else
		{
			i = orb->Sparkles[0] = GetFreeSparkle(orb);			// make new sparkle
			if (i != -1)
			{
				gSparkles[i].flags = SPARKLE_FLAG_OMNIDIRECTIONAL | SPARKLE_FLAG_RANDOMSPIN | SPARKLE_FLAG_FLICKER | SPARKLE_FLAG_ALWAYSDRAW;
				gSparkles[i].where.x = x;
				gSparkles[i].where.y = y;
				gSparkles[i].where.z = z;

				gSparkles[i].color.r = 1;
				gSparkles[i].color.g = 1;
				gSparkles[i].color.b = 1;
				gSparkles[i].color.a = 1;

				gSparkles[i].scale 	= 120.0f;
				gSparkles[i].separation = 40.0f;

				gSparkles[i].textureNum = PARTICLE_SObjType_BlueGlint;
			}
		}

			/* TARGET SPARKLE */

		x += vx * orb->LaserDistance;
		y += vy * orb->LaserDistance;
		z += vz * orb->LaserDistance;

		i = orb->Sparkles[1];
		if (i != -1)							// do we alredy have one?
		{
			gSparkles[i].where.x = x;			// just update the coord
			gSparkles[i].where.y = y;
			gSparkles[i].where.z = z;
		}
		else
		{
			i = orb->Sparkles[1] = GetFreeSparkle(orb);			// make new sparkle
			if (i != -1)
			{
				gSparkles[i].flags = SPARKLE_FLAG_OMNIDIRECTIONAL | SPARKLE_FLAG_RANDOMSPIN | SPARKLE_FLAG_FLICKER | SPARKLE_FLAG_ALWAYSDRAW;
				gSparkles[i].where.x = x;
				gSparkles[i].where.y = y;
				gSparkles[i].where.z = z;

				gSparkles[i].color.r = 1;
				gSparkles[i].color.g = 1;
				gSparkles[i].color.b = 1;
				gSparkles[i].color.a = 1;

				gSparkles[i].scale 	= 120.0f;
				gSparkles[i].separation = 40.0f;

				gSparkles[i].textureNum = PARTICLE_SObjType_BlueGlint;
			}

		}


			/* UPDATE SOUND EFFECT WHILE WE'RE HERE */

		if (orb->EffectChannel == -1)
			orb->EffectChannel = PlayEffect_Parms3D(EFFECT_LASERBEAM, &gPlayerInfo[orb->PlayerNum].coord, NORMAL_CHANNEL_RATE * 4/5, .9);
		else
			Update3DSoundChannel(EFFECT_LASERBEAM, &orb->EffectChannel, &gPlayerInfo[orb->PlayerNum].coord);


	}
}



#pragma mark -

/************************ PRIME LASER ORB *************************/

Boolean PrimeLaserOrb(long splineNum, SplineItemType *itemPtr)
{
ObjNode			*newObj;
float			x,z,placement;

			/* GET SPLINE INFO */

	placement = itemPtr->placement;
	GetCoordOnSpline(&gSplineList[splineNum], placement, &x, &z);


				/* MAKE RAPTOR */

	newObj = MakeLaserOrb(x,z);


				/* SET BETTER INFO */

	newObj->StatusBits		|= STATUS_BIT_ONSPLINE;
	newObj->SplineItemPtr 	= itemPtr;
	newObj->SplineNum 		= splineNum;
	newObj->SplinePlacement = placement;
	newObj->SplineMoveCall 	= MoveLaserOrbOnSpline;					// set move call


			/* ADD SPLINE OBJECT TO SPLINE OBJECT LIST */
			//
			// NOTE:  Normally we'd detach the ObjNode, but Laser Orbs are special and
			// 		they need to always be active!!!
			//

//	DetachObject(newObj, true);										// detach this object from the linked list
	AddToSplineObjectList(newObj, true);

	return(true);
}


/******************** MOVE LASER ORB ON SPLINE ***************************/

static void MoveLaserOrbOnSpline(ObjNode *theNode)
{
//Boolean isInRange;

//	isInRange = IsSplineItemOnActiveTerrain(theNode);					// update its visibility

		/* MOVE ALONG THE SPLINE */

	IncreaseSplineIndex(theNode, 100);
	GetObjectCoordOnSpline(theNode);


			/* UPDATE STUFF IF IN RANGE */

//	if (isInRange)
	{
		theNode->Coord.y = GetTerrainY(theNode->Coord.x, theNode->Coord.z);							// calc y coord

		MoveLaserOrb(theNode);
	}
}















