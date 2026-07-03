//
// Skeleton.h
//

#ifndef __SKELOBJ
#define __SKELOBJ

#include "structs.h"

typedef enum SWIFT_ENUM_CLOSED SkeletonType
{
	SKELETON_TYPE_PLAYER SWIFT_NAME(player) = 0,
	SKELETON_TYPE_WORMHOLE SWIFT_NAME(wormhole),
	SKELETON_TYPE_RAPTOR SWIFT_NAME(raptor),
	SKELETON_TYPE_BONUSWORMHOLE SWIFT_NAME(bonusWormhole),
	SKELETON_TYPE_BRACH SWIFT_NAME(brach),
	SKELETON_TYPE_WORM SWIFT_NAME(worm),
	SKELETON_TYPE_RAMPHOR SWIFT_NAME(ramphor),

	MAX_SKELETON_TYPES SWIFT_NAME(_count)
} SkeletonType;


		/* ANIM EVENTS */

#define	MAX_ANIM_EVENTS		30

#define	MAX_ANIMEVENT_TYPES	7

typedef enum SWIFT_ENUM_CLOSED AnimDirection
{
	ANIM_DIRECTION_FORWARD SWIFT_NAME(forward),
	ANIM_DIRECTION_BACKWARD SWIFT_NAME(backward)
} AnimDirection;


typedef enum SWIFT_ENUM_CLOSED AnimEventKind
{
	ANIMEVENT_TYPE_STOP SWIFT_NAME(stop),
	ANIMEVENT_TYPE_LOOP SWIFT_NAME(loop),
	ANIMEVENT_TYPE_ZIGZAG SWIFT_NAME(zigzag),
	ANIMEVENT_TYPE_GOTOMARKER SWIFT_NAME(gotoMarker),
	ANIMEVENT_TYPE_SETMARKER SWIFT_NAME(setMarker),
	ANIMEVENT_TYPE_PLAYSOUND SWIFT_NAME(playSound),
	ANIMEVENT_TYPE_SETFLAG SWIFT_NAME(setFlag),
	ANIMEVENT_TYPE_CLEARFLAG SWIFT_NAME(clearFlag),
	ANIMEVENT_TYPE_PAUSE SWIFT_NAME(pause)
} AnimEventKind;

		/* ACCELERATION MODES */
typedef enum SWIFT_ENUM_CLOSED AccelerationMode
{
	ACCEL_MODE_LINEAR SWIFT_NAME(linear),
	ACCEL_MODE_EASEINOUT SWIFT_NAME(easeInOut),
	ACCEL_MODE_EASEIN SWIFT_NAME(easeIn),
	ACCEL_MODE_EASEOUT SWIFT_NAME(easeOut)
} AccelerationMode;


#define	NUM_ACCELERATION_CURVE_NUBS		23						// THESE MUST MATCH BIO-OREO'S NUMBERS!!!
#define	SPLINE_POINTS_PER_NUB			100
#define CURVE_SIZE						((NUM_ACCELERATION_CURVE_NUBS-3)*SPLINE_POINTS_PER_NUB)



#define	NO_PREVIOUS_JOINT	(-1)

extern  float	gAccelerationCurve[CURVE_SIZE];
static inline float* GetAccelerationCurvePtr(void) { return gAccelerationCurve; }


//===============================

extern	ObjNode	*MakeNewSkeletonObject(NewObjectDefinitionType *newObjDef);
extern	void AllocSkeletonDefinitionMemory(SkeletonDefType *skeleton);
extern	void InitSkeletonManager(void);
void LoadASkeleton(Byte num);
extern	void FreeSkeletonFile(Byte skeletonType);
extern	void FreeAllSkeletonFiles(short skipMe);
void FreeSkeletonBaseData(SkeletonObjDataType *skeletonData, short skeletonType);
void DrawSkeleton(ObjNode *theNode);



extern	void UpdateSkeletonAnimation(ObjNode *theNode);
extern	void SetSkeletonAnim(SkeletonObjDataType *skeleton, long animNum);
extern	void GetModelCurrentPosition(SkeletonObjDataType *skeleton);
extern	void MorphToSkeletonAnim(SkeletonObjDataType *skeleton, long animNum, float speed);
extern	void CalcAccelerationSplineCurve(void);
void SetSkeletonAnimTime(SkeletonObjDataType *skeleton, float timeRatio);

void BurnSkeleton(ObjNode *theNode, float flameScale);


extern	void UpdateJointTransforms(SkeletonObjDataType * _Nonnull skeleton,long jointNum);
void FindCoordOfJoint(ObjNode * _Nonnull theNode, long jointNum, OGLPoint3D * _Nonnull outPoint);
void FindCoordOnJoint(ObjNode * _Nonnull theNode, long jointNum, const OGLPoint3D * _Nonnull inPoint, OGLPoint3D * _Nonnull outPoint);
void FindJointFullMatrix(ObjNode * _Nonnull theNode, long jointNum, OGLMatrix4x4 * _Nonnull outMatrix);
void FindCoordOnJointAtFlagEvent(ObjNode * _Nonnull theNode, long jointNum, const OGLPoint3D * _Nonnull inPoint, OGLPoint3D * _Nonnull outPoint);
void FindJointMatrixAtFlagEvent(ObjNode * _Nonnull theNode, long jointNum, Byte flagNum, OGLMatrix4x4 * _Nonnull m);


void LoadBonesReferenceModel(FSSpec	*inSpec, SkeletonDefType *skeleton, int skeletonType);
extern	void UpdateSkinnedGeometry(ObjNode *theNode);
extern	void PrimeBoneData(SkeletonDefType *skeleton);


#endif