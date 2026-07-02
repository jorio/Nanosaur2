//
// Skeleton.h
//

#ifndef __SKELOBJ
#define __SKELOBJ

#include "structs.h"

enum
{
	SKELETON_TYPE_PLAYER = 0,
	SKELETON_TYPE_WORMHOLE,
	SKELETON_TYPE_RAPTOR,
	SKELETON_TYPE_BONUSWORMHOLE,
	SKELETON_TYPE_BRACH,
	SKELETON_TYPE_WORM,
	SKELETON_TYPE_RAMPHOR,

	MAX_SKELETON_TYPES
};


		/* ANIM EVENTS */

#define	MAX_ANIM_EVENTS		30

#define	MAX_ANIMEVENT_TYPES	7

enum
{
	ANIM_DIRECTION_FORWARD,
	ANIM_DIRECTION_BACKWARD
};


enum
{
	ANIMEVENT_TYPE_STOP,
	ANIMEVENT_TYPE_LOOP,
	ANIMEVENT_TYPE_ZIGZAG,
	ANIMEVENT_TYPE_GOTOMARKER,
	ANIMEVENT_TYPE_SETMARKER,
	ANIMEVENT_TYPE_PLAYSOUND,
	ANIMEVENT_TYPE_SETFLAG,
	ANIMEVENT_TYPE_CLEARFLAG,
	ANIMEVENT_TYPE_PAUSE
};

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