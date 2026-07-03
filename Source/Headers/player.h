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


typedef enum SWIFT_ENUM_CLOSED PlayerDeathType
{
	PLAYER_DEATH_TYPE_EXPLODE SWIFT_NAME(explode),
	PLAYER_DEATH_TYPE_DEATHDIVE SWIFT_NAME(deathDive)
} PlayerDeathType;


		/* ANIMS */

typedef enum SWIFT_ENUM_CLOSED PlayerAnim
{
	PLAYER_ANIM_FLAP SWIFT_NAME(flap),
	PLAYER_ANIM_BANKLEFT SWIFT_NAME(bankLeft),
	PLAYER_ANIM_BANKRIGHT SWIFT_NAME(bankRight),
	PLAYER_ANIM_DEATHDIVE SWIFT_NAME(deathDive),
	PLAYER_ANIM_APPEARWORMHOLE SWIFT_NAME(appearWormhole),
	PLAYER_ANIM_READY2GRAB SWIFT_NAME(readyToGrab),
	PLAYER_ANIM_FLAPWITHEGG SWIFT_NAME(flapWithEgg),
	PLAYER_ANIM_BANKLEFTEGG SWIFT_NAME(bankLeftEgg),
	PLAYER_ANIM_BANKRIGHTEGG SWIFT_NAME(bankRightEgg),
	PLAYER_ANIM_ENTERWORMHOLE SWIFT_NAME(enterWormhole),
	PLAYER_ANIM_DISORIENTED SWIFT_NAME(disoriented),
	PLAYER_ANIM_DUSTDEVIL SWIFT_NAME(dustDevil),
	PLAYER_ANIM_COASTING SWIFT_NAME(coasting)
} PlayerAnim;


		/* JOINTS */

typedef enum SWIFT_ENUM_CLOSED PlayerJoint
{
	PLAYER_JOINT_LEFT_ARMPIT SWIFT_NAME(leftArmpit) = 1,
	PLAYER_JOINT_RIGHT_ARMPIT SWIFT_NAME(rightArmpit) = 2,
	PLAYER_JOINT_LEFT_FOOT SWIFT_NAME(leftFoot) = 8,
	PLAYER_JOINT_RIGHT_FOOT SWIFT_NAME(rightFoot) = 11,
	PLAYER_JOINT_RIGHT_WING3 SWIFT_NAME(rightWing3) = 13,
	PLAYER_JOINT_RIGHT_WINGTIP SWIFT_NAME(rightWingtip) = 16,
	PLAYER_JOINT_LEFT_WING3 SWIFT_NAME(leftWing3) = 18,
	PLAYER_JOINT_LEFT_WINGTIP SWIFT_NAME(leftWingtip) = 21,
	PLAYER_JOINT_HEAD SWIFT_NAME(head) = 23,
	PLAYER_JOINT_JAW SWIFT_NAME(jaw) = 24,
	PLAYER_JOINT_EGGHOLD SWIFT_NAME(eggHold) = 27

} PlayerJoint;


		/* WEAPON TYPES */

typedef enum SWIFT_ENUM_CLOSED WeaponType
{
	WEAPON_TYPE_NONE SWIFT_NAME(none) = -1,

	WEAPON_TYPE_BLASTER SWIFT_NAME(blaster) = 0,
	WEAPON_TYPE_CLUSTERSHOT SWIFT_NAME(clusterShot),
	WEAPON_TYPE_HEATSEEKER SWIFT_NAME(heatSeeker),
	WEAPON_TYPE_SONICSCREAM SWIFT_NAME(sonicScream),
	WEAPON_TYPE_BOMB SWIFT_NAME(bomb),

	NUM_WEAPON_TYPES SWIFT_NAME(_count)
} WeaponType;

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
	float				jetpackRumbleCooldown;

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
	uint32_t			dirtParticleMagicNum;
	float				groundScrapeRumbleCooldown;				// force feedback for when player brushed ground


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
Boolean DoTrig_Player(ObjNode * _Nonnull trigger, ObjNode * _Nonnull theNode);

Boolean PlayerLoseHealth(short playerNum, float damage, Byte deathType, OGLPoint3D * _Nullable where, Boolean disorient);
void KillPlayer(short playerNum, Byte deathType, OGLPoint3D * _Nullable where);
void ExplodePlayer(ObjNode * _Nonnull player, short playerNum, OGLPoint3D * _Nullable where);
void DisorientPlayer(ObjNode * _Nonnull player);

void ResetPlayerAtBestCheckpoint(short playerNum);
void UpdateCarriedObject(ObjNode * _Nonnull player, ObjNode * _Nonnull held);
float CalcDistanceToClosestPlayer(OGLPoint3D * _Nonnull pt, short * _Nullable playerNum);

void HidePlayer(ObjNode * _Nonnull player);
void ShowPlayer(ObjNode * _Nonnull player);
Boolean	FadePlayer(ObjNode * _Nonnull player, float rate);

void SetPlayerFlyingAnim(ObjNode * _Nonnull player);
float CalcPlayerMaxAltitude(float x, float z);


void CreatePlayerObject(short playerNum, OGLPoint3D *where, float rotY);
void HandlePlayerLineMarkerCrossing(ObjNode *player);

Boolean PlayerSmackedIntoObject(ObjNode *player, ObjNode *hitObj, short deathType);
Boolean PlayerHitByWeaponCallback(ObjNode * _Nonnull weapon, ObjNode * _Nonnull player, OGLPoint3D * _Nullable hitCoord, OGLVector3D * _Nullable hitNormal);

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
void SelectNextWeapon(short playerNum, Boolean allowSonicScream, int delta);
Boolean AddWeaponPOW(TerrainItemEntryType *itemPtr, float  x, float z);
void CauseBombShockwaveDamage(ObjNode *wave, uint32_t ctype);

			/* RACE */

void UpdatePlayerRaceMarkers(ObjNode * _Nonnull player);
void CalcPlayerPlaces(void);

void UpdatePlayerSteering(int playerNum);
