#include "game.h"

static ObjNode* gAnaglyphScreenHead = NULL;

void DisposeAnaglyphCalibrationScreen(void)
{
	DisposeSpriteAtlas(SPRITE_GROUP_FONT3);
	DisposeSpriteGroup(SPRITE_GROUP_LEVELSPECIFIC);

	if (gAnaglyphScreenHead)
	{
		DeleteObject(gAnaglyphScreenHead);
		gAnaglyphScreenHead = NULL;
	}
}

static void MoveAnaglyphScreenHeadObject(ObjNode* theNode)
{
	(void) theNode;

	if (GetCurrentMenu() != 'cali')
	{
		DisposeAnaglyphCalibrationScreen();
	}
}

void SetUpAnaglyphCalibrationScreen(const MenuItem* mi)
{
	(void) mi;

			/* NUKE AND RELOAD TEXTURES SO THE CURRENT ANAGLYPH FILTER APPLIES TO THEM */

	DisposeAnaglyphCalibrationScreen();

	DisposeGlobalAssets();		// reload the font - won't apply to current menu because it keeps a reference to the
	LoadGlobalAssets();			// old material, but at least the text will look correct when we exit the menu.

	BuildMainMenuObjects();		// rebuild background image

	LoadSpriteAtlas(SPRITE_GROUP_FONT3, "subtitlefont", kAtlasLoadFont);

			/* CREATE HEAD SENTINEL - ALL ANAGLYPH CALIB OBJECTS WILL BE CHAINED TO IT */

	NewObjectDefinitionType headSentinelDef =
	{
		.group = CUSTOM_GENRE,
		.scale = 1,
		.slot = SPRITE_SLOT,
		.flags = STATUS_BIT_HIDDEN | STATUS_BIT_MOVEINPAUSE,
		.moveCall = MoveAnaglyphScreenHeadObject,
	};
	ObjNode* anaglyphScreenHead = MakeNewObject(&headSentinelDef);
	gAnaglyphScreenHead = anaglyphScreenHead;

			/* MAKE HELP BLURB */

	char blurb[1024];

	if (IsStereoAnaglyphColor())
	{
		snprintf(blurb, sizeof(blurb),
				"%s\n \n"
				"1. %s\n \n"
				"2. %s\n \n"
				"3. %s",
				Localize(STR_ANAGLYPH_HELP_WHILEWEARING),
				Localize(STR_ANAGLYPH_HELP_ADJUSTRB),
				Localize(STR_ANAGLYPH_HELP_ADJUSTG),
				Localize(STR_ANAGLYPH_HELP_CHANNELBALANCING));

	}
	else if (IsStereoAnaglyphMono())
	{
		snprintf(blurb, sizeof(blurb), "%s\n \n%s",
				Localize(STR_ANAGLYPH_HELP_WHILEWEARING),
				Localize(STR_ANAGLYPH_HELP_ADJUSTRB));
	}
	else
	{
		snprintf(blurb, sizeof(blurb), "\n");
	}

	NewObjectDefinitionType blurbDef =
	{
		.group = SPRITE_GROUP_FONT3,
		.scale = 0.18f,
		.slot = SPRITE_SLOT+1,
		.coord = {10, 470, 0},
	};
	ObjNode* blurbNode = TextMesh_New(blurb, kTextMeshAlignLeft | kTextMeshAlignBottom, &blurbDef);
	AppendNodeToChain(anaglyphScreenHead, blurbNode);

			/* MAKE TEST PATTERN */

	LoadSpriteGroupFromFiles(SPRITE_GROUP_LEVELSPECIFIC, 1, (const char*[]) {":images:calibration1.png"}, 0);
	NewObjectDefinitionType def =
	{
		.group		= SPRITE_GROUP_LEVELSPECIFIC,
		.type		= 0,		// 0th image in sprite group
		.coord		= {500,380,0},
		.slot		= SPRITE_SLOT+2,
		.scale		= 250,
	};

	ObjNode* sampleImage = MakeSpriteObject(&def, true);
	sampleImage->AnaglyphZ = 4.0f;
	AppendNodeToChain(anaglyphScreenHead, sampleImage);
}

void OnChangeAnaglyphSetting(const MenuItem* mi)
{
	gAnaglyphPass = 0;
	for (int i = 0; i < 4; i++)
	{
		glColorMask(GL_TRUE, GL_TRUE, GL_TRUE, GL_TRUE);
		glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
		SDL_GL_SwapWindow(gSDLWindow);
	}

	SetUpAnaglyphCalibrationScreen(mi);
	LayoutCurrentMenuAgain();
}

int GetAnaglyphDisplayFlags(const MenuItem* mi)
{
	if (IsStereoAnaglyph())
		return 0;
	else
		return kMILayoutFlagHidden;
}

int GetAnaglyphDisplayFlags_ColorOnly(const MenuItem* mi)
{
	if (IsStereoAnaglyphColor())
		return 0;
	else
		return kMILayoutFlagHidden;
}