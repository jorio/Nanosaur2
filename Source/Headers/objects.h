//
// Object.h
//

#pragma once

#define INVALID_NODE_FLAG	0xdeadbeef			// put into CType when node is deleted

#define	TERRAIN_SLOT	1
#define	PLAYER_SLOT		50						// note:  draw any "OGL fenced" objects first for best performance (we want their fences ending asap)
#define	ENEMY_SLOT		(PLAYER_SLOT+10)
#define	SLOT_OF_DUMB	3000
#define	BGPIC_SLOT		SLOT_OF_DUMB
#define	SPRITE_SLOT		(SLOT_OF_DUMB+100)
#define	FENCE_SLOT		(TERRAIN_SLOT+3)		// need to draw very early for alpha blending of other objects to look best
#define	PARTICLE_SLOT	(SPRITE_SLOT-2)
#define	CONFETTI_SLOT	(PARTICLE_SLOT-1)		// do confetti before particles since particles are xparent
#define	WATER_SLOT		(SLOT_OF_DUMB - 50)		// do before DUMB because some glowing weapons need to be drawn after the water
#define	CONTRAIL_SLOT	(SPRITE_SLOT - 10)
#define	INFOBAR_SLOT	(SLOT_OF_DUMB + 3000)
#define	FADEPANE_SLOT	(SLOT_OF_DUMB + 4000)
#define	MENU_SLOT		INFOBAR_SLOT
#define	PANEDIVIDER_SLOT (INFOBAR_SLOT-1)
#define	CURSOR_SLOT		(MENU_SLOT + 100)

enum
{
	ILLEGAL_GENRE = 0,
	SKELETON_GENRE,
	DISPLAY_GROUP_GENRE,
	SPRITE_GENRE,
	CUSTOM_GENRE,
	EVENT_GENRE,
	TEXTMESH_GENRE,
	QUADMESH_GENRE,
};


// ShadowType is now a plain Swift enum in GameEnums.swift - nothing in C touches it, so it's no longer declared here.


// WhatType is now a plain Swift enum in GameEnums.swift - nothing in C touches it, so it's no longer declared here.


#define	ShadowScaleX	SpecialF[0]
#define	ShadowScaleZ	SpecialF[1]
#define	CheckForBlockers	Flag[0]


//========================================================


extern	void DeleteObject(ObjNode * _Nullable theNode);



//===================









void SendNodeToOverlayPane(ObjNode* _Nonnull theNode);
