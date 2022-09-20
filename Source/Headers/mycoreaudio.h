//
// MyCoreAudio.h
//






void InitCoreAudioSystem(void);
int CoreAudio_LoadAIFFSample(Str255 filename);

int CoreAudio_PlaySound(int sample_idx, float lft_vol, float rgt_vol, Boolean loop);
