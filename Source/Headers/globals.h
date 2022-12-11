/****************************/
/*         MY GLOBALS       */
/* (c)2003 Pangea Software  */
/* By Brian Greenstone      */
/****************************/

#ifndef MYGLOBALS_H
#define MYGLOBALS_H


#define	kGameID 		'NAN2'

			/* SOME FLOATING POINT HELPERS */

#define EPS .0001					// a very small number which is useful for FP compares close to 0

#define GAME_CLAMP(x, lo, hi) ( (x) < (lo) ? (lo) : ( (x) > (hi) ? (hi) : (x) ) )
#define GAME_MIN(a, b) ( (a) < (b) ? (a) : (b) )
#define GAME_MAX(a, b) ( (a) > (b) ? (a) : (b) )
#define	SQUARED(x)					((x)*(x))






		/* CLOSE ENOUGH TO ZERO */
		//
		// If float value is close enough to 0, then make it 0
		//

#define	CLOSE_ENOUGH_TO_ZERO(theFloat)	if (fabs(theFloat) < EPS) theFloat = 0;


		/*******************/
		/* 2D ARRAY MACROS */
		/*******************/

#define Alloc_2d_array(type, array, n, m)								\
{																		\
uint32_t _i;															\
																		\
	array = (type **) AllocPtrClear((long)(n) * sizeof(type *));		\
	if (array == nil)													\
		DoFatalAlert("Alloc_2d_array failed!");							\
	array[0] = (type *) AllocPtrClear((long)(n) * (long)(m) * sizeof(type));	\
	if (array[0] == nil)												\
		DoFatalAlert("Alloc_2d_array failed!");							\
	for (_i = 1; _i < (uint32_t)(n); _i++)								\
		array[_i] = array[_i-1] + (m);									\
}


#define Free_2d_array(array)				\
{											\
		SafeDisposePtr((Ptr)array[0]);		\
		SafeDisposePtr((Ptr)array);			\
		array = nil;						\
}



#define	PI					((float)3.1415926535898)
#define PI2					(2.0f*PI)

#define	CHAR_ENTER			0x03
#define	CHAR_RETURN			0x0d	/* ASCII code for Return key */
#define CHAR_UP				0x1e
#define CHAR_DOWN			0x1f
#define	CHAR_LEFT			0x1c
#define	CHAR_RIGHT			0x1d
#define	CHAR_DELETE			0x08
#define	CHAR_APOSTROPHE		0x27


							// COLLISION SIDE INFO
							//=================================

#define	SIDE_BITS_TOP		(1)							// %000001	(r/l/b/t)
#define	SIDE_BITS_BOTTOM	(1<<1)						// %000010
#define	SIDE_BITS_LEFT		(1<<2)						// %000100
#define	SIDE_BITS_RIGHT		(1<<3)						// %001000
#define	SIDE_BITS_FRONT		(1<<4)						// %010000
#define	SIDE_BITS_BACK		(1<<5)						// %100000
#define	ALL_SOLID_SIDES		(SIDE_BITS_TOP|SIDE_BITS_BOTTOM|SIDE_BITS_LEFT|SIDE_BITS_RIGHT|\
							SIDE_BITS_FRONT|SIDE_BITS_BACK)


							// CBITS (32 BIT VALUES)
							//==================================

enum
{
	CBITS_TOP 			= SIDE_BITS_TOP,
	CBITS_BOTTOM 		= SIDE_BITS_BOTTOM,
	CBITS_LEFT 			= SIDE_BITS_LEFT,
	CBITS_RIGHT 		= SIDE_BITS_RIGHT,
	CBITS_FRONT 		= SIDE_BITS_FRONT,
	CBITS_BACK 			= SIDE_BITS_BACK,
	CBITS_ALLSOLID		= ALL_SOLID_SIDES,
	CBITS_NOTTOP		= SIDE_BITS_LEFT|SIDE_BITS_RIGHT|SIDE_BITS_FRONT|SIDE_BITS_BACK,
	CBITS_ALWAYSTRIGGER = (1<<6),
	CBITS_IMPENETRABLE	= (1<<7),	// set if object must have high collision priority and cannot be pushed thru this
	CBITS_IMPENETRABLE2	= (1<<8)	// set with CTYPE_IMPENETRABLE if dont want player to do coord=oldCoord when touched
};


							// CTYPES (32 BIT VALUES)
							//==================================

enum
{
	CTYPE_PLAYER1		=	1,			// Player 1
	CTYPE_PLAYER2		=	(1<<1),		// Player 2
	CTYPE_PLAYERSHIELD	=	(1<<2),	// player's shield
	CTYPE_TRIGGER2		=	(1<<3),		// Enemy Trigger
	CTYPE_TRIGGER		=	(1<<4),		// Trigger
	CTYPE_SKELETON		=	(1<<5),		// Skeleton
	CTYPE_MISC			=	(1<<6),		// Misc
	CTYPE_BLOCKSHADOW 	=	(1<<7),		// Shadows go over it
	CTYPE_WATER			=	(1<<8),		// if want to do auto water detect with HandleCollisions()
	CTYPE_POWERUP 		=	(1<<9),		// Powerup
	CTYPE_HURTME		= 	(1<<10),	// HURT ME
	CTYPE_HURTENEMY		= 	(1<<11),	// Hurt Enemy
	CTYPE_FENCE 		=	(1<<12),	// check fences
	CTYPE_TERRAIN		=	(1<<13),	// not an attribute, but just a flag passed to HandleCollisions()
	CTYPE_PICKUP		=	(1<<14),	// player can pick this up
	CTYPE_ENEMY 		=	(1<<15),	// enemy
	CTYPE_WEAPONTEST 	=	(1<<16),	// if can be hit by weapon bullets
	CTYPE_PLAYERTEST	=	(1<<17),	// if can be hit by player line-seg test
	CTYPE_AUTOTARGETWEAPON=	(1<<18),	// if auto target weapon fire
	CTYPE_BLOCKCAMERA 	=	(1<<19),	// camera goes over this
	CTYPE_EGG			= (1<<20),		// eggs
	CTYPE_xxx			= (1<<21),		//
	CTYPE_LOOKAT		= (1<<22),		// set if camera should do "look at"
	CTYPE_SOLIDTOENEMY	= (1<<23),		// solid to enemies
	CTYPE_PLAYERONLY	=	(1<<24)		// misc collision that only player can hit
};



							// OBJNODE STATUS BITS
							//==================================

enum
{
	STATUS_BIT_ONGROUND		=	1,			// Player is on anything solid (terrain or objnode)
	STATUS_BIT_NOTEXTUREWRAP =	(1<<1),		// if pin textures so they dont wrap
	STATUS_BIT_DONTCULL		=	(1<<2),		// set if don't want to perform custom culling on this object
	STATUS_BIT_NOCOLLISION  = 	(1<<3),		// set if want collision code to skip testing against this object
	STATUS_BIT_NOMOVE  		= 	(1<<4),		// dont call object's move function
	STATUS_BIT_DONTPURGE	= 	(1<<5),		// set if don't want object to get deleted when scrolls out of range
	STATUS_BIT_HIDDEN		=	(1<<6),		// dont draw object
	STATUS_BIT_DOUBLESIDED	=	(1<<7),	// keep both sides
	STATUS_BIT_UNDERWATER 	=	(1<<8),		// set if underwater
	STATUS_BIT_ROTXZY		=	(1<<9),		// set if want to do x->z->y ordered rotation
	STATUS_BIT_ROTYZX		=	(1<<10),
	STATUS_BIT_ROTZXY		= 	(1<<11),
	STATUS_BIT_USEALIGNMENTMATRIX=(1<<12),	// use AlignmentMatrix instead of Rot x,y,z for object alignment
	STATUS_BIT_MOVEINPAUSE	=	(1<<13),	// call objnode's move call even when game is paused
	STATUS_BIT_ONLYSHOWTHISPLAYER=(1<<14),	// set if only draw this object for this PlayerNum
	STATUS_BIT_CLIPALPHA6 	=	(1<<15), 	// set if want to not draw pixels with alpha <= .6
	STATUS_BIT_NOLIGHTING	=	(1<<16),	// used when want to render object will NULL shading (no lighting)
	STATUS_BIT_NOZBUFFER	=	(1<<17),	// set when want to turn off z buffer
	STATUS_BIT_NOZWRITES	=	(1<<18),	// set when want to turn off z buffer writes
	STATUS_BIT_NOFOG		=	(1<<19),
	STATUS_BIT_AUTOFADE		=	(1<<20),	// calculate fade xparency value for object when rendering
	STATUS_BIT_DETACHED		=	(1<<21),	// set if objnode is free-floating and not attached to linked list
	STATUS_BIT_ONSPLINE		=	(1<<22),	// if objnode is attached to spline
	STATUS_BIT_REVERSESPLINE =	(1<<23),	// if going reverse direction on spline
	STATUS_BIT_GLOW			=	(1<<24),			// use additive blending for glow effect
	STATUS_BIT_AIMATCAMERA	=	(1<<25),		// if need to aim at player's camera (for sprite billboards)
	STATUS_BIT_UVTRANSFORM	=	(1<<26),		// do uv transform on object when drawing
	STATUS_BIT_ISCULLED1	=	(1<<27),	// set if culling function deemed it culled for pane 1
	STATUS_BIT_ISCULLED2	=	(1<<28),	// set if culling function deemed it culled for pane 2
	STATUS_BIT_ISCULLED3	=	(1<<29),	// set if culling function deemed it culled for pane 3 (fullscreen overlay in 2P games)
};

#define STATUS_BITS_FOR_2D \
	(STATUS_BIT_NOTEXTUREWRAP \
	| STATUS_BIT_DONTCULL \
	| STATUS_BIT_NOZBUFFER \
	| STATUS_BIT_NOZWRITES \
	| STATUS_BIT_NOFOG \
	| STATUS_BIT_NOLIGHTING)

enum
{
	POW_TYPE_STUNPULSE,
	POW_TYPE_HEALTH,
	POW_TYPE_JUMPJET,
	POW_TYPE_FUEL,
	POW_TYPE_SUPERNOVA,
	POW_TYPE_FREEZE,
	POW_TYPE_MAGNET,
	POW_TYPE_GROWTH,
	POW_TYPE_FLAME,
	POW_TYPE_FLARE,
	POW_TYPE_DART,
	POW_TYPE_FREELIFE,

	NUM_POW_TYPES
};



#include "structs.h"

#endif










