// shim.h -- shared C support for the Nanosaur 2 3DS port.
//
// Currently just posix_memalign: Embedded Swift's runtime allocator
// (swift_allocObject/swift_slowAlloc/swift_coroFrameAlloc) calls it
// directly, but devkitARM's newlib doesn't provide it (only the older
// non-POSIX memalign()/aligned_alloc()).
#ifndef NANOSAUR2_3DS_SHIM_H
#define NANOSAUR2_3DS_SHIM_H

#include <stddef.h>

int posix_memalign(void **memptr, size_t alignment, size_t size);

#endif // NANOSAUR2_3DS_SHIM_H
