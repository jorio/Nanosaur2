#include "internal.h"

const GLubyte* glGetString(GLenum name)
{
	switch(name)
	{
		case GL_RENDERER:
			return (GLubyte*)"DMP(R) PICA200";
		case GL_VERSION:
			return (GLubyte*)"1.1";
		case GL_VENDOR:
			return (GLubyte*)"MasterFeizz";
		default: 
			return (GLubyte*)"";
	}
}

void glGetIntegerv(GLenum pname, GLint *params)
{
	switch(pname) 
	{
		case GL_MAX_TEXTURE_SIZE:
			*params = 128;
	}
}