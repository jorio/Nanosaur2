/****************************/
/*   OPENGL SUPPORT.C	    */
/*   By Brian Greenstone    */
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

static void OGL_CreateDrawContext(OGLSetupInputType *def);
static void OGL_SetStyles(OGLSetupInputType *setupDefPtr);
static void OGL_CreateLights(OGLLightDefType *lightDefPtr);
static void OGL_InitFont(void);
static void OGL_FreeFont(void);

static void OGL_InitVertexArrayMemory(void);
static void OGL_UpdateVertexArrayRange(void);
static void OGL_DisableVertexArrayRanges(void);
static long OGL_MaxMemForVARType(Byte varType);
static void	ConvertTextureToGrey(void *imageMemory, short width, short height, GLint srcFormat, GLint dataType);
static void	ConvertTextureToColorAnaglyph(void *imageMemory, short width, short height, GLint srcFormat, GLint dataType);

static void DrawBlueLine(GLint window_width, GLint window_height);
static void ClearAllBuffersToBlack(void);

/****************************/
/*    CONSTANTS             */
/****************************/

#define	STATE_STACK_SIZE	20


struct VertexArrayMemoryNode
{
	struct	VertexArrayMemoryNode	*prevNode;
	struct	VertexArrayMemoryNode	*nextNode;

	Ptr			pointer;
	size_t		size;
};
typedef struct VertexArrayMemoryNode VertexArrayMemoryNode;



/*********************/
/*    VARIABLES      */
/*********************/

static	Boolean			gDoAnisotropy 	= false;		// WARNING!!  THIS IS A MAJOR PERFORMANCE KILLER
static	float 			gMaxAnisotropy 	= 1.0;


float					gAnaglyphFocallength	= 450.0f;
float					gAnaglyphEyeSeparation 	= 40.0f;
Byte					gAnaglyphPass;
u_char					gAnaglyphGreyTable[255];

AGLDrawable				gAGLWin;
AGLContext				gAGLContext = nil;

static GLuint 			gFontList;


OGLMatrix4x4	gViewToFrustumMatrix,gWorldToViewMatrix,gWorldToFrustumMatrix, gLocalToViewMatrix, gLocalToFrustumMatrix;
OGLMatrix4x4	gWorldToWindowMatrix[MAX_SPLITSCREENS],gFrustumToWindowMatrix[MAX_SPLITSCREENS];

Byte			gCurrentSplitScreenPane = 0;
Byte			gActiveSplitScreenMode 	= SPLITSCREEN_MODE_NONE;		// currently active split mode


float			gCurrentPaneAspectRatio = 1;


int			gStateStackIndex = 0;

Boolean		gStateStack_Lighting[STATE_STACK_SIZE];
Boolean		gStateStack_CullFace[STATE_STACK_SIZE];
Boolean		gStateStack_DepthTest[STATE_STACK_SIZE];
Boolean		gStateStack_Normalize[STATE_STACK_SIZE];
Boolean		gStateStack_Texture2D[STATE_STACK_SIZE];
Boolean		gStateStack_Blend[STATE_STACK_SIZE];
Boolean		gStateStack_Fog[STATE_STACK_SIZE];
GLboolean	gStateStack_DepthMask[STATE_STACK_SIZE];
GLint		gStateStack_BlendDst[STATE_STACK_SIZE];
GLint		gStateStack_BlendSrc[STATE_STACK_SIZE];
static OGLColorRGBA	gStateStack_Color[STATE_STACK_SIZE];

Boolean			gMyState_Lighting;
Boolean			gMyState_Blend;
Boolean			gMyState_Fog;
Boolean			gMyState_Texture2D;
Boolean			gMyState_CullFace;
uint32_t			gMyState_TextureUnit;
OGLColorRGBA	gMyState_Color;
GLenum			gMyState_BlendFuncS, gMyState_BlendFuncD;


int			gPolysThisFrame;

		/* VERTEX ARRAY RANGE */

static	Boolean					gVARMemoryAllocated = false;
static	Ptr						gVertexArrayMemoryBlock[NUM_VERTEX_ARRAY_RANGES] = {NULL};
static	VertexArrayMemoryNode	*gVertexArrayMemory_Head[NUM_VERTEX_ARRAY_RANGES];
static	VertexArrayMemoryNode	*gVertexArrayMemory_Tail[NUM_VERTEX_ARRAY_RANGES];
#if VERTEXARRAYRANGES
static	size_t					gVertexArrayRangeSize[NUM_VERTEX_ARRAY_RANGES] = {0};
static	size_t					gPreviousVertexArrayRangeSize[NUM_VERTEX_ARRAY_RANGES] = {0};
static	Boolean					gVertexArrayRangeUsed[NUM_VERTEX_ARRAY_RANGES] = {0};
static	Boolean					gForceVertexArrayUpdate[NUM_VERTEX_ARRAY_RANGES] = {0};
static	Boolean					gVertexArrayRangeActivated[NUM_VERTEX_ARRAY_RANGES] = {0};
GLuint							gVertexArrayRangeObjects[NUM_VERTEX_ARRAY_RANGES] = {0};
Boolean							gHardwareSupportsVertexArrayRange = false;
Boolean							gUsingVertexArrayRange = false;
#endif


/******************** OGL BOOT *****************/
//
// Initialize my OpenGL stuff.
//

void OGL_Boot(void)
{
short	i;
float	f;

		/* GENERATE ANAGLYPH GREY CONVERSION TABLE */
		//
		// This makes an intensity curve to brighten things up, but sometimes
		// it washes them out.
		//

	f = 0;
	for (i = 0; i < 255; i++)
	{
		gAnaglyphGreyTable[i] = sin(f) * 255.0f;
		f += (PI/2.0) / 255.0f;
	}

}


/*********************** OGL: NEW VIEW DEF **********************/
//
// fills a view def structure with default values.
//

void OGL_NewViewDef(OGLSetupInputType *viewDef)
{
const OGLColorRGBA		clearColor = {0,0,0,1};
const OGLPoint3D			cameraFrom = { 0, 0, 0.0 };
const OGLPoint3D			cameraTo = { 0, 0, -1 };
const OGLVector3D			cameraUp = { 0.0, 1.0, 0.0 };
const OGLColorRGBA			ambientColor = { .2, .2, .2, 1 };
const OGLColorRGBA			fillColor = { 1.0, 1.0, 1.0, 1 };
static OGLVector3D			fillDirection1 = { 1, 0, -1 };
static OGLVector3D			fillDirection2 = { -1, -.3, -.3 };


	OGLVector3D_Normalize(&fillDirection1, &fillDirection1);
	OGLVector3D_Normalize(&fillDirection2, &fillDirection2);

	viewDef->view.clearColor 		= clearColor;
	viewDef->view.clip.left 	= 0;
	viewDef->view.clip.right 	= 0;
	viewDef->view.clip.top 		= 0;
	viewDef->view.clip.bottom 	= 0;
	viewDef->view.numPanes	 	= 1;				// assume only 1 pane
	viewDef->view.clearBackBuffer = true;

	viewDef->camera.from[0]			= cameraFrom;
	viewDef->camera.from[1] 		= cameraFrom;
	viewDef->camera.to[0] 			= cameraTo;
	viewDef->camera.to[1] 			= cameraTo;
	viewDef->camera.up[0] 			= cameraUp;
	viewDef->camera.up[1] 			= cameraUp;
	viewDef->camera.hither 			= 10;
	viewDef->camera.yon 			= 4000;
	viewDef->camera.fov 			= 1.2;

	viewDef->styles.useFog			= false;
	viewDef->styles.fogStart		= viewDef->camera.yon * .5f;
	viewDef->styles.fogEnd			= viewDef->camera.yon;
	viewDef->styles.fogDensity		= 1.0;
	viewDef->styles.fogMode			= GL_LINEAR;

	viewDef->lights.ambientColor 	= ambientColor;
	viewDef->lights.numFillLights 	= 1;
	viewDef->lights.fillDirection[0] = fillDirection1;
	viewDef->lights.fillDirection[1] = fillDirection2;
	viewDef->lights.fillColor[0] 	= fillColor;
	viewDef->lights.fillColor[1] 	= fillColor;
}


/************** SETUP OGL WINDOW *******************/

void OGL_SetupWindow(OGLSetupInputType *setupDefPtr, OGLSetupOutputType **outputHandle)
{
OGLSetupOutputType	*outputPtr;
short	i;

	HideCursor();		// do this just as a safety precaution to make sure no cursor lingering around

			/* ALLOC MEMORY FOR OUTPUT DATA */

	outputPtr = (OGLSetupOutputType *)AllocPtr(sizeof(OGLSetupOutputType));
	if (outputPtr == nil)
		DoFatalAlert("OGL_SetupWindow: AllocPtr failed");

			/* SET SOME PANE INFO */

	gCurrentSplitScreenPane = 0;
	switch(gNumPlayers)
	{
		case	1:
				gActiveSplitScreenMode = SPLITSCREEN_MODE_NONE;
				break;

		case	2:
				gActiveSplitScreenMode = gGamePrefs.splitScreenMode;
				break;

		default:
				DoFatalAlert("OGL_SetupWindow: # panes not implemented");
	}


				/* SETUP */

	OGL_CreateDrawContext(setupDefPtr);
	OGL_CheckError();
	OGL_SetStyles(setupDefPtr);
	OGL_CheckError();
	OGL_CreateLights(&setupDefPtr->lights);
	OGL_CheckError();

	OGL_InitVertexArrayMemory();
	OGL_CheckError();


				/* PASS BACK INFO */

	outputPtr->drawContext 		= gAGLContext;
	outputPtr->clip 			= setupDefPtr->view.clip;
	outputPtr->hither 			= setupDefPtr->camera.hither;			// remember hither/yon
	outputPtr->yon 				= setupDefPtr->camera.yon;
	outputPtr->useFog 			= setupDefPtr->styles.useFog;
	outputPtr->clearBackBuffer 	= setupDefPtr->view.clearBackBuffer;
	outputPtr->clearColor		= setupDefPtr->view.clearColor;
	outputPtr->windowAspectRatio = (float)gGameWindowHeight / (float)gGameWindowWidth;

	outputPtr->isActive = true;											// it's now an active structure

	outputPtr->lightList = setupDefPtr->lights;							// copy lights

	for (i = 0; i < MAX_SPLITSCREENS; i++)
	{
		outputPtr->fov[i] = setupDefPtr->camera.fov;					// each camera will have its own fov so we can change it for special effects
		OGL_UpdateCameraFromTo(outputPtr, &setupDefPtr->camera.from[i], &setupDefPtr->camera.to[i], i);
	}

	outputPtr->frameCount = 0;											// init frame counter

	*outputHandle = outputPtr;											// return value to caller
}



/***************** OGL_DisposeWindowSetup ***********************/
//
// Disposes of all data created by OGL_SetupWindow
//

void OGL_DisposeWindowSetup(OGLSetupOutputType **dataHandle)
{
OGLSetupOutputType	*data;

	data = *dataHandle;
	if (data == nil)												// see if this setup exists
		DoFatalAlert("OGL_DisposeWindowSetup: data == nil");


		/***********************************************/
		/* MAKE SURE TO CLEAR STEREO BUFFERS IF NEEDED */
		/***********************************************/

			/* SET BUFFER FOR SHUTTER GLASSES */

	ClearAllBuffersToBlack();




			/* KILL DEBUG FONT */

	OGL_FreeFont();

			/* FREE VERTEX ARRAY RANGE MEMORY */

	OGL_DisableVertexArrayRanges();


			/* NUKE THE CONTEXT */

	SDL_GL_MakeCurrent(gSDLWindow, nil);					// make context not current
	SDL_GL_DeleteContext(data->drawContext);				// nuke the AGL context


		/* FREE MEMORY & NIL POINTER */

	data->isActive = false;									// now inactive
	SafeDisposePtr((Ptr)data);
	*dataHandle = nil;

	gAGLContext = nil;
}




/**************** OGL: CREATE DRAW CONTEXT *********************/

static void OGL_CreateDrawContext(OGLSetupInputType *def)
{
GLint			maxTexSize;
OGLViewDefType *viewDefPtr = &def->view;

	GAME_ASSERT_MESSAGE(!gAGLContext, "GL context already exists");
	GAME_ASSERT_MESSAGE(gSDLWindow, "Window must be created before the DC!");

			/* CREATE AGL CONTEXT & ATTACH TO WINDOW */

	gAGLContext = SDL_GL_CreateContext(gSDLWindow);

	if (!gAGLContext)
		DoFatalAlert(SDL_GetError());

	GAME_ASSERT(glGetError() == GL_NO_ERROR);


			/* ACTIVATE CONTEXT */

	int mkc = SDL_GL_MakeCurrent(gSDLWindow, gAGLContext);
	GAME_ASSERT_MESSAGE(mkc == 0, SDL_GetError());

			/* ENABLE VSYNC */

	SDL_GL_SetSwapInterval(1);



	SOFTIMPME;
#if 0
AGLPixelFormat 	fmt;
GLboolean      mkc, ok;
GLint          attribWindow[]	= {AGL_RGBA, AGL_DOUBLEBUFFER, AGL_DEPTH_SIZE, 32, AGL_ALL_RENDERERS, AGL_ACCELERATED, AGL_NO_RECOVERY, AGL_NONE};
GLint          attrib32bit[] 	= {AGL_RGBA, AGL_FULLSCREEN, AGL_DOUBLEBUFFER, AGL_DEPTH_SIZE, 32, AGL_ALL_RENDERERS, AGL_ACCELERATED, AGL_NO_RECOVERY, AGL_NONE};
GLint          attrib16bit[] 	= {AGL_RGBA, AGL_FULLSCREEN, AGL_DOUBLEBUFFER, AGL_DEPTH_SIZE, 32, AGL_ALL_RENDERERS, AGL_ACCELERATED, AGL_NO_RECOVERY, AGL_NONE};
GLint          attrib2[] 		= {AGL_RGBA, AGL_FULLSCREEN, AGL_DOUBLEBUFFER, AGL_DEPTH_SIZE, 16, AGL_ALL_RENDERERS, AGL_NONE};
GLint          attrib32bitStereo[] 	= {AGL_RGBA, AGL_FULLSCREEN, AGL_STEREO, AGL_DOUBLEBUFFER, AGL_DEPTH_SIZE, 32, AGL_ALL_RENDERERS, AGL_ACCELERATED, AGL_NO_RECOVERY, AGL_NONE};
GLint          attrib16bitStereo[] 	= {AGL_RGBA, AGL_FULLSCREEN, AGL_STEREO, AGL_DOUBLEBUFFER, AGL_DEPTH_SIZE, 32, AGL_ALL_RENDERERS, AGL_ACCELERATED, AGL_NO_RECOVERY, AGL_NONE};
AGLContext agl_ctx;
GLint			maxTexSize;
static char			*s;

OGLViewDefType *viewDefPtr = &def->view;


			/* FIX FOG FOR FOR B&W ANAGLYPH */
			//
			// The NTSC luminance standard where grayscale = .299r + .587g + .114b
			//

	if (gGamePrefs.stereoGlassesMode == STEREO_GLASSES_MODE_ANAGLYPH)
	{
		if (gGamePrefs.anaglyphColor)
		{
			uint32_t	r,g,b;

			r = viewDefPtr->clearColor.r * 255.0f;
			g = viewDefPtr->clearColor.g * 255.0f;
			b = viewDefPtr->clearColor.b * 255.0f;

			ColorBalanceRGBForAnaglyph(&r, &g, &b, true);

			viewDefPtr->clearColor.r = (float)r / 255.0f;
			viewDefPtr->clearColor.g = (float)g / 255.0f;
			viewDefPtr->clearColor.b = (float)b / 255.0f;

		}
		else
		{
			float	f;

			f = viewDefPtr->clearColor.r * .299;
			f += viewDefPtr->clearColor.g * .587;
			f += viewDefPtr->clearColor.b * .114;

			viewDefPtr->clearColor.r =
			viewDefPtr->clearColor.g =
			viewDefPtr->clearColor.b = f;
		}
	}

			/***********************/
			/* CHOOSE PIXEL FORMAT */
			/***********************/

			/* PLAY IN WINDOW */

	if (!gPlayFullScreen)
	{
		if (gGamePrefs.stereoGlassesMode == STEREO_GLASSES_MODE_SHUTTER)
			DoFatalAlert("Cannot play stero mode in a window!");

		fmt = aglChoosePixelFormat(&gGDevice, 1, attribWindow);
	}

			/* FULL-SCREEN */
	else
	{
				/* STEREO FOR SHUTTER GLASSES */

		if (gGamePrefs.stereoGlassesMode == STEREO_GLASSES_MODE_SHUTTER)
		{
			if (gGamePrefs.depth == 32)
				fmt = aglChoosePixelFormat(&gGDevice, 1, attrib32bitStereo);
			else
				fmt = aglChoosePixelFormat(&gGDevice, 1, attrib16bitStereo);
		}
				/* NORMAL FULL-SCREEN DISPLAY */
		else
		{
			if (gGamePrefs.depth == 32)
				fmt = aglChoosePixelFormat(&gGDevice, 1, attrib32bit);						// 32-bit display
			else
				fmt = aglChoosePixelFormat(&gGDevice, 1, attrib16bit);						// 16-bit display
		}
	}

			/* BACKUP PLAN IF ERROR */

	if ((fmt == NULL) || (aglGetError() != AGL_NO_ERROR))
	{
		fmt = aglChoosePixelFormat(&gGDevice, 1, attrib2);							// try being less stringent
		if ((fmt == NULL) || (aglGetError() != AGL_NO_ERROR))
		{
			DoFatalAlert("aglChoosePixelFormat failed!  OpenGL could not initialize your video card for 3D.  Check that your video card meets the game's minimum system requirements.");
		}
	}


			/* CREATE AGL CONTEXT & ATTACH TO WINDOW */

	gAGLContext = aglCreateContext(fmt, nil);
	if ((gAGLContext == nil) || (aglGetError() != AGL_NO_ERROR))
		DoFatalAlert("OGL_CreateDrawContext: aglCreateContext failed!");

	agl_ctx = gAGLContext;

	if (gPlayFullScreen)
	{
		gAGLWin = nil;
		aglEnable (gAGLContext, AGL_FS_CAPTURE_SINGLE);
		aglSetFullScreen(gAGLContext, 0, 0, 0, 0);
	}
	else
	{
		gAGLWin = (AGLDrawable)gGameWindowGrafPtr;
		ok = aglSetDrawable(gAGLContext, gAGLWin);
		if ((!ok) || (aglGetError() != AGL_NO_ERROR))
		{
			if (aglGetError() == AGL_BAD_ALLOC)
			{
				gGamePrefs.showScreenModeDialog	= true;
				SavePrefs();
				DoFatalAlert("Not enough VRAM for the selected video mode.  Please try again and select a different mode.");
			}
			else
				DoFatalAlert("OGL_CreateDrawContext: aglSetDrawable failed!");
		}
	}


			/* ACTIVATE CONTEXT */

	mkc = aglSetCurrentContext(gAGLContext);
	if ((mkc == nil) || (aglGetError() != AGL_NO_ERROR))
		return;


			/* NO LONGER NEED PIXEL FORMAT */

	aglDestroyPixelFormat(fmt);
#endif


			/* CLEAR ALL BUFFERS TO BLACK */

	ClearAllBuffersToBlack();


				/* SET VARIOUS STATE INFO */


	glClearColor(viewDefPtr->clearColor.r, viewDefPtr->clearColor.g, viewDefPtr->clearColor.b, 1.0);
	glEnable(GL_DEPTH_TEST);								// use z-buffer

	{
		GLfloat	color[] = {1,1,1,1};									// set global material color to white
		glMaterialfv(GL_FRONT_AND_BACK, GL_AMBIENT_AND_DIFFUSE, color);
	}

	glColorMaterial(GL_FRONT_AND_BACK, GL_AMBIENT_AND_DIFFUSE);
	glEnable(GL_COLOR_MATERIAL);

  	glEnable(GL_NORMALIZE);


#if VERTEXARRAYRANGES
 		/***************************/
		/* GET OPENGL CAPABILITIES */
 		/***************************/

	char* s = (char *)glGetString(GL_EXTENSIONS);					// get extensions list

		/* SEE IF HAVE VERTEX ARRAY RANGE CAPABILITIES */

	if (strstr(s, "GL_APPLE_vertex_array_range"))
		gHardwareSupportsVertexArrayRange = true;
	else
		gHardwareSupportsVertexArrayRange = false;
#endif




			/* INIT DEBUG FONT */

	OGL_InitFont();


			/* SEE IF SUPPORT 1024x1024 TEXTURES */

	glGetIntegerv(GL_MAX_TEXTURE_SIZE, &maxTexSize);
	if (maxTexSize < 1024)
		DoFatalAlert("Your video card cannot do 1024x1024 textures, so it is below the game's minimum system requirements.");
}



/**************** OGL: SET STYLES ****************/

static void OGL_SetStyles(OGLSetupInputType *setupDefPtr)
{
OGLStyleDefType *styleDefPtr = &setupDefPtr->styles;
AGLContext agl_ctx = gAGLContext;


	gMyState_CullFace = false;
	OGL_EnableCullFace();
	glCullFace(GL_BACK);
	glFrontFace(GL_CCW);									// CCW is front face
	OGL_CheckError();

	if (gGamePrefs.depth == 16)
		glEnable(GL_DITHER);
	else
		glDisable(GL_DITHER);
	OGL_CheckError();

			/* SET BLENDING DEFAULTS */

	gMyState_BlendFuncS = gMyState_BlendFuncD = 0;
    OGL_BlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);		// set default blend func

	gMyState_Blend = true;
	OGL_DisableBlend();
	OGL_CheckError();

#if 0
	glHint(GL_TRANSFORM_HINT_APPLE, GL_FASTEST);
	OGL_CheckError();
#endif
	glDisable(GL_RESCALE_NORMAL);
	OGL_CheckError();

	gMyState_TextureUnit = GL_TEXTURE0_ARB;
	OGL_ActiveTextureUnit(GL_TEXTURE0_ARB);
	gMyState_Texture2D = true;
	OGL_DisableTexture2D();
	OGL_CheckError();


	gMyState_Color.r =
	gMyState_Color.g =
	gMyState_Color.b =
	gMyState_Color.a = .1;
	OGL_SetColor4f(1,1,1,1);

			/* ENABLE ALPHA CHANNELS */

	glEnable(GL_ALPHA_TEST);
	glAlphaFunc(GL_NOTEQUAL, 0);	// draw any pixel who's Alpha != 0
	OGL_CheckError();


		/* SET FOG */

	glHint(GL_FOG_HINT, GL_FASTEST);

	if (styleDefPtr->useFog)
	{
		glFogi(GL_FOG_MODE, styleDefPtr->fogMode);
		glFogf(GL_FOG_DENSITY, styleDefPtr->fogDensity);
		glFogf(GL_FOG_START, styleDefPtr->fogStart);
		glFogf(GL_FOG_END, styleDefPtr->fogEnd);
		glFogfv(GL_FOG_COLOR, (float *)&setupDefPtr->view.clearColor);
		gMyState_Fog = false;
		OGL_EnableFog();
	}
	else
	{
		gMyState_Fog = true;
		OGL_DisableFog();
	}
	OGL_CheckError();

		/* ANISOTRIPIC FILTERING */

	if (gDoAnisotropy)
		glGetFloatv(GL_MAX_TEXTURE_MAX_ANISOTROPY_EXT, &gMaxAnisotropy);
	OGL_CheckError();
}

/**************** CLEAR ALL BUFFERS TO BLACK *********************/

static void ClearAllBuffersToBlack(void)
{
	AGLContext agl_ctx = gAGLContext;

	glClearColor(0,0,0,1);
	if (gGamePrefs.stereoGlassesMode == STEREO_GLASSES_MODE_SHUTTER)
	{

		glDrawBuffer(GL_BACK_LEFT);
		glClear(GL_COLOR_BUFFER_BIT|GL_DEPTH_BUFFER_BIT);
		glDrawBuffer(GL_BACK_RIGHT);
		glClear(GL_COLOR_BUFFER_BIT|GL_DEPTH_BUFFER_BIT);
		aglSwapBuffers(agl_ctx);
		glDrawBuffer(GL_BACK_LEFT);
		glClear(GL_COLOR_BUFFER_BIT|GL_DEPTH_BUFFER_BIT);
		glDrawBuffer(GL_BACK_RIGHT);
		glClear(GL_COLOR_BUFFER_BIT|GL_DEPTH_BUFFER_BIT);
		aglSwapBuffers(agl_ctx);

		if (OGL_CheckError())
			DoFatalAlert("ClearAllBuffersToBlack: a GL call has failed here.");

		if (aglGetError() != AGL_NO_ERROR)
			DoFatalAlert("ClearAllBuffersToBlack: an AGL call has failed here.");


	}
	else
	{
		glClear(GL_COLOR_BUFFER_BIT|GL_DEPTH_BUFFER_BIT);		// clear buffer
		aglSwapBuffers(agl_ctx);
		glClear(GL_COLOR_BUFFER_BIT|GL_DEPTH_BUFFER_BIT);		// clear buffer
		aglSwapBuffers(agl_ctx);
	}
}


/********************* OGL: CREATE LIGHTS ************************/
//
// NOTE:  The Projection matrix must be the identity or lights will be transformed.
//

static void OGL_CreateLights(OGLLightDefType *lightDefPtr)
{
int		i;
GLfloat	ambient[4];
AGLContext agl_ctx = gAGLContext;

	gMyState_Lighting = false;
	OGL_EnableLighting();


			/************************/
			/* CREATE AMBIENT LIGHT */
			/************************/

	ambient[0] = lightDefPtr->ambientColor.r;
	ambient[1] = lightDefPtr->ambientColor.g;
	ambient[2] = lightDefPtr->ambientColor.b;
	ambient[3] = 1;
	glLightModelfv(GL_LIGHT_MODEL_AMBIENT, ambient);			// set scene ambient light


			/**********************/
			/* CREATE FILL LIGHTS */
			/**********************/

	for (i=0; i < lightDefPtr->numFillLights; i++)
	{
		static GLfloat lightamb[4] = { 0.0, 0.0, 0.0, 1.0 };
		GLfloat lightVec[4];
		GLfloat	diffuse[4];

					/* SET FILL DIRECTION */

		OGLVector3D_Normalize(&lightDefPtr->fillDirection[i], &lightDefPtr->fillDirection[i]);
		lightVec[0] = -lightDefPtr->fillDirection[i].x;		// negate vector because OGL is stupid
		lightVec[1] = -lightDefPtr->fillDirection[i].y;
		lightVec[2] = -lightDefPtr->fillDirection[i].z;
		lightVec[3] = 0;									// when w==0, this is a directional light, if 1 then point light
		glLightfv(GL_LIGHT0+i, GL_POSITION, lightVec);


					/* SET COLOR */

		glLightfv(GL_LIGHT0+i, GL_AMBIENT, lightamb);

		diffuse[0] = lightDefPtr->fillColor[i].r;
		diffuse[1] = lightDefPtr->fillColor[i].g;
		diffuse[2] = lightDefPtr->fillColor[i].b;
		diffuse[3] = 1;

		glLightfv(GL_LIGHT0+i, GL_DIFFUSE, diffuse);


		glEnable(GL_LIGHT0+i);								// enable the light
	}

}

#pragma mark -

/******************* OGL DRAW SCENE *********************/

void OGL_DrawScene(OGLSetupOutputType *setupInfo, void (*drawRoutine)(OGLSetupOutputType *))
{
AGLContext agl_ctx = setupInfo->drawContext;


			/* POLL EVENT QUEUE ONCE PER FRAME TO KEEP SYSTEM HAPPY */

//    EventRef        theEvent;
//	ReceiveNextEvent(0, NULL, kEventDurationNoWait, false, &theEvent);



	SDL_GL_GetDrawableSize(gSDLWindow, &gGameWindowWidth, &gGameWindowHeight);


#if 0
			/* WHILE WE'RE HERE MAKE SURE OS X DOESNT GO TO SLEEP */

	{
		static float	timer = 0;

		timer -= gFramesPerSecondFrac;
		if (timer < 0.0f)
		{
			timer = 100.0f;
			UpdateSystemActivity(UsrActivity);
		}
	}
#endif

	if (!setupInfo->isActive)
		DoFatalAlert("OGL_DrawScene isActive == false");

  	aglSetCurrentContext(setupInfo->drawContext);			// make context active


			/* INIT SOME STUFF */

	if (gGamePrefs.stereoGlassesMode != STEREO_GLASSES_MODE_OFF)
	{
		gAnaglyphPass = 0;
		PrepAnaglyphCameras();
	}

	gPolysThisFrame 	= 0;										// init poly counter
	gMostRecentMaterial = nil;
	gGlobalMaterialFlags = 0;
	gGlobalTransparency = 1.0f;
	OGL_SetColor4f(1,1,1,1);

#if VERTEXARRAYRANGES
				/* MAKE SURE VERTEX ARRAY RANGE INFO IS UP-TO-DATE */

	OGL_UpdateVertexArrayRange();
#endif


do_shutter:

			/* SET BUFFER FOR SHUTTER GLASSES */

	if (gGamePrefs.stereoGlassesMode == STEREO_GLASSES_MODE_SHUTTER)
	{
		if (gAnaglyphPass == 0)
			glDrawBuffer(GL_BACK_LEFT);
		else
			glDrawBuffer(GL_BACK_RIGHT);

		if (OGL_CheckError())
			DoFatalAlert("OGL_DrawScene: glDrawBuffer()");
	}

				/*****************/
				/* CLEAR BUFFERS */
				/*****************/

	if (setupInfo->clearBackBuffer || (gDebugMode == 3) || (gGamePrefs.stereoGlassesMode == STEREO_GLASSES_MODE_ANAGLYPH))
	{
		if (gGamePrefs.stereoGlassesMode == STEREO_GLASSES_MODE_ANAGLYPH)
		{
				/* MAKE SURE GREEN CHANNEL IS CLEAR */
				//
				// Bringing up dialogs can write into green channel, so always be sure it's clear
				//

			if (gGamePrefs.anaglyphColor)
				glColorMask(GL_TRUE, GL_TRUE, GL_TRUE, GL_TRUE);		// make sure clearing Red/Green/Blue channels
			else
				glColorMask(GL_TRUE, GL_FALSE, GL_TRUE, GL_TRUE);		// make sure clearing Red/Blue channels
		}
		glClear(GL_COLOR_BUFFER_BIT|GL_DEPTH_BUFFER_BIT);
	}
	else
		glClear(GL_DEPTH_BUFFER_BIT);


			/*************************/
			/* SEE IF DOING ANAGLYPH */
			/*************************/

do_anaglyph:

	if (gGamePrefs.stereoGlassesMode == STEREO_GLASSES_MODE_ANAGLYPH)
	{
				/* SET COLOR MASK */

		if (gAnaglyphPass == 0)
		{
			glColorMask(GL_TRUE, GL_FALSE, GL_FALSE, GL_TRUE);
		}
		else
		{
			if (gGamePrefs.anaglyphColor)
				glColorMask(GL_FALSE, GL_TRUE, GL_TRUE, GL_TRUE);
			else
				glColorMask(GL_FALSE, GL_FALSE, GL_TRUE, GL_TRUE);
			glClear(GL_DEPTH_BUFFER_BIT);
		}

	}

				/**************************************/
				/* DRAW EACH SPLIT-SCREEN PANE IF ANY */
				/**************************************/

	for (gCurrentSplitScreenPane = 0; gCurrentSplitScreenPane < gNumPlayers; gCurrentSplitScreenPane++)
	{
				/* OFFSET ANAGLYPH CAMERAS */

		if (gGamePrefs.stereoGlassesMode != STEREO_GLASSES_MODE_OFF)
			CalcAnaglyphCameraOffset(gCurrentSplitScreenPane, gAnaglyphPass);


						/* SET SPLIT-SCREEN VIEWPORT */

		int	x,y,w,h;
		OGL_GetCurrentViewport(setupInfo, &x, &y, &w, &h, gCurrentSplitScreenPane);
		glViewport(x,y, w, h);
		gCurrentPaneAspectRatio = (float)h/(float)w;


				/* GET UPDATED GLOBAL COPIES OF THE VARIOUS MATRICES */

		OGL_Camera_SetPlacementAndUpdateMatrices(setupInfo, gCurrentSplitScreenPane);


				/* CALL INPUT DRAW FUNCTION */

		if (drawRoutine != nil)
			drawRoutine(setupInfo);
	}


			/***********************************/
			/* SEE IF DO ANOTHER ANAGLYPH PASS */
			/***********************************/

	if (gGamePrefs.stereoGlassesMode != STEREO_GLASSES_MODE_OFF)
	{
		gAnaglyphPass++;
		if (gAnaglyphPass == 1)
		{
			if (gGamePrefs.stereoGlassesMode == STEREO_GLASSES_MODE_ANAGLYPH)		// anaglyph doesn't need to clear the backbuffer on the 2nd pass
				goto do_anaglyph;
			else																	// but shutters have separate buffers so they do need to clear the buffers
				goto do_shutter;
		}
	}




		/**************************/
		/* SEE IF SHOW DEBUG INFO */
		/**************************/

	if (GetNewKeyState(KEY_F8))
	{
		if (++gDebugMode > 3)
			gDebugMode = 0;

		if (gDebugMode == 3)								// see if show wireframe
			glPolygonMode(GL_FRONT_AND_BACK ,GL_LINE);
		else
			glPolygonMode(GL_FRONT_AND_BACK ,GL_FILL);
	}


	if (gTimeDemo)
	{
		OGL_DrawInt(gGameFrameNum, 20,20);
	}

				/* SHOW BASIC DEBUG INFO */

	if (gDebugMode > 0)
	{
		int		y = 100;

		OGL_DrawString("fps:", 20,y);
		OGL_DrawInt(gFramesPerSecond+.5f, 50,y);
		y += 15;

		OGL_DrawString("#tri:", 20,y);
		OGL_DrawInt(gPolysThisFrame, 50,y);
		y += 15;

		OGL_DrawString("#RAM:", 20,y);
		OGL_DrawInt(gRAMAlloced, 50,y);
		y += 15;



#if 0

		OGL_DrawString("#scratchF:", 20,y);
		OGL_DrawFloat(gScratchF, 100,y);
		y += 15;

		{
		int		i;
		for (i = 0; i < NUM_VERTEX_ARRAY_RANGES; i++)
		{
			int max = OGL_MaxMemForVARType(i);
			OGL_DrawString("VAR max=", 20,y);
			OGL_DrawInt(max, 100,y);
			y += 9;
			OGL_DrawString("cur=", 20,y);
			OGL_DrawInt(gVertexArrayRangeSize[i], 100,y);
			y += 9;
		}
		}


		OGL_DrawString("#scratchF:", 20,y);
		OGL_DrawFloat(gScratchF, 100,y);
		y += 15;

		OGL_DrawString("player Y:", 20,y);
		OGL_DrawInt(gPlayerInfo[0].coord.y, 100,y);
		y += 15;


		OGL_DrawString("input x:", 20,y);
		OGL_DrawFloat(gPlayerInfo[0].analogControlX, 100,y);
		y += 15;
		OGL_DrawString("input y:", 20,y);
		OGL_DrawFloat(gPlayerInfo[0].analogControlZ, 100,y);
		y += 15;


		OGL_DrawString("#scratch:", 20,y);
		OGL_DrawInt(gScratch, 100,y);
		y += 15;

		OGL_DrawString("OGL Mem:", 20,y);
		OGL_DrawInt(glmGetInteger(GLM_CURRENT_MEMORY), 100,y);
		y += 15;


		OGL_DrawString("#H2O:", 20,y);
		OGL_DrawInt(gNumWaterDrawn, 100,y);
		y += 15;

#endif

	}



            /**************/
			/* END RENDER */
			/**************/

	if (gGamePrefs.stereoGlassesMode == STEREO_GLASSES_MODE_SHUTTER)
		DrawBlueLine (gGamePrefs.screenWidth, gGamePrefs.screenHeight);



           /* SWAP THE BUFFS */

	aglSwapBuffers(setupInfo->drawContext);					// end render loop

	setupInfo->frameCount++;								// inc frame count AFTER drawing (so that the previous Move calls were in sync with this draw frame count)


	if (gGamePrefs.stereoGlassesMode != STEREO_GLASSES_MODE_OFF)
		RestoreCamerasFromAnaglyph();

}

/***************** DRAW BLUE LINE ************************/
//
// for stereo blue-line stuff
//

static void DrawBlueLine(GLint window_width, GLint window_height)
{
AGLContext agl_ctx = gAGLContext;
unsigned long buffer;

	glPushAttrib(GL_ALL_ATTRIB_BITS);

	glDisable(GL_ALPHA_TEST);
	glDisable(GL_BLEND);
	glDisable(GL_COLOR_LOGIC_OP);
	glDisable(GL_COLOR_MATERIAL);
	glDisable(GL_DEPTH_TEST);
	glDisable(GL_DITHER);
	glDisable(GL_FOG);
	glDisable(GL_LIGHTING);
	glDisable(GL_LINE_SMOOTH);
	glDisable(GL_LINE_STIPPLE);
	glDisable(GL_SCISSOR_TEST);
	glDisable(GL_TEXTURE_1D);
	glDisable(GL_TEXTURE_2D);
	glDisable(GL_TEXTURE_3D);

	for(buffer = GL_BACK_LEFT; buffer <= GL_BACK_RIGHT; buffer++)
	{
		GLint matrixMode;
		GLint vp[4];

		glDrawBuffer(buffer);

		glGetIntegerv(GL_VIEWPORT, vp);
		glViewport(0, 0, window_width, window_height);

		glGetIntegerv(GL_MATRIX_MODE, &matrixMode);
		glMatrixMode(GL_PROJECTION);
		glPushMatrix();
		glLoadIdentity();

		glMatrixMode(GL_MODELVIEW);
		glPushMatrix();
		glLoadIdentity();
		glScalef(2.0f / window_width, -2.0f / window_height, 1.0f);
		glTranslatef(-window_width / 2.0f, -window_height / 2.0f, 0.0f);

		// draw sync lines
		OGL_SetColor4f(0.0f, 0.0f, 0.0f, 1);
		glBegin(GL_LINES); // Draw a background line
			glVertex3f(0.0f, window_height - 0.5f, 0.0f);
			glVertex3f(window_width, window_height - 0.5f, 0.0f);
		glEnd();
		OGL_SetColor4f(0.0f, 0.0f, 1.0f, 1);
		glBegin(GL_LINES); // Draw a line of the correct length (the cross over is about 40% across the screen from the left
			glVertex3f(0.0f, window_height - 0.5f, 0.0f);
			if(buffer == GL_BACK_LEFT)
				glVertex3f(window_width * 0.30f, window_height - 0.5f, 0.0f);
			else
				glVertex3f(window_width * 0.80f, window_height - 0.5f, 0.0f);
		glEnd();

		glPopMatrix();
		glMatrixMode(GL_PROJECTION);
		glPopMatrix();
		glMatrixMode(matrixMode);

		glViewport(vp[0], vp[1], vp[2], vp[3]);
	}
	glPopAttrib();

	if (OGL_CheckError())
		DoFatalAlert("DrawBlueLine failed");

}



/********************** OGL: GET CURRENT VIEWPORT ********************/
//
// Remember that with OpenGL, the bottom of the screen is y==0, so some of this code
// may look upside down.
//

void OGL_GetCurrentViewport(const OGLSetupOutputType *setupInfo, int *x, int *y, int *w, int *h, Byte whichPane)
{
int	t,b,l,r;

	t = setupInfo->clip.top;
	b = setupInfo->clip.bottom;
	l = setupInfo->clip.left;
	r = setupInfo->clip.right;

	switch(gActiveSplitScreenMode)
	{
		case	SPLITSCREEN_MODE_NONE:
				*x = l;
				*y = t;
				*w = gGameWindowWidth-l-r;
				*h = gGameWindowHeight-t-b;
				break;

		case	SPLITSCREEN_MODE_HORIZ:
				*x = l;
				*w = gGameWindowWidth-l-r;
				*h = (gGameWindowHeight-l-r)/2;
				switch(whichPane)
				{
					case	0:
							*y = t + (gGameWindowHeight-l-r)/2;
							break;

					case	1:
							*y = t;
							break;
				}
				break;

		case	SPLITSCREEN_MODE_VERT:
				*w = (gGameWindowWidth-l-r)/2;
				*h = gGameWindowHeight-t-b;
				*y = t;
				switch(whichPane)
				{
					case	0:
							*x = l;
							break;

					case	1:
							*x = l + (gGameWindowWidth-l-r)/2;
							break;
				}
				break;
	}
}


#pragma mark -


/***************** OGL TEXTUREMAP LOAD **************************/
//
// INPUT:
//			textureInRAM = true if OpenGL is to use the texture directly from imageMemory.
//							In this case we are in control of the texture, and must remember to delete it later
//

GLuint OGL_TextureMap_Load(void *imageMemory, int width, int height, GLint destFormat,
							GLint srcFormat, GLint dataType, Boolean textureInRAM)
{
GLuint	textureName;
AGLContext agl_ctx = gAGLContext;



				/* KEEP ANY SONG GOING SMOOTHLY */

//	if (gSongMovie)
//		MoviesTask(gSongMovie, 0);


	if (gGamePrefs.stereoGlassesMode == STEREO_GLASSES_MODE_ANAGLYPH)
	{
		if (gGamePrefs.anaglyphColor)
			ConvertTextureToColorAnaglyph(imageMemory, width, height, srcFormat, dataType);
		else
			ConvertTextureToGrey(imageMemory, width, height, srcFormat, dataType);
	}

			/* GET A UNIQUE TEXTURE NAME & INITIALIZE IT */

	glGenTextures(1, &textureName);
	if (OGL_CheckError())
		DoFatalAlert("OGL_TextureMap_Load: glGenTextures failed!");

	glBindTexture(GL_TEXTURE_2D, textureName);				// this is now the currently active texture
	if (OGL_CheckError())
		DoFatalAlert("OGL_TextureMap_Load: glBindTexture failed!");


				/* LOAD TEXTURE AND/OR MIPMAPS */

#if 0
	if (0)
	{
		GLint	error;

	    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR);
    	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);

		error = gluBuild2DMipmaps(GL_TEXTURE_2D,
							destFormat,								// format in OpenGL
							width,									// width in pixels
							height,									// height in pixels
							srcFormat,								// what my format is
							dataType,								// size of each r,g,b
							imageMemory);							// pointer to the actual texture pixels

		if (error)
		{
			DoFatalAlert("OGL_TextureMap_Load: gluBuild2DMipmaps failed! %d", error);
		}
	}
	else
#endif

	{
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
 		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);

#if 1
		GAME_ASSERT_MESSAGE(!textureInRAM, "GL_UNPACK_CLIENT_STORAGE_APPLE is unsupported");
#else
		if (textureInRAM)
			glPixelStorei(GL_UNPACK_CLIENT_STORAGE_APPLE, 1);
#endif

		glTexImage2D(GL_TEXTURE_2D,
					0,										// mipmap level
					destFormat,								// format in OpenGL
					width,									// width in pixels
					height,									// height in pixels
					0,										// border
					srcFormat,								// what my format is
					dataType,								// size of each r,g,b
					imageMemory);							// pointer to the actual texture pixels
	}

			/* SEE IF RAN OUT OF MEMORY WHILE COPYING TO OPENGL */

	if (OGL_CheckError())
		DoFatalAlert("OGL_TextureMap_Load: glTexImage2D failed!");


				/* SET THIS TEXTURE AS CURRENTLY ACTIVE FOR DRAWING */

	OGL_Texture_SetOpenGLTexture(textureName);

	return(textureName);
}


/***************** OGL TEXTUREMAP LOAD FROM PNG/JPG **********************/

GLuint OGL_TextureMap_LoadImageFile(const char* path, int* outWidth, int* outHeight)
{
uint8_t*				pixelData = nil;
int						width;
int						height;
long					imageFileLength = 0;
Ptr						imageFileData = nil;

				/* LOAD PICTURE FILE */

	imageFileData = LoadDataFile(path, &imageFileLength);
	GAME_ASSERT(imageFileData);

	pixelData = (uint8_t*) stbi_load_from_memory((const stbi_uc*) imageFileData, imageFileLength, &width, &height, NULL, 4);
	GAME_ASSERT(pixelData);

	SafeDisposePtr(imageFileData);
	imageFileData = NULL;

			/* PRE-PROCESS IMAGE */

	int internalFormat = GL_RGBA;

#if 0
	if (flags & kLoadTextureFlags_KeepOriginalAlpha)
	{
		internalFormat = GL_RGBA;
	}
	else
	{
		internalFormat = GL_RGB;
	}
#endif

			/* LOAD TEXTURE */

	GLuint glTextureName = OGL_TextureMap_Load(
			pixelData,
			width,
			height,
			GL_RGBA,
			internalFormat,
			GL_UNSIGNED_BYTE,
			false);
	OGL_CheckError();

			/* CLEAN UP */

	//DisposePtr((Ptr) pixelData);
	free(pixelData);  // TODO: define STBI_MALLOC/STBI_REALLOC/STBI_FREE in stb_image.c?

	if (outWidth)
		*outWidth = width;
	if (outHeight)
		*outHeight = height;

	return glTextureName;
}



/******************** CONVERT TEXTURE TO GREY **********************/
//
// The NTSC luminance standard where grayscale = .299r + .587g + .114b
//

static void	ConvertTextureToGrey(void *imageMemory, short width, short height, GLint srcFormat, GLint dataType)
{
long	x,y;
float	r,g,b;
uint32_t	a,q,rq,bq;
uint32_t   redCal = gGamePrefs.anaglyphCalibrationRed;
uint32_t   blueCal =  gGamePrefs.anaglyphCalibrationBlue;


	if (dataType == GL_UNSIGNED_INT_8_8_8_8_REV)
	{
		uint32_t	*pix32 = (uint32_t *)imageMemory;
		for (y = 0; y < height; y++)
		{
			for (x = 0; x < width; x++)
			{
				uint32_t	pix = pix32[x];

				r = (float)((pix >> 16) & 0xff) / 255.0f * .299f;
				g = (float)((pix >> 8) & 0xff) / 255.0f * .586f;
				b = (float)(pix & 0xff) / 255.0f * .114f;
				a = (pix >> 24) & 0xff;


				q = (r + g + b) * 255.0f;									// pass thru the brightness curve
				if (q > 0xff)
					q = 0xff;
				q = gAnaglyphGreyTable[q];

				rq = (q * redCal) / 0xff;									// balance the red & blue
				bq = (q * blueCal) / 0xff;

				pix = (a << 24) | (rq << 16) | (q << 8) | bq;
				pix32[x] = pix;
			}
			pix32 += width;
		}
	}

	else
	if ((dataType == GL_UNSIGNED_BYTE) && (srcFormat == GL_RGBA))
	{
		uint32_t	*pix32 = (uint32_t *)imageMemory;
		for (y = 0; y < height; y++)
		{
			for (x = 0; x < width; x++)
			{
				uint32_t	pix = SwizzleULong(&pix32[x]);

				r = (float)((pix >> 24) & 0xff) / 255.0f * .299f;
				g = (float)((pix >> 16) & 0xff) / 255.0f * .586f;
				b = (float)((pix >> 8)  & 0xff) / 255.0f * .114f;
				a = pix & 0xff;

				q = (r + g + b) * 255.0f;									// pass thru the brightness curve
				if (q > 0xff)
					q = 0xff;
				q = gAnaglyphGreyTable[q];

				rq = (q * redCal) / 0xff;									// balance the red & blue
				bq = (q * blueCal) / 0xff;

				pix = (rq << 24) | (q << 16) | (bq << 8) | a;
				pix32[x] = SwizzleULong(&pix);

			}
			pix32 += width;
		}
	}
	else
	if (dataType == GL_UNSIGNED_SHORT_1_5_5_5_REV)
	{
		u_short	*pix16 = (u_short *)imageMemory;
		for (y = 0; y < height; y++)
		{
			for (x = 0; x < width; x++)
			{
				u_short	pix = pix16[x]; //SwizzleUShort(&pix16[x]);

				r = (float)((pix >> 10) & 0x1f) / 31.0f * .299f;
				g = (float)((pix >> 5) & 0x1f) / 31.0f * .586f;
				b = (float)(pix & 0x1f) / 31.0f * .114f;
				a = pix & 0x8000;

				q = (r + g + b) * 255.0f;								// pass thru the brightness curve
				if (q > 0xff)
					q = 0xff;
				q = gAnaglyphGreyTable[q];

				rq = (q * redCal) / 0xff;									// balance the red & blue
				bq = (q * blueCal) / 0xff;

				q = (float)q / 8.0f;
				if (q > 0x1f)
					q = 0x1f;

				rq = (float)rq / 8.0f;
				if (rq > 0x1f)
					rq = 0x1f;
				bq = (float)bq / 8.0f;
				if (bq > 0x1f)
					bq = 0x1f;

				pix = a | (rq << 10) | (q << 5) | bq;
				pix16[x] = pix; //SwizzleUShort(&pix);

			}
			pix16 += width;
		}
	}


}


/******************* COLOR BALANCE RGB FOR ANAGLYPH *********************/

void ColorBalanceRGBForAnaglyph(uint32_t *rr, uint32_t *gg, uint32_t *bb, Boolean allowChannelBalancing)
{
long	r,g,b;
float	d;
float   lumR, lumGB, ratio;

	r = *rr;
	g = *gg;
	b = *bb;


				/* ADJUST FOR USER CALIBRATION */

	r = r * gGamePrefs.anaglyphCalibrationRed / 255;
	b = b * gGamePrefs.anaglyphCalibrationBlue / 255;
	g = g * gGamePrefs.anaglyphCalibrationGreen / 255;


				/* DO LUMINOSITY CHANNEL BALANCING */

	if (allowChannelBalancing && gGamePrefs.doAnaglyphChannelBalancing)
	{
		float   fr, fg, fb;

		fr = r;
		fg = g;
		fb = b;

		lumR = fr * .299f;
		lumGB = fg * .587f + fb * .114f;

		lumR += 1.0f;
		lumGB += 1.0f;


			/* BALANCE BLUE */

		ratio = lumR / lumGB;
		ratio *= 1.5f;
		d = fb * ratio;
		if (d > fb)
		{
			b = d;
			if (b > 0xff)
				b = 0xff;
		}

			/* SMALL BALANCE ON GREEN */

		ratio *= .8f;
		d = fg * ratio;
		if (d > fg)
		{
			g = d;
			if (g > 0xff)
				g = 0xff;
		}

			/* BALANCE RED */

		ratio = lumGB / lumR;
		ratio *= .4f;
		d = fr * ratio;
		if (d > fr)
		{
			r = d;
			if (r > 0xff)
				r = 0xff;
		}

	}



	*rr = r;
	*gg = g;
	*bb = b;
}



/******************** CONVERT TEXTURE TO COLOR ANAGLYPH **********************/


static void	ConvertTextureToColorAnaglyph(void *imageMemory, short width, short height, GLint srcFormat, GLint dataType)
{
long	x,y;
uint32_t	r,g,b;
uint32_t	a;

	if (dataType == GL_UNSIGNED_INT_8_8_8_8_REV)
	{
		uint32_t	*pix32 = (uint32_t *)imageMemory;
		for (y = 0; y < height; y++)
		{
			for (x = 0; x < width; x++)
			{
				uint32_t	pix = pix32[x]; //SwizzleULong(&pix32[x]);

				a = ((pix >> 24) & 0xff);
				r = ((pix >> 16) & 0xff);
				g = ((pix >> 8) & 0xff);
				b = ((pix >> 0) & 0xff);

				ColorBalanceRGBForAnaglyph(&r, &g, &b, true);

				pix = (a << 24) | (r << 16) | (g << 8) | b;
				pix32[x] = pix; //SwizzleULong(&pix);
			}
			pix32 += width;
		}
	}
	else
	if ((dataType == GL_UNSIGNED_BYTE) && (srcFormat == GL_RGBA))
	{
		uint32_t	*pix32 = (uint32_t *)imageMemory;
		for (y = 0; y < height; y++)
		{
			for (x = 0; x < width; x++)
			{
				uint32_t	pix = SwizzleULong(&pix32[x]);

				a = ((pix >> 0) & 0xff);
				r = ((pix >> 24) & 0xff);
				g = ((pix >> 16) & 0xff);
				b = ((pix >> 8) & 0xff);

				ColorBalanceRGBForAnaglyph(&r, &g, &b, true);

				pix = (r << 24) | (g << 16) | (b << 8) | a;
				pix32[x] = SwizzleULong(&pix);

			}
			pix32 += width;
		}
	}
	else
	if (dataType == GL_UNSIGNED_SHORT_1_5_5_5_REV)
	{
		u_short	*pix16 = (u_short *)imageMemory;
		for (y = 0; y < height; y++)
		{
			for (x = 0; x < width; x++)
			{
				u_short	pix = pix16[x]; //SwizzleUShort(&pix16[x]);

				r = ((pix >> 10) & 0x1f) << 3;			// load 5 bits per channel & convert to 8 bits
				g = ((pix >> 5) & 0x1f) << 3;
				b = (pix & 0x1f) << 3;
				a = pix & 0x8000;

				ColorBalanceRGBForAnaglyph(&r, &g, &b, true);

				r >>= 3;
				g >>= 3;
				b >>= 3;

				pix = a | (r << 10) | (g << 5) | b;
				pix16[x] = pix; //SwizzleUShort(&pix);

			}
			pix16 += width;
		}
	}

}


/************************ OGL:  RAM TEXTURE HAS CHANGED ***********************/

void OGL_RAMTextureHasChanged(GLuint textureName, short width, short height, uint32_t *pixels)
{
AGLContext agl_ctx = gAGLContext;

	glBindTexture(GL_TEXTURE_2D, textureName);				// this is now the currently active texture

	glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, width, height, GL_BGRA, GL_UNSIGNED_INT_8_8_8_8_REV, pixels);
}



/****************** OGL: TEXTURE SET OPENGL TEXTURE **************************/
//
// Sets the current OpenGL texture using glBindTexture et.al. so any textured triangles will use it.
//

void OGL_Texture_SetOpenGLTexture(GLuint textureName)
{
AGLContext agl_ctx = gAGLContext;

	glBindTexture(GL_TEXTURE_2D, textureName);
	if (OGL_CheckError())
		DoFatalAlert("OGL_Texture_SetOpenGLTexture: glBindTexture failed!");

	OGL_EnableTexture2D();
}



#pragma mark -

/*************** OGL_MoveCameraFromTo ***************/

void OGL_MoveCameraFromTo(OGLSetupOutputType *setupInfo, float fromDX, float fromDY, float fromDZ, float toDX, float toDY, float toDZ, int camNum)
{

			/* SET CAMERA COORDS */

	setupInfo->cameraPlacement[camNum].cameraLocation.x += fromDX;
	setupInfo->cameraPlacement[camNum].cameraLocation.y += fromDY;
	setupInfo->cameraPlacement[camNum].cameraLocation.z += fromDZ;

	setupInfo->cameraPlacement[camNum].pointOfInterest.x += toDX;
	setupInfo->cameraPlacement[camNum].pointOfInterest.y += toDY;
	setupInfo->cameraPlacement[camNum].pointOfInterest.z += toDZ;

	UpdateListenerLocation(setupInfo);
}


/*************** OGL_MoveCameraFrom ***************/

void OGL_MoveCameraFrom(OGLSetupOutputType *setupInfo, float fromDX, float fromDY, float fromDZ, Byte camNum)
{

			/* SET CAMERA COORDS */

	setupInfo->cameraPlacement[camNum].cameraLocation.x += fromDX;
	setupInfo->cameraPlacement[camNum].cameraLocation.y += fromDY;
	setupInfo->cameraPlacement[camNum].cameraLocation.z += fromDZ;

	UpdateListenerLocation(setupInfo);
}



/*************** OGL_UpdateCameraFromTo ***************/
//
// from and to are both optional as nil
//

void OGL_UpdateCameraFromTo(OGLSetupOutputType *setupInfo, OGLPoint3D *from, OGLPoint3D *to, int camNum)
{
static const OGLVector3D up = {0,1,0};

	if ((camNum < 0) || (camNum >= MAX_SPLITSCREENS))
		DoFatalAlert("OGL_UpdateCameraFromTo: illegal camNum");

	setupInfo->cameraPlacement[camNum].upVector 		= up;

	if (from)
		setupInfo->cameraPlacement[camNum].cameraLocation 	= *from;

	if (to)
		setupInfo->cameraPlacement[camNum].pointOfInterest 	= *to;

	UpdateListenerLocation(setupInfo);
}



/*************** OGL_UpdateCameraFromToUp ***************/

void OGL_UpdateCameraFromToUp(OGLSetupOutputType *setupInfo, OGLPoint3D *from, OGLPoint3D *to, const OGLVector3D *up, int camNum)
{
	if ((camNum < 0) || (camNum >= MAX_SPLITSCREENS))
		DoFatalAlert("OGL_UpdateCameraFromToUp: illegal camNum");

	setupInfo->cameraPlacement[camNum].upVector 		= *up;
	setupInfo->cameraPlacement[camNum].cameraLocation 	= *from;
	setupInfo->cameraPlacement[camNum].pointOfInterest 	= *to;

	UpdateListenerLocation(setupInfo);
}



/************** OGL: CAMERA SET PLACEMENT & UPDATE MATRICES **********************/
//
// This is called by OGL_DrawScene to initialize all of the view matrices,
// and to extract the current view matrices used for culling et.al.
//

void OGL_Camera_SetPlacementAndUpdateMatrices(OGLSetupOutputType *setupInfo, int camNum)
{
float	aspect;
OGLCameraPlacement	*placement;
int		temp, w, h, i;
OGLLightDefType	*lights;
AGLContext agl_ctx = gAGLContext;

	OGL_GetCurrentViewport(setupInfo, &temp, &temp, &w, &h, 0);
	aspect = (float)w/(float)h;

			/**************************/
			/* INIT PROJECTION MATRIX */
			/**************************/

	glMatrixMode(GL_PROJECTION);
	glLoadIdentity();

			/* SETUP FOR ANAGLYPH STEREO 3D CAMERA */

	if (gGamePrefs.stereoGlassesMode != STEREO_GLASSES_MODE_OFF)
	{
		float	left, right;
		float	halfFOV = setupInfo->fov[camNum] * .5f;
		float	near 	= setupInfo->hither;
	   	float	wd2     = near * tan(halfFOV);
		float	ndfl    = near / gAnaglyphFocallength;

		if (gAnaglyphPass == 0)
		{
			left  = - aspect * wd2 + 0.5f * gAnaglyphEyeSeparation * ndfl;
			right =   aspect * wd2 + 0.5f * gAnaglyphEyeSeparation * ndfl;
		}
		else
		{
			left  = - aspect * wd2 - 0.5f * gAnaglyphEyeSeparation * ndfl;
			right =   aspect * wd2 - 0.5f * gAnaglyphEyeSeparation * ndfl;
		}

		glFrustum(left, right, -wd2, wd2, setupInfo->hither, setupInfo->yon);
	}

			/* SETUP STANDARD PERSPECTIVE CAMERA */
	else
	{
		gluPerspective (OGLMath_RadiansToDegrees(setupInfo->fov[camNum]),	// fov
						aspect,					// aspect
						setupInfo->hither,		// hither
						setupInfo->yon);		// yon
	}

			/* INIT MODELVIEW MATRIX */

	glMatrixMode(GL_MODELVIEW);
	glLoadIdentity();
	placement = &setupInfo->cameraPlacement[camNum];
	gluLookAt(placement->cameraLocation.x, placement->cameraLocation.y, placement->cameraLocation.z,
			placement->pointOfInterest.x, placement->pointOfInterest.y, placement->pointOfInterest.z,
			placement->upVector.x, placement->upVector.y, placement->upVector.z);


		/* UPDATE LIGHT POSITIONS */

	lights =  &setupInfo->lightList;						// point to light list
	for (i=0; i < lights->numFillLights; i++)
	{
		GLfloat lightVec[4];

		lightVec[0] = -lights->fillDirection[i].x;			// negate vector because OGL is stupid
		lightVec[1] = -lights->fillDirection[i].y;
		lightVec[2] = -lights->fillDirection[i].z;
		lightVec[3] = 0;									// when w==0, this is a directional light, if 1 then point light
		glLightfv(GL_LIGHT0+i, GL_POSITION, lightVec);
	}


			/* GET VARIOUS CAMERA MATRICES */

	glGetFloatv(GL_MODELVIEW_MATRIX, (GLfloat *)&gWorldToViewMatrix);
	glGetFloatv(GL_MODELVIEW_MATRIX, (GLfloat *)&gLocalToViewMatrix);
	glGetFloatv(GL_PROJECTION_MATRIX, (GLfloat *)&gViewToFrustumMatrix);
	OGLMatrix4x4_Multiply(&gLocalToViewMatrix, &gViewToFrustumMatrix, &gLocalToFrustumMatrix);
	OGLMatrix4x4_Multiply(&gWorldToViewMatrix, &gViewToFrustumMatrix, &gWorldToFrustumMatrix);

	OGLMatrix4x4_GetFrustumToWindow(setupInfo, &gFrustumToWindowMatrix[camNum],camNum);
	OGLMatrix4x4_Multiply(&gLocalToFrustumMatrix, &gFrustumToWindowMatrix[camNum], &gWorldToWindowMatrix[camNum]);

	UpdateListenerLocation(setupInfo);
}



#pragma mark -


/**************** OGL BUFFER TO GWORLD ***********************/

GWorldPtr OGL_BufferToGWorld(Ptr buffer, int width, int height, int bytesPerPixel)
{
	IMPME;
	return NULL;
#if 0
Rect			r;
GWorldPtr		gworld;
PixMapHandle	gworldPixmap;
long			gworldRowBytes,x,y,pixmapRowbytes;
Ptr				gworldPixelPtr;
unsigned long	*pix32Src,*pix32Dest;
unsigned short	*pix16Src,*pix16Dest;
OSErr			iErr;
long			pixelSize;

			/* CREATE GWORLD TO DRAW INTO */

	switch(bytesPerPixel)
	{
		case	2:
				pixelSize = 16;
				break;

		case	4:
				pixelSize = 32;
				break;

		default:
				return(nil);
	}

	SetRect(&r,0,0,width,height);
	iErr = NewGWorld(&gworld,pixelSize, &r, nil, nil, 0);
	if (iErr)
		DoFatalAlert("OGL_BufferToGWorld: NewGWorld failed!");

	DoLockPixels(gworld);

	gworldPixmap = GetGWorldPixMap(gworld);
	LockPixels(gworldPixmap);

	gworldRowBytes = (**gworldPixmap).rowBytes & 0x3fff;					// get GWorld's rowbytes
	gworldPixelPtr = GetPixBaseAddr(gworldPixmap);							// get ptr to pixels

	pixmapRowbytes = width * bytesPerPixel;


			/* WRITE DATA INTO GWORLD */

	switch(pixelSize)
	{
		case	32:
				pix32Src = (unsigned long *)buffer;							// get 32bit pointers
				pix32Dest = (unsigned long *)gworldPixelPtr;
				for (y = 0; y <  height; y++)
				{
					for (x = 0; x < width; x++)
						pix32Dest[x] = pix32Src[x];

					pix32Dest += gworldRowBytes/4;							// next dest row
					pix32Src += pixmapRowbytes/4;
				}
				break;

		case	16:
				pix16Src = (unsigned short *)buffer;						// get 16bit pointers
				pix16Dest = (unsigned short *)gworldPixelPtr;
				for (y = 0; y <  height; y++)
				{
					for (x = 0; x < width; x++)
						pix16Dest[x] = pix16Src[x];

					pix16Dest += gworldRowBytes/2;							// next dest row
					pix16Src += pixmapRowbytes/2;
				}
				break;


		default:
				DoFatalAlert("OGL_BufferToGWorld: Only 32/16 bit textures supported right now.");

	}

	return(gworld);
#endif
}


/******************** OGL: CHECK ERROR ********************/

GLenum OGL_CheckError_Impl(const char* file, const int line)
{
	GLenum error = glGetError();
	if (error != 0)
	{
		const char* text;
		switch (error)
		{
			case	GL_INVALID_ENUM:		text = "invalid enum"; break;
			case	GL_INVALID_VALUE:		text = "invalid value"; break;
			case	GL_INVALID_OPERATION:	text = "invalid operation"; break;
			case	GL_STACK_OVERFLOW:		text = "stack overflow"; break;
			case	GL_STACK_UNDERFLOW:		text = "stack underflow"; break;
			default:
				text = "";
		}

		DoFatalAlert("OpenGL error 0x%x (%s)\nin %s:%d", error, text, file, line);
	}
	return error;
}


#pragma mark -


/********************* PUSH STATE **************************/

void OGL_PushState(void)
{
int	i;
AGLContext agl_ctx = gAGLContext;

		/* PUSH MATRIES WITH OPENGL */

	glMatrixMode(GL_MODELVIEW);
	glPushMatrix();
	glMatrixMode(GL_PROJECTION);
	glPushMatrix();

	glMatrixMode(GL_MODELVIEW);										// in my code, I keep modelview matrix as the currently active one all the time.


		/* SAVE OTHER INFO */

	i = gStateStackIndex++;											// get stack index and increment

	if (i >= STATE_STACK_SIZE)
		DoFatalAlert("OGL_PushState: stack overflow");

	gStateStack_Lighting[i] = 	gMyState_Lighting;
	gStateStack_CullFace[i] = 	gMyState_CullFace;
	gStateStack_DepthTest[i] = glIsEnabled(GL_DEPTH_TEST);
	gStateStack_Normalize[i] = glIsEnabled(GL_NORMALIZE);
	gStateStack_Texture2D[i] = gMyState_Texture2D;
	gStateStack_Fog[i] 		= glIsEnabled(GL_FOG);
	gStateStack_Blend[i] 	= gMyState_Blend;
	gStateStack_Color[i] 	= gMyState_Color;

	gStateStack_BlendSrc[i]	= gMyState_BlendFuncS;
	gStateStack_BlendDst[i]	= gMyState_BlendFuncD;

	glGetBooleanv(GL_DEPTH_WRITEMASK, &gStateStack_DepthMask[i]);
}


/********************* POP STATE **************************/

void OGL_PopState(void)
{
int		i;
AGLContext agl_ctx = gAGLContext;

		/* RETREIVE OPENGL MATRICES */

	glMatrixMode(GL_PROJECTION);
	glPopMatrix();
	glMatrixMode(GL_MODELVIEW);
	glPopMatrix();

		/* GET OTHER INFO */

	i = --gStateStackIndex;												// dec stack index

	if (i < 0)
		DoFatalAlert("OGL_PopState: stack underflow!");

	if (gStateStack_Lighting[i])
		OGL_EnableLighting();
	else
		OGL_DisableLighting();


	if (gStateStack_CullFace[i])
		OGL_EnableCullFace();
	else
		OGL_DisableCullFace();


	if (gStateStack_DepthTest[i])
		glEnable(GL_DEPTH_TEST);
	else
		glDisable(GL_DEPTH_TEST);

	if (gStateStack_Normalize[i])
		glEnable(GL_NORMALIZE);
	else
		glDisable(GL_NORMALIZE);

	if (gStateStack_Texture2D[i])
		OGL_EnableTexture2D();
	else
		OGL_DisableTexture2D();

	if (gStateStack_Blend[i])
		OGL_EnableBlend();
	else
		OGL_DisableBlend();

	if (gStateStack_Fog[i])
		OGL_EnableFog();
	else
		OGL_DisableFog();

	glDepthMask(gStateStack_DepthMask[i]);

	OGL_BlendFunc(gStateStack_BlendSrc[i], gStateStack_BlendDst[i]);
	OGL_SetColor4fv(&gStateStack_Color[i]);

}


/******************* OGL ENABLE LIGHTING ****************************/

void OGL_EnableLighting(void)
{
AGLContext agl_ctx = gAGLContext;

	if (!gMyState_Lighting)
	{
		gMyState_Lighting = true;
		glEnable(GL_LIGHTING);
	}
}


/******************* OGL DISABLE LIGHTING ****************************/

void OGL_DisableLighting(void)
{
AGLContext agl_ctx = gAGLContext;

	if (gMyState_Lighting)
	{
		gMyState_Lighting = false;
		glDisable(GL_LIGHTING);
	}
}


/********************** OGL ENABLE BLEND ********************/

void OGL_EnableBlend(void)
{
AGLContext agl_ctx = gAGLContext;

	if (!gMyState_Blend)
	{
		gMyState_Blend = true;
		glEnable(GL_BLEND);
	}
}


/******************* OGL DISABLE BLEND ****************************/

void OGL_DisableBlend(void)
{
AGLContext agl_ctx = gAGLContext;

	if (gMyState_Blend)
	{
		gMyState_Blend = false;
		glDisable(GL_BLEND);
	}
}


/********************** OGL ENABLE TEXTURE 2D ********************/

void OGL_EnableTexture2D(void)
{
AGLContext agl_ctx = gAGLContext;

		/* DO STATE CACHINE FOR UNIT 0 */

	if (gMyState_TextureUnit == GL_TEXTURE0)
	{
		if (!gMyState_Texture2D)
		{
			gMyState_Texture2D = true;
			glEnable(GL_TEXTURE_2D);
		}
	}

		/* FOR ALL OTHER TEXTURE UNITS JUST DO IT */

	else
	{
		glEnable(GL_TEXTURE_2D);
	}
}


/******************* OGL DISABLE TEXTURE 2D ****************************/

void OGL_DisableTexture2D(void)
{
AGLContext agl_ctx = gAGLContext;

		/* DO STATE CACHINE FOR UNIT 0 */

	if (gMyState_TextureUnit == GL_TEXTURE0)
	{
		if (gMyState_Texture2D)
		{
			gMyState_Texture2D = false;
			glDisable(GL_TEXTURE_2D);
		}
	}

		/* FOR ALL OTHER TEXTURE UNITS JUST DO IT */

	else
	{
		glDisable(GL_TEXTURE_2D);
	}
}


/******************** OGL:  ACTIVE TEXTURE UNIT **************************/
//
// Sets the currently active texture unit for GL_TEXTURE0...n
//

void OGL_ActiveTextureUnit(uint32_t texUnit)
{
AGLContext agl_ctx = gAGLContext;

	glActiveTexture(texUnit);
	glClientActiveTexture(texUnit);

	gMyState_TextureUnit = texUnit;
}


/********************** OGL SET COLOR 4fV ********************/

void OGL_SetColor4fv(OGLColorRGBA *color)
{
	if ((color->r != gMyState_Color.r) ||
		(color->g != gMyState_Color.g) ||
		(color->b != gMyState_Color.b) ||
		(color->a != gMyState_Color.a))
	{
		AGLContext agl_ctx = gAGLContext;

		glColor4fv((GLfloat *)color);

		gMyState_Color = *color;
	}
}


/********************** OGL SET COLOR 4f ********************/

void OGL_SetColor4f(float r, float g, float b, float a)
{

	if ((r != gMyState_Color.r) ||
		(g != gMyState_Color.g) ||
		(b != gMyState_Color.b) ||
		(a != gMyState_Color.a))
	{
		AGLContext agl_ctx = gAGLContext;

		glColor4f(r, g, b, a);

		gMyState_Color.r = r;
		gMyState_Color.g = g;
		gMyState_Color.b = b;
		gMyState_Color.a = a;
	}
}


/********************** OGL ENABLE CULL FACE ********************/

void OGL_EnableCullFace(void)
{
AGLContext agl_ctx = gAGLContext;

	if (!gMyState_CullFace)
	{
		gMyState_CullFace = true;
		glEnable(GL_CULL_FACE);
	}
}


/******************* OGL DISABLE CULL FACE ****************************/

void OGL_DisableCullFace(void)
{
AGLContext agl_ctx = gAGLContext;

	if (gMyState_CullFace)
	{
		gMyState_CullFace = false;
		glDisable(GL_CULL_FACE);
	}
}


/********************** OGL ENABLE FOG ********************/

void OGL_EnableFog(void)
{
AGLContext agl_ctx = gAGLContext;

	if (!gMyState_Fog)
	{
		gMyState_Fog = true;
		glEnable(GL_FOG);
	}
}


/******************* OGL DISABLE FOG ****************************/

void OGL_DisableFog(void)
{
AGLContext agl_ctx = gAGLContext;

	if (gMyState_Fog)
	{
		gMyState_Fog = false;
		glDisable(GL_FOG);
	}
}


/********************** OGL BLEND FUNC ********************/

void OGL_BlendFunc(GLenum sfactor, GLenum dfactor)
{
	if ((sfactor != gMyState_BlendFuncS) || (dfactor != gMyState_BlendFuncD))
	{
		AGLContext agl_ctx = gAGLContext;

		glBlendFunc(sfactor, dfactor);

		gMyState_BlendFuncS = sfactor;
		gMyState_BlendFuncD = dfactor;
	}
}




#pragma mark -

/************************** OGL_INIT FONT **************************/

static void OGL_InitFont(void)
{
AGLContext agl_ctx = gAGLContext;

	gFontList = glGenLists(256);

//    if (!aglUseFont(gAGLContext, kFontIDMonaco, bold, 9, 0, 256, gFontList))
//	{
//		DoAlert("OGL_InitFont: aglUseFont failed");
//		DoFatalAlert("OpenGL could not locate the font 'Monaco' which is one of the default MacOS system fonts.  You should reinstall OS X to get this font back since it is needed by the operating system.");
//	}
}


/******************* OGL_FREE FONT ***********************/

static void OGL_FreeFont(void)
{

AGLContext agl_ctx = gAGLContext;
	glDeleteLists(gFontList, 256);

}

/**************** OGL_DRAW STRING ********************/

void OGL_DrawString(const char* s, GLint x, GLint y)
{

AGLContext agl_ctx = gAGLContext;

	OGL_PushState();

	glMatrixMode (GL_MODELVIEW);
	glLoadIdentity();
	glMatrixMode (GL_PROJECTION);
	glLoadIdentity();
	glOrtho(0, 640, 0, 480, -10.0, 10.0);

	glDisable(GL_LIGHTING);

	OGL_DisableTexture2D();
	OGL_SetColor4f(1,1,1,1);
	glRasterPos2i(x, 480-y);

	glListBase(gFontList);
	glCallLists(s[0], GL_UNSIGNED_BYTE, &s[1]);

	OGL_PopState();

}

/**************** OGL_DRAW FLOAT ********************/

void OGL_DrawFloat(float f, GLint x, GLint y)
{
	SOFTIMPME;

#if 0
Str255	s;

	FloatToString(f,s);
	OGL_DrawString(s,x,y);
#endif
}



/**************** OGL_DRAW INT ********************/

void OGL_DrawInt(int f, GLint x, GLint y)
{

Str255	s;

	NumToString(f,s);
	OGL_DrawString(s,x,y);

}

#pragma mark -



/********************** OGL INIT VERTEX ARRAY MEMORY *********************/
//
// This game will try to put all Vertex Array data in a common block of memory so that
// we an use GL_APPLE_vertex_array_range to get massive performance boosts.
//
// So, to do this we need to allocate a large block of memory and then implement our
// own memory management within that block so that we can put as much vertex array
// data there as possible.
//
// Most if not all of this allocation is done at init time, so performance isn't crucial.
//
// Basically, this memory system is implemented as a linked list where each
// node represents a block of memory which we've allocated out of our commom block.
//
// There are two independant systems here:  one for vertex array memory which is Shared, and one for Cached.
// Shared memory is that which we can modify freely with no speed penalty by doing so.
// Cached is that which gets stored in VRAM so we don't want to modify it often.
//

static void OGL_InitVertexArrayMemory(void)
{
	if (gVARMemoryAllocated)
		DoFatalAlert("OGL_InitVertexArrayMemory: memory already allocated.");



		/* INIT THE LINKED LIST HEAD & TAIL PTRS */

	memset(gVertexArrayMemory_Head, 0, sizeof(gVertexArrayMemory_Head));
	memset(gVertexArrayMemory_Tail, 0, sizeof(gVertexArrayMemory_Tail));


		/* ALLOCATE MASTER BLOCK FOR NON-"USER" V.A.R. TYPES */

	for (int i = 0; i < VERTEX_ARRAY_RANGE_TYPE_USER1; i++)
	{
		gVertexArrayMemoryBlock[i] = AllocPtr(OGL_MaxMemForVARType(i));
	}

#if VERTEXARRAYRANGES
			/* GENERATE VERTEX ARRAY OBJECTS */

	glGenVertexArraysAPPLE(NUM_VERTEX_ARRAY_RANGES, &gVertexArrayRangeObjects[0]);

			/* INIT EACH */

	for (int i = 0; i < NUM_VERTEX_ARRAY_RANGES; i++)										// init both the "Static/Cached" memory and the "Dynamic/Shared" memory systems
	{
		gVertexArrayRangeActivated[i] 		= false;
		gVertexArrayRangeUsed[i] 			= false;
		gPreviousVertexArrayRangeSize[i]	= 0;
		gVertexArrayRangeSize[i] 			= 0;
	}

	if (gHardwareSupportsVertexArrayRange)					// only use VAR capability if hardware supports it
		gUsingVertexArrayRange = true;
	else
		gUsingVertexArrayRange = false;
#endif

		/* WE'RE DONE */

	gVARMemoryAllocated = true;
}


/******************** OGL: DISABLE VERTEX ARRAY RANGES **************************/

static void OGL_DisableVertexArrayRanges(void)
{
	if (!gVARMemoryAllocated)
		DoFatalAlert("OGL_DisableVertexArrayRanges: VAR already off.");


#if VERTEXARRAYRANGES
			/* TELL OPENGL WE ARE NOT USING VERTEX ARRAY RANGES ANYMORE */

	for (int i = 0; i < NUM_VERTEX_ARRAY_RANGES; i++)
	{
		glBindVertexArrayAPPLE(gVertexArrayRangeObjects[i]);
		glDisableClientState(GL_VERTEX_ARRAY_RANGE_APPLE);
		glVertexArrayRangeAPPLE(0, nil);

		gVertexArrayRangeActivated[i] = false;
		gVertexArrayRangeUsed[i] = false;
	}

	glDeleteVertexArraysAPPLE(NUM_VERTEX_ARRAY_RANGES, gVertexArrayRangeObjects);
#endif


				/* FREE UP THE MEMORY */
				// Only for non-"User" types. "User" types don't have allocated memory.

	for (int i = 0; i < VERTEX_ARRAY_RANGE_TYPE_USER1; i++)
	{
		if (gVertexArrayMemoryBlock[i])
		{
			SafeDisposePtr(gVertexArrayMemoryBlock[i]);
			gVertexArrayMemoryBlock[i] = nil;
		}
	}

	gVARMemoryAllocated 	= false;

#if VERTEXARRAYRANGES
	gUsingVertexArrayRange 	= false;
#endif
}


/********************* OGL ALLOC VERTEX ARRAY MEMORY *********************/
//
// Call this function to get a section of our vertex array ranged memory
//

void *OGL_AllocVertexArrayMemory(long size, Byte type)
{
VertexArrayMemoryNode	*scanNode, *newNode;
Ptr			prevEndPtr;

	if (type >= VERTEX_ARRAY_RANGE_TYPE_USER1)						// can't allocate memory for the "User" Types
		DoFatalAlert("OGL_AllocVertexArrayMemory: illegal type");

	if (!gVARMemoryAllocated)
		DoFatalAlert("OGL_AllocVertexArrayMemory: not initialized");


			/* TO BE SAFE, LETS ROUND UP THE SIZE TO THE NEAREST MULTIPLE OF 16 */

	size = (size + 15) & 0xfffffff0;


	newNode 		= AllocPtr(sizeof(VertexArrayMemoryNode));		// allocate the node (assume we'll find room for it below)
	newNode->size 	= size;											// remember how big a chunk we're allocating

	scanNode = 	gVertexArrayMemory_Head[type];						// start scanning @ front


			/**************************************/
			/* SEE IF THIS IS THE ONLY ALLOCATION */
			/**************************************/

	if (scanNode == nil)
	{
		newNode->pointer 	= gVertexArrayMemoryBlock[type];		// point to the front of the master block
		newNode->prevNode	= nil;
		newNode->nextNode 	= nil;

		gVertexArrayMemory_Head[type] = newNode;
		gVertexArrayMemory_Tail[type] = newNode;

		goto got_it;
	}


		/**********************************************/
		/* SCAN THRU NODES LOOKING FOR A SPACE TO FIT */
		/**********************************************/

	prevEndPtr = gVertexArrayMemoryBlock[type] - 1;					// pretend like a node ended before the master block
	do
	{
		ptrdiff_t freeSpace = scanNode->pointer - prevEndPtr - 1;	// how much memory is between these nodes?
		if (freeSpace >= size)										// is this big enough for us?
		{
				/* INSERT A NEW NODE BEFORE THE CURRENT ONE */

			newNode->pointer = prevEndPtr + 1;						// allocate immediately after the end of the previous node

			newNode->prevNode = scanNode->prevNode;
			newNode->nextNode = scanNode;

			scanNode->prevNode = newNode;

			if (newNode->prevNode == nil)							// is our new node the head?
				gVertexArrayMemory_Head[type] = newNode;
			else
				newNode->prevNode->nextNode = newNode;

			goto got_it;
		}

		prevEndPtr = scanNode->pointer + scanNode->size - 1;		// calc new end ptr

		scanNode = scanNode->nextNode;

	}while(scanNode != nil);


		/**********************************************************************/
		/* IT WOULDN'T FIT BEFORE ANY EXISTING NODES, SO TACK IT ONTO THE END */
		/**********************************************************************/

		/* WILL OUR NEW ALLOCATION FIT AT THE END? */

	prevEndPtr = gVertexArrayMemory_Tail[type]->pointer + gVertexArrayMemory_Tail[type]->size - 1;		// calc end of allocations

	if (((uintptr_t) prevEndPtr + size) >= ((uintptr_t) (gVertexArrayMemoryBlock[type]) + OGL_MaxMemForVARType(type)))		// would this allocation go over our master block's range?
	{
		SafeDisposePtr(newNode);

		DoFatalAlert("OGL_AllocVertexArrayMemory:  Master Block is full! Type %d", type);

		return(nil);
	}

			/* YEP IT'LL FIT */

	newNode->pointer	= prevEndPtr + 1;

	newNode->prevNode 	= gVertexArrayMemory_Tail[type];
	newNode->nextNode	= nil;

	gVertexArrayMemory_Tail[type]->nextNode = newNode;

	gVertexArrayMemory_Tail[type] = newNode;


got_it:
#if VERTEXARRAYRANGES
	gVertexArrayRangeUsed[type] = true;																					// memory has been allocated, so mark this type as used
	gVertexArrayRangeSize[type] = (uintptr_t)gVertexArrayMemory_Tail[type]->pointer + gVertexArrayMemory_Tail[type]->size - (uintptr_t)gVertexArrayMemoryBlock[type];	// calc the total size of the memory block we're using
#endif

	return(newNode->pointer);
}


/********************* OGL:  FREE VERTEX ARRAY MEMORY *************************/

void OGL_FreeVertexArrayMemory(void *pointer, Byte type)
{
VertexArrayMemoryNode	*scanNode, *prev, *next;

	if (type >= VERTEX_ARRAY_RANGE_TYPE_USER1)						// can't free memory for the "User" Types
		DoFatalAlert("OGL_FreeVertexArrayMemory: illegal type");


			/* IF NOT USING V-A-R THEN JUST DISPOSE REGULAR */

	if (!gVARMemoryAllocated)
		DoFatalAlert("OGL_FreeVertexArrayMemory: not initialized");



			/* SCAN THE LINKED LIST FOR THE MATCHING NODE */

	scanNode = 	gVertexArrayMemory_Head[type];						// start scanning @ front

	while(scanNode)
	{
		if (scanNode->pointer == pointer)						// does this node match our pointer
		{
					/* REMOVE THE NODE FROM THE LINKED LIST */

			prev = scanNode->prevNode;
			next = scanNode->nextNode;

			if (prev)											// patch the prev node
				prev->nextNode = next;
			else
				gVertexArrayMemory_Head[type] = next;

			if (next)											// patch the next node
				next->prevNode = prev;
			else
				gVertexArrayMemory_Tail[type] = prev;

			SafeDisposePtr(scanNode);							// delete the node


#if VERTEXARRAYRANGES
					/* IS IT ALL FREED UP? */

			if (gVertexArrayMemory_Head[type] == nil)
				gVertexArrayRangeUsed[type] = false;

			if (gVertexArrayMemory_Tail[type])					// calc the total size of the memory block we're using
				gVertexArrayRangeSize[type] = (uintptr_t)gVertexArrayMemory_Tail[type]->pointer + gVertexArrayMemory_Tail[type]->size - (uintptr_t)gVertexArrayMemoryBlock[type];
			else
				gVertexArrayRangeSize[type] = 0;
#endif

			return;
		}
		scanNode = scanNode->nextNode;
	}



			/* IF GETS HERE THEN NO MATCH WAS FOUND */

	DoFatalAlert("OGL_FreeVertexArrayMemory: no matching pointer found!");
}


#if VERTEXARRAYRANGES
/************************ ASSIGN VERTEX ARRAY RANGE MEMORY ************************/
//
// For directly assigning memory blocks to the USER slots.
//

void AssignVertexArrayRangeMemory(long size, void *pointer, Byte type)
{
	if (type < VERTEX_ARRAY_RANGE_TYPE_USER1)
		DoFatalAlert("AssignVertexArrayRangeMemory: type is not a USER type");

	gPreviousVertexArrayRangeSize[type] = 0;

	gVertexArrayRangeSize[type] 	= size;
	gVertexArrayMemoryBlock[type] 	= pointer;

	gVertexArrayRangeUsed[type] 	= true;
	gVertexArrayRangeActivated[type] = false;
}


/******************* RELEASE VERTEX ARRAY RANGE MEMORY ************************/

void ReleaseVertexArrayRangeMemory(Byte type)
{
	gVertexArrayRangeUsed[type] 	= false;
	gVertexArrayRangeSize[type] 	= 0;
	gVertexArrayMemoryBlock[type] 	= nil;

	gVertexArrayRangeUsed[type] 	= false;
	gVertexArrayRangeActivated[type] = false;
}
#endif


/********************* OGL:  SET VERTEX ARRAY RANGE DIRTY ***************************/
//
// Call this to force a Vertex Array range to be updated after modifying geometry

void OGL_SetVertexArrayRangeDirty(short buffer)
{
#if VERTEXARRAYRANGES
	if (buffer < 0)		// ignore -1
		return;

	GAME_ASSERT(buffer < NUM_VERTEX_ARRAY_RANGES);

	gForceVertexArrayUpdate[buffer] = true;
#endif
}

/********************* OGL:  UPDATE VERTEX ARRAY RANGE ***************************/
//
// This function is called before each render loop to see if the Vertex Array Range needs to be updated
//

static void OGL_UpdateVertexArrayRange(void)
{
#if VERTEXARRAYRANGES
AGLContext agl_ctx = gAGLContext;
long	size;
Byte	i;
Boolean	cached;

	if (!gUsingVertexArrayRange)
		return;

	for (i = 0; i < NUM_VERTEX_ARRAY_RANGES; i++)
	{
		if (!gVertexArrayRangeUsed[i])											// is this range in use?
			continue;

						/* CALC SIZE NEEDED */

		size = gVertexArrayRangeSize[i];										// how much memory are we using?
		if (size == 0)															// note:  this should never be 0 if gVertexArrayRangeUsed was true, but check anyway
			continue;


				/* SEE IF ANYTHING NEEDS UPDATING */

		if (gForceVertexArrayUpdate[i])
			goto update_it;

		if (size != gPreviousVertexArrayRangeSize[i])
			goto update_it;

		continue;


					/**************************************/
					/* UPDATE THE VERTEX ARRAY RANGE DATA */
					/**************************************/

update_it:

		glBindVertexArrayAPPLE(gVertexArrayRangeObjects[i]);


				/* IS THIS TYPE CACHED? */

		switch(i)
		{
			case	VERTEX_ARRAY_RANGE_TYPE_BG3DMODELS:
					cached = true;
					break;

//			case	VERTEX_ARRAY_RANGE_TYPE_USER_FENCES:
//			case	VERTEX_ARRAY_RANGE_TYPE_USER_FENCES2:
//					if (gAutoFadeStatusBits)						// fences can be cached as long as we're not auto-fading them
//						cached = false;
//					else
//						cached = true;
//					break;

			default:
					cached = false;
		}




				/* SEE IF THIS IS THE FIRST TIME IN */

		if (!gVertexArrayRangeActivated[i])
		{
			glVertexArrayRangeAPPLE(size, gVertexArrayMemoryBlock[i]);

			if (cached)
				glVertexArrayParameteriAPPLE(GL_VERTEX_ARRAY_STORAGE_HINT_APPLE, GL_STORAGE_CACHED_APPLE);
			else
				glVertexArrayParameteriAPPLE(GL_VERTEX_ARRAY_STORAGE_HINT_APPLE, GL_STORAGE_SHARED_APPLE);

			glFlushVertexArrayRangeAPPLE(size, gVertexArrayMemoryBlock[i]);				// this isn't documented, but you MUST call this flush to get the data uploaded to VRAM!!

			glEnableClientState(GL_VERTEX_ARRAY_RANGE_APPLE);

			gVertexArrayRangeActivated[i] = true;
		}

				/* JUST UPDATING */
				//
				// glFlushVertexArrayRangeAPPLE() should work on its own, but it doesn't on 10.2.x
				// I found that nuking the Array Range and then Resetting it is the only way to cause an update.
				//

		else
		{
			if (cached)														// cached data seems to need a complete reset
			{
				glVertexArrayRangeAPPLE(0, nil);
				glVertexArrayRangeAPPLE(size, gVertexArrayMemoryBlock[i]);
			}
			glFlushVertexArrayRangeAPPLE(size, gVertexArrayMemoryBlock[i]);	// force an update of the existing memory
		}


		gPreviousVertexArrayRangeSize[i] = size;
		gForceVertexArrayUpdate[i] = false;


		if (OGL_CheckError())
			DoFatalAlert("OGL_UpdateVertexArrayRange: error!");
	}
#endif
}



/********************* OGL:  MAX MEM FOR VAR TYPE ************************/
//
// Defines how much RAM to allocate for the Vertex Array Range buffers.
//

static long OGL_MaxMemForVARType(Byte varType)
{
	switch(varType)
	{
		case	VERTEX_ARRAY_RANGE_TYPE_PARTICLES1:
		case	VERTEX_ARRAY_RANGE_TYPE_PARTICLES2:
				return(6000000);

		case	VERTEX_ARRAY_RANGE_TYPE_BG3DMODELS:
				return(6000000);

		case	VERTEX_ARRAY_RANGE_TYPE_TERRAIN:
				return(8000000);

		case	VERTEX_ARRAY_RANGE_TYPE_ZAPS1:
		case	VERTEX_ARRAY_RANGE_TYPE_ZAPS2:
				return(300000);


		case	VERTEX_ARRAY_RANGE_TYPE_SKELETONS:
		case	VERTEX_ARRAY_RANGE_TYPE_SKELETONS2:
				return(5000000);

		default:
				return(1000000);
	}
}

