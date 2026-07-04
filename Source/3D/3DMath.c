/*******************************/
/*     		3D MATH.C		   */
/* (c)2003 Pangea Software  */
/* By Brian Greenstone         */
/*******************************/

// All function implementations are now in 3DMath_Angles.swift, 3DMath_Matrix.swift,
// and 3DMath_Geometry.swift. gUp stays here since it's a plain (non-static) global
// referenced directly via `extern` from many other files.

#include "game.h"

const 	OGLVector3D	gUp = {0,1,0};
