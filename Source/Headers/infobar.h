//
// infobar.h
//



void InitInfobar(void);
void DrawInfobar(ObjNode * _Nullable theNode);
void DisposeInfobar(void);
void DrawInfobarSprite(float x, float y, float size, short texNum);
void DrawInfobarSprite2_Centered(float x, float y, float size, short group, short texNum);
void DrawInfobarSprite2(float x, float y, float size, short group, short texNum);
void DrawInfobarSprite3(float x, float y, float size, short texNum);
void DrawInfobarSprite3_Centered(float x, float y, float size, short texNum);
void DrawInfobarSprite_Centered(float x, float y, float size, short texNum);
void Infobar_DrawNumber(int number, float x, float y, float scale, int numDigits, Boolean showLeading);

OGLRect Get2DLogicalRect(Byte splitScreenPane, float zoom);
void SetInfobarSpriteState(float anaglyphZ, float zoom);

ObjNode* _Nullable ShowLapNum(short playerNum);
ObjNode* _Nullable ShowWinLose(short playerNum, Byte mode);

void HighlightInfobarEgg(int eggType);
