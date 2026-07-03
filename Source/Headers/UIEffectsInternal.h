#pragma once

#include "game.h"
#include "uieffects.h"

// Internal twitch-driver types shared between UIEffects.swift and C.
// TwitchDriverData used to be private to UIEffects.c; it moves here so
// Swift can see it.

#define MAX_TWITCH_CHAIN_LENGTH 4

typedef struct
{
	ObjNode*	_Nullable	puppet;
	Twitch*		_Nullable	fxChain[MAX_TWITCH_CHAIN_LENGTH];
	float					timers[MAX_TWITCH_CHAIN_LENGTH];
	uint32_t				cookie;
	uint8_t					chainLength;
	bool					deletePuppetOnCompletion;
	bool					hideDuringDelay;
} TwitchDriverData;
_Static_assert(sizeof(TwitchDriverData) <= MAX_SPECIAL_DATA_BYTES, "TwitchDriverData doesn't fit in special area");

// SpecialPadding lives in an anonymous union inside ObjNode, and Swift's
// pointer(to:) nil-crashes on union members — hand out the pointer from C.
static inline TwitchDriverData* _Nonnull GetTwitchDriverData(ObjNode* _Nonnull node)
{
	return (TwitchDriverData*) node->SpecialPadding;
}
