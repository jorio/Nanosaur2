// SDL3/SDL_opengl.h - forwards to picaGL's real GL/gl.h for the 3DS target.
// Real desktop game.h includes SDL3's actual <SDL3/SDL_opengl.h> (desktop
// GL headers); this file stands in for it on 3DS.
//
// Previously this declared a hand-rolled ~70-function GL-compatibility
// subset backed by ports/3DS/common/glcompat.c (a citro3d C3D_Imm*-based
// shim written for this port). Replaced with picaGL
// (ports/3DS/vendor/picaGL, see VENDORED.md) - a real, existing OpenGL
// 1.x-style implementation for the PICA200 that talks to the GPU command
// queue directly (not citro3d), providing a full standard `gl.h` plus real
// (not stubbed) vertex-array/texture/blend/depth/stencil support our own
// shim didn't have. glcompat.c/its shader are retired, not kept alongside
// this - picaGL fully supersedes them.
#pragma once
#include <GL/gl.h>

// A handful of real GL 1.x/1.3 constants Source/**/*.swift references that
// picaGL's own gl.h doesn't declare (it isn't a complete Khronos header -
// no functional support for these exists in picaGL either, so this is
// purely to let the engine compile; call sites using these already work
// with whatever picaGL's fixed-function texenv/state actually does).
#ifndef GL_TEXTURE_3D
#define GL_TEXTURE_3D 0x806F
#endif
#ifndef GL_COMBINE_RGB
#define GL_COMBINE_RGB 0x8571
#endif
#ifndef GL_COMBINE_ALPHA
#define GL_COMBINE_ALPHA 0x8572
#endif
#ifndef GL_LINE_STIPPLE
#define GL_LINE_STIPPLE 0x0B24
#endif
#ifndef GL_LINE_SMOOTH
#define GL_LINE_SMOOTH 0x0B20
#endif
#ifndef GL_COLOR_LOGIC_OP
#define GL_COLOR_LOGIC_OP 0x0BF2
#endif
#ifndef GL_DEPTH_WRITEMASK
#define GL_DEPTH_WRITEMASK 0x0B72
#endif
#ifndef GL_ALL_ATTRIB_BITS
#define GL_ALL_ATTRIB_BITS 0xFFFFFFFFu
#endif
#ifndef GL_MAX_TEXTURE_MAX_ANISOTROPY_EXT
#define GL_MAX_TEXTURE_MAX_ANISOTROPY_EXT 0x84FF
#endif
