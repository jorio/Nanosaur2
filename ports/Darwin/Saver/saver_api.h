// saver_api.h - the C surface between the engine module (SaverGlue.swift,
// compiled with the game's bridging header) and the ScreenSaverView host
// module (Nanosaur2SaverView.swift, which imports AppKit and therefore
// can't see the game's bridging header). This is the host module's
// bridging header - keep it to plain C scalars only.

#pragma once

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/// Boot the engine against the host's current GL context. Call once per
/// process, with the absolute path of the bundle's Data folder.
void Nanosaur2Saver_Boot(const char* dataPath);

/// Build the wormhole scene (models, skeletons, sprites, fade-in).
void Nanosaur2Saver_StartScene(void);

/// Tear the scene down (objects, skeletons, sprites, game view).
void Nanosaur2Saver_StopScene(void);

/// Advance and draw one frame. The host's GL context must be current;
/// pass the view's backing size in pixels. The host presents afterwards.
void Nanosaur2Saver_Frame(int32_t pixelWidth, int32_t pixelHeight);

#ifdef __cplusplus
}
#endif
