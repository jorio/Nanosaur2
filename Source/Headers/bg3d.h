//
// bg3d.h
//

#ifndef BG3D_H
#define BG3D_H


#define	MAX_BG3D_MATERIALS			400			// max # of materials in a bg3d file

#define	MAX_BG3D_GROUPS			((int)MODEL_GROUP_SKELETONBASE+(int)MAX_SKELETON_TYPES)	// skeletons are @ end of list, so can use these counts for max #
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

// BG3DHeaderType, BG3DTextureHeader, BG3DJPEGTextureHeader, and
// BG3DGeometryHeader are now defined as native Swift structs in the
// BG3DFile module (Sources/BG3DFile, compiled flat into this game's single
// Swift module - see CMakeLists.txt) instead of here. That module is a
// tested, standalone parser for the BG3D tag-stream format (see
// Tests/BG3DFileTests), verified byte-for-byte against every real .bg3d
// asset in Data/Models and Data/Skeletons.


	/* BG3D MATERIAL FLAGS */

enum
{
	BG3D_MATERIALFLAG_TEXTURED		= 	1,
	BG3D_MATERIALFLAG_ALWAYSBLEND	=	(1<<1),	// set if always want to GL_BLEND this texture when drawn
	BG3D_MATERIALFLAG_CLAMP_U		=	(1<<2),
	BG3D_MATERIALFLAG_CLAMP_V		=	(1<<3),
	BG3D_MATERIALFLAG_MULTITEXTURE	=	(1<<4),
	BG3D_MATERIALFLAG_CLAMP_U_TRUE	=	(1<<5),	// this flag is set after glTexParameterf has been called to set clamping for this texture
	BG3D_MATERIALFLAG_CLAMP_V_TRUE	=	(1<<6),
};


// BG3D_TAGTYPE_* (tag stream chunk types) and BG3D_GEOMETRYTYPE_* are now
// BG3DTag/BG3DGeometryType in the BG3DFile module (Sources/BG3DFile) -
// nothing in C reads the file format directly anymore, and Bg3d.swift
// switches on the Swift enums instead.




#endif

