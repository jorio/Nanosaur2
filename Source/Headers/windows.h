//
// windows.h
//

#define	DEFAULT_ANAGLYPH_R	0xd8
#define	DEFAULT_ANAGLYPH_G	0xa0
#define	DEFAULT_ANAGLYPH_B	0xff


		/* EXTERNS */

extern	int				gGameWindowWidth, gGameWindowHeight;
extern	Boolean			gPlayFullScreen;
extern	float			gGammaTweak;
extern	uint32_t			gDisplayVRAM, gVRAMAfterBuffers;

extern	SDL_Window*		gSDLWindow;


//==================================================

extern void	InitWindowStuff(void);
void MakeFadeEvent(Boolean fadeIn, float fadeSpeed);

void CleanupDisplay(void);
void GammaFadeOut(void);
void GammaFadeIn(void);
void GammaOn(void);
void GammaOff(void);

void Wait(uint32_t ticks);
void DoScreenModeDialog(void);

void Enter2D(void);
void Exit2D(void);

void DoAnaglyphCalibrationDialog(void);


