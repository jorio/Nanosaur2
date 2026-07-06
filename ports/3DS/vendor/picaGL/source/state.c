#include "internal.h"
#include "vshader_shbin.h"
#include "clear_shbin.h"

picaGLState *pglState;

void _stateInitialize()
{
	pglState->gxQueue.maxEntries = 8;
	pglState->gxQueue.entries = (gxCmdEntry_s*)malloc(pglState->gxQueue.maxEntries*sizeof(gxCmdEntry_s));

	pglState->geometryBuffer[0] = linearAlloc(GEOMETRY_BUFFER_SIZE);
	pglState->geometryBuffer[1] = linearAlloc(GEOMETRY_BUFFER_SIZE);

	pglState->geometryBufferCurrent = 0;

	pglState->colorBuffer = vramAlloc(400 * 240 * 4); // 32-bit (RGBA8)
	pglState->depthBuffer = vramAlloc(400 * 240 * 4); // 24-bit depth + 8-bit stencil

	pglState->commandBuffer[0] = linearAlloc(COMMAND_BUFFER_SIZE);
	pglState->commandBuffer[1] = linearAlloc(COMMAND_BUFFER_SIZE);

	GPUCMD_SetBuffer(pglState->commandBuffer[0], COMMAND_BUFFER_LENGTH, 0);

	GX_BindQueue(&pglState->gxQueue);
	gxCmdQueueRun(&pglState->gxQueue);

	pglState->basicShader_dvlb = DVLB_ParseFile((u32*)vshader_shbin, vshader_shbin_size);

	shaderProgramInit(&pglState->basicShader);
	shaderProgramSetVsh(&pglState->basicShader, &pglState->basicShader_dvlb->DVLE[0]);
	shaderProgramUse(&pglState->basicShader);

	pglState->clearShader_dvlb = DVLB_ParseFile((u32*)clear_shbin, clear_shbin_size);

	shaderProgramInit(&pglState->clearShader);
	shaderProgramSetVsh(&pglState->clearShader, &pglState->clearShader_dvlb->DVLE[0]);

	_picaRenderBuffer(pglState->colorBuffer, pglState->depthBuffer);
	_picaAttribBuffersLocation((void*)__ctru_linear_heap);

}

void _stateDefault()
{
	for(int i = 0; i < 4; i++)
		_picaTextureEnvReset(&pglState->texenv[i]);

	pglState->texenv[PGL_TEXENV_UNTEXTURED].src_rgb   = GPU_TEVSOURCES(GPU_PRIMARY_COLOR, GPU_PRIMARY_COLOR, GPU_PRIMARY_COLOR);
	pglState->texenv[PGL_TEXENV_UNTEXTURED].src_alpha = pglState->texenv[PGL_TEXENV_UNTEXTURED].src_rgb;

	pglState->depthmapNear 	= 1.0f;
	pglState->depthmapFar 	= 0.0f;
	pglState->polygonOffset = 0.0f;

	glViewport(0, 0, 400, 240);
	glScissor(0, 0, 400, 240);

	glDisable(GL_CULL_FACE);
	glCullFace(GL_BACK);
	glAlphaFunc(GL_ALWAYS, 0.0);

	glDisable(GL_ALPHA_TEST);
	glDisable(GL_STENCIL_TEST);

	glEnableClientState(GL_VERTEX_ARRAY);

	glClearDepth(1.0);
	glMatrixMode(GL_MODELVIEW);

	pglState->writeMask = GPU_WRITE_ALL;

	glActiveTexture(GL_TEXTURE1);
	glBindTexture(GL_TEXTURE_2D, 0);
	glTexEnvf(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_MODULATE);
	glActiveTexture(GL_TEXTURE0);
	glBindTexture(GL_TEXTURE_2D, 0);
	glTexEnvf(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_MODULATE);

	glBlendEquation(GL_FUNC_ADD);
	glBlendFunc(GL_ONE, GL_ZERO);


	glColor4f(1.0f, 1.0f, 1.0f, 1.0f);

	_picaEarlyDepthTest(false);

	for(int i = 1; i < 6; i++)
		_picaTextureEnvSet(i, &pglState->texenv[PGL_TEXENV_DUMMY]);

	pglState->changes = 0xffffff;
}

void _stateFlush()
{
	static matrix4x4 matrix_mvp;

	if(!pglState->changes)
		return;
	
	if(pglState->changes & STATE_VIEWPORT_CHANGE)
	{
		_picaViewport(pglState->viewportY, pglState->viewportX, pglState->viewportHeight, pglState->viewportWidth);
	}

	if(pglState->changes & STATE_SCISSOR_CHANGE)
	{
		_picaScissorTest(pglState->scissorState ? 0x3 : 0x0, pglState->scissorY, pglState->scissorX, pglState->scissorY + pglState->scissorHeight, pglState->scissorX + pglState->scissorWidth);
	}

	if(pglState->changes & STATE_STENCIL_CHANGE)
	{
		_picaStencilTest(pglState->stencilTestState, pglState->stencilTestFunction, pglState->stencilTestReference, pglState->stencilBufferMask, pglState->stencilWriteMask);
		_picaStencilOp(pglState->stencilOpFail, pglState->stencilOpZFail, pglState->stencilOpZPass);
	}

	if(pglState->changes & STATE_ALPHATEST_CHANGE)
	{
		_picaAlphaTest(pglState->alphaTestState, pglState->alphaTestFunction, pglState->alphaTestReference);
	}

	if(pglState->changes & STATE_BLEND_CHANGE)
	{
		if(pglState->blendState)
		{
			_picaBlendFunction(pglState->blendEquation, pglState->blendEquation, pglState->blendSrcFunction, pglState->blendDstFunction, pglState->blendSrcFunction, pglState->blendDstFunction);
			_picaBlendColor(pglState->blendColor);
		}
		else
		{
			_picaLogicOp(GPU_LOGICOP_COPY);
		}
	}

	if(pglState->changes & STATE_DEPTHMAP_CHANGE)
	{
		_picaDepthMap(pglState->depthmapNear, pglState->depthmapFar, pglState->polygonOffsetState ? pglState->polygonOffset : 0);
	}

	if(pglState->changes & STATE_DEPTHTEST_CHANGE)
	{
		_picaDepthTestWriteMask(pglState->depthTestState, pglState->depthTestFunction, pglState->writeMask);
	}

	if(pglState->changes & STATE_CULL_CHANGE)
	{
		_picaCullMode(pglState->cullState ? pglState->cullMode : GPU_CULL_NONE);
	}

	if(pglState->changes & STATE_TEXTURE_CHANGE)
	{
		uint16_t texunit_enable_mask = 0;

		if(pglState->texUnitState[0] && pglState->textureBound[0]->data)
		{
			texunit_enable_mask |= 0x01;
			_picaTextureEnvSet(0, &pglState->texenv[0]);
			_picaTextureObjectSet(GPU_TEXUNIT0, pglState->textureBound[0]);
		}
		else
			_picaTextureEnvSet(0, &pglState->texenv[PGL_TEXENV_UNTEXTURED]);

		if(pglState->texUnitState[1] && pglState->textureBound[1]->data)
		{
			texunit_enable_mask |= 0x02;
			_picaTextureEnvSet(1, &pglState->texenv[1]);
			_picaTextureObjectSet(GPU_TEXUNIT1, pglState->textureBound[1]);
		}
		else
			_picaTextureEnvSet(1, &pglState->texenv[PGL_TEXENV_DUMMY]);

		_picaTexUnitEnable(texunit_enable_mask);
	}

	if(pglState->changes & STATE_MATRIX_CHANGE)
	{
		matrix4x4_multiply(&matrix_mvp, &pglState->matrix_projection, &pglState->matrix_modelview);
		_picaUniformFloat(GPU_VERTEX_SHADER, 0, (float*)&matrix_mvp, 4);
	}

	pglState->changes = 0;
}

void glDisable(GLenum cap)
{
	switch (cap)
	{
		case GL_DEPTH_TEST:
			pglState->depthTestState = false;
			pglState->changes |= STATE_DEPTHTEST_CHANGE;
			break;
		case GL_POLYGON_OFFSET_FILL:
			pglState->polygonOffsetState = false;
			pglState->changes |= STATE_DEPTHTEST_CHANGE;
			break;
		case GL_STENCIL_TEST:
			pglState->stencilTestState = false;
			pglState->changes |= STATE_STENCIL_CHANGE;
			break;
		case GL_BLEND:
			pglState->blendState = false;
			pglState->changes |= STATE_BLEND_CHANGE;
			break;
		case GL_SCISSOR_TEST:
			pglState->scissorState = false;
			pglState->changes |= STATE_SCISSOR_CHANGE;
			break;
		case GL_CULL_FACE:
			pglState->cullState = false;
			pglState->changes |= STATE_CULL_CHANGE;
			break;
		case GL_TEXTURE_2D:
			pglState->texUnitState[pglState->texUnitActive] = false;
			pglState->changes |= STATE_TEXTURE_CHANGE;
			break;
		case GL_ALPHA_TEST:
			pglState->alphaTestState = false;
			pglState->changes |= STATE_ALPHATEST_CHANGE;
			break;
		default:
			break;
	}
}

void glEnable(GLenum cap)
{
	switch (cap)
	{
		case GL_DEPTH_TEST:
			pglState->depthTestState = true;
			pglState->changes |= STATE_DEPTHTEST_CHANGE;
			break;
		case GL_POLYGON_OFFSET_FILL:
			pglState->polygonOffsetState = true;
			pglState->changes |= STATE_DEPTHTEST_CHANGE;
			break;
		case GL_STENCIL_TEST:
			pglState->stencilTestState = true;
			pglState->changes |= STATE_STENCIL_CHANGE;
			break;
		case GL_BLEND:
			pglState->blendState = true;
			pglState->changes |= STATE_BLEND_CHANGE;
			break;
		case GL_SCISSOR_TEST:
			pglState->scissorState = true;
			pglState->changes |= STATE_SCISSOR_CHANGE;
			break;
		case GL_CULL_FACE:
			pglState->cullState = true;
			pglState->changes |= STATE_CULL_CHANGE;
			break;
		case GL_TEXTURE_2D:
			pglState->texUnitState[pglState->texUnitActive] = true;
			pglState->changes |= STATE_TEXTURE_CHANGE;
			break;
		case GL_ALPHA_TEST:
			pglState->alphaTestState = true;
			pglState->changes |= STATE_ALPHATEST_CHANGE;
			break;
		default:
			break;
	}
}
