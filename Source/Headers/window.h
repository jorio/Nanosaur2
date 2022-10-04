//
// windows.h
//

#pragma once

#define	DEFAULT_ANAGLYPH_R	0xd8
#define	DEFAULT_ANAGLYPH_G	0xa0
#define	DEFAULT_ANAGLYPH_B	0xff


//==================================================

extern void	InitWindowStuff(void);
ObjNode* MakeFadeEvent(Boolean fadeIn, float fadeSpeed);

void OGL_FadeOutScene(void (*drawCall)(void), void (*moveCall)(void));

void Enter2D(void);
void Exit2D(void);

void DoAnaglyphCalibrationDialog(void);

void SetFullscreenMode(bool enforceDisplayPref);
