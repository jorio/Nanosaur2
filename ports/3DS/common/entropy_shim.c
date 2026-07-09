// entropy_shim.c - implements newlib's reentrant _getentropy_r, which
// devkitARM's libc declares (sys/unistd.h) but doesn't itself define for
// the 3DS target - arc4random_buf() (pulled in by the Swift runtime, e.g.
// for Dictionary/Set hash-seed randomization) calls getentropy(), which
// calls this, and link fails with "undefined reference to `_getentropy_r'"
// without it.
//
// Not cryptographic quality - svcGetSystemTick() is a monotonic hardware
// tick counter, not a real entropy source, but that's enough for hash-seed
// randomization (the only thing arc4random_buf is used for in this
// codebase; nothing here needs secure randomness). Declared directly
// rather than `#include <3ds.h>` for the same reason as game_3ds.h's
// hidScanInput/hidKeysHeld: avoiding libctru's Handle-typedef collision
// with the Mac Toolbox's own Handle (SwMacTypes.h) - this file doesn't
// need any other libctru symbol, so there's nothing to lose by declaring
// just this one.
#include <stddef.h>

extern unsigned long long svcGetSystemTick(void);

// struct _reent's actual layout is irrelevant here (never dereferenced) -
// newlib's calling convention just needs *a* pointer-sized first
// parameter matching the non-reentrant wrapper's call site.
int _getentropy_r(void *reent, void *buffer, size_t length)
{
    (void)reent;
    unsigned char *buf = (unsigned char *)buffer;
    for (size_t i = 0; i < length; i++) {
        unsigned long long tick = svcGetSystemTick();
        buf[i] = (unsigned char)(tick ^ (tick >> 8) ^ (tick >> 16) ^ (tick >> 24) ^ i);
    }
    return 0;
}
