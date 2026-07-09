// Placeholder public-headers directory for SwiftPM's C-target validator.
// CNanosaur2Core's real headers live under include/ and are reached via
// -import-objc-header (Nanosaur2Swift) or explicit headerSearchPath
// (Nanosaur2Exe), never via `import CNanosaur2Core` as a Clang module - the
// ~50 headers under include/ assume a fixed textual inclusion order via
// game.h and fail Clang's per-header module self-containment validation.
// Pointing publicHeadersPath here (nothing includes into it) avoids that
// validation ever running against include/ at all.
#pragma once
