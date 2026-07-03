/****************************/
/*   	PARTICLES.C		    */
/* (c)2003 Pangea Software  */
/* By Brian Greenstone      */
/****************************/

// All function implementations are now in Particles.swift. gNewParticleGroupDef
// stays here because LaserOrbs.c, Turrets.c, and Mines.c (all still unported)
// write to it directly via `extern`.

#include "game.h"

NewParticleGroupDefType	gNewParticleGroupDef;
