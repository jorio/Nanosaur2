//
// infobar.h
//



void InitInfobar(void);
void DrawInfobar(ObjNode *theNode);
void DisposeInfobar(void);
void DrawInfobarSprite(float x, float y, float size, short texNum);
void DrawInfobarSprite2_Centered(float x, float y, float size, short group, short texNum);
void DrawInfobarSprite2(float x, float y, float size, short group, short texNum);
void DrawInfobarSprite3(float x, float y, float size, short texNum);
void DrawInfobarSprite3_Centered(float x, float y, float size, short texNum);
void DrawInfobarSprite_Centered(float x, float y, float size, short texNum);
void Infobar_DrawNumber(int number, float x, float y, float scale, int numDigits, Boolean showLeading);

void SetInfobarSpriteState(float anaglyphZ);

ObjNode* ShowLapNum(short playerNum);
ObjNode* ShowWinLose(short playerNum, Byte mode);

