#pragma once

typedef enum GameLanguageID
{
	LANGUAGE_ILLEGAL = -1,
	LANGUAGE_ENGLISH = 0,
	LANGUAGE_FRENCH,
	LANGUAGE_GERMAN,
	LANGUAGE_SPANISH,
	LANGUAGE_ITALIAN,
	LANGUAGE_SWEDISH,
	LANGUAGE_DUTCH,
	NUM_LANGUAGES
} GameLanguageID;

typedef enum LocStrID
{
	STR_NULL					= 0,

	STR_LANGUAGE_NAME,

	STR_ENGLISH,
	STR_FRENCH,
	STR_GERMAN,
	STR_SPANISH,
	STR_ITALIAN,
	STR_SWEDISH,
	STR_DUTCH,

	STR_BACK_SYMBOL,

	STR_PLAY_GAME,
	STR_SETTINGS,
	STR_INFO,
	STR_QUIT,

	STR_ADVENTURE,
	STR_NANO_VS_NANO,
	STR_SAVED_GAMES,
	STR_STORY,

	STR_CREDITS,
	STR_PANGEA_WEBSITE,
	STR_3D_GLASSES,

	STR_RACE1,
	STR_RACE2,
	STR_BATTLE1,
	STR_BATTLE2,
	STR_CAPTURE1,
	STR_CAPTURE2,

	STR_RESUME,
	STR_END,

	NUM_LOCALIZED_STRINGS,
} LocStrID;

void LoadLocalizedStrings(GameLanguageID languageID);
void DisposeLocalizedStrings(void);

const char* Localize(LocStrID stringID);
int LocalizeWithPlaceholder(LocStrID stringID, char* buf, size_t bufSize, const char* format, ...);

GameLanguageID GetBestLanguageIDFromSystemLocale(void);
