//
// effects.h
//

#ifndef __EFFECTS_H
#define __EFFECTS_H

#define	MAX_PARTICLE_GROUPS		80
#define	MAX_PARTICLES			150		// (note change Byte below if > 255)

#define	MAX_CONFETTI_GROUPS		50
#define	MAX_CONFETTIS			150		// (note change Byte below if > 255)


		/* FIRE & SMOKE */

#define	FireTimer			SpecialF[5]
#define	SmokeTimer			SpecialF[4]
#define	SmokeParticleGroup	Special[5]
#define	SmokeParticleMagic	Special[4]

			/* PARTICLE GROUP TYPE */

typedef struct
{
	Byte			inPurgeQueue;
	signed char		purgeTimer;
	Byte			type;
	Byte			particleTextureNum;

	Byte			isUsed[MAX_PARTICLES];

	uint32_t			magicNum;
	u_short			flags;
	float			gravity;
	float			magnetism;
	float			baseScale;
	float			decayRate;						// shrink speed
	float			fadeRate;

	int				srcBlend,dstBlend;

	float			alpha[MAX_PARTICLES];
	float			scale[MAX_PARTICLES];
	float			rotZ[MAX_PARTICLES];
	float			rotDZ[MAX_PARTICLES];
	OGLPoint3D		coord[MAX_PARTICLES];
	OGLVector3D		delta[MAX_PARTICLES];

	float			maxY;

	MOVertexArrayObject	*geometryObj[2][MAX_PLAYERS];		// there are 2 objects for each PG because we double-buffer it for the VAR
															// plus an object for each player

	OGLBoundingBox  bbox;

}ParticleGroupType;


		/* CONFETTI GROUP TYPE */

typedef struct
{
	uint32_t			magicNum;
	Byte			isUsed[MAX_CONFETTIS];
	uint32_t			flags;
	Byte			confettiTextureNum;
	float			gravity;
	float			baseScale;
	float			decayRate;						// shrink speed
	float			fadeRate;

	float			fadeDelay[MAX_CONFETTIS];
	float			alpha[MAX_CONFETTIS];
	float			scale[MAX_CONFETTIS];
	OGLVector3D		rot[MAX_CONFETTIS];
	OGLVector3D		deltaRot[MAX_CONFETTIS];
	OGLPoint3D		coord[MAX_CONFETTIS];
	OGLVector3D		delta[MAX_CONFETTIS];

	MOVertexArrayObject	*geometryObj;

}ConfettiGroupType;



enum
{
	PARTICLE_TYPE_FALLINGSPARKS,
	PARTICLE_TYPE_GRAVITOIDS
};

enum
{
	PARTICLE_FLAGS_BOUNCE 			= (1<<0),
	PARTICLE_FLAGS_HURTPLAYER 		= (1<<1),
	PARTICLE_FLAGS_HURTPLAYERBAD 	= (1<<2),	//combine with PARTICLE_FLAGS_HURTPLAYER
	PARTICLE_FLAGS_HURTENEMY 		= (1<<3),
	PARTICLE_FLAGS_DONTCHECKGROUND 	= (1<<4),
	PARTICLE_FLAGS_xxx		 		= (1<<5),
	PARTICLE_FLAGS_DISPERSEIFBOUNCE = (1<<6),
	PARTICLE_FLAGS_ALLAIM 			= (1<<7),	// want to calc look-at matrix for all particles
	PARTICLE_FLAGS_HASMAXY			= (1<<8)	// if particle can only go so high
};


/********** PARTICLE GROUP DEFINITION **************/

typedef struct
{
	uint32_t 	magicNum;
	Byte 	type;
	uint32_t  flags;
	float 	gravity;
	float 	magnetism;
	float 	baseScale;
	float 	decayRate;
	float 	fadeRate;
	Byte 	particleTextureNum;
	int		srcBlend,dstBlend;
}NewParticleGroupDefType;

/*************** NEW PARTICLE DEFINITION *****************/

typedef struct
{
	short 		groupNum;
	OGLPoint3D 	*where;
	OGLVector3D *delta;
	float 		scale;
	float		rotZ,rotDZ;
	float 		alpha;
}NewParticleDefType;


/********** CONFETTI GROUP DEFINITION **************/

typedef struct
{
	uint32_t 	magicNum;
	uint32_t  flags;
	float 	gravity;
	float 	baseScale;
	float 	decayRate;
	float 	fadeRate;
	Byte 	confettiTextureNum;
}NewConfettiGroupDefType;


/*************** NEW CONFETTI DEFINITION *****************/

typedef struct
{
	short 		groupNum;
	OGLPoint3D 	*where;
	OGLVector3D *delta;
	float 		scale;
	OGLVector3D	rot,deltaRot;
	float		fadeDelay;
	float 		alpha;
}NewConfettiDefType;


#define	FULL_ALPHA	1.0f


			/* EXTERNS */

extern	NewParticleGroupDefType	gNewParticleGroupDef;
extern	NewConfettiGroupDefType	gNewConfettiGroupDef;



//============================================================================================


		/* MISC EFFECTS */


void InitEffects(void);
ObjNode *MakeShockwaveRing(OGLPoint3D *coord, float scale);


			/* PARTICLES */

void InitParticleSystem(void);
void DeleteAllParticleGroups(void);
short NewParticleGroup(NewParticleGroupDefType *def);
Boolean AddParticleToGroup(const NewParticleDefType *def);
Boolean VerifyParticleGroupMagicNum(short group, uint32_t magicNum);
Boolean ParticleHitObject(ObjNode *theNode, u_short inFlags);
void DisposeParticleSystem(void);

void MakePuff(short numPuffs, OGLPoint3D *where, float scale, short texNum, GLint src, GLint dst, float decayRate);
void MakeSparkExplosion(const OGLPoint3D *coord, float force, float scale, short sparkTexture, short quantityLimit, float fadeRate);

void MakeBombExplosion(float x, float z, OGLVector3D *delta);
void MakeSplash(OGLPoint3D *where, float scale);

void SprayWater(ObjNode *theNode, float x, float y, float z);
void BurnFire(ObjNode *theNode, float x, float y, float z, Boolean doSmoke, short particleType, float scale, uint32_t moreFlags);


void MakeFireExplosion(OGLPoint3D *where);

void MakeSplatter(OGLPoint3D *where, short modelObjType, float scale);

void MakeSteam(ObjNode *blob, float x, float y, float z);
Boolean AddSmoker(TerrainItemEntryType *itemPtr, float  x, float z);
ObjNode *MakeSmoker(float  x, float z, int kind);

Boolean AddFlame(TerrainItemEntryType *itemPtr, float  x, float z);
ObjNode *MakeFireRing(float x, float y, float z);




		/* CONFETTI */

void InitConfettiManager(void);
void DeleteAllConfettiGroups(void);
short NewConfettiGroup(NewConfettiGroupDefType *def);
Boolean AddConfettiToGroup(NewConfettiDefType *def);
Boolean VerifyConfettiGroupMagicNum(short group, uint32_t magicNum);
void MakeConfettiExplosion(float x, float y, float z, float force, float scale, short texture, short quantityLimit);
void DoPlayerGroundScrape(ObjNode *player, short playerNum);


		/* CONTRAILS */

void InitContrails(void);
void MakeNewContrail(float width, short *contrailNum);
void AddPointToContrail(short contrailNum, OGLPoint3D *where, OGLVector3D *aim, float alpha);
void ModifyContrailPreviousAddition(short contrailNum, OGLPoint3D *where);
void DisposeContrails(void);
void DisconnectContrail(short contrailNum);
void UpdatePlayerContrails(ObjNode *player);




#endif




