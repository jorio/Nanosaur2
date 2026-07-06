typedef uint32_t (*readFunc) (const void*);
typedef void 	 (*writeFunc)(void*, uint32_t);

uint32_t _readRGBA8(const void* data)
{
	return *(uint32_t*)data;
}

uint32_t _readRGB8(const void* data)
{
	uint8_t  *clr = (uint8_t*)data;

	uint8_t r = clr[0];
	uint8_t g = clr[1];
	uint8_t b = clr[2];
	uint8_t a = 255;

	return (r | (g << 8) | (b << 16) | (a << 24));
}

uint32_t _readLA8(const void* data)
{
	uint8_t  *clr = (uint8_t*)data;

	uint8_t l = clr[0];
	uint8_t a = clr[1];

	return (l | (l << 8) | (l << 16) | (a << 24));
}

uint32_t _readA8(const void* data)
{
	uint8_t  *clr = (uint8_t*)data;

	uint8_t l = 255;
	uint8_t a = clr[0];

	return (l | (l << 8) | (l << 16) | (a << 24));
}

void _writeRGBA4(void *data, uint32_t color)
{
	uint16_t *dst = (uint16_t*)data;
	uint8_t  *clr = (uint8_t*)&color;

	uint8_t r = clr[0] >> 4;
	uint8_t g = clr[1] >> 4;
	uint8_t b = clr[2] >> 4;
	uint8_t a = clr[3] >> 4;

	*dst = (a | (b << 4) | (g << 8) | (r << 12));
}

void _writeRGB565(void *data, uint32_t color)
{
	uint16_t *dst = (uint16_t*)data;
	uint8_t  *clr = (uint8_t*)&color;

	uint8_t r = clr[0] >> 3;
	uint8_t g = clr[1] >> 2;
	uint8_t b = clr[2] >> 3;

	*dst = (b | (g << 5) | (r << 11));
}

void _writeLA4(void *data, uint32_t color)
{
	uint8_t *dst = (uint8_t*)data;
	uint8_t *clr = (uint8_t*)&color;

	uint8_t l = clr[0] >> 4;
	uint8_t a = clr[3] >> 4;

	*dst = (a | (l << 4));
}

void _writeLA8(void *data, uint32_t color)
{
	uint16_t *dst = (uint16_t*)data;
	uint8_t  *clr = (uint8_t*)&color;

	uint8_t l = clr[0];
	uint8_t a = clr[3];

	*dst = (a | (l << 8));
}

void _writeA8(void *data, uint32_t color)
{
	uint8_t *dst = (uint8_t*)data;
	uint8_t *clr = (uint8_t*)&color;

	*dst = clr[3];
}
