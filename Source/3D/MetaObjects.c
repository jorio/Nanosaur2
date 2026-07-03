/****************************/
/*   METAOBJECTS.C		    */
/* (c)2003 Pangea Software  */
/*   By Brian Greenstone    */
/****************************/

// All function implementations are now in MetaObjects.swift

#include "game.h"

float				gGlobalTransparency = 1;			// 0 == clear, 1 = opaque
OGLColorRGB			gGlobalColorFilter = {1,1,1};
uint32_t				gGlobalMaterialFlags = 0;

MOMaterialObject	*gMostRecentMaterial;
