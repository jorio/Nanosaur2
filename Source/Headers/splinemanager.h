//
// splinemanager.h
//


typedef struct
{
	Boolean			isUsed;
	long			numPoints;
	OGLPoint3D		*splinePoints;
}CustomSplineType;

extern  CustomSplineType	gCustomSplines[];


//=================


void InitSplineManager(void);
void FreeAllCustomSplines(void);
short GenerateCustomSpline(short numNubs, OGLPoint3D *nubPoints, long pointsPerSpan) ;
void FreeACustomSpline(short splineNum);
