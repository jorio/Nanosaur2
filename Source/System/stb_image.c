#include "game.h"		// AllocPtr, ReallocPtr, SafeDisposePtr

#define STB_IMAGE_IMPLEMENTATION
#define STBI_ONLY_JPEG
#define STBI_ONLY_PNG
#define STBI_MALLOC AllocPtr
#define STBI_REALLOC ReallocPtr
#define STBI_FREE SafeDisposePtr

#include "stb_image.h"
