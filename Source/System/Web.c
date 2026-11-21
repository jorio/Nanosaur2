#ifdef __EMSCRIPTEN__
#include "game.h"
float gWebFlightCameraDistance = 280.0f;

int WebGetKey(int key)
{
    switch (key)
    {
        case kNeed_PitchUp: return WebGetButton(WEB_UP);
        case kNeed_PitchDown: return WebGetButton(WEB_DOWN);
        case kNeed_YawLeft: return WebGetButton(WEB_LEFT);
        case kNeed_YawRight: return WebGetButton(WEB_RIGHT);
        case kNeed_Fire: return WebGetButton(WEB_KICK);
        case kNeed_Drop: return WebGetButton(WEB_PICKUP);
        case kNeed_NextWeapon: return WebGetButton(WEB_NEXT_WEAPON);
        case kNeed_PrevWeapon: return WebGetButton(WEB_PREV_WEAPON);
        case kNeed_Jetpack: return WebGetButton(WEB_JET);
        case kNeed_CameraMode: return WebGetButton(WEB_CAMERA_MODE);
        case kNeed_UIUp: return WebGetButton(WEB_UP);
        case kNeed_UIDown: return WebGetButton(WEB_DOWN);
        case kNeed_UIPrev: return WebGetButton(WEB_LEFT);
        case kNeed_UINext: return WebGetButton(WEB_RIGHT);
        case kNeed_UIConfirm: return WebGetButton(WEB_CONFIRM);
        case kNeed_UIStart: return WebGetButton(WEB_CONFIRM);
        case kNeed_UIBack: return WebGetButton(WEB_PAUSE);
        case kNeed_UIPause: return WebGetButton(WEB_PAUSE);
        default: return 0;
    }
}
float WebGetAnalog(int key)
{
    float x,y; WebGetMovement(&x,&y);
    switch (key)
    {
        case kNeed_YawLeft: return fmaxf(0, -x);
        case kNeed_YawRight: return fmaxf(0, x);
        case kNeed_PitchUp: return fmaxf(0, -y);
        case kNeed_PitchDown: return fmaxf(0, y);
        default: return WebGetKey(key) ? 1.0f : 0.0f;
    }
}
void WebGameResize(int width, int height) { gGameWindowWidth = width; gGameWindowHeight = height; }
void WebEndFrame(void) { WebPresent(WebIsGameplayActive(), gGamePaused); }
#endif
