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
int32_t		gNumSpritesInGroupList[MAX_SPRITE_GROUPS];		// note:  this must be int32_t's since that's what we read from the sprite file!



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


/************************** DISPOSE BG3D *****************************/

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


/************** LOAD SPRITE GROUP FROM IMAGE FILES ********************/

void LoadSpriteGroupFromFiles(int groupNum, int numSprites, const char** paths, int flags)
{
	AllocSpriteGroup(groupNum, numSprites);

	for (int i = 0; i < numSprites; i++)
	{
			/* LOAD TEXTURE FROM IMAGE FILE */

		int width = 0;
		int height = 0;
		GLuint textureName = OGL_TextureMap_LoadImageFile(paths[i], &width, &height);
		GAME_ASSERT(textureName);

			/* SET UP MATERIAL */

		MOMaterialData	matData =
		{
//			.setupInfo		= gGameViewInfoPtr,
			.flags			= BG3D_MATERIALFLAG_TEXTURED
								| BG3D_MATERIALFLAG_ALWAYSBLEND		// assume all files have alpha
								| BG3D_MATERIALFLAG_UPRIGHT_V,		// unlike .sprites files, standalone image files aren't flipped vertically
			.diffuseColor	= {1, 1, 1, 1},
			.width			= width,
			.height			= height,
			.pixelSrcFormat	= GL_UNSIGNED_BYTE,						// see OGL_TextureMap_LoadImageFile
			.pixelDstFormat	= GL_RGBA,								// see OGL_TextureMap_LoadImageFile
			.numMipmaps		= 1,
			.texturePixels	= {NULL},								// we've preloaded the texture
			.textureName	= {textureName},
		};

			/* SET SPRITE INFO */

		gSpriteGroupList[groupNum][i] = (SpriteType)
		{
			.width = width,
			.height = height,
			.aspectRatio = (float)height / (float)width,
			.materialObject = MO_CreateNewObjectOfType(MO_TYPE_MATERIAL, 0, &matData),
		};

		GAME_ASSERT(gSpriteGroupList[groupNum][i].materialObject);
	}
}


/********************** LOAD SPRITE FILE **************************/
//
// NOTE:  	All sprite files must be imported AFTER the draw context has been created,
//			because all imported textures are named with OpenGL and loaded into OpenGL!
//

void LoadSpriteGroup(int groupNum, const char* fileName, int flags)
{
short			refNum;
int				w,h;
long			count;
MOMaterialData	matData;

	(void) flags;


		/* OPEN THE FILE */

	FSSpec spec;
	FSMakeFSSpec(gDataSpec.vRefNum, gDataSpec.parID, fileName, &spec);

	if (FSpOpenDF(&spec, fsRdPerm, &refNum) != noErr)
		DoFatalAlert("LoadSpriteGroup: FSpOpenDF failed");

		/* READ # SPRITES IN THIS FILE */

	int32_t numSprites = 0;
	count = sizeof(numSprites);
	FSRead(refNum, &count, (Ptr) &numSprites);

	numSprites = SwizzleLong(&numSprites);

		/* ALLOCATE MEMORY FOR SPRITE RECORDS */

	AllocSpriteGroup(groupNum, numSprites);


			/********************/
			/* READ EACH SPRITE */
			/********************/

	for (int i = 0; i < numSprites; i++)
	{
		uint32_t *buffer;
		uint32_t	hasAlpha;

			/* READ WIDTH/HEIGHT, ASPECT RATIO */

		count = sizeof(int32_t);
		FSRead(refNum, &count, (Ptr) &gSpriteGroupList[groupNum][i].width);
		gSpriteGroupList[groupNum][i].width = SwizzleLong(&gSpriteGroupList[groupNum][i].width);

		count = sizeof(int32_t);
		FSRead(refNum, &count, (Ptr) &gSpriteGroupList[groupNum][i].height);
		gSpriteGroupList[groupNum][i].height = SwizzleLong(&gSpriteGroupList[groupNum][i].height);

		count = sizeof(float);
		FSRead(refNum, &count, (Ptr) &gSpriteGroupList[groupNum][i].aspectRatio);
		gSpriteGroupList[groupNum][i].aspectRatio = SwizzleFloat(&gSpriteGroupList[groupNum][i].aspectRatio);

		w = gSpriteGroupList[groupNum][i].width;
		h = gSpriteGroupList[groupNum][i].height;


				/* READ HAS-ALPHA FLAG */

		count = sizeof(hasAlpha);
		FSRead(refNum, &count, (Ptr) &hasAlpha);
		hasAlpha = SwizzleULong(&hasAlpha);


				/********************************/
				/* READ COMPRESSED JPEG TEXTURE */
				/********************************/

		{
			Ptr			jpegBuffer;
			int32_t		dataSize;

				/* READ JPEG DATA SIZE */

			count = sizeof(dataSize);
			FSRead(refNum, &count, (Ptr) &dataSize);
			dataSize = SwizzleLong(&dataSize);			// swizzle

				/* READ JPEG DATA */

			count = dataSize;
			jpegBuffer = AllocPtr(count);							// alloc memory for jpeg buffer
			FSRead(refNum, &count, jpegBuffer);						// read JPEG data (image desc + compressed data)

					/* ALLOCATE PIXEL BUFFER & GWORLD */

			buffer = AllocPtr(w * h * 4);

			DecompressQTImage(jpegBuffer, dataSize, (Ptr) buffer, w, h);

			SafeDisposePtr(jpegBuffer);
			jpegBuffer = NULL;


			/**********************/
			/* READ ALPHA CHANNEL */
			/**********************/

			if (hasAlpha)
			{
				uint8_t *alphaBuffer;

				count = w * h;

				alphaBuffer = AllocPtr(count);						// alloc buffer for alpha channel

				FSRead(refNum, &count, (Ptr) alphaBuffer);			// read alpha channel

				for (int j = 0; j < count; j++)
				{
					uint32_t	pixel = buffer[j];

					pixel  &= 0x00ffffff;						// mask out alpha
					pixel |= (uint32_t)alphaBuffer[j] << 24;
					buffer[j] =pixel;							// insert alpha
				}

				SafeDisposePtr(alphaBuffer);
			}
		}

				/*****************************/
				/* CREATE NEW TEXTURE OBJECT */
				/*****************************/

//		matData.setupInfo		= gGameViewInfoPtr;
		matData.flags			= BG3D_MATERIALFLAG_TEXTURED;
		if (hasAlpha)
			matData.flags		|= BG3D_MATERIALFLAG_ALWAYSBLEND;
		matData.diffuseColor.r	= 1;
		matData.diffuseColor.g	= 1;
		matData.diffuseColor.b	= 1;
		matData.diffuseColor.a	= 1;

		matData.numMipmaps		= 1;
		w = matData.width		= gSpriteGroupList[groupNum][i].width;
		h = matData.height		= gSpriteGroupList[groupNum][i].height;

		matData.pixelSrcFormat	= GL_UNSIGNED_INT_8_8_8_8_REV;
		matData.pixelDstFormat	= GL_RGBA8;

		matData.texturePixels[0]= nil;											// we're going to preload


		matData.textureName[0] 	= OGL_TextureMap_Load(buffer, matData.width, matData.height, GL_RGBA8,
													 GL_BGRA, GL_UNSIGNED_INT_8_8_8_8_REV, false);


		gSpriteGroupList[groupNum][i].materialObject = MO_CreateNewObjectOfType(MO_TYPE_MATERIAL, 0, &matData);

		GAME_ASSERT(gSpriteGroupList[groupNum][i].materialObject);


		SafeDisposePtr((Ptr)buffer);														// free the buffer

	}



		/* CLOSE FILE */

	FSClose(refNum);
}


/**************** SWIZZLE AGB TO RGBA *************************/

void SwizzleARGBtoRGBA(long w, long h, uint32_t *pixels)
{
long	count, i;

	count = w * h;

	for (i = 0; i < count; i++)
	{
		uint32_t	pixel32;

		pixel32 = pixels[i] << 8;				// get 32-bit ARGB pixel and shift up a byte to make RGBA
		pixel32 |= 0xff;						// set alpha to 0xff

		pixels[i] = pixel32;					// save it back out as RGBA
	}
}


/**************** SWIZZLE ARGB TO BGRA *************************/

void SwizzleARGBtoBGRA(long w, long h, uint32_t *pixels)
{
long	count, i;

	count = w * h;

	for (i = 0; i < count; i++)
	{
		pixels[i] = SwizzleULong(&pixels[i]);
	}
}


/**************** SET ALPHA IN ARGB BUFFER *************************/

void SetAlphaInARGBBuffer(long w, long h, uint32_t *pixels)
{
long	count, i;
unsigned char *a = (unsigned char *)pixels;

	count = w * h;

	for (i = 0; i < count; i++)
	{
		*a =  0xff;
		a += 4;
	}
}


/**************** SET ALPHA IN 16BIT BUFFER *************************/

void SetAlphaIn16BitBuffer(long w, long h, uint16_t *pixels)
{
long	count, i;

	count = w * h;

	for (i = 0; i < count; i++)
	{
#if __BIG_ENDIAN__
		pixels[i] |= 0x8000;
#else
		pixels[i] = SwizzleUShort(&pixels[i]);
		pixels[i] |= 0x8000;
#endif
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


			/* DISPOSE OF ALL LOADED OPENGL TEXTURENAMES */

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


			/* DISPOSE OF ALL LOADED OPENGL TEXTURENAMES */

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

