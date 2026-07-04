//
// sprites.h
//

#pragma once



enum
{
	SPRITE_FLAG_GLOW = (1)
};


typedef struct
{
	int32_t			width,height;			// read from file
	float			aspectRatio;			// h/w
	MetaObjectPtr _Nullable	materialObject;
}SpriteType;


#pragma clang assume_nonnull begin

void ModifySpriteObjectFrame(ObjNode *theNode, short type);

#pragma clang assume_nonnull end
