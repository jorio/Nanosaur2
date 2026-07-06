#include "internal.h"

static inline GPU_STENCILOP pgl_convert_stencilop(GLenum op)
{
	switch (op) 
	{
		case GL_KEEP: return GPU_STENCIL_KEEP;
		case GL_ZERO: return GPU_STENCIL_ZERO;
		case GL_REPLACE: return GPU_STENCIL_REPLACE;
		case GL_INCR: return GPU_STENCIL_INCR;
		case GL_DECR: return GPU_STENCIL_DECR;
		case GL_INVERT: return GPU_STENCIL_INVERT;
		default: return GPU_STENCIL_KEEP;
	}
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

void glStencilFunc(GLenum func, GLint ref, GLuint mask)
{
	pglState->stencilTestReference = ref;
	pglState->stencilBufferMask = mask;
	pglState->stencilTestFunction = pgl_convert_testfunc(func);

	pglState->changes |= STATE_STENCIL_CHANGE;
}

void glStencilMask(GLuint mask)
{
	pglState->stencilWriteMask = mask;
	pglState->changes |= STATE_STENCIL_CHANGE;
}

void glStencilOp(GLenum fail, GLenum zfail, GLenum zpass)
{
	pglState->stencilOpFail  = pgl_convert_stencilop(fail);
	pglState->stencilOpZFail = pgl_convert_stencilop(zfail);
	pglState->stencilOpZPass = pgl_convert_stencilop(zpass);

	pglState->changes |= STATE_STENCIL_CHANGE;
}
