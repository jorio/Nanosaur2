//
// misc.h
//

#pragma once

void	DoAlert(const char* format, ...);
POMME_NORETURN void DoFatalAlert(const char* format, ...);
POMME_NORETURN void CleanQuit(void);

void* AllocPtr(long size);
void* AllocPtrClear(long size);
void* ReallocPtr(void* ptr, long size);
void SafeDisposePtr(void* ptr);

void VerifySystem(void);

void SetMyRandomSeed(uint32_t seed);
uint32_t MyRandomLong(void);
void InitMyRandomSeed(void);
float RandomFloat(void);
uint16_t	RandomRange(unsigned short min, unsigned short max);
void CalcFramesPerSecond(void);
Boolean IsPowerOf2(int num);
float RandomFloat2(void);

void MyFlushEvents(void);

int16_t SwizzleShort(const int16_t *shortPtr);
int32_t SwizzleLong(const int32_t *longPtr);
float SwizzleFloat(const float *floatPtr);
uint32_t SwizzleULong(const uint32_t *longPtr);
uint16_t SwizzleUShort(const uint16_t *shortPtr);

static inline int PositiveModulo(int value, unsigned int m)
{
	int mod = value % (int) m;
	if (mod < 0)
	{
		mod += m;
	}
	return mod;
}

static inline float RangeNorm(float x, float rangeMin, float rangeMax)
{
	return (x - rangeMin) / (rangeMax - rangeMin);
}

static inline float RangeLerp(float frac, float rangeMin, float rangeMax)
{
	return rangeMin + frac * (rangeMax - rangeMin);
}

static inline float RangeTranspose(float x, float currentRangeMin, float currentRangeMax, float targetRangeMin, float targetRangeMax)
{
	float f = RangeNorm(x, currentRangeMin, currentRangeMax);
	float y = RangeLerp(f, targetRangeMin, targetRangeMax);
	return y;
}
