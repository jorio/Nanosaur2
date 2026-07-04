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


// PlayerDeathType is now a plain Swift enum in GameEnums.swift - nothing in C touches it, so it's no longer declared here.


		/* ANIMS */

// PlayerAnim is now a plain Swift enum in GameEnums.swift - nothing in C touches it, so it's no longer declared here.


		/* JOINTS */

// PlayerJoint is now a plain Swift enum in GameEnums.swift - nothing in C touches it, so it's no longer declared here.


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













			/* WEAPONS */


			/* RACE */


