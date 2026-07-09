// boot_shim.c - the 3DS's libctru heap-size override. The
// gSDLWindow/gSDLWindow2/gDualScreenMode/gMetalMode/gDataSpec/
// gCurrentAntialiasingLevel globals this file used to provide storage for
// (Source/Boot.cpp is desktop-only: argv parsing, SDL_CreateWindow,
// --dual-screen handling - none of which applies on 3DS) now live in
// Source/System/BootGlobals.c instead - a portable C file picked up by
// this Makefile's own ENGINE_CFILES glob same as any other Source/**/*.c
// file, so defining them again here would collide at link time.
//
// gSDLWindow is a REAL SDL_Window (created in source/main.cpp via
// SDL_CreateWindow, same as desktop's Boot.cpp) even though picaGL - not
// SDL's own GL/renderer backend - does the actual drawing: too many engine
// call sites (OGL_Support.swift's window-size query, MainMenu.swift's mouse
// cursor tracking, Input.swift's mouse warp/grab) dereference gSDLWindow as
// a real SDL_Window every frame, so a fake non-NULL placeholder crashes the
// moment any of them run.
#include <stdint.h>

// libctru's crt0 startup code declares __ctru_heap_size/__ctru_linear_heap_size
// as WEAK symbols with its own default sizes - defining real, non-weak
// globals with these exact names here overrides those defaults (see
// /opt/devkitpro/libctru/include/3ds/env.h's envGetHeapSize/
// envGetLinearHeapSize, and `nm libctru.a` showing these as `V` = weak).
//
// Measured defaults: heap=89MiB, linearHeap=32MiB, and the two draw from
// one FIXED total pool (121MiB) - growing one shrinks the other by the
// same amount (confirmed empirically: +16MiB linearHeap regressed a
// different, previously-reliable code path that needed that 16MiB back
// from the regular heap).
//
// The actual crash (LoadPlayfield's supertile texture-assembly loop,
// Source/System/File.swift, running out of memory partway through a
// level's terrain textures) turned out to be the REGULAR heap, not the
// linear heap: stb_image's JPEG decoder (stb_image.h's STBI_MALLOC,
// unpatched - still plain malloc/free) allocates its temporary decoded
// pixel buffers from there, and the sliding window's minimum-safe 4-row
// lookahead (AssembleSeamlessSuperTileTexture needs a full row of
// vertical neighbor context on each side - this can't be tightened
// without breaking the seam-stitching math) keeps quite a few of those
// alive concurrently. Meanwhile LoadSuperTileTexture (same file) now
// downsamples every supertile 2x before GPU upload (4x less linear
// memory per texture - see that function's own comment), so linear
// memory is no longer the tight pool it was. This rebalances the fixed
// total pool toward the regular heap accordingly.
uint32_t __ctru_linear_heap_size = 8 * 1024 * 1024; // 8 MiB (default 32 MiB; downsampled textures need far less linear memory now, so give the freed-up budget to the regular heap instead - 4 MiB was too aggressive and crashed early, before even reaching sprite loading; 8 MiB is the smallest value tested that didn't regress anything else)
