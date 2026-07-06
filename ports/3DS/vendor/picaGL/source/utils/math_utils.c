#include "math_utils.h"
#include <stdio.h>

void matrix4x4_multiply(matrix4x4* out, const matrix4x4* a, const matrix4x4* b)
{
	int i, j;
	for (i = 0; i < 4; i ++)
		for (j = 0; j < 4; j ++)
			out->row[j].column[i] = a->row[j].x*b->row[0].column[i] + a->row[j].y*b->row[1].column[i] + a->row[j].z*b->row[2].column[i] + a->row[j].w*b->row[3].column[i];
}

void matrix4x4_translate(matrix4x4* mtx, float x, float y, float z)
{
	matrix4x4 tm, om;

	matrix4x4_identity(&tm);
	tm.row[0].w = x;
	tm.row[1].w = y;
	tm.row[2].w = z;

	matrix4x4_multiply(&om, mtx, &tm);
	matrix4x4_copy(mtx, &om);
}

void matrix4x4_scale(matrix4x4* mtx, float x, float y, float z)
{
	int i;
	for (i = 0; i < 4; i ++)
	{
		mtx->row[i].x *= x;
		mtx->row[i].y *= y;
		mtx->row[i].z *= z;
	}
}

void matrix4x4_rotate_x(matrix4x4* mtx, float angle, bool bRightSide)
{
	matrix4x4 rm, om;

	float cosAngle = cosf(angle);
	float sinAngle = sinf(angle);

	matrix4x4_zeros(&rm);
	rm.row[0].x = 1.0f;
	rm.row[1].y = cosAngle;
	rm.row[1].z = sinAngle;
	rm.row[2].y = -sinAngle;
	rm.row[2].z = cosAngle;
	rm.row[3].w = 1.0f;

	if (bRightSide) matrix4x4_multiply(&om, mtx, &rm);
	else            matrix4x4_multiply(&om, &rm, mtx);
	matrix4x4_copy(mtx, &om);
}

void matrix4x4_rotate_y(matrix4x4* mtx, float angle, bool bRightSide)
{
	matrix4x4 rm, om;

	float cosAngle = cosf(angle);
	float sinAngle = sinf(angle);

	matrix4x4_zeros(&rm);
	rm.row[0].x = cosAngle;
	rm.row[0].z = sinAngle;
	rm.row[1].y = 1.0f;
	rm.row[2].x = -sinAngle;
	rm.row[2].z = cosAngle;
	rm.row[3].w = 1.0f;

	if (bRightSide) matrix4x4_multiply(&om, mtx, &rm);
	else            matrix4x4_multiply(&om, &rm, mtx);
	matrix4x4_copy(mtx, &om);
}

void matrix4x4_rotate_z(matrix4x4* mtx, float angle, bool bRightSide)
{
	matrix4x4 rm, om;

	float cosAngle = cosf(angle);
	float sinAngle = sinf(angle);

	matrix4x4_zeros(&rm);
	rm.row[0].x = cosAngle;
	rm.row[0].y = sinAngle;
	rm.row[1].x = -sinAngle;
	rm.row[1].y = cosAngle;
	rm.row[2].z = 1.0f;
	rm.row[3].w = 1.0f;

	if (bRightSide) matrix4x4_multiply(&om, mtx, &rm);
	else            matrix4x4_multiply(&om, &rm, mtx);
	matrix4x4_copy(mtx, &om);
}

void matrix4x4_ortho_tilt(matrix4x4* mtx, float left, float right, float bottom, float top, float near, float far)
{
	matrix4x4 mp;
	matrix4x4_zeros(&mp);

	// Build standard orthogonal projection matrix
	mp.row[1].x = 2.0f / (left - right);
	mp.row[1].w = (left + right) / (right - left);
	mp.row[0].y = 2.0f / (top - bottom);
	mp.row[0].w = (bottom + top) / (bottom - top);
	mp.row[2].z = 2.0f / (near - far);
	mp.row[2].w = (far + near) / (far - near);
	mp.row[3].w = 1.0f;

	//Adjust depth range from [-1, 1] to [-1, 0]
	mp.row[2].z = (mp.row[2].z * 0.5f);
	mp.row[2].w = (mp.row[2].w * 0.5f) - 0.5f;

	matrix4x4_copy(mtx, &mp);
}

void matrix4x4_frustum(matrix4x4 *mtx, float left, float right, float bottom, float top, float near, float far)
{
	matrix4x4 mp;
	matrix4x4_zeros(&mp);

	mp.row[0].y = 2 * near / (top - bottom);
	mp.row[0].z = (right + left) / (right - left);
	mp.row[1].x = -2 * near / (right - left);
	mp.row[1].z = (top + bottom) / (top - bottom);
	mp.row[2].z = (far + near) / (far - near);
	mp.row[2].w = (2 * far * near) / (far - near);
	mp.row[3].z = -1.0f;

	//Adjust depth range from [-1, 1], to [-1, 0]
	mp.row[2].z = (-mp.row[2].z * 0.5f) + 0.5f;
	mp.row[2].w = (-mp.row[2].w * 0.5f);

	matrix4x4_copy(mtx, &mp);
}

void matrix4x4_fix_projection(matrix4x4 *mtx)
{
	mtx->row[2].z = mtx->row[2].z;
	mtx->row[2].w = mtx->row[2].w;
	
	matrix4x4 mp, mp2;
	matrix4x4_identity(&mp);
	mp.row[2].z = 0.5;
	mp.row[2].w = -0.5;
	matrix4x4_multiply(&mp2, &mp, mtx);

	matrix4x4_identity(&mp);
	mp.row[0].x = 0.0;
	mp.row[0].y = 1.0;
	mp.row[1].x = -1.0; // flipped
	mp.row[1].y = 0.0;
	matrix4x4_multiply(mtx, &mp, &mp2);
}