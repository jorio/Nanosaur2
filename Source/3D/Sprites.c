/****************************/
/*   	SPRITES.C			*/
/* By Brian Greenstone      */
/* (c)2003 Pangea Software  */
/* (c)2022 Iliyas Jorio     */
/****************************/


/****************************/
/*    EXTERNALS             */
/****************************/

#include "game.h"
#include "stb_image.h"


/****************************/
/*    PROTOTYPES            */
/****************************/


/****************************/
/*    CONSTANTS             */
/****************************/


/*********************/
/*    VARIABLES      */
/*********************/

SpriteType	*gSpriteGroupList[MAX_SPRITE_GROUPS];
int gNumSpritesInGroupList[MAX_SPRITE_GROUPS];



/****************** INIT SPRITE MANAGER ***********************/

void InitSpriteManager(void)
{
int	i;

	for (i = 0; i < MAX_SPRITE_GROUPS; i++)
	{
		gSpriteGroupList[i] = nil;
		gNumSpritesInGroupList[i] = 0;
	}
}


/******************* DISPOSE ALL SPRITE GROUPS ****************/

void DisposeAllSpriteGroups(void)
{
int	i;

	for (i = 0; i < MAX_SPRITE_GROUPS; i++)
	{
		if (gSpriteGroupList[i])
			DisposeSpriteGroup(i);
	}
}


/************************** DISPOSE SPRITE GROUP *****************************/

void DisposeSpriteGroup(int groupNum)
{
int 		i,n;

	n = gNumSpritesInGroupList[groupNum];						// get # sprites in this group
	if ((n == 0) || (gSpriteGroupList[groupNum] == nil))
		return;


			/* DISPOSE OF ALL LOADED OPENGL TEXTURENAMES */

	for (i = 0; i < n; i++)
		MO_DisposeObjectReference(gSpriteGroupList[groupNum][i].materialObject);


		/* DISPOSE OF GROUP'S ARRAY */

	SafeDisposePtr((Ptr)gSpriteGroupList[groupNum]);
	gSpriteGroupList[groupNum] = nil;
	gNumSpritesInGroupList[groupNum] = 0;
}



/********************** ALLOCATE SPRITE GROUP **************************/

void AllocSpriteGroup(int groupNum, int capacity)
{
	GAME_ASSERT_MESSAGE(!gSpriteGroupList[groupNum], "Sprite group already allocated");
	GAME_ASSERT(gNumSpritesInGroupList[groupNum] == 0);

	gNumSpritesInGroupList[groupNum] = capacity;

	gSpriteGroupList[groupNum] = (SpriteType *)AllocPtrClear(sizeof(SpriteType) * capacity);
	GAME_ASSERT(gSpriteGroupList[groupNum]);
}


/************** LOAD SPRITETYPE FROM IMAGE FILE ********************/

static SpriteType LoadSpriteFromDualImage(const char* path)
{
		/* LOAD TEXTURE FROM IMAGE FILE */

	int width = 0;
	int height = 0;
	int hasAlpha = 0;
	GLuint textureName = OGL_TextureMap_LoadImageFile(path, &width, &height, &hasAlpha);
	GAME_ASSERT(textureName);

		/* SET UP MATERIAL */

	MOMaterialData matData =
	{
		.flags			= BG3D_MATERIALFLAG_TEXTURED
							| (hasAlpha? BG3D_MATERIALFLAG_ALWAYSBLEND: 0),
		.diffuseColor	= {1, 1, 1, 1},
		.width			= width,
		.height			= height,
		.numMipmaps		= 1,
		.textureName	= {textureName},
	};

	return (SpriteType)
	{
		.width = matData.width,
		.height = matData.height,
		.aspectRatio = (float)matData.height / (float)matData.height,
		.materialObject = MO_CreateNewObjectOfType(MO_TYPE_MATERIAL, 0, &matData),
	};
}

/**************** LOAD SPRITE GROUP FROM SINGLE FILE **********************/

void LoadSpriteGroupFromFile(int groupNum, const char* path, int flags)
{
	AllocSpriteGroup(groupNum, 1);
	gSpriteGroupList[groupNum][0] = LoadSpriteFromDualImage(path);
	GAME_ASSERT(gSpriteGroupList[groupNum][0].materialObject);
}

/**************** LOAD SPRITE GROUP FROM SEQUENCE OF IMAGE FILES **********************/

void LoadSpriteGroupFromSeries(int groupNum, int numSprites, const char* seriesName)
{
	AllocSpriteGroup(groupNum, numSprites);

	for (int i = 0; i < gNumSpritesInGroupList[groupNum]; i++)
	{
		char path[64];
		snprintf(path, sizeof(path), ":Sprites:%s:%s%03d", seriesName, seriesName, i);

		gSpriteGroupList[groupNum][i] = LoadSpriteFromDualImage(path);
		GAME_ASSERT(gSpriteGroupList[groupNum][i].materialObject);
	}
}


/**************** LOAD SPRITE GROUP FROM SEQUENCE OF IMAGE FILES **********************/

void LoadSpriteGroupFromFiles(int groupNum, int numSprites, const char** spritePaths)
{
	AllocSpriteGroup(groupNum, numSprites);

	for (int i = 0; i < gNumSpritesInGroupList[groupNum]; i++)
	{
		gSpriteGroupList[groupNum][i] = LoadSpriteFromDualImage(spritePaths[i]);
		GAME_ASSERT(gSpriteGroupList[groupNum][i].materialObject);
	}
}



#pragma mark -

/************* MAKE NEW SRITE OBJECT *************/

ObjNode *MakeSpriteObject(NewObjectDefinitionType *newObjDef, Boolean drawCentered)
{
ObjNode				*newObj;
MOSpriteObject		*spriteMO;
MOSpriteSetupData	spriteData;

			/* ERROR CHECK */

	if (newObjDef->type >= gNumSpritesInGroupList[newObjDef->group])
		DoFatalAlert("MakeSpriteObject: illegal type");


			/* MAKE OBJNODE */

	newObjDef->genre = SPRITE_GENRE;
	newObjDef->flags |= STATUS_BIT_DOUBLESIDED|STATUS_BIT_NOZBUFFER|STATUS_BIT_NOLIGHTING|STATUS_BIT_NOTEXTUREWRAP;

	newObj = MakeNewObject(newObjDef);
	if (newObj == nil)
		return(nil);

			/* MAKE SPRITE META-OBJECT */

	spriteData.loadFile 	= false;										// these sprites are already loaded into gSpriteList
	spriteData.group		= newObjDef->group;								// set group
	spriteData.type 		= newObjDef->type;								// set group subtype
	spriteData.drawCentered = drawCentered;

	spriteMO = MO_CreateNewObjectOfType(MO_TYPE_SPRITE, 0, &spriteData);
	if (!spriteMO)
		DoFatalAlert("MakeSpriteObject: MO_CreateNewObjectOfType failed!");


			/* SET SPRITE MO INFO */

	spriteMO->objectData.scaleX =
	spriteMO->objectData.scaleY = newObj->Scale.x;
	spriteMO->objectData.coord = newObj->Coord;


			/* ATTACH META OBJECT TO OBJNODE */

	newObj->SpriteMO = spriteMO;

	return(newObj);
}

#if 0

/*********************** MODIFY SPRITE OBJECT IMAGE ******************************/

void ModifySpriteObjectFrame(ObjNode *theNode, short type)
{
MOSpriteSetupData	spriteData;
MOSpriteObject		*spriteMO;


	if (type == theNode->Type)										// see if it is the same
		return;

		/* DISPOSE OF OLD TYPE */

	MO_DisposeObjectReference(theNode->SpriteMO);


		/* MAKE NEW SPRITE MO */

	spriteData.loadFile = false;									// these sprites are already loaded into gSpriteList
	spriteData.group	= theNode->Group;							// set group
	spriteData.type 	= type;										// set group subtype

	spriteMO = MO_CreateNewObjectOfType(MO_TYPE_SPRITE, 0, &spriteData);
	if (!spriteMO)
		DoFatalAlert("ModifySpriteObjectFrame: MO_CreateNewObjectOfType failed!");


			/* SET SPRITE MO INFO */

	spriteMO->objectData.scaleX =
	spriteMO->objectData.scaleY = theNode->Scale.x;
	spriteMO->objectData.coord = theNode->Coord;


			/* ATTACH META OBJECT TO OBJNODE */

	theNode->SpriteMO = spriteMO;
	theNode->Type = type;
}

#endif


#pragma mark -

/*********************** BLEND ALL SPRITES IN GROUP ********************************/
//
// Set the blending flag for all sprites in the group.
//

void BlendAllSpritesInGroup(short group)
{
int		i,n;
MOMaterialObject	*m;

	n = gNumSpritesInGroupList[group];								// get # sprites in this group
	if ((n == 0) || (gSpriteGroupList[group] == nil))
		DoFatalAlert("BlendAllSpritesInGroup: this group is empty");


	for (i = 0; i < n; i++)
	{
		m = gSpriteGroupList[group][i].materialObject; 				// get material object ptr
		if (m == nil)
			DoFatalAlert("BlendAllSpritesInGroup: material == nil");

		m->objectData.flags |= 	BG3D_MATERIALFLAG_ALWAYSBLEND;		// set flag
	}
}


/*********************** BLEND A SPRITE ********************************/
//
// Set the blending flag for 1 sprite in the group.
//

void BlendASprite(int group, int type)
{
MOMaterialObject	*m;

	if (type >= gNumSpritesInGroupList[group])
		DoFatalAlert("BlendASprite: illegal type");


	m = gSpriteGroupList[group][type].materialObject; 				// get material object ptr
	if (m == nil)
		DoFatalAlert("BlendASprite: material == nil");

	m->objectData.flags |= 	BG3D_MATERIALFLAG_ALWAYSBLEND;		// set flag
}


#if 0
/************************** DRAW SPRITE ************************/

void DrawSprite(int	group, int type, float x, float y, float scale, float rot, uint32_t flags)
{
			/* SET STATE */

	OGL_PushState();								// keep state

	glMatrixMode(GL_PROJECTION);
	glLoadIdentity();
	glOrtho(0, 640, 480, 0, 0, 1);
	glMatrixMode(GL_MODELVIEW);
	glLoadIdentity();

	gGlobalMaterialFlags = BG3D_MATERIALFLAG_CLAMP_V|BG3D_MATERIALFLAG_CLAMP_U;	// clamp all textures
	OGL_DisableLighting();
	OGL_DisableCullFace();
	glDisable(GL_DEPTH_TEST);


	if (flags & SPRITE_FLAG_GLOW)
		OGL_BlendFunc(GL_SRC_ALPHA, GL_ONE);

	if (rot != 0.0f)
		glRotatef(OGLMath_RadiansToDegrees(rot), 0, 0, 1);											// remember:  rotation is in degrees, not radians!


		/* ACTIVATE THE MATERIAL */

	MO_DrawMaterial(gSpriteGroupList[group][type].materialObject);


			/* DRAW IT */

	glBegin(GL_QUADS);
	glTexCoord2f(0,1);	glVertex2f(x, y);
	glTexCoord2f(1,1);	glVertex2f(x+scale, y);
	glTexCoord2f(1,0);	glVertex2f(x+scale, y+scale);
	glTexCoord2f(0,0);	glVertex2f(x, y+scale);
	glEnd();


		/* CLEAN UP */

	OGL_PopState();									// restore state
	gGlobalMaterialFlags = 0;

	gPolysThisFrame += 2;						// 2 tris drawn
}
#endif

