/****************************/
/*   	COLLISION.c		    */
/* (c)2003 Pangea Software  */
/* By Brian Greenstone      */
/****************************/

// All function implementations are now in Collision.swift

#include "game.h"

#define	MAX_COLLISIONS				60

CollisionRec	gCollisionList[MAX_COLLISIONS];
short			gNumCollisions = 0;
Byte			gTotalSides;
