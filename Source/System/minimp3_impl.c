// minimp3_impl.c - generates minimp3's implementation (single-header
// library convention: exactly one translation unit must define
// MINIMP3_IMPLEMENTATION before including it). Declarations-only visibility
// for everyone else comes from including extern/minimp3/minimp3.h directly
// (see sound2.h) - that's safe from the bridging-header/Clang-modules
// collision this project has to avoid (see feedback_no_system_headers_
// from_bridging_header memory) because it's one of this project's own
// vendored headers, not an SDK header.
#define MINIMP3_IMPLEMENTATION
#include "minimp3.h"
