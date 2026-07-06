#ifndef __glext_h_
#define __glext_h_

#ifdef __cplusplus
extern "C" {
#endif

#ifndef GL_ARB_multitexture
#define GL_TEXTURE0_ARB                   0x84C0
#define GL_TEXTURE1_ARB                   0x84C1
#define GL_TEXTURE2_ARB                   0x84C2
#define GL_TEXTURE3_ARB                   0x84C3
#define GL_TEXTURE4_ARB                   0x84C4
#define GL_TEXTURE5_ARB                   0x84C5
#define GL_TEXTURE6_ARB                   0x84C6
#define GL_TEXTURE7_ARB                   0x84C7
#define GL_TEXTURE8_ARB                   0x84C8
#define GL_TEXTURE9_ARB                   0x84C9
#define GL_TEXTURE10_ARB                  0x84CA
#define GL_TEXTURE11_ARB                  0x84CB
#define GL_TEXTURE12_ARB                  0x84CC
#define GL_TEXTURE13_ARB                  0x84CD
#define GL_TEXTURE14_ARB                  0x84CE
#define GL_TEXTURE15_ARB                  0x84CF
#define GL_TEXTURE16_ARB                  0x84D0
#define GL_TEXTURE17_ARB                  0x84D1
#define GL_TEXTURE18_ARB                  0x84D2
#define GL_TEXTURE19_ARB                  0x84D3
#define GL_TEXTURE20_ARB                  0x84D4
#define GL_TEXTURE21_ARB                  0x84D5
#define GL_TEXTURE22_ARB                  0x84D6
#define GL_TEXTURE23_ARB                  0x84D7
#define GL_TEXTURE24_ARB                  0x84D8
#define GL_TEXTURE25_ARB                  0x84D9
#define GL_TEXTURE26_ARB                  0x84DA
#define GL_TEXTURE27_ARB                  0x84DB
#define GL_TEXTURE28_ARB                  0x84DC
#define GL_TEXTURE29_ARB                  0x84DD
#define GL_TEXTURE30_ARB                  0x84DE
#define GL_TEXTURE31_ARB                  0x84DF
#define GL_ACTIVE_TEXTURE_ARB             0x84E0
#define GL_CLIENT_ACTIVE_TEXTURE_ARB      0x84E1
#define GL_MAX_TEXTURE_UNITS_ARB          0x84E2
#endif

#ifndef GL_EXT_compiled_vertex_array
#define GL_EXT_compiled_vertex_array 1
void glLockArraysEXT (GLint, GLsizei);
void glUnlockArraysEXT (void);
#endif

#ifndef GL_ARB_multitexture
#define GL_ARB_multitexture 1
void glActiveTextureARB (GLenum);
void glClientActiveTextureARB (GLenum);
void glMultiTexCoord1dARB (GLenum, GLdouble);
void glMultiTexCoord1dvARB (GLenum, const GLdouble *);
void glMultiTexCoord1fARB (GLenum, GLfloat);
void glMultiTexCoord1fvARB (GLenum, const GLfloat *);
void glMultiTexCoord1iARB (GLenum, GLint);
void glMultiTexCoord1ivARB (GLenum, const GLint *);
void glMultiTexCoord1sARB (GLenum, GLshort);
void glMultiTexCoord1svARB (GLenum, const GLshort *);
void glMultiTexCoord2dARB (GLenum, GLdouble, GLdouble);
void glMultiTexCoord2dvARB (GLenum, const GLdouble *);
void glMultiTexCoord2fARB (GLenum, GLfloat, GLfloat);
void glMultiTexCoord2fvARB (GLenum, const GLfloat *);
void glMultiTexCoord2iARB (GLenum, GLint, GLint);
void glMultiTexCoord2ivARB (GLenum, const GLint *);
void glMultiTexCoord2sARB (GLenum, GLshort, GLshort);
void glMultiTexCoord2svARB (GLenum, const GLshort *);
void glMultiTexCoord3dARB (GLenum, GLdouble, GLdouble, GLdouble);
void glMultiTexCoord3dvARB (GLenum, const GLdouble *);
void glMultiTexCoord3fARB (GLenum, GLfloat, GLfloat, GLfloat);
void glMultiTexCoord3fvARB (GLenum, const GLfloat *);
void glMultiTexCoord3iARB (GLenum, GLint, GLint, GLint);
void glMultiTexCoord3ivARB (GLenum, const GLint *);
void glMultiTexCoord3sARB (GLenum, GLshort, GLshort, GLshort);
void glMultiTexCoord3svARB (GLenum, const GLshort *);
void glMultiTexCoord4dARB (GLenum, GLdouble, GLdouble, GLdouble, GLdouble);
void glMultiTexCoord4dvARB (GLenum, const GLdouble *);
void glMultiTexCoord4fARB (GLenum, GLfloat, GLfloat, GLfloat, GLfloat);
void glMultiTexCoord4fvARB (GLenum, const GLfloat *);
void glMultiTexCoord4iARB (GLenum, GLint, GLint, GLint, GLint);
void glMultiTexCoord4ivARB (GLenum, const GLint *);
void glMultiTexCoord4sARB (GLenum, GLshort, GLshort, GLshort, GLshort);
void glMultiTexCoord4svARB (GLenum, const GLshort *);
#endif

#endif

#ifdef __cplusplus
}
#endif