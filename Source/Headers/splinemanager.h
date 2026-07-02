//
// splinemanager.h
//

#pragma once

#define MAX_CUSTOM_SPLINES		40

#pragma clang assume_nonnull begin

typedef struct
{
	Boolean			isUsed;
	long			numPoints;
	OGLPoint3D		* _Nullable splinePoints;
}CustomSplineType;

extern  CustomSplineType	gCustomSplines[MAX_CUSTOM_SPLINES];


//=================


void InitSplineManager(void);
void FreeAllCustomSplines(void);
short GenerateCustomSpline(short numNubs, OGLPoint3D *nubPoints, long pointsPerSpan) ;
void FreeACustomSpline(short splineNum);

#pragma clang assume_nonnull end
