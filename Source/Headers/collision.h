//
// collision.h
//

#ifndef COLL_H
#define COLL_H

enum
{
	COLLISION_TYPE_OBJ,						// box
	COLLISION_TYPE_TILE
};




					/* COLLISION STRUCTURES */
struct CollisionRec
{
	Byte			baseBox,targetBox;
	unsigned short	sides;
	Byte			type;
	ObjNode			*objectPtr;			// object that collides with (if object type)
	float			planeIntersectY;	// where intersected triangle
};
typedef struct CollisionRec CollisionRec;



				/* EXTERNS */

extern	short			gNumCollisions;
extern	CollisionRec	gCollisionList[];
extern   Byte			gTotalSides;


//=================================

void CollisionDetect(ObjNode *baseNode, u_long CType, short startNumCollisions);

Byte HandleCollisions(ObjNode *theNode, u_long cType, float deltaBounce);
extern	Boolean IsPointInPoly2D( float,  float ,  Byte ,  OGLPoint2D *);
extern	Boolean IsPointInTriangle(float pt_x, float pt_y, float x0, float y0, float x1, float y1, float x2, float y2);
short DoSimplePointCollision(OGLPoint3D *thePoint, u_long cType, ObjNode *except);
short DoSimpleBoxCollision(float top, float bottom, float left, float right,
						float front, float back, u_long cType);



Boolean DoSimplePointCollisionAgainstPlayer(short playerNum, OGLPoint3D *thePoint);
Boolean DoSimpleBoxCollisionAgainstPlayer(short playerNum, float top, float bottom, float left, float right,
										float front, float back);
Boolean DoSimpleBoxCollisionAgainstObject(float top, float bottom, float left, float right,
										float front, float back, ObjNode *targetNode);
float FindHighestCollisionAtXZ(float x, float z, u_long cType);



Boolean	HandleLineSegmentCollision(const OGLLineSegment *lineSeg, ObjNode **hitObj, OGLPoint3D *hitPt,
									OGLVector3D *hitNormal, u_long *cTypes, Boolean	allowBBoxTests);

Boolean	HandleRayCollision(OGLRay *ray, ObjNode **hitObj, OGLPoint3D *hitPt,OGLVector3D *hitNormal, u_long *cTypes);

#endif



