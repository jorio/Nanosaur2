/****************************/
/*     SOUND ROUTINES       */
/* By Brian Greenstone      */
/* (c)2003 Pangea Software  */
/* (c)2022 Iliyas Jorio     */
/****************************/


/***************/
/* EXTERNALS   */
/***************/

#include "game.h"


/****************************/
/*    PROTOTYPES            */
/****************************/

static short FindSilentChannel(void);
static void Calc3DEffectVolume(short effectNum, OGLPoint3D *where, float volAdjust, uint32_t *leftVolOut, uint32_t *rightVolOut);


/****************************/
/*    CONSTANTS             */
/****************************/


#define		MAX_CHANNELS			40

#define		MAX_EFFECTS				70

#define		MAX_AUDIO_STREAMS		9

#define		FULL_SONG_VOLUME		1.0f
#define		FULL_EFFECTS_VOLUME		1.0f


typedef struct
{
	uint8_t			bank;
	const char*		name;
	float			refVol;
}EffectType;

typedef struct
{
	float			lowFrequencyStrength;
	float			highFrequencyStrength;
	uint16_t		duration;
} AutoRumbleDef;


#define	VOLUME_MIN_DIST		700.0f			// distance at which volume is 1.0 (maxxed).  Larger is louder


/**********************/
/*     VARIABLES      */
/**********************/

static float				gGlobalVolumeFade = 1.0f;						// multiplier applied to sfx/song volumes (changes during fade out)
static float				gEffectsVolume = FULL_EFFECTS_VOLUME;
static float				gMusicVolume = FULL_SONG_VOLUME;
static float				gMusicVolumeTweak = 1.0f;

static OGLPoint3D			gEarCoords[MAX_PLAYERS];						// coord of camera plus a tad to get pt in front of camera
static	OGLVector3D			gEyeVector[MAX_PLAYERS];


static	SndListHandle		gSndHandles[MAX_EFFECTS];		// handles to ALL sounds
static  long				gSndOffsets[MAX_EFFECTS];

static	SndChannelPtr		gSndChannel[MAX_CHANNELS];
ChannelInfoType				gChannelInfo[MAX_CHANNELS];
static	SndChannelPtr		gMusicChannel;

static short				gMaxChannels = 0;

static short				gMostRecentChannel = -1;

Boolean						gSongPlayingFlag = false;

short				gCurrentSong = -1;


		/*****************/
		/* EFFECTS TABLE */
		/*****************/

static const char* gSoundBankNames[NUM_SOUND_BANKS] =
{
	[SOUND_BANK_NULL] = NULL,
	[SOUND_BANK_MAIN] = "Main",
	[SOUND_BANK_NARRATION] = "Narration",
};

static const EffectType gEffectsTable[NUM_EFFECTS] =
{
	[EFFECT_NULL           ] = {SOUND_BANK_NULL, NULL,				1},
	[EFFECT_CHANGESELECT   ] = {SOUND_BANK_MAIN, "ChangeSelect",	1},
	[EFFECT_GETPOW         ] = {SOUND_BANK_MAIN, "GetPOW",			1},
	[EFFECT_SPLASH         ] = {SOUND_BANK_MAIN, "Splash",			1},
	[EFFECT_TURRETEXPLOSION] = {SOUND_BANK_MAIN, "TurretExplosion",	2},
	[EFFECT_IMPACTSIZZLE   ] = {SOUND_BANK_MAIN, "ImpactSizzle",	1},
	[EFFECT_SHIELD         ] = {SOUND_BANK_MAIN, "Shield",			1},
	[EFFECT_MINEEXPLODE    ] = {SOUND_BANK_MAIN, "MineExplode",		3},
	[EFFECT_PLANECRASH     ] = {SOUND_BANK_MAIN, "PlaneCrash",		1},
	[EFFECT_TURRETFIRE     ] = {SOUND_BANK_MAIN, "TurretFire",		.6f},
	[EFFECT_STUNGUN        ] = {SOUND_BANK_MAIN, "StunGun",			.7f},
	[EFFECT_ROCKETLAUNCH   ] = {SOUND_BANK_MAIN, "RocketLaunch",	1},		// unused?
	[EFFECT_WEAPONCHARGE   ] = {SOUND_BANK_MAIN, "WeaponCharge",	1},
	[EFFECT_FLARESHOOT     ] = {SOUND_BANK_MAIN, "FlareShoot",		1},
	[EFFECT_CHANGEWEAPON   ] = {SOUND_BANK_MAIN, "ChangeWeapon",	1},
	[EFFECT_SONICSCREAM    ] = {SOUND_BANK_MAIN, "SonicScream",		1},
	[EFFECT_ELECTRODEHUM   ] = {SOUND_BANK_MAIN, "ElectrodeHum",	.5f},
	[EFFECT_WORMHOLE       ] = {SOUND_BANK_MAIN, "Wormhole",		1},
	[EFFECT_WORMHOLEVANISH ] = {SOUND_BANK_MAIN, "WormholeVanish",	1.6f},
	[EFFECT_WORMHOLEAPPEAR ] = {SOUND_BANK_MAIN, "WormholeAppear",	1.6f},
	[EFFECT_EGGINTOWORMHOLE] = {SOUND_BANK_MAIN, "EggIntoWormhole",	1},
	[EFFECT_BODYHIT        ] = {SOUND_BANK_MAIN, "BodyHit",			1},
	[EFFECT_LAUNCHMISSILE  ] = {SOUND_BANK_MAIN, "LaunchMissile",	.7f},
	[EFFECT_GRABEGG        ] = {SOUND_BANK_MAIN, "GrabEgg",			.7f},
	[EFFECT_JETPACKHUM     ] = {SOUND_BANK_MAIN, "JetpackHum",		.8f},
	[EFFECT_JETPACKIGNITE  ] = {SOUND_BANK_MAIN, "JetpackIgnite",	.6f},
	[EFFECT_MENUSELECT     ] = {SOUND_BANK_MAIN, "MenuSelect",		.6f * (1.0f/4.0f)},
	[EFFECT_MISSILEENGINE  ] = {SOUND_BANK_MAIN, "MissileEngine",	.6f},
	[EFFECT_BOMBDROP       ] = {SOUND_BANK_MAIN, "BombDrop",		1},
	[EFFECT_DUSTDEVIL      ] = {SOUND_BANK_MAIN, "DustDevil",		1},
	[EFFECT_LASERBEAM      ] = {SOUND_BANK_MAIN, "LaserBeam",		0.7f},
	[EFFECT_CRYSTALSHATTER ] = {SOUND_BANK_MAIN, "CrystalShatter",	1.5f},
	[EFFECT_RAPTORDEATH    ] = {SOUND_BANK_MAIN, "RaptorDeath",		.8f},
	[EFFECT_RAPTORATTACK   ] = {SOUND_BANK_MAIN, "RaptorAttack",	1},
	[EFFECT_BRACHHURT      ] = {SOUND_BANK_MAIN, "BrachHurt",		1.2f},
	[EFFECT_BRACHDEATH     ] = {SOUND_BANK_MAIN, "BrachDeath",		1},
	[EFFECT_DIRT           ] = {SOUND_BANK_MAIN, "Dirt",			1},
	[EFFECT_BADSELECT      ] = {SOUND_BANK_MAIN, "BadSelect",		1},
	[EFFECT_STORY1         ] = {SOUND_BANK_NARRATION, "story1",		1},
	[EFFECT_STORY2         ] = {SOUND_BANK_NARRATION, "story2",		1},
	[EFFECT_STORY3         ] = {SOUND_BANK_NARRATION, "story3",		1},
	[EFFECT_STORY4         ] = {SOUND_BANK_NARRATION, "story4",		1},
	[EFFECT_STORY5         ] = {SOUND_BANK_NARRATION, "story5",		1},
	[EFFECT_STORY6         ] = {SOUND_BANK_NARRATION, "story6",		1},
	[EFFECT_STORY7         ] = {SOUND_BANK_NARRATION, "story7",		1},
};

static const AutoRumbleDef gAutoRumbleTable[NUM_EFFECTS] =
{
	[EFFECT_NULL           ] = {0},
	[EFFECT_CHANGESELECT   ] = {0},
	[EFFECT_GETPOW         ] = {0.0f, 0.7f, 150},
	[EFFECT_SPLASH         ] = {0},
	[EFFECT_TURRETEXPLOSION] = {0},
	[EFFECT_IMPACTSIZZLE   ] = {0},
	[EFFECT_SHIELD         ] = {1.0f, 1.0f, 300},
	[EFFECT_MINEEXPLODE    ] = {0},
	[EFFECT_PLANECRASH     ] = {1.0f, 1.0f, 1000},
	[EFFECT_TURRETFIRE     ] = {0},
	[EFFECT_STUNGUN        ] = {0.0f, 0.9f, 50},
	[EFFECT_ROCKETLAUNCH   ] = {0.0f, 1.0f, 180},		// unused I think
	[EFFECT_WEAPONCHARGE   ] = {0},
	[EFFECT_FLARESHOOT     ] = {0.0f, 1.0f, 180},
	[EFFECT_CHANGEWEAPON   ] = {0},
	[EFFECT_SONICSCREAM    ] = {0},
	[EFFECT_ELECTRODEHUM   ] = {0},
	[EFFECT_WORMHOLE       ] = {0},
	[EFFECT_WORMHOLEVANISH ] = {0.5f, 0.0f, 750},
	[EFFECT_WORMHOLEAPPEAR ] = {0},
	[EFFECT_EGGINTOWORMHOLE] = {0.5f, 0.0f, 750},
	[EFFECT_BODYHIT        ] = {1.0f, 1.0f, 300},
	[EFFECT_LAUNCHMISSILE  ] = {0.0f, 1.0f, 180},
	[EFFECT_GRABEGG        ] = {0.0f, 0.9f, 100},
	[EFFECT_JETPACKHUM     ] = {0.5f, 0.0f, 100},
	[EFFECT_JETPACKIGNITE  ] = {0},
	[EFFECT_MENUSELECT     ] = {0},
	[EFFECT_MISSILEENGINE  ] = {0},
	[EFFECT_BOMBDROP       ] = {0.0f, 1.0f, 180},
	[EFFECT_DUSTDEVIL      ] = {0},
	[EFFECT_LASERBEAM      ] = {0},
	[EFFECT_CRYSTALSHATTER ] = {0},
	[EFFECT_RAPTORDEATH    ] = {0},
	[EFFECT_RAPTORATTACK   ] = {0},
	[EFFECT_BRACHHURT      ] = {0},
	[EFFECT_BRACHDEATH     ] = {0},
	[EFFECT_DIRT           ] = {0},
	[EFFECT_BADSELECT      ] = {0},
};

/********************* INIT SOUND TOOLS ********************/

void InitSoundTools(void)
{
OSErr			iErr;


	gMaxChannels = 0;
	gMostRecentChannel = -1;


			/******************/
			/* ALLOC CHANNELS */
			/******************/

	for (gMaxChannels = 0; gMaxChannels < MAX_CHANNELS; gMaxChannels++)
	{
			/* NEW SOUND CHANNEL */

		iErr = SndNewChannel(&gSndChannel[gMaxChannels], sampledSynth, initStereo, nil);
		if (iErr)												// if err, stop allocating channels
			break;
	}

		/* SONG CHANNEL */

	iErr = SndNewChannel(&gMusicChannel, sampledSynth, initStereo, nil);
	GAME_ASSERT(!iErr);



		/* SET INITIAL VOLUME IN ALL CHANNELS FROM PREFS */

	UpdateGlobalVolume();


		/***********************/
		/* LOAD DEFAULT SOUNDS */
		/***********************/

	LoadSoundBank(SOUND_BANK_MAIN);
}


/******************** SHUTDOWN SOUND ***************************/
//
// Called at Quit time
//

void ShutdownSound(void)
{
			/* STOP ANY PLAYING AUDIO */

	StopAllEffectChannels();
	KillSong();


		/* DISPOSE OF CHANNELS */

	for (int i = 0; i < gMaxChannels; i++)
		SndDisposeChannel(gSndChannel[i], true);
	gMaxChannels = 0;


		/* DISPOSE OF ALL SOUND BANKS */

	for (int i = 0; i < NUM_SOUND_BANKS; i++)
	{
		DisposeSoundBank(i);
	}
}

#pragma mark -

/******************* LOAD SOUND BANK ************************/

void LoadSoundBank(uint8_t bank)
{
	static const char* kSoundExts[] = {"aiff", "mp3", NULL};
	OSErr iErr;

	StopAllEffectChannels();

			/* DISPOSE OF EXISTING BANK */

	DisposeSoundBank(bank);

			/****************************/
			/* LOAD ALL EFFECTS IN BANK */
			/****************************/

	for (int i = 0; i < NUM_EFFECTS; i++)
	{
		const EffectType* effectDef = &gEffectsTable[i];

				/* FILTER EFFECTS BY BANK */

		if (effectDef->bank != bank)
			continue;

				/* FIND FSSPEC TO EFFECT FILE */

		FSSpec spec;
		short refNum = -1;
		iErr = noErr;

		for (size_t extNum = 0; kSoundExts[extNum]; extNum++)
		{
			char path[64];

			SDL_snprintf(path, sizeof(path), ":Audio:%s:%s.%s",
				gSoundBankNames[effectDef->bank],
				effectDef->name,
				kSoundExts[extNum]);

			iErr = FSMakeFSSpec(gDataSpec.vRefNum, gDataSpec.parID, path, &spec);
			if (iErr == noErr)	// if the file exists, stop; otherwise try next extension
			{
				break;
			}
		}

		// after trying all extensions, stop here if still don't have a valid FSSpec
		GAME_ASSERT(!iErr);

				/* OPEN DATA FORK */

		iErr = FSpOpenDF(&spec, fsRdPerm, &refNum);
		GAME_ASSERT(!iErr);

				/* LOAD SND REZ */

		gSndHandles[i] = Pomme_SndLoadFileAsResource(refNum);
		GAME_ASSERT(gSndHandles[i]);

				/* GET OFFSET INTO IT */

		GetSoundHeaderOffset(gSndHandles[i], &gSndOffsets[i]);

				/* PRE-DECOMPRESS IT */

		Pomme_DecompressSoundResource(&gSndHandles[i], &gSndOffsets[i]);

				/* CLOSE DATA FORK */

		FSClose(refNum);
	}
}


/******************** DISPOSE SOUND BANK **************************/

void DisposeSoundBank(uint8_t bank)
{
	StopAllEffectChannels();									// make sure all sounds are stopped before nuking any banks

			/* FREE ALL SAMPLES */

	for (int i = 0; i < NUM_EFFECTS; i++)
	{
		if (gEffectsTable[i].bank == bank)
		{
			if (gSndHandles[i])
			{
				DisposeHandle((Handle) gSndHandles[i]);
			}

			gSndHandles[i] = nil;
			gSndOffsets[i] = 0;
		}
	}
}



/********************* STOP A CHANNEL **********************/
//
// Stops the indicated sound channel from playing.
//

void StopAChannel(short *channelNum)
{
SndCommand 	mySndCmd;
short		c = *channelNum;

	if ((c < 0) || (c >= gMaxChannels))		// make sure its a legal #
		return;

	mySndCmd.cmd = flushCmd;
	mySndCmd.param1 = 0;
	mySndCmd.param2 = 0;
	SndDoImmediate(gSndChannel[c], &mySndCmd);

	mySndCmd.cmd = quietCmd;
	mySndCmd.param1 = 0;
	mySndCmd.param2 = 0;
	SndDoImmediate(gSndChannel[c], &mySndCmd);

	*channelNum = -1;

	gChannelInfo[c].effectNum = -1;
}


/********************* STOP A CHANNEL IF EFFECT NUM **********************/
//
// Stops the indicated sound channel from playing if it is still this effect #
//

Boolean StopAChannelIfEffectNum(short *channelNum, short effectNum)
{
short		c = *channelNum;

	if (c < 0)
		return false;

	if (gChannelInfo[c].effectNum != effectNum)		// make sure its the right effect
		return(false);

	StopAChannel(channelNum);

	return(true);
}



/********************* STOP ALL EFFECT CHANNELS **********************/

void StopAllEffectChannels(void)
{
short		i;

	for (i=0; i < gMaxChannels; i++)
	{
		short	c;

		c = i;
		StopAChannel(&c);
	}
}


#pragma mark -


/******************** PLAY SONG ***********************/
//
// if songNum == -1, then play existing open song
//
// INPUT: loopFlag = true if want song to loop
//

void PlaySong(short songNum, Boolean loopFlag)
{
OSErr 	iErr;
static	SndCommand 		mySndCmd;
FSSpec	spec;
short	musicFileRefNum;

	if (songNum == gCurrentSong)					// see if this is already playing
		return;


		/* ZAP ANY EXISTING SONG */

	gCurrentSong 	= songNum;
	KillSong();

			/******************************/
			/* OPEN APPROPRIATE SONG FILE */
			/******************************/


	static const struct
	{
		const char* path;
		float volumeTweak;
	} songs[MAX_SONGS] =
	{
		[SONG_THEME]		= {":Audio:theme.mp3",			1.0f},
		[SONG_INTRO]		= {":Audio:introsong.mp3",		1.0f},
		[SONG_LEVEL1]		= {":Audio:level1song.mp3",		1.1f},
		[SONG_LEVEL2]		= {":Audio:level2song.mp3",		1.0f},
		[SONG_LEVEL3]		= {":Audio:level3song.mp3",		1.0f},
		[SONG_WIN]			= {":Audio:winsong.mp3",		1.0f},
	};

	iErr = FSMakeFSSpec(gDataSpec.vRefNum, gDataSpec.parID, songs[songNum].path, &spec);
	GAME_ASSERT(!iErr);

	iErr = FSpOpenDF(&spec, fsRdPerm, &musicFileRefNum);
	GAME_ASSERT(!iErr);

	gCurrentSong = songNum;
	gMusicVolumeTweak = songs[songNum].volumeTweak;


				/*****************/
				/* START PLAYING */
				/*****************/

			/* START PLAYING FROM FILE */

	iErr = SndStartFilePlay(
		gMusicChannel,
		musicFileRefNum,
		0,
		0, //STREAM_BUFFER_SIZE
		0, //gMusicBuffer
		nil,
		nil, //SongCompletionProc
		true);

	FSClose(musicFileRefNum);		// close the file (Pomme decompresses entire song into memory)

	if (iErr)
	{
		DoFatalAlert("PlaySong: SndStartFilePlay failed! (System error %d)", iErr);
	}

	gSongPlayingFlag = true;


			/* SET LOOP FLAG ON STREAM (SOURCE PORT ADDITION) */
			/* So we don't need to re-read the file over and over. */

	mySndCmd.cmd = pommeSetLoopCmd;
	mySndCmd.param1 = loopFlag ? 1 : 0;
	mySndCmd.param2 = 0;
	iErr = SndDoImmediate(gMusicChannel, &mySndCmd);
	if (iErr)
		DoFatalAlert("PlaySong: SndDoImmediate (pomme loop extension) failed!");

	uint32_t lv2 = kFullVolume * gMusicVolumeTweak * gMusicVolume;
	uint32_t rv2 = kFullVolume * gMusicVolumeTweak * gMusicVolume;
	mySndCmd.cmd = volumeCmd;
	mySndCmd.param1 = 0;
	mySndCmd.param2 = (rv2<<16) | lv2;
	iErr = SndDoImmediate(gMusicChannel, &mySndCmd);
	if (iErr)
		DoFatalAlert("PlaySong: SndDoImmediate (volumeCmd) failed!");


#if 0
			/* SEE IF WANT TO MUTE THE MUSIC */

	if (gMuteMusicFlag)
	{
		if (gSongMovie)
			StopMovie(gSongMovie);
	}
#endif
}


/*********************** KILL SONG *********************/

void KillSong(void)
{
	gCurrentSong = -1;

	if (!gSongPlayingFlag)
		return;

	gSongPlayingFlag = false;											// tell callback to do nothing

	SndStopFilePlay(gMusicChannel, true);								// stop it
}

#if 0
/******************** TOGGLE MUSIC *********************/

void ToggleMusic(void)
{

	gMuteMusicFlag = !gMuteMusicFlag;

	if (gSongMovie)
	{
		gInQuicktimeFunction = true;				// dont allow song task to start anything new
		while(gInMoviesTask);			// DONT DO ANYTHING WHILE IN THE SONG TASK!!

		if (gMuteMusicFlag)
			StopMovie(gSongMovie);
		else
			StartMovie(gSongMovie);

		gInQuicktimeFunction = false;
	}
}
#endif





#pragma mark -

/***************************** PLAY EFFECT 3D ***************************/
//
// NO SSP
//
// OUTPUT: channel # used to play sound
//

short PlayEffect3D(short effectNum, OGLPoint3D *where)
{
short					theChan;
uint32_t					leftVol, rightVol;

	if (effectNum >= MAX_EFFECTS)			// see if illegal sound #
	{
		DoFatalAlert("Illegal sound number %d!", effectNum);
	}

				/* CALC VOLUME */

	Calc3DEffectVolume(effectNum, where, 1.0, &leftVol, &rightVol);
	if ((leftVol+rightVol) == 0)
		return(-1);


	theChan = PlayEffect_Parms(effectNum, leftVol, rightVol, NORMAL_CHANNEL_RATE);

	if (theChan != -1)
		gChannelInfo[theChan].volumeAdjust = 1.0;			// full volume adjust

	return(theChan);									// return channel #
}



/***************************** PLAY EFFECT PARMS 3D ***************************/
//
// Plays an effect with parameters in 3D
//
// OUTPUT: channel # used to play sound
//

short PlayEffect_Parms3D(short effectNum, OGLPoint3D *where, uint32_t rateMultiplier, float volumeAdjust)
{
short			theChan;
uint32_t			leftVol, rightVol;

	if (effectNum >= MAX_EFFECTS)					// see if illegal sound #
	{
		DoFatalAlert("Illegal sound number %d!", effectNum);
	}

				/* CALC VOLUME */

	Calc3DEffectVolume(effectNum, where, volumeAdjust, &leftVol, &rightVol);
	if ((leftVol+rightVol) == 0)
		return(-1);


				/* PLAY EFFECT */

	theChan = PlayEffect_Parms(effectNum, leftVol, rightVol, rateMultiplier);

	if (theChan != -1)
		gChannelInfo[theChan].volumeAdjust = volumeAdjust;	// remember volume adjuster

	return(theChan);									// return channel #
}


/************************* UPDATE 3D SOUND CHANNEL ***********************/
//
// Returns TRUE if effectNum was a mismatch or something went wrong
//

Boolean Update3DSoundChannel(short effectNum, short *channel, OGLPoint3D *where)
{
uint32_t			leftVol,rightVol;
short			c;

	c = *channel;

	if (c == -1)
		return(true);

			/* MAKE SURE THE SAME SOUND IS STILL ON THIS CHANNEL */

	if (effectNum != gChannelInfo[c].effectNum)
	{
		*channel = -1;
		return(true);
	}


			/* SEE IF SOUND HAS COMPLETED */

	if (!IsEffectChannelPlaying(c))
	{
		return(true);
	}


			/* UPDATE THE THING */

	if (where)
	{
		Calc3DEffectVolume(gChannelInfo[c].effectNum, where, gChannelInfo[c].volumeAdjust, &leftVol, &rightVol);
		if ((leftVol+rightVol) == 0)										// if volume goes to 0, then kill channel
		{
			StopAChannel(channel);
			return(false);
		}

		ChangeChannelVolume(c, leftVol, rightVol);
	}
	return(false);
}

/******************** CALC 3D EFFECT VOLUME *********************/

static void Calc3DEffectVolume(short effectNum, OGLPoint3D *where, float volAdjust, uint32_t *leftVolOut, uint32_t *rightVolOut)
{
float	dist;
float	volumeFactor;
uint32_t	volume,left,right;
uint32_t	maxLeft,maxRight;
short	whichEar = 0;

	dist 	= OGLPoint3D_Distance(where, &gEarCoords[0]);		// calc dist to sound for pane 0
	if (gNumPlayers > 1)										// see if other pane is closer (thus louder)
	{
		float	dist2 = OGLPoint3D_Distance(where, &gEarCoords[1]);

		if (dist2 < dist)
		{
			dist = dist2;
			whichEar = 1;
		}
	}


		/* DO VOLUME CALCS */

	volumeFactor = (VOLUME_MIN_DIST / dist) * gEffectsTable[effectNum].refVol;
	if (volumeFactor > 1.0f)
		volumeFactor = 1.0f;


	volume = (float)FULL_CHANNEL_VOLUME * volumeFactor * volAdjust;


	if (volume < 6)							// if really quiet, then just turn it off
	{
		*leftVolOut = *rightVolOut = 0;
		return;
	}

			/************************/
			/* DO STEREO SEPARATION */
			/************************/

	else
	{
		float		volF = (float)volume;
		OGLVector2D	earToSound,lookVec;
		float		dot,cross;

		maxLeft = maxRight = 0;

			/* CALC VECTOR TO SOUND */

		earToSound.x = where->x - gEarCoords[whichEar].x;
		earToSound.y = where->z - gEarCoords[whichEar].z;
		FastNormalizeVector2D(earToSound.x, earToSound.y, &earToSound, true);


			/* CALC EYE LOOK VECTOR */

		FastNormalizeVector2D(gEyeVector[whichEar].x, gEyeVector[whichEar].z, &lookVec, true);


			/* DOT PRODUCT  TELLS US HOW MUCH STEREO SHIFT */

		dot = 1.0f - fabs(OGLVector2D_Dot(&earToSound,  &lookVec));
		if (dot < 0.0f)
			dot = 0.0f;
		else
		if (dot > 1.0f)
			dot = 1.0f;


			/* CROSS PRODUCT TELLS US WHICH SIDE */

		cross = OGLVector2D_Cross(&earToSound,  &lookVec);


				/* DO LEFT/RIGHT CALC */

		if (cross > 0.0f)
		{
			left 	= volF + (volF * dot);
			right 	= volF - (volF * dot);
		}
		else
		{
			right 	= volF + (volF * dot);
			left 	= volF - (volF * dot);
		}


				/* KEEP MAX */

		if (left > maxLeft)
			maxLeft = left;
		if (right > maxRight)
			maxRight = right;

	}

	*leftVolOut = maxLeft;
	*rightVolOut = maxRight;
}



#pragma mark -

/******************* UPDATE LISTENER LOCATION ******************/
//
// Get ear coord for all local players
//

void UpdateListenerLocation(void)
{
	for (int i = 0; i < gNumPlayers; i++)
	{
		OGLCameraPlacement* p = &gGameViewInfoPtr->cameraPlacement[i];

		OGLVector3D	v;
		v.x = p->pointOfInterest.x - p->cameraLocation.x;	// calc line of sight vector
		v.y = p->pointOfInterest.y - p->cameraLocation.y;
		v.z = p->pointOfInterest.z - p->cameraLocation.z;
		FastNormalizeVector(v.x, v.y, v.z, &v);

		gEarCoords[i].x = p->cameraLocation.x + (v.x * 300.0f);			// put ear coord in front of camera
		gEarCoords[i].y = p->cameraLocation.y + (v.y * 300.0f);
		gEarCoords[i].z = p->cameraLocation.z + (v.z * 300.0f);

		gEyeVector[i] = v;
	}
}


/***************************** PLAY EFFECT ***************************/
//
// OUTPUT: channel # used to play sound
//

short PlayEffect(short effectNum)
{
	return(PlayEffect_Parms(effectNum,FULL_CHANNEL_VOLUME,FULL_CHANNEL_VOLUME,NORMAL_CHANNEL_RATE));

}

/***************************** PLAY EFFECT PARMS ***************************/
//
// Plays an effect with parameters
//
// OUTPUT: channel # used to play sound
//

short  PlayEffect_Parms(short effectNum, uint32_t leftVolume, uint32_t rightVolume, unsigned long rateMultiplier)
{
SndCommand 		mySndCmd;
SndChannelPtr	chanPtr;
short			theChan;
OSErr			myErr;
uint32_t			lv2,rv2;
static UInt32          loopStart, loopEnd;
#if 0 //TODO: Missing in Pomme?
SoundHeaderPtr   sndPtr;
#endif

	GAME_ASSERT(effectNum >= 0);
	GAME_ASSERT(effectNum < MAX_EFFECTS);
	GAME_ASSERT_MESSAGE(gSndHandles[effectNum], "sound effect wasn't loaded!");

			/* LOOK FOR FREE CHANNEL */

	theChan = FindSilentChannel();
	if (theChan == -1)
	{
		return(-1);
	}

	lv2 = (float)leftVolume * gEffectsVolume;							// amplify by global volume
	rv2 = (float)rightVolume * gEffectsVolume;


					/* GET IT GOING */

	chanPtr = gSndChannel[theChan];

	mySndCmd.cmd = flushCmd;
	mySndCmd.param1 = 0;
	mySndCmd.param2 = 0;
	myErr = SndDoImmediate(chanPtr, &mySndCmd);
	if (myErr)
		return(-1);

	mySndCmd.cmd = quietCmd;
	mySndCmd.param1 = 0;
	mySndCmd.param2 = 0;
	myErr = SndDoImmediate(chanPtr, &mySndCmd);
	if (myErr)
		return(-1);

	mySndCmd.cmd = volumeCmd;										// set sound playback volume
	mySndCmd.param1 = 0;
	mySndCmd.param2 = (rv2<<16) | lv2;
	myErr = SndDoImmediate(chanPtr, &mySndCmd);


	mySndCmd.cmd = bufferCmd;										// make it play
	mySndCmd.param1 = 0;
	mySndCmd.ptr = ((Ptr) *gSndHandles[effectNum]) + gSndOffsets[effectNum];	// pointer to SoundHeader
    SndDoImmediate(chanPtr, &mySndCmd);
	if (myErr)
		return(-1);

	mySndCmd.cmd 		= rateMultiplierCmd;						// modify the rate to change the frequency
	mySndCmd.param1 	= 0;
	mySndCmd.param2 	= rateMultiplier;
	SndDoImmediate(chanPtr, &mySndCmd);


#if 0
    		/* SEE IF THIS IS A LOOPING EFFECT */
			// Source port note: unnecessary

    sndPtr = (SoundHeaderPtr)(((Ptr)*gSndHandles[bankNum][soundNum])+gSndOffsets[bankNum][soundNum]);
    loopStart = sndPtr->loopStart;
    loopEnd = sndPtr->loopEnd;
    if ((loopStart + 1) < loopEnd)
    {
    	mySndCmd.cmd = callBackCmd;										// let us know when the buffer is done playing
    	mySndCmd.param1 = 0;
    	mySndCmd.ptr = ((Ptr)*gSndHandles[bankNum][soundNum])+gSndOffsets[bankNum][soundNum];	// pointer to SoundHeader
    	SndDoImmediate(chanPtr, &mySndCmd);

    	gChannelInfo[theChan].isLooping = true;
    	gNumLoopingEffects++;
	}
	else
		gChannelInfo[theChan].isLooping = false;
#endif


			/* SET MY INFO */

	gChannelInfo[theChan].effectNum 	= effectNum;		// remember what effect is playing on this channel
	gChannelInfo[theChan].leftVolume 	= leftVolume;		// remember requested volume (not the adjusted volume!)
	gChannelInfo[theChan].rightVolume 	= rightVolume;
	return(theChan);										// return channel #
}


#pragma mark -


/****************** UPDATE GLOBAL VOLUME ************************/
//
// Call this whenever gGlobalVolume is changed.  This will update
// all of the sounds with the correct volume.
//

void UpdateGlobalVolume(void)
{
	gEffectsVolume = FULL_EFFECTS_VOLUME * (0.01f * gGamePrefs.sfxVolumePercent) * gGlobalVolumeFade;

			/* ADJUST VOLUMES OF ALL CHANNELS REGARDLESS IF THEY ARE PLAYING OR NOT */

	for (int c = 0; c < gMaxChannels; c++)
	{
		ChangeChannelVolume(c, gChannelInfo[c].leftVolume, gChannelInfo[c].rightVolume);
	}


			/* UPDATE SONG VOLUME */

	// First, resume song playback if it was paused -- e.g. when we're adjusting the volume via pause menu
	SndCommand cmd1 = { .cmd = pommeResumePlaybackCmd };
	SndDoImmediate(gMusicChannel, &cmd1);

	// Now update song channel volume
	gMusicVolume = FULL_SONG_VOLUME * (0.01f * gGamePrefs.musicVolumePercent) * gGlobalVolumeFade;
	uint32_t lv2 = kFullVolume * gMusicVolumeTweak * gMusicVolume;
	uint32_t rv2 = kFullVolume * gMusicVolumeTweak * gMusicVolume;
	SndCommand cmd2 =
	{
		.cmd = volumeCmd,
		.param1 = 0,
		.param2 = (rv2 << 16) | lv2,
	};
	SndDoImmediate(gMusicChannel, &cmd2);
}

/*************** CHANGE CHANNEL VOLUME **************/
//
// Modifies the volume of a currently playing channel
//

void ChangeChannelVolume(short channel, float leftVol, float rightVol)
{
SndCommand 		mySndCmd;
SndChannelPtr	chanPtr;
uint32_t			lv2,rv2;

	if (channel < 0)									// make sure it's valid
		return;

	lv2 = leftVol * gEffectsVolume;						// amplify by global volume
	rv2 = rightVol * gEffectsVolume;

	chanPtr = gSndChannel[channel];						// get the actual channel ptr

	mySndCmd.cmd = volumeCmd;							// set sound playback volume
	mySndCmd.param1 = 0;
	mySndCmd.param2 = (rv2<<16) | lv2;					// set volume left & right
	SndDoImmediate(chanPtr, &mySndCmd);

	gChannelInfo[channel].leftVolume = leftVol;			// remember requested volume (not the adjusted volume!)
	gChannelInfo[channel].rightVolume = rightVol;
}



/*************** CHANGE CHANNEL RATE **************/
//
// Modifies the frequency of a currently playing channel
//
// The Input Freq is a fixed-point multiplier, not the static rate via rateCmd.
// This function uses rateMultiplierCmd, so a value of 0x00020000 is x2.0
//

void ChangeChannelRate(short channel, long rateMult)
{
static	SndCommand 		mySndCmd;
SndChannelPtr			chanPtr;

	if (channel < 0)									// make sure it's valid
		return;

	chanPtr = gSndChannel[channel];						// get the actual channel ptr

	mySndCmd.cmd 		= rateMultiplierCmd;						// modify the rate to change the frequency
	mySndCmd.param1 	= 0;
	mySndCmd.param2 	= rateMult;
	SndDoImmediate(chanPtr, &mySndCmd);
}




#pragma mark -


/******************** FIND SILENT CHANNEL *************************/

static short FindSilentChannel(void)
{
short		theChan, startChan;
OSErr		myErr;
SCStatus	theStatus;

	theChan = gMostRecentChannel + 1;					// start on channel after the most recently acquired one - assuming it has the best chance of being silent
	if (theChan >= gMaxChannels)
		theChan = 0;
	startChan = theChan;

	do
	{
		myErr = SndChannelStatus(gSndChannel[theChan], sizeof(SCStatus), &theStatus);	// get channel info

		if (!myErr && !theStatus.scChannelBusy)			// error-free and not playing anything, pick this one
		{
			gMostRecentChannel = theChan;
			return theChan;
		}
		else
		{
			theChan++;									// try next channel
			if (theChan >= gMaxChannels)
				theChan = 0;
		}
	}while(theChan != startChan);

			/* NO FREE CHANNELS */

	return(-1);
}


/********************** IS EFFECT CHANNEL PLAYING ********************/

Boolean IsEffectChannelPlaying(short chanNum)
{
SCStatus	theStatus;

	SndChannelStatus(gSndChannel[chanNum],sizeof(SCStatus),&theStatus);	// get channel info
	return (theStatus.scChannelBusy);
}


/*************** PAUSE ALL SOUND CHANNELS **************/

void PauseAllChannels(Boolean pause)
{
	SndCommand cmd = { .cmd = pause ? pommePausePlaybackCmd : pommeResumePlaybackCmd };

	for (int c = 0; c < gMaxChannels; c++)
	{
		SndDoImmediate(gSndChannel[c], &cmd);
	}

	SndDoImmediate(gMusicChannel, &cmd);
}

#pragma mark -

/********************** GLOBAL VOLUME FADE ***************************/


void FadeSound(float loudness)
{
	gGlobalVolumeFade = loudness;
	UpdateGlobalVolume();
}


#pragma mark -

/********************** PLAY RUMBLE EFFECT ***************************/

void PlayRumbleEffect(short effectNum, int playerNum)
{
	if (effectNum < 0 || effectNum >= NUM_EFFECTS)
		return;

	const AutoRumbleDef* rumbleEffect = &gAutoRumbleTable[effectNum];

	if (rumbleEffect->duration > 0)
	{
		Rumble(rumbleEffect->lowFrequencyStrength, rumbleEffect->highFrequencyStrength, rumbleEffect->duration, playerNum);
	}
}
