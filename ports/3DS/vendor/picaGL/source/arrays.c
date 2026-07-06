#include "internal.h"

static inline bool _addressIsLinear(const void* addr)
{
	u32 vaddr = (u32)addr;
	return vaddr >= __ctru_linear_heap && vaddr < (__ctru_linear_heap + __ctru_linear_heap_size);
}

static uint64_t _configAttribBuffer(uint64_t format, uint8_t stride, uint8_t count, uint32_t padding)
{
	uint32_t *config = (uint32_t*)&format;

	while(padding > 0)
	{
		if(padding < 4) {
			format |= (0xB + padding) << (count * 4);
			padding = 0;
		} else {
			format |= 0xF << (count * 4);
			padding -= 4;
		}
		count++;
	}

	config[1] |= (count << 28) | ((stride & 0xFF) << 16);

	return format;
}

//Check if we have enough space in the current geometry buffer
static bool _checkBufferLimit(GLsizei size)
{
	if(pglState->geometryBufferOffset + size > GEOMETRY_BUFFER_SIZE)
		return false;
	else
		return true;
}

static void* _bufferArray(const void *data, GLsizei size)
{
	void *cache = pglState->geometryBuffer[pglState->geometryBufferCurrent] + pglState->geometryBufferOffset;

	if(data != NULL)
		memcpy(cache, data, size);

	pglState->geometryBufferOffset += size;

	return cache;
}

void glVertexPointer(GLint size, GLenum type, GLsizei stride, const GLvoid * pointer)
{
	AttribPointer *vertexArray = &pglState->vertexArrayPointer;

	switch(type)
	{
		case GL_SHORT:
			vertexArray->type = GPU_SHORT;
			vertexArray->stride = size * 2;
			break;
		case GL_FLOAT:
			vertexArray->type = GPU_FLOAT;
			vertexArray->stride = size * 4;
			break;
		default:
			printf("%s: unimplemented type: %i\n", __FUNCTION__, type);
			break;
	}

	if(stride)
	{
		vertexArray->padding = (stride - vertexArray->stride) / 4;
		vertexArray->stride = stride;
	}

	vertexArray->pointer = pointer;
	vertexArray->size = size;

	vertexArray->inLinearMem  = _addressIsLinear(pointer);
	vertexArray->bufferConfig = _configAttribBuffer( 0x0, vertexArray->stride, 1, vertexArray->padding);
}

void glColorPointer(GLint size, GLenum type, GLsizei stride, const GLvoid * pointer)
{
	AttribPointer *colorArray = &pglState->colorArrayPointer;

	switch(type)
	{
		case GL_BYTE:
			colorArray->type = GPU_BYTE;
			colorArray->stride = size * 1;
			break;
		case GL_UNSIGNED_BYTE:
			colorArray->type = GPU_UNSIGNED_BYTE;
			colorArray->stride = size * 1;
			break;
		case GL_SHORT:
			colorArray->type = GPU_SHORT;
			colorArray->stride = size * 2;
			break;
		case GL_FLOAT:
			colorArray->type = GPU_FLOAT;
			colorArray->stride = size * 4;
			break;
		default:
			printf("%s: unimplemented type: %i\n", __FUNCTION__, type);
			return;
	}

	if(stride)
	{
		colorArray->padding = (stride - pglState->colorArrayPointer.stride) / 4;
		colorArray->stride  = stride;
	}

	colorArray->pointer = pointer;
	colorArray->size = size;

	colorArray->inLinearMem  = _addressIsLinear(pointer);
	colorArray->bufferConfig = _configAttribBuffer(0x1, colorArray->stride, 1, colorArray->padding);
}

void glTexCoordPointer(GLint size, GLenum type, GLsizei stride, const GLvoid* pointer)
{
	AttribPointer *texCoordArray = &pglState->texCoordArrayPointer[pglState->texUnitActiveClient];

	switch(type)
	{
		case GL_SHORT:
			texCoordArray->type = GPU_SHORT;
			texCoordArray->stride = size * 2;
			break;
		case GL_FLOAT:
			texCoordArray->type = GPU_FLOAT;
			texCoordArray->stride = size * 4;
			break;
		default:
			printf("%s: unimplemented type: %i\n", __FUNCTION__, type);
			return;
	}

	if(stride)
	{
		texCoordArray->padding = (stride - texCoordArray->stride) / 4;
		texCoordArray->stride = stride;
	}

	texCoordArray->pointer = pointer;
	texCoordArray->size = size;

	texCoordArray->inLinearMem  = _addressIsLinear(pointer);
	texCoordArray->bufferConfig = _configAttribBuffer(0x2 + pglState->texUnitActiveClient, texCoordArray->stride, 1, texCoordArray->padding);
}

void glEnableClientState(GLenum array)
{
	switch(array)
	{
		case GL_VERTEX_ARRAY:
			pglState->vertexArrayState = GL_TRUE;
			break;
		case GL_COLOR_ARRAY:
			pglState->colorArrayState = GL_TRUE;
			break;
		case GL_TEXTURE_COORD_ARRAY:
			pglState->texCoordArrayState[pglState->texUnitActive] = GL_TRUE;
			break;
	}
}

void glDisableClientState(GLenum array)
{
	switch(array)
	{
		case GL_VERTEX_ARRAY:
			pglState->vertexArrayState = GL_FALSE;
			break;
		case GL_COLOR_ARRAY:
			pglState->colorArrayState = GL_FALSE;
			break;
		case GL_TEXTURE_COORD_ARRAY:
			pglState->texCoordArrayState[pglState->texUnitActive] = GL_FALSE;
			break;
	}
}

void glDrawArrays(GLenum mode, GLint first, GLsizei count)
{
	if(pglState->vertexArrayState == GL_FALSE)
		return;

	glDrawRangeElements(mode, first, count, count, GL_UNSIGNED_SHORT, NULL);
}

void glDrawElements(GLenum mode, GLsizei count, GLenum type, const GLvoid *indices)
{
	if(type != GL_UNSIGNED_SHORT || pglState->vertexArrayState == GL_FALSE)
		return;

	uint32_t end = 0;

	for(int i = 0; i < count; i++)
	{
			if(end < ((GLushort*)indices)[i])
				end = ((GLushort*)indices)[i];
	}

	end++;

	glDrawRangeElements( mode, 0, end, count, type, indices );
}

void glDrawRangeElements( GLenum mode, GLuint start, GLuint end, GLsizei count, GLenum type, const GLvoid *indices )
{
	if(type != GL_UNSIGNED_SHORT || pglState->vertexArrayState == GL_FALSE)
		return;

	void *arrayCache = NULL;

	uint8_t  bufferCount 			= 0;
	uint16_t attributesFixedMask 	= 0x00;
	uint64_t attributesFormat 		= 0x00;
	uint64_t attributesPermutation  = 0x3210;

	AttribPointer *vertexArray 	    = &pglState->vertexArrayPointer;
	AttribPointer *colorArray 		= &pglState->colorArrayPointer;
	AttribPointer *texCoordArray 	= pglState->texCoordArrayPointer;

	if(_checkBufferLimit((end * 48) + (sizeof(GLushort) * count)) == false)
		glFlush();

	_stateFlush();

	if(vertexArray->inLinearMem)
		arrayCache = (void*)vertexArray->pointer;
	else
		arrayCache = _bufferArray(vertexArray->pointer, vertexArray->stride * end);

	attributesFormat |= GPU_ATTRIBFMT(0, vertexArray->size, vertexArray->type);
	_picaAttribBufferOffset(bufferCount, (uint32_t)arrayCache - __ctru_linear_heap);
	_picaAttribBufferConfig(bufferCount, vertexArray->bufferConfig);

	bufferCount++;

	if(pglState->colorArrayState == GL_TRUE)
	{
		if(colorArray->inLinearMem)
			arrayCache = (void*)colorArray->pointer;
		else
			arrayCache = _bufferArray(colorArray->pointer, colorArray->stride * end);

		attributesFormat |= GPU_ATTRIBFMT(1, colorArray->size, colorArray->type);
		_picaAttribBufferOffset(bufferCount, (uint32_t)arrayCache - __ctru_linear_heap);
		_picaAttribBufferConfig(bufferCount, colorArray->bufferConfig);

		bufferCount++;
	}
	else
	{
		attributesFixedMask |= 1 << 1;
		attributesFormat |= GPU_ATTRIBFMT(1, 4, GPU_FLOAT);

		GPUCMD_AddWrite(GPUREG_FIXEDATTRIB_INDEX, 1);
		_picaFixedAttribute(pglState->currentColor.r, pglState->currentColor.g, pglState->currentColor.b, pglState->currentColor.a);
	}

	if( (pglState->texCoordArrayState[0] == GL_TRUE) && (pglState->texUnitState[0] == GL_TRUE) )
	{
		if(texCoordArray[0].inLinearMem)
			arrayCache = (void*)texCoordArray[0].pointer;
		else
			arrayCache = _bufferArray(texCoordArray[0].pointer, texCoordArray[0].stride * end);

		attributesFormat |= GPU_ATTRIBFMT(2, texCoordArray[0].size, texCoordArray[0].type);
		_picaAttribBufferOffset(bufferCount, (uint32_t)arrayCache - __ctru_linear_heap);
		_picaAttribBufferConfig(bufferCount, texCoordArray[0].bufferConfig);

		bufferCount++;
	}
	else
	{
		attributesFixedMask |= 1 << 2;
		attributesFormat |= GPU_ATTRIBFMT(2, 2, GPU_FLOAT);

		GPUCMD_AddWrite(GPUREG_FIXEDATTRIB_INDEX, 2);
		_picaFixedAttribute(1, 1, 0, 0);
	}

	if( (pglState->texCoordArrayState[1] == GL_TRUE) && (pglState->texUnitState[1] == GL_TRUE) )
	{	
		if(texCoordArray[0].inLinearMem)
			arrayCache = (void*)texCoordArray[0].pointer;
		else
			arrayCache = _bufferArray(texCoordArray[0].pointer, texCoordArray[0].stride * end);
		
		attributesFormat |= GPU_ATTRIBFMT(3, texCoordArray[1].size, texCoordArray[1].type);
		_picaAttribBufferOffset(bufferCount, (uint32_t)arrayCache - __ctru_linear_heap);
		_picaAttribBufferConfig(bufferCount, texCoordArray[1].bufferConfig);

		bufferCount++;
	}
	else
	{
		attributesFixedMask |= 1 << 3;
		attributesFormat |= GPU_ATTRIBFMT(3, 2, GPU_FLOAT);

		GPUCMD_AddWrite(GPUREG_FIXEDATTRIB_INDEX, 3);
		_picaFixedAttribute(1, 1, 0, 0);
	}

	_picaAttribBuffersFormat(attributesFormat, attributesFixedMask, attributesPermutation, bufferCount);

	GPU_Primitive_t primitive_type;

	switch(mode)
	{
		case GL_TRIANGLES: 
			primitive_type = GPU_TRIANGLES; 
			break;
		case GL_TRIANGLE_FAN:
			primitive_type = GPU_TRIANGLE_FAN; 
			break;
		case GL_TRIANGLE_STRIP:
			primitive_type = GPU_TRIANGLE_STRIP;
			break;
		default:
			primitive_type = GPU_TRIANGLES;
	}
	
	if(indices)
	{
		uint16_t* index_array  = _bufferArray(indices, sizeof(uint16_t) * count);

		_picaDrawElements(primitive_type, (uint32_t)index_array - __ctru_linear_heap, count);
	}
	else
	{
		_picaDrawArray(primitive_type, start, count);
	}

	if(++pglState->batchedDraws > MAX_BATCHED_DRAWS)
		glFlush();
}