//
// Sound2.h
//


typedef struct
{
	short	effectNum;
	float	volumeAdjust;
	float	leftVolume, rightVolume;
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
	SONG_WIN,
	MAX_SONGS
};



/***************** EFFECTS *************************/
// This table must match gEffectsTable
//

enum
{
	EFFECT_NULL,

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
	EFFECT_BADSELECT,

		/* NARRATION */

	EFFECT_STORY1,
	EFFECT_STORY2,
	EFFECT_STORY3,
	EFFECT_STORY4,
	EFFECT_STORY5,
	EFFECT_STORY6,
	EFFECT_STORY7,

	NUM_EFFECTS
};

enum
{
	SOUND_BANK_NULL,
	SOUND_BANK_MAIN,
	SOUND_BANK_NARRATION,
	NUM_SOUND_BANKS,
};


			/* EXTERNS */

extern	ChannelInfoType				gChannelInfo[];

//===================== PROTOTYPES ===================================


extern void	InitSoundTools(void);
void ShutdownSound(void);

void StopAChannel(short *channelNum);
extern	void StopAllEffectChannels(void);
void LoadSoundBank(uint8_t bank);
void DisposeSoundBank(uint8_t bank);
void PlaySong(short songNum, Boolean loopFlag);
extern void	KillSong(void);
extern	short PlayEffect(short effectNum);
short PlayEffect_Parms3D(short effectNum, OGLPoint3D *where, uint32_t rateMultiplier, float volumeAdjust);
extern void	ToggleMusic(void);
void UpdateGlobalVolume(void);
short PlayEffect_Parms(short effectNum, uint32_t leftVolume, uint32_t rightVolume, unsigned long rateMultiplier);
void ChangeChannelVolume(short channel, float leftVol, float rightVol);
short PlayEffect3D(short effectNum, OGLPoint3D *where);
Boolean Update3DSoundChannel(short effectNum, short *channel, OGLPoint3D *where);
Boolean IsEffectChannelPlaying(short chanNum);
void UpdateListenerLocation(void);
void ChangeChannelRate(short channel, long rateMult);
Boolean StopAChannelIfEffectNum(short *channelNum, short effectNum);
void PauseAllChannels(Boolean pause);
void FadeSound(float loudness);
