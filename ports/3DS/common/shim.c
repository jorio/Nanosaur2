// shim.c -- see shim.h.

#include "shim.h"

#include <errno.h>
#include <malloc.h>

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
