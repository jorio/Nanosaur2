#pragma once

#include "items.h"

// gNumEggsToSave/gNumEggsSaved are fixed-size C arrays (`Byte gNumEggsToSave[NUM_EGG_TYPES]`),
// which Swift imports as non-subscriptable tuples. Hand out element pointers
// instead so they can be dynamically indexed.
static inline Byte* GetNumEggsToSaveSlot(int i) { return &gNumEggsToSave[i]; }
static inline Byte* GetNumEggsSavedSlot(int i) { return &gNumEggsSaved[i]; }
