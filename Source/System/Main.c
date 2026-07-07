/****************************/
/*    NANOSAUR 2 - MAIN 	*/
/* By Brian Greenstone      */
/* (c)2003 Pangea Software  */
/* (c)2022 Iliyas Jorio     */
/****************************/

// All function implementations are now in Main.swift. gGamePrefs is the
// only global left here: Boot.cpp reads/writes gGamePrefs.antialiasingLevel
// directly, so PrefsType must stay a C-visible extern global.

#include "game.h"

PrefsType			gGamePrefs;
