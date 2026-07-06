// SDL3/SDL_opengl.h - minimal 3DS stub. Real game.h/local headers use these
// scalar GL typedefs purely as type aliases for plain struct fields
// (OGLPoint3D.x, MOMaterialObject's texture name, etc.) - no real GL calls
// are declared here (those get replaced with citro2d/citro3d in Phase 3).
#pragma once

typedef float GLfloat;
typedef unsigned int GLuint;
typedef int GLint;
typedef unsigned int GLenum;
typedef unsigned int GLbitfield;
typedef unsigned char GLboolean;
