/****************************/
/*   		PICK.C    	    */
/* (c)2003 Pangea Software  */
/* By Brian Greenstone      */
/****************************/

// All function implementations are now in Pick.swift. gPickAllTrianglesAsDoubleSided
// stays here because Enemy_Raptor.c (still unported) reads/writes it directly
// via `extern`.

#include "game.h"

Boolean		gPickAllTrianglesAsDoubleSided = false;
