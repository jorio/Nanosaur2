// EmbeddedMath.swift - Float overloads for transcendental math functions,
// 3DS-only.
//
// On desktop, Swift resolves calls like `sin(aFloatValue)` to a
// Float-specialized overload the platform's Glibc/Darwin overlay module
// provides alongside the Swift standard library. Embedded Swift (this
// engine's 3DS target) doesn't have that overlay, so those same call
// sites - unchanged, still passing Float - fall back to trying to match
// <math.h>'s double-only C declarations (`double sin(double)` etc.,
// visible via game_3ds.h) and fail to compile ("cannot convert value of
// type 'Float' to expected argument type 'Double'"). newlib's math.h
// already declares real float-precision C variants (sinf/cosf/acosf/...)
// - this file just gives them the plain names every existing call site
// already uses, so nothing elsewhere needs to change.
#if NANOSAUR_3DS
func sin(_ x: Float) -> Float { sinf(x) }
func cos(_ x: Float) -> Float { cosf(x) }
func tan(_ x: Float) -> Float { tanf(x) }
func acos(_ x: Float) -> Float { acosf(x) }
func asin(_ x: Float) -> Float { asinf(x) }
func atan2(_ y: Float, _ x: Float) -> Float { atan2f(y, x) }
func sqrt(_ x: Float) -> Float { sqrtf(x) }
#endif
