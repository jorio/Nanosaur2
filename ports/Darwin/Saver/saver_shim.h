// saver_shim.h - declarations for the screen-saver build's platform shim
// (shim.c). See shim.c's header comment for the philosophy.

#pragma once

#ifdef __cplusplus
extern "C" {
#endif

/// dlsym-based GL proc lookup (OpenGL.framework is linked directly);
/// replaces SDL_GL_GetProcAddress for GLRenderBackend.loadGLProcs.
void* Saver_GLGetProcAddress(const char* name);

#ifdef __cplusplus
}
#endif
