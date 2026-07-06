#include "internal.h"

#include <stdio.h>

#include "texture_conv.inc"

static inline bool _addressIsVRAM(const void* addr)
{
	u32 vaddr = (u32)addr;
	return vaddr >= 0x1F000000 && vaddr < 0x1F600000;
}

static size_t _determineBPP(GPU_TEXCOLOR format)
{
	switch (format)
	{
		case GPU_RGBA8:  return 4;

		case GPU_RGB8:   return 3;

		case GPU_RGBA5551:
		case GPU_RGB565:
		case GPU_RGBA4:
		case GPU_LA8:    return 2;

		case GPU_A8:
		case GPU_LA4:    return 1;

		default:         return 4;
	}
}

static GPU_TEXCOLOR _determineHardwareFormat(GLenum format)
{
	switch(format)
	{	
		case 4:
		case GL_RGBA8: //return GPU_RGBA8;
		case GL_RGBA:
		case GL_RGBA4: return GPU_RGBA4;

		case 3:
		case GL_RGB8:
		case GL_RGB:
		case GL_RGB5:  return GPU_RGB565;

		case GL_ALPHA:
		case GL_LUMINANCE_ALPHA: return GPU_LA4;

		default: return GPU_RGBA4;
	}
}

static inline readFunc _determineReadFunction(GLenum format, GLenum type, uint8_t *bpp)
{
	switch (format) {
		case GL_ALPHA:
			switch (type) {
				case GL_UNSIGNED_BYTE: *bpp = 1; return _readA8;
				default:               return NULL;
			}
		case GL_LUMINANCE_ALPHA:
			switch (type) {
				case GL_UNSIGNED_BYTE: *bpp = 2; return _readLA8;
				default:               return NULL;
			}
		case GL_RGB:
			switch (type) {
				case GL_UNSIGNED_BYTE: *bpp = 3; return _readRGB8;
				default:               return NULL;
			}
		case GL_RGBA:
			switch (type) {
				case GL_UNSIGNED_BYTE: *bpp = 4; return _readRGBA8;
				default:               return NULL;
			}
		default:
			return NULL;
	}
}

static inline writeFunc _determineWriteFunction(GPU_TEXCOLOR format)
{
	switch (format) {
		case GPU_RGBA4:  return _writeRGBA4;
		case GPU_RGB565: return _writeRGB565;
		case GPU_LA8:    return _writeLA8;
		case GPU_LA4:    return _writeLA4;
		case GPU_A8:     return _writeA8;
		default:         return NULL;
	}
}

static inline uint32_t _picaConvertWrap(uint32_t param)
{
	switch(param)
	{
		case GL_CLAMP:
		case GL_CLAMP_TO_EDGE: return GPU_CLAMP_TO_EDGE;
		case GL_REPEAT: return GPU_REPEAT;
		case GL_MIRRORED_REPEAT: return GPU_MIRRORED_REPEAT;
		default: return GPU_REPEAT;
	}
}

static inline uint32_t _picaConvertFilter(uint32_t param)
{
	switch(param)
	{	
		case GL_LINEAR_MIPMAP_LINEAR:
		case GL_LINEAR: return GPU_LINEAR;
		
		case GL_NEAREST_MIPMAP_NEAREST:
		case GL_NEAREST: return GPU_NEAREST;

		default: return GL_LINEAR;
	}
}

static inline void *_textureDataAlloc(size_t size)
{
	void *ret = NULL;

	if(size > 0x800)
		ret = vramAlloc(size);

	if(!ret)
		ret = linearAlloc(size); 

	return ret;
}

static inline void _textureDataFree(TextureObject *texture)
{
	if(texture->in_vram)
		vramFree(texture->data);
	else
		linearFree(texture->data);

	texture->data = NULL;
}

//Borrowed from citra
static inline uint32_t _mortonInterleave(uint32_t x, uint32_t y)
{
    static uint32_t xlut[] = {0x00, 0x01, 0x04, 0x05, 0x10, 0x11, 0x14, 0x15};
    static uint32_t ylut[] = {0x00, 0x02, 0x08, 0x0a, 0x20, 0x22, 0x28, 0x2a};

    return xlut[x % 8] + ylut[y % 8];
}

#define BLOCK_HEIGHT 8

static inline uint32_t _getMortonOffset(uint32_t x, uint32_t y)
{
	uint32_t coarse_x = x & ~7;

	u32 i = _mortonInterleave(x, y);

	uint32_t offset = coarse_x * BLOCK_HEIGHT;

	return (i + offset);
}

static inline void _textureTile(TextureObject *texture, GLint xoffset, GLint yoffset, GLsizei width, GLsizei height, const void* data, uint8_t bpp, readFunc readPixel, writeFunc writePixel)
{
	uint32_t texel, offset, output_y, coarse_y;

	void *tiled_output = texture->data;

	if(texture->in_vram)
	{
		tiled_output = linearAlloc(texture->width * texture->height * texture->bpp);

		if(!tiled_output)
			return;

		if(xoffset || yoffset)
		{
			_queueWaitAndClear();
			GX_TextureCopy(texture->data, 0, tiled_output, 0, texture->width * texture->height * texture->bpp, 8);
			_queueRun(false);
			
			_textureDataFree(texture);

			texture->data = tiled_output;
			texture->in_vram = false;
		}
	}

	for(int y = 0; y < height; y++)
	{
		output_y = texture->height - 1 - (y + yoffset);
		coarse_y = output_y & ~7;

		for(int x = 0; x < width; x++)
		{
			offset = (_getMortonOffset(x + xoffset, output_y) + coarse_y * texture->width) * texture->bpp;
			texel = readPixel(data + ((x + (y * width)) * bpp));

			writePixel(tiled_output + offset, texel);
		}
	}

	GSPGPU_FlushDataCache(tiled_output, texture->width * texture->height * texture->bpp);

	if(texture->in_vram)
	{
		_queueWaitAndClear();
		GX_TextureCopy(tiled_output, 0, texture->data, 0, texture->width * texture->height * texture->bpp, 8);
		_queueRun(false);
		
		linearFree(tiled_output);
	}
}

void glActiveTexture(GLenum texture)
{
	uint8_t texunit = texture & 0x01;

	if(texunit > 1)
		texunit = 0;

	pglState->texUnitActive = texunit;
}

void glClientActiveTexture( GLenum texture )
{
	uint8_t texunit = texture & 0x01;

	if(texunit > 1)
		texunit = 0;

	pglState->texUnitActiveClient = texunit;
}

void glTexImage2D(GLenum target, GLint level, GLint internalFormat, GLsizei width, GLsizei height, GLint border, GLenum format, GLenum type, const GLvoid* data)
{
	if(level != 0 || target != GL_TEXTURE_2D)
		return;

	TextureObject *texture = pglState->textureBound[pglState->texUnitActive];
	texture->used = true;

	if(texture->data)
		_textureDataFree(texture);

	texture->format = _determineHardwareFormat(internalFormat);
	texture->bpp 	= _determineBPP(texture->format);
	texture->width  = width;
	texture->height = height;
	texture->data   = _textureDataAlloc(width * height * texture->bpp);

	if(texture->data == NULL)
		return;

	if(_addressIsVRAM(texture->data))
		texture->in_vram = true;
	else
		texture->in_vram = false;

	pglState->textureChanged = GL_TRUE;
	pglState->changes |= STATE_TEXTURE_CHANGE;

	if(!data) return;

	uint8_t offset_bpp = 0;

	readFunc readPixel   = _determineReadFunction(format, type, &offset_bpp);
	writeFunc writePixel = _determineWriteFunction(texture->format);

	if(readPixel && writePixel && data)
		_textureTile(texture, 0, 0, width, height, data, offset_bpp, readPixel, writePixel);
}

void glTexSubImage2D(GLenum target, GLint level, GLint xoffset, GLint yoffset, GLsizei width, GLsizei height, GLenum format, GLenum type, const GLvoid* data)
{
	if(level != 0 || target != GL_TEXTURE_2D || data == NULL)
		return;

	TextureObject *texture = pglState->textureBound[pglState->texUnitActive];

	if(texture->data == NULL)
		return;

	uint8_t offset_bpp = 0;

	readFunc readPixel   = _determineReadFunction(format, type, &offset_bpp);
	writeFunc writePixel = _determineWriteFunction(texture->format);

	if(readPixel && writePixel)
		_textureTile(texture, xoffset, yoffset, width, height, data, offset_bpp, readPixel, writePixel);

	pglState->textureChanged = GL_TRUE;
	pglState->changes |= STATE_TEXTURE_CHANGE;
}

void glTexParameterf(GLenum target, GLenum pname, GLfloat param)
{
	TextureObject *texture = pglState->textureBound[pglState->texUnitActive];

	uint32_t tex_param = texture->param;

	switch(pname)
	{
		case GL_TEXTURE_MAG_FILTER:
			tex_param = (tex_param & 0xFFFE) | GPU_TEXTURE_MAG_FILTER(_picaConvertFilter(param));
			break;
		case GL_TEXTURE_MIN_FILTER:
			tex_param = (tex_param & 0xFFFD) | GPU_TEXTURE_MIN_FILTER(_picaConvertFilter(param));
			break;
		case GL_TEXTURE_WRAP_T:
			tex_param = (tex_param & 0xFCFF) | GPU_TEXTURE_WRAP_T(_picaConvertWrap(param));
			break;
		case GL_TEXTURE_WRAP_S:
			tex_param = (tex_param & 0xCFFF) | GPU_TEXTURE_WRAP_S(_picaConvertWrap(param));
			break;
		default:
			return;
	}

	texture->param = tex_param;

	pglState->changes |= STATE_TEXTURE_CHANGE;
}

void glTexParameteri(GLenum target, GLenum pname, GLint param)
{
	GLfloat fparam = (GLfloat)param;
	glTexParameterf( target, pname, fparam );
}

void glBindTexture(GLenum target, GLuint texture)
{
	TextureObject *texObject;

	texObject = hashTableGet(&pglState->textureTable, texture);

	if(texObject == NULL)
	{
		texObject = malloc(sizeof(TextureObject));

		texObject->param  = GPU_TEXTURE_MAG_FILTER(GPU_LINEAR) | GPU_TEXTURE_WRAP_S(GPU_REPEAT) | GPU_TEXTURE_WRAP_T(GPU_REPEAT);
		texObject->width  = 0;
		texObject->height = 0;

		texObject->format = 0;
		texObject->data   = NULL;
		
		hashTableInsert(&pglState->textureTable, texture, texObject);
	}

	if(pglState->textureBound[pglState->texUnitActive] == texObject)
		return;

	pglState->textureBound[pglState->texUnitActive] = texObject;

	pglState->textureChanged = GL_TRUE;
	pglState->changes |= STATE_TEXTURE_CHANGE;
}

void glGenTextures(GLsizei n, GLuint *textures)
{
	TextureObject *texObject;
	int id;
	for(int i = 0; i < n; i++)
	{
		id = hashTableUniqueKey(&pglState->textureTable);
		texObject = malloc(sizeof(TextureObject));

		texObject->param  = GPU_TEXTURE_MAG_FILTER(GPU_LINEAR) | GPU_TEXTURE_WRAP_S(GPU_REPEAT) | GPU_TEXTURE_WRAP_T(GPU_REPEAT);
		texObject->width  = 0;
		texObject->height = 0;

		texObject->format = 0;
		texObject->data   = NULL;

		hashTableInsert(&pglState->textureTable, id, texObject);

		textures[i] = id;
	}
}

void glDeleteTextures(GLsizei n, const GLuint *textures)
{
	for(int i = 0; i < n; i++)
	{
		TextureObject *texObject = hashTableRemove(&pglState->textureTable, textures[i]);

		if(!texObject)
			continue;

		if(texObject->data)
			_textureDataFree(texObject);

		free(texObject);
	}
}

GLboolean glIsTexture( GLuint texture ) 
{ 
	if(texture == 0)
		return GL_FALSE;

	TextureObject *texObject = hashTableGet(&pglState->textureTable, texture);

	if(texObject)
		return GL_TRUE;

	return GL_FALSE;
}

void glTexImage1D(GLenum target, GLint level, GLint internalformat, GLsizei width, GLint border, GLenum format, GLenum type, const GLvoid *pixels)
{
	glTexImage2D( GL_TEXTURE_2D, level, internalformat, width, 1, border, format, type, pixels );
}

void glTexEnvfv( GLenum target, GLenum pname, const GLfloat *params )
{
	if ((target != GL_TEXTURE_ENV) || (pname != GL_TEXTURE_ENV_COLOR))
		return;

	uint8_t texunit = pglState->texUnitActive;
	TextureEnv *texenv  = &pglState->texenv[texunit];

	uint8_t r = (uint8_t)(params[0] * 255);
	uint8_t g = (uint8_t)(params[1] * 255);
	uint8_t b = (uint8_t)(params[2] * 255);
	uint8_t a = (uint8_t)(params[3] * 255);

	texenv->color = r | (g << 8) | (b << 16) | (a << 24);
	
	pglState->changes |= STATE_TEXTURE_CHANGE;
}

inline void glTexEnvi (GLenum target, GLenum pname, GLint param)
{
	if ((target != GL_TEXTURE_ENV) || (pname != GL_TEXTURE_ENV_MODE))
		return;
	
	uint8_t texunit = pglState->texUnitActive;
	TextureEnv *texenv  = &pglState->texenv[texunit];

	switch (param)
	{
	case GL_ADD:
		texenv->func_rgb = GPU_ADD;
		texenv->src_rgb  = GPU_TEVSOURCES(GPU_TEXTURE0 + texunit, texunit == 0 ? GPU_PRIMARY_COLOR : GPU_PREVIOUS, 0);
		texenv->op_rgb   = GPU_TEVOPERANDS(0, 0, 0);

		texenv->func_alpha = GPU_MODULATE;
		texenv->src_alpha  = GPU_TEVSOURCES(GPU_TEXTURE0 + texunit, texunit == 0 ? GPU_PRIMARY_COLOR : GPU_PREVIOUS, 0);
		texenv->op_alpha   = GPU_TEVOPERANDS(0, 0, 0);
		break;

	case GL_REPLACE:
		texenv->func_rgb = GPU_REPLACE;
		texenv->src_rgb  = GPU_TEVSOURCES(GPU_TEXTURE0 + texunit, 0, 0);
		texenv->op_rgb   = GPU_TEVOPERANDS(0, 0, 0);

		texenv->func_alpha = GPU_REPLACE;
		texenv->src_alpha  = GPU_TEVSOURCES(GPU_TEXTURE0 + texunit, 0, 0);
		texenv->op_alpha   = GPU_TEVOPERANDS(0, 0, 0);
		break;

	case GL_MODULATE:
		texenv->func_rgb = GPU_MODULATE;
		texenv->src_rgb  = GPU_TEVSOURCES(GPU_TEXTURE0 + texunit, texunit == 0 ? GPU_PRIMARY_COLOR : GPU_PREVIOUS, 0);
		texenv->op_rgb   = GPU_TEVOPERANDS(0, 0, 0);

		texenv->func_alpha = GPU_MODULATE;
		texenv->src_alpha  = GPU_TEVSOURCES(GPU_TEXTURE0 + texunit, texunit == 0 ? GPU_PRIMARY_COLOR : GPU_PREVIOUS, 0);
		texenv->op_alpha   = GPU_TEVOPERANDS(0, 0, 0);
		break;

	case GL_DECAL:
		texenv->func_rgb = GPU_INTERPOLATE;
		texenv->src_rgb  = GPU_TEVSOURCES(GPU_TEXTURE0 + texunit, texunit == 0 ? GPU_PRIMARY_COLOR : GPU_PREVIOUS, GPU_TEXTURE0 + texunit);
		texenv->op_rgb   = GPU_TEVOPERANDS(0, 0, GPU_TEVOP_RGB_SRC_ALPHA);

		texenv->func_alpha = GPU_REPLACE;
		texenv->src_alpha  = GPU_TEVSOURCES(GPU_PRIMARY_COLOR, 0, 0);
		texenv->op_alpha   = GPU_TEVOPERANDS(0, 0, 0);
		break;

	case GL_BLEND:
		texenv->func_rgb = GPU_INTERPOLATE;
		texenv->src_rgb  = GPU_TEVSOURCES(GPU_CONSTANT, texunit == 0 ? GPU_PRIMARY_COLOR : GPU_PREVIOUS,  GPU_TEXTURE0 + texunit);
		texenv->op_rgb   = GPU_TEVOPERANDS(0, 0, 0);

		texenv->func_alpha = GPU_MODULATE;
		texenv->src_alpha  = GPU_TEVSOURCES(GPU_TEXTURE0 + texunit, texunit == 0 ? GPU_PRIMARY_COLOR : GPU_PREVIOUS, 0);
		texenv->op_alpha   = GPU_TEVOPERANDS(0, 0, 0);
		break;

	default:
		break;
	}

	pglState->changes |= STATE_TEXTURE_CHANGE;
}

void glTexEnvf (GLenum target, GLenum pname, GLfloat param)
{
	glTexEnvi (target, pname, (int)param);
}