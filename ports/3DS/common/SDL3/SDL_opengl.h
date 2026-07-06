// SDL3/SDL_opengl.h - GL-compatibility shim for the 3DS target (Phase 3 of
// docs/3DS_PORT_PLAN.md, "Milestone: a real, navigable main menu"). Real
// desktop game.h includes SDL3's actual <SDL3/SDL_opengl.h> (desktop GL
// headers); this file stands in for it on 3DS, declaring the same GL
// surface Source/**/*.swift actually calls (glBegin/glVertex2f/glTexEnvi/
// etc.) with signatures backed by a real implementation in
// ports/3DS/common/glcompat.c - citro3d's C3D_Imm* immediate-mode API
// (see that file's own header comment for why this works: the PICA200's
// fragment stage - texture combiners, alpha test, blending - is genuine
// fixed-function hardware, so only the vertex transform needs a compiled
// shader, not a from-scratch renderer).
//
// Deliberately scalar-typed (GLfloat/GLuint/GLenum, no C3D_Tex*/C3D_Mtx*
// etc.) so this header never needs citro3d's own types in scope - Swift
// only ever sees plain numbers, and glcompat.c (a separate translation
// unit, compiled directly by arm-none-eabi-gcc, never through
// -import-objc-header) is where the real citro3d types live. This sidesteps
// the `Handle`-typedef collision between libctru and Pomme documented in
// game_3ds.h - citro3d headers are never included in the same translation
// unit as Pomme/game.h.
#pragma once

typedef float GLfloat;
typedef double GLdouble;
typedef unsigned int GLuint;
typedef int GLint;
typedef int GLsizei;
typedef unsigned int GLenum;
typedef unsigned int GLbitfield;
typedef unsigned char GLboolean;
typedef unsigned char GLubyte;

// MARK: - Constants
//
// These only need to be unique and internally consistent with
// glcompat.c's switch statements - nothing links against real desktop GL
// headers on this target, so the numeric values don't need to match
// desktop GL's.

// glBegin primitives
#define GL_LINES              0x0001
#define GL_LINE_LOOP          0x0002
#define GL_LINE_STRIP         0x0003
#define GL_TRIANGLES          0x0004
#define GL_QUADS              0x0007

// glClear bits
#define GL_DEPTH_BUFFER_BIT   0x0100
#define GL_COLOR_BUFFER_BIT   0x4000

// glEnable/glDisable/glIsEnabled targets
#define GL_LINE_SMOOTH        0x0B20
#define GL_CULL_FACE          0x0B44
#define GL_LIGHTING           0x0B50
#define GL_LIGHT0             0x4000
#define GL_COLOR_MATERIAL     0x0B57
#define GL_FOG                0x0B60
#define GL_DEPTH_TEST         0x0B71
#define GL_ALPHA_TEST         0x0BC0
#define GL_BLEND              0x0BE2
#define GL_SCISSOR_TEST       0x0C11
#define GL_COLOR_LOGIC_OP     0x0BF2
#define GL_DITHER             0x0BD0
#define GL_TEXTURE            0x1702
#define GL_TEXTURE_1D         0x0DE0
#define GL_TEXTURE_2D         0x0DE1
#define GL_TEXTURE_3D         0x806F
#define GL_TEXTURE_GEN_S      0x0C60
#define GL_TEXTURE_GEN_T      0x0C61
#define GL_NORMALIZE          0x0BA1
#define GL_RESCALE_NORMAL     0x803A
#define GL_LINE_STIPPLE       0x0B24

// glGetBooleanv/glGetFloatv/glGetIntegerv targets
#define GL_MATRIX_MODE        0x0BA0
#define GL_MODELVIEW_MATRIX   0x0BA6
#define GL_PROJECTION_MATRIX  0x0BA7
#define GL_MAX_TEXTURE_SIZE   0x0D33
#define GL_VIEWPORT           0x0BA2
#define GL_DEPTH_WRITEMASK    0x0B72

// glMatrixMode targets
#define GL_MODELVIEW          0x1700
#define GL_PROJECTION         0x1701

// glBlendFunc factors
#define GL_ONE                1
#define GL_SRC_ALPHA          0x0302
#define GL_ONE_MINUS_SRC_ALPHA 0x0303

// glAlphaFunc/depth func comparisons
#define GL_NOTEQUAL           0x0205
#define GL_GREATER            0x0204

// glCullFace/glFrontFace
#define GL_FRONT_AND_BACK     0x0408
#define GL_BACK               0x0405
#define GL_BACK_LEFT          0x0402
#define GL_BACK_RIGHT         0x0403
#define GL_CCW                0x0901

// glTexImage2D/glTexSubImage2D formats/types
#define GL_RGBA               0x1908
#define GL_BGRA               0x80E1
#define GL_UNSIGNED_BYTE      0x1401
#define GL_UNSIGNED_INT       0x1405
#define GL_UNSIGNED_INT_8_8_8_8_REV 0x8367
#define GL_UNSIGNED_SHORT_1_5_5_5_REV 0x8366
#define GL_FLOAT              0x1406

// glTexParameter targets/values
#define GL_TEXTURE_MAG_FILTER 0x2800
#define GL_TEXTURE_MIN_FILTER 0x2801
#define GL_TEXTURE_WRAP_S     0x2802
#define GL_TEXTURE_WRAP_T     0x2803
#define GL_LINEAR             0x2601
#define GL_REPEAT             0x2901
#define GL_CLAMP_TO_EDGE      0x812F
#define GL_MAX_TEXTURE_MAX_ANISOTROPY_EXT 0x84FF

// glTexEnv targets/values
#define GL_TEXTURE_ENV        0x2300
#define GL_TEXTURE_ENV_MODE   0x2200
#define GL_MODULATE           0x2100
#define GL_ADD                0x0104
#define GL_COMBINE            0x8570
#define GL_COMBINE_RGB        0x8571
#define GL_COMBINE_ALPHA      0x8572
#define GL_SPHERE_MAP         0x2402
#define GL_TEXTURE_GEN_MODE   0x2500

// glTexGen targets
#define GL_S                  0x2000
#define GL_T                  0x2001

// glActiveTexture/glClientActiveTexture units
#define GL_TEXTURE0           0x84C0
#define GL_TEXTURE0_ARB       0x84C0
#define GL_TEXTURE1           0x84C1

// Lighting/material
#define GL_AMBIENT            0x1200
#define GL_DIFFUSE            0x1201
#define GL_AMBIENT_AND_DIFFUSE 0x1602
#define GL_POSITION           0x1203
#define GL_LIGHT_MODEL_AMBIENT 0x0B53
#define GL_LIGHT_MODEL_TWO_SIDE 0x0B52

// Fog
#define GL_FOG_MODE           0x0B65
#define GL_FOG_DENSITY        0x0B62
#define GL_FOG_START          0x0B63
#define GL_FOG_END            0x0B64
#define GL_FOG_COLOR          0x0B66
#define GL_FOG_HINT           0x0C54
#define GL_FASTEST            0x1101

// glEnableClientState/glDisableClientState arrays
#define GL_VERTEX_ARRAY       0x8074
#define GL_NORMAL_ARRAY       0x8075
#define GL_COLOR_ARRAY        0x8076
#define GL_TEXTURE_COORD_ARRAY 0x8078

// glPolygonMode
#define GL_LINE               0x1B01
#define GL_FILL               0x1B02

// glPushAttrib
#define GL_ALL_ATTRIB_BITS    0xFFFFFFFF

// glGetError results
#define GL_NO_ERROR           0
#define GL_INVALID_ENUM       0x0500
#define GL_INVALID_VALUE      0x0501
#define GL_INVALID_OPERATION  0x0502
#define GL_STACK_OVERFLOW     0x0503
#define GL_STACK_UNDERFLOW    0x0504

#define GL_TRUE               1
#define GL_FALSE              0

// MARK: - Immediate mode

void glBegin(GLenum mode);
void glEnd(void);
void glVertex2f(GLfloat x, GLfloat y);
void glVertex3f(GLfloat x, GLfloat y, GLfloat z);
void glVertex3fv(const GLfloat *v);
void glTexCoord2f(GLfloat s, GLfloat t);
void glTexCoord2fv(const GLfloat *v);
void glColor4f(GLfloat r, GLfloat g, GLfloat b, GLfloat a);
void glColor4fv(const GLfloat *v);

// MARK: - State

void glEnable(GLenum cap);
void glDisable(GLenum cap);
GLboolean glIsEnabled(GLenum cap);
void glBlendFunc(GLenum sfactor, GLenum dfactor);
void glAlphaFunc(GLenum func, GLfloat ref);
void glCullFace(GLenum mode);
void glFrontFace(GLenum mode);
void glDepthMask(GLboolean flag);
void glColorMask(GLboolean r, GLboolean g, GLboolean b, GLboolean a);
void glShadeModel(GLenum mode);
void glHint(GLenum target, GLenum mode);
void glPolygonMode(GLenum face, GLenum mode);
void glColorMaterial(GLenum face, GLenum mode);
void glPushAttrib(GLbitfield mask);
void glPopAttrib(void);
GLenum glGetError(void);
void glGetBooleanv(GLenum pname, GLboolean *params);
void glGetFloatv(GLenum pname, GLfloat *params);
void glGetIntegerv(GLenum pname, GLint *params);

// MARK: - Matrix

void glMatrixMode(GLenum mode);
void glLoadIdentity(void);
void glLoadMatrixf(const GLfloat *m);
void glMultMatrixf(const GLfloat *m);
void glPushMatrix(void);
void glPopMatrix(void);
void glTranslatef(GLfloat x, GLfloat y, GLfloat z);
void glRotatef(GLfloat angle, GLfloat x, GLfloat y, GLfloat z);
void glScalef(GLfloat x, GLfloat y, GLfloat z);
void glOrtho(GLdouble left, GLdouble right, GLdouble bottom, GLdouble top, GLdouble zNear, GLdouble zFar);
void glFrustum(GLdouble left, GLdouble right, GLdouble bottom, GLdouble top, GLdouble zNear, GLdouble zFar);
void glViewport(GLint x, GLint y, GLsizei width, GLsizei height);

// MARK: - Clear

void glClearColor(GLfloat r, GLfloat g, GLfloat b, GLfloat a);
void glClear(GLbitfield mask);

// MARK: - Textures

void glGenTextures(GLsizei n, GLuint *textures);
void glDeleteTextures(GLsizei n, const GLuint *textures);
void glBindTexture(GLenum target, GLuint texture);
void glTexImage2D(GLenum target, GLint level, GLint internalformat, GLsizei width, GLsizei height, GLint border, GLenum format, GLenum type, const void *pixels);
void glTexSubImage2D(GLenum target, GLint level, GLint xoffset, GLint yoffset, GLsizei width, GLsizei height, GLenum format, GLenum type, const void *pixels);
void glTexParameteri(GLenum target, GLenum pname, GLint param);
void glTexParameterf(GLenum target, GLenum pname, GLfloat param);
void glTexEnvi(GLenum target, GLenum pname, GLint param);
void glTexGeni(GLenum target, GLenum pname, GLint param);
void glActiveTexture(GLenum texture);
void glClientActiveTexture(GLenum texture);

// MARK: - Lighting/fog (state-tracked only; not fed to the vertex shader
// yet - see glcompat.c's header comment and docs/3DS_PORT_PLAN.md's
// "no lighting support" note. Menu-only milestone doesn't need real
// lighting; tracked as a real gap for the 3D-gameplay-screens follow-up.)

void glLightfv(GLenum light, GLenum pname, const GLfloat *params);
void glLightModelfv(GLenum pname, const GLfloat *params);
void glLightModeli(GLenum pname, GLint param);
void glMaterialfv(GLenum face, GLenum pname, const GLfloat *params);
void glFogf(GLenum pname, GLfloat param);
void glFogfv(GLenum pname, const GLfloat *params);
void glFogi(GLenum pname, GLint param);

// MARK: - Vertex arrays (not implemented - no call sites reach these in a
// menu-only build; real gameplay-screen skeleton/terrain rendering needs
// these ported to C3D_BufInfo/C3D_AttrInfo + C3D_DrawArrays, a separate
// follow-up per docs/3DS_PORT_PLAN.md's Phase 3 table.)

void glEnableClientState(GLenum array);
void glDisableClientState(GLenum array);
void glVertexPointer(GLint size, GLenum type, GLsizei stride, const void *pointer);
void glNormalPointer(GLenum type, GLsizei stride, const void *pointer);
void glTexCoordPointer(GLint size, GLenum type, GLsizei stride, const void *pointer);
void glColorPointer(GLint size, GLenum type, GLsizei stride, const void *pointer);
void glDrawElements(GLenum mode, GLsizei count, GLenum type, const void *indices);
void glDrawBuffer(GLenum buf);
