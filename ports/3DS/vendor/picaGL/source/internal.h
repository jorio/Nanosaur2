#ifndef __pglState_H__
#define __pglState_H__

#include <stdlib.h>
#include <stdio.h>
#include <3ds.h>
#include <GL/picaGL.h>

#include "utils/math_utils.h"
#include "utils/hashtable.h"

#define MATRIX_STACK_SIZE 16

#define MAX_BATCHED_DRAWS 200

#define GEOMETRY_BUFFER_SIZE 0x20000
#define COMMAND_BUFFER_LENGTH 0x40000

#define COMMAND_BUFFER_SIZE   COMMAND_BUFFER_LENGTH * 4

#define STATE_RENDERTARGET_CHANGE 	(1 << 0)
#define STATE_VIEWPORT_CHANGE 		(1 << 1)
#define STATE_STENCIL_CHANGE 		(1 << 2)
#define STATE_DEPTHTEST_CHANGE		(1 << 3)
#define STATE_ALPHATEST_CHANGE 		(1 << 4)
#define STATE_CULL_CHANGE 			(1 << 5)
#define STATE_TEXTURE_CHANGE		(1 << 6)
#define STATE_DEPTHMAP_CHANGE		(1 << 7)
#define STATE_BLEND_CHANGE			(1 << 8)
#define STATE_MATRIX_CHANGE 		(1 << 9)
#define STATE_SCISSOR_CHANGE		(1 << 10)
#define STATE_ALL_CHANGE			(0xffffffff);

#define PGL_TEXENV_UNTEXTURED 2
#define PGL_TEXENV_DUMMY 3

extern u32 __ctru_linear_heap;
extern u32 __ctru_linear_heap_size;

typedef struct {
	uint16_t src_rgb, src_alpha;
	uint16_t op_rgb, op_alpha;
	uint16_t func_rgb, func_alpha;
	uint32_t color;
	uint16_t scale_rgb, scale_alpha;
} TextureEnv;

typedef struct {
	uint16_t format;
	uint16_t width, height;
	uint32_t param;
	uint32_t border;
	uint8_t bpp;
	void* data;
	size_t size;
	bool in_vram;
	bool used;
} TextureObject;

typedef struct {
	GLint size;
	GLenum type;
	GLsizei stride;
	GLsizei padding;
	const GLvoid* pointer;
	uint64_t bufferConfig;
	bool inLinearMem;
} AttribPointer;

typedef struct {
	float r, g, b, a;
} color_rgba;

typedef struct { 
	float s, t;
} texcoord;

typedef struct {
	gxCmdQueue_s 		gxQueue;

	uint32_t			*commandBuffer[2], commandBufferLength;
	uint32_t			*colorBuffer, *depthBuffer;

	DVLB_s*				basicShader_dvlb;
	shaderProgram_s		basicShader;

	DVLB_s*				clearShader_dvlb;
	shaderProgram_s		clearShader;
	
	color_rgba			clearColor;
	GLfloat 			clearDepth;

	uint8_t 			display;
	uint32_t 			display_side;

	GLfloat				depthmapNear, depthmapFar;
	GLfloat				polygonOffset;
	GLboolean			polygonOffsetState;

	GLboolean			cullState;
	GLenum				cullMode;

	GLboolean			depthTestState;
	GLenum				depthTestFunction;

	GLboolean			alphaTestState;
	GLenum				alphaTestFunction;
	GLuint				alphaTestReference;

	GLboolean			blendState;
	GLenum				blendSrcFunction;
	GLenum				blendDstFunction;
	GLenum				blendEquation;
	GLuint				blendColor;

	matrix4x4			matrix_modelview;
	matrix4x4			matrix_modelview_stack[MATRIX_STACK_SIZE];
	GLuint				matrix_modelview_stack_counter;
	matrix4x4			matrix_projection;
	matrix4x4			matrix_projection_stack[MATRIX_STACK_SIZE];
	GLuint				matrix_projection_stack_counter;
	matrix4x4			*matrix_current;

	GLboolean			scissorState;
	GLint 				scissorX, scissorY;
	GLsizei 			scissorWidth, scissorHeight;

	GLboolean			stencilTestState;
	GLenum				stencilTestFunction;
	GLint				stencilTestReference;
	GLuint				stencilBufferMask;
	GLuint 				stencilWriteMask;

	GLenum				stencilOpFail;
	GLenum				stencilOpZFail;
	GLenum				stencilOpZPass;

	TextureEnv			texenv[4];

	GLboolean			texUnitState[2];
	GLuint				texUnitActive;
	GLuint				texUnitActiveClient;

	TextureObject 		*textureBound[2];
	HashTable			textureTable;

	GLboolean			textureChanged;

	GLint				viewportX, viewportY;
	GLsizei				viewportWidth, viewportHeight;

	GLboolean			vertexArrayState;
	AttribPointer		vertexArrayPointer;

	GLboolean			texCoordArrayState[2];
	AttribPointer		texCoordArrayPointer[2];

	GLboolean			colorArrayState;
	AttribPointer		colorArrayPointer;

	GLuint				writeMask;

	color_rgba			currentColor;
	texcoord			currentTexCoord[2];

	void 				*geometryBuffer[2];
	GLuint 				 geometryBufferOffset, geometryBufferCurrent;

	GLuint				changes;
	GLuint 				batchedDraws;
} picaGLState;

extern picaGLState *pglState;

void _stateInitialize();
void _stateReset();
void _stateFlush();
void _stateDefault();

/* pica.c */
void _picaAttribBuffersLocation(const void *location);
void _picaAttribBuffersFormat(uint64_t format, uint16_t mask, uint64_t permutaion, uint8_t count);
void _picaAttribBufferOffset(uint8_t id, uint32_t offset);
void _picaAttribBufferConfig(uint8_t id, uint64_t config);

void _picaBlendFunction(GPU_BLENDEQUATION color_equation, GPU_BLENDEQUATION alpha_equation, GPU_BLENDFACTOR color_src, GPU_BLENDFACTOR color_dst, GPU_BLENDFACTOR alpha_src, GPU_BLENDFACTOR alpha_dst);

void _picaViewport(uint32_t x, uint32_t y, uint32_t width, uint32_t height);
void _picaScissorTest(GPU_SCISSORMODE mode, u32 left, u32 top, u32 right, u32 bottom);
void _picaRenderBuffer(uint32_t *colorBuffer, uint32_t *depthBuffer);
void _picaCullMode(GPU_CULLMODE mode);

void _picaDepthMap(float near, float far, float polygon_offset);
void _picaDrawArray(GPU_Primitive_t primitive, uint32_t first, uint32_t count);
void _picaEarlyDepthTest(bool enabled);
void _picaStencilTest(bool enabled, GPU_TESTFUNC function, int reference, u32 buffer_mask, u32 write_mask);
void _picaStencilOp(GPU_STENCILOP sfail, GPU_STENCILOP dfail, GPU_STENCILOP pass);
void _picaTextureEnvSet(uint8_t id, TextureEnv *env);
void _picaTextureEnvReset(TextureEnv* env);
void _picaAlphaTest(bool enable, GPU_TESTFUNC function, uint8_t ref);
void _picaUniformFloat(GPU_SHADER_TYPE type, uint32_t startreg, float *data, uint32_t numreg);
void _picaDepthTestWriteMask(bool enable, GPU_TESTFUNC function, GPU_WRITEMASK writemask);
void _picaFinalize(bool drew_something);
void _picaBlendColor(uint32_t color);
void _picaTexUnitEnable(GPU_TEXUNIT units);
void _picaTextureObjectSet(GPU_TEXUNIT unit, TextureObject* texture);
void _picaImmediateBegin(GPU_Primitive_t primitive);
void _picaImmediateEnd(void);
void _picaLogicOp(GPU_LOGICOP op);
void _picaDrawElements(GPU_Primitive_t primitive, uint32_t indexArray, uint32_t count);
void _picaFixedAttribute(float x, float y, float z, float w);
void _picaRestartPrimitive();

void _queueWaitAndClear();
void _queueRun(bool async);

#endif
