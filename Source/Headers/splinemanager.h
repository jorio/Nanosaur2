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


//=================



#pragma clang assume_nonnull end
