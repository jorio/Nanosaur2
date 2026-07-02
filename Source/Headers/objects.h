//
// Object.h
//

#pragma once

#define INVALID_NODE_FLAG	0xdeadbeef			// put into CType when node is deleted

#define	TERRAIN_SLOT	1
#define	PLAYER_SLOT		50						// note:  draw any "OGL fenced" objects first for best performance (we want their fences ending asap)
#define	ENEMY_SLOT		(PLAYER_SLOT+10)
#define	SLOT_OF_DUMB	3000
#define	BGPIC_SLOT		SLOT_OF_DUMB
#define	SPRITE_SLOT		(SLOT_OF_DUMB+100)
#define	FENCE_SLOT		(TERRAIN_SLOT+3)		// need to draw very early for alpha blending of other objects to look best
#define	PARTICLE_SLOT	(SPRITE_SLOT-2)
#define	CONFETTI_SLOT	(PARTICLE_SLOT-1)		// do confetti before particles since particles are xparent
#define	WATER_SLOT		(SLOT_OF_DUMB - 50)		// do before DUMB because some glowing weapons need to be drawn after the water
#define	CONTRAIL_SLOT	(SPRITE_SLOT - 10)
#define	INFOBAR_SLOT	(SLOT_OF_DUMB + 3000)
#define	FADEPANE_SLOT	(SLOT_OF_DUMB + 4000)
#define	MENU_SLOT		INFOBAR_SLOT
#define	PANEDIVIDER_SLOT (INFOBAR_SLOT-1)
#define	CURSOR_SLOT		(MENU_SLOT + 100)

enum
{
	ILLEGAL_GENRE = 0,
	SKELETON_GENRE,
	DISPLAY_GROUP_GENRE,
	SPRITE_GENRE,
	CUSTOM_GENRE,
	EVENT_GENRE,
	TEXTMESH_GENRE,
	QUADMESH_GENRE,
};


typedef enum SWIFT_ENUM_CLOSED ShadowType
{
	SHADOW_TYPE_CIRCULAR SWIFT_NAME(circular),
	SHADOW_TYPE_BALSAPLANE SWIFT_NAME(balsaPlane),
	SHADOW_TYPE_CIRCULARDARK SWIFT_NAME(circularDark),
	SHADOW_TYPE_SQUARE SWIFT_NAME(square)
} ShadowType;


typedef enum SWIFT_ENUM_CLOSED WhatType
{
	WHAT_UNDEFINED SWIFT_NAME(undefined) = 0,

	WHAT_ELECTRODE SWIFT_NAME(electrode),
	WHAT_EGGWORMHOLE SWIFT_NAME(eggWormhole),
	WHAT_EGG SWIFT_NAME(egg),
	WHAT_HOLE SWIFT_NAME(hole)
} WhatType;


#define	ShadowScaleX	SpecialF[0]
#define	ShadowScaleZ	SpecialF[1]
#define	CheckForBlockers	Flag[0]


//========================================================

extern	void InitObjectManager(void);
extern	ObjNode	* _Nullable MakeNewObject(NewObjectDefinitionType * _Nonnull newObjDef);
extern	void MoveObjects(void);
void DrawObjects(void);

extern	void DeleteAllObjects(void);
extern	void DeleteObject(ObjNode * _Nullable theNode);
void DetachObject(ObjNode * _Nullable theNode, Boolean subrecurse);
extern	void GetObjectInfo(ObjNode * _Nonnull theNode);
extern	void UpdateObject(ObjNode * _Nonnull theNode);
void SetObjectGridLocation(ObjNode * _Nonnull theNode);
extern	ObjNode * _Nullable MakeNewDisplayGroupObject(NewObjectDefinitionType * _Nonnull newObjDef);
extern	void CreateBaseGroup(ObjNode * _Nonnull theNode);
extern	void UpdateObjectTransforms(ObjNode * _Nonnull theNode);
extern	void SetObjectTransformMatrix(ObjNode * _Nonnull theNode);
extern	void DisposeObjectBaseGroup(ObjNode * _Nonnull theNode);
extern	void ResetDisplayGroupObject(ObjNode * _Nonnull theNode);
void AttachObject(ObjNode * _Nullable theNode, Boolean recurse);
void CalcObjectRadiusFromBBox(ObjNode * _Nonnull theNode);

void MoveStaticObject(ObjNode * _Nullable theNode);
void MoveStaticObject2(ObjNode * _Nullable theNode);
void MoveStaticObject3(ObjNode * _Nullable theNode);

void CalcNewTargetOffsets(ObjNode *theNode, float scale);

//===================


void CalcObjectBoxFromNode(ObjNode *theNode);
void CalcObjectBoxFromGlobal(ObjNode *theNode);
void SetObjectCollisionBounds(ObjNode *theNode, float top, float bottom, float left,
							 float right, float front, float back);
ObjNode	*AttachStaticShadowToObject(ObjNode *theNode, ShadowType shadowType, float scaleX, float scaleZ);
void UpdateShadow(ObjNode *theNode);

void CullTestAllObjects(void);
Boolean	IsObjectTotallyCulled(ObjNode *theNode);

ObjNode	*AttachShadowToObject(ObjNode *theNode, ShadowType shadowType, float scaleX, float scaleZ, Boolean checkBlockers);
void CreateCollisionBoxFromBoundingBox(ObjNode *theNode, float tweakXZ, float tweakY);
void CreateCollisionBoxFromBoundingBox_Maximized(ObjNode *theNode, float scaleMag);
void CreateCollisionBoxFromBoundingBox_Rotated(ObjNode *theNode, float tweakXZ, float tweakY);
void CreateCollisionBoxFromBoundingBox_Update(ObjNode *theNode, float tweakXZ, float tweakY);
void KeepOldCollisionBoxes(ObjNode *theNode);
void AddCollisionBoxToObject(ObjNode *theNode, float top, float bottom, float left,
							 float right, float front, float back);
void AttachGeometryToDisplayGroupObject(ObjNode * _Nonnull theNode, MetaObjectPtr _Nullable geometry);
void CalcDisplayGroupWorldPoints(ObjNode *theNode);

void HideObjectChain(ObjNode *theNode);
void ShowObjectChain(ObjNode *theNode);

Boolean SetObjectVisible(ObjNode * _Nonnull theNode, Boolean visible);

int GetNodeChainLength(ObjNode* _Nullable start);
ObjNode* _Nullable GetNthChainedNode(ObjNode* _Nullable start, int targetIndex, ObjNode* _Nullable * _Nullable outPrevNode);
ObjNode* _Nullable GetChainTailNode(ObjNode* _Nullable start);
void AppendNodeToChain(ObjNode* _Nonnull start, ObjNode* _Nonnull newTail);
void UnchainNode(ObjNode* _Nullable theNode);

ObjNode* MakeBackgroundPictureObject(const char* imagePath);

void SendNodeToOverlayPane(ObjNode* _Nonnull theNode);
