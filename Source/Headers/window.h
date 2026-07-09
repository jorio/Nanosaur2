//
// windows.h
//

#pragma once

#define	DEFAULT_ANAGLYPH_R	0xd8
#define	DEFAULT_ANAGLYPH_G	0xa0
#define	DEFAULT_ANAGLYPH_B	0xff


//==================================================

enum
{
	kFadeFlags_Out		= 0x00,
	kFadeFlags_In		= 0x01,
	kFadeFlags_P1		= 0x10,
	kFadeFlags_P2		= 0x20,
};



void Enter2D(void);
void Exit2D(void);
