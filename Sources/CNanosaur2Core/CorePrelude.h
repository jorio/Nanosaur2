// CorePrelude.h
//
// Force-included (via -include) ahead of every file SPM compiles as part of
// the CNanosaur2Core module, including its own header self-containment
// validation pass. The ~50 headers under include/ were written assuming
// they'd only ever be textually concatenated in a fixed order via game.h (as
// the CMake build's Objective-C bridging header did) - none of them
// individually #include the foundational types/macros they use (GLfloat,
// Boolean, Rect, uint32_t, SWIFT_ENUM_CLOSED, etc.), relying entirely on
// whatever came before them in game.h's include list. SwiftPM's Clang module
// builder instead validates each header for self-containment independently,
// in an unspecified (roughly alphabetical) order, so anything relying on
// prior textual state fails. Rather than editing every header to explicitly
// include its real dependencies, this single prelude - built from game.h's
// own pre-amble - is force-included first, restoring the same "everything
// already visible" precondition the headers were written against.
#pragma once

#include <Pomme.h>
#include <SDL3/SDL.h>
#include <SDL3/SDL_opengl.h>
#include <SDL3/SDL_opengl_glext.h>
#include <math.h>
#include <stdlib.h>

#include "SwiftAnnotations.h"
