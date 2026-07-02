// LOCALIZATION.C
// (C) 2025 Iliyas Jorio
// This file is part of Nanosaur 2. https://github.com/jorio/nanosaur2

// LoadLocalizedStrings/Localize/DisposeLocalizedStrings are now in
// Localization.swift. LocalizeWithPlaceholder stays here because it takes
// C variadic arguments, which Swift can't implement. IsNativeEnglishSystem
// and GetBestLanguageIDFromSystemLocale also stay here since they consume
// kLanguageCodesISO639_1, a 2D fixed char array.

#include "game.h"

static const char kLanguageCodesISO639_1[NUM_LANGUAGES][3] =
{
	[LANGUAGE_ENGLISH	] = "en",
	[LANGUAGE_FRENCH	] = "fr",
	[LANGUAGE_GERMAN	] = "de",
	[LANGUAGE_SPANISH	] = "es",
	[LANGUAGE_ITALIAN	] = "it",
	[LANGUAGE_SWEDISH	] = "sv",
	[LANGUAGE_DUTCH		] = "nl",
	[LANGUAGE_RUSSIAN	] = "ru",
};

int LocalizeWithPlaceholder(LocStrID stringID, char* buf0, size_t bufSize, const char* format, ...)
{
	char* buf = buf0;
	const char* localizedString = Localize(stringID);

	const char* placeholder = SDL_strchr(localizedString, '#');

	if (!placeholder)
	{
		goto fail;
	}

	size_t bytesBeforePlaceholder = placeholder - localizedString;

	if (bytesBeforePlaceholder + 1 >= bufSize)		// +1 for nul terminator
	{
		goto fail;
	}

	SDL_memcpy(buf, localizedString, bytesBeforePlaceholder);
	buf += bytesBeforePlaceholder;
	bufSize -= bytesBeforePlaceholder;

	va_list args;
	va_start(args, format);
	int rc = SDL_vsnprintf(buf, bufSize, format, args);
	va_end(args);

	if (rc >= 0)
	{
		buf += rc;
		bufSize -= rc;

		rc = SDL_snprintf(buf, bufSize, "%s", placeholder + 1);
		if (rc >= 0)
		{
			buf += rc;
			bufSize -= rc;
		}
	}

	return (int) (buf - buf0);

fail:
	return SDL_snprintf(buf, bufSize, "%s", localizedString);
}

bool IsNativeEnglishSystem(void)
{
	bool prefersEnglish = true;

	int numLocales = 0;
	SDL_Locale** localeList = SDL_GetPreferredLocales(&numLocales);

	if (NULL != localeList
		&& 0 != localeList[0]->language
		&& (0 != strncmp(localeList[0]->language, kLanguageCodesISO639_1[LANGUAGE_ENGLISH], 2)))
	{
		prefersEnglish = false;
	}

	SDL_free(localeList);

	return prefersEnglish;
}

GameLanguageID GetBestLanguageIDFromSystemLocale(void)
{
	GameLanguageID languageID = LANGUAGE_ENGLISH;

	int numLocales = 0;
	SDL_Locale** localeList = SDL_GetPreferredLocales(&numLocales);

	for (int locale = 0; locale < numLocales; locale++)
	{
		const char* localeLanguage = localeList[locale]->language;

		for (int language = 0; language < NUM_LANGUAGES; language++)
		{
			if (0 == SDL_strncmp(localeLanguage, kLanguageCodesISO639_1[language], 2))
			{
				languageID = language;
				goto foundLocale;
			}
		}
	}

foundLocale:
	SDL_free(localeList);

	return languageID;
}
