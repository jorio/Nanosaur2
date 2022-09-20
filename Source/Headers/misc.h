//
// misc.h
//

#pragma once

#define SERIAL_LENGTH      12

#define ShowSystemErr(errNo) DoFatalAlert("System error %d", errNo)
#define ShowSystemErr_NonFatal(errNo) DoAlert("System error %d", errNo)

void	DoAlert(const char* format, ...);
POMME_NORETURN void DoFatalAlert(const char* format, ...);
extern	void CleanQuit(void);
extern	void SetMyRandomSeed(unsigned long seed);
extern	unsigned long MyRandomLong(void);
extern	void FloatToString(float num, Str255 string);
extern	Handle	AllocHandle(long size);
extern	void *AllocPtr(long size);
void *AllocPtrClear(long size);
extern	void InitMyRandomSeed(void);
extern	void VerifySystem(void);
extern	float RandomFloat(void);
u_short	RandomRange(unsigned short min, unsigned short max);
extern	void RegulateSpeed(short fps);
extern	void CopyPStr(ConstStr255Param	inSourceStr, StringPtr	outDestStr);
void CalcFramesPerSecond(void);
Boolean IsPowerOf2(int num);
float RandomFloat2(void);

void SafeDisposePtr(void *ptr);
void MyFlushEvents(void);

Boolean WeAreFrontProcess(void);
OSErr LoadOurPrefs(void);
void SaveOurPrefs(void);

short SwizzleShort(short *shortPtr);
long SwizzleLong(long *longPtr);
float SwizzleFloat(float *floatPtr);
u_long SwizzleULong(u_long *longPtr);
u_short SwizzleUShort(u_short *shortPtr);


/***********************************/


extern	float		gFramesPerSecondFrac;
extern	Boolean		gGameIsRegistered, gAltivec, gLittleSnitch, gLowRAM;
extern	Str255  	gSerialFileName;
extern  u_long		gSerialWasVerifiedMode;
