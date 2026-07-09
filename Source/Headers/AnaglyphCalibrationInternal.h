#pragma once

#include "menu.h"
#include "game.h"

#pragma clang assume_nonnull begin

// Stable pointers to gGamePrefs anaglyph fields for use as MenuCyclerData/
// MenuSliderData valuePtr. Swift can't form a stable address to a C-global
// struct field without going through a C helper.
static inline Byte* AnaglyphInternal_GetStereoGlassesModePtr(void)      { return (Byte*)&gGamePrefs.stereoGlassesMode; }
static inline Byte* AnaglyphInternal_GetCalibRedPtr(void)               { return &gGamePrefs.anaglyphCalibrationRed; }
static inline Byte* AnaglyphInternal_GetCalibGreenPtr(void)             { return &gGamePrefs.anaglyphCalibrationGreen; }
static inline Byte* AnaglyphInternal_GetCalibBluePtr(void)              { return &gGamePrefs.anaglyphCalibrationBlue; }
static inline Byte* AnaglyphInternal_GetChannelBalancingPtr(void)       { return (Byte*)&gGamePrefs.doAnaglyphChannelBalancing; }

#pragma clang assume_nonnull end
