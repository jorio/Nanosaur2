#pragma once

#include "splinemanager.h"

#pragma clang assume_nonnull begin

// Swift can't dynamically index a fixed-size C array of a non-trivial
// struct type (it imports as a giant tuple); hand out element pointers
// instead.
static inline CustomSplineType* GetCustomSplineSlot(int i) { return &gCustomSplines[i]; }

#pragma clang assume_nonnull end
