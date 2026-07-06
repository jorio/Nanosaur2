#include "internal.h"

static inline GPU_BLENDFACTOR pgl_convert_blendfactor(GLenum factor) 
{
	switch(factor)
	{
		case GL_ZERO: 						return GPU_ZERO;
		case GL_ONE:  						return GPU_ONE;
		case GL_SRC_COLOR: 					return GPU_SRC_COLOR;
		case GL_ONE_MINUS_SRC_COLOR: 		return GPU_ONE_MINUS_SRC_COLOR;
		case GL_DST_COLOR: 					return GPU_DST_COLOR;
		case GL_ONE_MINUS_DST_COLOR: 		return GPU_ONE_MINUS_DST_COLOR;
		case GL_SRC_ALPHA: 					return GPU_SRC_ALPHA;
		case GL_ONE_MINUS_SRC_ALPHA: 		return GPU_ONE_MINUS_SRC_ALPHA;
		case GL_DST_ALPHA: 					return GPU_DST_ALPHA;
		case GL_ONE_MINUS_DST_ALPHA: 		return GPU_ONE_MINUS_DST_ALPHA;
		case GL_SRC_ALPHA_SATURATE: 		return GPU_SRC_ALPHA_SATURATE;
		case GL_CONSTANT_COLOR: 			return GPU_CONSTANT_COLOR;
		case GL_ONE_MINUS_CONSTANT_COLOR: 	return GPU_ONE_MINUS_CONSTANT_COLOR;
		case GL_CONSTANT_ALPHA: 			return GPU_CONSTANT_ALPHA;
		case GL_ONE_MINUS_CONSTANT_ALPHA: 	return GPU_ONE_MINUS_CONSTANT_ALPHA;
	}
	
	return GPU_ONE;
}

static inline GPU_TESTFUNC pgl_convert_testfunc(GLenum func)
{
	switch(func)
	{
		case GL_NEVER: 		return GPU_NEVER;
		case GL_EQUAL: 		return GPU_EQUAL;
		case GL_LEQUAL: 	return GPU_LEQUAL;
		case GL_GREATER: 	return GPU_GREATER;
		case GL_NOTEQUAL: 	return GPU_NOTEQUAL;
		case GL_GEQUAL: 	return GPU_GEQUAL;
		case GL_LESS:		return GPU_LESS;
		default:			return GPU_ALWAYS;
	}
}

void glAlphaFunc(GLenum func, GLclampf ref)
{
	pglState->alphaTestFunction = pgl_convert_testfunc(func);
	pglState->alphaTestReference = (GLuint)(ref * 255.0f);

	pglState->changes |= STATE_ALPHATEST_CHANGE;
}

void glBlendColor(GLclampf red, GLclampf green, GLclampf blue, GLclampf alpha)
{ 
	uint8_t r = red * 255;
	uint8_t b = blue * 255;
	uint8_t g = green * 255;
	uint8_t a = alpha * 255;
	pglState->blendColor = r | (g << 8) | (b << 16) | (a << 24);

	pglState->changes |= STATE_BLEND_CHANGE;
}

void glBlendEquation(GLenum mode)
{
	switch(mode)
	{
		case GL_FUNC_SUBTRACT:
			pglState->blendEquation = GPU_BLEND_SUBTRACT;
			break;
		case GL_FUNC_REVERSE_SUBTRACT:
			pglState->blendEquation = GPU_BLEND_REVERSE_SUBTRACT;
			break;
		default:
			pglState->blendEquation = GPU_BLEND_ADD;
			break;
	}

	pglState->changes |= STATE_BLEND_CHANGE;
}

void glBlendFunc(GLenum sfactor, GLenum dfactor)
{
	pglState->blendSrcFunction = pgl_convert_blendfactor(sfactor);
	pglState->blendDstFunction = pgl_convert_blendfactor(dfactor);

	pglState->changes |= STATE_BLEND_CHANGE;
}