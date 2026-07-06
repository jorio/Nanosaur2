#include "internal.h"

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

void glClearDepth(GLclampd depth)
{
	//I don't think this is right...
	pglState->clearDepth = -depth;
}

void glDepthFunc(GLenum func)
{
	pglState->depthTestFunction = pgl_convert_testfunc(func);

	pglState->changes |= STATE_DEPTHTEST_CHANGE;
}

void glDepthMask(GLboolean flag)
{
	pglState->writeMask = (pglState->writeMask & 0xF) | ((flag & 0x1) << 4);

	pglState->changes |= STATE_DEPTHTEST_CHANGE;
}

void glDepthRange(GLclampd nearVal, GLclampd farVal)
{
	pglState->depthmapNear = (float)farVal;
	pglState->depthmapFar  = (float)nearVal;

	pglState->changes |= STATE_DEPTHMAP_CHANGE;
}

void glPolygonOffset(GLfloat factor, GLfloat units) 
{
	//Not correct, but seems to do it for my needs
	pglState->polygonOffset = units / (1 << 10);

	pglState->changes |= STATE_DEPTHMAP_CHANGE;
}