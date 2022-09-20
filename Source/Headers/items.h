//
// items.h
//


#define	BUMBLEBEE_JOINTNUM_HAND		23


			/* ITEMS */

extern	void InitItemsManager(void);
void CreateCyclorama(void);
void DrawCyclorama(ObjNode *theNode, const OGLSetupOutputType *setupInfo);

Boolean AddRock(TerrainItemEntryType *itemPtr, float  x, float z);
Boolean AddCrystal(TerrainItemEntryType *itemPtr, float  x, float z);
Boolean DoTrig_MiscSmackableObject(ObjNode *trigger, ObjNode *theNode);
Boolean AddRiverRock(TerrainItemEntryType *itemPtr, float  x, float z);
Boolean AddGasMound(TerrainItemEntryType *itemPtr, float  x, float z);
Boolean AddAsteroid(TerrainItemEntryType *itemPtr, float  x, float z);


		/* EGGS */

enum
{
	EGG_COLOR_RED,
	EGG_COLOR_GREEN,
	EGG_COLOR_BLUE,
	EGG_COLOR_YELLOW,
	EGG_COLOR_PURPLE,

	NUM_EGG_TYPES
};


Boolean AddEgg(TerrainItemEntryType *itemPtr, float  x, float z);
void DropEgg_NoWormhole(short playerNum);
void FindAllEggItems(void);

extern	Byte	gNumEggsToSave[NUM_EGG_TYPES];
extern	Byte	gNumEggsSaved[NUM_EGG_TYPES];



		/* WORMHOLE */

void InitWormholes(void);
Boolean AddEggWormhole(TerrainItemEntryType *itemPtr, float  x, float z);
ObjNode *FindClosestEggWormholeInRange(short playerNum, OGLPoint3D *pt);
ObjNode *MakeEntryWormhole(short playerNum);

extern	Boolean			gOpenPlayerWormhole;
extern	ObjNode			*gExitWormhole;



		/* TURRETS */

Boolean AddTowerTurret(TerrainItemEntryType *itemPtr, float  x, float z);


		/* POWERUPS */

enum
{
	POW_KIND_HEALTH,
	POW_KIND_FLIGHT,
	POW_KIND_MAP,
	POW_KIND_FREELIFE,
	POW_KIND_RAMGRAIN,
	POW_KIND_BUDDYBUG,
	POW_KIND_REDKEY,
	POW_KIND_GREENKEY,
	POW_KIND_BLUEKEY,
	POW_KIND_GREENCLOVER,
	POW_KIND_BLUECLOVER,
	POW_KIND_GOLDCLOVER,
	POW_KIND_SHIELD
};

		/* BUSHES */

Boolean AddGrass(TerrainItemEntryType *itemPtr, float  x, float z);
Boolean AddFern(TerrainItemEntryType *itemPtr, float  x, float z);
Boolean AddBerryBush(TerrainItemEntryType *itemPtr, float  x, float z);
Boolean AddCatTail(TerrainItemEntryType *itemPtr, float  x, float z);

Boolean AddDesertBush(TerrainItemEntryType *itemPtr, float  x, float z);
Boolean AddCactus(TerrainItemEntryType *itemPtr, float  x, float z);
Boolean AddPalmBush(TerrainItemEntryType *itemPtr, float  x, float z);

Boolean AddGeckoPlant(TerrainItemEntryType *itemPtr, float  x, float z);
Boolean AddSproutPlant(TerrainItemEntryType *itemPtr, float  x, float z);

Boolean AddIvy(TerrainItemEntryType *itemPtr, float  x, float z);


		/* TREES */

Boolean AddBirchTree(TerrainItemEntryType *itemPtr, float  x, float z);
Boolean AddPineTree(TerrainItemEntryType *itemPtr, float  x, float z);
Boolean AddSmallTree(TerrainItemEntryType *itemPtr, float  x, float z);
Boolean AddFallenTree(TerrainItemEntryType *itemPtr, float  x, float z);
Boolean AddTreeStump(TerrainItemEntryType *itemPtr, float  x, float z);
Boolean AddBentPineTree(TerrainItemEntryType *itemPtr, float  x, float z);

Boolean AddDesertTree(TerrainItemEntryType *itemPtr, float  x, float z);
Boolean AddPalmTree(TerrainItemEntryType *itemPtr, float  x, float z);
Boolean AddBurntDesertTree(TerrainItemEntryType *itemPtr, float  x, float z);

Boolean AddHydraTree(TerrainItemEntryType *itemPtr, float  x, float z);
Boolean AddOddTree(TerrainItemEntryType *itemPtr, float  x, float z);
Boolean AddSwampFallenTree(TerrainItemEntryType *itemPtr, float  x, float z);
Boolean AddSwampStump(TerrainItemEntryType *itemPtr, float  x, float z);


		/* MINES */

Boolean AddAirMine(TerrainItemEntryType *itemPtr, float  x, float z);



	/* FOREST DOOR */

void InitForestDoors(void);
Boolean AddForestDoor(TerrainItemEntryType *itemPtr, float  x, float z);
Boolean AddForestDoorKey(TerrainItemEntryType *itemPtr, float  x, float z);


	/* ELECTRODES */

Boolean AddElectrode(TerrainItemEntryType *itemPtr, float  x, float z);
void InitZaps(void);


		/* POWS */

Boolean AddWeaponPOW(TerrainItemEntryType *itemPtr, float  x, float z);
Boolean AddFuelPOW(TerrainItemEntryType *itemPtr, float  x, float z);
Boolean AddHealthPOW(TerrainItemEntryType *itemPtr, float  x, float z);
Boolean AddShieldPOW(TerrainItemEntryType *itemPtr, float  x, float z);
Boolean AddFreeLifePOW(TerrainItemEntryType *itemPtr, float  x, float z);


		/* DUST DEVIL */

void InitDustDevilMemory(void);
void UpdateDustDevilUVAnimation(void);
Boolean AddDustDevil(TerrainItemEntryType *itemPtr, float  x, float z);
Boolean PrimeDustDevil(long splineNum, SplineItemType *itemPtr);


		/* LASER ORBS */

Boolean AddLaserOrb(TerrainItemEntryType *itemPtr, float  x, float z);
Boolean PrimeLaserOrb(long splineNum, SplineItemType *itemPtr);

		/* HOLES */

Boolean AddHole(TerrainItemEntryType *itemPtr, float  x, float z);






