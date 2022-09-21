/****************************/
/*   	PLAYER.C   			*/
/* (c)2004 Pangea Software  */
/* By Brian Greenstone      */
/****************************/


/****************************/
/*    EXTERNALS             */
/****************************/

#include "game.h"


/****************************/
/*    PROTOTYPES            */
/****************************/

static Boolean PlayerShieldHitByWeaponCallback(ObjNode *bullet, ObjNode *shield, OGLPoint3D *hitCoord, OGLVector3D *hitTriangleNormal);
static void DrawPlayerShield(ObjNode *theNode, const OGLSetupOutputType *setupInfo);


/****************************/
/*    CONSTANTS             */
/****************************/



/*********************/
/*    VARIABLES      */
/*********************/

Byte			gNumPlayers = 1;				// 2 if split-screen, otherwise 1

PlayerInfoType	gPlayerInfo[MAX_PLAYERS];

float	gDeathTimer[MAX_PLAYERS] = {0,0};


Boolean	gPlayerIsDead[MAX_PLAYERS] = {false, false};

#define	TextureTransformU2	SpecialF[0]
#define	TextureTransformV2	SpecialF[1]




/******************** INIT PLAYER INFO ***************************/
//
// Called once at beginning of game
//

void InitPlayerInfo_Game(void)
{
short	i, w;

	for (i = 0; i < MAX_PLAYERS; i++)
	{

				/* INIT SOME THINGS IF NOT LOADING SAVED GAME */

		if (!gPlayingFromSavedGame)
		{
			if (gVSMode == VS_MODE_BATTLE)									// more lives in battle mode
				gPlayerInfo[i].numFreeLives		= 5;
			else
				gPlayerInfo[i].numFreeLives		= 3;

			gPlayerInfo[i].health 			= 1.0;

			if (gVSMode == VS_MODE_RACE)									// start with very little fuel in races
				gPlayerInfo[i].jetpackFuel  = 0.25;
			else
				gPlayerInfo[i].jetpackFuel	= 1.0f;

			gPlayerInfo[i].shieldPower		= MAX_SHIELD_POWER;

			for (w = 0; w < NUM_WEAPON_TYPES; w++)							// init weapon inventory
				gPlayerInfo[i].weaponQuantity[w] = 0;
		}


		gDeathTimer[i] = 0;

		gPlayerInfo[i].startX 			= 0;
		gPlayerInfo[i].startZ 			= 0;
		gPlayerInfo[i].coord.x 			= 0;
		gPlayerInfo[i].coord.y 			= 0;
		gPlayerInfo[i].coord.z 			= 0;

		gPlayerInfo[i].blinkTimer 		= 2;

		gPlayerInfo[i].turretSide		= 0;

		gPlayerInfo[i].wormhole			= nil;

		gPlayerInfo[i].currentWeapon						= WEAPON_TYPE_SONICSCREAM;
		gPlayerInfo[i].weaponQuantity[WEAPON_TYPE_SONICSCREAM] 	= 999;		// we have infinite of these, but set to 999 anyways
	}

}


/******************* INIT PLAYER AT START OF LEVEL ********************/

void InitPlayerAtStartOfLevel(void)
{
short	i, j;

			/* FIRST PRIME THE TERRAIN TO CAUSE ALL OBJECTS TO BE GENERATED BEFORE WE PUT THE PLAYER DOWN */

	InitCurrentScrollSettings();
	DoPlayerTerrainUpdate();


				/* INIT EACH PLAYER'S INFO */

	for (i = 0; i < gNumPlayers; i++)
	{

		gPlayerInfo[i].invincibilityTimer = 0;


		gPlayerInfo[i].burnTimer = 0;

		gPlayerInfo[i].shieldObj = nil;
		gPlayerInfo[i].weaponChargeChannel = -1;

		gPlayerInfo[i].jetpackActive	= false;

		gPlayerInfo[i].crosshairTargetObj = nil;

		gPlayerIsDead[i] = false;

		gPlayerInfo[i].waterRippleTimer = 0;

		gPlayerInfo[i].previousWingContrailPt[0].x =
		gPlayerInfo[i].previousWingContrailPt[0].y =
		gPlayerInfo[i].previousWingContrailPt[0].z =
		gPlayerInfo[i].previousWingContrailPt[1].x =
		gPlayerInfo[i].previousWingContrailPt[1].y =
		gPlayerInfo[i].previousWingContrailPt[1].z = 10000000;

		gPlayerInfo[i].carriedObj = nil;

				/* INIT RACE-SPECIFIC INFO */

		for (j = 0; j < MAX_LINEMARKERS; j++)								// start with all race checkpoints tagged to trick lapNum @ start of race
			gPlayerInfo[i].raceCheckpointTagged[j] 	= true;

		gPlayerInfo[i].movingBackwards	= false;
		gPlayerInfo[i].wrongWay			= false;

		gPlayerInfo[i].lapNum					= -1;						// start @ -1 since we cross the finish line @ start
		gPlayerInfo[i].raceCheckpointNum		= gNumLineMarkers-1;
		gPlayerInfo[i].place					= i;
		gPlayerInfo[i].distToNextCheckpoint		= 0;
		gPlayerInfo[i].raceComplete				= false;

		gPlayerInfo[i].dirtParticleTimer = 0;
		gPlayerInfo[i].dirtParticleGroup = -1;


				/* CREATE THE PLAYER */

		CreatePlayerObject(i, &gPlayerInfo[i].coord, gPlayerInfo[i].startRotY);

		gBestCheckpointCoord[i] = gPlayerInfo[i].coord;					// set first checkpoint @ starting location
		gBestCheckpointAim[i]	= gPlayerInfo[i].objNode->Rot.y;


				/* GIVE PLAYER A SHIELD */

		if (gPlayerInfo[i].shieldPower > 0.0f)							// only give shield obj if have shield power
			CreatePlayerShield(i);
	}


			/*********************************************/
			/* LAY DOWN ENTRY WORMHOLE IN ADVENTURE MODE */
			/*********************************************/

	if (gVSMode == VS_MODE_NONE)
	{
		static OGLPoint3D wormStartOff 	= {0,1200, 0};
		static OGLVector3D	wormVector 	= {0, 1, 0};
		ObjNode	*player 				= gPlayerInfo[0].objNode;
		ObjNode	*wormhole;

		wormhole = MakeEntryWormhole(0);

					/* CALC COORD AND VECTOR OF PLAYER AT START OF WORMHOLE */

		OGLPoint3D_Transform(&wormStartOff, &wormhole->BaseTransformMatrix, &player->Coord);
		OGLVector3D_Transform(&wormVector,  &wormhole->BaseTransformMatrix, &player->Delta);

		player->Speed = 2500.0f;

		player->Delta.x *= -player->Speed;
		player->Delta.y *= -player->Speed;
		player->Delta.z *= -player->Speed;

		gPlayerInfo[0].coord = player->Coord;

		SetSkeletonAnim(player->Skeleton, PLAYER_ANIM_APPEARWORMHOLE);
		player->Rot.x = -PI/2 + wormhole->Rot.x;


		FadePlayer(player, -.99);			// start faded out

	}



}



#pragma mark -

/***************** DISORIENT PLAYER ********************/

void DisorientPlayer(ObjNode *player)
{
short	playerNum = player->PlayerNum;

	if (!gGamePrefs.kiddieMode)							// don't drop eggs in kiddie mode
		DropEgg_NoWormhole(playerNum);

	if (player->Skeleton->AnimNum != PLAYER_ANIM_DISORIENTED)
		MorphToSkeletonAnim(player->Skeleton, PLAYER_ANIM_DISORIENTED, 3.0f);

}


/***************** PLAYER LOSE HEALTH ************************/
//
// return true if player killed
//
//
// where is usually gCoord, but if nil then use coord from player's objNode
//


Boolean PlayerLoseHealth(short playerNum, float damage, Byte deathType, OGLPoint3D *where, Boolean disorient)
{
Boolean	killed = false;




	if (gPlayerInfo[playerNum].invincibilityTimer > 0.0f)	// see if invincible
		return(false);

	if (gPlayerInfo[playerNum].health < 0.0f)				// see if already dead
		return(true);

	gPlayerInfo[playerNum].health -= damage;

		/* SEE IF KILLED */

	if (gPlayerInfo[playerNum].health <= 0.0f)
	{
		gPlayerInfo[playerNum].health = 0;

		KillPlayer(playerNum, deathType, where);
		killed = true;
	}

		/* JUST HURT */

	else
	if (disorient)
	{
		DisorientPlayer(gPlayerInfo[playerNum].objNode);
	}


	return(killed);
}


/****************** KILL PLAYER *************************/
//
// where is usually gCoord, but if nil then use coord from player's objNode
//

void KillPlayer(short playerNum, Byte deathType, OGLPoint3D *where)
{
ObjNode	*player = gPlayerInfo[playerNum].objNode;

			/* MAKE SURE STOPPED WEAPON CHARGE SFX */

	StopAChannel(&gPlayerInfo[playerNum].weaponChargeChannel);

	JetpackOff(playerNum);


			/* DROP EGG (IF ANY) */

	DropEgg_NoWormhole(playerNum);


		/* VERIFY ANIM IF ALREADY DEAD */
		//
		// This should assure us that we don't get kicked out of our death anim accidentally
		//

	if (gPlayerIsDead[playerNum])						// see if already dead
		return;


			/* KILL US NOW */


	gPlayerIsDead[playerNum] = true;
	gPlayerInfo[playerNum].health = 0;					// make sure this is set correctly

	switch(deathType)
	{
		case	PLAYER_DEATH_TYPE_EXPLODE:
				ExplodePlayer(player, playerNum, where);
				break;

		case	PLAYER_DEATH_TYPE_DEATHDIVE:
				MorphToSkeletonAnim(player->Skeleton, PLAYER_ANIM_DEATHDIVE, 3.0f);
				gDeathTimer[playerNum] = gPlayerInfo[playerNum].invincibilityTimer = 8.0f;
				gCameraInDeathDiveMode[playerNum] = true;
				PlayEffect3D(EFFECT_BODYHIT, &player->Coord);
				break;
	}


			/* SPECIAL STUFF FOR BATTLE MODE */

	if (gVSMode == VS_MODE_BATTLE)
	{
		if (gPlayerInfo[playerNum].numFreeLives <= 0)	// is this player out of lives?
		{
			ShowWinLose(playerNum, 1);					// lost
			ShowWinLose(playerNum^1, 0);				// win
			StartLevelCompletion(5.0f);
		}
	}

}



/********************* HIDE PLAYER ************************/

void HidePlayer(ObjNode *player)
{
ObjNode	*node = player;

	while(node)
	{
		node->StatusBits |= STATUS_BIT_HIDDEN | STATUS_BIT_NOMOVE;
		node = node->ChainNode;
	}

	player->CType = 0;
}


/********************* SHOW PLAYER ************************/

void ShowPlayer(ObjNode *player)
{
ObjNode	*node = player;

	while(node)
	{
		node->StatusBits &= ~(STATUS_BIT_HIDDEN | STATUS_BIT_NOMOVE);
		node = node->ChainNode;
	}

}


/********************* FADE PLAYER *************************/
//
// Return true if player is now invisible / hidden
//

Boolean	FadePlayer(ObjNode *player, float rate)
{
float	a;
ObjNode	*node = player;

	a = player->ColorFilter.a;
	a += rate;


	if (a > 1.0f)
		a = 1.0f;
	else
	if (a <= 0.0f)
	{
		HidePlayer(player);
		return(true);
	}


	while(node)
	{
		node->ColorFilter.a = a;

//		if (a < 1.0f)
//			node->StatusBits |= STATUS_BIT_NOZWRITES;
//		else
//			node->StatusBits &= ~STATUS_BIT_NOZWRITES;

		node = node->ChainNode;
	}

	return(false);
}



/****************** RESET PLAYER @ BEST CHECKPOINT *********************/

void ResetPlayerAtBestCheckpoint(short playerNum)
{
ObjNode	*player = gPlayerInfo[playerNum].objNode;

	SetSkeletonAnim(player->Skeleton, PLAYER_ANIM_COASTING);

			/***************************************************/
			/* FIRST TAKE AWAY A LIFE AND SEE IF IT'S ALL OVER */
			/***************************************************/

	switch(gVSMode)								// not all game modes have lives
	{
		case	VS_MODE_RACE:					// infinite lives in racing & flag modes
		case	VS_MODE_CAPTURETHEFLAG:
				break;

		case	VS_MODE_BATTLE:
				if (gPlayerInfo[playerNum].numFreeLives <= 0)		// if no lives remaining then do nothing but wait for level completion to finish
					return;
				else
					gPlayerInfo[playerNum].numFreeLives--;			// dec # lives
				break;

		default:
				if (gPlayerInfo[playerNum].numFreeLives <= 0)		// if no free lives then cannot reset, so game over
				{
					gGameOver = true;
					return;
				}
				gPlayerInfo[playerNum].numFreeLives--;				// dec # lives
	}


			/* RESET SPEEDS */

	gTargetMaxSpeed[playerNum] = PLAYER_NORMAL_MAX_SPEED;
	gCurrentMaxSpeed[playerNum] = PLAYER_NORMAL_MAX_SPEED;
	player->Speed = PLAYER_NORMAL_MAX_SPEED;


				/****************************/
				/* RESET COORD @ CHECKPOINT */
				/****************************/
				//
				// In 2-player modes we start each player at a different height so that they don't materialize on top
				// of each other if they both die and reincarnate simultaneously!
				//

	gPlayerInfo[playerNum].coord = player->Coord = gBestCheckpointCoord[playerNum];

				/* ALWAYS REINCARNATE HIGH */

	if (playerNum == 0)
		gPlayerInfo[playerNum].coord.y = player->Coord.y = CalcPlayerMaxAltitude(player->Coord.x, player->Coord.z) - 600.0f;
	else
		gPlayerInfo[playerNum].coord.y = player->Coord.y = CalcPlayerMaxAltitude(player->Coord.x, player->Coord.z) - (600.0f+200.0f);		// player 2 starts lower than player 1

	DoPlayerTerrainUpdate();								// do this to prime any objecs/platforms there before we calc our new y Coord

	player->OldCoord = player->Coord;
	player->Delta.x = player->Delta.y = player->Delta.z = 0;

	player->Scale.x =
	player->Scale.y =
	player->Scale.z = PLAYER_DEFAULT_SCALE;


				/* RESET COLLISION & STATUS INFO */

	player->CType = CTYPE_PLAYER1 << playerNum;				// make sure collision is set

	if (gVSMode != VS_MODE_NONE)							// be sure to reset this for 2P modes
	{
		player->CType 			|= CTYPE_TRIGGER;
		player->CBits			|= CBITS_ALWAYSTRIGGER;
		player->TriggerCallback = DoTrig_Player;
	}


	ShowPlayer(player);
	FadePlayer(player, 1.0);


	gPlayerInfo[playerNum].health = player->Health = 1.0;
	gPlayerInfo[playerNum].burnTimer = 0;

	gPlayerIsDead[playerNum]		= false;

 	gPlayerInfo[playerNum].invincibilityTimer = 1.0f;

	player->Rot.x = player->Rot.z = 0;
	player->Rot.y = gBestCheckpointAim[playerNum];			// set the aim


	gCameraInDeathDiveMode[playerNum] = false;				// make sure camera not frozen

	SetPlayerFlyingAnim(player);

	InitCamera_Terrain(playerNum);


	MakeFadeEvent(true, 3.0);

}





#pragma mark -



/************************ UPDATE CARRIED OBJECT ********************************/

void UpdateCarriedObject(ObjNode *player, ObjNode *held)
{
OGLMatrix4x4	m,mst,rm,m2;
float			scale;

			/* CALC SCALE MATRIX */

	scale = held->Scale.x / player->Scale.x;					// to adjust from player's scale to held's scale
	OGLMatrix4x4_SetScale(&mst, scale, scale, scale);

			/* CALC TRANSLATE MATRIX */

	mst.value[M03] = held->HoldOffset.x;						// insert translation into scale matrix
	mst.value[M13] = held->HoldOffset.y;
	mst.value[M23] = held->HoldOffset.z;


			/* CALC ROTATE MATRIX */

	OGLMatrix4x4_SetRotate_XYZ(&rm, held->HoldRot.x, held->HoldRot.y, held->HoldRot.z);
	OGLMatrix4x4_Multiply(&rm, &mst, &m2);


			/* GET ALIGNMENT MATRIX */

	FindJointFullMatrix(player, PLAYER_JOINT_EGGHOLD, &m);			// get joint's matrix

	OGLMatrix4x4_Multiply(&m2, &m, &held->BaseTransformMatrix);
	SetObjectTransformMatrix(held);


			/* GET COORDS FOR OBJECT & KEEP COLLISION BOX */
			//
			// even tho the collision box is turned off while the player
			// is carrying the object, we maintain these values
			// so that when the player drops the object things
			// dont freak out.
			//

	held->Coord.x = held->OldCoord.x = held->BaseTransformMatrix.value[M03];
	held->Coord.y = held->OldCoord.y = held->BaseTransformMatrix.value[M13];
	held->Coord.z = held->OldCoord.z = held->BaseTransformMatrix.value[M23];

	held->Rot.y = player->Rot.y;
	CalcObjectBoxFromNode(held);
	UpdateShadow(held);


#if 0	// can't do this with Nano 2 since light beam chains off of the eggs
			/* ALSO UPDATE ANY CHAINS */

	if (held->ChainNode)
	{
		ObjNode	*child = held->ChainNode;

		child->BaseTransformMatrix = held->BaseTransformMatrix;
		child->Coord = held->Coord;
		SetObjectTransformMatrix(child);
	}
#endif
}


/**************** CALC DISTANCE TO CLOSEST PLAYER **********************/

float CalcDistanceToClosestPlayer(OGLPoint3D *pt, short *playerNum)
{
float	d1, d2;

			/* CHECK PLAYER 1 */

	if (gPlayerIsDead[0])												// ignore dead player
		d1 = 10000000;
	else
		d1 = OGLPoint3D_Distance(pt, &gPlayerInfo[0].coord);			// get player 1 dist

	if (playerNum)
		*playerNum = 0;



			/* CHECK PLAYER 2 */

	if (gNumPlayers > 1)
	{
		if (gPlayerIsDead[1])												// ignore dead player
			return(d1);

		d2 = OGLPoint3D_Distance(pt, &gPlayerInfo[1].coord);
		if (d2 < d1)
		{
			if (playerNum)
				*playerNum = 1;
			return(d2);
		}
	}

	return(d1);
}




#pragma mark -

/********************** EXPLODE PLAYER ***********************/
//
// where is usually gCoord, but if nil then use coord from player's objNode
//

void ExplodePlayer(ObjNode *player, short playerNum, OGLPoint3D *where)
{
long					pg,i;
OGLVector3D				d;
OGLPoint3D				pt;
NewParticleDefType		newParticleDef;
NewConfettiDefType		newConfettiDef;
float					x,y,z;

	if (where)
	{
		x = where->x;
		y = where->y;
		z = where->z;
	}
	else
	{
		x = player->Coord.x;
		y = player->Coord.y;
		z = player->Coord.z;
	}


		/*****************/
		/* MAKE FIREBALL */
		/*****************/

	gNewParticleGroupDef.magicNum				= 0;
	gNewParticleGroupDef.type					= PARTICLE_TYPE_FALLINGSPARKS;
	gNewParticleGroupDef.flags					= 0;
	gNewParticleGroupDef.gravity				= 0;
	gNewParticleGroupDef.magnetism				= 0;
	gNewParticleGroupDef.baseScale				= 18;
	gNewParticleGroupDef.decayRate				=  -4.0;
	gNewParticleGroupDef.fadeRate				= 1.1;
	gNewParticleGroupDef.particleTextureNum		= PARTICLE_SObjType_Fire;
	gNewParticleGroupDef.srcBlend				= GL_SRC_ALPHA;
	gNewParticleGroupDef.dstBlend				= GL_ONE;
	pg = NewParticleGroup(&gNewParticleGroupDef);
	if (pg != -1)
	{
		for (i = 0; i < 100; i++)
		{
			d.y = RandomFloat2() * 150.0f;
			d.x = RandomFloat2() * 150.0f;
			d.z = RandomFloat2() * 150.0f;

			pt.x = x + d.x * .2f;
			pt.y = y + d.y * .2f;
			pt.z = z + d.z * .2f;

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
	gNewParticleGroupDef.flags					= PARTICLE_FLAGS_BOUNCE;
	gNewParticleGroupDef.gravity				= 700;
	gNewParticleGroupDef.magnetism				= 0;
	gNewParticleGroupDef.baseScale				= 10;
	gNewParticleGroupDef.decayRate				=  .4;
	gNewParticleGroupDef.fadeRate				= .7;
	gNewParticleGroupDef.particleTextureNum		= PARTICLE_SObjType_BlueSpark;
	gNewParticleGroupDef.srcBlend				= GL_SRC_ALPHA;
	gNewParticleGroupDef.dstBlend				= GL_ONE;
	pg = NewParticleGroup(&gNewParticleGroupDef);
	if (pg != -1)
	{
		for (i = 0; i < 70; i++)
		{
			d.x = RandomFloat2() * 600.0f;
			d.y = RandomFloat2() * 600.0f;
			d.z = RandomFloat2() * 600.0f;

			pt.x = x + d.x * .05f;
			pt.y = y + d.y * .05f;
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



		/************/
		/* CONFETTI */
		/************/

	gNewConfettiGroupDef.magicNum				= 0;
	gNewConfettiGroupDef.flags					= PARTICLE_FLAGS_DONTCHECKGROUND;
	gNewConfettiGroupDef.gravity				= 300;
	gNewConfettiGroupDef.baseScale				= 6.0;
	gNewConfettiGroupDef.decayRate				= 1.0;
	gNewConfettiGroupDef.fadeRate				= 1.0;
	gNewConfettiGroupDef.confettiTextureNum		= PARTICLE_SObjType_Confetti_NanoFlesh;

	pg = NewConfettiGroup(&gNewConfettiGroupDef);
	if (pg != -1)
	{
		for (i = 0; i < 150; i++)
		{
			d.x = RandomFloat2() * 400.0f;
			d.y = RandomFloat2() * 400.0f;
			d.z = RandomFloat2() * 400.0f;

			pt.x = x + d.x * .05f;
			pt.y = y + d.y * .05f;
			pt.z = z + d.z * .05f;

			newConfettiDef.groupNum		= pg;
			newConfettiDef.where		= &pt;
			newConfettiDef.delta		= &d;
			newConfettiDef.scale		= 1.0f + RandomFloat();
			newConfettiDef.rot.x		= RandomFloat()*PI2;
			newConfettiDef.rot.y		= RandomFloat()*PI2;
			newConfettiDef.rot.z		= RandomFloat()*PI2;
			newConfettiDef.deltaRot.x	= RandomFloat2()*20.0f;
			newConfettiDef.deltaRot.y	= RandomFloat2()*20.0f;
			newConfettiDef.deltaRot.z	= 0;
			newConfettiDef.alpha		= FULL_ALPHA;
			newConfettiDef.fadeDelay	= 1.0f + RandomFloat();
			if (AddConfettiToGroup(&newConfettiDef))
				break;
		}
	}

		/*********/
		/* OTHER */
		/*********/

	HidePlayer(player);

	if (gPlayerInfo[0].numFreeLives <= 0)								// longer death timer if the game is over (so we can see the YOU LOSE sign
		gDeathTimer[playerNum] = gPlayerInfo[playerNum].invincibilityTimer = 6.0f;
	else
		gDeathTimer[playerNum] = gPlayerInfo[playerNum].invincibilityTimer = 3.0f;

	PlayEffect3D(EFFECT_PLANECRASH, &gCoord);
}



/******************** PLAYER HIT BY WEAPON CALLBACK ***********************/
//
// This callback is invoked whenever a trap's weapon hits a player object (such as gun turret blaster bullets)
//

Boolean PlayerHitByWeaponCallback(ObjNode *weapon, ObjNode *player, OGLPoint3D *hitCoord, OGLVector3D *hitNormal)
{
short	p = player->PlayerNum;
Boolean	playerKilled = false;


				/* DOUBLE-CHECK FOR SHIELD */
				//
				// Most weapons will hit the shield geometry before ever getting here.
				// However, some things like the bomb shockwaves will hit both the
				// shield and the player, so be careful.
				//

	if (gPlayerInfo[p].shieldPower > 0.0f)
	{
		if (weapon->Kind == WEAPON_TYPE_SONICSCREAM)
			PlayerShieldHitByWeaponCallback(weapon, gPlayerInfo[p].shieldObj, hitCoord, hitNormal);
	}

		/* NO SHIELD, SO HURT PLAYER */

	else
	{
		playerKilled = PlayerLoseHealth(p, weapon->Damage, PLAYER_DEATH_TYPE_DEATHDIVE, nil, true);
	}


	return(playerKilled);
}



/******************** TRIGGER CALLBACK:  PLAYER ************************/
//
// This gets called when one player touches another player.
//

Boolean DoTrig_Player(ObjNode *trigger, ObjNode *theNode)
{
float	angle, damage;
Boolean	p1Dead, p2Dead;
short   p1,p2;

	PlayEffect3D(EFFECT_BODYHIT, &trigger->Coord);

			/* THE ANGLE OF IMPACT WILL DETERMINE THE DAMAGE INFLICTED */

	angle = acos(OGLVector3D_Dot(&trigger->MotionVector, &theNode->MotionVector));
	damage = angle / (PI/2.0f);							// damage is based on angle
	if (damage < .5f)
		damage = .5f;


				/* HURT BOTH PLAYERS */

	p1 = trigger->PlayerNum;
	p2 = theNode->PlayerNum;

	p1Dead = PlayerLoseHealth(p1, damage, PLAYER_DEATH_TYPE_DEATHDIVE, nil, true);
	gPlayerInfo[p1].invincibilityTimer = .5f;

	p2Dead = PlayerLoseHealth(p2, damage, PLAYER_DEATH_TYPE_DEATHDIVE, &gCoord, true);
	gPlayerInfo[p2].invincibilityTimer = .5f;


			/*********************************/
			/* SPECIAL STUFF FOR BATTLE MODE */
			/*********************************/
			//
			// We need to check if both players lost simultaneously
			//

	if (gVSMode == VS_MODE_BATTLE)
	{
				/* DID BOTH PLAYERS JUST DIE, AND WERE BOTH OUT OF FREE LIVES?  IF SO, IT'S A DRAW */

		if (p1Dead && p2Dead && (gPlayerInfo[0].numFreeLives <= 0) && (gPlayerInfo[1].numFreeLives <= 0))
		{
			ShowWinLose(0, 2);							// draw
			ShowWinLose(1, 2);							// draw
			StartLevelCompletion(5.0f);
		}
				/* DID PLAYER 1 JUST BITE IT? */
		else
		if (p1Dead && (gPlayerInfo[0].numFreeLives <= 0))
		{
			ShowWinLose(0, 1);							// lose
			ShowWinLose(1, 0);							// win
			StartLevelCompletion(5.0f);
		}
				/* DID PLAYER 2 JUST BITE IT? */
		else
		if (p2Dead && (gPlayerInfo[1].numFreeLives <= 0))
		{
			ShowWinLose(1, 1);							// lose
			ShowWinLose(0, 0);							// win
			StartLevelCompletion(5.0f);
		}
	}


	return(true);				// handle as solid collision
}



#pragma mark -


/********************** CREATE PLAYER SHIELD ************************/
//
// This creates the physical shield object which is always active as long as the player
// has some shield power.  It remains invisible until the shield is hit by something which
// causes it to momentarily become visible.
//

void CreatePlayerShield(short playerNum)
{
ObjNode	*shield, *player = gPlayerInfo[playerNum].objNode;


			/* MAKE SHIELD OBJ */

	if (gPlayerInfo[playerNum].shieldObj == nil)
	{
		gNewObjectDefinition.group 		= MODEL_GROUP_WEAPONS;
		gNewObjectDefinition.type 		= WEAPONS_ObjType_Shield;
		gNewObjectDefinition.scale 		= player->BoundingSphereRadius * 1.1f;
		gNewObjectDefinition.coord	 	= player->Coord;
		gNewObjectDefinition.flags 		= STATUS_BIT_GLOW | STATUS_BIT_DOUBLESIDED | STATUS_BIT_NOZWRITES | STATUS_BIT_ROTXZY |
										STATUS_BIT_UVTRANSFORM | STATUS_BIT_NOFOG;
		gNewObjectDefinition.slot 		= SLOT_OF_DUMB-1;
		gNewObjectDefinition.moveCall 	= nil;
		gNewObjectDefinition.rot 		= 0;
		shield = MakeNewDisplayGroupObject(&gNewObjectDefinition);

		shield->PlayerNum = playerNum;

		shield->CType = CTYPE_WEAPONTEST | CTYPE_MISC | CTYPE_PLAYERSHIELD;
		shield->HitByWeaponHandler 	= PlayerShieldHitByWeaponCallback;

		shield->CustomDrawFunction = DrawPlayerShield;

		gPlayerInfo[playerNum].shieldObj = shield;

		shield->ColorFilter.a = 0.0f;				// start hidden
	}
}


/********************** UPDATE PLAYER SHIELD ***********************/

void UpdatePlayerShield(short playerNum)
{
ObjNode	*shield = gPlayerInfo[playerNum].shieldObj;
ObjNode	*player;
float	fps = gFramesPerSecondFrac;

	if (shield == nil)				// do we have a shield?
		return;

	player = gPlayerInfo[playerNum].objNode;


			/* FADE OUT */

	shield->ColorFilter.a -= fps * 3.0f;
	if (shield->ColorFilter.a <= 0.0f)
	{
		shield->ColorFilter.a = 0.0f;

				/* IS THE SHIELD EMPTY? */

		if (gPlayerInfo[playerNum].shieldPower <= 0.0f)
		{
			DeleteObject(shield);									// nix the shield
			gPlayerInfo[playerNum].shieldObj = nil;
			return;
		}
	}


			/* HIDE WITH PLAYER */

	if (player->StatusBits & STATUS_BIT_HIDDEN)
		shield->StatusBits |= STATUS_BIT_HIDDEN;
	else
		shield->StatusBits &= ~STATUS_BIT_HIDDEN;


			/* DO TEXTURE ANIMATION */

	shield->TextureTransformU 	+= fps * .8f;
	shield->TextureTransformV 	+= fps * .3f;
	shield->TextureTransformU2 	+= fps * -.4f;
	shield->TextureTransformV2 	+= fps * -.5f;



		/* UPDATE TRANSFORMS */


	shield->Coord = player->Coord;
	shield->Rot = player->Rot;

	UpdateObjectTransforms(shield);
}



/***************** PLAYER SHIELD HIT BY WEAPON CALLBACK **********************/

static Boolean PlayerShieldHitByWeaponCallback(ObjNode *bullet, ObjNode *shield, OGLPoint3D *hitCoord, OGLVector3D *hitTriangleNormal)
{
#pragma unused (bullet, hitCoord, hitTriangleNormal)

short	playerNum = shield->PlayerNum;							// see which player's shield got hit

		/* IF SHIELD IS ALREADY GONE THEN LET BULLET THRU */

	if (gPlayerInfo[playerNum].shieldPower <= 0.0f)
	{
		return(false);
	}


				/* SEE IF SHIELD IS GONE */
				//
				// Once shield power is set to 0 it will delete itself during the update function above
				//

	HitPlayerShield(playerNum, bullet->Damage, 1.0, false);

	return(false);
}


/******************** HIT PLAYER SHIELD **************************/

void HitPlayerShield(short playerNum, float damage, float shieldGlowDuration, Boolean disorientPlayer)
{
ObjNode	*shield = gPlayerInfo[playerNum].shieldObj;

	if (gPlayerInfo[playerNum].invincibilityTimer <= 0.0f)					// if still invincible then don't dec the shield
	{
		gPlayerInfo[playerNum].shieldPower -= damage;						// cause damage to shield
		if (gPlayerInfo[playerNum].shieldPower <= 0.0f)
		{
			gPlayerInfo[playerNum].shieldPower = 0.0;
		}
	}

	if (shield)												// make sure shield obj really exists
	{
				/* PLAY EFFECT IF SHIELD WAS ALMOST DIMMED */

		if (shield->ColorFilter.a < .2f)
			PlayEffect_Parms3D(EFFECT_SHIELD, &gPlayerInfo[playerNum].coord, NORMAL_CHANNEL_RATE, .3);


				/* MAKE IT GLOW */

		shield->ColorFilter.a = shieldGlowDuration;
	}



			/* DISORIENT PLAYER */

	if (disorientPlayer)
		DisorientPlayer(gPlayerInfo[playerNum].objNode);
}



/******************* DRAW PLAYER SHIELD ***********************/
//
// This is a bit of a hack.  Basically, we temporarily modify the TriMesh structure
// so that it appears to have all the data needed for drawing multi-textured.
//
//
//

static void DrawPlayerShield(ObjNode *theNode, const OGLSetupOutputType *setupInfo)
{
MOVertexArrayObject	*mo;
MOVertexArrayData	*va;
//MOMaterialObject	*mat;

	mo = gBG3DGroupList[MODEL_GROUP_WEAPONS][WEAPONS_ObjType_Shield];
	va = &mo->objectData;														// point to vertex array data

//	mat = va->materials[0];														// get pointer to material
//	mat->objectData.multiTextureCombine	= MULTI_TEXTURE_COMBINE_ADD;			// set combining mode



			/* MAKE TEMPORARY MODIFICATIONS */

	va->numMaterials 	= 2;
	va->materials[1] = va->materials[0];
	va->uvs[1] = va->uvs[0];


	OGL_ActiveTextureUnit(GL_TEXTURE1);
	glMatrixMode(GL_TEXTURE);					// set texture matrix
	glTranslatef(theNode->TextureTransformU2, theNode->TextureTransformV2, 0);
	glMatrixMode(GL_MODELVIEW);
	OGL_ActiveTextureUnit(GL_TEXTURE0);


			/* DRAW IT */

	MO_DrawObject(theNode->BaseGroup, setupInfo);


			/* RESTORE MODS */

	va->numMaterials 	= 1;
	va->materials[1] 	= nil;
	va->uvs[1] 			= nil;

	OGL_ActiveTextureUnit(GL_TEXTURE1);
	glMatrixMode(GL_TEXTURE);					// set texture matrix
	glLoadIdentity();
	glMatrixMode(GL_MODELVIEW);
	OGL_ActiveTextureUnit(GL_TEXTURE0);

}


#pragma mark -

/********************** CALC MAX ALTITUDE ***************************/

float CalcPlayerMaxAltitude(float x, float z)
{
float	maxAlt;

	switch(gLevelNum)
	{
		case	LEVEL_NUM_ADVENTURE1:
				maxAlt = GetTerrainY(x, z) + MAX_ALTITUDE_DIFF;
				if (maxAlt > MAX_ALTITUDE)
					maxAlt = MAX_ALTITUDE;
				break;

		default:
				maxAlt = MAX_ALTITUDE;
	}


	return(maxAlt);
}












