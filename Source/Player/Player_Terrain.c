/*******************************/
/*   	PLAYER_TERRAIN.C	   */
/* (c)2003 Pangea Software     */
/* By Brian Greenstone         */
/*******************************/

// All function implementations are now in Player_Terrain.swift. gTargetMaxSpeed
// and gCurrentMaxSpeed stay here because they're accessed via accessor shims
// (PlayerInternal.h) from Player.swift, and nothing else needs to see the
// backing storage directly.

#include "game.h"

float	gTargetMaxSpeed[MAX_PLAYERS] = {PLAYER_NORMAL_MAX_SPEED, PLAYER_NORMAL_MAX_SPEED};
float	gCurrentMaxSpeed[MAX_PLAYERS] = {PLAYER_NORMAL_MAX_SPEED, PLAYER_NORMAL_MAX_SPEED};
