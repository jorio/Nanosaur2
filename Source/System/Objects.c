/*********************************/
/*    OBJECT MANAGER 		     */
/* (c)2003 Pangea Software  	 */
/* By Brian Greenstone      	 */
/*********************************/

// All function implementations are now in Objects.swift

#include "game.h"

ObjNode		*gFirstNodePtr = nil;
ObjNode		*gCurrentNode;

OGLPoint3D	gCoord;
OGLVector3D	gDelta;

float		gAutoFadeStartDist,gAutoFadeEndDist,gAutoFadeRange_Frac;

int			gNumObjectNodes;
int			gNumObjectNodesPeak = 0;
