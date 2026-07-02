//
// camera.h
//

typedef enum SWIFT_ENUM_CLOSED CameraMode
{
	CAMERA_MODE_NORMAL SWIFT_NAME(CAMERA_MODE_NORMAL) = 0,
	CAMERA_MODE_FIRSTPERSON SWIFT_NAME(CAMERA_MODE_FIRSTPERSON),
	CAMERA_MODE_ANAGLYPHCLOSE SWIFT_NAME(CAMERA_MODE_ANAGLYPHCLOSE)
} CameraMode;


		/* EXTERNS */

extern	Boolean		gCameraInDeathDiveMode[], gCameraInExitMode;
extern  Byte		gCameraMode[];

//================================

float GetSplitscreenPaneFOV(void);

void UpdateCameras(void);
void InitCamera_Terrain(short playerNum);
void DrawLensFlare(void);


void PrepAnaglyphCameras(void);
void RestoreCamerasFromAnaglyph(void);
void CalcAnaglyphCameraOffset(Byte pane, Byte pass);
