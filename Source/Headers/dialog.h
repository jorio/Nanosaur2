//
// dialog.h
//


#define	DEFAULT_DIALOG_ACTIVATE_DIST	300.0f

// DialogMessage is now a plain Swift enum in GameEnums.swift - nothing in C touches it, so it's no longer declared here.



void InitDialogManager(void);


void DoDialogMessage(int messNum, int priority, float duration, OGLPoint3D *fromWhere);
void DrawDialogMessage(void);


int CharToSprite(char c);
float GetCharSpacing(char c, float spacingScale);
