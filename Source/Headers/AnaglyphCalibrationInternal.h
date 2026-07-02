#pragma once

#include "menu.h"

// Menu tree data tables for the anaglyph calibration screen, and the
// callbacks they embed by designated initializer, stay in
// AnaglyphCalibration.c: MenuItem's anonymous-union fields (.cycler.choices,
// .slider, four-char-code ids) aren't practical to construct from Swift.
// SetUpAnaglyphCalibrationScreen (in AnaglyphCalibration.swift) references
// them by name.

extern const MenuItem gInGameAnaglyphMenu[];
extern const MenuItem gAnaglyphMenu[];

#pragma clang assume_nonnull begin

static inline const MenuItem* GetInGameAnaglyphMenu(void) { return gInGameAnaglyphMenu; }
static inline const MenuItem* GetAnaglyphMenu(void) { return gAnaglyphMenu; }

#pragma clang assume_nonnull end
