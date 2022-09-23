/****************************/
/*     SOUND ROUTINES       */
/* (c)2003 Pangea Software  */
/* By Brian Greenstone      */
/****************************/


/***************/
/* EXTERNALS   */
/***************/

#include "game.h"


/****************************/
/*    PROTOTYPES            */
/****************************/

static void LoadSoundBank(void);
static void DisposeSoundBank(void);
static short FindSilentChannel(void);
static void Calc3DEffectVolume(short effectNum, OGLPoint3D *where, float volAdjust, uint32_t *leftVolOut, uint32_t *rightVolOut);
static void UpdateGlobalVolume(void);


/****************************/
/*    CONSTANTS             */
/****************************/


#define FloatToFixed16(a)      ((Fixed)((float)(a) * 0x000100L))		// convert float to 16bit fixed pt


#define		MAX_CHANNELS			40

#define		MAX_EFFECTS				70

#define		MAX_AUDIO_STREAMS		9


typedef struct
{
	const char*		name;
	float			refVol;
}EffectType;


#define	VOLUME_MIN_DIST		700.0f			// distance at which volume is 1.0 (maxxed).  Larger is louder


/**********************/
/*     VARIABLES      */
/**********************/

static volatile  Boolean gInQuicktimeFunction = false, gInMoviesTask = false;


			/* SONG RELATED */

static CGrafPtr		gQTDummyPort = nil;
/*Movie*/ void*		gSongMovie = nil;

const float	gSongVolumeTweaks[]=
{
	1.0,			// theme
	1.0,			// INTRO
	1.1,			// level 1
	1.0,			// level 2
	1.0,			// level 3
	1.0,			//  WIN
};


const Str32	gSongNames[] =
{
	":audio:theme.m4a",
	":audio:introsong.m4a",
	":audio:level1song.m4a",
	":audio:level2song.m4a",
	":audio:level3song.m4a",
	":audio:winsong.m4a",
};




			/* STREAMING FILES */

short				gNumStreamingAudioFiles = 0;
void* /*Movie*/		gStreamingAudioMovie[MAX_AUDIO_STREAMS];
float				gStreamingAudioTaskTimer[MAX_AUDIO_STREAMS];
float				gStreamingAudioVolume[MAX_AUDIO_STREAMS];
Boolean				gStreamingFileFlag[MAX_AUDIO_STREAMS];

		/* OTHER */


float						gGlobalVolume = 1.0;

static OGLPoint3D			gEarCoords[MAX_PLAYERS];						// coord of camera plus a tad to get pt in front of camera
static	OGLVector3D			gEyeVector[MAX_PLAYERS];


static	SndListHandle		gSndHandles[MAX_EFFECTS];		// handles to ALL sounds
static  long				gSndOffsets[MAX_EFFECTS];

static	SndChannelPtr		gSndChannel[MAX_CHANNELS];
ChannelInfoType				gChannelInfo[MAX_CHANNELS];

static short				gMaxChannels = 0;

static short				gMostRecentChannel = -1;

static short				gNumSndsInBank = 0;


Boolean						gSongPlayingFlag = false;
Boolean						gLoopSongFlag = true;
Boolean						gAllowAudioKeys = true;

int							gNumLoopingEffects;

Boolean				gMuteMusicFlag = false;
short				gCurrentSong = -1;


		/*****************/
		/* EFFECTS TABLE */
		/*****************/

static EffectType	gEffectsTable[] =
{
	[EFFECT_CHANGESELECT   ] = {"CHANGESELECT",		1},
	[EFFECT_GETPOW         ] = {"GETPOW",			1},
	[EFFECT_SPLASH         ] = {"SPLASH",			1},
	[EFFECT_TURRETEXPLOSION] = {"TURRETEXPLOSION",	2.0},
	[EFFECT_IMPACTSIZZLE   ] = {"IMPACTSIZZLE",		1},
	[EFFECT_SHIELD         ] = {"SHIELD",			1},
	[EFFECT_MINEEXPLODE    ] = {"MINEEXPLODE",		3},
	[EFFECT_PLANECRASH     ] = {"PLANECRASH",		1},
	[EFFECT_TURRETFIRE     ] = {"TURRETFIRE",		1.0},
	[EFFECT_STUNGUN        ] = {"STUNGUN",			.7},
	[EFFECT_ROCKETLAUNCH   ] = {"ROCKETLAUNCH",		1},
	[EFFECT_WEAPONCHARGE   ] = {"WEAPONCHARGE",		1},
	[EFFECT_FLARESHOOT     ] = {"FLARESHOOT",		1},
	[EFFECT_CHANGEWEAPON   ] = {"CHANGEWEAPON",		1},
	[EFFECT_SONICSCREAM    ] = {"SONICSCREAM",		1},
	[EFFECT_ELECTRODEHUM   ] = {"ELECTRODEHUM",		.2},
	[EFFECT_WORMHOLE       ] = {"WORMHOLE",			1.0},
	[EFFECT_WORMHOLEVANISH ] = {"WORMHOLEVANISH",	1.6},
	[EFFECT_WORMHOLEAPPEAR ] = {"WORMHOLEAPPEAR",	1.6},
	[EFFECT_EGGINTOWORMHOLE] = {"EGGINTOWORMHOLE",	1.0},
	[EFFECT_BODYHIT        ] = {"BODYHIT",			1.0},
	[EFFECT_LAUNCHMISSILE  ] = {"LAUNCHMISSILE",	.7},
	[EFFECT_GRABEGG        ] = {"GRABEGG",			.7},
	[EFFECT_JETPACKHUM     ] = {"JETPACKHUM",		.8},
	[EFFECT_JETPACKIGNITE  ] = {"JETPACKIGNITE",	.6},
	[EFFECT_MENUSELECT     ] = {"MENUSELECT",		.6},
	[EFFECT_MISSILEENGINE  ] = {"MISSILEENGINE",	.6},
	[EFFECT_BOMBDROP       ] = {"BOMBDROP",			1.0},
	[EFFECT_DUSTDEVIL      ] = {"DUSTDEVIL",		1.0},
	[EFFECT_LASERBEAM      ] = {"LASERBEAM",		1.0},
	[EFFECT_CRYSTALSHATTER ] = {"CRYSTALSHATTER",	1.5},
	[EFFECT_RAPTORDEATH    ] = {"RAPTORDEATH",		.8},
	[EFFECT_RAPTORATTACK   ] = {"RAPTORATTACK",		1.0},
	[EFFECT_BRACHHURT      ] = {"BRACHHURT",		1.2},
	[EFFECT_BRACHDEATH     ] = {"BRACHDEATH",		1.0},
	[EFFECT_DIRT           ] = {"DIRT",				1.0},
};


/********************* INIT SOUND TOOLS ********************/

void InitSoundTools(void)
{
OSErr			iErr;
FSSpec			spec;


	gNumLoopingEffects = 0;

	gMaxChannels = 0;
	gMostRecentChannel = -1;


			/* INIT BANK INFO */

	gNumSndsInBank = 0;

			/******************/
			/* ALLOC CHANNELS */
			/******************/

	for (gMaxChannels = 0; gMaxChannels < MAX_CHANNELS; gMaxChannels++)
	{
			/* NEW SOUND CHANNEL */

		SndCommand 		mySndCmd;

		iErr = SndNewChannel(&gSndChannel[gMaxChannels],sampledSynth,initMono+initNoInterp,nil);//NewSndCallBackUPP(CallBackFn));
		if (iErr)												// if err, stop allocating channels
			break;

		gChannelInfo[gMaxChannels].isLooping = false;
	}


			/****************/
			/* INIT STREAMS */
			/****************/

	gNumStreamingAudioFiles = 0;

	for (int i = 0; i < MAX_AUDIO_STREAMS; i++)
	{
		gStreamingAudioMovie[i] 	= nil;
		gStreamingAudioTaskTimer[i] = 0;
		gStreamingFileFlag[i] 		= false;
	}




		/***********************/
		/* LOAD DEFAULT SOUNDS */
		/***********************/

	iErr = FSMakeFSSpec(gDataSpec.vRefNum, gDataSpec.parID, ":Audio:Main.sounds", &spec);
	if (iErr)
		DoFatalAlert("InitSoundTools: FSMakeFSSpec failed");

	LoadSoundBank();
}


/******************** SHUTDOWN SOUND ***************************/
//
// Called at Quit time
//

void ShutdownSound(void)
{
int	i;

			/* STOP ANY PLAYING AUDIO */

	StopAllEffectChannels();
	KillSong();


		/* DISPOSE OF CHANNELS */

	for (i = 0; i < gMaxChannels; i++)
		SndDisposeChannel(gSndChannel[i], true);
	gMaxChannels = 0;


		/* DISPOSE SOUND BANK */

	DisposeSoundBank();
}

#pragma mark -

/******************* LOAD SOUND BANK ************************/

static void LoadSoundBank(void)
{
	StopAllEffectChannels();

			/* DISPOSE OF EXISTING BANK */

	DisposeSoundBank();

			/****************************/
			/* LOAD ALL EFFECTS IN BANK */
			/****************************/

	for (int i = 0; i < NUM_EFFECTS; i++)
	{
		char path[64];
		FSSpec spec;
		short refNum;

		snprintf(path, sizeof(path), ":Audio:SoundBank:%s.aiff", gEffectsTable[i].name);
		FSMakeFSSpec(gDataSpec.vRefNum, gDataSpec.parID, path, &spec);
		FSpOpenDF(&spec, fsRdPerm, &refNum);

				/* LOAD SND REZ */

		gSndHandles[i] = Pomme_SndLoadFileAsResource(refNum);
		GAME_ASSERT(gSndHandles[i]);

				/* GET OFFSET INTO IT */

		GetSoundHeaderOffset(gSndHandles[i], &gSndOffsets[i]);

				/* PRE-DECOMPRESS IT */

		Pomme_DecompressSoundResource(&gSndHandles[i], &gSndOffsets[i]);

		FSClose(refNum);
	}

	gNumSndsInBank = NUM_EFFECTS;					// remember how many sounds we've got
}


/******************** DISPOSE SOUND BANK **************************/

static void DisposeSoundBank(void)
{
	StopAllEffectChannels();									// make sure all sounds are stopped before nuking any banks

			/* FREE ALL SAMPLES */

	for (int i = 0; i < gNumSndsInBank; i++)
	{
		DisposeHandle((Handle) gSndHandles[i]);
		gSndHandles[i] = nil;
	}


	gNumSndsInBank = 0;
}



/********************* STOP A CHANNEL **********************/
//
// Stops the indicated sound channel from playing.
//

void StopAChannel(short *channelNum)
{
SndCommand 	mySndCmd;
OSErr 		myErr;
short		c = *channelNum;

	if ((c < 0) || (c >= gMaxChannels))		// make sure its a legal #
		return;

	mySndCmd.cmd = flushCmd;
	mySndCmd.param1 = 0;
	mySndCmd.param2 = 0;
	myErr = SndDoImmediate(gSndChannel[c], &mySndCmd);

	mySndCmd.cmd = quietCmd;
	mySndCmd.param1 = 0;
	mySndCmd.param2 = 0;
	myErr = SndDoImmediate(gSndChannel[c], &mySndCmd);

	*channelNum = -1;

	if (gChannelInfo[c].isLooping)
	{
		gNumLoopingEffects--;
		gChannelInfo[c].isLooping = false;
	}

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


/****************** WAIT EFFECTS SILENT *********************/

void WaitEffectsSilent(void)
{
short	i;
Boolean	isBusy;
SCStatus				theStatus;

	do
	{
		isBusy = 0;
		for (i=0; i < gMaxChannels; i++)
		{
			SndChannelStatus(gSndChannel[i],sizeof(SCStatus),&theStatus);	// get channel info
			isBusy |= theStatus.scChannelBusy;
		}
	}while(isBusy);
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
FSSpec	spec;
short	myRefNum;
GrafPtr	oldPort;

	if (songNum == gCurrentSong)					// see if this is already playing
		return;


		/* ZAP ANY EXISTING SONG */

	gCurrentSong 	= songNum;
	gLoopSongFlag 	= loopFlag;
	KillSong();
	DoSoundMaintenance();

			/******************************/
			/* OPEN APPROPRIATE SND FILE */
			/******************************/

	iErr = FSMakeFSSpec(gDataSpec.vRefNum, gDataSpec.parID, gSongNames[songNum], &spec);
	if (iErr)
		DoFatalAlert("PlaySong: song file not found");

	gCurrentSong = songNum;


	SOFTIMPME;
#if 0
				/*****************/
				/* START PLAYING */
				/*****************/

			/* GOT TO SET A DUMMY PORT OR QT MAY FREAK */

	if (gQTDummyPort == nil)						// create a blank graf port
		gQTDummyPort = CreateNewPort();

	GetPort(&oldPort);								// set as active before NewMovieFromFile()
	SetPort(gQTDummyPort);


	iErr = OpenMovieFile(&spec, &myRefNum, fsRdPerm);
	if (myRefNum && (iErr == noErr))
	{
		iErr = NewMovieFromFile(&gSongMovie, myRefNum, 0, nil, newMovieActive, nil);
		CloseMovieFile(myRefNum);

		if (iErr == noErr)
		{
			TimeValue timeNow, duration;
			Fixed playRate;
			Media theMedia;

			SetMoviePlayHints(gSongMovie, 0, hintsUseSoundInterp|hintsHighQuality);	// turn these off
			if (loopFlag)
				SetMoviePlayHints(gSongMovie, hintsLoop, hintsLoop);	// turn this on

			timeNow = GetMovieTime(gSongMovie, nil);
			duration = GetMovieDuration(gSongMovie);
			playRate = GetMoviePreferredRate(gSongMovie);
			theMedia = GetTrackMedia(GetMovieIndTrack(gSongMovie, 1));

			LoadMovieIntoRam(gSongMovie, timeNow, duration, keepInRam);
			LoadMediaIntoRam(theMedia, timeNow, duration, keepInRam);

//			MediaSetPreferredChunkSize(theMedia, 200000);
 			PrePrerollMovie(gSongMovie, timeNow, playRate, nil, nil);
  			PrerollMovie(gSongMovie, timeNow, playRate);

			SetMovieVolume(gSongMovie, FloatToFixed16(gGlobalVolume * gSongVolumeTweaks[songNum])); // set volume
			StartMovie(gSongMovie);

			gSongPlayingFlag = true;
		}
	}

	SetPort(oldPort);



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
	gInQuicktimeFunction = true;				// dont allow song task to start anything new
	while(gInMoviesTask);			// DONT DO ANYTHING WHILE IN THE SONG TASK!!


	gCurrentSong = -1;

	if (!gSongPlayingFlag)
		goto bail;

	gSongPlayingFlag = false;											// tell callback to do nothing

	SOFTIMPME;
#if 0
	StopMovie(gSongMovie);
	DisposeMovie(gSongMovie);
#endif

	gSongMovie = nil;


bail:
	gInQuicktimeFunction = false;
}

/******************** TOGGLE MUSIC *********************/

void ToggleMusic(void)
{

	gMuteMusicFlag = !gMuteMusicFlag;

	SOFTIMPME;
#if 0
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
#endif
}





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

	if (effectNum >= gNumSndsInBank)					// see if illegal sound #
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

	if (effectNum >= gNumSndsInBank)					// see if illegal sound #
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
SCStatus		theStatus;
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

	if (!gChannelInfo[c].isLooping)										// loopers wont complete, duh.
	{
		SndChannelStatus(gSndChannel[c],sizeof(SCStatus),&theStatus);	// get channel info
		if (!theStatus.scChannelBusy)									// see if channel not busy
		{
			StopAChannel(channel);							// make sure it's really stopped (OS X sound manager bug)
			return(true);
		}
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

void UpdateListenerLocation(OGLSetupOutputType *setupInfo)
{
OGLVector3D	v;
short	i;

	for (i = 0; i < gNumPlayers; i++)
	{
		v.x = setupInfo->cameraPlacement[i].pointOfInterest.x - setupInfo->cameraPlacement[i].cameraLocation.x;	// calc line of sight vector
		v.y = setupInfo->cameraPlacement[i].pointOfInterest.y - setupInfo->cameraPlacement[i].cameraLocation.y;
		v.z = setupInfo->cameraPlacement[i].pointOfInterest.z - setupInfo->cameraPlacement[i].cameraLocation.z;
		FastNormalizeVector(v.x, v.y, v.z, &v);

		gEarCoords[i].x = setupInfo->cameraPlacement[i].cameraLocation.x + (v.x * 300.0f);			// put ear coord in front of camera
		gEarCoords[i].y = setupInfo->cameraPlacement[i].cameraLocation.y + (v.y * 300.0f);
		gEarCoords[i].z = setupInfo->cameraPlacement[i].cameraLocation.z + (v.z * 300.0f);

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

#if 0
/***************************** CALLBACKFN ***************************/
//
// Called by the Sound Manager at interrupt time to let us know that
// the sound is done playing.
//

static pascal void CallBackFn (SndChannelPtr chan, SndCommand *cmd)
{
SndCommand      theCmd;

    // Play the sound again (loop it)

    theCmd.cmd = bufferCmd;
    theCmd.param1 = 0;
    theCmd.param2 = cmd->param2;
	SndDoCommand (chan, &theCmd, true);

    // Just reuse the callBackCmd that got us here in the first place
    SndDoCommand (chan, cmd, true);
}
#endif

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

	if (effectNum >= gNumSndsInBank)									// see if illegal sound #
	{
		DoFatalAlert("Illegal sound number %d!", effectNum);
	}

			/* LOOK FOR FREE CHANNEL */

	theChan = FindSilentChannel();
	if (theChan == -1)
	{
		return(-1);
	}

	lv2 = (float)leftVolume * gGlobalVolume;							// amplify by global volume
	rv2 = (float)rightVolume * gGlobalVolume;


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



    		/* SEE IF THIS IS A LOOPING EFFECT */

	SOFTIMPME;
#if 0
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

static void UpdateGlobalVolume(void)
{
int		c;

			/* ADJUST VOLUMES OF ALL CHANNELS REGARDLESS IF THEY ARE PLAYING OR NOT */

	for (c = 0; c < gMaxChannels; c++)
	{
		ChangeChannelVolume(c, gChannelInfo[c].leftVolume, gChannelInfo[c].rightVolume);
	}

	SOFTIMPME;
#if 0
			/* UPDATE SONG VOLUME */

	if (gSongPlayingFlag)
	{
		gInQuicktimeFunction = true;				// dont allow song task to start anything new
		while(gInMoviesTask);			// DONT DO ANYTHING WHILE IN THE SONG TASK!!

		SetMovieVolume(gSongMovie, FloatToFixed16(gGlobalVolume) * gSongVolumeTweaks[gCurrentSong]);

		gInQuicktimeFunction = false;
	}

			/* UPDATE STREAMING AUDIO VOLUME */

	for (c = 0; c < MAX_AUDIO_STREAMS; c++)
	{
		if (gStreamingFileFlag[c])
		{
			SetMovieVolume(gStreamingAudioMovie[c], FloatToFixed16(gGlobalVolume) * gStreamingAudioVolume[c]);
		}
	}
#endif

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

	lv2 = leftVol * gGlobalVolume;						// amplify by global volume
	rv2 = rightVol * gGlobalVolume;

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


/******************** DO SOUND MAINTENANCE *************/
//
// 		ReadKeyboard() must have already been called
//

void DoSoundMaintenance(void)
{
float	fps = gFramesPerSecondFrac;
short	i;

	if (gAllowAudioKeys)
	{
					/* SEE IF TOGGLE MUSIC */

		if (GetNewKeyState(KEY_M))
		{
			ToggleMusic();
		}


				/* SEE IF CHANGE VOLUME */

		if (GetKeyState(KEY_PLUS))
		{
			gGlobalVolume += .5f * fps;
			UpdateGlobalVolume();
		}
		else
		if (GetKeyState(KEY_MINUS))
		{
			gGlobalVolume -= .5f * fps;
			if (gGlobalVolume < 0.0f)
				gGlobalVolume = 0.0f;
			UpdateGlobalVolume();
		}
	}


				/***************/
				/* UPDATE SONG */
				/***************/

	if (gSongPlayingFlag)
	{
		SOFTIMPME;
#if 0
		gInQuicktimeFunction = true;				// dont allow song task to start anything new
		while(gInMoviesTask);			// DONT DO ANYTHING WHILE IN THE SONG TASK!!

		if (IsMovieDone(gSongMovie))				// see if the song has completed
		{
			if (gLoopSongFlag)						// see if repeat it
			{
				GoToBeginningOfMovie(gSongMovie);
				StartMovie(gSongMovie);
			}
			else									// otherwise kill the song
				KillSong();
		}
#endif

		gInQuicktimeFunction = false;
	}


				/**************************/
				/* UPDATE STREAMING AUDIO */
				/**************************/

	if (gNumStreamingAudioFiles > 0)
	{
		for (i = 0; i < MAX_AUDIO_STREAMS; i++)
		{
			if (gStreamingFileFlag[i])
			{
				SOFTIMPME;
#if 0
				if (IsMovieDone(gStreamingAudioMovie[i]))				// see if the song has completed
				{
					KillAudioStream(i);
				}
				else
				{
					gStreamingAudioTaskTimer[i] -= fps;
					if (gStreamingAudioTaskTimer[i] <= 0.0f)
					{
						gInQuicktimeFunction = true;				// dont allow song task to start anything new
						while(gInMoviesTask);						// DONT DO ANYTHING WHILE IN THE SONG TASK!!

						MoviesTask(gStreamingAudioMovie[i], 0);
						gStreamingAudioTaskTimer[i] += .15f;

						gInQuicktimeFunction = false;
					}
				}
#endif
			}
		}
	}

		/* ALSO CHECK OPTIONS */

	if (GetNewKeyState(KEY_F1))
	{
		DoGameOptionsDialog();
	}

}



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
		if (gChannelInfo[theChan].isLooping)				// see if this channel is playing a looping effect
			goto next;

		myErr = SndChannelStatus(gSndChannel[theChan],sizeof(SCStatus),&theStatus);	// get channel info
		if (myErr)
			goto next;

		if (theStatus.scChannelBusy)					// see if channel busy
			goto next;

		gMostRecentChannel = theChan;
		return(theChan);

next:
		theChan++;										// try next channel
		if (theChan >= gMaxChannels)
			theChan = 0;

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



#pragma mark -


/******************** STREAM AUDIO FILE ***********************/

void StreamAudioFile(const char* filename, short streamNum, float volumeTweak, Boolean playNow)
{
	SOFTIMPME;
	printf("Stream: %s\n", filename);
	return;
OSErr 	iErr;
short	myRefNum;
GrafPtr	oldPort;
FSSpec spec;

	if (streamNum >= MAX_AUDIO_STREAMS)
		DoFatalAlert("StreamAudioFile: streamNum >= MAX_AUDIO_STREAMS");

		/* ZAP ANY EXISTING STREAM */

	KillAudioStream(streamNum);
	DoSoundMaintenance();


	if (FSMakeFSSpec(gDataSpec.vRefNum, gDataSpec.parID, filename, &spec) != noErr)
		DoFatalAlert("StreamAudioFile: file not found");


				/*****************/
				/* START PLAYING */
				/*****************/

	SOFTIMPME;
#if 0
			/* GOT TO SET A DUMMY PORT OR QT MAY FREAK */

	if (gQTDummyPort == nil)						// create a blank graf port
		gQTDummyPort = CreateNewPort();

	GetPort(&oldPort);								// set as active before NewMovieFromFile()
	SetPort(gQTDummyPort);


	iErr = OpenMovieFile(&spec, &myRefNum, fsRdPerm);
	if (myRefNum && (iErr == noErr))
	{
		iErr = NewMovieFromFile(&gStreamingAudioMovie[streamNum], myRefNum, 0, nil, newMovieActive, nil);
		CloseMovieFile(myRefNum);

		if (iErr == noErr)
		{
			LoadMovieIntoRam(gStreamingAudioMovie[streamNum], 0, GetMovieDuration(gStreamingAudioMovie[streamNum]), keepInRam);

			SetMoviePlayHints(gStreamingAudioMovie[streamNum], 0, hintsUseSoundInterp|hintsHighQuality);	// turn these off

			SetMovieVolume(gStreamingAudioMovie[streamNum], FloatToFixed16(gGlobalVolume * volumeTweak));	// set volume
			if (playNow)
				StartMovie(gStreamingAudioMovie[streamNum]);												// start playing now if we want

			gStreamingFileFlag[streamNum] = true;
		}
	}

	SetPort(oldPort);
#endif

	gStreamingAudioVolume[streamNum] = volumeTweak;


	gNumStreamingAudioFiles++;

}

/************************* START AUDIO STREAM ***********************/

void StartAudioStream(short streamNum)
{
	SOFTIMPME;
#if 0
	if (gStreamingFileFlag[streamNum])
		StartMovie(gStreamingAudioMovie[streamNum]);
#endif
}


/*********************** KILL AUDIO STREAM *********************/

void KillAudioStream(short streamNum)
{
	SOFTIMPME;
#if 0
		/* KILL ALL AUDIO STREAMS */

	if (streamNum == -1)
	{
		for (streamNum = 0; streamNum < MAX_AUDIO_STREAMS; streamNum++)
		{
			if (!gStreamingFileFlag[streamNum])
				continue;

			gStreamingFileFlag[streamNum] = false;											// tell callback to do nothing

			StopMovie(gStreamingAudioMovie[streamNum]);
			DisposeMovie(gStreamingAudioMovie[streamNum]);

			gStreamingAudioMovie[streamNum] = nil;

			gNumStreamingAudioFiles--;
		}
	}

			/* JUST KILL THIS ONE */

	else
	{
		if (!gStreamingFileFlag[streamNum])
			return;

		gStreamingFileFlag[streamNum] = false;											// tell callback to do nothing

		StopMovie(gStreamingAudioMovie[streamNum]);
		DisposeMovie(gStreamingAudioMovie[streamNum]);

		gStreamingAudioMovie[streamNum] = nil;

		gNumStreamingAudioFiles--;
	}
#endif
}

