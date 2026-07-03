/****************************/
/*     SOUND ROUTINES       */
/* By Brian Greenstone      */
/* (c)2003 Pangea Software  */
/* (c)2022 Iliyas Jorio     */
/****************************/

// All function implementations are now in Sound.swift. gChannelInfo stays
// here because SwiftInternal.h's GetChannelInfoEntry shim references it
// directly. gSongPlayingFlag/gCurrentSong stay here because they're
// `extern`'d in game.h, and gCurrentSong is read by MainMenu.c (still
// unported).

#include "game.h"

#define		MAX_CHANNELS			40

ChannelInfoType				gChannelInfo[MAX_CHANNELS];

Boolean						gSongPlayingFlag = false;

short				gCurrentSong = -1;
