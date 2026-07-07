#pragma once

#include "game.h"

#pragma clang assume_nonnull begin

// Stable pointers to gGamePrefs fields for use as MenuItem valuePtr.
// Swift can't form stable addresses to C-global struct fields without a helper.
static inline Byte* SettingsInternal_GetKiddieModePtr(void)             { return &gGamePrefs.kiddieMode; }
static inline Byte* SettingsInternal_GetLanguagePtr(void)               { return (Byte*)&gGamePrefs.language; }
static inline Byte* SettingsInternal_GetShowCrosshairsPtr(void)         { return &gGamePrefs.showTargetingCrosshairs; }
static inline Byte* SettingsInternal_GetForce4x3HUDPtr(void)            { return &gGamePrefs.force4x3HUD; }
static inline Byte* SettingsInternal_GetHUDScalePtr(void)               { return &gGamePrefs.hudScale; }
static inline Byte* SettingsInternal_GetInvertVerticalSteeringPtr(void) { return &gGamePrefs.invertVerticalSteering; }
static inline Byte* SettingsInternal_GetRumbleIntensityPtr(void)        { return &gGamePrefs.rumbleIntensity; }
static inline Byte* SettingsInternal_GetFullscreenPtr(void)             { return &gGamePrefs.fullscreen; }
static inline Byte* SettingsInternal_GetDisplayNumPtr(void)             { return &gGamePrefs.displayNum; }
static inline Byte* SettingsInternal_GetVSyncPtr(void)                  { return &gGamePrefs.vsync; }
static inline Byte* SettingsInternal_GetAntialiasingLevelPtr(void)      { return &gGamePrefs.antialiasingLevel; }
static inline Byte* SettingsInternal_GetMusicVolumePercentPtr(void)     { return &gGamePrefs.musicVolumePercent; }
static inline Byte* SettingsInternal_GetSFXVolumePercentPtr(void)       { return &gGamePrefs.sfxVolumePercent; }
static inline Byte* SettingsInternal_GetMouseSensitivityLevelPtr(void)  { return &gGamePrefs.mouseSensitivityLevel; }

// Generator for the monitor cycler: returns a display's 1-based number as a string.
// Uses a static buffer — valid until the next call (same contract as the original C).
static inline const char* SettingsInternal_GetDisplayName(Byte value) {
    static char textBuf[8];
    SDL_snprintf(textBuf, sizeof(textBuf), "%d", value + 1);
    return textBuf;
}

// Wrapper for IsNativeEnglishSystem (macro/static inline, not callable from Swift directly).
static inline bool SettingsInternal_IsNativeEnglishSystem(void) { return IsNativeEnglishSystem(); }

#pragma clang assume_nonnull end
