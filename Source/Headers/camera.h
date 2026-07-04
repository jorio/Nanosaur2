//
// camera.h
//

typedef enum SWIFT_ENUM_CLOSED CameraMode
{
	CAMERA_MODE_NORMAL SWIFT_NAME(normal) = 0,
	CAMERA_MODE_FIRSTPERSON SWIFT_NAME(firstPerson),
	CAMERA_MODE_ANAGLYPHCLOSE SWIFT_NAME(anaglyphClose)
} CameraMode;


		/* EXTERNS */

extern	Boolean		gCameraInDeathDiveMode[], gCameraInExitMode;
extern  Byte		gCameraMode[];

//================================

float GetSplitscreenPaneFOV(void);



