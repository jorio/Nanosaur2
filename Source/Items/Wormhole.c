/****************************/
/*   	WORMHOLE.C		    */
/* (c)2003 Pangea Software  */
/* By Brian Greenstone      */
/****************************/


/****************************/
/*    EXTERNALS             */
/****************************/


#include "3DMath.h"

extern	float				gFramesPerSecondFrac,gFramesPerSecond;
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
extern	MetaObjectPtr			gBG3DGroupList[MAX_BG3D_GROUPS][MAX_OBJECTS_IN_GROUP];

/****************************/
/*    PROTOTYPES            */
/****************************/

static void MoveEggWormhole(ObjNode *egg);
static void MoveEntryWormhole(ObjNode *theNode);
static void MoveExitWormhole(ObjNode *theNode);
static void MakeExitWormhole(float x, float z);
static void DrawWormhole(ObjNode *theNode, const OGLSetupOutputType *setupInfo);
static void ModifyWormholeTextures(void);
static void SeeIfExitWormholeGrabPlayer(ObjNode *wormhole);


/****************************/
/*    CONSTANTS             */
/****************************/

#define	PLAYER_WORMHOLE_SIZE	4.0f

#define	EGG_WORMHOLE_SIZE		4.0f

#define	MIN_DIST_TO_GET_EGG		1600.0f


/*********************/
/*    VARIABLES      */
/*********************/

#define	TextureTransformU2	SpecialF[0]
#define	TextureTransformV2	SpecialF[1]

Boolean			gOpenPlayerWormhole;
ObjNode			*gExitWormhole = nil;


/******************* INIT WORMHOLES ************************/

void InitWormholes(void)
{
	gOpenPlayerWormhole = false;
	gExitWormhole		= nil;

	ModifyWormholeTextures();

}



/********************* MODIFY WOMRHOLE TEXTURES **************************/
//
// Does some funky multi-texture assignments to the wormhole models
//

static void ModifyWormholeTextures(void)
{
MOVertexArrayObject	*mo;
MOVertexArrayData	*va;
MOMaterialObject	*mat;


			/*******************/
			/* PLAYER WORMHOLE */
			/*******************/

	mo = gBG3DGroupList[MODEL_GROUP_GLOBAL][GLOBAL_ObjType_EntryWormhole];					// point to this object

	if (mo->objectHeader.type == MO_TYPE_GROUP)										// see if need to go into group
		DoFatalAlert("\pModifyWormholeTextures: object is group");


			/* ASSUME MO IS A VERTEX ARRAY OBJECT */

	va = &mo->objectData;														// point to vertex array data

	mat = va->materials[0];														// get pointer to material
	mat->objectData.flags |= BG3D_MATERIALFLAG_MULTITEXTURE;					// set flags for multi-texture

	mat->objectData.multiTextureCombine	= MULTI_TEXTURE_COMBINE_ADD;			// set combining mode


			/****************/
			/* EGG WORMHOLE */
			/****************/

	mo = gBG3DGroupList[MODEL_GROUP_SKELETONBASE + SKELETON_TYPE_WORMHOLE][0];					// point to this object

	if (mo->objectHeader.type == MO_TYPE_GROUP)										// see if need to go into group
		DoFatalAlert("\pModifyWormholeTextures: object is group");


			/* ASSUME MO IS A VERTEX ARRAY OBJECT */

	va = &mo->objectData;														// point to vertex array data

	mat = va->materials[0];														// get pointer to material
	mat->objectData.flags |= BG3D_MATERIALFLAG_MULTITEXTURE;					// set flags for multi-texture

	mat->objectData.multiTextureCombine	= MULTI_TEXTURE_COMBINE_ADD;			// set combining mode


}


#pragma mark -


/************************* ADD EGG WORMHOLE *********************************/

Boolean AddEggWormhole(TerrainItemEntryType *itemPtr, float  x, float z)
{
ObjNode	*newObj;

				/* SEE IF NEED TO CREATE AN EXIT WORMHOLE INSTEAD */

	if (gOpenPlayerWormhole)
	{
		if (gExitWormhole == nil)
			MakeExitWormhole(x,z);
		return(false);
	}

			/****************************/
			/* MAKE NEW SKELETON OBJECT */
			/****************************/

	gNewObjectDefinition.type 		= SKELETON_TYPE_WORMHOLE;
	gNewObjectDefinition.animNum 	= 0;
	gNewObjectDefinition.coord.x 	= x;
	gNewObjectDefinition.coord.y 	= itemPtr->terrainY + 1300.0f;
	gNewObjectDefinition.coord.z 	= z;
	gNewObjectDefinition.flags 		= STATUS_BIT_DOUBLESIDED | STATUS_BIT_UVTRANSFORM |
									STATUS_BIT_NOZWRITES | STATUS_BIT_GLOW;
	gNewObjectDefinition.slot 		= SLOT_OF_DUMB;
	gNewObjectDefinition.moveCall 	= MoveEggWormhole;
	gNewObjectDefinition.rot 		= (float)itemPtr->parm[0] * (PI2/8);
	gNewObjectDefinition.scale 		= EGG_WORMHOLE_SIZE;
	newObj = MakeNewSkeletonObject(&gNewObjectDefinition);

	newObj->TerrainItemPtr = itemPtr;						// keep ptr to item list

	newObj->PlayerNum = itemPtr->parm[1];					// remember this for capture the flag modes

	newObj->CustomDrawFunction = DrawWormhole;
	newObj->What = WHAT_EGGWORMHOLE;

	newObj->Rot.x = .8f;
	UpdateObjectTransforms(newObj);

	return(true);											// item was added
}



/********************* MOVE EGG WORMHOLE **********************/

static void MoveEggWormhole(ObjNode *theNode)
{
float	fps = gFramesPerSecondFrac;

		/* SEE IF GONE */

	if (TrackTerrainItem(theNode))
	{
		DeleteObject(theNode);
		return;
	}


			/* DO TEXTURE ANIMATION */

	theNode->TextureTransformU += fps * .5f;			// spin
	theNode->TextureTransformV -= fps * .3f;			// suck

	theNode->TextureTransformU2 += fps * -.1f;			// spin
	theNode->TextureTransformV2 -= fps * .4f;			// suck


			/* SEE IF NEED TO MAKE VANISH */

	if (gOpenPlayerWormhole)
	{
		if (theNode->Skeleton->AnimNum != 1)						// see if need to change to vanish anim
		{
			MorphToSkeletonAnim(theNode->Skeleton, 1, 2.0f);
			PlayEffect3D(EFFECT_WORMHOLEVANISH, &theNode->Coord);
		}

		theNode->Rot.x += fps;

		theNode->Scale.x =
		theNode->Scale.y =
		theNode->Scale.z -= fps * 6.0f;

		if (theNode->Scale.x <= 0.0f)
		{
				/* SEE IF MAKE PLAYER'S EXIT WORMHOLE HERE */

			if (gExitWormhole == nil)
				MakeExitWormhole(theNode->Coord.x, theNode->Coord.z);

			DeleteObject(theNode);
			return;
		}

		UpdateObjectTransforms(theNode);
	}


				/* UPDATE EFFECT */

	if (theNode->EffectChannel == -1)
		theNode->EffectChannel = PlayEffect_Parms3D(EFFECT_WORMHOLE, &theNode->Coord, NORMAL_CHANNEL_RATE*3/2, 1.0);
	else
	{
		gChannelInfo[theNode->EffectChannel].volumeAdjust = theNode->Scale.x / EGG_WORMHOLE_SIZE;		// set volume based on scale

		Update3DSoundChannel(EFFECT_WORMHOLE, &theNode->EffectChannel, &theNode->Coord);
	}
}



/********************* FIND CLOSEST EGG WORMHOLE IN RANGE *****************************/

ObjNode *FindClosestEggWormholeInRange(short playerNum, OGLPoint3D *pt)
{
ObjNode		*thisNodePtr,*best = nil;
float		d,minDist = 1000000;
OGLPoint3D	mouthPt, mouthPt2;
OGLVector3D	v, v2;
float		dot;

			/*************************/
			/* FIND CLOSEST WORMHOLE */
			/*************************/

	thisNodePtr = gFirstNodePtr;

	do
	{
		if (thisNodePtr->What == WHAT_EGGWORMHOLE)
		{
			if (gVSMode == VS_MODE_CAPTURETHEFLAG)						// only find wormhole valid for this player
				if (thisNodePtr->PlayerNum == playerNum)
					goto next;

				/* POINT MUST BE IN FRONT OF WORMHOLE */

			FindCoordOfJoint(thisNodePtr, 1, &mouthPt);					// calc coord of mouth of wormhole
			FindCoordOfJoint(thisNodePtr, 0, &mouthPt2);

			v.x = mouthPt2.x - mouthPt.x;								// calc aim vector of mouth
			v.y = mouthPt2.y - mouthPt.y;
			v.z = mouthPt2.z - mouthPt.z;
			OGLVector3D_Normalize(&v, &v);

			v2.x = mouthPt2.x - pt->x;									// calc vector from pt to mouth
			v2.y = mouthPt2.y - pt->y;
			v2.z = mouthPt2.z - pt->z;
			OGLVector3D_Normalize(&v2, &v2);

			dot = OGLVector3D_Dot(&v, &v2);							// calc angle between vectors to determine if in front
			if (dot < 0.0f)
			{
					/* POINT MUST BE CLOSE ENOUGH */

				d = OGLPoint3D_Distance(pt, &mouthPt2);					// calc dist to mouth
				if (d < minDist)
				{
					minDist = d;
					best = thisNodePtr;
				}
			}
		}
next:
		thisNodePtr = thisNodePtr->NextNode;		// next node
	}
	while (thisNodePtr != nil);


		/* IS IT IN RANGE? */

	if (minDist < MIN_DIST_TO_GET_EGG)
	{
		return(best);
	}


	return(nil);
}


#pragma mark -


/************************* MAKE ENTRY WORMHOLE *********************************/
//
// Create an entry wormhole at Player 1's position.
//

ObjNode *MakeEntryWormhole(short playerNum)
{
ObjNode	*newObj, *player;
float	x,z;

	x = gPlayerInfo[playerNum].coord.x;
	z = gPlayerInfo[playerNum].coord.z;

	player = gPlayerInfo[playerNum].objNode;

			/*******************/
			/* MAKE NEW OBJECT */
			/*******************/

	gNewObjectDefinition.group		= MODEL_GROUP_GLOBAL;
	gNewObjectDefinition.type 		= GLOBAL_ObjType_EntryWormhole;								// cyc is always 1st model in level bg3d files
	gNewObjectDefinition.coord.x 	= x;
	gNewObjectDefinition.coord.y 	= GetTerrainY(x,z) + MAX_ALTITUDE_DIFF;
	gNewObjectDefinition.coord.z 	= z;
	gNewObjectDefinition.flags 		= STATUS_BIT_DOUBLESIDED | STATUS_BIT_UVTRANSFORM |
									STATUS_BIT_NOZWRITES  | STATUS_BIT_GLOW;
	gNewObjectDefinition.slot 		= SLOT_OF_DUMB;
	gNewObjectDefinition.moveCall 	= MoveEntryWormhole;
	gNewObjectDefinition.rot 		= player->Rot.y;
	gNewObjectDefinition.scale 		= PLAYER_WORMHOLE_SIZE;
	newObj = MakeNewDisplayGroupObject(&gNewObjectDefinition);

	newObj->CustomDrawFunction = DrawWormhole;


	newObj->Rot.x = PI/5;

	UpdateObjectTransforms(newObj);

	newObj->Health = 3.0f;									// set life of wormhole before start to fade out

	newObj->PlayerNum = playerNum;
	gPlayerInfo[playerNum].wormhole = newObj;

	return(newObj);													// item was added
}


/******************* DRAW WORMHOLE ***********************/
//
// This is a bit of a hack.  Basically, we temporarily modify the TriMesh structure
// so that it appears to have all the data needed for drawing multi-textured.
//
//
//

static void DrawWormhole(ObjNode *theNode, const OGLSetupOutputType *setupInfo)
{
MOVertexArrayObject	*mo;
MOVertexArrayData	*va;

	if (theNode->What == WHAT_EGGWORMHOLE)								// gotta handle the two types differently
	{
		SkeletonObjDataType	*skeleton = theNode->Skeleton;
//		Byte		buffNum = skeleton->activeBuffer;
		Byte	buffNum = setupInfo->frameCount & 1;

		va = &skeleton->deformedMeshes[buffNum][0];			// point to triMesh
	}
	else
	{
		mo = gBG3DGroupList[MODEL_GROUP_GLOBAL][GLOBAL_ObjType_EntryWormhole];
		va = &mo->objectData;														// point to vertex array data
	}


			/* MAKE TEMPORARY MODIFICATIONS */


	va->numMaterials 	= 2;
	va->materials[1] = va->materials[0];
	va->uvs[1] = va->uvs[0];


	OGL_ActiveTextureUnit(GL_TEXTURE1);
	glMatrixMode(GL_TEXTURE);					// set texture matrix
	glLoadIdentity();	//-------
	glTranslatef(theNode->TextureTransformU2, theNode->TextureTransformV2, 0);
	glMatrixMode(GL_MODELVIEW);
	OGL_ActiveTextureUnit(GL_TEXTURE0);


			/* DRAW IT */

	if (theNode->What == WHAT_EGGWORMHOLE)
		DrawSkeleton(theNode, setupInfo);
	else
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




/********************* MOVE ENTRY WORMHOLE **********************/

static void MoveEntryWormhole(ObjNode *theNode)
{
float	fps = gFramesPerSecondFrac;
float	oldH = theNode->Health;

	theNode->Health -= fps;
	if (theNode->Health < 0.0f)
	{
		if (oldH >= 0.0f)
			PlayEffect_Parms3D(EFFECT_WORMHOLEVANISH, &theNode->Coord, NORMAL_CHANNEL_RATE, 2.0);

		theNode->Scale.x =
		theNode->Scale.y =
		theNode->Scale.z -= fps * 8.0f;
		if (theNode->Scale.x <= 0.0f)
		{
			gPlayerInfo[theNode->PlayerNum].wormhole = nil;
			DeleteObject(theNode);
			return;
		}
	}

	theNode->TextureTransformU += fps * .5f;			// spin
	theNode->TextureTransformV += fps * .3f;			// spit

	theNode->TextureTransformU2 += fps * -.1f;			// spin
	theNode->TextureTransformV2 += fps * .4f;			// spit


	UpdateObjectTransforms(theNode);



				/* UPDATE EFFECT */

	if (theNode->EffectChannel == -1)
		theNode->EffectChannel = PlayEffect_Parms3D(EFFECT_WORMHOLE, &theNode->Coord, NORMAL_CHANNEL_RATE, 1.0);
	else
		Update3DSoundChannel(EFFECT_WORMHOLE, &theNode->EffectChannel, &theNode->Coord);


}


#pragma mark -


/************************* MAKE EXIT WORMHOLE *********************************/

static void MakeExitWormhole(float x, float z)
{
			/*******************/
			/* MAKE NEW OBJECT */
			/*******************/

	gNewObjectDefinition.group		= MODEL_GROUP_GLOBAL;
	gNewObjectDefinition.type 		= GLOBAL_ObjType_EntryWormhole;
	gNewObjectDefinition.coord.x 	= x;
	gNewObjectDefinition.coord.y 	= GetTerrainY(x,z) + MAX_ALTITUDE_DIFF;
	gNewObjectDefinition.coord.z 	= z;
	gNewObjectDefinition.flags 		= STATUS_BIT_DOUBLESIDED | STATUS_BIT_UVTRANSFORM |	STATUS_BIT_NOZWRITES  |
									 STATUS_BIT_GLOW;
	gNewObjectDefinition.slot 		= SLOT_OF_DUMB;
	gNewObjectDefinition.moveCall 	= MoveExitWormhole;
	gNewObjectDefinition.rot 		= 0;
	gNewObjectDefinition.scale 		= .001f;									// start shrunken
	gExitWormhole = MakeNewDisplayGroupObject(&gNewObjectDefinition);

	gExitWormhole->CustomDrawFunction = DrawWormhole;

	gExitWormhole->Rot.x = PI/8;


	UpdateObjectTransforms(gExitWormhole);


	PlayEffect_Parms3D(EFFECT_WORMHOLEAPPEAR, &gExitWormhole->Coord, NORMAL_CHANNEL_RATE, 2.0);
}


/********************* MOVE EXIT WORMHOLE **********************/

static void MoveExitWormhole(ObjNode *theNode)
{
float	fps = gFramesPerSecondFrac;
float	s;

			/* SCALE IT UP */

	s = theNode->Scale.x += fps * 5.0f;
	if (s > PLAYER_WORMHOLE_SIZE)
		s = PLAYER_WORMHOLE_SIZE;

	theNode->Scale.x =
	theNode->Scale.y =
	theNode->Scale.z = s;


		/* TEXTURE ANIMATION */

	theNode->TextureTransformU -= fps * .5f;			// spin
	theNode->TextureTransformV -= fps * .3f;			// spit

	theNode->TextureTransformU2 -= fps * -.1f;			// spin
	theNode->TextureTransformV2 -= fps * .4f;			// spit

	UpdateObjectTransforms(theNode);


			/* UPDATE EFFECT */

	if (theNode->EffectChannel == -1)
		theNode->EffectChannel = PlayEffect_Parms3D(EFFECT_WORMHOLE, &theNode->Coord, NORMAL_CHANNEL_RATE, 1.4);
	else
	{
		Update3DSoundChannel(EFFECT_WORMHOLE, &theNode->EffectChannel, &theNode->Coord);
	}


		/* SEE IF GRAB PLAYER */

	if (s == PLAYER_WORMHOLE_SIZE)									// only grab when full size
	{
		SeeIfExitWormholeGrabPlayer(theNode);
	}
}


/******************** SEE IF EXIT WORMHOLE GRAB PLAYER **********************/

static void SeeIfExitWormholeGrabPlayer(ObjNode *wormhole)
{
ObjNode				*player = gPlayerInfo[0].objNode;
OGLVector3D			v,v2;
static OGLVector3D	down = {0,-1,0};
float				dot;


			/* SEE IF PLAYER IS IN RANGE */

	if (OGLPoint3D_Distance(&player->Coord, &wormhole->Coord) > 1000.0f)
		return;


			/* PLAYER MUST BE IN FRONT OF MOUTH */

	OGLVector3D_Transform(&down, &wormhole->BaseTransformMatrix, &v);	// calc aim vector of mouth

	v2.x = wormhole->Coord.x - player->Coord.x;							// calc vector from player to mouth
	v2.y = wormhole->Coord.y - player->Coord.y;
	v2.z = wormhole->Coord.z - player->Coord.z;
	OGLVector3D_Normalize(&v2, &v2);

	dot = OGLVector3D_Dot(&v, &v2);										// calc angle between vectors to determine if in front or back
	if (dot > 0.0f)
		return;


			/* PLAYER MUST BE AIMING AT MOUTH */

//	dot = OGLVector3D_Dot(&player->MotionVector, &v);
//
//	if (dot > 0.0f)
//		return;


			/****************/
			/* TAKE CONTROL */
			/****************/

	DropEgg_NoWormhole(player->PlayerNum);				// drop any egg
	JetpackOff(player->PlayerNum);

	MorphToSkeletonAnim(player->Skeleton, PLAYER_ANIM_ENTERWORMHOLE, 2.0f);

	player->MotionVector = v2;

	gCameraInExitMode = true;
}





















