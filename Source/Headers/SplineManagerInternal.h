#pragma once

#include "splinemanager.h"

// Swift can't dynamically index a fixed-size C array of a non-trivial
// struct type (it imports as a giant tuple); hand out element pointers
// instead.
static inline CustomSplineType* GetCustomSplineSlot(int i) { return &gCustomSplines[i]; }
