// shim.c -- see shim.h.

#include "shim.h"

#include <errno.h>
#include <malloc.h>
#include <stdlib.h>

int posix_memalign(void **memptr, size_t alignment, size_t size)
{
	if (alignment % sizeof(void *) != 0 || (alignment & (alignment - 1)) != 0) {
		return EINVAL;
	}

	void *p = memalign(alignment, size);
	if (!p) {
		return ENOMEM;
	}

	*memptr = p;
	return 0;
}

// Embedded Swift's Float(String) parsing calls this (declared in Swift's
// own RuntimeShims.h, normally implemented in the full stdlib runtime -
// not present in the Embedded Swift libraries, which don't ship a full
// runtime). newlib's strtof has no locale concept at all (freestanding C
// libraries only ever have the "C" locale), so "with the C locale" is just
// plain strtof here - not a stub, a real (if trivial) implementation.
const char *_swift_stdlib_strtof_clocale(const char *nptr, float *outResult)
{
	char *endptr;
	*outResult = strtof(nptr, &endptr);
	return endptr;
}
