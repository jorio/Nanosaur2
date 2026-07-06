#ifndef __gl_h_
#define __gl_h_

#ifdef __cplusplus
extern "C" {
#endif
/*
 * Datatypes
 */
typedef unsigned int  GLenum;
typedef unsigned char GLboolean;
typedef unsigned int  GLbitfield;
typedef void    GLvoid;
typedef signed char GLbyte;   /* 1-byte signed */
typedef short   GLshort;  /* 2-byte signed */
typedef int   GLint;    /* 4-byte signed */
typedef unsigned char GLubyte;  /* 1-byte unsigned */
typedef unsigned short  GLushort; /* 2-byte unsigned */
typedef unsigned int  GLuint;   /* 4-byte unsigned */
typedef int   GLsizei;  /* 4-byte signed */
typedef float   GLfloat;  /* single precision float */
typedef float   GLclampf; /* single precision float in [0,1] */
typedef double    GLdouble; /* double precision float */
typedef double    GLclampd; /* double precision float in [0,1] */


/*
 * Constants
 */

/* Boolean values */
#define GL_FALSE        0x0
#define GL_TRUE         0x1

/* Data types */
#define GL_BYTE         0x1400
#define GL_UNSIGNED_BYTE      0x1401
#define GL_SHORT        0x1402
#define GL_UNSIGNED_SHORT     0x1403
#define GL_INT          0x1404
#define GL_UNSIGNED_INT       0x1405
#define GL_FLOAT        0x1406
#define GL_2_BYTES        0x1407
#define GL_3_BYTES        0x1408
#define GL_4_BYTES        0x1409
#define GL_DOUBLE       0x140A

/* Primitives */
#define GL_POINTS       0x0000
#define GL_LINES        0x0001
#define GL_LINE_LOOP        0x0002
#define GL_LINE_STRIP       0x0003
#define GL_TRIANGLES        0x0004
#define GL_TRIANGLE_STRIP     0x0005
#define GL_TRIANGLE_FAN       0x0006
#define GL_QUADS        0x0007
#define GL_QUAD_STRIP       0x0008
#define GL_POLYGON        0x0009

/* Vertex Arrays */
#define GL_VERTEX_ARRAY       0x8074
#define GL_NORMAL_ARRAY       0x8075
#define GL_COLOR_ARRAY        0x8076
#define GL_TEXTURE_COORD_ARRAY      0x8078
#define GL_EDGE_FLAG_ARRAY      0x8079
#define GL_V2F          0x2A20
#define GL_V3F          0x2A21
#define GL_C4UB_V2F       0x2A22
#define GL_C4UB_V3F       0x2A23
#define GL_C3F_V3F        0x2A24
#define GL_N3F_V3F        0x2A25
#define GL_C4F_N3F_V3F        0x2A26
#define GL_T2F_V3F        0x2A27
#define GL_T4F_V4F        0x2A28
#define GL_T2F_C4UB_V3F       0x2A29
#define GL_T2F_C3F_V3F        0x2A2A
#define GL_T2F_N3F_V3F        0x2A2B
#define GL_T2F_C4F_N3F_V3F      0x2A2C
#define GL_T4F_C4F_N3F_V4F      0x2A2D

/* Matrix Mode */
#define GL_MATRIX_MODE        0x0BA0
#define GL_MODELVIEW        0x1700
#define GL_PROJECTION       0x1701
#define GL_TEXTURE        0x1702

/* Polygons */
#define GL_POINT        0x1B00
#define GL_LINE         0x1B01
#define GL_FILL         0x1B02
#define GL_CW         0x0900
#define GL_CCW          0x0901
#define GL_FRONT        0x0404
#define GL_BACK         0x0405
#define GL_CULL_FACE        0x0B44
#define GL_CULL_FACE_MODE     0x0B45
#define GL_FRONT_FACE       0x0B46
#define GL_POLYGON_OFFSET_POINT     0x2A01
#define GL_POLYGON_OFFSET_LINE      0x2A02
#define GL_POLYGON_OFFSET_FILL      0x8037

/* Display Lists */
#define GL_COMPILE        0x1300
#define GL_COMPILE_AND_EXECUTE      0x1301
#define GL_LIST_BASE        0x0B32
#define GL_LIST_INDEX       0x0B33
#define GL_LIST_MODE        0x0B30

/* Depth buffer */
#define GL_NEVER        0x0200
#define GL_LESS         0x0201
#define GL_EQUAL        0x0202
#define GL_LEQUAL       0x0203
#define GL_GREATER        0x0204
#define GL_NOTEQUAL       0x0205
#define GL_GEQUAL       0x0206
#define GL_ALWAYS       0x0207
#define GL_DEPTH_TEST       0x0B71
#define GL_DEPTH_BITS       0x0D56

/* Lighting */
#define GL_LIGHTING       0x0B50
#define GL_LIGHT0       0x4000
#define GL_LIGHT1       0x4001
#define GL_LIGHT2       0x4002
#define GL_LIGHT3       0x4003
#define GL_LIGHT4       0x4004
#define GL_LIGHT5       0x4005
#define GL_LIGHT6       0x4006
#define GL_LIGHT7       0x4007
#define GL_SPOT_EXPONENT      0x1205
#define GL_SPOT_CUTOFF        0x1206
#define GL_CONSTANT_ATTENUATION     0x1207
#define GL_LINEAR_ATTENUATION     0x1208
#define GL_QUADRATIC_ATTENUATION    0x1209
#define GL_AMBIENT        0x1200
#define GL_DIFFUSE        0x1201
#define GL_SPECULAR       0x1202
#define GL_SHININESS        0x1601
#define GL_EMISSION       0x1600
#define GL_POSITION       0x1203
#define GL_SPOT_DIRECTION     0x1204
#define GL_AMBIENT_AND_DIFFUSE      0x1602
#define GL_LIGHT_MODEL_TWO_SIDE     0x0B52
#define GL_LIGHT_MODEL_LOCAL_VIEWER   0x0B51
#define GL_LIGHT_MODEL_AMBIENT      0x0B53
#define GL_FRONT_AND_BACK     0x0408
#define GL_FLAT         0x1D00
#define GL_SMOOTH       0x1D01
#define GL_COLOR_MATERIAL     0x0B57
#define GL_NORMALIZE        0x0BA1

/* User clipping planes */
#define GL_CLIP_PLANE0        0x3000
#define GL_CLIP_PLANE1        0x3001
#define GL_CLIP_PLANE2        0x3002
#define GL_CLIP_PLANE3        0x3003
#define GL_CLIP_PLANE4        0x3004
#define GL_CLIP_PLANE5        0x3005

/* Accumulation buffer */
#define GL_ADD          0x0104

/* Alpha testing */
#define GL_ALPHA_TEST       0x0BC0
#define GL_ALPHA_TEST_REF     0x0BC2
#define GL_ALPHA_TEST_FUNC      0x0BC1

/* Blending */
#define GL_BLEND        0x0BE2
#define GL_BLEND_SRC        0x0BE1
#define GL_BLEND_DST        0x0BE0
#define GL_ZERO         0x0
#define GL_ONE          0x1
#define GL_SRC_COLOR        0x0300
#define GL_ONE_MINUS_SRC_COLOR      0x0301
#define GL_SRC_ALPHA        0x0302
#define GL_ONE_MINUS_SRC_ALPHA      0x0303
#define GL_DST_ALPHA        0x0304
#define GL_ONE_MINUS_DST_ALPHA      0x0305
#define GL_DST_COLOR        0x0306
#define GL_ONE_MINUS_DST_COLOR      0x0307
#define GL_SRC_ALPHA_SATURATE     0x0308

/* Fog */
#define GL_FOG          0x0B60
#define GL_FOG_MODE       0x0B65
#define GL_FOG_DENSITY        0x0B62
#define GL_FOG_COLOR        0x0B66
#define GL_FOG_START        0x0B63
#define GL_FOG_END        0x0B64
#define GL_LINEAR       0x2601
#define GL_EXP          0x0800
#define GL_EXP2         0x0801

/* Logic Ops */
#define GL_INVERT       0x150A

/* Stencil */
#define GL_STENCIL_TEST       0x0B90
#define GL_KEEP         0x1E00
#define GL_REPLACE        0x1E01
#define GL_INCR         0x1E02
#define GL_DECR         0x1E03

/* Buffers, Pixel Drawing/Reading */
#define GL_NONE         0x0
#define GL_LEFT         0x0406
#define GL_RIGHT        0x0407
#define GL_FRONT_LEFT       0x0400
#define GL_FRONT_RIGHT        0x0401
#define GL_BACK_LEFT        0x0402
#define GL_BACK_RIGHT       0x0403
#define GL_AUX0         0x0409
#define GL_AUX1         0x040A
#define GL_AUX2         0x040B
#define GL_AUX3         0x040C
#define GL_COLOR_INDEX        0x1900
#define GL_RED          0x1903
#define GL_GREEN        0x1904
#define GL_BLUE         0x1905
#define GL_ALPHA        0x1906
#define GL_LUMINANCE        0x1909
#define GL_LUMINANCE_ALPHA      0x190A
#define GL_ALPHA_BITS       0x0D55
#define GL_RED_BITS       0x0D52
#define GL_GREEN_BITS       0x0D53
#define GL_BLUE_BITS        0x0D54
#define GL_INDEX_BITS       0x0D51
#define GL_SUBPIXEL_BITS      0x0D50
#define GL_AUX_BUFFERS        0x0C00
#define GL_READ_BUFFER        0x0C02
#define GL_DRAW_BUFFER        0x0C01
#define GL_DOUBLEBUFFER       0x0C32
#define GL_STEREO       0x0C33
#define GL_BITMAP       0x1A00
#define GL_COLOR        0x1800
#define GL_DEPTH        0x1801
#define GL_STENCIL        0x1802
#define GL_DITHER       0x0BD0
#define GL_RGB          0x1907
#define GL_RGBA         0x1908

/* Implementation limits */
#define GL_MAX_MODELVIEW_STACK_DEPTH    0x0D36
#define GL_MAX_PROJECTION_STACK_DEPTH   0x0D38
#define GL_MAX_TEXTURE_STACK_DEPTH    0x0D39
#define GL_MAX_LIGHTS       0x0D31
#define GL_MAX_CLIP_PLANES      0x0D32
#define GL_MAX_TEXTURE_SIZE     0x0D33

/* Gets */
#define GL_INDEX_MODE       0x0C30
#define GL_MODELVIEW_MATRIX     0x0BA6
#define GL_PROJECTION_MATRIX      0x0BA7
#define GL_RGBA_MODE        0x0C31
#define GL_VIEWPORT       0x0BA2

/* Hints */
#define GL_FOG_HINT       0x0C54
#define GL_PERSPECTIVE_CORRECTION_HINT    0x0C50
#define GL_POLYGON_SMOOTH_HINT      0x0C53
#define GL_DONT_CARE        0x1100
#define GL_FASTEST        0x1101
#define GL_NICEST       0x1102

/* Scissor box */
#define GL_SCISSOR_TEST       0x0C11

/* Pixel Mode / Transfer */
#define GL_PACK_ALIGNMENT     0x0D05
#define GL_PACK_LSB_FIRST     0x0D01
#define GL_PACK_ROW_LENGTH      0x0D02
#define GL_PACK_SKIP_PIXELS     0x0D04
#define GL_PACK_SKIP_ROWS     0x0D03
#define GL_PACK_SWAP_BYTES      0x0D00
#define GL_UNPACK_ALIGNMENT     0x0CF5
#define GL_UNPACK_LSB_FIRST     0x0CF1
#define GL_UNPACK_ROW_LENGTH      0x0CF2
#define GL_UNPACK_SKIP_PIXELS     0x0CF4
#define GL_UNPACK_SKIP_ROWS     0x0CF3
#define GL_UNPACK_SWAP_BYTES      0x0CF0

/* Texture mapping */
#define GL_TEXTURE_ENV        0x2300
#define GL_TEXTURE_ENV_MODE     0x2200
#define GL_TEXTURE_1D       0x0DE0
#define GL_TEXTURE_2D       0x0DE1
#define GL_TEXTURE_WRAP_S     0x2802
#define GL_TEXTURE_WRAP_T     0x2803
#define GL_TEXTURE_MAG_FILTER     0x2800
#define GL_TEXTURE_MIN_FILTER     0x2801
#define GL_TEXTURE_ENV_COLOR      0x2201
#define GL_TEXTURE_GEN_S      0x0C60
#define GL_TEXTURE_GEN_T      0x0C61
#define GL_TEXTURE_GEN_MODE     0x2500
#define GL_TEXTURE_WIDTH      0x1000
#define GL_TEXTURE_HEIGHT     0x1001
#define GL_TEXTURE_GREEN_SIZE     0x805D
#define GL_NEAREST_MIPMAP_NEAREST   0x2700
#define GL_NEAREST_MIPMAP_LINEAR    0x2702
#define GL_LINEAR_MIPMAP_NEAREST    0x2701
#define GL_LINEAR_MIPMAP_LINEAR     0x2703
#define GL_OBJECT_LINEAR      0x2401
#define GL_OBJECT_PLANE       0x2501
#define GL_EYE_LINEAR       0x2400
#define GL_EYE_PLANE        0x2502
#define GL_SPHERE_MAP       0x2402
#define GL_DECAL        0x2101
#define GL_MODULATE       0x2100
#define GL_NEAREST        0x2600
#define GL_REPEAT       0x2901
#define GL_CLAMP        0x2900
#define GL_S          0x2000
#define GL_T          0x2001
#define GL_R          0x2002
#define GL_Q          0x2003
#define GL_TEXTURE_GEN_R      0x0C62
#define GL_TEXTURE_GEN_Q      0x0C63

/* Utility */
#define GL_VENDOR       0x1F00
#define GL_RENDERER       0x1F01
#define GL_VERSION        0x1F02
#define GL_EXTENSIONS       0x1F03

/* Errors */
#define GL_NO_ERROR         0x0
#define GL_INVALID_VALUE      0x0501
#define GL_INVALID_ENUM       0x0500
#define GL_INVALID_OPERATION      0x0502
#define GL_STACK_OVERFLOW     0x0503
#define GL_STACK_UNDERFLOW      0x0504
#define GL_OUT_OF_MEMORY      0x0505

/* glPush/PopAttrib bits */
#define GL_FOG_BIT        0x00000080
#define GL_DEPTH_BUFFER_BIT     0x00000100
#define GL_STENCIL_BUFFER_BIT     0x00000400
#define GL_VIEWPORT_BIT       0x00000800
#define GL_COLOR_BUFFER_BIT     0x00004000


/* OpenGL 1.1 */
#define GL_PROXY_TEXTURE_1D     0x8063
#define GL_PROXY_TEXTURE_2D     0x8064
#define GL_ALPHA8       0x803C
#define GL_LUMINANCE8       0x8040
#define GL_LUMINANCE8_ALPHA8      0x8045
#define GL_INTENSITY        0x8049
#define GL_INTENSITY8       0x804B
#define GL_RGB4         0x804F
#define GL_RGB5         0x8050
#define GL_RGB8         0x8051
#define GL_RGBA4        0x8056
#define GL_RGB5_A1      0x8057
#define GL_RGBA8        0x8058
#define GL_CLIENT_VERTEX_ARRAY_BIT    0x00000002

/* GL_ARB_imaging */
#define GL_CONSTANT_COLOR     0x8001
#define GL_ONE_MINUS_CONSTANT_COLOR   0x8002
#define GL_CONSTANT_ALPHA     0x8003
#define GL_ONE_MINUS_CONSTANT_ALPHA   0x8004
#define GL_FUNC_ADD       0x8006
#define GL_FUNC_SUBTRACT      0x800A
#define GL_FUNC_REVERSE_SUBTRACT    0x800B


/*
 * Miscellaneous
 */

void glClearColor( GLclampf red, GLclampf green, GLclampf blue, GLclampf alpha );
void glClear( GLbitfield mask );
void glColorMask( GLboolean red, GLboolean green, GLboolean blue, GLboolean alpha );
void glAlphaFunc( GLenum func, GLclampf ref );
void glBlendFunc( GLenum sfactor, GLenum dfactor );
void glBlendEquation(GLenum mode);
void glCullFace( GLenum mode );
void glFrontFace( GLenum mode );
void glPolygonMode( GLenum face, GLenum mode );
void glPolygonOffset( GLfloat factor, GLfloat units );
void glEdgeFlag( GLboolean flag );
void glEdgeFlagv( const GLboolean *flag );
void glScissor( GLint x, GLint y, GLsizei width, GLsizei height);
void glClipPlane( GLenum plane, const GLdouble *equation );
void glDrawBuffer( GLenum mode );
void glReadBuffer( GLenum mode );
void glEnable( GLenum cap );
void glDisable( GLenum cap );
GLboolean glIsEnabled( GLenum cap );

void glEnableClientState( GLenum cap );  /* 1.1 */
void glDisableClientState( GLenum cap );  /* 1.1 */

void glGetBooleanv( GLenum pname, GLboolean *params );
void glGetDoublev( GLenum pname, GLdouble *params );
void glGetFloatv( GLenum pname, GLfloat *params );
void glGetIntegerv( GLenum pname, GLint *params );


void glPushAttrib( GLbitfield mask );
void glPopAttrib( void );


void glPushClientAttrib( GLbitfield mask );  /* 1.1 */
void glPopClientAttrib( void );  /* 1.1 */


GLenum glGetError( void );
const GLubyte * glGetString( GLenum name );

void glFinish( void );
void glFlush( void );

void glHint( GLenum target, GLenum mode );


/*
 * Depth Buffer
 */

void glClearDepth( GLclampd depth );
void glDepthFunc( GLenum func );
void glDepthMask( GLboolean flag );
void glDepthRange( GLclampd near_val, GLclampd far_val );


/*
 * Transformation
 */

void glMatrixMode( GLenum mode );
void glOrtho( GLdouble left, GLdouble right, GLdouble bottom, GLdouble top, GLdouble near_val, GLdouble far_val );
void glFrustum( GLdouble left, GLdouble right, GLdouble bottom, GLdouble top, GLdouble near_val, GLdouble far_val );
void glViewport( GLint x, GLint y, GLsizei width, GLsizei height );
void glPushMatrix( void );
void glPopMatrix( void );
void glLoadIdentity( void );
void glLoadMatrixd( const GLdouble *m );
void glLoadMatrixf( const GLfloat *m );
void glMultMatrixd( const GLdouble *m );
void glMultMatrixf( const GLfloat *m );
void glRotated( GLdouble angle, GLdouble x, GLdouble y, GLdouble z );
void glRotatef( GLfloat angle, GLfloat x, GLfloat y, GLfloat z );

void glScaled( GLdouble x, GLdouble y, GLdouble z );
void glScalef( GLfloat x, GLfloat y, GLfloat z );

void glTranslated( GLdouble x, GLdouble y, GLdouble z );
void glTranslatef( GLfloat x, GLfloat y, GLfloat z );


/*
 * Display Lists
 */

GLboolean glIsList( GLuint list );
void glDeleteLists( GLuint list, GLsizei range );
GLuint glGenLists( GLsizei range );
void glNewList( GLuint list, GLenum mode );
void glEndList( void );
void glCallList( GLuint list );
void glCallLists( GLsizei n, GLenum type, const GLvoid *lists );
void glListBase( GLuint base );


/*
 * Drawing Functions
 */

void glBegin( GLenum mode );

void glEnd( void );


void glVertex2d( GLdouble x, GLdouble y );
void glVertex2f( GLfloat x, GLfloat y );
void glVertex2i( GLint x, GLint y );
void glVertex2s( GLshort x, GLshort y );

void glVertex3d( GLdouble x, GLdouble y, GLdouble z );
void glVertex3f( GLfloat x, GLfloat y, GLfloat z );
void glVertex3i( GLint x, GLint y, GLint z );
void glVertex3s( GLshort x, GLshort y, GLshort z );

void glVertex4d( GLdouble x, GLdouble y, GLdouble z, GLdouble w );
void glVertex4f( GLfloat x, GLfloat y, GLfloat z, GLfloat w );
void glVertex4i( GLint x, GLint y, GLint z, GLint w );
void glVertex4s( GLshort x, GLshort y, GLshort z, GLshort w );

void glVertex2dv( const GLdouble *v );
void glVertex2fv( const GLfloat *v );
void glVertex2iv( const GLint *v );
void glVertex2sv( const GLshort *v );

void glVertex3dv( const GLdouble *v );
void glVertex3fv( const GLfloat *v );
void glVertex3iv( const GLint *v );
void glVertex3sv( const GLshort *v );

void glVertex4dv( const GLdouble *v );
void glVertex4fv( const GLfloat *v );
void glVertex4iv( const GLint *v );
void glVertex4sv( const GLshort *v );


void glNormal3b( GLbyte nx, GLbyte ny, GLbyte nz );
void glNormal3d( GLdouble nx, GLdouble ny, GLdouble nz );
void glNormal3f( GLfloat nx, GLfloat ny, GLfloat nz );
void glNormal3i( GLint nx, GLint ny, GLint nz );
void glNormal3s( GLshort nx, GLshort ny, GLshort nz );

void glNormal3bv( const GLbyte *v );
void glNormal3dv( const GLdouble *v );
void glNormal3fv( const GLfloat *v );
void glNormal3iv( const GLint *v );
void glNormal3sv( const GLshort *v );


void glColor3b( GLbyte red, GLbyte green, GLbyte blue );
void glColor3d( GLdouble red, GLdouble green, GLdouble blue );
void glColor3f( GLfloat red, GLfloat green, GLfloat blue );
void glColor3i( GLint red, GLint green, GLint blue );
void glColor3s( GLshort red, GLshort green, GLshort blue );
void glColor3ub( GLubyte red, GLubyte green, GLubyte blue );
void glColor3ui( GLuint red, GLuint green, GLuint blue );
void glColor3us( GLushort red, GLushort green, GLushort blue );

void glColor4b( GLbyte red, GLbyte green, GLbyte blue, GLbyte alpha );
void glColor4d( GLdouble red, GLdouble green, GLdouble blue, GLdouble alpha );
void glColor4f( GLfloat red, GLfloat green, GLfloat blue, GLfloat alpha );
void glColor4i( GLint red, GLint green, GLint blue, GLint alpha );
void glColor4s( GLshort red, GLshort green, GLshort blue, GLshort alpha );
void glColor4ub( GLubyte red, GLubyte green, GLubyte blue, GLubyte alpha );
void glColor4ui( GLuint red, GLuint green, GLuint blue, GLuint alpha );
void glColor4us( GLushort red, GLushort green, GLushort blue, GLushort alpha );


void glColor3bv( const GLbyte *v );
void glColor3dv( const GLdouble *v );
void glColor3fv( const GLfloat *v );
void glColor3iv( const GLint *v );
void glColor3sv( const GLshort *v );
void glColor3ubv( const GLubyte *v );
void glColor3uiv( const GLuint *v );
void glColor3usv( const GLushort *v );

void glColor4bv( const GLbyte *v );
void glColor4dv( const GLdouble *v );
void glColor4fv( const GLfloat *v );
void glColor4iv( const GLint *v );
void glColor4sv( const GLshort *v );
void glColor4ubv( const GLubyte *v );
void glColor4uiv( const GLuint *v );
void glColor4usv( const GLushort *v );


void glTexCoord1d( GLdouble s );
void glTexCoord1f( GLfloat s );
void glTexCoord1i( GLint s );
void glTexCoord1s( GLshort s );

void glTexCoord2d( GLdouble s, GLdouble t );
void glTexCoord2f( GLfloat s, GLfloat t );
void glTexCoord2i( GLint s, GLint t );
void glTexCoord2s( GLshort s, GLshort t );

void glTexCoord3d( GLdouble s, GLdouble t, GLdouble r );
void glTexCoord3f( GLfloat s, GLfloat t, GLfloat r );
void glTexCoord3i( GLint s, GLint t, GLint r );
void glTexCoord3s( GLshort s, GLshort t, GLshort r );

void glTexCoord4d( GLdouble s, GLdouble t, GLdouble r, GLdouble q );
void glTexCoord4f( GLfloat s, GLfloat t, GLfloat r, GLfloat q );
void glTexCoord4i( GLint s, GLint t, GLint r, GLint q );
void glTexCoord4s( GLshort s, GLshort t, GLshort r, GLshort q );

void glTexCoord1dv( const GLdouble *v );
void glTexCoord1fv( const GLfloat *v );
void glTexCoord1iv( const GLint *v );
void glTexCoord1sv( const GLshort *v );

void glTexCoord2dv( const GLdouble *v );
void glTexCoord2fv( const GLfloat *v );
void glTexCoord2iv( const GLint *v );
void glTexCoord2sv( const GLshort *v );

void glTexCoord3dv( const GLdouble *v );
void glTexCoord3fv( const GLfloat *v );
void glTexCoord3iv( const GLint *v );
void glTexCoord3sv( const GLshort *v );

void glTexCoord4dv( const GLdouble *v );
void glTexCoord4fv( const GLfloat *v );
void glTexCoord4iv( const GLint *v );
void glTexCoord4sv( const GLshort *v );


void glRectd( GLdouble x1, GLdouble y1, GLdouble x2, GLdouble y2 );
void glRectf( GLfloat x1, GLfloat y1, GLfloat x2, GLfloat y2 );
void glRecti( GLint x1, GLint y1, GLint x2, GLint y2 );
void glRects( GLshort x1, GLshort y1, GLshort x2, GLshort y2 );


void glRectdv( const GLdouble *v1, const GLdouble *v2 );
void glRectfv( const GLfloat *v1, const GLfloat *v2 );
void glRectiv( const GLint *v1, const GLint *v2 );
void glRectsv( const GLshort *v1, const GLshort *v2 );


/*
 * Vertex Arrays  (1.1)
 */

void glVertexPointer( GLint size, GLenum type, GLsizei stride, const GLvoid *ptr );
void glNormalPointer( GLenum type, GLsizei stride, const GLvoid *ptr );
void glColorPointer( GLint size, GLenum type, GLsizei stride, const GLvoid *ptr );
void glTexCoordPointer( GLint size, GLenum type, GLsizei stride, const GLvoid *ptr );
void glEdgeFlagPointer( GLsizei stride, const GLvoid *ptr );
void glArrayElement( GLint i );
void glDrawArrays( GLenum mode, GLint first, GLsizei count );
void glDrawElements( GLenum mode, GLsizei count, GLenum type, const GLvoid *indices );
void glInterleavedArrays( GLenum format, GLsizei stride, const GLvoid *pointer );

/*
 * Lighting
 */

void glShadeModel( GLenum mode );
void glLightf( GLenum light, GLenum pname, GLfloat param );
void glLighti( GLenum light, GLenum pname, GLint param );
void glLightfv( GLenum light, GLenum pname, const GLfloat *params );
void glLightiv( GLenum light, GLenum pname, const GLint *params );
void glLightModelf( GLenum pname, GLfloat param );
void glLightModeli( GLenum pname, GLint param );
void glLightModelfv( GLenum pname, const GLfloat *params );
void glLightModeliv( GLenum pname, const GLint *params );
void glMaterialf( GLenum face, GLenum pname, GLfloat param );
void glMateriali( GLenum face, GLenum pname, GLint param );
void glMaterialfv( GLenum face, GLenum pname, const GLfloat *params );
void glMaterialiv( GLenum face, GLenum pname, const GLint *params );
void glColorMaterial( GLenum face, GLenum mode );


/*
 * Raster functions
 */

void glPixelStoref( GLenum pname, GLfloat param );
void glPixelStorei( GLenum pname, GLint param );
void glReadPixels( GLint x, GLint y, GLsizei width, GLsizei height, GLenum format, GLenum type, GLvoid *pixels );

/*
 * Stenciling
 */

void glStencilFunc( GLenum func, GLint ref, GLuint mask );
void glStencilMask( GLuint mask );
void glStencilOp( GLenum fail, GLenum zfail, GLenum zpass );
void glClearStencil( GLint s );



/*
 * Texture mapping
 */

void glTexGend( GLenum coord, GLenum pname, GLdouble param );
void glTexGenf( GLenum coord, GLenum pname, GLfloat param );
void glTexGeni( GLenum coord, GLenum pname, GLint param );

void glTexGendv( GLenum coord, GLenum pname, const GLdouble *params );
void glTexGenfv( GLenum coord, GLenum pname, const GLfloat *params );
void glTexGeniv( GLenum coord, GLenum pname, const GLint *params );

void glTexEnvf( GLenum target, GLenum pname, GLfloat param );
void glTexEnvi( GLenum target, GLenum pname, GLint param );

void glTexEnvfv( GLenum target, GLenum pname, const GLfloat *params );
void glTexEnviv( GLenum target, GLenum pname, const GLint *params );

void glTexParameterf( GLenum target, GLenum pname, GLfloat param );
void glTexParameteri( GLenum target, GLenum pname, GLint param );

void glTexParameterfv( GLenum target, GLenum pname, const GLfloat *params );
void glTexParameteriv( GLenum target, GLenum pname, const GLint *params );

void glGetTexLevelParameterfv( GLenum target, GLint level, GLenum pname, GLfloat *params );
void glGetTexLevelParameteriv( GLenum target, GLint level, GLenum pname, GLint *params );

void glTexImage1D( GLenum target, GLint level, GLint internalFormat, GLsizei width, GLint border, GLenum format, GLenum type, const GLvoid *pixels );
void glTexImage2D( GLenum target, GLint level, GLint internalFormat, GLsizei width, GLsizei height, GLint border, GLenum format, GLenum type, const GLvoid *pixels );

void glGetTexImage( GLenum target, GLint level, GLenum format, GLenum type, GLvoid *pixels );


/* 1.1 functions */

void glGenTextures( GLsizei n, GLuint *textures );
void glDeleteTextures( GLsizei n, const GLuint *textures);
void glBindTexture( GLenum target, GLuint texture );
GLboolean glIsTexture( GLuint texture );
void glTexSubImage1D( GLenum target, GLint level, GLint xoffset, GLsizei width, GLenum format, GLenum type, const GLvoid *pixels );
void glTexSubImage2D( GLenum target, GLint level, GLint xoffset, GLint yoffset, GLsizei width, GLsizei height, GLenum format, GLenum type, const GLvoid *pixels );
void glCopyTexSubImage2D( GLenum target, GLint level, GLint xoffset, GLint yoffset, GLint x, GLint y, GLsizei width, GLsizei height );


/*
 * Fog
 */

void glFogf( GLenum pname, GLfloat param );
void glFogi( GLenum pname, GLint param );
void glFogfv( GLenum pname, const GLfloat *params );
void glFogiv( GLenum pname, const GLint *params );


/*
 * OpenGL 1.2
 */

#define GL_RESCALE_NORMAL     0x803A
#define GL_CLAMP_TO_EDGE      0x812F
#define GL_BGR          0x80E0
#define GL_BGRA         0x80E1
#define GL_UNSIGNED_SHORT_5_5_5_1       0x8034
#define GL_UNSIGNED_SHORT_5_6_5     	0x8363
#define GL_UNSIGNED_SHORT_5_6_5_REV     0x8364
#define GL_UNSIGNED_SHORT_4_4_4_4_REV   0x8365
#define GL_UNSIGNED_SHORT_1_5_5_5_REV   0x8366
#define GL_UNSIGNED_INT_8_8_8_8_REV   0x8367
#define GL_LIGHT_MODEL_COLOR_CONTROL    0x81F8
#define GL_SINGLE_COLOR       0x81F9
#define GL_SEPARATE_SPECULAR_COLOR    0x81FA
#define GL_TEXTURE_MAX_LEVEL      0x813D

void glDrawRangeElements( GLenum mode, GLuint start, GLuint end, GLsizei count, GLenum type, const GLvoid *indices );



/*
 * OpenGL 1.3
 */

/* multitexture */
#define GL_TEXTURE0         0x84C0
#define GL_TEXTURE1         0x84C1
#define GL_TEXTURE2         0x84C2
#define GL_TEXTURE3         0x84C3
#define GL_TEXTURE4         0x84C4
#define GL_TEXTURE5         0x84C5
#define GL_TEXTURE6         0x84C6
#define GL_TEXTURE7         0x84C7
#define GL_TEXTURE8         0x84C8
#define GL_TEXTURE9         0x84C9
#define GL_TEXTURE10        0x84CA
#define GL_TEXTURE11        0x84CB
#define GL_TEXTURE12        0x84CC
#define GL_TEXTURE13        0x84CD
#define GL_TEXTURE14        0x84CE
#define GL_TEXTURE15        0x84CF
#define GL_TEXTURE16        0x84D0
#define GL_TEXTURE17        0x84D1
#define GL_TEXTURE18        0x84D2
#define GL_TEXTURE19        0x84D3
#define GL_TEXTURE20        0x84D4
#define GL_TEXTURE21        0x84D5
#define GL_TEXTURE22        0x84D6
#define GL_TEXTURE23        0x84D7
#define GL_TEXTURE24        0x84D8
#define GL_TEXTURE25        0x84D9
#define GL_TEXTURE26        0x84DA
#define GL_TEXTURE27        0x84DB
#define GL_TEXTURE28        0x84DC
#define GL_TEXTURE29        0x84DD
#define GL_TEXTURE30        0x84DE
#define GL_TEXTURE31        0x84DF
#define GL_MAX_TEXTURE_UNITS      0x84E2
/* texture_cube_map */
#define GL_NORMAL_MAP       0x8511
#define GL_REFLECTION_MAP     0x8512
/* texture_compression */
#define GL_TEXTURE_COMPRESSED_IMAGE_SIZE  0x86A0
#define GL_TEXTURE_COMPRESSED     0x86A1
/* texture_env_combine */
#define GL_COMBINE        0x8570
/* texture_border_clamp */
#define GL_CLAMP_TO_BORDER      0x812D

void glActiveTexture( GLenum texture );
void glClientActiveTexture( GLenum texture );
void glMultiTexCoord1d( GLenum target, GLdouble s );
void glMultiTexCoord1dv( GLenum target, const GLdouble *v );
void glMultiTexCoord1f( GLenum target, GLfloat s );
void glMultiTexCoord1fv( GLenum target, const GLfloat *v );
void glMultiTexCoord1i( GLenum target, GLint s );
void glMultiTexCoord1iv( GLenum target, const GLint *v );
void glMultiTexCoord1s( GLenum target, GLshort s );
void glMultiTexCoord1sv( GLenum target, const GLshort *v );
void glMultiTexCoord2d( GLenum target, GLdouble s, GLdouble t );
void glMultiTexCoord2dv( GLenum target, const GLdouble *v );
void glMultiTexCoord2f( GLenum target, GLfloat s, GLfloat t );
void glMultiTexCoord2fv( GLenum target, const GLfloat *v );
void glMultiTexCoord2i( GLenum target, GLint s, GLint t );
void glMultiTexCoord2iv( GLenum target, const GLint *v );
void glMultiTexCoord2s( GLenum target, GLshort s, GLshort t );
void glMultiTexCoord2sv( GLenum target, const GLshort *v );
void glMultiTexCoord3d( GLenum target, GLdouble s, GLdouble t, GLdouble r );
void glMultiTexCoord3dv( GLenum target, const GLdouble *v );
void glMultiTexCoord3f( GLenum target, GLfloat s, GLfloat t, GLfloat r );
void glMultiTexCoord3fv( GLenum target, const GLfloat *v );
void glMultiTexCoord3i( GLenum target, GLint s, GLint t, GLint r );
void glMultiTexCoord3iv( GLenum target, const GLint *v );
void glMultiTexCoord3s( GLenum target, GLshort s, GLshort t, GLshort r );
void glMultiTexCoord3sv( GLenum target, const GLshort *v );
void glMultiTexCoord4d( GLenum target, GLdouble s, GLdouble t, GLdouble r, GLdouble q );
void glMultiTexCoord4dv( GLenum target, const GLdouble *v );
void glMultiTexCoord4f( GLenum target, GLfloat s, GLfloat t, GLfloat r, GLfloat q );
void glMultiTexCoord4fv( GLenum target, const GLfloat *v );
void glMultiTexCoord4i( GLenum target, GLint s, GLint t, GLint r, GLint q );
void glMultiTexCoord4iv( GLenum target, const GLint *v );
void glMultiTexCoord4s( GLenum target, GLshort s, GLshort t, GLshort r, GLshort q );
void glMultiTexCoord4sv( GLenum target, const GLshort *v );


/*
 * More extensions
 */
#define GL_MIRRORED_REPEAT      0x8370
#define GL_FOG_COORDINATE_SOURCE    0x8450
#define GL_FOG_COORDINATE     0x8451
#define GL_FRAGMENT_DEPTH     0x8452
#define GL_FOG_COORDINATE_ARRAY     0x8457
#define GL_COLOR_SUM        0x8458
#define GL_SECONDARY_COLOR_ARRAY    0x845E
#define GL_MAX_TEXTURE_LOD_BIAS     0x84FD
#define GL_TEXTURE_FILTER_CONTROL   0x8500
#define GL_TEXTURE_LOD_BIAS     0x8501
#define GL_CLIP_VOLUME_CLIPPING_HINT_EXT  0x80F0
#define GL_INCR_WRAP_EXT      0x8507
#define GL_DECR_WRAP_EXT      0x8508

void glFogCoordf (GLfloat);
void glFogCoordfv (const GLfloat *);
void glFogCoordd (GLdouble);
void glFogCoorddv (const GLdouble *);
void glFogCoordPointer (GLenum, GLsizei, const GLvoid *);

void glSecondaryColor3b (GLbyte, GLbyte, GLbyte);
void glSecondaryColor3bv (const GLbyte *);
void glSecondaryColor3d (GLdouble, GLdouble, GLdouble);
void glSecondaryColor3dv (const GLdouble *);
void glSecondaryColor3f (GLfloat, GLfloat, GLfloat);
void glSecondaryColor3fv (const GLfloat *);
void glSecondaryColor3i (GLint, GLint, GLint);
void glSecondaryColor3iv (const GLint *);
void glSecondaryColor3s (GLshort, GLshort, GLshort);
void glSecondaryColor3sv (const GLshort *);
void glSecondaryColor3ub (GLubyte, GLubyte, GLubyte);
void glSecondaryColor3ubv (const GLubyte *);
void glSecondaryColor3ui (GLuint, GLuint, GLuint);
void glSecondaryColor3uiv (const GLuint *);
void glSecondaryColor3us (GLushort, GLushort, GLushort);
void glSecondaryColor3usv (const GLushort *);
void glSecondaryColorPointer (GLint, GLenum, GLsizei, const GLvoid *);

void glBlendFuncSeparate (GLenum, GLenum, GLenum, GLenum);

void glLockArraysEXT (GLint, GLsizei);
void glUnlockArraysEXT (void);

void glPolygonOffsetEXT (GLfloat, GLfloat);

void glCompressedTexImage1D( GLenum target, GLint level, GLenum internalformat, GLsizei width, GLint border, GLsizei imageSize, const GLvoid *data );
void glCompressedTexImage2D( GLenum target, GLint level, GLenum internalformat, GLsizei width, GLsizei height, GLint border, GLsizei imageSize, const GLvoid *data );
void glCompressedTexImage3D( GLenum target, GLint level, GLenum internalformat, GLsizei width, GLsizei height, GLsizei depth, GLint border, GLsizei imageSize, const GLvoid *data );
void glCompressedTexSubImage1D( GLenum target, GLint level, GLint xoffset, GLsizei width, GLenum format, GLsizei imageSize, const GLvoid *data );
void glCompressedTexSubImage2D( GLenum target, GLint level, GLint xoffset, GLint yoffset, GLsizei width, GLsizei height, GLenum format, GLsizei imageSize, const GLvoid *data );
void glCompressedTexSubImage3D( GLenum target, GLint level, GLint xoffset, GLint yoffset, GLint zoffset, GLsizei width, GLsizei height, GLsizei depth, GLenum format, GLsizei imageSize, const GLvoid *data );
void glGetCompressedTexImage( GLenum target, GLint lod, GLvoid *img );

#ifdef __cplusplus
}
#endif

#include <GL/glext.h>

#endif