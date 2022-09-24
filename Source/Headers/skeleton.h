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
enum
{
	ACCEL_MODE_LINEAR,
	ACCEL_MODE_EASEINOUT,
	ACCEL_MODE_EASEIN,
	ACCEL_MODE_EASEOUT
};


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


extern	void UpdateJointTransforms(SkeletonObjDataType *skeleton,long jointNum);
void FindCoordOfJoint(ObjNode *theNode, long jointNum, OGLPoint3D *outPoint);
void FindCoordOnJoint(ObjNode *theNode, long jointNum, const OGLPoint3D *inPoint, OGLPoint3D *outPoint);
void FindJointFullMatrix(ObjNode *theNode, long jointNum, OGLMatrix4x4 *outMatrix);
void FindCoordOnJointAtFlagEvent(ObjNode *theNode, long jointNum, const OGLPoint3D *inPoint, OGLPoint3D *outPoint);
void FindJointMatrixAtFlagEvent(ObjNode *theNode, long jointNum, Byte flagNum, OGLMatrix4x4 *m);


void LoadBonesReferenceModel(FSSpec	*inSpec, SkeletonDefType *skeleton, int skeletonType);
extern	void UpdateSkinnedGeometry(ObjNode *theNode);
extern	void PrimeBoneData(SkeletonDefType *skeleton);


#endif