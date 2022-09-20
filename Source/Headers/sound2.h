//
// Sound2.h
//


typedef struct
{
	short	effectNum;
	float	volumeAdjust;
	float	leftVolume, rightVolume;
	Boolean	isLooping;
}ChannelInfoType;



#define		BASE_EFFECT_RESOURCE	10000

#define		FULL_CHANNEL_VOLUME		kFullVolume
#define		NORMAL_CHANNEL_RATE		0x10000



enum
{
	SONG_THEME,
	SONG_INTRO,
	SONG_LEVEL1,
	SONG_LEVEL2,
	SONG_LEVEL3,
	SONG_WIN
};



enum
{
	SOUND_BANK_MAIN 			= 0,
	SOUND_BANK_MENU				= 1,
	SOUND_BANK_BONUS			= 1,
	SOUND_BANK_LOSE				= 1,
	SOUND_BANK_MAINMENU			= 1,
	SOUND_BANK_LEVELSPECIFIC	= 2,
	SOUND_BANK_SONG				= 3,

	MAX_SOUND_BANKS
};



/***************** EFFECTS *************************/
// This table must match gEffectsTable
//

enum
{
		/* DEFAULT */

	EFFECT_CHANGESELECT,
	EFFECT_GETPOW,
	EFFECT_SPLASH,
	EFFECT_TURRETEXPLOSION,
	EFFECT_IMPACTSIZZLE,
	EFFECT_SHIELD,
	EFFECT_MINEEXPLODE,
	EFFECT_PLANECRASH,
	EFFECT_TURRETFIRE,
	EFFECT_STUNGUN,
	EFFECT_ROCKETLAUNCH,
	EFFECT_WEAPONCHARGE,
	EFFECT_FLARESHOOT,
	EFFECT_CHANGEWEAPON,
	EFFECT_SONICSCREAM,
	EFFECT_ELECTRODEHUM,
	EFFECT_WORMHOLE,
	EFFECT_WORMHOLEVANISH,
	EFFECT_WORMHOLEAPPEAR,
	EFFECT_EGGINTOWORMHOLE,
	EFFECT_BODYHIT,
	EFFECT_LAUNCHMISSILE,
	EFFECT_GRABEGG,
	EFFECT_JETPACKHUM,
	EFFECT_JETPACKIGNITE,
	EFFECT_MENUSELECT,
	EFFECT_MISSILEENGINE,
	EFFECT_BOMBDROP,
	EFFECT_DUSTDEVIL,
	EFFECT_LASERBEAM,
	EFFECT_CRYSTALSHATTER,
	EFFECT_RAPTORDEATH,
	EFFECT_RAPTORATTACK,
	EFFECT_BRACHHURT,
	EFFECT_BRACHDEATH,
	EFFECT_DIRT,

	NUM_EFFECTS
};



/**********************/
/* SOUND BANK TABLES  */
/**********************/
//
// These are simple enums for equating the sound effect #'s in each sound
// bank's rez file.
//

/******** SOUND_BANK_MAIN *********/

enum
{
	SOUND_DEFAULT_CHANGESELECT = 0,
	SOUND_DEFAULT_GETPOT,
	SOUND_DEFAULT_SPLASH,
	SOUND_DEFAULT_TURRETEXPLOSION,
	SOUND_DEFAULT_IMPACTSIZZLE,
	SOUND_DEFAULT_SHIELD,
	SOUND_DEFAULT_MINEEXPLODE,
	SOUND_DEFAULT_PLANECRASH,
	SOUND_DEFAULT_TURRETFIRE,
	SOUND_DEFAULT_STUNGUN,
	SOUND_DEFAULT_ROCKETLAUNCH,
	SOUND_DEFAULT_WEAPONCHARGE,
	SOUND_DEFAULT_FLARESHOOT,
	SOUND_DEFAULT_CHANGEWEAPON,
	SOUND_DEFAULT_SONICSCREAM,
	SOUND_DEFAULT_ELECTRODEHUM,
	SOUND_DEFAULT_WORMHOLE,
	SOUND_DEFAULT_WORMHOLEVANISH,
	SOUND_DEFAULT_WORMHOLEAPPEAR,
	SOUND_DEFAULT_EGGINTOWORMHOLE,
	SOUND_DEFAULT_BODYHIT,
	SOUND_DEFAULT_LAUNCHMISSILE,
	SOUND_DEFAULT_GRABEGG,
	SOUND_DEFAULT_JETPACKHUM,
	SOUND_DEFAULT_JETPACKIGNITE,
	SOUND_DEFAULT_MENUSELECT,
	SOUND_DEFAULT_MISSILEENGINE,
	SOUND_DEFAULT_BOMBDROP,
	SOUND_DEFAULT_DUSTDEVIL,
	SOUND_DEFAULT_LASERBEAM,
	SOUND_DEFAULT_CRYSTALSHATTER,
	SOUND_DEFAULT_RAPTORDEATH,
	SOUND_DEFAULT_RAPTORATTACK,
	SOUND_DEFAULT_BRACHHURT,
	SOUND_DEFAULT_BRACHDEATH,
	SOUND_DEFAULT_DIRT
};



/********** SOUND BANK: GARDEN **************/

enum
{
	SOUND_GARDEN_GNOMESTEP = 0
};



			/* EXTERNS */

extern	ChannelInfoType				gChannelInfo[];

//===================== PROTOTYPES ===================================


extern void	InitSoundTools(void);
void ShutdownSound(void);

void StopAChannel(short *channelNum);
extern	void StopAllEffectChannels(void);
void PlaySong(short songNum, Boolean loopFlag);
extern void	KillSong(void);
extern	short PlayEffect(short effectNum);
short PlayEffect_Parms3D(short effectNum, OGLPoint3D *where, u_long rateMultiplier, float volumeAdjust);
extern void	ToggleMusic(void);
extern void	DoSoundMaintenance(void);
extern	void LoadSoundBank(FSSpec *spec, long bankNum);
extern	void WaitEffectsSilent(void);
extern	void DisposeSoundBank(short bankNum);
short PlayEffect_Parms(short effectNum, u_long leftVolume, u_long rightVolume, unsigned long rateMultiplier);
void ChangeChannelVolume(short channel, float leftVol, float rightVol);
short PlayEffect3D(short effectNum, OGLPoint3D *where);
Boolean Update3DSoundChannel(short effectNum, short *channel, OGLPoint3D *where);
Boolean IsEffectChannelPlaying(short chanNum);
void UpdateListenerLocation(OGLSetupOutputType *setupInfo);
void ChangeChannelRate(short channel, long rateMult);
Boolean StopAChannelIfEffectNum(short *channelNum, short effectNum);


void StreamAudioFile(Str255 filename, short streamNum, float volumeTweak, Boolean playNow);
void KillAudioStream(short streamNum);
void StartAudioStream(short streamNum);





