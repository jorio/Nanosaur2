// fatal_shim.h - see fatal_shim.c.
//
// Plain scalar-typed declaration (no <3ds.h> types), same reasoning as
// picaGL_shim.h/romfs_shim.h: this needs libctru's console/hid APIs, which
// can't coexist with Pomme's Handle typedef in the same translation unit
// (see game_3ds.h's comment on hidScanInput for the full explanation).
#pragma once

#ifdef __cplusplus
extern "C" {
#endif

// Prints `message` to the bottom screen via libctru's console (independent
// of picaGL, which owns the top screen) and never returns - loops forever
// polling input so the message stays on screen and the app doesn't just
// vanish/hang invisibly the way SDL_ShowSimpleMessageBox does on 3DS's
// software-only SDL backend. Used by Source/System/Misc.c's
// DoAlert/DoFatalAlert on 3DS instead of SDL_ShowSimpleMessageBox.
void Fatal3DS_Print(const char *message);

#ifdef __cplusplus
}
#endif
