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
void LoadSpriteGroup(int groupNum, const char* fileName, int flags);
ObjNode *MakeSpriteObject(NewObjectDefinitionType *newObjDef, Boolean drawCentered);
void BlendAllSpritesInGroup(short group);
void ModifySpriteObjectFrame(ObjNode *theNode, short type);
void DrawSprite(int	group, int type, float x, float y, float scale, float rot, uint32_t flags);
void BlendASprite(int group, int type);

ObjNode *MakeFontStringObject(const char* s, NewObjectDefinitionType *newObjDef, Boolean center);
float GetStringWidth(const char* s, float scale);
float GetCharSpacing(char c, float spacingScale);
int CharToSprite(char c);

void SwizzleARGBtoBGRA(long w, long h, uint32_t *pixels);
void SwizzleARGBtoRGBA(long w, long h, uint32_t *pixels);
void SetAlphaInARGBBuffer(long w, long h, uint32_t *pixels);
void SetAlphaIn16BitBuffer(long w, long h, u_short *pixels);
