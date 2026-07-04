//
// ogl_support.h
//

#pragma once

#define	MAX_SPLITSCREENS	2
#define	MAX_VIEWPORTS		(MAX_SPLITSCREENS+1)

#define	MAX_FILL_LIGHTS		4

typedef enum SWIFT_ENUM_CLOSED StereoGlassesMode
{
	STEREO_GLASSES_MODE_OFF SWIFT_NAME(off) = 0,
	STEREO_GLASSES_MODE_ANAGLYPH_COLOR SWIFT_NAME(anaglyphColor),
	STEREO_GLASSES_MODE_ANAGLYPH_MONO SWIFT_NAME(anaglyphMono),
	STEREO_GLASSES_MODE_SHUTTER SWIFT_NAME(shutter)
} StereoGlassesMode;


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

// OGLPoint4D is now a plain Swift struct in OGLTypes.swift - nothing in C
// touches it (directly or transitively), so it's no longer declared here.

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

// OGLRay/OGLLineSegment are now plain Swift structs in OGLTypes.swift -
// nothing in C touches them, so they're no longer declared here.

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

// OGLColorRGBA_Byte is now a plain Swift struct in OGLTypes.swift - nothing
// in C touches it, so it's no longer declared here.

typedef union
{
	GLfloat	value[16];
	#if defined(__ppc__)
	vector float v[4];
	#endif
}OGLMatrix4x4;

// OGLMatrix3x3 is now a plain Swift struct in OGLTypes.swift - nothing in C
// touches it, so it's no longer declared here.

typedef struct
{
	OGLVector3D 					normal;
	float 							constant;
}OGLPlaneEquation;

// OGLVertex is now a plain Swift struct in OGLTypes.swift - nothing in C
// touches it, so it's no longer declared here.

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


// OGLBoundingSphere is now a plain Swift struct in OGLTypes.swift - nothing
// in C touches it, so it's no longer declared here.


typedef struct
{
	float	top,bottom,left,right;
}OGLRect;

//========================

// OGLViewDefType/OGLStyleDefType/OGLCameraDefType are now plain Swift
// structs in OGLTypes.swift - nothing in C touches them, so they're no
// longer declared here.

typedef	struct
{
	OGLColorRGBA		ambientColor;
	int					numFillLights;
	OGLVector3D			fillDirection[MAX_FILL_LIGHTS];
	OGLColorRGBA		fillColor[MAX_FILL_LIGHTS];
}OGLLightDefType;


// OGLSetupInputType is now a plain Swift struct in OGLTypes.swift -
// nothing in C touches it, so it's no longer declared here.


		/* OGLSetupOutputType */

typedef struct
{
	Boolean					isActive;
	Rect					clip;				// not pane size, but clip:  left = amount to clip off left

	OGLLightDefType			lightList;
	OGLCameraPlacement		cameraPlacement[MAX_VIEWPORTS];	// 2 cameras, one for each viewport/player
	float					fov[MAX_VIEWPORTS],hither,yon;
	Boolean					useFog;
	Boolean					clearBackBuffer;
	OGLColorRGBA			clearColor;

	long					frameCount;

	Boolean					fadeSound;
}OGLSetupOutputType;


typedef enum SWIFT_ENUM_CLOSED VertexArrayRangeType
{
	VERTEX_ARRAY_RANGE_TYPE_PARTICLES1 SWIFT_NAME(particles1) = 0,			// particles
	VERTEX_ARRAY_RANGE_TYPE_PARTICLES2 SWIFT_NAME(particles2),				// it's double-buffered
	VERTEX_ARRAY_RANGE_TYPE_TERRAIN SWIFT_NAME(terrain),				// cached, but only for use by Terrain
	VERTEX_ARRAY_RANGE_TYPE_BG3DMODELS SWIFT_NAME(bg3dModels),				// all the .model files go here
	VERTEX_ARRAY_RANGE_TYPE_SKELETONS SWIFT_NAME(skeletons),				// all the local skeleton meshes go here
	VERTEX_ARRAY_RANGE_TYPE_SKELETONS2 SWIFT_NAME(skeletons2),				// double buffered
	VERTEX_ARRAY_RANGE_TYPE_CONTRAILS1 SWIFT_NAME(contrails1),
	VERTEX_ARRAY_RANGE_TYPE_CONTRAILS2 SWIFT_NAME(contrails2),
	VERTEX_ARRAY_RANGE_TYPE_ZAPS1 SWIFT_NAME(zaps1),
	VERTEX_ARRAY_RANGE_TYPE_ZAPS2 SWIFT_NAME(zaps2),


	VERTEX_ARRAY_RANGE_TYPE_USER1 SWIFT_NAME(user1),					// memory block is defined by the caller
	VERTEX_ARRAY_RANGE_TYPE_USER_FENCES SWIFT_NAME(userFences),
	VERTEX_ARRAY_RANGE_TYPE_USER_FENCES2 SWIFT_NAME(userFences2),
	VERTEX_ARRAY_RANGE_TYPE_USER_WATER SWIFT_NAME(userWater),
	VERTEX_ARRAY_RANGE_TYPE_USER_DUSTDEVIL SWIFT_NAME(userDustDevil),

	NUM_VERTEX_ARRAY_RANGES SWIFT_NAME(_count)
} VertexArrayRangeType;


		/* SPLITSCREEN */

typedef enum SWIFT_ENUM_CLOSED SplitscreenMode
{
	SPLITSCREEN_MODE_NONE SWIFT_NAME(none) = 0,
	SPLITSCREEN_MODE_HORIZ SWIFT_NAME(horizontal),			// 2 horizontal panes
	SPLITSCREEN_MODE_VERT SWIFT_NAME(vertical),			// 2 vertical panes

	NUM_SPLITSCREEN_MODES SWIFT_NAME(_count)
} SplitscreenMode;


//=====================================================================

#define OGL_CheckError() OGL_CheckError_Impl(__FILE__, __LINE__)





#if VERTEXARRAYRANGES
void AssignVertexArrayRangeMemory(long size, void *pointer, Byte type);
void ReleaseVertexArrayRangeMemory(Byte type);
#endif



#define GetOverlayPaneNumber() (gNumPlayers)
