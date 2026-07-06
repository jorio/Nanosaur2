#include <math.h>
#include <GL/gl.h>
#include <GL/glu.h>

void gluPerspective(float fovy, float aspect, float near, float far)
{
	float xmin, xmax, ymin, ymax;

	ymax = near * tan( fovy * M_PI / 360.0 );
	ymin = -ymax;

	xmin = ymin * aspect;
	xmax = ymax * aspect;

	glFrustum( xmin, xmax, ymin, ymax, near, far );
}