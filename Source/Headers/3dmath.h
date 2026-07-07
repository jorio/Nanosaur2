//
// 3DMath.h
//

#pragma once

#define OGLMath_RadiansToDegrees(x)	((float)((x) * 180.0f / PI))

// OGLPoint3D_DistanceToPlane/Distance/Transform/TransformArray/
// CalcBoundingBox are now plain OGLPoint3D methods in
// 3DMath_Geometry.swift - nothing in C calls them anymore, so they're no
// longer declared here.

// OGL_ComputeTrianglePlaneEquation/IntersectionOfLineSegAndPlane/
// IsPointInTriangle3D/IntersectLineSegments/CalcLineNormal2D/CalcRayNormal2D/
// ReflectVector2D/ReflectVector3D/OGLPoint2D_LineDistance/
// OGLBoundingBox_Transform/DecayToZero/OGL_IsBBoxVisible/CalcVectorLength/
// CalcVectorLength2D are now plain Swift-only functions in
// 3DMath_Geometry.swift/3DMath_Matrix.swift - nothing in C calls them
// anymore, so they're no longer declared here.

// ApplyFrictionToDeltas/ApplyFrictionToDeltasXZ/ApplyFrictionToRotation/
// VectorsAreCloseEnough/OGLVector3D_Cross/OGLVector3D_Dot/OGLVector3D_Normalize/
// OGLVector3D_Transform/OGLVector3D_TransformArray/OGLVector3D_MoveToVector are
// now plain OGLVector3D methods in 3DMath_Geometry.swift/3DMath_Angles.swift -
// nothing in C calls them anymore, so they're no longer declared here.

// IntersectionOfYAndPlane_Func/OGLPoint2D_Transform/OGLVector2D_Transform/
// OGLVector2D_Dot/OGLVector2D_Normalize/OGLVector2D_Cross/OGLPoint2D_Distance/
// OGLPoint3D_To4DTransformArray/OGLPoint2D_TransformArray are now plain
// Swift-only functions in 3DMath_Geometry.swift - nothing in C calls them
// anymore, so they're no longer declared here.

// OGLCreateFromToRotationMatrix/SetLookAtMatrix/SetLookAtMatrixAndTranslate/
// SetAlignmentMatrix/SetAlignmentMatrixWithZRot/OGLMatrix3x3_SetRotate/
// OGLMatrix3x3_SetIdentity/OGLMatrix3x3_Multiply/
// OGLMatrix3x3_SetRotateAboutPoint/OGLMatrix3x3_SetTranslate are now plain
// Swift-only functions in 3DMath_Matrix.swift - nothing in C calls them
// anymore, so they're no longer declared here.




/*********** INTERSECTION OF Y AND PLANE ********************/
//
// INPUT:
//			x/z		:	xz coords of point
//			p		:	ptr to the plane
//
//
// *** IMPORTANT-->  This function does not check for divides by 0!! As such, there should be no
//					"vertical" polygons (polys with normal->y == 0).
//

#define IntersectionOfYAndPlane(_x, _z, _p)	(((_p)->constant - (((_p)->normal.x * _x) + ((_p)->normal.z * _z))) / (_p)->normal.y)


/***************** ANGLE TO VECTOR ******************/
//
// Returns a normalized 2D vector based on a radian angle
//
// NOTE: +rotation == counter clockwise!
//

static inline void AngleToVector(float angle, OGLVector2D *theVector);

static inline void AngleToVector(float angle, OGLVector2D *theVector)
{
	theVector->x = -sin(angle);
	theVector->y = -cos(angle);
}



/******************** FAST RECIPROCAL **************************/
//
//   y1 = y0 + y0*(1 - num*y0), where y0 = recip_est(num)
//

#define FastReciprocal(_num,_out)		\
{										\
	float	_y0;						\
										\
	_y0 = __fres(_num);					\
	_out = _y0 * (1 - _num*_y0) + _y0;	\
}


/***************** FAST VECTOR LENGTH 3D/2D *********************/

#define VectorLength3D(_r, _inX, _inY, _inZ)	_r = sqrt((_inY*_inY) + (_inX*_inX) + (_inZ*_inZ));

#define VectorLength2D(_r, _inX, _inY)	_r = sqrt((_inY*_inY) + (_inX*_inX));



/******************** FAST NORMALIZE VECTOR ***********************/
//
// My special version here will use the frsqrte opcode if available.
// It does Newton-Raphson refinement to get a good result.
//

static inline void FastNormalizeVector(float vx, float vy, float vz, OGLVector3D *outV);

static inline void FastNormalizeVector(float vx, float vy, float vz, OGLVector3D *outV)
{
float	temp;

	if ((fabs(vx) <= EPS) && (fabs(vy) <= EPS) && (fabs(vz) <= EPS))		// check for zero length vectors
	{
		outV->x = outV->y = outV->z = 0;
		return;
	}

	temp = vx * vx;
	temp += vy * vy;
	temp += vz * vz;

#if defined (__ppc__)
{
	float	isqrt, temp1, temp2;

	isqrt = __frsqrte (temp);					// isqrt = first approximation of 1/sqrt()
	temp1 = temp * (float)(-.5);				// temp1 = -a / 2
	temp2 = isqrt * isqrt;						// temp2 = sqrt^2
	temp1 *= isqrt;								// temp1 = -a * sqrt / 2
	isqrt *= (float)(3.0/2.0);					// isqrt = 3 * sqrt / 2
	temp = isqrt + temp1 * temp2;				// isqrt = (3 * sqrt - a * sqrt^3) / 2
}
#else
	temp = 1.0 / sqrt(temp);
#endif

	outV->x = vx * temp;						// return results
	outV->y = vy * temp;
	outV->z = vz * temp;
}

/******************** FAST NORMALIZE VECTOR 2D ***********************/
//
// My special version here will use the frsqrte opcode if available.
// It does Newton-Raphson refinement to get a good result.
//

static inline void FastNormalizeVector2D(float vx, float vy, OGLVector2D *outV, Boolean errCheck);

static inline void FastNormalizeVector2D(float vx, float vy, OGLVector2D *outV, Boolean errCheck)
{
	if (errCheck)
	{
		if ((fabs(vx) <= EPS) && (fabs(vy) <= EPS))			// check for zero length vectors
		{
			outV->x = outV->y = 0;
			return;
		}
	}


float	temp;


	temp = vx * vx;
	temp += vy * vy;

#if defined (__ppc__)
{
float	isqrt, temp1, temp2;

	isqrt = __frsqrte (temp);					// isqrt = first approximation of 1/sqrt()
	temp1 = temp * (float)(-.5);				// temp1 = -a / 2
	temp2 = isqrt * isqrt;						// temp2 = sqrt^2
	temp1 *= isqrt;								// temp1 = -a * sqrt / 2
	isqrt *= (float)(3.0/2.0);					// isqrt = 3 * sqrt / 2
	temp = isqrt + temp1 * temp2;				// isqrt = (3 * sqrt - a * sqrt^3) / 2
}
#else
	temp = 1.0 / sqrt(temp);
#endif

	outV->x = vx * temp;						// return results
	outV->y = vy * temp;

}



/***************** CALC FACE NORMAL *********************/
//
// Returns the normal vector off the face defined by 3 points.
//

static inline void CalcFaceNormal(const OGLPoint3D *p1, const OGLPoint3D *p2, const OGLPoint3D *p3, OGLVector3D *normal);

static inline void CalcFaceNormal(const OGLPoint3D *p1, const OGLPoint3D *p2, const OGLPoint3D *p3, OGLVector3D *normal)
{
float		dx1,dx2,dy1,dy2,dz1,dz2;
float		x,y,z;

	dx1 = (p1->x - p3->x);
	dy1 = (p1->y - p3->y);
	dz1 = (p1->z - p3->z);
	dx2 = (p2->x - p3->x);
	dy2 = (p2->y - p3->y);
	dz2 = (p2->z - p3->z);


			/* DO CROSS PRODUCT */

	x =   dy1 * dz2 - dy2 * dz1;
	y =   dx2 * dz1 - dx1 * dz2;
	z =   dx1 * dy2 - dx2 * dy1;

			/* NORMALIZE IT */

	FastNormalizeVector(x,y, z, normal);
}

/***************** CALC FACE NORMAL: NOT NORMALIZED *********************/
//
// Returns the normal vector off the face defined by 3 points.
//

static inline void CalcFaceNormal_NotNormalized(const OGLPoint3D *p1, const OGLPoint3D *p2, const OGLPoint3D *p3, OGLVector3D *normal);

static inline void CalcFaceNormal_NotNormalized(const OGLPoint3D *p1, const OGLPoint3D *p2, const OGLPoint3D *p3, OGLVector3D *normal)
{
float		dx1,dx2,dy1,dy2,dz1,dz2;

	dx1 = (p1->x - p3->x);
	dy1 = (p1->y - p3->y);
	dz1 = (p1->z - p3->z);
	dx2 = (p2->x - p3->x);
	dy2 = (p2->y - p3->y);
	dz2 = (p2->z - p3->z);


			/* DO CROSS PRODUCT */

	normal->x =   dy1 * dz2 - dy2 * dz1;
	normal->y =   dx2 * dz1 - dx1 * dz2;
	normal->z =   dx1 * dy2 - dx2 * dy1;
}


/******************* CALC PLANE EQUATION OF TRIANGLE ********************/
//
// input points should be clockwise!
//

static inline void CalcPlaneEquationOfTriangle(OGLPlaneEquation *plane, const OGLPoint3D *p3, const OGLPoint3D *p2, const OGLPoint3D *p1);

static inline void CalcPlaneEquationOfTriangle(OGLPlaneEquation *plane, const OGLPoint3D *p3, const OGLPoint3D *p2, const OGLPoint3D *p1)
{
float	pq_x,pq_y,pq_z;
float	pr_x,pr_y,pr_z;
float	p1x,p1y,p1z;
float	x,y,z;

	p1x = p1->x;									// get point #1
	p1y = p1->y;
	p1z = p1->z;

	pq_x = p1x - p2->x;								// calc vector pq
	pq_y = p1y - p2->y;
	pq_z = p1z - p2->z;

	pr_x = p1->x - p3->x;							// calc vector pr
	pr_y = p1->y - p3->y;
	pr_z = p1->z - p3->z;


			/* CALC CROSS PRODUCT FOR THE FACE'S NORMAL */

	x = (pq_y * pr_z) - (pq_z * pr_y);				// cross product of edge vectors = face normal
	y = ((pq_z * pr_x) - (pq_x * pr_z));
	z = (pq_x * pr_y) - (pq_y * pr_x);

	FastNormalizeVector(x, y, z, &plane->normal);


		/* CALC DOT PRODUCT FOR PLANE CONSTANT */

	plane->constant = 	((plane->normal.x * p1x) +
						(plane->normal.y * p1y) +
						(plane->normal.z * p1z));
}


/************* CALC QUICK DISTANCE ****************/
//
// Does cheezeball quick distance calculation on 2 2D points.
//

static inline float CalcQuickDistance(float x1, float y1, float x2, float y2);

static inline float CalcQuickDistance(float x1, float y1, float x2, float y2)
{
float	diffX,diffY;

	diffX = fabs(x1-x2);
	diffY = fabs(y1-y2);

	if (diffX > diffY)
	{
		return(diffX + (0.375f*diffY));			// same as (3*diffY)/8
	}
	else
	{
		return(diffY + (0.375f*diffX));
	}

}

/************* CALC DISTANCE ****************/

static inline float CalcDistance(float x1, float y1, float x2, float y2);

static inline float CalcDistance(float x1, float y1, float x2, float y2)
{
float	diffX,diffY;

	diffX = fabs(x1-x2);
	diffY = fabs(y1-y2);

	return(sqrt(diffX*diffX + diffY*diffY));
}

/************* CALC DISTANCE 3D ****************/

static inline float CalcDistance3D(float x1, float y1, float z1, float x2, float y2, float z2);

static inline float CalcDistance3D(float x1, float y1, float z1, float x2, float y2, float z2)
{
float	diffX,diffY,diffZ;

	diffX = fabs(x1-x2);
	diffY = fabs(y1-y2);
	diffZ = fabs(z1-z2);

	return(sqrt(diffX*diffX + diffY*diffY + diffZ*diffZ));
}


/******************** MASK ANGLE ****************************/
//
// Given an arbitrary angle, it limits it to between 0 and 2*PI
//

static inline float MaskAngle(float angle);

static inline float MaskAngle(float angle)
{
int		n;
Boolean	neg;

	neg = angle < 0.0f;
	n = angle * (1.0f/PI2);						// see how many times it wraps fully
	angle -= ((float)n * PI2);					// subtract # wrappings to get just the remainder

	if (neg)
		angle += PI2;

	return(angle);
}

/****************** OGLVECTOR3D DOT NO PIN ******************/

static inline float OGLVector3D_Dot_NoPin(const OGLVector3D	*v1, const OGLVector3D	*v2);

static inline float OGLVector3D_Dot_NoPin(const OGLVector3D	*v1, const OGLVector3D	*v2)
{
float	dot;

	dot = ((v1->x * v2->x) + (v1->y * v2->y) + (v1->z * v2->z));		// calc dot

	return(dot);
}


/****************** OGLVECTOR3D DOT NO PIN DOUBLE ******************/
//
// Calculates with double precision
//

static inline double OGLVector3D_Dot_NoPinDouble(const OGLVector3D	*v1, const OGLVector3D	*v2);

static inline double OGLVector3D_Dot_NoPinDouble(const OGLVector3D	*v1, const OGLVector3D	*v2)
{
double	dot, v1x, v2x, v1y, v2y, v1z, v2z;

	v1x = v1->x;		v1y = v1->y;		v1z = v1->z;
	v2x = v2->x;		v2y = v2->y;		v2z = v2->z;


	dot = ((v1x * v2x) + (v1y * v2y) + (v1z * v2z));		// calc dot

	return(dot);
}


/****************** OGLVECTOR3D CROSS NO PIN ******************/

static inline void OGLVector3D_Cross_NoPin(const OGLVector3D* v1, const OGLVector3D* v2, OGLVector3D* result)
{
	float rx = (v1->y * v2->z) - (v1->z * v2->y);
	float ry = (v1->z * v2->x) - (v1->x * v2->z);
	float rz = (v1->x * v2->y) - (v1->y * v2->x);

	result->x = rx;
	result->y = ry;
	result->z = rz;
}

/********************* VECTOR 3D SUBTRACT **********************/

static inline void OGLVector3D_Subtract(OGLVector3D *v1, OGLVector3D *v2, OGLVector3D *newV);

static inline void OGLVector3D_Subtract(OGLVector3D *v1, OGLVector3D *v2, OGLVector3D *newV)
{
	newV->x = v1->x - v2->x;
	newV->y = v1->y - v2->y;
	newV->z = v1->z - v2->z;
}

/********************* POINT 3D SUBTRACT **********************/

static inline void OGLPoint3D_Subtract(const OGLPoint3D *v1, const OGLPoint3D *v2, OGLVector3D *newV);

static inline void OGLPoint3D_Subtract(const OGLPoint3D *v1, const OGLPoint3D *v2, OGLVector3D *newV)
{
	newV->x = v1->x - v2->x;
	newV->y = v1->y - v2->y;
	newV->z = v1->z - v2->z;
}

/************** OGL POINT3D/VECTOR3D ADD ******************/

#define OGLPoint3D_Vector3D_Add(_p, _v, _r)						  			\
		(_r)->x = (_p)->x + (_v)->x;										\
		(_r)->y = (_p)->y + (_v)->y;										\
		(_r)->z = (_p)->z + (_v)->z;



/************* OGL VECTOR3D SCALE ***********************/

#define OGLVector3D_Scale(_v1, _s, _v2)										\
		(_v2)->x = (_v1)->x * (_s);											\
		(_v2)->y = (_v1)->y * (_s);											\
		(_v2)->z = (_v1)->z * (_s);


// OGL_SetGluPerspectiveMatrix/OGL_SetGluLookAtMatrix/OGL_GluUnProject are now
// plain Swift-only functions in 3DMath_Matrix.swift - nothing in C calls
// them anymore, so they're no longer declared here.
