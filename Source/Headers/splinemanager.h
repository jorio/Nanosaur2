//
// splinemanager.h
//


#define MAX_CUSTOM_SPLINES		40


typedef struct
{
	Boolean			isUsed;
	long			numPoints;
	OGLPoint3D		*splinePoints;
}CustomSplineType;

extern  CustomSplineType	gCustomSplines[MAX_CUSTOM_SPLINES];


//=================


void InitSplineManager(void);
void FreeAllCustomSplines(void);
short GenerateCustomSpline(short numNubs, OGLPoint3D *nubPoints, long pointsPerSpan) ;
void FreeACustomSpline(short splineNum);
