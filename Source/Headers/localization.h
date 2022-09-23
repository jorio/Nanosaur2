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

	NUM_LOCALIZED_STRINGS,
} LocStrID;

void LoadLocalizedStrings(GameLanguageID languageID);
void DisposeLocalizedStrings(void);

const char* Localize(LocStrID stringID);
int LocalizeWithPlaceholder(LocStrID stringID, char* buf, size_t bufSize, const char* format, ...);

GameLanguageID GetBestLanguageIDFromSystemLocale(void);
