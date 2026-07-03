/****************************/
/*   	CONFETTI.C		    */
/* (c)2003 Pangea Software  */
/* By Brian Greenstone      */
/****************************/

// All function implementations are now in Confetti.swift. gNewConfettiGroupDef
// stays here because Trees.c and Player.c (still unported) write to it
// directly by name via `extern`.

#include "game.h"

NewConfettiGroupDefType	gNewConfettiGroupDef;
