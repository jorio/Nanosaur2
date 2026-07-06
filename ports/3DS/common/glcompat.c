// glcompat.c - GL-compatibility shim backing SDL3/SDL_opengl.h's
// declarations, for the 3DS target. See docs/3DS_PORT_PLAN.md, "Milestone:
// a real, navigable main menu", step 1.
//
// Strategy: citro3d's C3D_ImmDrawBegin/C3D_ImmSendAttrib/C3D_ImmDrawEnd is
// real GPU immediate-mode vertex submission, shaped like glBegin/glVertex/
// glEnd. The PICA200's fragment stage (texture combiners, alpha test,
// blending) is genuine fixed-function hardware - same as desktop GL's
// fixed-function pipeline - so only the *vertex* transform needs a real
// shader (glcompat.shbin, compiled from shaders/glcompat.v.pica: transforms
// position by one `mvp` uniform this file maintains as a CPU-side "matrix
// stack" mirroring glMatrixMode/glLoadIdentity/glMultMatrixf, and passes
// texcoord0/color straight through unlit).
//
// This is a SEPARATE translation unit from the Swift bridging header
// (game_3ds.h) - compiled directly by arm-none-eabi-gcc, like shim.c, never
// through -import-objc-header. That's deliberate: citro3d's own types
// (C3D_Tex, C3D_Mtx, etc.) never need to coexist with Pomme/game.h's Mac
// Toolbox types in the same translation unit, sidestepping the `Handle`
// typedef collision documented in game_3ds.h. Swift only ever sees the
// scalar-typed (GLfloat/GLuint/GLenum) declarations in SDL_opengl.h.
//
// Known gaps (not needed for the main-menu milestone, tracked as real
// follow-up work rather than silently wrong): no lighting (glLightfv/
// glMaterialfv/glLightModel* are state-tracked but never fed to the vertex
// shader - the shader has no lighting uniforms at all yet), no fog, no
// GL_LINES/GL_LINE_LOOP/GL_LINE_STRIP (PICA200's primitive assembler only
// has triangles/strip/fan/geometry - no native line primitive - so these
// are silently skipped), no vertex-array/glDrawElements path (needed for
// skeleton/terrain rendering, not menu sprites/HUD).

#include <citro3d.h>
#include <string.h>
#include <stdlib.h>
#include "SDL3/SDL_opengl.h"
#include "glcompat_shbin.h"

// MARK: - Shader + attribute setup

static DVLB_s *sGlcompatDvlb;
static shaderProgram_s sGlcompatProgram;
static int sUlocMvp;
static bool sInited;

void GLCompat_Init(void)
{
    if (sInited) {
        return;
    }
    sInited = true;

    sGlcompatDvlb = DVLB_ParseFile((u32 *)glcompat_shbin, glcompat_shbin_size);
    shaderProgramInit(&sGlcompatProgram);
    shaderProgramSetVsh(&sGlcompatProgram, &sGlcompatDvlb->DVLE[0]);
    C3D_BindProgram(&sGlcompatProgram);

    sUlocMvp = shaderInstanceGetUniformLocation(sGlcompatProgram.vertexShader, "mvp");

    // Attribute format/count are ignored in immediate mode (see
    // 3ds-examples/graphics/gpu/immediate) - only the loader *count* (3:
    // position, texcoord, color) and order matter, matching how glEnd
    // below sends exactly 3 C3D_ImmSendAttrib calls per vertex.
    C3D_AttrInfo *attrInfo = C3D_GetAttrInfo();
    AttrInfo_Init(attrInfo);
    AttrInfo_AddLoader(attrInfo, 0, GPU_FLOAT, 4); // v0 = position
    AttrInfo_AddLoader(attrInfo, 1, GPU_FLOAT, 4); // v1 = texcoord0
    AttrInfo_AddLoader(attrInfo, 2, GPU_FLOAT, 4); // v2 = color

    C3D_CullFace(GPU_CULL_NONE);
    C3D_DepthTest(true, GPU_GEQUAL, GPU_WRITE_ALL);
}

// MARK: - Matrix stack
//
// PICA200 has no matrix stack of its own - glMatrixMode/glLoadIdentity/
// glTranslatef/etc. are emulated entirely on the CPU here, and multiplied
// down to one `mvp` uniform matrix uploaded at glEnd time (matching how the
// shader only has that one uniform - see glcompat.v.pica).

#define MATRIX_STACK_DEPTH 16

static GLenum sMatrixMode = GL_MODELVIEW;
static C3D_Mtx sModelView;
static C3D_Mtx sProjection;
static C3D_Mtx sModelViewStack[MATRIX_STACK_DEPTH];
static C3D_Mtx sProjectionStack[MATRIX_STACK_DEPTH];
static int sModelViewStackTop;
static int sProjectionStackTop;

static C3D_Mtx *currentMatrix(void)
{
    return sMatrixMode == GL_PROJECTION ? &sProjection : &sModelView;
}

void glMatrixMode(GLenum mode)
{
    sMatrixMode = mode;
}

void glLoadIdentity(void)
{
    Mtx_Identity(currentMatrix());
}

void glLoadMatrixf(const GLfloat *m)
{
    // OpenGL matrices are column-major float[16]; C3D_Mtx is row-major
    // internally but exposes the same conceptual layout via Mtx_FromRows.
    // Nothing in this engine actually calls glLoadMatrixf with a
    // non-identity matrix today (grep shows no call sites), so this is
    // provided for completeness but unverified.
    C3D_Mtx *cur = currentMatrix();
    memcpy(cur, m, sizeof(float) * 16);
}

void glMultMatrixf(const GLfloat *m)
{
    C3D_Mtx incoming;
    memcpy(&incoming, m, sizeof(float) * 16);
    C3D_Mtx *cur = currentMatrix();
    C3D_Mtx result;
    Mtx_Multiply(&result, cur, &incoming);
    *cur = result;
}

void glPushMatrix(void)
{
    if (sMatrixMode == GL_PROJECTION) {
        if (sProjectionStackTop < MATRIX_STACK_DEPTH) {
            sProjectionStack[sProjectionStackTop++] = sProjection;
        }
    } else {
        if (sModelViewStackTop < MATRIX_STACK_DEPTH) {
            sModelViewStack[sModelViewStackTop++] = sModelView;
        }
    }
}

void glPopMatrix(void)
{
    if (sMatrixMode == GL_PROJECTION) {
        if (sProjectionStackTop > 0) {
            sProjection = sProjectionStack[--sProjectionStackTop];
        }
    } else {
        if (sModelViewStackTop > 0) {
            sModelView = sModelViewStack[--sModelViewStackTop];
        }
    }
}

void glTranslatef(GLfloat x, GLfloat y, GLfloat z)
{
    Mtx_Translate(currentMatrix(), x, y, z, true);
}

void glRotatef(GLfloat angle, GLfloat x, GLfloat y, GLfloat z)
{
    C3D_Mtx *cur = currentMatrix();
    float radians = angle * (3.14159265358979323846f / 180.0f);
    if (x != 0.0f) {
        Mtx_RotateX(cur, radians, true);
    } else if (y != 0.0f) {
        Mtx_RotateY(cur, radians, true);
    } else if (z != 0.0f) {
        Mtx_RotateZ(cur, radians, true);
    }
    // Arbitrary-axis rotation (x/y/z combined in one call) isn't used by
    // any call site today (grep shows only single-axis calls) - only the
    // three principal axes are handled.
}

void glScalef(GLfloat x, GLfloat y, GLfloat z)
{
    Mtx_Scale(currentMatrix(), x, y, z);
}

void glOrtho(GLdouble left, GLdouble right, GLdouble bottom, GLdouble top, GLdouble zNear, GLdouble zFar)
{
    Mtx_OrthoTilt(currentMatrix(), (float)left, (float)right, (float)bottom, (float)top, (float)zNear, (float)zFar, true);
}

void glFrustum(GLdouble left, GLdouble right, GLdouble bottom, GLdouble top, GLdouble zNear, GLdouble zFar)
{
    Mtx_PerspTilt(currentMatrix(),
        2.0f * atan2f((float)(top - bottom) * 0.5f, (float)zNear),
        (float)(right - left) / (float)(top - bottom),
        (float)zNear, (float)zFar, true);
    // Approximates glFrustum's general asymmetric-frustum shape as a
    // symmetric perspective (fov derived from top/bottom, aspect from
    // left/right) - exact for the symmetric case this engine actually
    // uses (glFrustum call sites always pass a mirrored left/right,
    // top/bottom pair), not a general replacement.
}

void glViewport(GLint x, GLint y, GLsizei width, GLsizei height)
{
    C3D_SetViewport((u32)x, (u32)y, (u32)width, (u32)height);
}

// MARK: - Clear

static float sClearR = 0, sClearG = 0, sClearB = 0, sClearA = 1;

void glClearColor(GLfloat r, GLfloat g, GLfloat b, GLfloat a)
{
    sClearR = r; sClearG = g; sClearB = b; sClearA = a;
}

void glClear(GLbitfield mask)
{
    // Actual render-target clearing on citro3d happens via
    // C3D_RenderTargetClear, driven by the render-target setup in
    // OGL_Support.swift's 3DS conformance (not written yet - see the
    // milestone checklist) - this just remembers the requested clear
    // color/mask so that call site can read it. Intentionally a no-op
    // here rather than guessing at a render target to clear.
    (void)mask;
}

void GLCompat_GetClearColor(float *r, float *g, float *b, float *a)
{
    *r = sClearR; *g = sClearG; *b = sClearB; *a = sClearA;
}

// MARK: - State

static bool sTexture2DEnabled;
static bool sBlendEnabled;
static bool sDepthTestEnabled = true;
static bool sAlphaTestEnabled;
static bool sCullFaceEnabled;
static GLenum sBlendSFactor = GL_ONE, sBlendDFactor = GL_ONE_MINUS_SRC_ALPHA;

static void applyTexEnv(void)
{
    C3D_TexEnv *env = C3D_GetTexEnv(0);
    C3D_TexEnvInit(env);
    if (sTexture2DEnabled) {
        C3D_TexEnvSrc(env, C3D_Both, GPU_TEXTURE0, GPU_PRIMARY_COLOR, 0);
        C3D_TexEnvFunc(env, C3D_Both, GPU_MODULATE);
    } else {
        C3D_TexEnvSrc(env, C3D_Both, GPU_PRIMARY_COLOR, 0, 0);
        C3D_TexEnvFunc(env, C3D_Both, GPU_REPLACE);
    }
}

static void applyBlend(void)
{
    if (sBlendEnabled) {
        C3D_AlphaBlend(GPU_BLEND_ADD, GPU_BLEND_ADD, GPU_SRC_ALPHA, GPU_ONE_MINUS_SRC_ALPHA, GPU_SRC_ALPHA, GPU_ONE_MINUS_SRC_ALPHA);
    } else {
        C3D_AlphaBlend(GPU_BLEND_ADD, GPU_BLEND_ADD, GPU_ONE, GPU_ZERO, GPU_ONE, GPU_ZERO);
    }
    (void)sBlendSFactor; (void)sBlendDFactor;
    // GL_SRC_ALPHA/GL_ONE_MINUS_SRC_ALPHA is the only blend factor pair any
    // call site actually uses (grep confirms), so this always configures
    // standard alpha blending rather than mapping every possible GL
    // factor combination onto GPU_BLENDFACTOR - a real general mapping is
    // future work if a call site ever needs a different pair.
}

void glEnable(GLenum cap)
{
    switch (cap) {
        case GL_TEXTURE_2D: sTexture2DEnabled = true; applyTexEnv(); break;
        case GL_BLEND: sBlendEnabled = true; applyBlend(); break;
        case GL_DEPTH_TEST: sDepthTestEnabled = true; C3D_DepthTest(true, GPU_GEQUAL, GPU_WRITE_ALL); break;
        case GL_CULL_FACE: sCullFaceEnabled = true; break;
        case GL_ALPHA_TEST: sAlphaTestEnabled = true; break;
        default: break; // GL_LIGHTING/GL_FOG/GL_NORMALIZE/etc: state-tracked
                         // nowhere yet - not fed into the shader (see file
                         // header comment's "Known gaps").
    }
}

void glDisable(GLenum cap)
{
    switch (cap) {
        case GL_TEXTURE_2D: sTexture2DEnabled = false; applyTexEnv(); break;
        case GL_BLEND: sBlendEnabled = false; applyBlend(); break;
        case GL_DEPTH_TEST: sDepthTestEnabled = false; C3D_DepthTest(false, GPU_GEQUAL, GPU_WRITE_ALL); break;
        case GL_CULL_FACE: sCullFaceEnabled = false; break;
        case GL_ALPHA_TEST: sAlphaTestEnabled = false; break;
        default: break;
    }
}

GLboolean glIsEnabled(GLenum cap)
{
    switch (cap) {
        case GL_TEXTURE_2D: return sTexture2DEnabled;
        case GL_BLEND: return sBlendEnabled;
        case GL_DEPTH_TEST: return sDepthTestEnabled;
        case GL_CULL_FACE: return sCullFaceEnabled;
        case GL_ALPHA_TEST: return sAlphaTestEnabled;
        default: return GL_FALSE;
    }
}

void glBlendFunc(GLenum sfactor, GLenum dfactor)
{
    sBlendSFactor = sfactor;
    sBlendDFactor = dfactor;
    if (sBlendEnabled) {
        applyBlend();
    }
}

void glAlphaFunc(GLenum func, GLfloat ref) { (void)func; (void)ref; }
void glCullFace(GLenum mode) { (void)mode; }
void glFrontFace(GLenum mode) { (void)mode; }
void glDepthMask(GLboolean flag) { C3D_DepthTest(sDepthTestEnabled, GPU_GEQUAL, flag ? GPU_WRITE_ALL : GPU_WRITE_COLOR); }
void glColorMask(GLboolean r, GLboolean g, GLboolean b, GLboolean a) { (void)r; (void)g; (void)b; (void)a; }
void glShadeModel(GLenum mode) { (void)mode; }
void glHint(GLenum target, GLenum mode) { (void)target; (void)mode; }
void glPolygonMode(GLenum face, GLenum mode) { (void)face; (void)mode; }
void glColorMaterial(GLenum face, GLenum mode) { (void)face; (void)mode; }
void glPushAttrib(GLbitfield mask) { (void)mask; }
void glPopAttrib(void) { }
GLenum glGetError(void) { return GL_NO_ERROR; }
void glGetBooleanv(GLenum pname, GLboolean *params) { (void)pname; if (params) *params = GL_FALSE; }
void glGetFloatv(GLenum pname, GLfloat *params) { (void)pname; if (params) params[0] = 0; }
void glGetIntegerv(GLenum pname, GLint *params)
{
    if (!params) return;
    switch (pname) {
        case GL_MAX_TEXTURE_SIZE: params[0] = 1024; break;
        default: params[0] = 0; break;
    }
}

void glLightfv(GLenum light, GLenum pname, const GLfloat *params) { (void)light; (void)pname; (void)params; }
void glLightModelfv(GLenum pname, const GLfloat *params) { (void)pname; (void)params; }
void glLightModeli(GLenum pname, GLint param) { (void)pname; (void)param; }
void glMaterialfv(GLenum face, GLenum pname, const GLfloat *params) { (void)face; (void)pname; (void)params; }
void glFogf(GLenum pname, GLfloat param) { (void)pname; (void)param; }
void glFogfv(GLenum pname, const GLfloat *params) { (void)pname; (void)params; }
void glFogi(GLenum pname, GLint param) { (void)pname; (void)param; }

// MARK: - Immediate mode

#define MAX_IMM_VERTICES 512

typedef struct {
    float x, y, z, w;
    float s, t;
    float r, g, b, a;
} GLCompatVertex;

static GLenum sBeginMode;
static GLCompatVertex sVertices[MAX_IMM_VERTICES];
static int sVertexCount;
static float sCurrentS, sCurrentT;
static float sCurrentR = 1, sCurrentG = 1, sCurrentB = 1, sCurrentA = 1;

void glBegin(GLenum mode)
{
    sBeginMode = mode;
    sVertexCount = 0;
}

void glTexCoord2f(GLfloat s, GLfloat t)
{
    sCurrentS = s;
    sCurrentT = t;
}

void glTexCoord2fv(const GLfloat *v)
{
    sCurrentS = v[0];
    sCurrentT = v[1];
}

void glColor4f(GLfloat r, GLfloat g, GLfloat b, GLfloat a)
{
    sCurrentR = r; sCurrentG = g; sCurrentB = b; sCurrentA = a;
}

void glColor4fv(const GLfloat *v)
{
    sCurrentR = v[0]; sCurrentG = v[1]; sCurrentB = v[2]; sCurrentA = v[3];
}

static void pushVertex(GLfloat x, GLfloat y, GLfloat z)
{
    if (sVertexCount >= MAX_IMM_VERTICES) {
        return; // silently drop - no call site today submits anywhere
                // close to this many vertices in one glBegin/glEnd pair
    }
    GLCompatVertex *v = &sVertices[sVertexCount++];
    v->x = x; v->y = y; v->z = z; v->w = 1.0f;
    v->s = sCurrentS; v->t = sCurrentT;
    v->r = sCurrentR; v->g = sCurrentG; v->b = sCurrentB; v->a = sCurrentA;
}

void glVertex2f(GLfloat x, GLfloat y)
{
    pushVertex(x, y, 0.0f);
}

void glVertex3f(GLfloat x, GLfloat y, GLfloat z)
{
    pushVertex(x, y, z);
}

void glVertex3fv(const GLfloat *v)
{
    pushVertex(v[0], v[1], v[2]);
}

static void sendVertex(const GLCompatVertex *v)
{
    C3D_ImmSendAttrib(v->x, v->y, v->z, v->w);
    C3D_ImmSendAttrib(v->s, v->t, 0.0f, 0.0f);
    C3D_ImmSendAttrib(v->r, v->g, v->b, v->a);
}

void glEnd(void)
{
    if (sVertexCount == 0) {
        return;
    }

    if (!sInited) {
        GLCompat_Init();
    }

    C3D_Mtx mvp;
    Mtx_Multiply(&mvp, &sProjection, &sModelView);
    C3D_FVUnifMtx4x4(GPU_VERTEX_SHADER, sUlocMvp, &mvp);

    switch (sBeginMode) {
        case GL_QUADS:
            // No native GL_QUADS primitive on PICA200 - but a single
            // convex quad IS exactly a GPU_TRIANGLE_FAN, so each group of
            // 4 vertices gets its own Imm draw (fanning across an entire
            // multi-quad batch in one draw would connect unrelated quads
            // together, which is why this loops per-quad instead of doing
            // one draw for the whole buffer).
            for (int i = 0; i + 4 <= sVertexCount; i += 4) {
                C3D_ImmDrawBegin(GPU_TRIANGLE_FAN);
                for (int j = 0; j < 4; j++) {
                    sendVertex(&sVertices[i + j]);
                }
                C3D_ImmDrawEnd();
            }
            break;

        case GL_TRIANGLES:
            C3D_ImmDrawBegin(GPU_TRIANGLES);
            for (int i = 0; i < sVertexCount; i++) {
                sendVertex(&sVertices[i]);
            }
            C3D_ImmDrawEnd();
            break;

        case GL_LINES:
        case GL_LINE_LOOP:
        case GL_LINE_STRIP:
            // PICA200's primitive assembler has no line primitive at all
            // (GPU_Primitive_t is triangles/strip/fan/geometry only) -
            // silently skipped. Not needed for the main-menu milestone;
            // would need thin-quad emulation if a future screen relies on
            // wireframe/line rendering.
            break;

        default:
            break;
    }

    sVertexCount = 0;
}

// MARK: - Textures

#define MAX_TEXTURES 64

static C3D_Tex sTextures[MAX_TEXTURES];
static bool sTextureUsed[MAX_TEXTURES];
static GLuint sBoundTexture;

void glGenTextures(GLsizei n, GLuint *textures)
{
    int found = 0;
    for (int i = 1; i < MAX_TEXTURES && found < n; i++) {
        if (!sTextureUsed[i]) {
            sTextureUsed[i] = true;
            textures[found++] = (GLuint)i;
        }
    }
}

void glDeleteTextures(GLsizei n, const GLuint *textures)
{
    for (int i = 0; i < n; i++) {
        GLuint name = textures[i];
        if (name > 0 && name < MAX_TEXTURES && sTextureUsed[name]) {
            C3D_TexDelete(&sTextures[name]);
            sTextureUsed[name] = false;
        }
    }
}

void glBindTexture(GLenum target, GLuint texture)
{
    (void)target;
    sBoundTexture = texture;
    if (texture > 0 && texture < MAX_TEXTURES && sTextureUsed[texture]) {
        C3D_TexBind(0, &sTextures[texture]);
    }
}

void glTexImage2D(GLenum target, GLint level, GLint internalformat, GLsizei width, GLsizei height, GLint border, GLenum format, GLenum type, const void *pixels)
{
    (void)target; (void)level; (void)internalformat; (void)border; (void)format; (void)type;

    if (sBoundTexture == 0 || sBoundTexture >= MAX_TEXTURES) {
        return;
    }

    C3D_Tex *tex = &sTextures[sBoundTexture];
    if (!C3D_TexInit(tex, (u16)width, (u16)height, GPU_RGBA8)) {
        return;
    }
    if (pixels) {
        C3D_TexUpload(tex, pixels);
    }
    C3D_TexSetFilter(tex, GPU_LINEAR, GPU_LINEAR);
    C3D_TexSetWrap(tex, GPU_REPEAT, GPU_REPEAT);
    // Real desktop glTexImage2D accepts arbitrary GL_RGBA/GL_BGRA/
    // GL_UNSIGNED_BYTE/etc. source formats and converts on upload; this
    // always treats `pixels` as already being GPU_RGBA8-laid-out bytes.
    // OGL_TextureMap_LoadImageFile's actual pixel format (from stb_image)
    // needs to match, or be converted before calling here - not yet
    // verified end to end (see milestone step 2, texture loading).
}

void glTexSubImage2D(GLenum target, GLint level, GLint xoffset, GLint yoffset, GLsizei width, GLsizei height, GLenum format, GLenum type, const void *pixels)
{
    (void)target; (void)level; (void)xoffset; (void)yoffset; (void)width; (void)height; (void)format; (void)type; (void)pixels;
    // Not used by any call site today (grep confirms) - only full-image
    // glTexImage2D uploads happen in this engine.
}

void glTexParameteri(GLenum target, GLenum pname, GLint param)
{
    (void)target;
    if (sBoundTexture == 0 || sBoundTexture >= MAX_TEXTURES) {
        return;
    }
    C3D_Tex *tex = &sTextures[sBoundTexture];
    GPU_TEXTURE_FILTER_PARAM filter = (param == GL_LINEAR) ? GPU_LINEAR : GPU_NEAREST;
    GPU_TEXTURE_WRAP_PARAM wrap = (param == GL_CLAMP_TO_EDGE) ? GPU_CLAMP_TO_EDGE : GPU_REPEAT;
    switch (pname) {
        case GL_TEXTURE_MAG_FILTER: C3D_TexSetFilter(tex, filter, tex->maxLevel > 0 ? GPU_LINEAR : filter); break;
        case GL_TEXTURE_MIN_FILTER: C3D_TexSetFilter(tex, filter, filter); break;
        case GL_TEXTURE_WRAP_S: C3D_TexSetWrap(tex, wrap, GPU_REPEAT); break;
        case GL_TEXTURE_WRAP_T: C3D_TexSetWrap(tex, GPU_REPEAT, wrap); break;
        default: break;
    }
}

void glTexParameterf(GLenum target, GLenum pname, GLfloat param)
{
    glTexParameteri(target, pname, (GLint)param);
}

void glTexEnvi(GLenum target, GLenum pname, GLint param)
{
    (void)target; (void)pname; (void)param;
    // GL_TEXTURE_ENV_MODE (GL_MODULATE/GL_REPLACE/etc.) - applyTexEnv()
    // above already always configures GPU_MODULATE whenever texturing is
    // enabled, which matches every call site's actual usage (grep shows
    // this engine only ever uses GL_MODULATE) - a real per-mode mapping
    // is future work if that ever changes.
}

void glTexGeni(GLenum target, GLenum pname, GLint param) { (void)target; (void)pname; (void)param; }
void glActiveTexture(GLenum texture) { (void)texture; }
void glClientActiveTexture(GLenum texture) { (void)texture; }

// MARK: - Vertex arrays (not implemented - see SDL_opengl.h's header
// comment; no call site reaches these without skeleton/terrain rendering,
// out of scope for the main-menu milestone)

void glEnableClientState(GLenum array) { (void)array; }
void glDisableClientState(GLenum array) { (void)array; }
void glVertexPointer(GLint size, GLenum type, GLsizei stride, const void *pointer) { (void)size; (void)type; (void)stride; (void)pointer; }
void glNormalPointer(GLenum type, GLsizei stride, const void *pointer) { (void)type; (void)stride; (void)pointer; }
void glTexCoordPointer(GLint size, GLenum type, GLsizei stride, const void *pointer) { (void)size; (void)type; (void)stride; (void)pointer; }
void glColorPointer(GLint size, GLenum type, GLsizei stride, const void *pointer) { (void)size; (void)type; (void)stride; (void)pointer; }
void glDrawElements(GLenum mode, GLsizei count, GLenum type, const void *indices) { (void)mode; (void)count; (void)type; (void)indices; }
void glDrawBuffer(GLenum buf) { (void)buf; }
