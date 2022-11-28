//
// fences.h
//

#pragma once

#define MAX_FENCES			90
#define	MAX_NUBS_IN_FENCE	80

enum
{
	FENCE_TYPE_PINETREES,
	FENCE_TYPE_INVISIBLEBLOCKENEMY,
	NUM_FENCE_TYPES
};

typedef struct
{
	uint16_t		type;				// type of fence
	short			numNubs;			// # nubs in fence
	OGLPoint3D		*nubList;			// pointer to nub list
	OGLBoundingBox	bBox;				// bounding box of fence area
	OGLVector2D		*sectionVectors;	// for each section/span, this is the vector from nub(n) to nub(n+1)
	OGLVector2D		*sectionNormals;	// for each section/span, this is the perpendicular normal vector
}FenceDefType;

//============================================

void PrimeFences(void);
void UpdateFences(void);
Boolean DoFenceCollision(ObjNode *theNode);
void DisposeFences(void);
//Boolean SeeIfLineSegmentHitsFence(const OGLPoint3D *endPoint1, const OGLPoint3D *endPoint2, OGLPoint3D *intersect, Boolean *overTop, float *fenceTopY);
