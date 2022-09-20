//
// bg3d.h
//

#ifndef BG3D_H
#define BG3D_H


#define	MAX_MULTITEXTURE_LAYERS		4			// max # of multi texture layers supported
												// WARNING: changing this may alter file format!!

#define	MAX_BG3D_MATERIALS			400			// max # of materials in a bg3d file

#define	MAX_BG3D_GROUPS			(MODEL_GROUP_SKELETONBASE+MAX_SKELETON_TYPES)	// skeletons are @ end of list, so can use these counts for max #
#define	MAX_OBJECTS_IN_GROUP	100

		/***********************/
		/* BG3D FILE CONTAINER */
		/***********************/

typedef struct
{
	int					numMaterials;
	MOMaterialObject	*materials[MAX_BG3D_MATERIALS];	// references to all of the materials used in file
	MetaObjectPtr		root;							// the root object or group containing all geometry in file
}BG3DFileContainer;



		/* BG3D HEADER */

typedef struct
{
	char			headerString[16];			// header string
	NumVersion		version;					// version of file
}BG3DHeaderType;


	/* BG3D MATERIAL FLAGS */

enum
{
	BG3D_MATERIALFLAG_TEXTURED		= 	1,
	BG3D_MATERIALFLAG_ALWAYSBLEND	=	(1<<1),	// set if always want to GL_BLEND this texture when drawn
	BG3D_MATERIALFLAG_CLAMP_U		=	(1<<2),
	BG3D_MATERIALFLAG_CLAMP_V		=	(1<<3),
	BG3D_MATERIALFLAG_MULTITEXTURE	=	(1<<4),
	BG3D_MATERIALFLAG_CLAMP_U_TRUE	=	(1<<5),	// this flag is set after glTexParameterf has been called to set clamping for this texture
	BG3D_MATERIALFLAG_CLAMP_V_TRUE	=	(1<<6)

};


		/* TAG TYPES */

enum
{
	BG3D_TAGTYPE_MATERIALFLAGS				=	0,
	BG3D_TAGTYPE_MATERIALDIFFUSECOLOR		=	1,
	BG3D_TAGTYPE_TEXTUREMAP					=	2,
	BG3D_TAGTYPE_GROUPSTART					=	3,
	BG3D_TAGTYPE_GROUPEND					=	4,
	BG3D_TAGTYPE_GEOMETRY					=	5,
	BG3D_TAGTYPE_VERTEXARRAY				=	6,
	BG3D_TAGTYPE_NORMALARRAY				=	7,
	BG3D_TAGTYPE_UVARRAY					=	8,
	BG3D_TAGTYPE_COLORARRAY					=	9,
	BG3D_TAGTYPE_TRIANGLEARRAY				= 	10,
	BG3D_TAGTYPE_ENDFILE					=	11,
	BG3D_TAGTYPE_BOUNDINGBOX				=	12,
	BG3D_TAGTYPE_JPEGTEXTURE				=	13
};


typedef struct
{
	u_long	width,height;					// dimensions of texture
	GLint	srcPixelFormat;					// OGL format (GL_RGBA, etc.) for internal
	GLint	dstPixelFormat;					// format for VRAM
	u_long	bufferSize;						// size of texture data to follow
	u_long	reserved[4];					// for future use
}BG3DTextureHeader;


typedef struct
{
	u_long	width,height;					// dimensions of texture
	u_long	bufferSize;						// size of JPEG data to follow
	u_long	hasAlphaChannel;				// true if alpha buffer follows JPEG data
}BG3DJPEGTextureHeader;


	/* GEOMETRY TYPES */

enum
{
	BG3D_GEOMETRYTYPE_VERTEXELEMENTS

};


		/* BG3D GEOMETRY HEADER */

typedef struct
{
	u_long	type;								// geometry type
	long		numMaterials;						// # material layers
	u_long	layerMaterialNum[MAX_MULTITEXTURE_LAYERS];	// index into material list
	u_long	flags;								// flags
	u_long	numPoints;							// (if applicable)
	u_long	numTriangles;						// (if applicable)
	u_long	reserved[4];						// for future use
}BG3DGeometryHeader;




//-----------------------------------


void InitBG3DManager(void);
void ImportBG3D(FSSpec *spec, int groupNum, OGLSetupOutputType *setupInfo, short varType);
void DisposeBG3DContainer(int groupNum);
void DisposeAllBG3DContainers(void);
void BG3D_SetContainerMaterialFlags(short group, short type, short geometryNum, u_long flags);
void BG3D_SphereMapGeomteryMaterial(short group, short type, short geometryNum, u_short combineMode, u_short envMapNum);
void SetSphereMapInfoOnVertexArrayData(MOVertexArrayData *va, u_short combineMode, u_short envMapNum);
void SetSphereMapInfoOnVertexArrayObject(MOVertexArrayObject *mo, u_short combineMode, u_short envMapNum);
void SetSphereMapInfoOnMaterialObject(MOMaterialObject *mat, u_short combineMode, u_short envMapNum);


#endif

