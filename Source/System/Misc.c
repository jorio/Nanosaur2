/****************************/
/*      MISC ROUTINES       */
/* (c)2003 Pangea Software  */
/* By Brian Greenstone      */
/****************************/


/***************/
/* EXTERNALS   */
/***************/

#include <string.h>
#include <stdio.h>
#include <stdarg.h>
#include "game.h"


/****************************/
/*    CONSTANTS             */
/****************************/

#define		ERROR_ALERT_ID		401

#define	MAX_FPS				190
#define	DEFAULT_FPS			13


/**********************/
/*     VARIABLES      */
/**********************/

long	gRAMAlloced = 0;

uint32_t 	gSeed0 = 0, gSeed1 = 0, gSeed2 = 0;

float	gFramesPerSecond = DEFAULT_FPS;
float	gFramesPerSecondFrac = 1.0f / DEFAULT_FPS;

int		gNumPointers = 0;


/**********************/
/*     PROTOTYPES     */
/**********************/


/*********************** DO ALERT *******************/

void DoAlert(const char* format, ...)
{
	Enter2D();

	char message[1024];
	va_list args;
	va_start(args, format);
	vsnprintf(message, sizeof(message), format, args);
	va_end(args);

	printf("Nanosaur 2 Alert: %s\n", message);
	SDL_ShowSimpleMessageBox(SDL_MESSAGEBOX_ERROR, "Nanosaur 2", message, /*gSDLWindow*/NULL);

	Exit2D();
}


/*********************** DO FATAL ALERT *******************/

void DoFatalAlert(const char* format, ...)
{
	Enter2D();

	char message[1024];
	va_list args;
	va_start(args, format);
	vsnprintf(message, sizeof(message), format, args);
	va_end(args);

	printf("Nanosaur 2 Fatal Alert: %s\n", message);
	SDL_ShowSimpleMessageBox(SDL_MESSAGEBOX_ERROR, "Nanosaur 2", message, /*gSDLWindow*/NULL);

	Exit2D();
	CleanQuit();
}


/************ CLEAN QUIT ***************/

void CleanQuit(void)
{
static Boolean	beenHere = false;


	if (!beenHere)
	{
		beenHere = true;

		SavePrefs();									// save prefs before bailing

		DeleteAllObjects();
		DisposeTerrain();								// dispose of any memory allocated by terrain manager
		DisposeAllBG3DContainers();						// nuke all models
		DisposeAllSpriteGroups();						// nuke all sprites

		if (gGameViewInfoPtr)							// see if need to dispose this
			OGL_DisposeGameView();

		OGL_Shutdown();

		ShutdownSound();								// cleanup sound stuff
	}

	SDL_ShowCursor(1);
	MyFlushEvents();

	ExitToShell();
}



#pragma mark -


/******************** MY RANDOM LONG **********************/
//
// My own random number generator that returns a LONG
//
// NOTE: call this instead of MyRandomShort if the value is going to be
//		masked or if it just doesnt matter since this version is quicker
//		without the 0xffff at the end.
//

unsigned long MyRandomLong(void)
{
  return gSeed2 ^= (((gSeed1 ^= (gSeed2>>5)*1568397607UL)>>7)+
                   (gSeed0 = (gSeed0+1)*3141592621UL))*2435386481UL;
}


/************************* RANDOM RANGE *************************/
//
// THE RANGE *IS* INCLUSIVE OF MIN AND MAX
//

u_short	RandomRange(unsigned short min, unsigned short max)
{
u_short		qdRdm;											// treat return value as 0-65536
uint32_t		range, t;

	qdRdm = MyRandomLong();
	range = max+1 - min;
	t = (qdRdm * range)>>16;	 							// now 0 <= t <= range

	return( t+min );
}



/************** RANDOM FLOAT ********************/
//
// returns a random float between 0 and 1
//

float RandomFloat(void)
{
unsigned long	r;
float	f;

	r = MyRandomLong() & 0xfff;
	if (r == 0)
		return(0);

	f = (float)r;							// convert to float
	f = f * (1.0f/(float)0xfff);			// get # between 0..1
	return(f);
}


/************** RANDOM FLOAT 2 ********************/
//
// returns a random float between -1 and +1
//

float RandomFloat2(void)
{
unsigned long	r;
float	f;

	r = MyRandomLong() & 0xfff;
	if (r == 0)
		return(0);

	f = (float)r;							// convert to float
	f = f * (2.0f/(float)0xfff);			// get # between 0..2
	f -= 1.0f;								// get -1..+1
	return(f);
}



/**************** SET MY RANDOM SEED *******************/

void SetMyRandomSeed(unsigned long seed)
{
	gSeed0 = seed;
	gSeed1 = 0;
	gSeed2 = 0;

}

/**************** INIT MY RANDOM SEED *******************/

void InitMyRandomSeed(void)
{
	gSeed0 = 0x2a80ce30;
	gSeed1 = 0;
	gSeed2 = 0;
}


#pragma mark -


/****************** ALLOC HANDLE ********************/

Handle	AllocHandle(long size)
{
Handle	hand;
OSErr	err;

	hand = NewHandle(size);							// alloc in APPL
	if (hand == nil)
	{
		DoAlert("AllocHandle: using temp mem");
		hand = TempNewHandle(size,&err);			// try TEMP mem
		if (hand == nil)
		{
			DoAlert("AllocHandle: failed!");
			return(nil);
		}
		else
			return(hand);
	}
	return(hand);

}



/****************** ALLOC PTR ********************/

void *AllocPtr(long size)
{
Ptr	pr;
uint32_t	*cookiePtr;

	size += 16;								// make room for our cookie & whatever else (also keep to 16-byte alignment!)

	pr = malloc(size);
	if (pr == nil)
		DoFatalAlert("AllocPtr: NewPtr failed");

	cookiePtr = (uint32_t *)pr;

	*cookiePtr++ = 'FACE';
	*cookiePtr++ = size;
	*cookiePtr++ = 'PTR3';
	*cookiePtr = 'PTR4';

	pr += 16;

	gNumPointers++;


	gRAMAlloced += size;

	return(pr);
}


/****************** ALLOC PTR CLEAR ********************/

void *AllocPtrClear(long size)
{
Ptr	pr;
uint32_t	*cookiePtr;

	size += 16;								// make room for our cookie & whatever else (also keep to 16-byte alignment!)

	pr = calloc(1, size);

	if (pr == nil)
		DoFatalAlert("AllocPtr: NewPtr failed");

	cookiePtr = (uint32_t *)pr;

	*cookiePtr++ = 'FACE';
	*cookiePtr++ = size;
	*cookiePtr++ = 'PTC3';
	*cookiePtr = 'PTC4';

	pr += 16;

	gNumPointers++;


	gRAMAlloced += size;

	return(pr);
}


/***************** SAFE DISPOSE PTR ***********************/

void SafeDisposePtr(void *ptr)
{
uint32_t	*cookiePtr;
Ptr		p = ptr;

	p -= 16;					// back up to pt to cookie

	cookiePtr = (uint32_t *)p;

	if (*cookiePtr != 'FACE')
		DoFatalAlert("SafeSafeDisposePtr: invalid cookie!");

	gRAMAlloced -= cookiePtr[1];

	*cookiePtr = 0;									// zap cookie

	free(p);

	gNumPointers--;

}



#pragma mark -


/******************* VERIFY SYSTEM ******************/

void VerifySystem(void)
{
}


/******************** REGULATE SPEED ***************/

void RegulateSpeed(short fps)
{
uint32_t	n;
static uint32_t oldTick = 0;

	n = 60 / fps;
	while ((TickCount() - oldTick) < n) {}			// wait for n ticks
	oldTick = TickCount();							// remember current time
}



#pragma mark -



/************** CALC FRAMES PER SECOND *****************/
//
// This version uses UpTime() which is only available on PCI Macs.
//

void CalcFramesPerSecond(void)
{
#if 1
static UnsignedWide time;
UnsignedWide currTime;
unsigned long deltaTime;
#else
AbsoluteTime currTime,deltaTime;
static AbsoluteTime time = {0,0};
Nanoseconds	nano;
#endif
float		fps;

int				i;
static int		sampIndex = 0;
static float	sampleList[16] = {60,60,60,60,60,60,60,60,60,60,60,60,60,60,60,60};

//wait:
	if (gTimeDemo)
	{
		fps = 40;
	}
	else
	{
#if 1
		Microseconds(&currTime);
		deltaTime = currTime.lo - time.lo;

		if (deltaTime == 0)
		{
			fps = DEFAULT_FPS;
		}
		else
		{
			fps = 1000000.0f / deltaTime;

			if (fps < DEFAULT_FPS)					// (avoid divide by 0's later)
				fps = DEFAULT_FPS;
		}

#if _DEBUG
		if (GetKeyState(SDL_SCANCODE_KP_PLUS))		// debug speed-up with KP_PLUS
			fps = DEFAULT_FPS;
#endif
#else
		currTime = UpTime();

		deltaTime = SubAbsoluteFromAbsolute(currTime, time);
		nano = AbsoluteToNanoseconds(deltaTime);

		fps = (float)kSecondScale / (float)nano.lo;

		if (fps > MAX_FPS)				// limit to avoid issues
			goto wait;
#endif
	}

			/* ADD TO LIST */

	sampleList[sampIndex] = fps;
	sampIndex++;
	sampIndex &= 0x7;


			/* CALC AVERAGE */

	gFramesPerSecond = 0;
	for (i = 0; i < 8; i++)
		gFramesPerSecond += sampleList[i];
	gFramesPerSecond *= 1.0f / 8.0f;



	if (gFramesPerSecond < DEFAULT_FPS)			// (avoid divide by 0's later)
		gFramesPerSecond = DEFAULT_FPS;
	gFramesPerSecondFrac = 1.0f/gFramesPerSecond;		// calc fractional for multiplication


	time = currTime;	// reset for next time interval
}


/********************* IS POWER OF 2 ****************************/

Boolean IsPowerOf2(int num)
{
int		i;

	i = 2;
	do
	{
		if (i == num)				// see if this power of 2 matches
			return(true);
		i *= 2;						// next power of 2
	}while(i <= num);				// search until power is > number

	return(false);
}

#pragma mark-

/******************* MY FLUSH EVENTS **********************/
//
// This call makes damed sure that there are no events anywhere in any event queue.
//

void MyFlushEvents(void)
{
#if 0
#if 1
	while (1)
	{
		EventRef        theEvent;
		OSStatus err = ReceiveNextEvent(0, NULL, kEventDurationNoWait, true, &theEvent);
		if (err == noErr) {
			(void) SendEventToEventTarget(theEvent, GetEventDispatcherTarget());
			ReleaseEvent(theEvent);
		}
		else
			break;
	}

#endif
#if 0
	//EventRecord 	theEvent;

	FlushEvents (everyEvent, REMOVE_ALL_EVENTS);
	FlushEventQueue(GetMainEventQueue());

	/* POLL EVENT QUEUE TO BE SURE THINGS ARE FLUSHED OUT */

	while (GetNextEvent(mDownMask|mUpMask|keyDownMask|keyUpMask|autoKeyMask, &theEvent));


	FlushEvents (everyEvent, REMOVE_ALL_EVENTS);
	FlushEventQueue(GetMainEventQueue());
#endif
#endif
}


#pragma mark -


/************************* WE ARE FRONT PROCESS ******************************/

Boolean WeAreFrontProcess(void)
{
	SOFTIMPME;
	return true;
#if 0
ProcessSerialNumber	frontProcess, myProcess;
Boolean				same;

	GetFrontProcess(&frontProcess); 					// get the front process
	MacGetCurrentProcess(&myProcess);					// get the current process

	SameProcess(&frontProcess, &myProcess, &same);		// if they're the same then we're in front

	return(same);
#endif
}


#pragma mark -


/********************* SWIZZLE SHORT **************************/

int16_t SwizzleShort(const int16_t *shortPtr)
{
	return (int16_t) SwizzleUShort((const uint16_t*) shortPtr);
}


/********************* SWIZZLE USHORT **************************/

uint16_t SwizzleUShort(const uint16_t *shortPtr)
{
uint16_t	theShort = *shortPtr;

#if __LITTLE_ENDIAN__

	uint32_t	b1 = theShort & 0xff;
	uint32_t	b2 = (theShort & 0xff00) >> 8;

	theShort = (b1 << 8) | b2;
#endif

	return(theShort);
}



/********************* SWIZZLE LONG **************************/

int32_t SwizzleLong(const int32_t *longPtr)
{
	return (int32_t) SwizzleULong((const uint32_t*) longPtr);

}


/********************* SWIZZLE U LONG **************************/

uint32_t SwizzleULong(const uint32_t *longPtr)
{
uint32_t	theLong = *longPtr;

#if __LITTLE_ENDIAN__

	uint32_t	b1 = theLong & 0xff;
	uint32_t	b2 = (theLong & 0xff00) >> 8;
	uint32_t	b3 = (theLong & 0xff0000) >> 16;
	uint32_t	b4 = (theLong & 0xff000000) >> 24;

	theLong = (b1 << 24) | (b2 << 16) | (b3 << 8) | b4;

#endif

	return(theLong);
}



/********************* SWIZZLE FLOAT **************************/

float SwizzleFloat(const float *floatPtr)
{
float	*theFloat;
uint32_t	bytes = SwizzleULong((const uint32_t *)floatPtr);

	theFloat = (float *)&bytes;

	return(*theFloat);
}
