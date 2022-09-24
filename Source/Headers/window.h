//
// windows.h
//

#pragma once

#define	DEFAULT_ANAGLYPH_R	0xd8
#define	DEFAULT_ANAGLYPH_G	0xa0
#define	DEFAULT_ANAGLYPH_B	0xff


//==================================================

extern void	InitWindowStuff(void);
void MakeFadeEvent(Boolean fadeIn, float fadeSpeed);

void GammaFadeOut(void);
void GammaFadeIn(void);
void GammaOn(void);
void GammaOff(void);

void Wait(uint32_t ticks);
void DoScreenModeDialog(void);

void Enter2D(void);
void Exit2D(void);

void DoAnaglyphCalibrationDialog(void);
