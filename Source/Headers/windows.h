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
extern	u_long			gDisplayVRAM, gVRAMAfterBuffers;


//==================================================

extern void	InitWindowStuff(void);
extern void	DumpGWorld2(GWorldPtr, WindowPtr, Rect *);
extern void	DoLockPixels(GWorldPtr);
pascal void DoBold (DialogPtr dlogPtr, short item);
pascal void DoOutline (DialogPtr dlogPtr, short item);
void MakeFadeEvent(Boolean fadeIn, float fadeSpeed);
void DumpGWorld2(GWorldPtr thisWorld, WindowPtr thisWindow,Rect *destRect);
void DumpGWorldToGWorld(GWorldPtr thisWorld, GWorldPtr destWorld);

void CleanupDisplay(void);
void GammaFadeOut(void);
void GammaFadeIn(void);
void GammaOn(void);
void GammaOff(void);

void DoLockPixels(GWorldPtr world);
void DoScreenModeDialog(void);

void Wait(u_long ticks);
void DoScreenModeDialog(void);

void Enter2D(void);
void Exit2D(void);

void BuildControlMenu(WindowRef window, SInt32 controlSig, SInt32 id, Str255 textList[], short numItems, short defaultSelection);
void DoAnaglyphCalibrationDialog(void);


