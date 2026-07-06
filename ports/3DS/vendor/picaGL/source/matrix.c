#include "internal.h"

void glLoadIdentity(void)
{
	matrix4x4 *matrix = pglState->matrix_current;

	matrix4x4_zeros(matrix);
	matrix->row[0].x = matrix->row[1].y = matrix->row[2].z = matrix->row[3].w = 1.0f;
	
	pglState->changes |= STATE_MATRIX_CHANGE;
}

void glTranslatef(GLfloat x,  GLfloat y,  GLfloat z)
{
	matrix4x4 *matrix = pglState->matrix_current;

	matrix4x4_translate(matrix, x, y, z);
	pglState->changes |= STATE_MATRIX_CHANGE;
}

void glScalef(GLfloat x, GLfloat y, GLfloat z)
{
	matrix4x4 *matrix = pglState->matrix_current;

	matrix4x4_scale(matrix, x, y, z);
	pglState->changes |= STATE_MATRIX_CHANGE;
}

void glRotatef(GLfloat angle,  GLfloat x,  GLfloat y,  GLfloat z)
{
	matrix4x4 *matrix = pglState->matrix_current;

	if (x == 1.0f)
		matrix4x4_rotate_x(matrix, -DEG_TO_RAD(angle), true);

	if (y == 1.0f)
		matrix4x4_rotate_y(matrix,  DEG_TO_RAD(angle), true);
	
	if (z == 1.0f)
		matrix4x4_rotate_z(matrix, -DEG_TO_RAD(angle), true);

	pglState->changes |= STATE_MATRIX_CHANGE;
}

void glMatrixMode(GLenum mode)
{
	if(mode == GL_MODELVIEW)
		pglState->matrix_current = &pglState->matrix_modelview;
	else
		pglState->matrix_current = &pglState->matrix_projection;

	pglState->changes |= STATE_MATRIX_CHANGE;
}

void glOrtho(GLdouble left, GLdouble right, GLdouble bottom, GLdouble top, GLdouble near_val, GLdouble far_val)
{
	matrix4x4 *matrix = pglState->matrix_current;

	matrix4x4_ortho_tilt(matrix, (float)left, (float)right, (float)bottom, (float)top, (float)near_val, (float)far_val);
	pglState->changes |= STATE_MATRIX_CHANGE;
}

void glFrustum(GLdouble left, GLdouble right, GLdouble bottom, GLdouble top, GLdouble nearVal, GLdouble farVal)
{
	matrix4x4 *matrix = pglState->matrix_current;

	matrix4x4_frustum(matrix, (float)left, (float)right, (float)bottom, (float)top, (float)nearVal, (float)farVal);
	pglState->changes |= STATE_MATRIX_CHANGE;
}

void glPopMatrix(void)
{	
	matrix4x4 *matrix = pglState->matrix_current;

	if(matrix == &pglState->matrix_projection)
	{
		matrix4x4_copy(matrix, &pglState->matrix_projection_stack[pglState->matrix_projection_stack_counter]);
		if(pglState->matrix_projection_stack_counter > 0)
			--pglState->matrix_projection_stack_counter;
	}
	else
	{
		matrix4x4_copy(matrix, &pglState->matrix_modelview_stack[pglState->matrix_modelview_stack_counter]);
		if(pglState->matrix_modelview_stack_counter > 0)
			--pglState->matrix_modelview_stack_counter;
	}

	pglState->changes |= STATE_MATRIX_CHANGE;
}

void glPushMatrix(void)
{
	matrix4x4 *matrix = pglState->matrix_current;

	if(matrix == &pglState->matrix_projection)
	{
		if(pglState->matrix_projection_stack_counter < (MATRIX_STACK_SIZE - 1))
			++pglState->matrix_projection_stack_counter;

		matrix4x4_copy(&pglState->matrix_projection_stack[pglState->matrix_projection_stack_counter], matrix);
	}
	else
	{
		if(pglState->matrix_modelview_stack_counter < (MATRIX_STACK_SIZE - 1))
			++pglState->matrix_modelview_stack_counter;

		matrix4x4_copy(&pglState->matrix_modelview_stack[pglState->matrix_modelview_stack_counter], matrix);
	}

	pglState->changes |= STATE_MATRIX_CHANGE;
}

void glLoadMatrixf(const GLfloat* m)
{
	matrix4x4 *matrix = pglState->matrix_current;
	
	for(int i = 0; i < 4; i++)
	{
		matrix->row[i].x = m[0 + i];
		matrix->row[i].y = m[4 + i];
		matrix->row[i].z = m[8 + i];
		matrix->row[i].w = m[12 + i];
	}

	if(matrix == &pglState->matrix_projection)
	{
		matrix4x4_fix_projection(matrix);
	}

	pglState->changes |= STATE_MATRIX_CHANGE;
}

void glMultMatrixf(const GLfloat *m)
{
	matrix4x4 in, tmp;
	
	for(int i = 0; i < 4; i++)
	{
		in.row[i].x = m[0 + i];
		in.row[i].y = m[4 + i];
		in.row[i].z = m[8 + i];
		in.row[i].w = m[12 + i];
	}

	matrix4x4_multiply(&tmp, pglState->matrix_current, &in);

	*pglState->matrix_current = tmp;

	pglState->changes |= STATE_MATRIX_CHANGE;
}