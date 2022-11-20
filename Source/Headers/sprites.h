//
// sprites.h
//



enum
{
	SPRITE_FLAG_GLOW = (1)
};


typedef struct
{
	int32_t			width,height;			// read from file
	float			aspectRatio;			// h/w
	MetaObjectPtr	materialObject;
}SpriteType;


void InitSpriteManager(void);
void DisposeAllSpriteGroups(void);
void DisposeSpriteGroup(int groupNum);
void LoadSpriteGroupFromFiles(int groupNum, int numSprites, const char** paths, int flags);
void LoadSpriteGroupFromFile(int groupNum, const char* path, int flags);
void LoadSpriteGroupFromSeries(int groupNum, int numSprites, const char* seriesName);
ObjNode *MakeSpriteObject(NewObjectDefinitionType *newObjDef, Boolean drawCentered);
void BlendAllSpritesInGroup(short group);
void ModifySpriteObjectFrame(ObjNode *theNode, short type);
void BlendASprite(int group, int type);
