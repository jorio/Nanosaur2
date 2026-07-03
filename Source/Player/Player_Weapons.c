/****************************/
/*   	PLAYER_WEAPONS.C    */
/* (c)2003 Pangea Software  */
/* By Brian Greenstone      */
/****************************/

// All function implementations are now in Player_Weapons.swift. gAutoFireDelay
// stays here because Player_Terrain.c (still unported) reads/writes it
// directly by name via `extern`.

#include "game.h"

float	gAutoFireDelay[MAX_PLAYERS] = {0,0};
