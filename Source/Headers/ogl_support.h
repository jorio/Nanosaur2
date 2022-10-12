//
// ogl_support.h
//

#pragma once

#define	MAX_SPLITSCREENS	2

#define	MAX_FILL_LIGHTS		4

enum
{
	STEREO_GLASSES_MODE_OFF = 0,
	STEREO_GLASSES_MODE_ANAGLYPH,
	STEREO_GLASSES_MODE_SHUTTER
};


		/* 4x4 MATRIX INDECIES */
enum
{
	M00	= 0,
	M10,
	M20,
	M30,
	M01,
	M11,
	M21,
	M31,
	M02,
	M12,
	M22,
	M32,
	M03,
	M13,
	M23,
	M33
};

		/* 3x3 MATRIX INDECIES */
enum
{
	N00	= 0,
	N10,
	N20,
	N01,
	N11,
	N21,
	N02,
	N12,
	N22
};

#define OGLIsZero(a) (((a) >= -EPS) && ((a) <= EPS))


		/* 3D STRUCTURES */

typedef struct
{
	float 	x,y,z,w;
}OGLPoint4D;

typedef struct
{
	GLfloat	x,y,z;
}OGLPoint3D;

typedef struct
{
	GLfloat	x,y;
}OGLPoint2D;

typedef struct
{
	GLfloat	x,y,z;
}OGLVector3D;

typedef struct
{
	GLfloat	x,y;
}OGLVector2D;

typedef struct
{
	OGLPoint3D			origin;
	OGLVector3D			direction;
	float				distance;
}OGLRay;

typedef struct
{
	OGLPoint3D	p1, p2;
}OGLLineSegment;

typedef struct
{
	GLfloat	u,v;
}OGLTextureCoord;

typedef struct
{
	GLfloat	r,g,b;
}OGLColorRGB;

typedef struct
{
	GLfloat	r,g,b,a;
}OGLColorRGBA;

typedef struct
{
	GLubyte	r,g,b,a;
}OGLColorRGBA_Byte;

typedef union
{
	GLfloat	value[16];
	#if defined(__ppc__)
	vector float v[4];
	#endif
}OGLMatrix4x4;

typedef struct
{
	GLfloat	value[9];
}OGLMatrix3x3;

typedef struct
{
	OGLVector3D 					normal;
	float 							constant;
}OGLPlaneEquation;

typedef struct
{
	OGLPoint3D			point;
	OGLTextureCoord		uv;
	OGLColorRGBA		color;
}OGLVertex;

typedef struct
{
	OGLPoint3D 			cameraLocation;				/*  Location point of the camera 	*/
	OGLPoint3D 			pointOfInterest;			/*  Point of interest 				*/
	OGLVector3D 		upVector;					/*  "up" vector 					*/
	OGLVector3D			cameraAim;					// normalized vector loc->poi
}OGLCameraPlacement;

typedef struct
{
	OGLPoint3D 			min;
	OGLPoint3D 			max;
	Boolean 			isEmpty;
}OGLBoundingBox;


typedef struct
{
	OGLPoint3D 			origin;
	float 				radius;
	Boolean 			isEmpty;
}OGLBoundingSphere;


typedef struct
{
	float	top,bottom,left,right;
}OGLRect;

//========================

typedef	struct
{
	Boolean					clearBackBuffer;
	OGLColorRGBA			clearColor;
	Rect					clip;			// left = amount to clip off left, etc.
	int						numPanes;
}OGLViewDefType;


typedef	struct
{
	Boolean			useFog;
	float			fogStart;
	float			fogEnd;
	float			fogDensity;
	short			fogMode;

}OGLStyleDefType;


typedef struct
{
	OGLPoint3D				from[MAX_SPLITSCREENS];			// 2 cameras, one for each viewport/player
	OGLPoint3D				to[MAX_SPLITSCREENS];
	OGLVector3D				up[MAX_SPLITSCREENS];
	float					hither;
	float					yon;
	float					fov;
}OGLCameraDefType;

typedef	struct
{
	OGLColorRGBA		ambientColor;
	long				numFillLights;
	OGLVector3D			fillDirection[MAX_FILL_LIGHTS];
	OGLColorRGBA		fillColor[MAX_FILL_LIGHTS];
}OGLLightDefType;


		/* OGLSetupInputType */

typedef struct
{
	OGLViewDefType		view;
	OGLStyleDefType		styles;
	OGLCameraDefType	camera;
	OGLLightDefType		lights;
	Boolean					useFog;
	Boolean					clearBackBuffer;
}OGLSetupInputType;


		/* OGLSetupOutputType */

typedef struct
{
	Boolean					isActive;
	Rect					clip;				// not pane size, but clip:  left = amount to clip off left

	OGLLightDefType			lightList;
	OGLCameraPlacement		cameraPlacement[MAX_SPLITSCREENS];	// 2 cameras, one for each viewport/player
	float					fov[MAX_SPLITSCREENS],hither,yon;
	Boolean					useFog;
	Boolean					clearBackBuffer;
	OGLColorRGBA			clearColor;

	long					frameCount;
}OGLSetupOutputType;


enum
{
	VERTEX_ARRAY_RANGE_TYPE_PARTICLES1 = 0,			// particles
	VERTEX_ARRAY_RANGE_TYPE_PARTICLES2,				// it's double-buffered
	VERTEX_ARRAY_RANGE_TYPE_TERRAIN,				// cached, but only for use by Terrain
	VERTEX_ARRAY_RANGE_TYPE_BG3DMODELS,				// all the .model files go here
	VERTEX_ARRAY_RANGE_TYPE_SKELETONS,				// all the local skeleton meshes go here
	VERTEX_ARRAY_RANGE_TYPE_SKELETONS2,				// double buffered
	VERTEX_ARRAY_RANGE_TYPE_CONTRAILS1,
	VERTEX_ARRAY_RANGE_TYPE_CONTRAILS2,
	VERTEX_ARRAY_RANGE_TYPE_ZAPS1,
	VERTEX_ARRAY_RANGE_TYPE_ZAPS2,


	VERTEX_ARRAY_RANGE_TYPE_USER1,					// memory block is defined by the caller
	VERTEX_ARRAY_RANGE_TYPE_USER_FENCES,
	VERTEX_ARRAY_RANGE_TYPE_USER_FENCES2,
	VERTEX_ARRAY_RANGE_TYPE_USER_WATER,
	VERTEX_ARRAY_RANGE_TYPE_USER_DUSTDEVIL,

	NUM_VERTEX_ARRAY_RANGES
};


		/* SPLITSCREEN */

enum
{
	SPLITSCREEN_MODE_NONE = 0,
	SPLITSCREEN_MODE_HORIZ,			// 2 horizontal panes
	SPLITSCREEN_MODE_VERT,			// 2 vertical panes

	NUM_SPLITSCREEN_MODES
};


//=====================================================================

void OGL_Boot(void);
void OGL_Shutdown(void);
void OGL_NewViewDef(OGLSetupInputType *viewDef);
void OGL_SetupGameView(OGLSetupInputType *setupDefPtr);
void OGL_DisposeGameView(void);
void OGL_DrawScene(void (*drawRoutine)(void));
void OGL_MoveCameraFromTo(float fromDX, float fromDY, float fromDZ, float toDX, float toDY, float toDZ, int camNum);
void OGL_UpdateCameraFromTo(OGLPoint3D *from, OGLPoint3D *to, int camNum);
void OGL_MoveCameraFrom(float fromDX, float fromDY, float fromDZ, Byte camNum);
void OGL_UpdateCameraFromToUp(OGLPoint3D *from, OGLPoint3D *to, const OGLVector3D *up, int camNum);
void OGL_Camera_SetPlacementAndUpdateMatrices(int camNum);
void OGL_Texture_SetOpenGLTexture(GLuint textureName);
GLuint OGL_TextureMap_Load(void *imageMemory, int width, int height, GLint destFormat, GLint srcFormat, GLint dataType);
GLuint OGL_TextureMap_LoadImageFile(const char* path, int* outWidth, int* outHeight);
void OGL_RAMTextureHasChanged(GLuint textureName, short width, short height, uint32_t *pixels);
GLenum OGL_CheckError_Impl(const char* file, int line);
#define OGL_CheckError() OGL_CheckError_Impl(__FILE__, __LINE__)
void OGL_GetCurrentViewport(int *x, int *y, int *w, int *h, Byte whichPane);

void OGL_PushState(void);
void OGL_PopState(void);

void OGL_EnableLighting(void);
void OGL_DisableLighting(void);
void OGL_EnableBlend(void);
void OGL_DisableBlend(void);
void OGL_EnableTexture2D(void);
void OGL_DisableTexture2D(void);
void OGL_ActiveTextureUnit(uint32_t texUnit);
void OGL_SetColor4fv(OGLColorRGBA *color);
void OGL_SetColor4f(float r, float g, float b, float a);
void OGL_EnableCullFace(void);
void OGL_DisableCullFace(void);
void OGL_BlendFunc(GLenum sfactor, GLenum dfactor);
void OGL_EnableFog(void);
void OGL_DisableFog(void);


void OGL_DrawString(const char* s, GLint x, GLint y);
void OGL_DrawFloat(float f, GLint x, GLint y);
void OGL_DrawInt(int f, GLint x, GLint y);

void *OGL_AllocVertexArrayMemory(long size, Byte type);
void OGL_FreeVertexArrayMemory(void *pointer, Byte type);
void OGL_SetVertexArrayRangeDirty(short buffer);
#if VERTEXARRAYRANGES
void AssignVertexArrayRangeMemory(long size, void *pointer, Byte type);
void ReleaseVertexArrayRangeMemory(Byte type);
#endif


void ColorBalanceRGBForAnaglyph(uint32_t *rr, uint32_t *gg, uint32_t *bb, Boolean doChannelBalancing);
