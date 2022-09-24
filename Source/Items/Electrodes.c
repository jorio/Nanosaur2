/****************************/
/*   	ELECTRODES.C	    */
/* (c)2003 Pangea Software  */
/* By Brian Greenstone      */
/****************************/


/****************************/
/*    EXTERNALS             */
/****************************/


#include "game.h"


/****************************/
/*    PROTOTYPES            */
/****************************/

static Boolean ElectrodeHitByWeaponCallback(ObjNode *bullet, ObjNode *mine, OGLPoint3D *hitCoord, OGLVector3D *hitTriangleNormal);
static Boolean DoTrig_Electrode(ObjNode *mine, ObjNode *player);
static void MoveElectrode(ObjNode *theNode);
static void DoElectrodeZap(ObjNode *fromObj, ObjNode *toObj);
static short GetFreeZapSlot(void);
static void DrawZaps(ObjNode *dummy, const OGLSetupOutputType *setupInfo);
static void MoveZaps(ObjNode *theNode);
static void AllocateZapGeometry(short zapSlot);
static void FreeZap(short zapNum);


/****************************/
/*    CONSTANTS             */
/****************************/

#define	ELECTRODE_SCALE	2.0f

#define	ELECTRODE_TOP	(1200.0f * ELECTRODE_SCALE)

#define	MAX_ELECTRODE_TARGETS	8



#define	MAX_ZAPS		30
#define	MAX_ZAP_ENDPOINTS	30


typedef struct
{
	Boolean		isUsed;
	long		numEndpoints;
	float		alpha;

	short		endpointSparkles[2];

	OGLPoint3D	endpointCoords[MAX_ZAP_ENDPOINTS];
	OGLVector3D	endpointDeltas[MAX_ZAP_ENDPOINTS];

	MOVertexArrayData	triMesh[2];								// double-buffered VAR trimeshes
}ZapType;


#define	ZAP_THICKNESS		20.0f

#define	ZAP_RANDOM_SIZE		20.0f

#define	ENDPOINT_OFFSET		70.0f

/*********************/
/*    VARIABLES      */
/*********************/



static	short			gNumZaps = 0;
static	ZapType			gZaps[MAX_ZAPS];

static	short			gZapBuffer = 0;								// which VAR double buffer? 0 or 1


/************************* ADD ELECTRODE *********************************/

Boolean AddElectrode(TerrainItemEntryType *itemPtr, float  x, float z)
{
ObjNode	*pole, *topbot, *middle;

				/*************/
				/* MAKE POLE */
				/*************/

	gNewObjectDefinition.group 		= MODEL_GROUP_GLOBAL;
	gNewObjectDefinition.type 		= GLOBAL_ObjType_Electrode_Pole;
	gNewObjectDefinition.scale 		= ELECTRODE_SCALE;
	gNewObjectDefinition.coord.x 	= x;
	gNewObjectDefinition.coord.z 	= z;
	gNewObjectDefinition.coord.y 	= GetMinTerrainY(x,z, gNewObjectDefinition.group, gNewObjectDefinition.type, gNewObjectDefinition.scale);
	gNewObjectDefinition.flags 		= gAutoFadeStatusBits;
	gNewObjectDefinition.slot 		= 161;
	gNewObjectDefinition.moveCall 	= MoveElectrode;
	gNewObjectDefinition.rot 		= 0;
	pole = MakeNewDisplayGroupObject(&gNewObjectDefinition);

	pole->TerrainItemPtr = itemPtr;								// keep ptr to item list


	if (itemPtr->flags & ITEM_FLAGS_USER1)			// see if already got blown up
	{
		pole->Health 		= 0;
		pole->DeltaRot.y 	= 0;
		pole->ColorFilter.r =
		pole->ColorFilter.g =
		pole->ColorFilter.b = .3;
		pole->CType			= CTYPE_SOLIDTOENEMY | CTYPE_WEAPONTEST | CTYPE_PLAYERTEST;
	}
	else
	{
		pole->What 			= WHAT_ELECTRODE;
		pole->Health 		= 1.0f;
		pole->DeltaRot.y 	= PI;
		pole->CType 		= CTYPE_SOLIDTOENEMY | CTYPE_WEAPONTEST | CTYPE_PLAYERTEST | CTYPE_AUTOTARGETWEAPON;
	}

			/* SET COLLISION STUFF */

	pole->CBits				= CBITS_ALLSOLID;
	CreateCollisionBoxFromBoundingBox(pole, 1, 1);

	pole->TriggerCallback = DoTrig_Electrode;
	pole->HitByWeaponHandler = ElectrodeHitByWeaponCallback;

	pole->Timer = RandomFloat() * 1.0f;

	pole->HeatSeekHotSpotOff.x = 0;
	pole->HeatSeekHotSpotOff.y = 600.0f;
	pole->HeatSeekHotSpotOff.z = 0;




				/*********************/
				/* MAKE TOP & BOTTOM */
				/*********************/

	gNewObjectDefinition.type 		= GLOBAL_ObjType_Electrode_TopBottom;
	gNewObjectDefinition.slot++;
	gNewObjectDefinition.moveCall 	= nil;
	topbot = MakeNewDisplayGroupObject(&gNewObjectDefinition);

			/* SET COLLISION STUFF */

	topbot->CType 				= CTYPE_SOLIDTOENEMY | CTYPE_WEAPONTEST | CTYPE_PLAYERTEST;
	topbot->TriggerCallback 	= DoTrig_Electrode;
	topbot->HitByWeaponHandler 	= ElectrodeHitByWeaponCallback;

	pole->ChainNode = topbot;
	topbot->ChainHead = pole;


				/***************/
				/* MAKE MIDDLE */
				/***************/

	gNewObjectDefinition.type 		= GLOBAL_ObjType_Electrode_Middle;
	gNewObjectDefinition.slot++;
	middle = MakeNewDisplayGroupObject(&gNewObjectDefinition);

	middle->CType 				= CTYPE_SOLIDTOENEMY | CTYPE_WEAPONTEST | CTYPE_PLAYERTEST;
	middle->TriggerCallback 	= DoTrig_Electrode;
	middle->HitByWeaponHandler 	= ElectrodeHitByWeaponCallback;


	topbot->ChainNode = middle;
	middle->ChainHead = topbot;


	return(true);													// item was added
}


/********************** MOVE ELECTRODE ***********************/

static void MoveElectrode(ObjNode *pole)
{
ObjNode	*topbot, *middle;
float	fps = gFramesPerSecondFrac;
float	c;
Boolean		isAlive = pole->What == WHAT_ELECTRODE;

		/* SEE IF GONE */

	if (TrackTerrainItem(pole))
	{
		DeleteObject(pole);
		return;
	}

		/****************/
		/* ROTATE PARTS */
		/****************/

	topbot = pole->ChainNode;
	middle = topbot->ChainNode;


	topbot->Rot.y += pole->DeltaRot.y * fps;
	middle->Rot.y -= pole->DeltaRot.y * fps;

	UpdateObjectTransforms(topbot);
	UpdateObjectTransforms(middle);


				/* UPDATE EFFECT */

	if (pole->EffectChannel == -1)
		pole->EffectChannel = PlayEffect_Parms3D(EFFECT_ELECTRODEHUM, &pole->Coord, NORMAL_CHANNEL_RATE + (MyRandomLong() & 0x1fff), .8);
	else
		Update3DSoundChannel(EFFECT_ELECTRODEHUM, &pole->EffectChannel, &pole->Coord);



			/* SEE IF IS STILL ACTIVE */

	if (!isAlive)
	{
		MakeSteam(pole, pole->Coord.x, pole->Coord.y, pole->Coord.z);
		return;
	}



			/* FLICKER */

	c = .3f + (pole->Health * .7f);					// calc dim based on health

	topbot->ColorFilter.r =
	topbot->ColorFilter.b =
	topbot->ColorFilter.g = (.7f + RandomFloat() * .3f) * c;

	middle->ColorFilter.r =
	middle->ColorFilter.b =
	middle->ColorFilter.g = (.7f + RandomFloat() * .3f) * c;


	/**************/
	/* SEE IF ZAP */
	/**************/

	pole->Timer -= fps;
	if (pole->Timer <= 0.0f)
	{
		ObjNode	*thisNode, *theTarget;
		ObjNode	*targets[MAX_ELECTRODE_TARGETS];
		short	numTargets = 0;
		float	x = pole->Coord.x;
		float	z = pole->Coord.z;

		pole->Timer = RandomFloat() * .35f;				// reset timer

		/* BUILD LIST OF ELIGIBLE TARGET ELECTRODES */

		thisNode = gFirstNodePtr;
		do
		{
			if (thisNode != pole)
			{
				if (thisNode->What == WHAT_ELECTRODE)		// only look for electrodes
				{
					if (CalcQuickDistance(x,z, thisNode->Coord.x, thisNode->Coord.z) < 4000.0f)	// in range?
					{
						targets[numTargets] = thisNode;
						numTargets++;
						if (numTargets >= MAX_ELECTRODE_TARGETS)
							break;
					}
				}
			}
			thisNode = thisNode->NextNode;
		}while(thisNode != nil);

				/* CHOOSE A RANDOM TARGET */

		if (numTargets > 0)
		{
			theTarget = targets[RandomRange(0, numTargets-1)];
			DoElectrodeZap(pole, theTarget);
		}
	}
}


#pragma mark -


/******************** TRIGGER CALLBACK:  ELECTRODE ************************/
//
// Returns TRUE if want to handle hit as a solid
//

static Boolean DoTrig_Electrode(ObjNode *mine, ObjNode *player)
{
	PlayerSmackedIntoObject(player, mine, PLAYER_DEATH_TYPE_EXPLODE);

	return(true);
}


/*************************** ELECTRODE HIT BY WEAPON CALLBACK *****************************/
//
// Returns true if object should stop bullet.
//

static Boolean ElectrodeHitByWeaponCallback(ObjNode *bullet, ObjNode *theNode, OGLPoint3D *hitCoord, OGLVector3D *hitTriangleNormal)
{
float	c;
ObjNode	*pole = theNode;

#pragma unused (hitCoord, hitTriangleNormal, theNode)


	while(pole->ChainHead)							// scan for the parent object of the whole electrode gizmo
		pole = pole->ChainHead;

	pole->Health -= bullet->Damage * .8f;
	if (pole->Health <= 0.0f)
	{
		pole->Health = 0;
		pole->What = 0;								// no longer a zappable electrode
		pole->TerrainItemPtr->flags |= ITEM_FLAGS_USER1;		// set flag so will come back dead next time
		pole->CType &= ~CTYPE_AUTOTARGETWEAPON;		// dont auto-target anymore
	}


		/* MAKE DIMMER */

	c = .3f + (pole->Health * .7f);

	pole->ColorFilter.r =
	pole->ColorFilter.g =
	pole->ColorFilter.b = c;


		/* SLOW SPIN */

	pole->DeltaRot.y = pole->Health * PI;


	return(true);
}



#pragma mark -


/*************************** DO ELECTRODE ZAP **************************/

static void DoElectrodeZap(ObjNode *fromObj, ObjNode *toObj)
{

int				numEndpoints, i;
float			x,y,z, dist, o;
OGLVector3D		boltVector, v;
OGLPoint3D		*endPoints;
short			zapSlot;


			/* IF BOTH ELECTRODES ARE CULLED THEN DON'T ACTUALLY MAKE THE ZAP */

	if (IsObjectTotallyCulled(fromObj) && IsObjectTotallyCulled(toObj))
		return;

			/* GET NEW ZAP */

	zapSlot = GetFreeZapSlot();
	if (zapSlot == -1)
		return;

	endPoints = &gZaps[zapSlot].endpointCoords[0];						// point to endpoints list

	gZaps[zapSlot].alpha = 1.3f;										// set inital alpha of this zap


		/***********************/
		/* CALCULATE ENDPOINTS */
		/***********************/


		/* DETERMINE HOW MANY ENDPOINTS */

	dist = OGLPoint3D_Distance(&fromObj->Coord, &toObj->Coord);

	x = fromObj->Coord.x;
	y = fromObj->Coord.y + RandomFloat() * ELECTRODE_TOP;
	z = fromObj->Coord.z;

	if (gGamePrefs.lowRenderQuality)
		numEndpoints = dist * .01f;									// calc # zap endpoints based on distance
	else
		numEndpoints = dist * .015f;									// calc # zap endpoints based on distance

	if (numEndpoints > MAX_ZAP_ENDPOINTS)
		numEndpoints = MAX_ZAP_ENDPOINTS;
	if (numEndpoints < 2)
		numEndpoints = 2;

	gZaps[zapSlot].numEndpoints = numEndpoints;


		/* CALC VECTOR FROM->TO */

	boltVector.x = toObj->Coord.x - x;
	boltVector.y = (toObj->Coord.y + 30.0f + RandomFloat() * ELECTRODE_TOP) - y;
	boltVector.z = toObj->Coord.z - z;

	FastNormalizeVector(boltVector.x, boltVector.y, boltVector.z, &v);	// also create a normalize version

	boltVector.x -= v.x * ENDPOINT_OFFSET;								// offset to get endoing away from center of pole
	boltVector.z -= v.z * ENDPOINT_OFFSET;

	o = 1.0f / (float)(numEndpoints-1);
	boltVector.x *= o;													// divide vector length for multiple segments
	boltVector.y *= o;
	boltVector.z *= o;


		/* SET STARTING POINT */

	endPoints[0].x = x + v.x * ENDPOINT_OFFSET;							// offset to get endoing away from center of pole
	endPoints[0].z = z + v.z * ENDPOINT_OFFSET;
	endPoints[0].y = y;

		/* CALC INTERMEDIATE & END POINTS */

	for (i = 1; i < numEndpoints; i++)
	{
		x += boltVector.x;										// calc linear endpoint value
		y += boltVector.y;
		z += boltVector.z;

		endPoints[i].x = x;
		endPoints[i].y = y;
		endPoints[i].z = z;
	}


		/*************************/
		/* ALLOCATE ZAP GEOMETRY */
		/*************************/

	AllocateZapGeometry(zapSlot);




		/**************************/
		/* MAKE ENDPOINT SPARKLES */
		/**************************/

			/* FROM */

	i = gZaps[zapSlot].endpointSparkles[0] = GetFreeSparkle(nil);			// make new sparkle
	if (i != -1)
	{
		gSparkles[i].flags = SPARKLE_FLAG_OMNIDIRECTIONAL | SPARKLE_FLAG_RANDOMSPIN | SPARKLE_FLAG_FLICKER;
		gSparkles[i].where = endPoints[0];

		gSparkles[i].color.r = 1;
		gSparkles[i].color.g = 1;
		gSparkles[i].color.b = 1;
		gSparkles[i].color.a = 1;

		gSparkles[i].scale 	= 80.0f;
		gSparkles[i].separation = 10.0f;

		gSparkles[i].textureNum = PARTICLE_SObjType_BlueSpark;
	}

			/* TO */

	i = gZaps[zapSlot].endpointSparkles[1] = GetFreeSparkle(nil);			// make new sparkle
	if (i != -1)
	{
		gSparkles[i].flags = SPARKLE_FLAG_OMNIDIRECTIONAL | SPARKLE_FLAG_RANDOMSPIN | SPARKLE_FLAG_FLICKER;
		gSparkles[i].where = endPoints[numEndpoints-1];

		gSparkles[i].color.r = 1;
		gSparkles[i].color.g = 1;
		gSparkles[i].color.b = 1;
		gSparkles[i].color.a = 1;

		gSparkles[i].scale 	= 80.0f;
		gSparkles[i].separation = 10.0f;

		gSparkles[i].textureNum = PARTICLE_SObjType_BlueSpark;
	}




}



#pragma mark -


/******************** INIT ZAPS ***************************/

void InitZaps(void)
{
ObjNode		*newObj;
short		i;

	gZapBuffer = 0;

	gNumZaps = 0;

	for (i = 0; i < MAX_ZAPS; i++)
		gZaps[i].isUsed = false;				// all slots are free


		/***********************************************************************/
		/* CREATE DUMMY CUSTOM OBJECT TO CAUSE ZAP DRAWING AT THE DESIRED TIME */
		/***********************************************************************/

	gNewObjectDefinition.genre		= CUSTOM_GENRE;
	gNewObjectDefinition.slot 		= SLOT_OF_DUMB + 80;
	gNewObjectDefinition.moveCall 	= MoveZaps;
	gNewObjectDefinition.flags 		= STATUS_BIT_DOUBLESIDED|STATUS_BIT_NOLIGHTING|STATUS_BIT_NOZWRITES|STATUS_BIT_NOFOG|
										STATUS_BIT_DONTCULL | STATUS_BIT_GLOW;

	newObj = MakeNewObject(&gNewObjectDefinition);
	newObj->CustomDrawFunction = DrawZaps;

	newObj->VertexArrayMode = VERTEX_ARRAY_RANGE_TYPE_ZAPS1;

	newObj->Damage = 1.0f;

}


/********************* ALLOCATE ZAP GEOMETRY **************************/
//
// Initializes the trimesh vertex array data for this zap
//

static void AllocateZapGeometry(short zapSlot)
{
long	numEndpoints = gZaps[zapSlot].numEndpoints;
long	numVerts = numEndpoints * 2;
long	numTriangles = numVerts - 2;
short	i, p, t, b;
float	u;
MOVertexArrayData	*triMesh;

	for (b = 0; b < 2; b++)													// allocate for both double-buffers
	{
		triMesh = &gZaps[zapSlot].triMesh[b];								// point to VAR double-buffer #n


		triMesh->VARtype 		= VERTEX_ARRAY_RANGE_TYPE_ZAPS1+b;
		triMesh->numMaterials 	= 1;
		triMesh->materials[0]	= gSpriteGroupList[SPRITE_GROUP_PARTICLES][PARTICLE_SObjType_ZapBeam].materialObject;	// set illegal ref
		triMesh->numPoints 		= numVerts;
		triMesh->numTriangles 	= numTriangles;


					/* ALLOCATE VARS */

		triMesh->points 		= OGL_AllocVertexArrayMemory(sizeof(OGLPoint3D) * numVerts, VERTEX_ARRAY_RANGE_TYPE_ZAPS1+b);
		triMesh->uvs[0]			= OGL_AllocVertexArrayMemory(sizeof(OGLTextureCoord) * numVerts, VERTEX_ARRAY_RANGE_TYPE_ZAPS1+b);
		triMesh->triangles		= OGL_AllocVertexArrayMemory(sizeof(MOTriangleIndecies) * numTriangles, VERTEX_ARRAY_RANGE_TYPE_ZAPS1+b);

		triMesh->normals 		= nil;
		triMesh->colorsFloat 	= nil;


				/**********************/
				/* BUILD THE GEOMETRY */
				/**********************/

				/* SET VERTEX POINTS */

		p = 0;
		for (i = 0; i < numEndpoints; i++)
		{
			triMesh->points[p].x = gZaps[zapSlot].endpointCoords[i].x;				// top vertex
			triMesh->points[p].y = gZaps[zapSlot].endpointCoords[i].y + ZAP_THICKNESS;
			triMesh->points[p].z = gZaps[zapSlot].endpointCoords[i].z;

			triMesh->points[p+1].x = gZaps[zapSlot].endpointCoords[i].x;				// bottom vertex
			triMesh->points[p+1].y = gZaps[zapSlot].endpointCoords[i].y - ZAP_THICKNESS;
			triMesh->points[p+1].z = gZaps[zapSlot].endpointCoords[i].z;

			p += 2;
		}


				/* SET VERTEX UVS */

		p = 0;
		u = 0;
		for (i = 0; i < numEndpoints; i++)
		{
			triMesh->uvs[0][p].u = u;									// top vertex
			triMesh->uvs[0][p].v = 1.0;

			triMesh->uvs[0][p+1].u = u;								// bottom vertex
			triMesh->uvs[0][p+1].v = 0.0;

			u += .4f;
			p += 2;
		}

				/* SET TRIANGLES */

		t = 0;
		p = 0;
		for (i = 0; i < (numEndpoints-1); i++)
		{
			triMesh->triangles[t].vertexIndices[0] = p;
			triMesh->triangles[t].vertexIndices[1] = p+1;
			triMesh->triangles[t].vertexIndices[2] = p+2;
			t++;

			triMesh->triangles[t].vertexIndices[0] = p+2;
			triMesh->triangles[t].vertexIndices[1] = p+1;
			triMesh->triangles[t].vertexIndices[2] = p+3;
			t++;
			p += 2;
		}
	}
}



/******************* MOVE ZAPS *****************************/

static void MoveZaps(ObjNode *theNode)
{
#pragma unused (theNode)
short	i, j, p, numEndpoints;
float	fps = gFramesPerSecondFrac;
MOVertexArrayData	*triMesh;
OGLLineSegment		lineSeg;
ObjNode				*hitObj;
OGLPoint3D			worldHitCoord;

	gZapBuffer ^= 1;									// toggle buffer to move & then draw

	for (i = 0; i < MAX_ZAPS; i++)
	{
		if (!gZaps[i].isUsed)							// is this one active
			continue;


				/************/
				/* FADE OUT */
				/************/

		gZaps[i].alpha -= fps * 1.2f;
		if (gZaps[i].alpha <= 0.0f)
		{
			FreeZap(i);
			continue;
		}

		numEndpoints = gZaps[i].numEndpoints;

				/************************/
				/* RANDOMIZE THE COORDS */
				/************************/

		triMesh = &gZaps[i].triMesh[gZapBuffer];									// point to VAR double-buffer #n

		p = 0;
		for (j = 0; j < numEndpoints; j++)
		{
			float	y = gZaps[i].endpointCoords[j].y + RandomFloat2() * ZAP_RANDOM_SIZE;
			float	thick = (ZAP_THICKNESS / 3) + ZAP_THICKNESS * RandomFloat();

			triMesh->points[p].y = y + thick;
			triMesh->points[p+1].y = y - thick;

			p += 2;
		}

		OGL_SetVertexArrayRangeDirty(VERTEX_ARRAY_RANGE_TYPE_ZAPS1 + gZapBuffer);


				/*********************/
				/* SEE IF HIT PLAYER */
				/*********************/

		lineSeg.p1 = gZaps[i].endpointCoords[0];
		lineSeg.p2 = gZaps[i].endpointCoords[numEndpoints-1];

		hitObj = OGL_DoLineSegmentCollision_ObjNodes(&lineSeg, STATUS_BIT_HIDDEN, CTYPE_PLAYERSHIELD | CTYPE_ENEMY | CTYPE_PLAYER1 | CTYPE_PLAYER2, &worldHitCoord, nil, nil, false);
		if (hitObj)
		{
			if (hitObj->HitByWeaponHandler)												// see if there is a handler for this object
				hitObj->HitByWeaponHandler(theNode, hitObj, nil, nil);
		}
	}
}



/******************* DRAW ZAPS *****************************/

static void DrawZaps(ObjNode *dummy, const OGLSetupOutputType *setupInfo)
{
#pragma unused (dummy)

short	i;

	OGL_SetColor4f(1,1,1,1);

	for (i = 0; i < MAX_ZAPS; i++)
	{
		if (!gZaps[i].isUsed)							// is this one active
			continue;

		gGlobalTransparency = gZaps[i].alpha;

		MO_DrawGeometry_VertexArray(&gZaps[i].triMesh[gZapBuffer], setupInfo);
	}

	gGlobalTransparency = 1.0f;
}


/*********************** GET FREE ZAP SLOT ***********************/

static short GetFreeZapSlot(void)
{
short	i;

	for (i = 0; i < MAX_ZAPS; i++)
	{
		if (!gZaps[i].isUsed)
		{
			gZaps[i].isUsed = true;
			return(i);
		}
	}
	return(-1);
}


/******************** FREE ZAP ***********************/

static void FreeZap(short zapNum)
{
MOVertexArrayData	*triMesh;
short	b, i;

	for (b = 0; b < 2; b++)
	{
		triMesh = &gZaps[zapNum].triMesh[b];

		OGL_FreeVertexArrayMemory(triMesh->points, VERTEX_ARRAY_RANGE_TYPE_ZAPS1+b);
		OGL_FreeVertexArrayMemory(triMesh->uvs[0], VERTEX_ARRAY_RANGE_TYPE_ZAPS1+b);
		OGL_FreeVertexArrayMemory(triMesh->triangles, VERTEX_ARRAY_RANGE_TYPE_ZAPS1+b);


	}


		/* FREE SPARKLES */

	for (i = 0; i < 2; i++)
	{
		if (gZaps[zapNum].endpointSparkles[i] != -1)
		{
			DeleteSparkle(gZaps[zapNum].endpointSparkles[i]);
			gZaps[zapNum].endpointSparkles[i] = -1;
		}
	}


	gZaps[zapNum].isUsed = false;
}











