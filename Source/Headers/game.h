#pragma once


		/* MY BUILD OPTIONS */

#define	OEM				1
#define DEMO			0
#define ALLOW_2P_INDEMO 0			// special build for Apple's .Mac promotion

#if !defined(__LITTLE_ENDIAN__) && !(__BIG_ENDIAN__)
#define __LITTLE_ENDIAN__ 1
#endif

		/* HEADERS */

#include <Pomme.h>
#include <SDL.h>
#include <SDL_opengl.h>
#include <SDL_opengl_glext.h>
#include <GL/glu.h> //---TEMP

typedef void* AGLContext;
typedef void* AGLPixelFormat;
typedef void* AGLDrawable;
typedef void* ImageDescriptionHandle;
typedef float CGGammaValue;
#define aglGetError() glGetError()
#define AGL_NO_ERROR GL_NO_ERROR
#define aglSwapBuffers(whatever) SDL_GL_SwapWindow(gSDLWindow)
#define aglSetCurrentContext(whatever) SDL_GL_MakeCurrent(gSDLWindow, (whatever))
#define FlightPhysicsCalibration(whatever)

#if 0
#include <Carbon/Carbon.h>

#include <IOKit/IOKitLib.h>
#include <IOKit/IOCFPlugIn.h>
#include <IOKit/hid/IOHIDLib.h>
#include <IOKit/hid/IOHIDKeys.h>
#include <Kernel/IOKit/hidsystem/IOHIDUsageTables.h>

#include <Quicktime/Movies.h>
#include <AGL/agl.h>
//#include <AGL/glu.h>
#include <OpenGL/glext.h>
#endif


#include "globals.h"
#include "structs.h"

#include "collision.h"
#include "ogl_support.h"
#include "metaobjects.h"
#include "ogl_shaders.h"
#include "main.h"
#include "terrain.h"
#include "player.h"
#include "mobjtypes.h"
#include "objects.h"
#include "misc.h"
#include "sound2.h"
#include "mycoreaudio.h"
#include "sobjtypes.h"
#include "sprites.h"
#include "shards.h"
#include "sparkle.h"
#include "bg3d.h"
#include "effects.h"
#include "camera.h"
#include 	"input.h"
#include "skeleton.h"
#include "file.h"
#include "fences.h"
#include "splineitems.h"
#include "items.h"
#include "windows.h"
#include "enemy.h"
#include "water.h"
#include "miscscreens.h"
#include	"infobar.h"
#include	"pick.h"
#include "internet.h"
#include "splinemanager.h"
#include "3dmath.h"

#define IMPME DoFatalAlert("IMPLEMENT ME in %s", __func__)
#define SOFTIMPME printf("soft IMPLEMENT ME in %s\n", __func__)

#define GAME_ASSERT(condition) do { if (!(condition)) DoFatalAlert("%s:%d: %s", __func__, __LINE__, #condition); } while(0)
#define GAME_ASSERT_MESSAGE(condition, message) do { if (!(condition)) DoFatalAlert("%s:%d: %s", __func__, __LINE__, message); } while(0)
