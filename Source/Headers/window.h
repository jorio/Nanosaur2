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

extern void	InitWindowStuff(void);
ObjNode* MakeFadeEvent(Byte fadeFlags, float fadeSpeed);

void OGL_FadeOutScene(void (*drawCall)(void), void (*moveCall)(void));

void Enter2D(void);
void Exit2D(void);

int GetNumDisplays(void);
void GetDefaultWindowSize(SDL_DisplayID display, int* width, int* height);
void SetFullscreenMode(bool enforceDisplayPref);
