#pragma once

#include "globals.h"

// General-purpose C shims for Swift interop, shared across ported files.
// Clang's macro-constant importer can only fold simple numeric literals;
// compound macros that reference other macros/enum constants aren't
// imported, so we re-expose them here as plain typed constants.

static const float SwPI2 = PI2;
