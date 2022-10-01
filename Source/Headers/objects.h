//
// Object.h
//

#pragma once

#define INVALID_NODE_FLAG	0xdeadbeef			// put into CType when node is deleted

#define	TERRAIN_SLOT	1
#define	PLAYER_SLOT		50						// note:  draw any "OGL fenced" objects first for best performance (we want their fences ending asap)
#define	ENEMY_SLOT		(PLAYER_SLOT+10)
#define	SLOT_OF_DUMB	3000
#define	SPRITE_SLOT		(SLOT_OF_DUMB+100)
#define	FENCE_SLOT		(TERRAIN_SLOT+3)		// need to draw very early for alpha blending of other objects to look best
#define	PARTICLE_SLOT	(SPRITE_SLOT-2)
#define	CONFETTI_SLOT	(PARTICLE_SLOT-1)		// do confetti before particles since particles are xparent
#define	WATER_SLOT		(SLOT_OF_DUMB - 50)		// do before DUMB because some glowing weapons need to be drawn after the water
#define	CONTRAIL_SLOT	(SPRITE_SLOT - 10)
#define	INFOBAR_SLOT	(SLOT_OF_DUMB + 3000)
#define	FADEPANE_SLOT	(SLOT_OF_DUMB + 4000)
#define	MENU_SLOT		INFOBAR_SLOT
#define	CURSOR_SLOT		(MENU_SLOT + 100)

enum
{
	ILLEGAL_GENRE = 0,
	SKELETON_GENRE,
	DISPLAY_GROUP_GENRE,
	SPRITE_GENRE,
	CUSTOM_GENRE,
	EVENT_GENRE,
	FONTSTRING_GENRE,
	TEXTMESH_GENRE,
	QUADMESH_GENRE,
};


enum
{
	SHADOW_TYPE_CIRCULAR,
	SHADOW_TYPE_BALSAPLANE,
	SHADOW_TYPE_CIRCULARDARK,
	SHADOW_TYPE_SQUARE
};


enum
{
	WHAT_UNDEFINED = 0,

	WHAT_ELECTRODE,
	WHAT_EGGWORMHOLE,
	WHAT_EGG,
	WHAT_HOLE
};


#define	ShadowScaleX	SpecialF[0]
#define	ShadowScaleZ	SpecialF[1]
#define	CheckForBlockers	Flag[0]


//========================================================

extern	void InitObjectManager(void);
extern	ObjNode	*MakeNewObject(NewObjectDefinitionType *newObjDef);
extern	void MoveObjects(void);
void DrawObjects(void);

extern	void DeleteAllObjects(void);
extern	void DeleteObject(ObjNode	*theNode);
void DetachObject(ObjNode *theNode, Boolean subrecurse);
extern	void GetObjectInfo(ObjNode *theNode);
extern	void UpdateObject(ObjNode *theNode);
void SetObjectGridLocation(ObjNode *theNode);
extern	ObjNode *MakeNewDisplayGroupObject(NewObjectDefinitionType *newObjDef);
extern	void CreateBaseGroup(ObjNode *theNode);
extern	void UpdateObjectTransforms(ObjNode *theNode);
extern	void SetObjectTransformMatrix(ObjNode *theNode);
extern	void DisposeObjectBaseGroup(ObjNode *theNode);
extern	void ResetDisplayGroupObject(ObjNode *theNode);
void AttachObject(ObjNode *theNode, Boolean recurse);
void CalcObjectRadiusFromBBox(ObjNode *theNode);

void MoveStaticObject(ObjNode *theNode);
void MoveStaticObject2(ObjNode *theNode);
void MoveStaticObject3(ObjNode *theNode);

void CalcNewTargetOffsets(ObjNode *theNode, float scale);

//===================


void CalcObjectBoxFromNode(ObjNode *theNode);
void CalcObjectBoxFromGlobal(ObjNode *theNode);
void SetObjectCollisionBounds(ObjNode *theNode, float top, float bottom, float left,
							 float right, float front, float back);
ObjNode	*AttachStaticShadowToObject(ObjNode *theNode, int shadowType, float scaleX, float scaleZ);
void UpdateShadow(ObjNode *theNode);

void CullTestAllObjects(void);
Boolean	IsObjectTotallyCulled(ObjNode *theNode);

ObjNode	*AttachShadowToObject(ObjNode *theNode, int shadowType, float scaleX, float scaleZ, Boolean checkBlockers);
void CreateCollisionBoxFromBoundingBox(ObjNode *theNode, float tweakXZ, float tweakY);
void CreateCollisionBoxFromBoundingBox_Maximized(ObjNode *theNode, float scaleMag);
void CreateCollisionBoxFromBoundingBox_Rotated(ObjNode *theNode, float tweakXZ, float tweakY);
void CreateCollisionBoxFromBoundingBox_Update(ObjNode *theNode, float tweakXZ, float tweakY);
void KeepOldCollisionBoxes(ObjNode *theNode);
void AddCollisionBoxToObject(ObjNode *theNode, float top, float bottom, float left,
							 float right, float front, float back);
void AttachGeometryToDisplayGroupObject(ObjNode *theNode, MetaObjectPtr geometry);
void CalcDisplayGroupWorldPoints(ObjNode *theNode);

void HideObjectChain(ObjNode *theNode);
void ShowObjectChain(ObjNode *theNode);

Boolean SetObjectVisible(ObjNode *theNode, Boolean visible);

int GetNodeChainLength(ObjNode* start);
ObjNode* GetNthChainedNode(ObjNode* start, int targetIndex, ObjNode** outPrevNode);
ObjNode* GetChainTailNode(ObjNode* start);
void AppendNodeToChain(ObjNode* start, ObjNode* newTail);
void UnchainNode(ObjNode* theNode);
