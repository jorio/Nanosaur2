//
// misc.h
//

#pragma once

void	DoAlert(const char* format, ...);
POMME_NORETURN void DoFatalAlert(const char* format, ...);
POMME_NORETURN void CleanQuit(void);

void* AllocPtr(long size);
void* ReallocPtr(void* ptr, long size);
void SafeDisposePtr(void* ptr);





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
