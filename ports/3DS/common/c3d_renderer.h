// c3d_renderer.h - citro3d-backed renderer for the 3DS port. Replaces
// picaGL (deleted; see git history) after picaGL's draw path was shown to
// drop texturing on healthy inputs and turned out to quietly downgrade all
// RGBA textures to 4-bit RGBA4.
//
// Scalar-typed C API only (no <3ds.h>/<citro3d.h> types leak out), so this
// is safe to include from game_3ds.h - same reasoning as romfs_shim.h et
// al: libctru's Handle typedef collides with the Mac Toolbox Handle from
// SwMacTypes.h, so game-visible headers must stay collision-free.
//
// The API mirrors Source/3D/RenderBackend.swift's protocol verbs 1:1;
// Citro3DBackend.swift is a thin forwarding layer over these. Enum-like
// int parameters use the constants below (kept as #defines, not enums, so
// the header stays trivially importable everywhere including Embedded
// Swift's ClangImporter).
#pragma once

#ifdef __cplusplus
extern "C" {
#endif

// RBBlendFactor
#define C3DR_BLEND_ONE                 0
#define C3DR_BLEND_SRC_ALPHA           1
#define C3DR_BLEND_ONE_MINUS_SRC_ALPHA 2

// RBMatrixMode
#define C3DR_MATRIX_MODELVIEW  0
#define C3DR_MATRIX_PROJECTION 1
#define C3DR_MATRIX_TEXTURE    2

// RBTextureEnv
#define C3DR_TEXENV_MODULATE        0
#define C3DR_TEXENV_COMBINE_ADD     1
#define C3DR_TEXENV_COMBINE_ADD_ALPHA 2

// RBPrimitive
#define C3DR_PRIM_QUADS      0
#define C3DR_PRIM_TRIANGLES  1
#define C3DR_PRIM_LINES      2
#define C3DR_PRIM_LINE_STRIP 3
#define C3DR_PRIM_LINE_LOOP  4

// Lifecycle. Init creates the top-screen render target and shader; call
// once after SDL_Init (SDL's n3ds video driver owns gfxInit). Present ends
// the current frame (starting one first if nothing drew - fades etc. must
// keep flipping).
void C3DR_Init(void);
void C3DR_Shutdown(void);
void C3DR_Present(void);

// Frame state
void C3DR_SetViewport(int x, int y, int w, int h);
void C3DR_SetClearColor(float r, float g, float b);
void C3DR_ClearColorAndDepth(void);
void C3DR_ClearDepthOnly(void);

// Raster state
void C3DR_SetBlendEnabled(int enabled);
void C3DR_SetBlendFunc(int srcFactor, int dstFactor);
void C3DR_SetCullEnabled(int enabled);
void C3DR_SetDepthTestEnabled(int enabled);
void C3DR_SetDepthWrite(int enabled);
void C3DR_SetAlphaTest(int enabled, int trimLowAlpha);
void C3DR_SetColorMask(int r, int g, int b, int a);
void C3DR_SetColor4f(float r, float g, float b, float a);

// Matrix stack (GL semantics; m is 16 floats column-major)
void C3DR_MatrixMode(int mode);
void C3DR_PushMatrix(void);
void C3DR_PopMatrix(void);
void C3DR_LoadIdentity(void);
void C3DR_LoadMatrix(const float *m);
void C3DR_MultMatrix(const float *m);
void C3DR_GetMatrix(int mode, float *outM);
void C3DR_Frustum(float left, float right, float bottom, float top, float nearVal, float farVal);
void C3DR_Ortho(float left, float right, float bottom, float top, float nearVal, float farVal);
void C3DR_Translate(float x, float y, float z);
void C3DR_Scale(float x, float y, float z);
void C3DR_Rotate(float angleDegrees, float x, float y, float z);

// Textures. Handles are 1-based indices into an internal table (0 = none,
// matching GL's convention so game code storing names keeps working).
// pixels are RGBA8 rows, first row = v0 (GL bottom-up origin - rows are
// flipped during tiling exactly like desktop GL + the game's UVs expect).
unsigned C3DR_CreateTexture(int width, int height, const void *rgba8Pixels);
void C3DR_UpdateTextureBGRA(unsigned name, int width, int height, const void *bgraPixels);
void C3DR_DeleteTexture(unsigned name);
void C3DR_ActiveTextureUnit(int unit); // 0 or 1
void C3DR_BindTexture(unsigned name);  // binds to the active unit
void C3DR_SetTexture2DEnabled(int enabled); // active unit
void C3DR_SetTextureEnv(int mode);          // active unit (unit 1 in practice)
void C3DR_SetTextureWrap(int axis, int clamp); // axis: 0=U 1=V; applies to the active unit's bound texture

// Indexed triangle-list draw (the MO_DrawGeometry_VertexArray path).
// Any attribute pointer may be NULL; indices are the game's 32-bit triples
// (downcast to the PICA's 16-bit indices internally; the vertex count is
// derived from the max index during that same scan).
void C3DR_DrawIndexedTriangles(
	const float *points,    // xyz per vertex
	const float *colors,    // rgba per vertex (NULL -> current color)
	const float *uv0,       // uv per vertex (NULL -> 0,0)
	const float *uv1,
	const unsigned *indices, // 3 per triangle
	int numTriangles);

// Immediate mode (2D quads/sprite paths). Line primitives are accepted but
// currently dropped (PICA has no line primitive; nothing on the 3DS path
// draws lines - DrawBlueLine is shutter-stereo desktop code).
void C3DR_Begin(int primitive);
void C3DR_TexCoord2f(float u, float v);
void C3DR_Vertex3f(float x, float y, float z);
void C3DR_End(void);

#ifdef __cplusplus
}
#endif
