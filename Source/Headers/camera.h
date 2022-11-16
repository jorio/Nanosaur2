//
// camera.h
//

enum
{
	CAMERA_MODE_NORMAL = 0,
	CAMERA_MODE_FIRSTPERSON,
	CAMERA_MODE_ANAGLYPHCLOSE
};


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
