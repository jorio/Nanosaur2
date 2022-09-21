//
// structs.h
//

#ifndef STRUCTS_H
#define STRUCTS_H


#include "globals.h"
#include "ogl_support.h"
#include "metaobjects.h"
#include "bg3d.h"

#define	MAX_ANIMS			40
#define	MAX_KEYFRAMES		60
#define	MAX_JOINTS			40
#define	MAX_CHILDREN		(MAX_JOINTS-1)

#define MAX_FLAGS_IN_OBJNODE			5		// # flags in ObjNode


#define	MAX_DECOMPOSED_POINTS	2000
#define	MAX_DECOMPOSED_NORMALS	2000
#define	MAX_POINT_REFS			20		// max times a point can be re-used in multiple places
#define	MAX_DECOMPOSED_TRIMESHES 10

#define	MAX_MORPH_TRIMESHES		10
#define	MAX_MORPH_POINTS		3000

#define	MAX_NODE_SPARKLES		20

#define	MAX_COLLISION_BOXES		8

#define	MAX_CONTRAILS_PER_OBJNODE	2

#define	MAX_MESHES_IN_MODEL		10					// max # of different meshes in a single ObjNode model / BG3D model


			/*********************/
			/* SPLINE STRUCTURES */
			/*********************/

typedef	struct
{
	float	x,z;
}SplinePointType;

typedef struct
{
	float			placement;			// where on spline to start item (0=front, 1.0 = end)
	uint16_t		type;
	uint8_t			parm[4];
	uint16_t		flags;
}SplineItemType;


typedef struct
{
	int16_t			numNubs;			// # nubs in spline
	SplinePointType	*nubList;			// ptr to nub list
	int32_t			numPoints;			// # points in spline
	SplinePointType	*pointList;			// ptr to calculated spline points
	int16_t			numItems;			// # items on the spline
	SplineItemType	*itemList;			// ptr to spline items

	Rect			bBox;				// bounding box of spline area
}SplineDefType;




		/* COLLISION BOX */

typedef struct
{
	float	left,right,front,back,top,bottom;
	float	oldLeft,oldRight,oldFront,oldBack,oldTop,oldBottom;
}CollisionBoxType;



//*************************** SKELETON *****************************************/

		/* BONE SPECIFICATIONS */
		//
		//
		// NOTE: Similar to joint definition but lacks animation, rot/scale info.
		//

typedef struct
{
	long 				parentBone;			 			// index to previous bone
	void				*ignored1;
	OGLMatrix4x4		ignored2;
	void				*ignored3;
	unsigned char		ignored4[32];
	OGLPoint3D			coord;							// absolute coord (not relative to parent!)
	u_short				numPointsAttachedToBone;		// # vertices/points that this bone has
	u_short				*pointList;						// indecies into gDecomposedPointList
	u_short				numNormalsAttachedToBone;		// # vertex normals this bone has
	u_short				*normalList;					// indecies into gDecomposedNormalsList
}BoneDefinitionType;


			/* DECOMPOSED POINT INFO */

typedef struct
{
	OGLPoint3D	realPoint;							// point coords as imported in 3DMF model
	OGLPoint3D	boneRelPoint;						// point relative to bone coords (offset from bone)

	Byte		numRefs;							// # of places this point is used in the geometry data
	Byte		whichTriMesh[MAX_POINT_REFS];		// index to trimeshes
	short		whichPoint[MAX_POINT_REFS];			// index into pointlist of triMesh above
	short		whichNormal[MAX_POINT_REFS];		// index into gDecomposedNormalsList
}DecomposedPointType;



		/* CURRENT JOINT STATE */

typedef struct
{
	int32_t		tick;					// time at which this state exists
	int32_t		accelerationMode;		// mode of in/out acceleration
	OGLPoint3D	coord;					// current 3D coords of joint (relative to link)
	OGLVector3D	rotation;				// current rotation values of joint (relative to link)
	OGLVector3D	scale;					// current scale values of joint mesh
}JointKeyframeType;


		/* JOINT DEFINITIONS */

typedef struct
{
	signed char			numKeyFrames[MAX_ANIMS];				// # keyframes
	JointKeyframeType 	**keyFrames;							// 2D array of keyframe data keyFrames[anim#][keyframe#]
}JointKeyFrameHeader;

			/* ANIM EVENT TYPE */

typedef struct
{
	short	time;
	Byte	type;
	Byte	value;
}AnimEventType;


			/* SKELETON INFO */


typedef struct
{
	Byte				NumBones;						// # joints in this skeleton object
	JointKeyFrameHeader	JointKeyframes[MAX_JOINTS];		// array of joint definitions

	Byte				numChildren[MAX_JOINTS];		// # children each joint has
	Byte				childIndecies[MAX_JOINTS][MAX_CHILDREN];	// index to each child

	Byte				NumAnims;						// # animations in this skeleton object
	Byte				*NumAnimEvents;					// ptr to array containing the # of animevents for each anim
	AnimEventType		**AnimEventsList;				// 2 dimensional array which holds a anim event list for each anim AnimEventsList[anim#][event#]

	BoneDefinitionType	*Bones;							// data which describes bone heirarachy

	long				numDecomposedTriMeshes;			// # trimeshes in skeleton
	MOVertexArrayData	decomposedTriMeshes[MAX_DECOMPOSED_TRIMESHES];	// array of triMeshData

	long				numDecomposedPoints;			// # shared points in skeleton
	DecomposedPointType	*decomposedPointList;			// array of shared points

	short				numDecomposedNormals ;			// # shared normal vectors
	OGLVector3D			*decomposedNormalsList;			// array of shared normals


}SkeletonDefType;


		/* THE STRUCTURE ATTACHED TO AN OBJNODE */
		//
		// This contains all of the local skeleton data for a particular ObjNode
		//

typedef struct
{
	Boolean			JointsAreGlobal;				// true when joints are already in world-space coords
	Byte			AnimNum;						// animation #

	Boolean			IsMorphing;						// flag set when morphing from an anim to another
	float			MorphSpeed;						// speed of morphing (1.0 = normal)
	float			MorphPercent;					// percentage of morph from kf1 to kf2 (0.0 - 1.0)

	JointKeyframeType	JointCurrentPosition[MAX_JOINTS];	// for each joint, holds current interpolated keyframe values
	JointKeyframeType	MorphStart[MAX_JOINTS];		// morph start & end keyframes for each joint
	JointKeyframeType	MorphEnd[MAX_JOINTS];

	float			CurrentAnimTime;				// current time index for animation
	float			LoopBackTime;					// time to loop or zigzag back to (default = 0 unless set by a setmarker)
	float			MaxAnimTime;					// duration of current anim
	float			AnimSpeed;						// time factor for speed of executing current anim (1.0 = normal time)
	float			PauseTimer;						// # seconds to pause animation
	Byte			AnimEventIndex;					// current index into anim event list
	Byte			AnimDirection;					// if going forward in timeline or backward
	Byte			EndMode;						// what to do when reach end of animation
	Boolean			AnimHasStopped;					// flag gets set when anim has reached end of sequence (looping anims don't set this!)

	OGLMatrix4x4	jointTransformMatrix[MAX_JOINTS];	// holds matrix xform for each joint

	SkeletonDefType	*skeletonDefinition;			// point to skeleton file's definition data

	MOMaterialObject	*overrideTexture[MAX_DECOMPOSED_TRIMESHES];		// an illegal ref to a texture object for each trimesh in skeleton

//	Byte			activeBuffer;					// which of the double-buffered Vertex Array's is the current one used for skinning, drawing, and collision?
	MOVertexArrayData	deformedMeshes[2][MAX_DECOMPOSED_TRIMESHES];	// double-buffered triMeshes which are re-built each frame during the animation update

	GLuint			oglFence;
	Boolean			oglFenceIsActive;

}SkeletonObjDataType;


			/* TERRAIN ITEM ENTRY TYPE */
			//
			//
			// note:  this isn't the same as the File_TerrainItemEntryType which is
			//		what's read in from the .ter files.
			//

typedef struct
{
	uint32_t							x,y;
	u_short							type;
	Byte							parm[4];
	u_short							flags;

	float							terrainY;						// calculated terrain Y at this init coord
}TerrainItemEntryType;




			/****************************/
			/*  OBJECT RECORD STRUCTURE */
			/****************************/

struct ObjNode
{
	Boolean			isUsed;				// true if ObjNode in gObjectList is used
	short			objectNum;			// index into gObjectList, or if (-1) then was malloced in an emergency situation

	uint32_t		Cookie;				// random number to identify the objnode (used for weapon targeting)

	struct ObjNode	*PrevNode;			// address of previous node in linked list
	struct ObjNode	*NextNode;			// address of next node in linked list
	struct ObjNode	*ChainNode;
	struct ObjNode	*ChainHead;			// a chain's head (link back to 1st obj in chain)

	struct ObjNode	*ShadowNode;		// ptr to node's shadow (if any)

	u_short			Slot;				// sort value
	Byte			Genre;				// obj genre
	int				Type;				// obj type
	int				Group;				// obj group
	int				Kind;				// kind
	int				Mode;				// mode
	int				What;				// what
	uint32_t		StatusBits;			// various status bits
	Byte			PlayerNum;			// player # 0..n for player objects

			/* MOVE/DRAW CALLBACKS */

	void			(*MoveCall)(struct ObjNode *);			// pointer to object's move routine
	void			(*SplineMoveCall)(struct ObjNode *);	// pointer to object's spline move routine
	void			(*CustomDrawFunction)(struct ObjNode *, const OGLSetupOutputType *setupInfo);// pointer to object's custom draw function


			/* PHYSICS */

	OGLPoint3D		Coord;				// coord of object
	OGLPoint3D		OldCoord;			// coord @ previous frame
	OGLPoint3D		InitCoord;			// coord where was created
	OGLVector3D		Delta;				// delta velocity of object
	OGLVector3D		MotionVector;		// normalized version of Delta
	OGLVector3D		DeltaRot;
	OGLVector3D		Rot;				// rotation of object
	OGLVector3D		Scale;				// scale of object
	int				GridX, GridY, GridZ;	// grid location for collision optimization

	float			Speed;

	OGLVector3D		TargetOff;
	OGLPoint3D		HeatSeekHotSpotOff;			// used by auto-targeting weapons to determine where on the object we want to hit

	OGLVector3D		HoldOffset;
	OGLVector3D		HoldRot;


			/* COLLISION INFO */

	uint32_t				CType;													// collision type bits
	uint32_t				CBits;													// collision attribute bits
	Byte				NumCollisionBoxes;
	CollisionBoxType	CollisionBoxes[MAX_COLLISION_BOXES];					// Array of collision rectangles
	float				LeftOff,RightOff,FrontOff,BackOff,TopOff,BottomOff;		// box offsets (only used by simple objects with 1 collision box)

	float				BoundingSphereRadius;
	struct ObjNode 		*CurrentTriggerObj;										// set when trigger occurs

	Boolean				(*TriggerCallback)(struct ObjNode *, struct ObjNode *);			// callback when trigger occurs
	Boolean				(*HurtCallback)(struct ObjNode *, float damage);							// used for enemies to call their hurt function
	Boolean				(*HitByWeaponHandler)(struct ObjNode *weaponObj, struct ObjNode *hitObj, OGLPoint3D *hitCoord, OGLVector3D *hitTriangleNormal);	// pointers to Weapon handler functions

	Boolean				HasWorldPoints;								// true if we have the world-space coords of the model's vertices
	MOVertexArrayData	WorldMeshes[MAX_MESHES_IN_MODEL];			// for each mesh in the model, a copy of the master mesh but with new vertex arrays that contain world-space coords; used for picking
	OGLPlaneEquation	*WorldPlaneEQs[MAX_MESHES_IN_MODEL];		// for each mesh, an array of plane equations for each triangle


			/* SPECS */

	signed char		Flag[6];
	long			Special[6];
	float			SpecialF[6];
	void*			SpecialPtr[6];
	OGLVector3D		SpecialV[3];
	float			Timer;				// misc use timer

	float			Health;				// health 0..1
	float			Damage;				// damage


			/* 3D CALCULATION STUFF */

	OGLMatrix4x4		AlignmentMatrix;		// when objects need to be aligned with a matrix rather than x,y,z rotations

	OGLMatrix4x4		BaseTransformMatrix;	// matrix which contains all of the transforms for the object as a whole
	MOMatrixObject		*BaseTransformObject;	// extra LEGAL object ref to BaseTransformMatrix (other legal ref is kept in BaseGroup)
	MOGroupObject		*BaseGroup;				// group containing all geometry,etc. for this object (for drawing)

	OGLBoundingBox		LocalBBox;				// local-space bbox for the model
	OGLBoundingBox		WorldBBox;				// world-space bbox for the model

	SkeletonObjDataType	*Skeleton;				// pointer to skeleton record data

	Byte				VertexArrayMode;		// either VERTEX_ARRAY_RANGE_TYPE_SHARED or VERTEX_ARRAY_RANGE_TYPE_CACHED


			/* TERRAIN ITEM / SPLINE INFO */

	TerrainItemEntryType *TerrainItemPtr;		// if item was from terrain, then this pts to entry in array
	SplineItemType 		*SplineItemPtr;			// if item was from spline, then this pts to entry in array
	u_char				SplineNum;				// which spline this spline item is on
	float				SplinePlacement;		// 0.0->.9999 for placement on spline
	short				SplineObjectIndex;		// index into gSplineObjectList of this ObjNode


				/* COLOR & TEXTURE INFO */

	OGLColorRGBA		ColorFilter;
	float				TextureTransformU, TextureTransformV;


			/* PARTICLE EFFECTS */

	short				EffectChannel;					// effect sound channel index (-1 = none)
	short				ParticleGroup;
	uint32_t				ParticleMagicNum;
	float				ParticleTimer;

	short				Sparkles[MAX_NODE_SPARKLES];	// indecies into sparkles list

	short				ContrailSlot[MAX_CONTRAILS_PER_OBJNODE];


			/* SPRITE INFO */

	MOSpriteObject		*SpriteMO;				// ref to sprite meta object for sprite genre.

	Byte				NumStringSprites;		// # sprites to build string (NOT SAME AS LENGTH OF STRING B/C SPACES ET.AL.)
	MOSpriteObject		*StringCharacters[31];	// sprites for each character

	float				AnaglyphZ;
};
typedef struct ObjNode ObjNode;


		/* NEW OBJECT DEFINITION TYPE */

typedef struct
{
	Byte			genre,group,type,animNum;
	OGLPoint3D		coord;
	unsigned long	flags;
	short			slot;
	void			(*moveCall)(ObjNode *);
	float			rot,scale;
}NewObjectDefinitionType;



#endif




