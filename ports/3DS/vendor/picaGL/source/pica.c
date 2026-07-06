#include <3ds.h>
#include "internal.h"

static inline void write24(u8* p, u32 val)
{
	p[0] = val;
	p[1] = val>>8;
	p[2] = val>>16;
}

void _picaRenderBuffer(uint32_t *colorBuffer, uint32_t *depthBuffer)
{
	u32 param[4];

	GPUCMD_AddWrite(GPUREG_FRAMEBUFFER_INVALIDATE, 1);

	param[0] = osConvertVirtToPhys(depthBuffer) >> 3;
	param[1] = osConvertVirtToPhys(colorBuffer) >> 3;
	param[2] = 0x01000000 | (((u32)(400 - 1) & 0xFFF) << 12) | (240 & 0xFFF);
	GPUCMD_AddIncrementalWrites(GPUREG_DEPTHBUFFER_LOC, param, 3);

	GPUCMD_AddWrite(GPUREG_RENDERBUF_DIM, param[2]);
	GPUCMD_AddWrite(GPUREG_DEPTHBUFFER_FORMAT,  0x00000003); // 24-bit depth + 8-bit stencil
	GPUCMD_AddWrite(GPUREG_COLORBUFFER_FORMAT,  0x00000002); // 32-bit (RGBA8)
	GPUCMD_AddWrite(GPUREG_FRAMEBUFFER_BLOCK32, 0x00000000); // 8x8 render block mode

	// Enable or disable color/depth buffers
	param[0] = param[1] = colorBuffer ? 0xF : 0;
	param[2] = param[3] = depthBuffer ? 0x2 : 0;
	GPUCMD_AddIncrementalWrites(GPUREG_COLORBUFFER_READ, param, 4);
}

void _picaViewport(uint32_t x, uint32_t y, uint32_t width, uint32_t height)
{
	u32 param[4];

	param[0] = f32tof24(width / 2.0f);
	param[1] = f32tof31(2.0f / width) << 1;
	param[2] = f32tof24(height / 2.0f);
	param[3] = f32tof31(2.0f / height) << 1;

	GPUCMD_AddIncrementalWrites(GPUREG_VIEWPORT_WIDTH, param, 4);
	GPUCMD_AddWrite(GPUREG_VIEWPORT_XY, (y << 16) | (x & 0xFFFF));
}

void _picaScissorTest(GPU_SCISSORMODE mode, u32 left, u32 top, u32 right, u32 bottom)
{
	u32 param[3];

	param[0] = mode;
	param[1] = (top << 16) | (left & 0xFFFF);
	param[2] = ((bottom-1) << 16) | ((right-1) & 0xFFFF);

	GPUCMD_AddIncrementalWrites(GPUREG_SCISSORTEST_MODE, param, 3);
}

void _picaCullMode(GPU_CULLMODE mode)
{
	GPUCMD_AddWrite(GPUREG_FACECULLING_CONFIG, mode & 0x3);
}

void _picaAttribBuffersLocation(const void *location)
{
	uint32_t phys_location = osConvertVirtToPhys(location);
	GPUCMD_AddWrite(GPUREG_ATTRIBBUFFERS_LOC, phys_location >> 3);
}

void _picaAttribBuffersFormat(uint64_t format, uint16_t mask, uint64_t permutaion, uint8_t count)
{
	uint32_t param[2];

	param[0] = format & 0xFFFFFFFF;
	param[1] = ((count - 1) << 28) | ((mask & 0xFFF) << 16) | ((format >> 32) & 0xFFFF);

	GPUCMD_AddIncrementalWrites(GPUREG_ATTRIBBUFFERS_FORMAT_LOW, param, 0x02);

	param[0] = permutaion & 0xFFFFFFFF;
	param[1] = (permutaion>>32) & 0xFFFF;
	GPUCMD_AddIncrementalWrites(GPUREG_VSH_ATTRIBUTES_PERMUTATION_LOW, param, 2);

	GPUCMD_AddMaskedWrite(GPUREG_VSH_INPUTBUFFER_CONFIG, 0xB, 0xA0000000|(count - 1));
	GPUCMD_AddWrite(GPUREG_VSH_NUM_ATTR, (count - 1));
}

void _picaAttribBufferConfig(uint8_t id, uint64_t config)
{
	if(id > 0xB) return;

	GPUCMD_AddIncrementalWrites(GPUREG_ATTRIBBUFFER0_CONFIG1 + (id * 0x03), (u32*)&config, 0x02);
}

void _picaAttribBufferOffset(uint8_t id, uint32_t offset)
{
	if(id > 0xB) return;

	GPUCMD_AddWrite(GPUREG_ATTRIBBUFFER0_OFFSET + (id * 0x03), offset);
}

void _picaDrawArray(GPU_Primitive_t primitive, uint32_t first, uint32_t count){

	GPUCMD_AddMaskedWrite(GPUREG_PRIMITIVE_CONFIG, 0x2, primitive);
	GPUCMD_AddMaskedWrite(GPUREG_RESTART_PRIMITIVE, 0x2, 0x00000001);
	GPUCMD_AddWrite(GPUREG_INDEXBUFFER_CONFIG, 0x80000000);
	GPUCMD_AddWrite(GPUREG_NUMVERTICES, count);
	GPUCMD_AddWrite(GPUREG_VERTEX_OFFSET, first);

	GPUCMD_AddMaskedWrite(GPUREG_GEOSTAGE_CONFIG2, 1, 1);
	GPUCMD_AddMaskedWrite(GPUREG_START_DRAW_FUNC0, 1, 0);
	GPUCMD_AddWrite(GPUREG_DRAWARRAYS, 1);
	GPUCMD_AddMaskedWrite(GPUREG_START_DRAW_FUNC0, 1, 1);
	GPUCMD_AddMaskedWrite(GPUREG_GEOSTAGE_CONFIG2, 1, 0);
	GPUCMD_AddWrite(GPUREG_VTX_FUNC, 1);

}

void _picaDrawElements(GPU_Primitive_t primitive, uint32_t indexArray, uint32_t count)
{

	GPUCMD_AddMaskedWrite(GPUREG_PRIMITIVE_CONFIG, 0x2, primitive != GPU_TRIANGLES ? primitive : GPU_GEOMETRY_PRIM);
	GPUCMD_AddMaskedWrite(GPUREG_RESTART_PRIMITIVE, 0x2, 0x00000001);
	GPUCMD_AddWrite(GPUREG_INDEXBUFFER_CONFIG, indexArray | (1 << 31));
	GPUCMD_AddWrite(GPUREG_NUMVERTICES, count);

	GPUCMD_AddWrite(GPUREG_VERTEX_OFFSET, 0x00000000);

	GPUCMD_AddMaskedWrite(GPUREG_GEOSTAGE_CONFIG, 0x2, 0x00000100);
	GPUCMD_AddMaskedWrite(GPUREG_GEOSTAGE_CONFIG2, 0x2, 0x00000100);

	GPUCMD_AddMaskedWrite(GPUREG_START_DRAW_FUNC0, 0x1, 0x00000000);
	GPUCMD_AddWrite(GPUREG_DRAWELEMENTS, 0x00000001);
	GPUCMD_AddMaskedWrite(GPUREG_START_DRAW_FUNC0, 0x1, 0x00000001);
	GPUCMD_AddWrite(GPUREG_VTX_FUNC, 0x00000001);

}

void _picaDepthMap(float near, float far, float polygon_offset){
	float scale  = near - far;
	float offset = near + polygon_offset;

	GPUCMD_AddWrite(GPUREG_DEPTHMAP_ENABLE, 0x00000001);
	GPUCMD_AddWrite(GPUREG_DEPTHMAP_SCALE, f32tof24(scale));
	GPUCMD_AddWrite(GPUREG_DEPTHMAP_OFFSET, f32tof24(offset));
}

void _picaStencilTest(bool enabled, GPU_TESTFUNC function, int reference, u32 buffer_mask, u32 write_mask){
	u32 param;

	param  = enabled;
	param |= (function & 7) << 4;
	param |= write_mask << 8;
	param |= reference << 16;
	param |= buffer_mask << 24;

	GPUCMD_AddWrite(GPUREG_STENCIL_TEST, param);
}

void _picaStencilOp(GPU_STENCILOP sfail, GPU_STENCILOP dfail, GPU_STENCILOP pass){
	GPUCMD_AddWrite(GPUREG_STENCIL_OP, sfail | (dfail << 4) | (pass << 8));
}

void _picaAlphaTest(bool enable, GPU_TESTFUNC function, uint8_t ref){
	GPUCMD_AddWrite(GPUREG_FRAGOP_ALPHA_TEST, (enable & 1) | ((function & 7) << 4)| (ref << 8));
}

void _picaTextureEnvSet(uint8_t id, TextureEnv *env)
{
	static const u8 GPU_TEVID[] = { 0xC0, 0xC8, 0xD0, 0xD8, 0xF0, 0xF8 };

	if(id > 6) return;

	u32 param[0x5];

	param[0x0] = (env->src_alpha << 16)  | (env->src_rgb);
	param[0x1] = (env->op_alpha << 12) | (env->op_rgb);
	param[0x2] = (env->func_alpha << 16)  | (env->func_rgb);
	param[0x3] =  env->color;
	param[0x4] = 0x00000000; // ?

	GPUCMD_AddIncrementalWrites(GPU_TEVID[id], param, 0x00000005);
}

void _picaTextureEnvReset(TextureEnv* env) {
	env->src_rgb = GPU_TEVSOURCES(GPU_PREVIOUS, 0, 0);
	env->src_alpha = env->src_rgb;
	env->op_rgb = GPU_TEVOPERANDS(0,0,0);
	env->op_alpha = env->op_rgb;
	env->func_rgb = GPU_REPLACE;
	env->func_alpha = env->func_rgb;
	env->color = 0xFFFFFFFF;
	env->scale_rgb = GPU_TEVSCALE_1;
	env->scale_alpha = GPU_TEVSCALE_1;
}

void _picaEarlyDepthTest(bool enabled) {
	GPUCMD_AddWrite(GPUREG_EARLYDEPTH_TEST1, enabled);
	GPUCMD_AddWrite(GPUREG_EARLYDEPTH_TEST2, enabled);
}

void _picaBlendFunction(GPU_BLENDEQUATION color_equation, GPU_BLENDEQUATION alpha_equation, GPU_BLENDFACTOR color_src, GPU_BLENDFACTOR color_dst, GPU_BLENDFACTOR alpha_src, GPU_BLENDFACTOR alpha_dst) {
	GPUCMD_AddWrite(GPUREG_COLOR_OPERATION, 0xE40100);
	GPUCMD_AddWrite(GPUREG_BLEND_FUNC, color_equation | (alpha_equation<<8) | (color_src<<16) | (color_dst<<20) | (alpha_src<<24) | (alpha_dst<<28));
}

void _picaUniformFloat(GPU_SHADER_TYPE type, uint32_t startreg, float *data, uint32_t numreg)
{
	if(!data)return;

	int regOffset = (type == GPU_GEOMETRY_SHADER) ? (-0x30) : (0x0);

	GPUCMD_AddWrite (GPUREG_VSH_FLOATUNIFORM_CONFIG + regOffset, 0x80000000 | startreg);
	GPUCMD_AddWrites(GPUREG_VSH_FLOATUNIFORM_DATA + regOffset, (u32*)data, numreg * 4);
}

void _picaDepthTestWriteMask(bool enable, GPU_TESTFUNC function, GPU_WRITEMASK writemask)
{
	GPUCMD_AddWrite(GPUREG_DEPTH_COLOR_MASK, (enable & 1) | ((function & 7) << 4) | (writemask << 8));
}

void _picaFinalize(bool drew_something)
{
	if(drew_something)
	{
		GPUCMD_AddWrite(GPUREG_FRAMEBUFFER_FLUSH, 1);
		GPUCMD_AddWrite(GPUREG_FRAMEBUFFER_INVALIDATE, 1);
		GPUCMD_AddWrite(GPUREG_EARLYDEPTH_CLEAR, 1);
	}
}

void _picaBlendColor(uint32_t color)
{
	GPUCMD_AddWrite(GPUREG_BLEND_COLOR, color);
}

void _picaTextureObjectSet(GPU_TEXUNIT unit, TextureObject* texture)
{
	uint32_t addr = osConvertVirtToPhys(texture->data);

	switch (unit)
	{
	case GPU_TEXUNIT0:
		GPUCMD_AddWrite(GPUREG_TEXUNIT0_TYPE, texture->format);
		GPUCMD_AddWrite(GPUREG_TEXUNIT0_ADDR1, addr >> 3);
		GPUCMD_AddWrite(GPUREG_TEXUNIT0_DIM, (texture->width << 16) | texture->height);
		GPUCMD_AddWrite(GPUREG_TEXUNIT0_PARAM, texture->param);
		break;

	case GPU_TEXUNIT1:
		GPUCMD_AddWrite(GPUREG_TEXUNIT1_TYPE, texture->format);
		GPUCMD_AddWrite(GPUREG_TEXUNIT1_ADDR, addr >> 3);
		GPUCMD_AddWrite(GPUREG_TEXUNIT1_DIM, (texture->width << 16) | texture->height);
		GPUCMD_AddWrite(GPUREG_TEXUNIT1_PARAM, texture->param);
		break;

	case GPU_TEXUNIT2:
		GPUCMD_AddWrite(GPUREG_TEXUNIT2_TYPE, texture->format);
		GPUCMD_AddWrite(GPUREG_TEXUNIT2_ADDR, addr >> 3);
		GPUCMD_AddWrite(GPUREG_TEXUNIT2_DIM, (texture->width << 16) | texture->height);
		GPUCMD_AddWrite(GPUREG_TEXUNIT2_PARAM, texture->param);
		break;
	}
}

void _picaImmediateBegin(GPU_Primitive_t primitive)
{
	GPUCMD_AddMaskedWrite(GPUREG_PRIMITIVE_CONFIG, 2, primitive);
	GPUCMD_AddWrite(GPUREG_RESTART_PRIMITIVE, 1);
	GPUCMD_AddWrite(GPUREG_INDEXBUFFER_CONFIG, 0x80000000);
	GPUCMD_AddMaskedWrite(GPUREG_GEOSTAGE_CONFIG2, 1, 1);
	GPUCMD_AddMaskedWrite(GPUREG_START_DRAW_FUNC0, 1, 0);
	GPUCMD_AddWrite(GPUREG_FIXEDATTRIB_INDEX, 0xF);
}

void _picaImmediateEnd(void)
{
	GPUCMD_AddMaskedWrite(GPUREG_START_DRAW_FUNC0, 1, 1);
	GPUCMD_AddMaskedWrite(GPUREG_GEOSTAGE_CONFIG2, 1, 0);
	GPUCMD_AddWrite(GPUREG_VTX_FUNC, 1);
}

void _picaFixedAttribute(float x, float y, float z, float w)
{
	union {
		u32 packed[3];
		struct { u8 x[3], y[3], z[3], w[3]; };
	} param;

	// Convert the values to float24
	write24(param.x, f32tof24(x));
	write24(param.y, f32tof24(y));
	write24(param.z, f32tof24(z));
	write24(param.w, f32tof24(w));

	// Reverse the packed words
	u32 p = param.packed[0];
	param.packed[0] = param.packed[2];
	param.packed[2] = p;

	// Send the attribute
	GPUCMD_AddIncrementalWrites(GPUREG_FIXEDATTRIB_DATA0, param.packed, 3);
}

void _picaTexUnitEnable(GPU_TEXUNIT units)
{
	GPUCMD_AddMaskedWrite(GPUREG_SH_OUTATTR_CLOCK, 0x2, units << 8);
	GPUCMD_AddWrite(GPUREG_TEXUNIT_CONFIG, 0x00011000 | units);
}

void _picaLogicOp(GPU_LOGICOP op)
{
	GPUCMD_AddWrite(GPUREG_LOGIC_OP, op);
	GPUCMD_AddWrite(GPUREG_COLOR_OPERATION, 0xE40000);
}
