/****************************/
/*   OPENGL SUPPORT.C	    */
/*   By Brian Greenstone    */
/* (c)2003 Pangea Software  */
/* (c)2022 Iliyas Jorio     */
/****************************/

// All function implementations are now in OGL_Support.swift. The globals
// below stay defined here (and `extern`'d via game.h) because Swift can
// read/write an extern C global once it's declared in a header, but can't
// originate a brand-new C-linkage global itself - same reasoning as gCoord
// staying in Objects.c, gNewParticleGroupDef in Particles.c, etc.
//
// gVertexArrayRangeObjects/gHardwareSupportsVertexArrayRange/
// gUsingVertexArrayRange are NOT defined here even though game.h still
// externs them: VERTEXARRAYRANGES is hardcoded to 0, so their original
// definitions were themselves entirely inside a dead `#if VERTEXARRAYRANGES`
// block (never actually compiled), and nothing anywhere references them -
// confirmed via a repo-wide grep before dropping them.

#include "game.h"

float			gAnaglyphFocallength	= 450.0f;
float			gAnaglyphEyeSeparation 	= 40.0f;
Byte			gAnaglyphPass;

SDL_GLContext	gAGLContext = nil;

OGLMatrix4x4	gViewToFrustumMatrix,gWorldToViewMatrix,gWorldToFrustumMatrix, gLocalToViewMatrix, gLocalToFrustumMatrix;
OGLMatrix4x4	gWorldToWindowMatrix[MAX_VIEWPORTS];

Byte			gCurrentSplitScreenPane = 0;
Byte			gActiveSplitScreenMode 	= SPLITSCREEN_MODE_NONE;		// currently active split mode

float			gCurrentPaneAspectRatio = 1;

Boolean			gMyState_Lighting;
OGLColorRGBA	gMyState_Color;

int				gPolysThisFrame;
