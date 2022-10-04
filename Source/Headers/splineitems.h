//
// splineitems.h
//


extern	SplineDefType	*gSplineList;


//=====================================================

void PrimeSplines(void);
void GetCoordOnSplineFromIndex(SplineDefType *splinePtr, float findex, float *x, float *z);
void GetCoordOnSpline(SplineDefType *splinePtr, float placement, float *x, float *z);
void GetCoordOnSpline2(SplineDefType *splinePtr, float placement, float offset, float *x, float *z);
void GetNextCoordOnSpline(SplineDefType *splinePtr, float placement, float *x, float *z);
Boolean IsSplineItemOnActiveTerrain(ObjNode *theNode);
void AddToSplineObjectList(ObjNode *theNode, Boolean setAim);
void MoveSplineObjects(void);
Boolean RemoveFromSplineObjectList(ObjNode *theNode);
void EmptySplineObjectList(void);
Boolean IncreaseSplineIndex(ObjNode *theNode, float speed);
void IncreaseSplineIndexZigZag(ObjNode *theNode, float speed);
void DetachObjectFromSpline(ObjNode *theNode, void (*moveCall)(ObjNode*));
void SetSplineAim(ObjNode *theNode);
void GetObjectCoordOnSpline(ObjNode *theNode);
void GetObjectCoordOnSpline2(ObjNode *theNode, float *x, float *z);
