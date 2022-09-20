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
extern	float		gAnaglyphSeparationTweak;
extern  Byte		gCameraMode[];

//================================


void UpdateCameras(void);
void InitCamera_Terrain(short playerNum);
void DrawLensFlare(const OGLSetupOutputType *setupInfo);


void PrepAnaglyphCameras(void);
void RestoreCamerasFromAnaglyph(void);
void CalcAnaglyphCameraOffset(Byte pane, Byte pass);
