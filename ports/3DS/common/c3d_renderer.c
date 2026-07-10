// c3d_renderer.c - see c3d_renderer.h.
//
// A minimal fixed-function-style renderer over citro3d, sized exactly to
// the RenderBackend protocol surface the game actually uses. Standalone
// translation unit: includes <3ds.h>/<citro3d.h> freely because nothing
// from the game's headers appears here (the Handle typedef collision that
// keeps those headers out of game-visible code - see game_3ds.h).
//
// Key semantics carried over from picaGL (verified working there) before
// it was deleted:
//  - GL projection matrices need a fix-up for the PICA: depth range
//    [-1,1] -> [-1,0] (z' = 0.5z - 0.5w) then a 90-degree screen rotation
//    (x' = y, y' = -x) because the 3DS framebuffer is physically portrait
//    240x400. (picaGL: matrix4x4_fix_projection.)
//  - Textures are Morton/8x8-block tiled on the CPU with a vertical row
//    flip (GL's bottom-up origin -> PICA's layout), then the GPU samples
//    them natively. (picaGL: _textureTile.)
//  - GL_BACK culling with CCW front faces maps to GPU_CULL_BACK_CCW under
//    that rotation (det(R) = +1, winding preserved).
//
// Deliberate phase-A gaps (parity with what picaGL actually delivered, so
// nothing regresses visually; all tracked for phase B):
//  - No lighting (picaGL stubbed it): normals are ignored.
//  - No fog (same).
//  - No sphere-map texgen (envmapped models render with their base UVs).
//  - Line primitives dropped (PICA has none; nothing on 3DS draws them).
//  - setViewport maps exactly for the full screen; split-screen panes
//    would need the rotated-rect general case.
//
// Texture format: GPU_RGBA4 for now - same as picaGL shipped - because the
// full texture set at RGBA8 (~30MB: font atlases, sprites, ~300 downsampled
// 128x128 supertiles, model textures) doesn't fit the linear heap's slice
// of the 3DS's fixed 121MiB pool alongside the regular heap's needs
// (boot_shim.c). Flip kTexFormat to GPU_RGBA8 selectively (or per-texture)
// once there's measured headroom - unlike picaGL, that's a one-line change
// we own.

#include <3ds.h>
#include <citro3d.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <stdarg.h>
#include <math.h>
#include "c3d_renderer.h"

#include "c3dr_vshader_shbin.h"

// SD-card log sink (console_shim.c - always compiled, even without DEBUGLOG).
extern void DebugLogFile3DS(const char *message);

static void c3drLog(const char *fmt, ...)
{
	char buf[128];
	va_list args;
	va_start(args, fmt);
	vsnprintf(buf, sizeof buf, fmt, args);
	va_end(args);
	DebugLogFile3DS(buf);
}

// ---------------------------------------------------------------------------
// State

#define MATRIX_STACK_DEPTH 16
#define MAX_TEXTURES 2048
#define RING_BYTES (2 * 1024 * 1024) // per-frame vertex/index staging (double-buffered)

static const GPU_TEXCOLOR kTexFormat = GPU_RGBA4; // see file header
#define TEX_BPP (kTexFormat == GPU_RGBA8 ? 4 : 2)

typedef struct {
	C3D_Tex tex;
	bool used;
	bool clampU, clampV;
} TexSlot;

static struct {
	bool initialized;
	bool inFrame;
	C3D_RenderTarget *target;

	DVLB_s *vshaderDVLB;
	shaderProgram_s program;
	int locMVP, locTexMtx;

	// GL-convention column-major matrix stacks
	float stacks[3][MATRIX_STACK_DEPTH][16];
	int stackTop[3];
	int matrixMode; // C3DR_MATRIX_*
	bool matricesDirty;

	// raster state
	float currentColor[4];
	bool blendEnabled;
	int blendSrc, blendDst;
	bool cullEnabled;
	bool depthTest;
	bool depthWrite;
	bool colorMask[4];
	u32 clearColor; // 0xRRGGBBAA
	int viewport[4];
	bool rasterDirty;

	// texturing
	TexSlot textures[MAX_TEXTURES];
	int activeUnit;
	unsigned bound[2];
	bool texEnabled[2];
	int texEnv1; // C3DR_TEXENV_* for unit 1
	bool texDirty;

	// staging ring (linear memory), double-buffered across frames
	u8 *ring[2];
	int ringIndex;
	size_t ringOffset;

	// diagnostics
	int liveTextures;
	u32 liveTexBytes;
	u32 presentCount;

	// immediate mode
	int immPrim;
	int immCount;
	float immUV[2];
	struct { float pos[3]; float clr[4]; float uv[2]; } immVerts[1024];
} R;

// ---------------------------------------------------------------------------
// Column-major 4x4 helpers (GL layout: m[col*4 + row])

static const float kIdentity[16] = {1,0,0,0, 0,1,0,0, 0,0,1,0, 0,0,0,1};

static float *curMatrix(void)
{
	return R.stacks[R.matrixMode][R.stackTop[R.matrixMode]];
}

static void mulCM(float *out, const float *a, const float *b) // out = a * b
{
	float tmp[16];
	for (int c = 0; c < 4; c++)
		for (int r = 0; r < 4; r++)
			tmp[c*4+r] = a[0*4+r]*b[c*4+0] + a[1*4+r]*b[c*4+1]
			           + a[2*4+r]*b[c*4+2] + a[3*4+r]*b[c*4+3];
	memcpy(out, tmp, sizeof tmp);
}

// GL depth-range + screen-rotation correction (see file header).
static void fixProjection(float *p /* in/out, column-major */)
{
	static const float D[16] = { // z' = 0.5z - 0.5w
		1,0,0,0,
		0,1,0,0,
		0,0,0.5f,0,
		0,0,-0.5f,1,
	};
	static const float Rm[16] = { // x' = y, y' = -x
		0,-1,0,0,
		1,0,0,0,
		0,0,1,0,
		0,0,0,1,
	};
	float tmp[16];
	mulCM(tmp, D, p);
	mulCM(p, Rm, tmp);
}

// ---------------------------------------------------------------------------
// Frame + dirty-state flush

static void applyViewport(void)
{
	// GL viewport (origin bottom-left of the 400x240 screen) -> rotated
	// 240x400 framebuffer. Exact for the full screen; see header for panes.
	C3D_SetViewport(R.viewport[1], R.viewport[0], R.viewport[3], R.viewport[2]);

#ifdef DEBUGLOG
	static int lastVp[4] = {-1, -1, -1, -1};
	if (memcmp(lastVp, R.viewport, sizeof lastVp) != 0)
	{
		memcpy(lastVp, R.viewport, sizeof lastVp);
		c3drLog("c3dr: viewport %d %d %d %d", R.viewport[0], R.viewport[1], R.viewport[2], R.viewport[3]);
	}
#endif
}

static void ensureFrame(void)
{
	if (R.inFrame)
		return;

	C3D_FrameBegin(C3D_FRAME_SYNCDRAW);
	C3D_FrameDrawOn(R.target);
	R.inFrame = true;

	R.ringIndex ^= 1;
	R.ringOffset = 0;

	applyViewport();
	R.rasterDirty = true;
	R.texDirty = true;
	R.matricesDirty = true;
}

static void flushMatrices(void)
{
	if (!R.matricesDirty)
		return;
	R.matricesDirty = false;

	float proj[16];
	memcpy(proj, R.stacks[C3DR_MATRIX_PROJECTION][R.stackTop[C3DR_MATRIX_PROJECTION]], sizeof proj);
	fixProjection(proj);

	float mvp[16];
	mulCM(mvp, proj, R.stacks[C3DR_MATRIX_MODELVIEW][R.stackTop[C3DR_MATRIX_MODELVIEW]]);

	// shader does dp4(row_i, pos): uniform i = row i of MVP
	for (int i = 0; i < 4; i++)
		C3D_FVUnifSet(GPU_VERTEX_SHADER, R.locMVP + i, mvp[0+i], mvp[4+i], mvp[8+i], mvp[12+i]);

	const float *t = R.stacks[C3DR_MATRIX_TEXTURE][R.stackTop[C3DR_MATRIX_TEXTURE]];
	for (int i = 0; i < 2; i++)
		C3D_FVUnifSet(GPU_VERTEX_SHADER, R.locTexMtx + i, t[0+i], t[4+i], t[8+i], t[12+i]);
}

static void flushRaster(void)
{
	if (!R.rasterDirty)
		return;
	R.rasterDirty = false;

	if (R.blendEnabled)
	{
		static const GPU_BLENDFACTOR map[3] = {GPU_ONE, GPU_SRC_ALPHA, GPU_ONE_MINUS_SRC_ALPHA};
		GPU_BLENDFACTOR s = map[R.blendSrc], d = map[R.blendDst];
		C3D_AlphaBlend(GPU_BLEND_ADD, GPU_BLEND_ADD, s, d, s, d);
	}
	else
		C3D_ColorLogicOp(GPU_LOGICOP_COPY);

	C3D_CullFace(R.cullEnabled ? GPU_CULL_BACK_CCW : GPU_CULL_NONE);

	int mask = 0;
	if (R.colorMask[0]) mask |= GPU_WRITE_RED;
	if (R.colorMask[1]) mask |= GPU_WRITE_GREEN;
	if (R.colorMask[2]) mask |= GPU_WRITE_BLUE;
	if (R.colorMask[3]) mask |= GPU_WRITE_ALPHA;
	if (R.depthWrite)   mask |= GPU_WRITE_DEPTH;
	// GPU_GREATER, not GL's LESS: fixProjection maps GL depth so NEAR lands
	// at 1 and FAR at 0 in the PICA depth buffer (z' = 0.5z - 0.5w over
	// [-1,0], negated into the buffer), and clears write 0 - the standard
	// citro3d convention. A closer fragment therefore has a LARGER buffer
	// value. With GPU_LESS nothing ever passed against the cleared buffer:
	// gameplay's depth-tested world rendered as pure black while
	// depth-test-off draws (HUD, the level-intro scene's objects) showed
	// fine, which is exactly how this bug presented.
	C3D_DepthTest(R.depthTest, GPU_GREATER, (GPU_WRITEMASK)mask);
}

static void flushTexEnv(void)
{
	if (!R.texDirty)
		return;
	R.texDirty = false;

	bool unit0 = R.texEnabled[0] && R.bound[0] != 0;
	bool unit1 = R.texEnabled[1] && R.bound[1] != 0;

	C3D_TexEnv *env0 = C3D_GetTexEnv(0);
	C3D_TexEnvInit(env0);
	if (unit0)
	{
		C3D_TexBind(0, &R.textures[R.bound[0] - 1].tex);
		C3D_TexEnvSrc(env0, C3D_Both, GPU_TEXTURE0, GPU_PRIMARY_COLOR, GPU_PRIMARY_COLOR);
		C3D_TexEnvFunc(env0, C3D_Both, GPU_MODULATE);
	}
	else
	{
		C3D_TexEnvSrc(env0, C3D_Both, GPU_PRIMARY_COLOR, GPU_PRIMARY_COLOR, GPU_PRIMARY_COLOR);
		C3D_TexEnvFunc(env0, C3D_Both, GPU_REPLACE);
	}

	C3D_TexEnv *env1 = C3D_GetTexEnv(1);
	C3D_TexEnvInit(env1);
	if (unit1)
	{
		C3D_TexBind(1, &R.textures[R.bound[1] - 1].tex);
		C3D_TexEnvSrc(env1, C3D_Both, GPU_PREVIOUS, GPU_TEXTURE1, GPU_PREVIOUS);
		switch (R.texEnv1)
		{
			case C3DR_TEXENV_COMBINE_ADD:
				C3D_TexEnvFunc(env1, C3D_RGB, GPU_ADD);
				C3D_TexEnvFunc(env1, C3D_Alpha, GPU_MODULATE);
				break;
			case C3DR_TEXENV_COMBINE_ADD_ALPHA:
				C3D_TexEnvFunc(env1, C3D_Both, GPU_ADD);
				break;
			default:
				C3D_TexEnvFunc(env1, C3D_Both, GPU_MODULATE);
				break;
		}
	}
	else
	{
		C3D_TexEnvSrc(env1, C3D_Both, GPU_PREVIOUS, GPU_PREVIOUS, GPU_PREVIOUS);
		C3D_TexEnvFunc(env1, C3D_Both, GPU_REPLACE);
	}
}

static void flushAll(void)
{
	ensureFrame();
	flushMatrices();
	flushRaster();
	flushTexEnv();
}

// ---------------------------------------------------------------------------
// Staging ring

static void *ringAlloc(size_t bytes, size_t align)
{
	size_t off = (R.ringOffset + (align - 1)) & ~(align - 1);
	if (off + bytes > RING_BYTES)
	{
		c3drLog("c3dr: staging ring overflow (%u + %u)", (unsigned)off, (unsigned)bytes);
		return NULL;
	}
	R.ringOffset = off + bytes;
	return R.ring[R.ringIndex] + off;
}

// ---------------------------------------------------------------------------
// Public API: lifecycle

void C3DR_Init(void)
{
	if (R.initialized)
		return;

	memset(&R, 0, sizeof R);

	C3D_Init(C3D_DEFAULT_CMDBUF_SIZE * 2);

	R.target = C3D_RenderTargetCreate(240, 400, GPU_RB_RGBA8, GPU_RB_DEPTH24_STENCIL8);

	// Match the transfer's output format to whatever the gfx framebuffer
	// actually is (SDL's n3ds video driver owns gfxInit and its format).
	GSPGPU_FramebufferFormat fbFmt = gfxGetScreenFormat(GFX_TOP);
	GX_TRANSFER_FORMAT outFmt;
	switch (fbFmt)
	{
		case GSP_RGBA8_OES:   outFmt = GX_TRANSFER_FMT_RGBA8; break;
		case GSP_RGB565_OES:  outFmt = GX_TRANSFER_FMT_RGB565; break;
		case GSP_RGB5_A1_OES: outFmt = GX_TRANSFER_FMT_RGB5A1; break;
		case GSP_RGBA4_OES:   outFmt = GX_TRANSFER_FMT_RGBA4; break;
		case GSP_BGR8_OES:
		default:              outFmt = GX_TRANSFER_FMT_RGB8; break;
	}
	C3D_RenderTargetSetOutput(R.target, GFX_TOP, GFX_LEFT,
		GX_TRANSFER_IN_FORMAT(GX_TRANSFER_FMT_RGBA8) | GX_TRANSFER_OUT_FORMAT(outFmt));

	// Shader
	R.vshaderDVLB = DVLB_ParseFile((u32*)c3dr_vshader_shbin, c3dr_vshader_shbin_size);
	shaderProgramInit(&R.program);
	shaderProgramSetVsh(&R.program, &R.vshaderDVLB->DVLE[0]);
	C3D_BindProgram(&R.program);
	R.locMVP    = shaderInstanceGetUniformLocation(R.program.vertexShader, "mvp");
	R.locTexMtx = shaderInstanceGetUniformLocation(R.program.vertexShader, "texmtx");

	// TEV stages 2-5: passthrough, set once
	for (int i = 2; i < 6; i++)
	{
		C3D_TexEnv *env = C3D_GetTexEnv(i);
		C3D_TexEnvInit(env);
		C3D_TexEnvSrc(env, C3D_Both, GPU_PREVIOUS, GPU_PREVIOUS, GPU_PREVIOUS);
		C3D_TexEnvFunc(env, C3D_Both, GPU_REPLACE);
	}

	// GL-default state
	for (int m = 0; m < 3; m++)
		memcpy(R.stacks[m][0], kIdentity, sizeof kIdentity);
	R.currentColor[0] = R.currentColor[1] = R.currentColor[2] = R.currentColor[3] = 1;
	R.depthWrite = true;
	R.colorMask[0] = R.colorMask[1] = R.colorMask[2] = R.colorMask[3] = true;
	R.viewport[2] = 400;
	R.viewport[3] = 240;
	R.blendSrc = C3DR_BLEND_SRC_ALPHA;
	R.blendDst = C3DR_BLEND_ONE_MINUS_SRC_ALPHA;
	C3D_AlphaTest(true, GPU_NOTEQUAL, 0);

	R.ring[0] = linearAlloc(RING_BYTES);
	R.ring[1] = linearAlloc(RING_BYTES);

	R.initialized = true;
}

void C3DR_Shutdown(void)
{
	if (!R.initialized)
		return;
	if (R.inFrame)
		C3D_FrameEnd(0);
	linearFree(R.ring[0]);
	linearFree(R.ring[1]);
	shaderProgramFree(&R.program);
	DVLB_Free(R.vshaderDVLB);
	C3D_RenderTargetDelete(R.target);
	C3D_Fini();
	R.initialized = false;
}

void C3DR_Present(void)
{
	ensureFrame(); // nothing drew this frame - still flip so fades keep pumping
	C3D_FrameEnd(0);
	R.inFrame = false;

#ifdef DEBUGLOG
	// Memory-trend heartbeat: a slow texture/linear leak across scene
	// teardowns only shows up as a trend, so log one every ~30s.
	if (++R.presentCount % 1800 == 0)
		c3drLog("c3dr: mem trend: tex=%d texKB=%u linearFree=%u vramFree=%u",
			R.liveTextures, (unsigned)(R.liveTexBytes / 1024),
			(unsigned)linearSpaceFree(), (unsigned)vramSpaceFree());
#endif
}

// ---------------------------------------------------------------------------
// Public API: frame state

void C3DR_SetViewport(int x, int y, int w, int h)
{
	R.viewport[0] = x; R.viewport[1] = y; R.viewport[2] = w; R.viewport[3] = h;
	if (R.inFrame)
		applyViewport();
}

void C3DR_SetClearColor(float r, float g, float b)
{
	u32 ri = (u32)(r * 255.0f), gi = (u32)(g * 255.0f), bi = (u32)(b * 255.0f);
	R.clearColor = (ri << 24) | (gi << 16) | (bi << 8) | 0xFF;
}

void C3DR_ClearColorAndDepth(void)
{
	ensureFrame();
	C3D_RenderTargetClear(R.target, C3D_CLEAR_ALL, R.clearColor, 0);
	C3D_FrameDrawOn(R.target);
	applyViewport();
}

void C3DR_ClearDepthOnly(void)
{
	ensureFrame();
	C3D_RenderTargetClear(R.target, C3D_CLEAR_DEPTH, 0, 0);
	C3D_FrameDrawOn(R.target);
	applyViewport();
}

// ---------------------------------------------------------------------------
// Public API: raster state

void C3DR_SetBlendEnabled(int enabled) { R.blendEnabled = enabled; R.rasterDirty = true; }
void C3DR_SetBlendFunc(int s, int d)   { R.blendSrc = s; R.blendDst = d; R.rasterDirty = true; }
void C3DR_SetCullEnabled(int enabled)  { R.cullEnabled = enabled; R.rasterDirty = true; }
void C3DR_SetDepthTestEnabled(int e)   { R.depthTest = e; R.rasterDirty = true; }
void C3DR_SetDepthWrite(int e)         { R.depthWrite = e; R.rasterDirty = true; }

void C3DR_SetColorMask(int r, int g, int b, int a)
{
	R.colorMask[0] = r; R.colorMask[1] = g; R.colorMask[2] = b; R.colorMask[3] = a;
	R.rasterDirty = true;
}

void C3DR_SetAlphaTest(int enabled, int trimLowAlpha)
{
	// Immediate (not dirty-flagged): the only two configs the game uses.
	ensureFrame();
	if (!enabled)
		C3D_AlphaTest(false, GPU_ALWAYS, 0);
	else if (trimLowAlpha)
		C3D_AlphaTest(true, GPU_GREATER, 153); // alpha > 0.6
	else
		C3D_AlphaTest(true, GPU_NOTEQUAL, 0);
}

void C3DR_SetColor4f(float r, float g, float b, float a)
{
	R.currentColor[0] = r; R.currentColor[1] = g; R.currentColor[2] = b; R.currentColor[3] = a;
}

// ---------------------------------------------------------------------------
// Public API: matrices

void C3DR_MatrixMode(int mode) { R.matrixMode = mode; }

void C3DR_PushMatrix(void)
{
	int m = R.matrixMode;
	if (R.stackTop[m] < MATRIX_STACK_DEPTH - 1)
	{
		memcpy(R.stacks[m][R.stackTop[m] + 1], R.stacks[m][R.stackTop[m]], sizeof(float) * 16);
		R.stackTop[m]++;
	}
}

void C3DR_PopMatrix(void)
{
	if (R.stackTop[R.matrixMode] > 0)
		R.stackTop[R.matrixMode]--;
	R.matricesDirty = true;
}

void C3DR_LoadIdentity(void)
{
	memcpy(curMatrix(), kIdentity, sizeof kIdentity);
	R.matricesDirty = true;
}

void C3DR_LoadMatrix(const float *m)
{
	memcpy(curMatrix(), m, sizeof(float) * 16);
	R.matricesDirty = true;
}

void C3DR_MultMatrix(const float *m)
{
	mulCM(curMatrix(), curMatrix(), m);
	R.matricesDirty = true;
}

void C3DR_GetMatrix(int mode, float *outM)
{
	memcpy(outM, R.stacks[mode][R.stackTop[mode]], sizeof(float) * 16);
}

void C3DR_Frustum(float l, float r, float b, float t, float n, float f)
{
	float m[16] = {0};
	m[0]  = 2*n/(r-l);
	m[5]  = 2*n/(t-b);
	m[8]  = (r+l)/(r-l);
	m[9]  = (t+b)/(t-b);
	m[10] = -(f+n)/(f-n);
	m[11] = -1;
	m[14] = -(2*f*n)/(f-n);
	C3DR_MultMatrix(m);
}

void C3DR_Ortho(float l, float r, float b, float t, float n, float f)
{
	float m[16] = {0};
	m[0]  = 2/(r-l);
	m[5]  = 2/(t-b);
	m[10] = -2/(f-n);
	m[12] = -(r+l)/(r-l);
	m[13] = -(t+b)/(t-b);
	m[14] = -(f+n)/(f-n);
	m[15] = 1;
	C3DR_MultMatrix(m);
}

void C3DR_Translate(float x, float y, float z)
{
	float m[16];
	memcpy(m, kIdentity, sizeof m);
	m[12] = x; m[13] = y; m[14] = z;
	C3DR_MultMatrix(m);
}

void C3DR_Scale(float x, float y, float z)
{
	float m[16] = {0};
	m[0] = x; m[5] = y; m[10] = z; m[15] = 1;
	C3DR_MultMatrix(m);
}

void C3DR_Rotate(float angleDegrees, float x, float y, float z)
{
	float len = sqrtf(x*x + y*y + z*z);
	if (len == 0)
		return;
	x /= len; y /= len; z /= len;

	float rad = angleDegrees * (float)M_PI / 180.0f;
	float c = cosf(rad), s = sinf(rad), ic = 1.0f - c;

	float m[16] = {0};
	m[0] = x*x*ic + c;   m[1] = y*x*ic + z*s; m[2]  = x*z*ic - y*s;
	m[4] = x*y*ic - z*s; m[5] = y*y*ic + c;   m[6]  = y*z*ic + x*s;
	m[8] = x*z*ic + y*s; m[9] = y*z*ic - x*s; m[10] = z*z*ic + c;
	m[15] = 1;
	C3DR_MultMatrix(m);
}

// ---------------------------------------------------------------------------
// Public API: textures

// Morton interleave within an 8x8 tile (borrowed from Citra via picaGL).
static inline u32 mortonInterleave(u32 x, u32 y)
{
	static const u32 xlut[] = {0x00, 0x01, 0x04, 0x05, 0x10, 0x11, 0x14, 0x15};
	static const u32 ylut[] = {0x00, 0x02, 0x08, 0x0a, 0x20, 0x22, 0x28, 0x2a};
	return xlut[x % 8] + ylut[y % 8];
}

static inline u32 mortonOffset(u32 x, u32 y)
{
	return mortonInterleave(x, y) + (x & ~7u) * 8;
}

// 4-bytes-per-pixel rows (first row = GL v0/bottom) -> tiled kTexFormat
// texels, with the vertical flip picaGL did. bgra selects the input byte
// order (BGRA for the anaglyph update path, RGBA for everything else).
// GPU_RGBA8 texel: u32 = R<<24|G<<16|B<<8|A (bytes ABGR in memory).
// GPU_RGBA4 texel: u16 = R<<12|G<<8|B<<4|A, 4 bits per channel.
static void tilePixels(void *out, const u8 *in, int width, int height, bool bgra)
{
	int ri = bgra ? 2 : 0;
	int bi = bgra ? 0 : 2;

	for (int y = 0; y < height; y++)
	{
		u32 outputY = height - 1 - y;
		u32 coarseY = outputY & ~7u;
		const u8 *row = in + (size_t)y * width * 4;

		for (int x = 0; x < width; x++)
		{
			u32 offset = mortonOffset(x, outputY) + coarseY * width;
			const u8 *p = row + x * 4;
			if (kTexFormat == GPU_RGBA8)
				((u32 *)out)[offset] = ((u32)p[ri] << 24) | ((u32)p[1] << 16) | ((u32)p[bi] << 8) | p[3];
			else
				((u16 *)out)[offset] = (u16)(((p[ri] >> 4) << 12) | ((p[1] >> 4) << 8) | ((p[bi] >> 4) << 4) | (p[3] >> 4));
		}
	}
}

// Tile + upload into a texture, handling VRAM destinations (which the CPU
// can't write): tile into a temporary linear buffer, then GX-copy it over.
static void uploadPixels(TexSlot *t, const void *pixels, int width, int height, bool bgra)
{
	u32 size = (u32)width * height * TEX_BPP;

	void *dst = t->tex.data;
	bool inVRAM = ((u32)dst >= OS_VRAM_VADDR && (u32)dst < OS_VRAM_VADDR + OS_VRAM_SIZE);
	if (inVRAM)
	{
		dst = linearAlloc(size);
		if (!dst)
		{
			c3drLog("c3dr: no staging memory for %dx%d VRAM upload", width, height);
			return;
		}
	}

	tilePixels(dst, (const u8 *)pixels, width, height, bgra);
	GSPGPU_FlushDataCache(dst, size);

	if (inVRAM)
	{
		C3D_SyncTextureCopy((u32 *)dst, 0, (u32 *)t->tex.data, 0, size, 8);
		linearFree(dst);
	}
}

// Box-downsample an RGBA8 buffer by 2x (malloc'd result; caller frees).
static u8 *downsample2xRGBA8(const u8 *src, int w, int h)
{
	int nw = w / 2, nh = h / 2;
	u8 *dst = malloc((size_t)nw * nh * 4);
	if (!dst)
		return NULL;
	for (int y = 0; y < nh; y++)
	{
		const u8 *r0 = src + (size_t)(y * 2) * w * 4;
		const u8 *r1 = r0 + (size_t)w * 4;
		u8 *out = dst + (size_t)y * nw * 4;
		for (int x = 0; x < nw; x++)
		{
			const u8 *a = r0 + (size_t)x * 8, *b = a + 4;
			const u8 *c = r1 + (size_t)x * 8, *d = c + 4;
			for (int ch = 0; ch < 4; ch++)
				out[x * 4 + ch] = (u8)((a[ch] + b[ch] + c[ch] + d[ch] + 2) >> 2);
		}
	}
	return dst;
}

unsigned C3DR_CreateTexture(int width, int height, const void *rgba8Pixels)
{
	// Downgrade oversized textures: on a 400x240 screen anything above
	// 512px is oversampled, and the big offenders (font atlases, 512x512
	// sprite/model atlases) each cost 0.5-2 MB of linear memory even at
	// RGBA4 - a big level (650+ unique supertiles) doesn't fit otherwise.
	// SQUARE textures shrink down to 256 (atlases - their glyphs/cells are
	// drawn small on this screen); non-square art (512x256 story slides,
	// shown full-screen) only shrinks above 512. Supertiles (128) pass
	// untouched.
	u8 *shrunk = NULL;
	int cap = (width == height) ? 256 : 512;
	while (width > cap || height > cap)
	{
		u8 *next = downsample2xRGBA8(shrunk ? shrunk : (const u8 *)rgba8Pixels, width, height);
		if (!next)
			break;
		free(shrunk);
		shrunk = next;
		width /= 2;
		height /= 2;
	}
	if (shrunk)
		rgba8Pixels = shrunk;

	int slot = -1;
	for (int i = 0; i < MAX_TEXTURES; i++)
	{
		if (!R.textures[i].used)
		{
			slot = i;
			break;
		}
	}
	if (slot < 0)
	{
		c3drLog("c3dr: out of texture slots");
		free(shrunk);
		return 0;
	}

	TexSlot *t = &R.textures[slot];
	memset(&t->tex, 0, sizeof t->tex);
	// VRAM first (the ~3.5MB not used by the render target is free real
	// estate the linear heap doesn't have to carry - same trick picaGL
	// used), falling back to linear when VRAM fills up.
	if (!C3D_TexInitVRAM(&t->tex, (u16)width, (u16)height, kTexFormat)
		&& !C3D_TexInit(&t->tex, (u16)width, (u16)height, kTexFormat))
	{
		c3drLog("c3dr: C3D_TexInit %dx%d failed (linear free=%u vram free=%u)",
			width, height, (unsigned)linearSpaceFree(), (unsigned)vramSpaceFree());
		free(shrunk);
		return 0;
	}

	uploadPixels(t, rgba8Pixels, width, height, false);
	free(shrunk);

	C3D_TexSetFilter(&t->tex, GPU_LINEAR, GPU_LINEAR);
	C3D_TexSetWrap(&t->tex, GPU_REPEAT, GPU_REPEAT);
	t->clampU = t->clampV = false;
	t->used = true;
	R.liveTextures++;
	R.liveTexBytes += (u32)width * height * TEX_BPP;

	return (unsigned)slot + 1;
}

void C3DR_UpdateTextureBGRA(unsigned name, int width, int height, const void *bgraPixels)
{
	if (name == 0 || name > MAX_TEXTURES || !R.textures[name - 1].used)
		return;
	TexSlot *t = &R.textures[name - 1];
	uploadPixels(t, bgraPixels, width, height, true);
}

void C3DR_DeleteTexture(unsigned name)
{
	if (name == 0 || name > MAX_TEXTURES || !R.textures[name - 1].used)
		return;
	TexSlot *slot = &R.textures[name - 1];
	R.liveTexBytes -= (u32)slot->tex.width * slot->tex.height * TEX_BPP;
	C3D_TexDelete(&slot->tex);
	slot->used = false;
	R.liveTextures--;
	for (int u = 0; u < 2; u++)
	{
		if (R.bound[u] == name)
		{
			R.bound[u] = 0;
			R.texDirty = true;
		}
	}
}

void C3DR_ActiveTextureUnit(int unit)
{
	R.activeUnit = unit & 1;
}

void C3DR_BindTexture(unsigned name)
{
	if (R.bound[R.activeUnit] != name)
	{
		R.bound[R.activeUnit] = name;
		R.texDirty = true;
	}
}

void C3DR_SetTexture2DEnabled(int enabled)
{
	if (R.texEnabled[R.activeUnit] != (bool)enabled)
	{
		R.texEnabled[R.activeUnit] = enabled;
		R.texDirty = true;
	}
}

void C3DR_SetTextureEnv(int mode)
{
	if (R.activeUnit == 1 && R.texEnv1 != mode)
	{
		R.texEnv1 = mode;
		R.texDirty = true;
	}
}

void C3DR_SetTextureWrap(int axis, int clamp)
{
	unsigned name = R.bound[R.activeUnit];
	if (name == 0 || !R.textures[name - 1].used)
		return;
	TexSlot *t = &R.textures[name - 1];
	if (axis == 0)
		t->clampU = clamp;
	else
		t->clampV = clamp;
	C3D_TexSetWrap(&t->tex,
		t->clampU ? GPU_CLAMP_TO_EDGE : GPU_REPEAT,
		t->clampV ? GPU_CLAMP_TO_EDGE : GPU_REPEAT);
}

// ---------------------------------------------------------------------------
// Public API: indexed draw

void C3DR_DrawIndexedTriangles(
	const float *points,
	const float *colors,
	const float *uv0,
	const float *uv1,
	const unsigned *indices,
	int numTriangles)
{
	if (numTriangles <= 0 || !points || !indices)
		return;

	int numIndices = numTriangles * 3;

	flushAll();

#ifdef DEBUGLOG
	// Draw probe: coarse per-draw state to compare scenes that render
	// against ones that don't (positions, texture, transform).
	static int dbgDraw = 0;
	if (++dbgDraw % 500 == 0)
	{
		float mvp[16];
		mulCM(mvp, R.stacks[1][R.stackTop[1]], R.stacks[0][R.stackTop[0]]);
		c3drLog("c3dr: draw#%d tris=%d tex=%u(%dx%d) p0=%.0f,%.0f,%.0f mvpd=%.3f",
			dbgDraw, numTriangles, R.bound[0],
			R.bound[0] ? R.textures[R.bound[0]-1].tex.width : 0,
			R.bound[0] ? R.textures[R.bound[0]-1].tex.height : 0,
			points[0], points[1], points[2],
			mvp[0]);
	}
#endif

	// Downcast indices to u16 (PICA has no 32-bit index path), finding the
	// vertex count in the same scan.
	u16 *idx = ringAlloc((size_t)numIndices * 2, 16);
	if (!idx)
		return;
	unsigned maxIndex = 0;
	for (int i = 0; i < numIndices; i++)
	{
		unsigned v = indices[i];
		if (v > maxIndex)
			maxIndex = v;
		idx[i] = (u16)v;
	}
	int numVerts = (int)maxIndex + 1;

	// Stage attribute arrays in linear memory (the GPU reads them directly).
	float *pts = ringAlloc((size_t)numVerts * 12, 16);
	if (!pts)
		return;
	memcpy(pts, points, (size_t)numVerts * 12);

	float *clr = NULL, *tc0 = NULL, *tc1 = NULL;
	if (colors)
	{
		clr = ringAlloc((size_t)numVerts * 16, 16);
		if (!clr)
			return;
		memcpy(clr, colors, (size_t)numVerts * 16);
	}
	if (uv0)
	{
		tc0 = ringAlloc((size_t)numVerts * 8, 16);
		if (!tc0)
			return;
		memcpy(tc0, uv0, (size_t)numVerts * 8);
	}
	if (uv1)
	{
		tc1 = ringAlloc((size_t)numVerts * 8, 16);
		if (!tc1)
			return;
		memcpy(tc1, uv1, (size_t)numVerts * 8);
	}

	GSPGPU_FlushDataCache(R.ring[R.ringIndex], R.ringOffset);

	// Attribute + buffer config for this draw
	C3D_AttrInfo *attr = C3D_GetAttrInfo();
	AttrInfo_Init(attr);
	AttrInfo_AddLoader(attr, 0, GPU_FLOAT, 3);
	if (clr) AttrInfo_AddLoader(attr, 1, GPU_FLOAT, 4);
	else
	{
		AttrInfo_AddFixed(attr, 1);
		C3D_FixedAttribSet(1, R.currentColor[0], R.currentColor[1], R.currentColor[2], R.currentColor[3]);
	}
	if (tc0) AttrInfo_AddLoader(attr, 2, GPU_FLOAT, 2);
	else
	{
		AttrInfo_AddFixed(attr, 2);
		C3D_FixedAttribSet(2, 0, 0, 0, 1);
	}
	if (tc1) AttrInfo_AddLoader(attr, 3, GPU_FLOAT, 2);
	else
	{
		AttrInfo_AddFixed(attr, 3);
		C3D_FixedAttribSet(3, 0, 0, 0, 1);
	}

	C3D_BufInfo *buf = C3D_GetBufInfo();
	BufInfo_Init(buf);
	BufInfo_Add(buf, pts, 12, 1, 0x0);
	if (clr) BufInfo_Add(buf, clr, 16, 1, 0x1);
	if (tc0) BufInfo_Add(buf, tc0, 8, 1, 0x2);
	if (tc1) BufInfo_Add(buf, tc1, 8, 1, 0x3);

	C3D_DrawElements(GPU_TRIANGLES, numIndices, C3D_UNSIGNED_SHORT, idx);
}

// ---------------------------------------------------------------------------
// Public API: immediate mode

void C3DR_Begin(int primitive)
{
	R.immPrim = primitive;
	R.immCount = 0;
	R.immUV[0] = R.immUV[1] = 0;
}

void C3DR_TexCoord2f(float u, float v)
{
	R.immUV[0] = u;
	R.immUV[1] = v;
}

void C3DR_Vertex3f(float x, float y, float z)
{
	if (R.immCount >= (int)(sizeof R.immVerts / sizeof R.immVerts[0]))
		return;
	R.immVerts[R.immCount].pos[0] = x;
	R.immVerts[R.immCount].pos[1] = y;
	R.immVerts[R.immCount].pos[2] = z;
	memcpy(R.immVerts[R.immCount].clr, R.currentColor, sizeof R.currentColor);
	memcpy(R.immVerts[R.immCount].uv, R.immUV, sizeof R.immUV);
	R.immCount++;
}

static void immEmit(int i)
{
	C3D_ImmSendAttrib(R.immVerts[i].pos[0], R.immVerts[i].pos[1], R.immVerts[i].pos[2], 1);
	C3D_ImmSendAttrib(R.immVerts[i].clr[0], R.immVerts[i].clr[1], R.immVerts[i].clr[2], R.immVerts[i].clr[3]);
	C3D_ImmSendAttrib(R.immVerts[i].uv[0], R.immVerts[i].uv[1], 0, 1);
	C3D_ImmSendAttrib(0, 0, 0, 1);
}

void C3DR_End(void)
{
	if (R.immCount == 0)
		return;

	// PICA has no line primitives; nothing on the 3DS path draws them.
	if (R.immPrim >= C3DR_PRIM_LINES)
	{
		R.immCount = 0;
		return;
	}

	flushAll();

	C3D_AttrInfo *attr = C3D_GetAttrInfo();
	AttrInfo_Init(attr);
	AttrInfo_AddLoader(attr, 0, GPU_FLOAT, 3); // via immediate submission
	AttrInfo_AddLoader(attr, 1, GPU_FLOAT, 4);
	AttrInfo_AddLoader(attr, 2, GPU_FLOAT, 2);
	AttrInfo_AddLoader(attr, 3, GPU_FLOAT, 2);

	C3D_ImmDrawBegin(GPU_TRIANGLES);
	if (R.immPrim == C3DR_PRIM_QUADS)
	{
		for (int q = 0; q + 3 < R.immCount; q += 4)
		{
			immEmit(q); immEmit(q + 1); immEmit(q + 2);
			immEmit(q); immEmit(q + 2); immEmit(q + 3);
		}
	}
	else // triangles
	{
		for (int i = 0; i + 2 < R.immCount; i += 3)
		{
			immEmit(i); immEmit(i + 1); immEmit(i + 2);
		}
	}
	C3D_ImmDrawEnd();

	R.immCount = 0;
}
