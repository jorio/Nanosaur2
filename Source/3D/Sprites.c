/****************************/
/*   	SPRITES.C			*/
/* (c)2003 Pangea Software  */
/* By Brian Greenstone      */
/****************************/


/****************************/
/*    EXTERNALS             */
/****************************/

#include "3DMath.h"
#include <AGL/aglmacro.h>


extern	float	gGlobalTransparency;
extern	int		gPolysThisFrame;
extern	Boolean			gSongPlayingFlag,gMuteMusicFlag;
extern	u_long			gGlobalMaterialFlags;

/****************************/
/*    PROTOTYPES            */
/****************************/


/****************************/
/*    CONSTANTS             */
/****************************/

#define	FONT_WIDTH	.51f


/*********************/
/*    VARIABLES      */
/*********************/

SpriteType	*gSpriteGroupList[MAX_SPRITE_GROUPS];
long		gNumSpritesInGroupList[MAX_SPRITE_GROUPS];		// note:  this must be long's since that's what we read from the sprite file!



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



/********************** LOAD SPRITE FILE **************************/
//
// NOTE:  	All sprite files must be imported AFTER the draw context has been created,
//			because all imported textures are named with OpenGL and loaded into OpenGL!
//

void LoadSpriteFile(FSSpec *spec, int groupNum, OGLSetupOutputType *setupInfo)
{
short			refNum;
int				i,w,h;
long			count, j;
MOMaterialData	matData;


		/* OPEN THE FILE */

	if (FSpOpenDF(spec, fsRdPerm, &refNum) != noErr)
		DoFatalAlert("\pLoadSpriteFile: FSpOpenDF failed");

		/* READ # SPRITES IN THIS FILE */

	count = sizeof(long);
	FSRead(refNum, &count, &gNumSpritesInGroupList[groupNum]);

	gNumSpritesInGroupList[groupNum] = SwizzleLong(&gNumSpritesInGroupList[groupNum]);


		/* ALLOCATE MEMORY FOR SPRITE RECORDS */

	gSpriteGroupList[groupNum] = (SpriteType *)AllocPtr(sizeof(SpriteType) * gNumSpritesInGroupList[groupNum]);
	if (gSpriteGroupList[groupNum] == nil)
		DoFatalAlert("\pLoadSpriteFile: AllocPtr failed");


			/********************/
			/* READ EACH SPRITE */
			/********************/

	for (i = 0; i < gNumSpritesInGroupList[groupNum]; i++)
	{
		u_long *buffer;
		u_long	hasAlpha;

			/* READ WIDTH/HEIGHT, ASPECT RATIO */

		count = sizeof(long);
		FSRead(refNum, &count, &gSpriteGroupList[groupNum][i].width);
		gSpriteGroupList[groupNum][i].width = SwizzleLong(&gSpriteGroupList[groupNum][i].width);

		count = sizeof(long);
		FSRead(refNum, &count, &gSpriteGroupList[groupNum][i].height);
		gSpriteGroupList[groupNum][i].height = SwizzleLong(&gSpriteGroupList[groupNum][i].height);

		count = sizeof(float);
		FSRead(refNum, &count, &gSpriteGroupList[groupNum][i].aspectRatio);
		gSpriteGroupList[groupNum][i].aspectRatio = SwizzleFloat(&gSpriteGroupList[groupNum][i].aspectRatio);

		w = gSpriteGroupList[groupNum][i].width;
		h = gSpriteGroupList[groupNum][i].height;


				/* READ HAS-ALPHA FLAG */

		count = sizeof(hasAlpha);
		FSRead(refNum, &count, &hasAlpha);
		hasAlpha = SwizzleULong(&hasAlpha);


				/********************************/
				/* READ COMPRESSED JPEG TEXTURE */
				/********************************/

		{
			Ptr			jpegBuffer;
			long		dataSize, descSize;
			GWorldPtr	buffGWorld;
			ImageDescriptionHandle	imageDescHandle;
			ImageDescriptionPtr		imageDescPtr;
			Ptr						imageDataPtr;
			Rect		r;
			OSErr		iErr;


				/* READ JPEG DATA SIZE */

			count = sizeof(dataSize);
			FSRead(refNum, &count, &dataSize);
			dataSize = SwizzleLong(&dataSize);			// swizzle

				/* READ JPEG DATA */

			count = dataSize;
			jpegBuffer = AllocPtr(count);							// alloc memory for jpeg buffer
			FSRead(refNum, &count, jpegBuffer);						// read JPEG data (image desc + compressed data)


				/* ALLOCATE PIXEL BUFFER & GWORLD */

			buffer = AllocPtr(w * h * 4);

			r.left = r.top = 0;	r.right = w; r.bottom = h;

			iErr = QTNewGWorldFromPtr(&buffGWorld, k32ARGBPixelFormat, &r, nil, nil, 0, buffer, w * 4);
			if (iErr || (buffGWorld == nil))
				DoFatalAlert("\pReadMaterialJPEGTextureMap: QTNewGWorldFromPtr failed.");

					/* EXTRACT THE IMAGE DESC */

			imageDescPtr = (ImageDescriptionPtr)jpegBuffer;						// create ptr into buffer to fake the imagedesc
			descSize = imageDescPtr->idSize;									// get size of the imagedesc data
			descSize = SwizzleLong(&descSize);

			imageDescHandle = (ImageDescriptionHandle)AllocHandle(descSize);	// convert Image Desc into a "real" handle
			BlockMove(imageDescPtr, *imageDescHandle, descSize);


				/* DECOMPRESS THE IMAGE */

			imageDataPtr = jpegBuffer + descSize;								// compressed image data is after the imagedesc data
			DecompressJPEGToGWorld(imageDescHandle, imageDataPtr, buffGWorld, nil);

//			SwizzleARGBtoRGBA(w, h, buffer);
			SwizzleARGBtoBGRA(w,h, buffer);


			/**********************/
			/* READ ALPHA CHANNEL */
			/**********************/

			if (hasAlpha)
			{
				u_char *alphaBuffer;

				count = w * h;

				alphaBuffer = AllocPtr(count);						// alloc buffer for alpha channel

				FSRead(refNum, &count, alphaBuffer);				// read alpha channel

				for (j = 0; j < count; j++)
				{
					u_long	pixel = buffer[j];

					pixel  &= 0x00ffffff;						// mask out alpha
					pixel |= (u_long)alphaBuffer[j] << 24;
					buffer[j] =pixel;							// insert alpha
				}

				SafeDisposePtr(alphaBuffer);

			}
			else
				SetAlphaInARGBBuffer(w,h,buffer);				// no alpha channel so set all aphas to $ff


			DisposeHandle((Handle)imageDescHandle);								// free our image desc handle
			SafeDisposePtr(jpegBuffer);											// free the jpeg data
			DisposeGWorld(buffGWorld);											// free the gworld (but it keeps the pixel buffer)
		}

				/*****************************/
				/* CREATE NEW TEXTURE OBJECT */
				/*****************************/

		matData.setupInfo		= setupInfo;
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

		if (gSpriteGroupList[groupNum][i].materialObject == nil)
			DoFatalAlert("\pLoadSpriteFile: MO_CreateNewObjectOfType failed");


		SafeDisposePtr((Ptr)buffer);														// free the buffer

	}



		/* CLOSE FILE */

	FSClose(refNum);


}


/**************** SWIZZLE AGB TO RGBA *************************/

void SwizzleARGBtoRGBA(long w, long h, u_long *pixels)
{
long	count, i;

	count = w * h;

	for (i = 0; i < count; i++)
	{
		u_long	pixel32;

		pixel32 = pixels[i] << 8;				// get 32-bit ARGB pixel and shift up a byte to make RGBA
		pixel32 |= 0xff;						// set alpha to 0xff

		pixels[i] = pixel32;					// save it back out as RGBA
	}
}


/**************** SWIZZLE ARGB TO BGRA *************************/

void SwizzleARGBtoBGRA(long w, long h, u_long *pixels)
{
long	count, i;

	count = w * h;

	for (i = 0; i < count; i++)
	{
		pixels[i] = SwizzleULong(&pixels[i]);
	}
}


/**************** SET ALPHA IN ARGB BUFFER *************************/

void SetAlphaInARGBBuffer(long w, long h, u_long *pixels)
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

void SetAlphaIn16BitBuffer(long w, long h, u_short *pixels)
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

ObjNode *MakeSpriteObject(NewObjectDefinitionType *newObjDef, OGLSetupOutputType *setupInfo, Boolean drawCentered)
{
ObjNode				*newObj;
MOSpriteObject		*spriteMO;
MOSpriteSetupData	spriteData;

			/* ERROR CHECK */

	if (newObjDef->type >= gNumSpritesInGroupList[newObjDef->group])
		DoFatalAlert("\pMakeSpriteObject: illegal type");


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

	spriteMO = MO_CreateNewObjectOfType(MO_TYPE_SPRITE, (u_long)setupInfo, &spriteData);
	if (!spriteMO)
		DoFatalAlert("\pMakeSpriteObject: MO_CreateNewObjectOfType failed!");


			/* SET SPRITE MO INFO */

	spriteMO->objectData.scaleX =
	spriteMO->objectData.scaleY = newObj->Scale.x;
	spriteMO->objectData.coord = newObj->Coord;


			/* ATTACH META OBJECT TO OBJNODE */

	newObj->SpriteMO = spriteMO;

	return(newObj);
}


/*********************** MODIFY SPRITE OBJECT IMAGE ******************************/

void ModifySpriteObjectFrame(ObjNode *theNode, short type, OGLSetupOutputType *setupInfo)
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

	spriteMO = MO_CreateNewObjectOfType(MO_TYPE_SPRITE, (u_long)setupInfo, &spriteData);
	if (!spriteMO)
		DoFatalAlert("\pModifySpriteObjectFrame: MO_CreateNewObjectOfType failed!");


			/* SET SPRITE MO INFO */

	spriteMO->objectData.scaleX =
	spriteMO->objectData.scaleY = theNode->Scale.x;
	spriteMO->objectData.coord = theNode->Coord;


			/* ATTACH META OBJECT TO OBJNODE */

	theNode->SpriteMO = spriteMO;
	theNode->Type = type;
}


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
		DoFatalAlert("\pBlendAllSpritesInGroup: this group is empty");


			/* DISPOSE OF ALL LOADED OPENGL TEXTURENAMES */

	for (i = 0; i < n; i++)
	{
		m = gSpriteGroupList[group][i].materialObject; 				// get material object ptr
		if (m == nil)
			DoFatalAlert("\pBlendAllSpritesInGroup: material == nil");

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
		DoFatalAlert("\pBlendASprite: illegal type");


			/* DISPOSE OF ALL LOADED OPENGL TEXTURENAMES */

	m = gSpriteGroupList[group][type].materialObject; 				// get material object ptr
	if (m == nil)
		DoFatalAlert("\pBlendASprite: material == nil");

	m->objectData.flags |= 	BG3D_MATERIALFLAG_ALWAYSBLEND;		// set flag
}


/************************** DRAW SPRITE ************************/

void DrawSprite(int	group, int type, float x, float y, float scale, float rot, u_long flags, const OGLSetupOutputType *setupInfo)
{
AGLContext agl_ctx = setupInfo->drawContext;


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

	MO_DrawMaterial(gSpriteGroupList[group][type].materialObject, setupInfo);


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




#pragma mark -


/************* MAKE FONT STRING OBJECT *************/

ObjNode *MakeFontStringObject(const Str31 s, NewObjectDefinitionType *newObjDef, OGLSetupOutputType *setupInfo, Boolean center)
{
ObjNode				*newObj;
MOSpriteObject		*spriteMO;
MOSpriteSetupData	spriteData;
int					i,len;
char				letter;
float				scale,x;

	newObjDef->group = SPRITE_GROUP_FONT;
	newObjDef->genre = FONTSTRING_GENRE;
	newObjDef->flags |= STATUS_BIT_DOUBLESIDED|STATUS_BIT_NOZBUFFER|STATUS_BIT_NOLIGHTING;


			/* MAKE OBJNODE */

	newObj = MakeNewObject(newObjDef);

	newObj->NumStringSprites = 0;											// no sprites in there yet

	len = s[0];																// get length of string
	if (len > 31)
		DoFatalAlert("\pMakeFontStringObject: string > 31 characters!");


			/* ADJUST FOR CENTERING */

	scale = newObj->Scale.x;												// get scale factor

	if (center)
		x = newObj->Coord.x - GetStringWidth(s, scale) * .5f;				// calc center starting x coord on left
	else
		x = newObj->Coord.x;												// dont center text

	x += (scale * .5f);														// offset half a character

			/****************************/
			/* MAKE SPRITE META-OBJECTS */
			/****************************/

	for (i = 1; i <= len; i++)
	{
		letter = s[i];

		spriteData.type = CharToSprite(letter);								// convert letter to sprite index
		if (spriteData.type == -1)											// skip spaces
			goto next;

		spriteData.loadFile = false;										// these sprites are already loaded into gSpriteList
		spriteData.group	= newObjDef->group;								// set group

		spriteData.drawCentered = center;

		spriteMO = MO_CreateNewObjectOfType(MO_TYPE_SPRITE, (u_long)setupInfo, &spriteData);
		if (!spriteMO)
			DoFatalAlert("\pMakeFontStringObject: MO_CreateNewObjectOfType failed!");


				/* SET SPRITE MO INFO */

		spriteMO->objectData.coord.x = x;
		spriteMO->objectData.coord.y = newObj->Coord.y;
		spriteMO->objectData.coord.z = newObj->Coord.z;

		spriteMO->objectData.scaleX =
		spriteMO->objectData.scaleY = scale;



				/* ATTACH META OBJECT TO OBJNODE */

		newObj->StringCharacters[newObj->NumStringSprites++] = spriteMO;

next:
		x += GetCharSpacing(letter, scale);									// next letter x coord
	}


	return(newObj);
}




/***************** CHAR TO SPRITE **********************/

int CharToSprite(char c)
{

	if ((c >= 'a') && (c <= 'z'))
	{
		return(FONT_SObjType_A + (c - 'a'));
	}
	else
	if ((c >= 'A') && (c <= 'Z'))
	{
		return(FONT_SObjType_A + (c - 'A'));
	}
	else
	if ((c >= '0') && (c <= '9'))
	{
		return(FONT_SObjType_0 + (c - '0'));
	}
	else
	{
		short	s;
		switch(c)
		{
			case	'.':
					s = FONT_SObjType_Period;
					break;

			case	',':
					s = FONT_SObjType_Comma;
					break;

			case	'-':
					s = FONT_SObjType_Dash;
					break;

			case	'&':
					s = FONT_SObjType_Ampersand;
					break;


			case	'!':
					s = FONT_SObjType_ExclamationMark;
					break;

			case	'†':
					s = FONT_SObjType_UU;
					break;

			case	'…':
					s = FONT_SObjType_OO;
					break;

			case	'€':
					s = FONT_SObjType_AA;
					break;

			case	'':
					s = FONT_SObjType_AO;
					break;

			case	'„':
					s = FONT_SObjType_NN;
					break;

			case	'ƒ':
					s = FONT_SObjType_EE;
					break;

			case	'é':
					s = FONT_SObjType_EE;
					break;

			case	'æ':
					s = FONT_SObjType_E;
					break;

			case	'Ë':
					s = FONT_SObjType_Ax;
					break;

			case	'ï':
					s = FONT_SObjType_Ox;
					break;

			case	'î':
					s = FONT_SObjType_Oa;
					break;

			case	'§':
					s = FONT_SObjType_beta;
					break;

			case	'‚':
					s = FONT_SObjType_C;
					break;

			case	CHAR_APOSTROPHE:
					s = FONT_SObjType_Apostrophe;
					break;

			case	'~':
					s = FONT_SObjType_BackArrow;
					break;

			default:
					s = -1;

		}
	return(s);
	}

}


/***************** GET STRING WIDTH *************************/

float GetStringWidth(const u_char *s, float scale)
{
int		i;
float	w = 0;

	for (i = 1; i <= s[0]; i++)
		w += GetCharSpacing(s[i], scale);


	return(w);
}


/******************** GET CHAR SPACING *************************/

float GetCharSpacing(char c, float spacingScale)
{
float	s;

	switch(c)
	{
		case	',':
				s = .2;
				break;

		case	'I':
		case	'.':
		case	'!':
		case	'i':
				s = .3;
				break;

		case	' ':
		case	CHAR_APOSTROPHE:
				s = .4;
				break;

		case	'S':
		case	'C':
		case	'J':
		case	'L':
		case	'E':
		case	'ƒ':
		case	'F':
		case	'0':
		case	'1':
		case	'2':
		case	'3':
		case	'4':
		case	'5':
		case	'6':
		case	'7':
		case	'8':
		case	'9':
				s = .5;
				break;

		case	'T':
		case	'P':
				s = .6;
				break;

		case	'H':
		case	'X':
		case	'D':
		case	'G':
				s = .7f;
				break;

		case	'A':
		case	'€':
		case	'N':
		case	'U':
		case	'†':
		case	'V':
		case	'O':
		case	'Q':
				s = .75;
				break;

		case	'M':
		case	'W':
				s = .9f;
				break;

		default:
				s = .65f;
	}


	return(spacingScale * s);


}





