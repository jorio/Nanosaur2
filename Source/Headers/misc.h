//
// misc.h
//

#pragma once

#define SERIAL_LENGTH      12

#define ShowSystemErr(errNo) DoFatalAlert("System error %d", errNo)
#define ShowSystemErr_NonFatal(errNo) DoAlert("System error %d", errNo)

void	DoAlert(const char* format, ...);
POMME_NORETURN void DoFatalAlert(const char* format, ...);
POMME_NORETURN void CleanQuit(void);
extern	void SetMyRandomSeed(unsigned long seed);
extern	unsigned long MyRandomLong(void);
extern	Handle	AllocHandle(long size);
extern	void *AllocPtr(long size);
void *AllocPtrClear(long size);
extern	void InitMyRandomSeed(void);
extern	void VerifySystem(void);
extern	float RandomFloat(void);
u_short	RandomRange(unsigned short min, unsigned short max);
extern	void RegulateSpeed(short fps);
void CalcFramesPerSecond(void);
Boolean IsPowerOf2(int num);
float RandomFloat2(void);

void SafeDisposePtr(void *ptr);
void MyFlushEvents(void);

Boolean WeAreFrontProcess(void);
OSErr LoadOurPrefs(void);
void SaveOurPrefs(void);

int16_t SwizzleShort(const int16_t *shortPtr);
int32_t SwizzleLong(const int32_t *longPtr);
float SwizzleFloat(const float *floatPtr);
uint32_t SwizzleULong(const uint32_t *longPtr);
uint16_t SwizzleUShort(const uint16_t *shortPtr);
