//
// player.h
//

#pragma once

#define	MAX_PLAYERS		2

#define	PLAYER_DEFAULT_SCALE	1.0f



#define	PLAYER_COLLISION_CTYPE	(CTYPE_TRIGGER|CTYPE_HURTME|CTYPE_PLAYERONLY)

#define	PLAYER_NORMAL_MAX_SPEED		900.0f
#define	PLAYER_JETPACK_MAX_SPEED	2000.0f

#define	MAX_ALTITUDE_DIFF			1400.0f				// this is as high as we can fly above terrain before we hit the ceiling
#define	MAX_ALTITUDE				2080.0f				// this is the max altitude no matter what the terrain is

#define	MAX_SHIELD_POWER		3.0f


enum
{
	PLAYER_DEATH_TYPE_EXPLODE,
	PLAYER_DEATH_TYPE_DEATHDIVE
};


		/* ANIMS */

enum
{
	PLAYER_ANIM_FLAP,
	PLAYER_ANIM_BANKLEFT,
	PLAYER_ANIM_BANKRIGHT,
	PLAYER_ANIM_DEATHDIVE,
	PLAYER_ANIM_APPEARWORMHOLE,
	PLAYER_ANIM_READY2GRAB,
	PLAYER_ANIM_FLAPWITHEGG,
	PLAYER_ANIM_BANKLEFTEGG,
	PLAYER_ANIM_BANKRIGHTEGG,
	PLAYER_ANIM_ENTERWORMHOLE,
	PLAYER_ANIM_DISORIENTED,
	PLAYER_ANIM_DUSTDEVIL,
	PLAYER_ANIM_COASTING
};


		/* JOINTS */

enum
{
	PLAYER_JOINT_LEFT_ARMPIT	=	1,
	PLAYER_JOINT_RIGHT_ARMPIT	=	2,
	PLAYER_JOINT_LEFT_FOOT		=	8,
	PLAYER_JOINT_RIGHT_FOOT		=	11,
	PLAYER_JOINT_RIGHT_WING3	=	13,
	PLAYER_JOINT_RIGHT_WINGTIP	=	16,
	PLAYER_JOINT_LEFT_WING3		=	18,
	PLAYER_JOINT_LEFT_WINGTIP	=	21,
	PLAYER_JOINT_HEAD			=	23,
	PLAYER_JOINT_JAW			=	24,
	PLAYER_JOINT_EGGHOLD		=	27

};


		/* WEAPON TYPES */

#define	WEAPON_TYPE_NONE	-1

enum
{
	WEAPON_TYPE_BLASTER 		= 0,
	WEAPON_TYPE_CLUSTERSHOT,
	WEAPON_TYPE_HEATSEEKER,
	WEAPON_TYPE_SONICSCREAM,
	WEAPON_TYPE_BOMB,

	NUM_WEAPON_TYPES
};

#define	NUM_CROSSHAIR_LEVELS	2


		/***************/
		/* PLAYER INFO */
		/***************/

typedef struct
{
	int					startX,startZ;
	float				startRotY;

	OGLPoint3D			coord;
	ObjNode				*objNode;

	float				distToFloor;
	float				mostRecentFloorY;

	float				knockDownTimer;
	float				invincibilityTimer;


	OGLRect				itemDeleteWindow;

	OGLCameraPlacement	camera;

	float				burnTimer;
	float				blinkTimer;

	ObjNode				*wormhole;

		/* TILE ATTRIBUTE PHYSICS TWEAKS */

//	int					waterPatch;
	float				waterRippleTimer;

	OGLPoint3D			previousWingContrailPt[2];


			/* CONTROL INFO */

	float				analogControlX,analogControlZ;


			/* INVENTORY INFO */

	short				numFreeLives;
	float				health;

	float				jetpackFuel;
	Boolean				jetpackActive;

	short				currentWeapon;
	short				weaponQuantity[NUM_WEAPON_TYPES];
	float				weaponCharge;							// for weapons which require a charge (hold down fire button)
	short				weaponChargeChannel;					// for charging sfx
	Byte				turretSide;								// 0 or 1 depending on which turret to shoot from next

	ObjNode				*carriedObj;


			/* SHIELD */

	float				shieldPower;
	ObjNode				*shieldObj;



			/* CROSSHAIR AUTO-TARGET */

	OGLPoint3D			crosshairCoord[NUM_CROSSHAIR_LEVELS];
	ObjNode				*crosshairTargetObj;
	uint32_t				crosshairTargetCookie;


			/* RACE INFO */

	Boolean				wrongWay, movingBackwards;
	short				lapNum;
	short				raceCheckpointNum;
	Boolean				raceCheckpointTagged[MAX_LINEMARKERS];
	short				place;
	float				distToNextCheckpoint;
	Boolean				raceComplete;


			/* MISC EFFECT INFO */

	float				dirtParticleTimer;						// particle info for dirt scrap when player brushes ground
	short				dirtParticleGroup;
	uint32_t				dirtParticleMagicNum;


			/* DUST DEVIL */

	ObjNode				*dustDevilObj;							// objNode of dust devil we're stuck in
	float				dustDevilRot;							// rot y around dust devil
	float				dustDevilRotSpeed;						// speed of rot around dust devil
	float				radiusFromDustDevil;					// dist from center axis
	Boolean				ejectedFromDustDevil;					// true when being ejected

}PlayerInfoType;





//=======================================================

void InitPlayerInfo_Game(void);
void InitPlayerAtStartOfLevel(void);
Boolean DoTrig_Player(ObjNode *trigger, ObjNode *theNode);

Boolean PlayerLoseHealth(short playerNum, float damage, Byte deathType, OGLPoint3D *where, Boolean disorient);
void KillPlayer(short playerNum, Byte deathType, OGLPoint3D *where);
void ExplodePlayer(ObjNode *player, short playerNum, OGLPoint3D *where);
void DisorientPlayer(ObjNode *player);

void ResetPlayerAtBestCheckpoint(short playerNum);
void UpdateCarriedObject(ObjNode *player, ObjNode *held);
float CalcDistanceToClosestPlayer(OGLPoint3D *pt, short *playerNum);

void HidePlayer(ObjNode *player);
void ShowPlayer(ObjNode *player);
Boolean	FadePlayer(ObjNode *player, float rate);

void SetPlayerFlyingAnim(ObjNode *player);
float CalcPlayerMaxAltitude(float x, float z);


void CreatePlayerObject(short playerNum, OGLPoint3D *where, float rotY);
void HandlePlayerLineMarkerCrossing(ObjNode *player);

Boolean PlayerSmackedIntoObject(ObjNode *player, ObjNode *hitObj, short deathType);
Boolean PlayerHitByWeaponCallback(ObjNode *weapon, ObjNode *player, OGLPoint3D *hitCoord, OGLVector3D *hitNormal);

void MovePlayerJetpack(ObjNode *jetpack);
void JetpackOff(short playerNum);

void SetReincarnationCheckpointAtMarker(ObjNode *player, short markerNum);

void CreatePlayerShield(short playerNum);
void UpdatePlayerShield(short playerNum);
void HitPlayerShield(short playerNum, float damage, float shieldGlowDuration, Boolean disorientPlayer);


			/* WEAPONS */

void UpdatePlayerCrosshairs(ObjNode *player);
void PlayerFireButtonPressed(ObjNode *player, Boolean newFireButton);
void PlayerFireButtonReleased(ObjNode *player);
void SelectNextWeapon(short playerNum, Boolean allowSonicScream);
Boolean AddWeaponPOW(TerrainItemEntryType *itemPtr, float  x, float z);
void CauseBombShockwaveDamage(ObjNode *wave, uint32_t ctype);

			/* RACE */

void UpdatePlayerRaceMarkers(ObjNode *player);
void CalcPlayerPlaces(void);

