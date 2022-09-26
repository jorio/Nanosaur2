/****************************/
/*   	INFOBAR.C		    */
/* (c)2003 Pangea Software  */
/* By Brian Greenstone      */
/****************************/


/****************************/
/*    EXTERNALS             */
/****************************/

#include	"game.h"

/****************************/
/*    PROTOTYPES            */
/****************************/

static void Infobar_DrawMap(void);
static void Infobar_DrawCrosshairs(void);
static void DrawAnaglyphCrosshairs(ObjNode *theNode);
static void Infobar_DrawPlayerLabels(void);
static void Infobar_DrawRaceInfo(void);
static void Infobar_DrawLives(void);
static void Infobar_DrawWeaponInventory(void);
static void Infobar_DrawHealth(void);
static void Infobar_DrawShield(void);
static void Infobar_DrawFuel(void);
static void Infobar_DrawEggs(void);
static void Infobar_CaptureFlagEggs(void);
static void Infobar_DrawPlayerArrows(void);

static void MoveLapMessage(ObjNode *theNode);



/****************************/
/*    CONSTANTS             */
/****************************/


#define MAP_SCALE	80.0f
#define MAP_SCALE2	(MAP_SCALE * .8 * .5)
#define	MAP_X		(665.0f - MAP_SCALE)
#define	MAP_Y		((480 - MAP_SCALE * .6f))

#define	LIVES_SCALE		25.0f
#define	LIVES_X			0.0f
#define	LIVES_Y			(457.5f - LIVES_SCALE * .6f)

#define	WEAPON_X		150.0f
#define	WEAPON_Y		0
#define	WEAPON_SCALE	85.0f


#define	HEALTH_SCALE	43.0f
#define	HEALTH_SCALE2	(HEALTH_SCALE * .9f * .5f)					// smaller scale for the red meter sprite
#define	HEALTH_X		(HEALTH_SCALE/2)
#define	HEALTH_Y		(HEALTH_SCALE/2)

#define	SHIELD_SCALE	HEALTH_SCALE
#define SHIELD_SCALE2	HEALTH_SCALE2
#define	SHIELD_X		(HEALTH_X + HEALTH_SCALE)
#define	SHIELD_Y		HEALTH_Y

#define	FUEL_SCALE		HEALTH_SCALE
#define	FUEL_SCALE2		HEALTH_SCALE2
#define	FUEL_X			(SHIELD_X + SHIELD_SCALE)
#define	FUEL_Y			HEALTH_Y

#define	PLAYER_X		0.0f
#define	PLAYER_Y		HEALTH_SCALE
#define	PLAYER_SCALE	60.0f


#define	EGGS_X			558.0f
#define	EGGS_Y			0
#define	EGGS_SCALE		14.0f

#define	CAP_EGGS_X			520.0f
#define	CAP_EGGS_Y			0
#define	CAP_EGGS_SCALE		25.0f

#define ARROW_SCALE		37.5f


#define	GUNSIGHT_SCALE	15.0f

#define	DIGIT_WIDTH		.58f

#define	INFOBAR_ANAGLYPHZ_Z	0.0f

/*********************/
/*    VARIABLES      */
/*********************/

OGLRect gLogicalRect;

Boolean			gHideInfobar = false;

ObjNode			*gFinalPlaceObj = nil;



			/* OVERHEAD MAP */

static MOMaterialObject	*gOverheadMapMaterial = nil;

static MOVertexArrayData	gOHMTriMesh;
static MOTriangleIndecies	gOHMTriangles[2] = {{{0, 1, 2}}, {{2, 0, 3}}};
static OGLTextureCoord		gOHMuv1[4];
static OGLTextureCoord		gOHMuv2[4] = {{0,0}, {0,1}, {1,1}, {1,0}};
static OGLPoint3D			gOHMPoints[4];


			/* HEALTH */

static MOVertexArrayData	gHealthTriMesh;
static MOTriangleIndecies	gHealthTriangles[2] = {{{0, 1, 2}}, {{2, 0, 3}}};
static OGLTextureCoord		gHealthuv1[4] = {{0,1}, {1,1}, {1,0}, {0,0}};
static OGLTextureCoord		gHealthuv2[4] = {{0,1}, {1,1}, {1,0}, {0,0}};
static OGLPoint3D			gHealthPoints[4] =
{
	{HEALTH_X - HEALTH_SCALE2,	HEALTH_Y - HEALTH_SCALE2, 		0},
	{HEALTH_X + HEALTH_SCALE2,	HEALTH_Y - HEALTH_SCALE2, 		0},
	{HEALTH_X + HEALTH_SCALE2,	HEALTH_Y + HEALTH_SCALE2,	 	0},
	{HEALTH_X - HEALTH_SCALE2,	HEALTH_Y + HEALTH_SCALE2, 		0},
};


			/* SHIELD */

static MOVertexArrayData	gShieldTriMesh;
static MOTriangleIndecies	gShieldTriangles[2] = {{{0, 1, 2}}, {{2, 0, 3}}};
static OGLTextureCoord		gShielduv1[4] = {{0,1}, {1,1}, {1,0}, {0,0}};
static OGLTextureCoord		gShielduv2[4] = {{0,1}, {1,1}, {1,0}, {0,0}};
static OGLPoint3D			gShieldPoints[4] =
{
	{SHIELD_X - SHIELD_SCALE2,	SHIELD_Y - SHIELD_SCALE2, 		0},
	{SHIELD_X + SHIELD_SCALE2,	SHIELD_Y - SHIELD_SCALE2, 		0},
	{SHIELD_X + SHIELD_SCALE2,	SHIELD_Y + SHIELD_SCALE2,	 	0},
	{SHIELD_X - SHIELD_SCALE2,	SHIELD_Y + SHIELD_SCALE2, 		0},
};


			/* FUEL */

static MOVertexArrayData	gFuelTriMesh;
static MOTriangleIndecies	gFuelTriangles[2] = {{{0, 1, 2}}, {{2, 0, 3}}};
static OGLTextureCoord		gFueluv1[4] = {{0,1}, {1,1}, {1,0}, {0,0}};
static OGLTextureCoord		gFueluv2[4] = {{0,1}, {1,1}, {1,0}, {0,0}};
static OGLPoint3D			gFuelPoints[4] =
{
	{FUEL_X - FUEL_SCALE2,	FUEL_Y - FUEL_SCALE2, 		0},
	{FUEL_X + FUEL_SCALE2,	FUEL_Y - FUEL_SCALE2, 		0},
	{FUEL_X + FUEL_SCALE2,	FUEL_Y + FUEL_SCALE2,	 	0},
	{FUEL_X - FUEL_SCALE2,	FUEL_Y + FUEL_SCALE2, 		0},
};


/********************* INIT INFOBAR ****************************/
//
// Called at beginning of level
//

void InitInfobar(void)
{
MOMaterialObject	*mo;
ObjNode		*newObj;

		/***********************/
		/* CREATE DUMMY OBJECT */
		/***********************/

	gNewObjectDefinition.genre		= CUSTOM_GENRE;
	gNewObjectDefinition.slot 		= INFOBAR_SLOT;
	gNewObjectDefinition.moveCall 	= nil;
	gNewObjectDefinition.flags 		= STATUS_BIT_DOUBLESIDED|STATUS_BIT_NOLIGHTING|STATUS_BIT_DONTCULL|STATUS_BIT_NOZBUFFER|
									STATUS_BIT_NOFOG;

	newObj = MakeNewObject(&gNewObjectDefinition);
	newObj->CustomDrawFunction = DrawInfobar;



		/********************************************/
		/* CREATE EVENT TO DRAW ANAGLYPH CROSSHAIRS */
		/********************************************/
		//
		// In Anaglyph mode we actually need to draw the crosshairs into the 3D space
		// instead of as faux sprites
		//


	if (gGamePrefs.stereoGlassesMode != STEREO_GLASSES_MODE_OFF)
	{
		gNewObjectDefinition.genre		= CUSTOM_GENRE;
		gNewObjectDefinition.slot 		= PARTICLE_SLOT-1;
		gNewObjectDefinition.moveCall 	= nil;
		gNewObjectDefinition.flags 		= STATUS_BIT_NOLIGHTING|STATUS_BIT_DONTCULL|	STATUS_BIT_NOFOG;

		newObj = MakeNewObject(&gNewObjectDefinition);
		newObj->CustomDrawFunction = DrawAnaglyphCrosshairs;
	}


		/*********************/
		/* LOAD OVERHEAD MAP */
		/*********************/

	switch(gLevelNum)
	{
		case	LEVEL_NUM_ADVENTURE1:
				gOverheadMapMaterial = gSpriteGroupList[SPRITE_GROUP_LEVELSPECIFIC][LEVEL1_SObjType_OHM].materialObject;		// get illegal ref to texture
				break;

		case	LEVEL_NUM_ADVENTURE2:
				gOverheadMapMaterial = gSpriteGroupList[SPRITE_GROUP_LEVELSPECIFIC][LEVEL2_SObjType_OHM].materialObject;
				break;

		case	LEVEL_NUM_ADVENTURE3:
				gOverheadMapMaterial = gSpriteGroupList[SPRITE_GROUP_LEVELSPECIFIC][LEVEL3_SObjType_OHM].materialObject;
				break;

		case	LEVEL_NUM_RACE1:
				gOverheadMapMaterial = gSpriteGroupList[SPRITE_GROUP_LEVELSPECIFIC][LEVEL3_SObjType_RaceOHM].materialObject;
				break;

		case	LEVEL_NUM_RACE2:
				gOverheadMapMaterial = gSpriteGroupList[SPRITE_GROUP_LEVELSPECIFIC][LEVEL2_SObjType_Race2OHM].materialObject;
				break;

		case	LEVEL_NUM_FLAG1:
				gOverheadMapMaterial = gSpriteGroupList[SPRITE_GROUP_LEVELSPECIFIC][LEVEL3_SObjType_FlagOHM].materialObject;
				break;
		case	LEVEL_NUM_FLAG2:
				gOverheadMapMaterial = gSpriteGroupList[SPRITE_GROUP_LEVELSPECIFIC][LEVEL1_SObjType_FlagOHM].materialObject;
				break;

		case	LEVEL_NUM_BATTLE1:
				gOverheadMapMaterial = gSpriteGroupList[SPRITE_GROUP_LEVELSPECIFIC][LEVEL1_SObjType_BattleOHM].materialObject;
				break;
		case	LEVEL_NUM_BATTLE2:
				gOverheadMapMaterial = gSpriteGroupList[SPRITE_GROUP_LEVELSPECIFIC][LEVEL2_SObjType_Battle2OHM].materialObject;
				break;




		default:
				gOverheadMapMaterial = nil;
				goto no_ohm;
	}

		/* SET TO BE MULTI-TEXTURE FOR MASKING */

	gOverheadMapMaterial->objectData.flags |= BG3D_MATERIALFLAG_MULTITEXTURE;
	gOverheadMapMaterial->objectData.multiTextureCombine = MULTI_TEXTURE_COMBINE_MODULATE;


		/* INIT OHM TRIMESH */

	gOHMPoints[0].z = gOHMPoints[1].z = gOHMPoints[2].z = gOHMPoints[3].z = 0;

	gOHMTriMesh.VARtype 		= -1;
	gOHMTriMesh.numMaterials 	= 2;
	gOHMTriMesh.materials[0] 	= gOverheadMapMaterial;
	gOHMTriMesh.materials[1] 	= gSpriteGroupList[SPRITE_GROUP_INFOBAR][INFOBAR_SObjType_MapMask].materialObject;

	gOHMTriMesh.numPoints 		= 4;
	gOHMTriMesh.numTriangles 	= 2;
	gOHMTriMesh.points 			= &gOHMPoints[0];
	gOHMTriMesh.normals 		= nil;
	gOHMTriMesh.uvs[0] 			= &gOHMuv1[0];
	gOHMTriMesh.uvs[1] 			= &gOHMuv2[0];
	gOHMTriMesh.colorsFloat 	= nil;
	gOHMTriMesh.triangles 		= &gOHMTriangles[0];

no_ohm:


		/********************/
		/* INIT HEALTH MESH */
		/********************/

	mo 									= gSpriteGroupList[SPRITE_GROUP_INFOBAR][INFOBAR_SObjType_HealthRed].materialObject;
	mo->objectData.flags 				|= BG3D_MATERIALFLAG_MULTITEXTURE | BG3D_MATERIALFLAG_ALWAYSBLEND;
	mo->objectData.multiTextureCombine 	= MULTI_TEXTURE_COMBINE_MODULATE;

	gHealthTriMesh.VARtype 			= -1;
	gHealthTriMesh.numMaterials 	= 2;
	gHealthTriMesh.materials[0] 	= mo;
	gHealthTriMesh.materials[1] 	= gSpriteGroupList[SPRITE_GROUP_INFOBAR][INFOBAR_SObjType_MapMask].materialObject;

	gHealthTriMesh.numPoints 		= 4;
	gHealthTriMesh.numTriangles 	= 2;
	gHealthTriMesh.points 			= &gHealthPoints[0];
	gHealthTriMesh.normals 			= nil;
	gHealthTriMesh.uvs[0] 			= &gHealthuv1[0];
	gHealthTriMesh.uvs[1] 			= &gHealthuv2[0];
	gHealthTriMesh.colorsFloat 		= nil;
	gHealthTriMesh.triangles 		= &gHealthTriangles[0];



		/********************/
		/* INIT SHIELD MESH */
		/********************/

	mo 									= gSpriteGroupList[SPRITE_GROUP_INFOBAR][INFOBAR_SObjType_ShieldRed].materialObject;
	mo->objectData.flags 				|= BG3D_MATERIALFLAG_MULTITEXTURE | BG3D_MATERIALFLAG_ALWAYSBLEND;
	mo->objectData.multiTextureCombine 	= MULTI_TEXTURE_COMBINE_MODULATE;

	gShieldTriMesh.VARtype 			= -1;
	gShieldTriMesh.numMaterials 	= 2;
	gShieldTriMesh.materials[0] 	= mo;
	gShieldTriMesh.materials[1] 	= gSpriteGroupList[SPRITE_GROUP_INFOBAR][INFOBAR_SObjType_MapMask].materialObject;

	gShieldTriMesh.numPoints 		= 4;
	gShieldTriMesh.numTriangles 	= 2;
	gShieldTriMesh.points 			= &gShieldPoints[0];
	gShieldTriMesh.normals 			= nil;
	gShieldTriMesh.uvs[0] 			= &gShielduv1[0];
	gShieldTriMesh.uvs[1] 			= &gShielduv2[0];
	gShieldTriMesh.colorsFloat 		= nil;
	gShieldTriMesh.triangles 		= &gShieldTriangles[0];


		/********************/
		/* INIT FUEL MESH */
		/********************/

	mo 								= gSpriteGroupList[SPRITE_GROUP_INFOBAR][INFOBAR_SObjType_FuelRed].materialObject;
	mo->objectData.flags 			|= BG3D_MATERIALFLAG_MULTITEXTURE | BG3D_MATERIALFLAG_ALWAYSBLEND;
	mo->objectData.multiTextureCombine 	= MULTI_TEXTURE_COMBINE_MODULATE;

	gFuelTriMesh.VARtype 			= -1;
	gFuelTriMesh.numMaterials 		= 2;
	gFuelTriMesh.materials[0] 		= mo;
	gFuelTriMesh.materials[1] 		= gSpriteGroupList[SPRITE_GROUP_INFOBAR][INFOBAR_SObjType_MapMask].materialObject;

	gFuelTriMesh.numPoints 			= 4;
	gFuelTriMesh.numTriangles 		= 2;
	gFuelTriMesh.points 			= &gFuelPoints[0];
	gFuelTriMesh.normals 			= nil;
	gFuelTriMesh.uvs[0] 			= &gFueluv1[0];
	gFuelTriMesh.uvs[1] 			= &gFueluv2[0];
	gFuelTriMesh.colorsFloat 		= nil;
	gFuelTriMesh.triangles 			= &gFuelTriangles[0];

}


/****************** DISPOSE INFOBAR **********************/

void DisposeInfobar(void)
{

}


/***************** SET INFOBAR SPRITE STATE *******************/
//
// anaglyphZ:  +5...-5  where + values are in front of screen, and - values are in back
//

void SetInfobarSpriteState(float anaglyphZ)
{
	OGL_DisableLighting();
	OGL_DisableCullFace();
	glDisable(GL_DEPTH_TEST);								// no z-buffer

				/* SET MATERIAL FLAGS */
				//
				// Assume that all sprites have clamped edges.
				// Assume that most sprites have alpha, so enable blending (this won't hurt if it doesn't have an alpha)
				//

	gGlobalMaterialFlags = BG3D_MATERIALFLAG_CLAMP_V|BG3D_MATERIALFLAG_CLAMP_U|BG3D_MATERIALFLAG_ALWAYSBLEND;


			/* INIT MATRICES */

	glMatrixMode(GL_PROJECTION);
	glLoadIdentity();

	int drawableW = 1;
	int drawableH = 1;
	SDL_GL_GetDrawableSize(gSDLWindow, &drawableW, &drawableH);

	float referenceW = 640;
	float referenceH = 480;
	float referenceAR = referenceW / referenceH;

	float logicalW;
	float logicalH;

	float drawableAR = drawableW / (float) drawableH;
	if (drawableAR >= referenceAR)
	{
		// wide
		logicalW = referenceH * drawableAR;
		logicalH = referenceH;
	}
	else
	{
		// tall
		logicalW = referenceW;
		logicalH = referenceW / drawableAR;
	}

	gLogicalRect.left	= (referenceW - logicalW) * 0.5f;
	gLogicalRect.top	= (referenceH - logicalH) * 0.5f;
	gLogicalRect.right	= gLogicalRect.left + logicalW;
	gLogicalRect.bottom	= gLogicalRect.top + logicalH;

	if (gGamePrefs.stereoGlassesMode != STEREO_GLASSES_MODE_OFF)
	{
		if (gAnaglyphPass == 0)
			glOrtho(-anaglyphZ, 640-anaglyphZ, 640.0f * gCurrentPaneAspectRatio, 0, 0, 1);
		else
			glOrtho(anaglyphZ, 640+anaglyphZ, 640.0f * gCurrentPaneAspectRatio, 0, 0, 1);
	}
	else
	{
		glOrtho(gLogicalRect.left, gLogicalRect.right, gLogicalRect.bottom, gLogicalRect.top, 0, 1);
	}

	glMatrixMode(GL_MODELVIEW);
	glLoadIdentity();
}


/********************** DRAW INFOBAR ****************************/

void DrawInfobar(ObjNode *theNode)
{
	(void) theNode;

			/* DRAW SOME OTHER GOODIES WHILE WE'RE HERE */

	DrawLensFlare();											// draw lens flare

	if (gCurrentSplitScreenPane == 0
		&& gAnaglyphPass == 0
		&& IsKeyDown(SDL_SCANCODE_F9))							// see if toggle statbar
	{
		gHideInfobar = !gHideInfobar;
	}

	if (gHideInfobar)
		return;

		/************/
		/* SET TAGS */
		/************/

	OGL_PushState();

	SetInfobarSpriteState(INFOBAR_ANAGLYPHZ_Z);



		/***************/
		/* DRAW THINGS */
		/***************/

	Infobar_DrawCrosshairs();
	Infobar_DrawWeaponInventory();
	Infobar_DrawHealth();
	Infobar_DrawShield();
	Infobar_DrawFuel();
	Infobar_DrawMap();


	switch(gVSMode)
	{
			/* ADVENTURE MODE */

		case	VS_MODE_NONE:
				Infobar_DrawLives();
				Infobar_DrawEggs();

						/* PLAYER DEAD */

				if (gPlayerIsDead[0] && (gPlayerInfo[0].numFreeLives <= 0))
				{
					DrawInfobarSprite_Centered(640/2, 480/2, 200, INFOBAR_SObjType_GameOver);

				}
						/* ENTER WORMHOLE */
				else
				if (gOpenPlayerWormhole && (!gCameraInExitMode))
				{
					DrawInfobarSprite_Centered(640/2, 480*2/3, 150, INFOBAR_SObjType_EnterWormhole);
				}
				break;

			/* RACE MODE */

		case	VS_MODE_RACE:
				Infobar_DrawPlayerLabels();
				Infobar_DrawRaceInfo();
				Infobar_DrawPlayerArrows();
				break;


			/* CAPTURE THE FLAG MODE */

		case	VS_MODE_CAPTURETHEFLAG:
				Infobar_DrawPlayerLabels();
				Infobar_CaptureFlagEggs();
				Infobar_DrawPlayerArrows();
				break;

			/* BATTLE MODE */

		case	VS_MODE_BATTLE:
				Infobar_DrawPlayerLabels();
				Infobar_DrawLives();
				Infobar_DrawPlayerArrows();
				break;
	}



			/***********/
			/* CLEANUP */
			/***********/

	OGL_PopState();
	gGlobalMaterialFlags = 0;
}

#pragma mark -

/******************** DRAW INFOBAR SPRITE **********************/

void DrawInfobarSprite(float x, float y, float size, short texNum)
{
MOMaterialObject	*mo;
float				aspect;

		/* ACTIVATE THE MATERIAL */

	mo = gSpriteGroupList[SPRITE_GROUP_INFOBAR][texNum].materialObject;
	MO_DrawMaterial(mo);

	aspect = (float)mo->objectData.height / (float)mo->objectData.width;

			/* DRAW IT */

	glBegin(GL_QUADS);
	glTexCoord2f(0,1);	glVertex2f(x, 		y);
	glTexCoord2f(1,1);	glVertex2f(x+size, 	y);
	glTexCoord2f(1,0);	glVertex2f(x+size,  y+(size*aspect));
	glTexCoord2f(0,0);	glVertex2f(x,		y+(size*aspect));
	glEnd();
}

/******************** DRAW INFOBAR SPRITE: CENTERED **********************/
//
// Coords are for center of sprite, not upper left
//

void DrawInfobarSprite_Centered(float x, float y, float size, short texNum)
{
MOMaterialObject	*mo;
float				aspect;

		/* ACTIVATE THE MATERIAL */

	mo = gSpriteGroupList[SPRITE_GROUP_INFOBAR][texNum].materialObject;
	MO_DrawMaterial(mo);

	aspect = (float)mo->objectData.height / (float)mo->objectData.width;

	x -= size*.5f;
	y -= (size*aspect)*.5f;


			/* DRAW IT */

	glBegin(GL_QUADS);
	glTexCoord2f(0,1);	glVertex2f(x, 		y);
	glTexCoord2f(1,1);	glVertex2f(x+size, 	y);
	glTexCoord2f(1,0);	glVertex2f(x+size,  y+(size*aspect));
	glTexCoord2f(0,0);	glVertex2f(x,		y+(size*aspect));
	glEnd();
}


/******************** DRAW INFOBAR SPRITE 2 **********************/
//
// This version lets user pass in the sprite group
//

void DrawInfobarSprite2(float x, float y, float size, short group, short texNum)
{
MOMaterialObject	*mo;
float				aspect;

		/* ACTIVATE THE MATERIAL */

	mo = gSpriteGroupList[group][texNum].materialObject;
	MO_DrawMaterial(mo);

	aspect = (float)mo->objectData.height / (float)mo->objectData.width;

			/* DRAW IT */

	glBegin(GL_QUADS);
	glTexCoord2f(0,1);	glVertex2f(x, 		y);
	glTexCoord2f(1,1);	glVertex2f(x+size, 	y);
	glTexCoord2f(1,0);	glVertex2f(x+size,  y+(size*aspect));
	glTexCoord2f(0,0);	glVertex2f(x,		y+(size*aspect));
	glEnd();
}


/******************** DRAW INFOBAR SPRITE 3 **********************/
//
// Same as above, but where size is the vertical size, not horiz.
//

void DrawInfobarSprite3(float x, float y, float size, short texNum)
{
MOMaterialObject	*mo;
float				aspect;

		/* ACTIVATE THE MATERIAL */

	mo = gSpriteGroupList[SPRITE_GROUP_INFOBAR][texNum].materialObject;
	MO_DrawMaterial(mo);

	aspect = (float)mo->objectData.width / (float)mo->objectData.height;

			/* DRAW IT */

	glBegin(GL_QUADS);
	glTexCoord2f(0,1);	glVertex2f(x, 					y);
	glTexCoord2f(1,1);	glVertex2f(x+(size*aspect), 	y);
	glTexCoord2f(1,0);	glVertex2f(x+(size*aspect),		y+size);
	glTexCoord2f(0,0);	glVertex2f(x,					y+size);
	glEnd();
}

/******************** DRAW INFOBAR SPRITE 3: CENTERED **********************/

void DrawInfobarSprite3_Centered(float x, float y, float size, short texNum)
{
MOMaterialObject	*mo;
float				aspect;

		/* ACTIVATE THE MATERIAL */

	mo = gSpriteGroupList[SPRITE_GROUP_INFOBAR][texNum].materialObject;
	MO_DrawMaterial(mo);

	aspect = (float)mo->objectData.width / (float)mo->objectData.height;

	y -= size*.5f;
	x -= (size*aspect)*.5f;

			/* DRAW IT */

	glBegin(GL_QUADS);
	glTexCoord2f(0,1);	glVertex2f(x, 					y);
	glTexCoord2f(1,1);	glVertex2f(x+(size*aspect), 	y);
	glTexCoord2f(1,0);	glVertex2f(x+(size*aspect),		y+size);
	glTexCoord2f(0,0);	glVertex2f(x,					y+size);
	glEnd();
}


/******************** DRAW INFOBAR SPRITE 2: CENTERED **********************/
//
// This version lets user pass in the sprite group
//

void DrawInfobarSprite2_Centered(float x, float y, float size, short group, short texNum)
{
MOMaterialObject	*mo;
float				aspect;

	if (texNum >= gNumSpritesInGroupList[group])
	{
		DoFatalAlert("DrawInfobarSprite2_Centered: sprite # (%d) > max in group (%d)!", texNum, gNumSpritesInGroupList[group]);
	}

		/* ACTIVATE THE MATERIAL */

	mo = gSpriteGroupList[group][texNum].materialObject;
	MO_DrawMaterial(mo);

	aspect = (float)mo->objectData.height / (float)mo->objectData.width;

	x -= size*.5f;
	y -= (size*aspect)*.5f;

			/* DRAW IT */

	glBegin(GL_QUADS);
	glTexCoord2f(0,1);	glVertex2f(x, 		y);
	glTexCoord2f(1,1);	glVertex2f(x+size, 	y);
	glTexCoord2f(1,0);	glVertex2f(x+size,  y+(size*aspect));
	glTexCoord2f(0,0);	glVertex2f(x,		y+(size*aspect));
	glEnd();
}



/******************** DRAW INFOBAR SPRITE: ROTATED **********************/

static void DrawInfobarSprite_Rotated(float x, float y, float size, short texNum, float rot)
{
MOMaterialObject	*mo;
float				aspect, xoff, yoff;
OGLPoint2D			p[4];
OGLMatrix3x3		m;

		/* ACTIVATE THE MATERIAL */

	mo = gSpriteGroupList[SPRITE_GROUP_INFOBAR][texNum].materialObject;
	MO_DrawMaterial(mo);

				/* SET COORDS */

	aspect = (float)mo->objectData.height / (float)mo->objectData.width;

	xoff = size*.5f;
	yoff = (size*aspect)*.5f;

	p[0].x = -xoff;		p[0].y = -yoff;
	p[1].x = xoff;		p[1].y = -yoff;
	p[2].x = xoff;		p[2].y = yoff;
	p[3].x = -xoff;		p[3].y = yoff;

	OGLMatrix3x3_SetRotate(&m, rot);
	OGLPoint2D_TransformArray(p, &m, p, 4);


			/* DRAW IT */

	glBegin(GL_QUADS);
	glTexCoord2f(0,1);	glVertex2f(p[0].x + x, p[0].y + y);
	glTexCoord2f(1,1);	glVertex2f(p[1].x + x, p[1].y + y);
	glTexCoord2f(1,0);	glVertex2f(p[2].x + x, p[2].y + y);
	glTexCoord2f(0,0);	glVertex2f(p[3].x + x, p[3].y + y);
	glEnd();
}





#pragma mark -





/*************** INFOBAR: DRAW NUMBER ************************/

void Infobar_DrawNumber(int number, float x, float y, float scale, int numDigits, Boolean showLeading)
{
int		i,n,r;
float	sep = scale * DIGIT_WIDTH;


	x += (numDigits-1) * sep;			// start on right

	for (i = 0; i < numDigits; i++)
	{
		n = number / 10;
		r = (number - (n * 10));
		if (r == 10)
			r = 0;
		number = n;

		DrawInfobarSprite(x, y, scale, INFOBAR_SObjType_0 + r);

		x -= sep;

		if (!showLeading)
		{
			if (number == 0)
				return;
		}

	}

}


#pragma mark -

/********************** DRAW MAP *************************/

static void Infobar_DrawMap(void)
{
float				xoff, yoff;
OGLPoint2D			p2D[4];
OGLMatrix3x3		m;
float				rot, u, v, y;
float				visibleRange;
double				leftEdge, topEdge;

	if (!gOverheadMapMaterial)
		return;

	rot = gPlayerInfo[gCurrentSplitScreenPane].objNode->Rot.y;

	y = MAP_Y;
//	if ((gNumPlayers > 1) && (gGamePrefs.splitScreenMode == SPLITSCREEN_MODE_HORIZ))		// adjust for horiz-split screen
//		y -= 20.0f;


		/* SET COORDS OF THE QUAD */

	xoff = MAP_SCALE2;
	yoff = MAP_SCALE2;

	p2D[0].x = -xoff;		p2D[0].y = -yoff;
	p2D[1].x = xoff;		p2D[1].y = -yoff;
	p2D[2].x = xoff;		p2D[2].y = yoff;
	p2D[3].x = -xoff;		p2D[3].y = yoff;

	OGLMatrix3x3_SetRotate(&m, rot);
	OGLPoint2D_TransformArray(p2D, &m, p2D, 4);


	gOHMPoints[0].x = p2D[0].x + MAP_X;	gOHMPoints[0].y = p2D[0].y + y;		// translate and convert to 3D point variable
	gOHMPoints[1].x = p2D[1].x + MAP_X;	gOHMPoints[1].y = p2D[1].y + y;
	gOHMPoints[2].x = p2D[2].x + MAP_X;	gOHMPoints[2].y = p2D[2].y + y;
	gOHMPoints[3].x = p2D[3].x + MAP_X;	gOHMPoints[3].y = p2D[3].y + y;


		/******************/
		/* CALC UV COORDS */
		/******************/
		//
		// First we need to adjust the world left/top to the texture's
		// left/top (since we've cropped the black out of it)
		//
		// Then we need to scale the scroll value to uv coords.
		//

	leftEdge = gPlayerInfo[gCurrentSplitScreenPane].coord.x * gMapToUnitValueFrac;		// convert world-coord to texture-pixel-coord
	topEdge = gPlayerInfo[gCurrentSplitScreenPane].coord.z * gMapToUnitValueFrac;

	switch(gLevelNum)
	{
		case	LEVEL_NUM_ADVENTURE1:
				visibleRange = .18f;

				leftEdge -= 1175.0;											// offset by the cropped black-space amount
				u = leftEdge * 0.00011;

				topEdge -= 911.0;											// offset by the cropped black-space amount
				v = 1.0 - (topEdge * 0.00011);
				break;


		case	LEVEL_NUM_ADVENTURE2:
				visibleRange = .24f;

				leftEdge -= 527.0;											// offset by the cropped black-space amount
				u = leftEdge * 0.0001057;

				topEdge -= 275.0;											// offset by the cropped black-space amount
				v = 1.0 - (topEdge * 0.0001057);
				break;

		case	LEVEL_NUM_ADVENTURE3:
				visibleRange = .29f;

				leftEdge -= 496.0;											// offset by the cropped black-space amount
				u = leftEdge * 0.0001029;

				topEdge -= 192.0;											// offset by the cropped black-space amount
				v = 1.0 - (topEdge * 0.0001029);
				break;

		case	LEVEL_NUM_RACE1:
				visibleRange = .3f;

				leftEdge -= 779.0;											// offset by the cropped black-space amount
				u = leftEdge * 0.0001463;

				topEdge -= 317.0;											// offset by the cropped black-space amount
				v = 1.0 - (topEdge * 0.0001463);
				break;


		case	LEVEL_NUM_RACE2:
				visibleRange = .25f;

				leftEdge -= 743.0;											// offset by the cropped black-space amount
				u = leftEdge * 0.000148853;			// 1.0 / pixel width

				topEdge -= 329.0;											// offset by the cropped black-space amount
				v = 1.0 - (topEdge * 0.000148853);
				break;

		case	LEVEL_NUM_FLAG1:
				visibleRange = .3f;

				leftEdge -= 1499.0;											// offset by the cropped black-space amount
				u = leftEdge * 0.0001999;

				topEdge -= 809.0;											// offset by the cropped black-space amount
				v = 1.0 - (topEdge * 0.0001999);
				break;

		case	LEVEL_NUM_FLAG2:
				visibleRange = .5f;

				leftEdge -= 2544;											// offset by the cropped black-space amount
				u = leftEdge * .0002735;

				topEdge -= 728;											// offset by the cropped black-space amount
				v = 1.0 - (topEdge * .0002735);
				break;



		case	LEVEL_NUM_BATTLE1:
				visibleRange = .5f;

				leftEdge -= 2732.0;											// offset by the cropped black-space amount
				u = leftEdge * .000371;

				topEdge -= 1328.0;											// offset by the cropped black-space amount
				v = 1.0 - (topEdge * .000371);
				break;

		case	LEVEL_NUM_BATTLE2:
				visibleRange = .3f;

				leftEdge -= 3152.0;											// offset by the cropped black-space amount
				u = leftEdge * .00054585;

				topEdge -= 1692.0f;											// offset by the cropped black-space amount
				v = 1.0 - (topEdge * .00054585);
				break;


		default:
				return;
	}

	gOHMuv1[0].u = u - visibleRange;
	gOHMuv1[0].v = (v + visibleRange);

	gOHMuv1[1].u = u + visibleRange;
	gOHMuv1[1].v = gOHMuv1[0].v;

	gOHMuv1[2].u = gOHMuv1[1].u;
	gOHMuv1[2].v = (v - visibleRange);

	gOHMuv1[3].u = gOHMuv1[0].u;
	gOHMuv1[3].v = gOHMuv1[2].v;


			/***********/
			/* DRAW IT */
			/***********/


			/* DRAW SHADOW */

	if (!gGamePrefs.lowRenderQuality)
		DrawInfobarSprite_Centered(MAP_X + 3, y + 3, MAP_SCALE * 1.3, INFOBAR_SObjType_CircleShadow);


			/* DRAW BACK */

	DrawInfobarSprite_Centered(MAP_X, y, MAP_SCALE, INFOBAR_SObjType_MapLines);


			/* DRAW MAP */

	MO_DrawGeometry_VertexArray(&gOHMTriMesh);


			/* DRAW FRAME OVERLAY */

	DrawInfobarSprite_Rotated(MAP_X, y, MAP_SCALE, INFOBAR_SObjType_MapFrame, 0);

	OGL_BlendFunc(GL_SRC_ALPHA, GL_ONE);
	DrawInfobarSprite_Centered(MAP_X, y, MAP_SCALE, INFOBAR_SObjType_MapGlass);
	OGL_BlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

}



/********************** DRAW HEALTH *************************/

static void Infobar_DrawHealth(void)
{
float				v;




			/******************/
			/* CALC UV COORDS */
			/******************/

	v = (1.0f - gPlayerInfo[gCurrentSplitScreenPane].health) * .5f;

			/* SET U'S FOR SCROLLING OF HEALTH BAR */

	gHealthuv1[0].v = gHealthuv1[1].v = v + .5;
	gHealthuv1[2].v = gHealthuv1[3].v = v;




			/***********/
			/* DRAW IT */
			/***********/

			/* DRAW SHADOW */

	if (!gGamePrefs.lowRenderQuality)
		DrawInfobarSprite_Centered(HEALTH_X + 2, HEALTH_Y + 2, HEALTH_SCALE * 1.3, INFOBAR_SObjType_CircleShadow);

	MO_DrawGeometry_VertexArray(&gHealthTriMesh);


			/* DRAW FRAME OVERLAY */

	DrawInfobarSprite_Centered(HEALTH_X, HEALTH_Y, HEALTH_SCALE, INFOBAR_SObjType_HealthFrame);

	OGL_BlendFunc(GL_SRC_ALPHA, GL_ONE);
	DrawInfobarSprite_Centered(HEALTH_X, HEALTH_Y, HEALTH_SCALE, INFOBAR_SObjType_HealthShine);
	OGL_BlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

}


/********************** DRAW SHIELD *************************/

static void Infobar_DrawShield(void)
{
float				v;
float				q;

	q = gPlayerInfo[gCurrentSplitScreenPane].shieldPower / MAX_SHIELD_POWER;		// convert shield power to 0..1 value

			/******************/
			/* CALC UV COORDS */
			/******************/

	v = (1.0f - q) * .5f;

			/* SET U'S FOR SCROLLING OF SHIELD BAR */

	gShielduv1[0].v = gShielduv1[1].v = v + .5;
	gShielduv1[2].v = gShielduv1[3].v = v;




			/***********/
			/* DRAW IT */
			/***********/


			/* DRAW SHADOW */

	if (!gGamePrefs.lowRenderQuality)
		DrawInfobarSprite_Centered(SHIELD_X + 2, SHIELD_Y + 2, SHIELD_SCALE * 1.3, INFOBAR_SObjType_CircleShadow);


	MO_DrawGeometry_VertexArray(&gShieldTriMesh);


			/* DRAW FRAME OVERLAY */

	DrawInfobarSprite_Centered(SHIELD_X, SHIELD_Y, SHIELD_SCALE, INFOBAR_SObjType_ShieldFrame);

	OGL_BlendFunc(GL_SRC_ALPHA, GL_ONE);
	DrawInfobarSprite_Centered(SHIELD_X, SHIELD_Y, SHIELD_SCALE, INFOBAR_SObjType_HealthShine);
	OGL_BlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);


}



/********************** DRAW FUEL *************************/

static void Infobar_DrawFuel(void)
{
float				v;

			/******************/
			/* CALC UV COORDS */
			/******************/

	v = (1.0f - gPlayerInfo[gCurrentSplitScreenPane].jetpackFuel) * .5f;

			/* SET U'S FOR SCROLLING OF FUEL BAR */

	gFueluv1[0].v = gFueluv1[1].v = v + .5;
	gFueluv1[2].v = gFueluv1[3].v = v;




			/***********/
			/* DRAW IT */
			/***********/

			/* DRAW SHADOW */

	if (!gGamePrefs.lowRenderQuality)
		DrawInfobarSprite_Centered(FUEL_X + 2, FUEL_Y + 2, FUEL_SCALE * 1.3, INFOBAR_SObjType_CircleShadow);


	MO_DrawGeometry_VertexArray(&gFuelTriMesh);


			/* DRAW FRAME OVERLAY */

	DrawInfobarSprite_Centered(FUEL_X, FUEL_Y, FUEL_SCALE, INFOBAR_SObjType_FuelFrame);

	OGL_BlendFunc(GL_SRC_ALPHA, GL_ONE);
	DrawInfobarSprite_Centered(FUEL_X, FUEL_Y, FUEL_SCALE, INFOBAR_SObjType_HealthShine);
	OGL_BlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

}


/********************** DRAW EGGS *************************/

static void Infobar_DrawEggs(void)
{
short	eggType, i;
float	x,y;


	x = EGGS_X;
	for (eggType = 0; eggType < NUM_EGG_TYPES; eggType++)
	{
		if (gNumEggsToSave[eggType] > 0)							// are there any eggs of this color?
		{
			y = EGGS_Y;
			for (i = 0; i < gNumEggsToSave[eggType]; i++)
			{
				if (gNumEggsSaved[eggType] > i)
					DrawInfobarSprite(x, y, EGGS_SCALE, INFOBAR_SObjType_SmallRedEgg + eggType);
				else
					DrawInfobarSprite(x, y, EGGS_SCALE, INFOBAR_SObjType_SmallBlankEgg);
				y += EGGS_SCALE;
			}
			x += EGGS_SCALE;
		}
	}
}


/********************** DRAW CAPTURE FLAG EGGS *************************/

static void Infobar_CaptureFlagEggs(void)
{
short	eggType = gCurrentSplitScreenPane^1;			// egg type is OTHER player's, so ^ 1
short	i;
float	x,y;

	y = CAP_EGGS_Y;
	x = CAP_EGGS_X;
	for (i = 0; i < gNumEggsToSave[eggType]; i++)
	{
		if (gNumEggsSaved[eggType] > i)
			DrawInfobarSprite(x, y, CAP_EGGS_SCALE, INFOBAR_SObjType_SmallRedEgg + eggType);
		else
		{
			if (eggType == 0)
				DrawInfobarSprite(x, y, CAP_EGGS_SCALE, INFOBAR_SObjType_SmallBlankEggRed);
			else
				DrawInfobarSprite(x, y, CAP_EGGS_SCALE, INFOBAR_SObjType_SmallBlankEgg);
		}
		x += CAP_EGGS_SCALE * .95f;
	}
}



/***************** DRAW INFOBAR PLAYER LABELS *********************/

static void Infobar_DrawPlayerLabels(void)
{
	if (gNumPlayers < 2)										// only draw if more than 1 player
		return;


	DrawInfobarSprite(PLAYER_X, PLAYER_Y, PLAYER_SCALE, INFOBAR_SObjType_Player1 + gCurrentSplitScreenPane);

}




/***************** DRAW INFOBAR LIVES *********************/

static void Infobar_DrawLives(void)
{
short	i;
float	x = LIVES_X;

	for (i = 0; i < gPlayerInfo[gCurrentSplitScreenPane].numFreeLives; i++)
	{
		DrawInfobarSprite(x, LIVES_Y, LIVES_SCALE, INFOBAR_SObjType_Life);
		x += LIVES_SCALE * 1.0f;
	}
}


/********************* DRAW WEAPON INVENTORY ***********************/

static void Infobar_DrawWeaponInventory(void)
{
short	weaponType;
float	x,y;


			/* DRAW FRAME */

	DrawInfobarSprite(WEAPON_X-15, WEAPON_Y-5, WEAPON_SCALE * 1.4, INFOBAR_SObjType_WeaponShadow);

	DrawInfobarSprite(WEAPON_X, WEAPON_Y, WEAPON_SCALE, INFOBAR_SObjType_WeaponFrame);


			/* DRAW ICON */


	weaponType = gPlayerInfo[gCurrentSplitScreenPane].currentWeapon;
	if (weaponType == WEAPON_TYPE_NONE)
		return;

	x = WEAPON_X + WEAPON_SCALE * .026f;
	y = WEAPON_Y + WEAPON_SCALE * .024f;

	DrawInfobarSprite(x, y, WEAPON_SCALE * .45, INFOBAR_SObjType_Blaster + weaponType);


			/* DRAW QUANTITY */

	x = WEAPON_X + (WEAPON_SCALE * .45);
	y = WEAPON_Y + (WEAPON_SCALE * .222);

	if (weaponType != WEAPON_TYPE_SONICSCREAM)		// dont draw quantity for SS since it's infinite
	{

		Infobar_DrawNumber(gPlayerInfo[gCurrentSplitScreenPane].weaponQuantity[weaponType], x, y, WEAPON_SCALE * .2, 3, true);
	}

		/* DRAW SONIC SCREAM BARS */

	else
	{
		short   numBars = gPlayerInfo[gCurrentSplitScreenPane].weaponCharge * 9.0f;
		short   i;

		for (i = 0; i < numBars; i++)
		{
			DrawInfobarSprite(x, y, WEAPON_SCALE * .1, INFOBAR_SObjType_SSBar);
			x += WEAPON_SCALE * .05f;
		}
	}


}


#pragma mark -

/***************** INFOBAR:  DRAW RACE INFO *********************/

static void Infobar_DrawRaceInfo(void)
{
short	n, lapNum;
short	place,playerNum = gCurrentSplitScreenPane;
float   scale;

			/* DRAW READY-SET-GO */

	n = gRaceReadySetGoTimer + 1;
	if (n >= 0)
	{
		scale = 135.0f;

		switch(n)
		{
			case	2:
					DrawInfobarSprite_Centered(640/2, 322.5f, scale, INFOBAR_SObjType_Ready);
					break;

			case	1:
					DrawInfobarSprite_Centered(640/2, 322.5f, scale, INFOBAR_SObjType_Set);
					break;

			case	0:
					DrawInfobarSprite_Centered(640/2, 322.5f, scale, INFOBAR_SObjType_Go);
					break;
		}
	}


			/* DRAW PLACE */

	scale = 60.0f;

	place = gPlayerInfo[playerNum].place;
	DrawInfobarSprite(300, 0, scale, INFOBAR_SObjType_Place1+place);



			/* DRAW LAP */

	if (!gLevelCompleted)
	{
		lapNum = gPlayerInfo[playerNum].lapNum;
		if (lapNum < 0)
			lapNum = 0;

		DrawInfobarSprite(640.0f - scale, 0, scale, INFOBAR_SObjType_Lap1+lapNum);
	}

			/* DRAW WRONG WAY */

	if (gPlayerInfo[playerNum].wrongWay)
	{
		gGlobalTransparency = .6;
		DrawInfobarSprite_Centered(640/2, 480/2, 80, INFOBAR_SObjType_WrongWay);
		gGlobalTransparency = 1.0;
	}
}




/****************** SHOW LAPNUM *********************/
//
// Called from Checkpoints.c whenever the player completes a new lap (except for winning lap).
//

ObjNode* ShowLapNum(short playerNum)
{
short	lapNum;
ObjNode	*newObj;

	lapNum = gPlayerInfo[playerNum].lapNum;

			/* SEE IF TELL LAP */

	if (lapNum <= 0)
		return NULL;

	NewObjectDefinitionType def =
	{
		.group		= SPRITE_GROUP_INFOBAR,
		.type		= lapNum == 1 ? INFOBAR_SObjType_Lap2Message : INFOBAR_SObjType_FinalLapMessage,
		.coord		= {640/2, 315, 0},
		.flags		= STATUS_BIT_ONLYSHOWTHISPLAYER,
		.slot		= SPRITE_SLOT,
		.moveCall 	= MoveLapMessage,
		.rot		= 0,
		.scale		= 170,
	};

	newObj = MakeSpriteObject(&def, true);
	newObj->PlayerNum = playerNum;			// only show for this player
	newObj->ColorFilter.a = 2.0f;
	return newObj;
}

/************* MOVE LAP MESSAGE *****************/

static void MoveLapMessage(ObjNode *theNode)
{
	theNode->ColorFilter.a -= gFramesPerSecondFrac;
	if (theNode->ColorFilter.a <= 0.0f)
		DeleteObject(theNode);
}


/****************** SHOW WIN LOSE *********************/
//
// Used for battle modes to show player if they win or lose.
//
// INPUT: 	mode 0 : won
//			mode 1 : lost
//			mode 2 : draw
//

ObjNode* ShowWinLose(short playerNum, Byte mode)
{
ObjNode *newObj;
int spriteNum;

	switch(mode)
	{
		case	0:
				spriteNum		= INFOBAR_SObjType_YouWin;
				break;

		case	1:
				spriteNum		= INFOBAR_SObjType_YouLose;
				break;

		case	2:
				spriteNum		= INFOBAR_SObjType_YouDraw;
				break;

		default:
				return NULL;
	}

	NewObjectDefinitionType def =
	{
		.coord		= {640/2, 400, 0},
		.flags		= STATUS_BIT_ONLYSHOWTHISPLAYER,
		.slot		= SPRITE_SLOT,
		.moveCall	= nil,
		.rot		= 0,
		.scale		= 230,
		.group		= SPRITE_GROUP_INFOBAR,
		.type		= spriteNum,
	};

	newObj = MakeSpriteObject(&def, true);
	newObj->PlayerNum = playerNum;						// only show for this player
	return newObj;
}


/********************* DRAW PLAYER ARROWS ********************************/

static void Infobar_DrawPlayerArrows(void)
{
OGLVector2D v, v2;
float		dot, cross;

			/* GET ANGLE TO P2 */

	if (gCurrentSplitScreenPane == 0)
	{
		v.x = gPlayerInfo[1].coord.x - gPlayerInfo[0].coord.x;			// calc vector from P1 to P2
		v.y = gPlayerInfo[1].coord.z - gPlayerInfo[0].coord.z;
		FastNormalizeVector2D(v.x, v.y, &v, false);

		v2.x = gPlayerInfo[0].objNode->MotionVector.x;					// get aim vector of P1
		v2.y = gPlayerInfo[0].objNode->MotionVector.z;

	}

			/* GET ANGLE TO P1 */
	else
	{
		v.x = gPlayerInfo[0].coord.x - gPlayerInfo[1].coord.x;			// calc vector from P2 to P1
		v.y = gPlayerInfo[0].coord.z - gPlayerInfo[1].coord.z;
		FastNormalizeVector2D(v.x, v.y, &v, false);

		v2.x = gPlayerInfo[1].objNode->MotionVector.x;					// get aim vector of P2
		v2.y = gPlayerInfo[1].objNode->MotionVector.z;
	}

		/* SEE WHICH ARROW TO DRAW */

	dot = OGLVector2D_Dot(&v, &v2);										// calc angle between
	dot = acos(dot);
	if (dot > .8f)
	{
		gGlobalTransparency = .8f;
		cross = OGLVector2D_Cross(&v, &v2);								// sign of cross tells us which side
		if (cross > 0.0f)
		{
			DrawInfobarSprite(0, 480/2, ARROW_SCALE, INFOBAR_SObjType_LeftArrow);
		}
		else
		{
			DrawInfobarSprite(640-ARROW_SCALE, 480/2, ARROW_SCALE, INFOBAR_SObjType_RightArrow);
		}
		gGlobalTransparency = 1.0f;
	}


}


#pragma mark -


/********************** DRAW ANAGLYPH CROSSHAIRS *************************/

static void DrawAnaglyphCrosshairs(ObjNode *theNode)
{
short	playerNum = gCurrentSplitScreenPane;
short	i;
OGLPoint3D		*coord;
OGLMatrix4x4	m;
const OGLVector3D up = {0,1,0};
Boolean		lockedOn;

#pragma unused (theNode)

	if (!gGamePrefs.showTargetingCrosshairs)
		return;

	if (gPlayerIsDead[playerNum])			// dont draw if player is dead
		return;

	if (gCameraMode[playerNum] == CAMERA_MODE_FIRSTPERSON)			// don't draw in 1st person camera
		return;

			/* ONLY SHOW CROSSHAIRS FOR CERTAIN WEAPONS */

	switch (gPlayerInfo[playerNum].currentWeapon)
	{
		case	WEAPON_TYPE_BOMB:
				return;
	}

				/* DON'T SHOW DURING DUST DEVIL */

	if (gPlayerInfo[playerNum].objNode->Skeleton->AnimNum == PLAYER_ANIM_DUSTDEVIL)
		return;



	lockedOn = (gPlayerInfo[playerNum].crosshairTargetObj != nil);				// see if an object is targeted


	for (i = 0; i < 1; i++)		// NUM_CROSSHAIR_LEVELS
	{
		coord = &gPlayerInfo[playerNum].crosshairCoord[i];


		SetLookAtMatrixAndTranslate(&m, &up, coord, &gPlayerInfo[playerNum].coord);

		glPushMatrix();
		glMultMatrixf((GLfloat *)&m);


					/* DRAW LARGE */

		if (i == 0)
		{
			const float	size = 45.0f;
			const float	size2 = 35.0f;


			MO_DrawMaterial(gSpriteGroupList[SPRITE_GROUP_INFOBAR][INFOBAR_SObjType_GunSight_OuterRing].materialObject);		// activate material

			glBegin(GL_QUADS);
			glTexCoord2f(0,0);	glVertex2f(-size, -size);
			glTexCoord2f(0,1);	glVertex2f(-size, size);
			glTexCoord2f(1,1);	glVertex2f(size, size);
			glTexCoord2f(1,0);	glVertex2f(size, -size);
			glEnd();

			if (lockedOn)
			{
				MO_DrawMaterial(gSpriteGroupList[SPRITE_GROUP_INFOBAR][INFOBAR_SObjType_GunSight_Locked].materialObject);		// activate material

				glBegin(GL_QUADS);
				glTexCoord2f(0,0);	glVertex2f(-size, -size);
				glTexCoord2f(0,1);	glVertex2f(-size, size);
				glTexCoord2f(1,1);	glVertex2f(size, size);
				glTexCoord2f(1,0);	glVertex2f(size, -size);
				glEnd();
			}
			else
			{
				MO_DrawMaterial(gSpriteGroupList[SPRITE_GROUP_INFOBAR][INFOBAR_SObjType_GunSight_Normal].materialObject);		// activate material

				glBegin(GL_QUADS);
				glTexCoord2f(0,0);	glVertex2f(-size2, -size2);
				glTexCoord2f(0,1);	glVertex2f(-size2, size2);
				glTexCoord2f(1,1);	glVertex2f(size2, size2);
				glTexCoord2f(1,0);	glVertex2f(size2, -size2);
				glEnd();


				MO_DrawMaterial(gSpriteGroupList[SPRITE_GROUP_INFOBAR][INFOBAR_SObjType_GunSight_Pointer].materialObject);		// activate material

				glBegin(GL_QUADS);
				glTexCoord2f(0,0);	glVertex2f(-size, -size);
				glTexCoord2f(0,1);	glVertex2f(-size, size);
				glTexCoord2f(1,1);	glVertex2f(size, size);
				glTexCoord2f(1,0);	glVertex2f(size, -size);
				glEnd();
			}
		}
					/* DRAW SMALL */

		else
		{
			const float	size = 30.0f;

			MO_DrawMaterial(gSpriteGroupList[SPRITE_GROUP_INFOBAR][INFOBAR_SObjType_GunSight_Normal].materialObject);		// activate material

			glBegin(GL_QUADS);
			glTexCoord2f(0,0);	glVertex2f(-size, -size);
			glTexCoord2f(0,1);	glVertex2f(-size, size);
			glTexCoord2f(1,1);	glVertex2f(size, size);
			glTexCoord2f(1,0);	glVertex2f(size, -size);
			glEnd();
		}

		glPopMatrix();
	}

}




/******************** DRAW INFOBAR CROSSHAIRS ***************************/

static void Infobar_DrawCrosshairs(void)
{
short		playerNum = gCurrentSplitScreenPane;
OGLPoint3D	screenCoord;
int			px,py,pw,ph;
float		screenToPaneX, screenToPaneY, r, dot;
OGLVector3D	*v1, *v2, v3;
Boolean		lockedOn;
float		scale;

	if (!gGamePrefs.showTargetingCrosshairs)
		return;

	if (gPlayerIsDead[playerNum])			// dont draw if player is dead
		return;

	if (gCameraInExitMode)
		return;

	if (gGamePrefs.stereoGlassesMode != STEREO_GLASSES_MODE_OFF)
		return;

	if (gCameraMode[playerNum] == CAMERA_MODE_FIRSTPERSON)			// don't draw in 1st person camera
		return;

			/* ONLY SHOW CROSSHAIRS FOR CERTAIN WEAPONS */

	switch (gPlayerInfo[playerNum].currentWeapon)
	{
		case	WEAPON_TYPE_BOMB:
				return;
	}

				/* DON'T SHOW DURING DUST DEVIL */

	if (gPlayerInfo[playerNum].objNode->Skeleton->AnimNum == PLAYER_ANIM_DUSTDEVIL)
		return;


		/* DONT DRAW IF PLAYER IS > n DEGREES TO CAMERA */

	v1 = &gPlayerInfo[playerNum].objNode->MotionVector;
	v2 = &gPlayerInfo[playerNum].camera.cameraAim;

	dot = OGLVector3D_Dot(v1, v2);
	if (dot < -.1f)
		return;



			/* CALC ADJUSTMENT FOR SCREEN COORDS TO OUR 640X480 COORDS */

	OGL_GetCurrentViewport(&px, &py, &pw, &ph, playerNum);

	float lrw = gLogicalRect.right - gLogicalRect.left;
	float lrh = gLogicalRect.bottom - gLogicalRect.top;

	screenToPaneX = lrw / (float)pw;
	screenToPaneY = lrh / (float)ph;


			/* SET SCALE BASED ON ASPECT RATIO */

	scale = GUNSIGHT_SCALE;


			/*******************************/
			/* DRAW AUTO-TARGET CROSSHAIRS */
			/*******************************/

	gGlobalTransparency = .8f;

	lockedOn = (gPlayerInfo[playerNum].crosshairTargetObj != nil);				// see if an object is targeted


			/* CALC SCREEN COORD */

	OGLPoint3D_Transform(&gPlayerInfo[playerNum].crosshairCoord[0],	&gWorldToWindowMatrix[playerNum], &screenCoord);
	screenCoord.x = screenCoord.x * screenToPaneX;
	screenCoord.y = screenCoord.y * screenToPaneY;
	screenCoord.x += gLogicalRect.left;
	screenCoord.y += gLogicalRect.top;


	if (lockedOn)
	{
		static float q = 0;

		q += gFramesPerSecondFrac * PI2;
		DrawInfobarSprite_Rotated(screenCoord.x, screenCoord.y, scale * 1.3, INFOBAR_SObjType_GunSight_Locked, q);
		DrawInfobarSprite_Centered(screenCoord.x, screenCoord.y, scale * 1.6, INFOBAR_SObjType_GunSight_OuterRing);
	}
	else
	{
		DrawInfobarSprite_Centered(screenCoord.x, screenCoord.y, scale, INFOBAR_SObjType_GunSight_Normal);

		OGLVector3D_Cross(v1, v2, &v3);
		if (v3.y > 0.0f)
			r = (-dot + 1.0f);
		else
			r = (dot - 1.0f);

		r *= 25.0f;
		DrawInfobarSprite_Rotated(screenCoord.x, screenCoord.y, scale * 1.6, INFOBAR_SObjType_GunSight_Pointer, r);
	}



			/*******************/
			/* DRAW FAR TARGET */
			/*******************/


	gGlobalTransparency = 1.0f;


	OGLPoint3D_Transform(&gPlayerInfo[playerNum].crosshairCoord[1],	&gWorldToWindowMatrix[playerNum], &screenCoord);
	screenCoord.x = screenCoord.x * screenToPaneX;
	screenCoord.y = screenCoord.y * screenToPaneY;
	screenCoord.x += gLogicalRect.left;
	screenCoord.y += gLogicalRect.top;

	DrawInfobarSprite_Centered(screenCoord.x, screenCoord.y, scale * .6, INFOBAR_SObjType_GunSight_Normal);



}









