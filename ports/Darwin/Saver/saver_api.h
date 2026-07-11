// saver_api.h - the C surface between the engine module (SaverGlue.swift,
// compiled with the game's bridging header) and the ScreenSaverView host
// module (Nanosaur2SaverView.swift, which imports AppKit and therefore
// can't see the game's bridging header). This is the host module's
// bridging header - keep it to plain C scalars only.

#pragma once

#include <stdbool.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/// Boot the engine against the host's CAMetalLayer. Call once per process,
/// with the absolute path of the bundle's Data folder, the layer pointer
/// (a CAMetalLayer*), and the layer's backing size in pixels. Returns
/// false if Metal isn't available.
bool Nanosaur2Saver_Boot(const char* dataPath, void* caMetalLayer, int32_t pixelWidth, int32_t pixelHeight);

/// Rebind rendering to a different CAMetalLayer (e.g. System Settings
/// swapping its thumbnail for the full-screen preview). Stops the scene
/// and reloads every GPU texture against the new layer; call
/// Nanosaur2Saver_StartScene afterwards.
bool Nanosaur2Saver_AttachLayer(void* caMetalLayer, int32_t pixelWidth, int32_t pixelHeight);

/// Build the wormhole scene (models, skeletons, sprites, fade-in).
/// No-op if the scene is already up.
void Nanosaur2Saver_StartScene(void);

/// Tear the scene down (objects, skeletons, sprites, game view).
/// No-op if the scene isn't up.
void Nanosaur2Saver_StopScene(void);

/// Advance and draw one frame; pass the view's backing size in pixels
/// (the Metal drawable follows it). Presentation happens inside.
void Nanosaur2Saver_Frame(int32_t pixelWidth, int32_t pixelHeight);

/// Headless-test hooks (SaverSmoke): capture finished frames (slow -
/// synchronous GPU readback) and copy the last one out as top-down BGRA.
void Nanosaur2Saver_SetCaptureEnabled(bool enabled);
bool Nanosaur2Saver_CopyLastFrame(uint8_t* out, int32_t outCapacity, int32_t* outWidth, int32_t* outHeight);

#ifdef __cplusplus
}
#endif
