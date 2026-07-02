#pragma once

// Swift interop annotations for the C headers.
//
// These are no-ops on non-Clang compilers (MSVC, GCC on Windows/Linux) so
// the plain-C build keeps working there unchanged; they only affect how
// Swift's ClangImporter presents these declarations when the macOS/Swift
// build parses the same headers through the bridging header.
//
// SWIFT_ENUM_CLOSED: marks a C enum as a fixed, exhaustive set of cases.
// Without this, Clang imports every enum case as a loose untyped global
// constant (commonly imported as plain `Int`, causing constant Int/Int32
// mismatches against the `Int32`-typed C fields/params that actually hold
// them). With it, the enum becomes a real `enum` in Swift with switch
// exhaustiveness checking. Only apply this to enums that are genuinely
// closed, mutually-exclusive value sets (state/mode/kind selectors) —
// NOT to bitmask/flag groups combined with `|` (those need a different,
// OptionSet-style annotation) or sequential ID-list enums that code adds
// integers to (e.g. `GLOBAL_ObjType_RedEgg + eggColor`), since arithmetic
// and OR'ing don't work on enum cases without unwrapping `.rawValue`.
//
// SWIFT_NAME(x): pins the exact Swift-side spelling of a single enum case
// (or other declaration) instead of relying on Clang's fuzzy prefix-
// stripping heuristic, which does not produce predictable results against
// this codebase's `k`-prefixed naming convention. Using this, `kFooBar`
// still imports as `.kFooBar` (now qualified under its enum type) rather
// than some derived shorthand.

#if defined(__clang__)
	#define SWIFT_ENUM_CLOSED __attribute__((enum_extensibility(closed)))
	#define SWIFT_ENUM_OPEN __attribute__((enum_extensibility(open)))
	#define SWIFT_NAME(_name) __attribute__((swift_name(#_name)))
#else
	#define SWIFT_ENUM_CLOSED
	#define SWIFT_ENUM_OPEN
	#define SWIFT_NAME(_name)
#endif
