/****************************/
/*   	PLAYER.C   			*/
/* By Brian Greenstone      */
/* (c)2004 Pangea Software  */
/* (c)2022 Iliyas Jorio     */
/****************************/

// All function implementations are now in Player.swift. gNumPlayers,
// gPlayerInfo, gDeathTimer, and gPlayerIsDead stay here because many
// still-unported C files (and already-ported Contrails.swift,
// Player_Race.swift, File.swift, etc.) read/write them directly via `extern`.

#include "game.h"

Byte			gNumPlayers = 1;				// 2 if split-screen, otherwise 1

PlayerInfoType	gPlayerInfo[MAX_PLAYERS];

float	gDeathTimer[MAX_PLAYERS] = {0,0};

Boolean	gPlayerIsDead[MAX_PLAYERS] = {false, false};
