//
// metaobjects.h
//

#pragma once

#define	MO_COOKIE				0xfeedface		// set at head of every object for validation
#define	MAX_MATERIAL_LAYERS		2				// max multitexture layers
#define	MO_MAX_MIPMAPS			6				// max mipmaps per material

#define	SPRITE_SCALE_BASIS_DENOMINATOR	640.0f

		/* OBJECT TYPES */
enum
{
	MO_TYPE_GROUP		= 	'grup',
	MO_TYPE_GEOMETRY	=	'geom',
	MO_TYPE_MATERIAL	=	'matl',
	MO_TYPE_MATRIX		=	'mtrx',
	MO_TYPE_PICTURE		=	'pict',
	MO_TYPE_SPRITE		=	'sprt'
};

	/* OBJECT SUBTYPES */

enum
{
	MO_GEOMETRY_SUBTYPE_VERTEXARRAY	=	'vary'
};


		/* META OBJECT HEADER */
		//
		// This structure is always at the head of any metaobject
		//

struct MetaObjectHeader
{
	uint32_t	cookie;						// this value should always == MO_COOKIE
	long		refCount;					// # times this is referenced
	uint32_t	type;						// object type
	intptr_t	subType;					// object sub-type
	void		*data;						// pointer to meta object's specific data

	struct MetaObjectHeader *parentGroup;			// illegal reference to parent group, or nil if no parent

	struct MetaObjectHeader *prevNode;			// ptr to previous node in linked list
	struct MetaObjectHeader *nextNode;			// ptr to next node in linked list
};
typedef struct MetaObjectHeader MetaObjectHeader;

typedef	void * MetaObjectPtr;


		/****************/
		/* GROUP OBJECT */
		/****************/

#define	MO_MAX_ITEMS_IN_GROUP	70

typedef struct
{
	int					numObjectsInGroup;
	MetaObjectHeader	*groupContents[MO_MAX_ITEMS_IN_GROUP];
}MOGroupData;

typedef struct
{
	MetaObjectHeader	objectHeader;
	MOGroupData			objectData;
}MOGroupObject;


		/*******************/
		/* MATERIAL OBJECT */
		/*******************/

typedef struct
{
	uint32_t			flags;
	OGLColorRGBA	diffuseColor;					// rgba diffuse color
	uint16_t			multiTextureMode;				// sphere map, etc.
	uint16_t			multiTextureCombine;			// blend, replace, etc.
	uint16_t			envMapNum;						// texture # in env map list to use

	uint32_t			numMipmaps;						// # texture mipmaps to use
	uint32_t			width,height;					// dimensions of texture
	GLint			pixelSrcFormat;					// OGL format (GL_RGBA, etc.) for src pixels
	GLint			pixelDstFormat;					// OGL format (GL_RGBA, etc.) for VRAM
	void			*texturePixels[MO_MAX_MIPMAPS]; // ptr to texture pixels for each mipmap
	GLuint			textureName[MO_MAX_MIPMAPS]; 	// texture name assigned by OpenGL
}MOMaterialData;

typedef struct
{
	MetaObjectHeader	objectHeader;
	MOMaterialData		objectData;
}MOMaterialObject;


enum
{
	MULTI_TEXTURE_MODE_REFLECTIONSPHERE,
	MULTI_TEXTURE_MODE_OBJECT_PLANE
};

enum
{
	MULTI_TEXTURE_COMBINE_MODULATE,
	MULTI_TEXTURE_COMBINE_ADD,
	MULTI_TEXTURE_COMBINE_ADDALPHA
};


		/********************************/
		/* VERTEX ARRAY GEOMETRY OBJECT */
		/********************************/

typedef struct
{
	GLuint vertexIndices[3];
}MOTriangleIndecies;

typedef struct
{
	short				VARtype;							// which VAR type (VERTEX_ARRAY_RANGE_TYPE_SHARED, etc) or -1 if not using VAR

	short				numMaterials;						// # material layers used in geometry (if negative, then use current texture)
	MOMaterialObject 	*materials[MAX_MATERIAL_LAYERS];	// a reference to a material meta object

	int					numPoints;							// # vertices in the model
	int					numTriangles;						// # triangls in the model
	OGLPoint3D			*points;							// ptr to array of vertex x,y,z coords
	OGLVector3D			*normals;							// ptr to array of vertex normals
	OGLTextureCoord		*uvs[MAX_MATERIAL_LAYERS];			// ptr to array of vertex uv's for each layer
	OGLColorRGBA		*colorsFloat;
	MOTriangleIndecies	*triangles;							// ptr to array of triangle triad indecies

	OGLBoundingBox		bBox;								// local BBox

	int					pointCapacity;						// size of point buffer. If 0, assume it's no larger than numPoints.
	int					triangleCapacity;					// size of triangle buffer. If 0, assume it's no larger than numTriangles.
}MOVertexArrayData;

typedef struct
{
	MetaObjectHeader	objectHeader;
	MOVertexArrayData	objectData;
}MOVertexArrayObject;



		/*****************/
		/* MATRIX OBJECT */
		/*****************/

typedef struct
{
	MetaObjectHeader	objectHeader;
	OGLMatrix4x4		matrix;
}MOMatrixObject;


		/******************/
		/* PICTURE OBJECT */
		/******************/

typedef struct
{
	OGLPoint3D			drawCoord;
	float				drawScaleX,drawScaleY;
	int					fullWidth,fullHeight;
	MOMaterialObject	*material;
}MOPictureData;

typedef struct
{
	MetaObjectHeader	objectHeader;
	MOPictureData		objectData;
}MOPictureObject;


		/*****************/
		/* SPRITE OBJECT */
		/*****************/

typedef struct
{
	float				width,height;			// pixel w/h of texture
	float				aspectRatio;			// h/w
	float				scaleBasis;
	Boolean				drawCentered;

	OGLPoint3D			coord;
	float				scaleX,scaleY;
	float				rot;

	MOMaterialObject	*material;
}MOSpriteData;

typedef struct
{
	MetaObjectHeader	objectHeader;
	MOSpriteData		objectData;
}MOSpriteObject;


typedef struct
{
	Boolean	loadFile;				// true if want to create sprite from pict right now, otherwise use from gSpriteList

	FSSpec	spec;					// picture file to load as sprite
	GLint	pixelFormat;			// format to store loaded sprite as

	short	group,type;				// group and type of gSpriteList sprite to use

	Boolean	drawCentered;

}MOSpriteSetupData;


//-----------------------------

void MO_InitHandler(void);
MetaObjectPtr MO_CreateNewObjectOfType(uint32_t type, intptr_t subType, void *data);
MetaObjectPtr MO_GetNewReference(MetaObjectPtr mo);
void MO_AppendToGroup(MOGroupObject *group, MetaObjectPtr newObject);
void MO_AttachToGroupStart(MOGroupObject *group, MetaObjectPtr newObject);
void MO_DrawGeometry_VertexArray(const MOVertexArrayData *data);
void MO_DrawGroup(const MOGroupObject *object);
void MO_DrawObject(const MetaObjectPtr object);
void MO_DrawMaterial(MOMaterialObject *matObj);
void MO_DrawMatrix(const MOMatrixObject *matObj);
void MO_DrawPicture(const MOPictureObject *picObj);
void MO_DisposeObjectReference(MetaObjectPtr obj);
void MO_DuplicateVertexArrayData(MOVertexArrayData *inData, MOVertexArrayData *outData, short varType);
void MO_DeleteObjectInfo_Geometry_VertexArray(MOVertexArrayData *data);
void MO_CalcBoundingBox(MetaObjectPtr object, OGLBoundingBox *bBox, OGLMatrix4x4 *m);
void MO_CalcBoundingSphere(MetaObjectPtr object, float *bSphere);

void MO_DrawSprite(const MOSpriteObject *spriteObj);
void MO_VertexArray_OffsetUVs(MetaObjectPtr object, float du, float dv);
void MO_Object_OffsetUVs(MetaObjectPtr object, float du, float dv);
