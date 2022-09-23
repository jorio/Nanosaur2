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
short PlayEffect_Parms3D(short effectNum, OGLPoint3D *where, uint32_t rateMultiplier, float volumeAdjust);
extern void	ToggleMusic(void);
extern void	DoSoundMaintenance(void);
extern	void WaitEffectsSilent(void);
short PlayEffect_Parms(short effectNum, uint32_t leftVolume, uint32_t rightVolume, unsigned long rateMultiplier);
void ChangeChannelVolume(short channel, float leftVol, float rightVol);
short PlayEffect3D(short effectNum, OGLPoint3D *where);
Boolean Update3DSoundChannel(short effectNum, short *channel, OGLPoint3D *where);
Boolean IsEffectChannelPlaying(short chanNum);
void UpdateListenerLocation(OGLSetupOutputType *setupInfo);
void ChangeChannelRate(short channel, long rateMult);
Boolean StopAChannelIfEffectNum(short *channelNum, short effectNum);


void StreamAudioFile(const char* filename, short streamNum, float volumeTweak, Boolean playNow);
void KillAudioStream(short streamNum);
void StartAudioStream(short streamNum);





