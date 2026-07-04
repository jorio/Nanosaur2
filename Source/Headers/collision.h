//
// collision.h
//

#pragma once

enum
{
	COLLISION_TYPE_OBJ,						// box
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




//=================================









