#pragma once
#include <string.h>
#include <stdbool.h>
#include <math.h>

#ifndef DEG_TO_RAD
#define DEG_TO_RAD(x) ((x) * M_PI / 180.0)
#endif
#define RAD_TO_RAD(x) ((x) * 180.0 / M_PI)

typedef union {
	struct { 
		float w, z, y, x; 
	};
	float column[4];
} vector4f;

typedef struct {
	vector4f row[4]; 
} matrix4x4;

static inline float v4f_dp4(const vector4f* a, const vector4f* b)
{
	return a->x*b->x + a->y*b->y + a->z*b->z + a->w*b->w;
}

static inline float v4f_mod4(const vector4f* a)
{
	return sqrtf(v4f_dp4(a,a));
}

static inline void v4f_norm4(vector4f* vec)
{
	float m = v4f_mod4(vec);
	if (m == 0.0) return;
	vec->x /= m;
	vec->y /= m;
	vec->z /= m;
	vec->w /= m;
}

static inline void matrix4x4_zeros(matrix4x4* out)
{
	memset(out, 0, sizeof(*out));
}

static inline void matrix4x4_copy(matrix4x4* out, const matrix4x4* in)
{
	memcpy(out, in, sizeof(*out));
}

static inline void matrix4x4_identity(matrix4x4* out)
{
	memset(out, 0, sizeof(*out));
	out->row[0].x = out->row[1].y = out->row[2].z = out->row[3].w = 1.0f;
}

void matrix4x4_multiply(matrix4x4* out, const matrix4x4* a, const matrix4x4* b);

void matrix4x4_translate(matrix4x4* mtx, float x, float y, float z);
void matrix4x4_scale(matrix4x4* mtx, float x, float y, float z);

void matrix4x4_rotate_x(matrix4x4* mtx, float angle, bool bRightSide);
void matrix4x4_rotate_y(matrix4x4* mtx, float angle, bool bRightSide);
void matrix4x4_rotate_z(matrix4x4* mtx, float angle, bool bRightSide);

// Special versions of the projection matrices that take the 3DS' screen orientation into account
void matrix4x4_ortho_tilt(matrix4x4* mtx, float left, float right, float bottom, float top, float near, float far);
void matrix4x4_frustum(matrix4x4 *mtx, float left, float right, float bottom, float top, float near, float far);
void matrix4x4_fix_projection(matrix4x4 *mtx);
