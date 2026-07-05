// NANOSAUR 2 ENTRY POINT
// (C) 2025 Iliyas Jorio
// This file is part of Nanosaur 2. https://github.com/jorio/nanosaur2

#include <cstring>

#include <SDL3/SDL.h>
#include <SDL3/SDL_main.h>

#include "Pomme.h"
#include "PommeInit.h"
#include "PommeFiles.h"

extern "C"
{
	#include "game.h"

	SDL_Window* gSDLWindow = nullptr;
	SDL_Window* gSDLWindow2 = nullptr;
	Boolean gDualScreenMode = false;
	FSSpec gDataSpec;
	int gCurrentAntialiasingLevel;
}

static fs::path FindGameData(const char* executablePath)
{
	fs::path dataPath;

	int attemptNum = 0;

#if !(__APPLE__)
	attemptNum++;		// skip macOS special case #0
#endif

	if (!executablePath)
		attemptNum = 2;

tryAgain:
	switch (attemptNum)
	{
		case 0:			// special case for macOS app bundles
			dataPath = executablePath;
			dataPath = dataPath.parent_path().parent_path() / "Resources";
			break;

		case 1:
			dataPath = executablePath;
			dataPath = dataPath.parent_path() / "Data";
			break;

		case 2:
			dataPath = "Data";
			break;

		default:
			throw std::runtime_error("Couldn't find the Data folder.");
	}

	attemptNum++;

	dataPath = dataPath.lexically_normal();

	// Set data spec -- Lets the game know where to find its asset files
	gDataSpec = Pomme::Files::HostPathToFSSpec(dataPath / "System");

	FSSpec someDataFileSpec;
	OSErr iErr = FSMakeFSSpec(gDataSpec.vRefNum, gDataSpec.parID, ":System:gamecontrollerdb.txt", &someDataFileSpec);
	if (iErr)
	{
		goto tryAgain;
	}

	return dataPath;
}

static void Boot(int argc, char** argv)
{
	SDL_SetAppMetadata(GAME_FULL_NAME, GAME_VERSION, GAME_IDENTIFIER);
#if _DEBUG
	SDL_SetLogPriorities(SDL_LOG_PRIORITY_VERBOSE);
#else
	SDL_SetLogPriorities(SDL_LOG_PRIORITY_INFO);
#endif

	// Start our "machine"
	Pomme::Init();

	// Scan command-line flags
	for (int i = 1; i < argc; i++)
	{
		if (0 == strcmp(argv[i], "--dual-screen"))
		{
			gDualScreenMode = true;
		}
	}

	// Find path to game data folder
	const char* executablePath = argc > 0 ? argv[0] : NULL;
	fs::path dataPath = FindGameData(executablePath);

	// Load game prefs before starting
	LoadPrefs();

retryVideo:
	// Initialize SDL video subsystem
	if (!SDL_Init(SDL_INIT_VIDEO))
	{
		throw std::runtime_error("Couldn't initialize SDL video subsystem.");
	}

	// Create window
	SDL_GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, SDL_GL_CONTEXT_PROFILE_COMPATIBILITY);
	SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 2);
	SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 0);

	gCurrentAntialiasingLevel = gGamePrefs.antialiasingLevel;
	if (gCurrentAntialiasingLevel != 0)
	{
		SDL_GL_SetAttribute(SDL_GL_MULTISAMPLEBUFFERS, 1);
		SDL_GL_SetAttribute(SDL_GL_MULTISAMPLESAMPLES, 1 << gCurrentAntialiasingLevel);
	}

	gSDLWindow = SDL_CreateWindow(
		GAME_FULL_NAME " (" GAME_VERSION ")", 640, 480,
		SDL_WINDOW_OPENGL | SDL_WINDOW_RESIZABLE | SDL_WINDOW_HIGH_PIXEL_DENSITY);

	if (!gSDLWindow)
	{
		if (gCurrentAntialiasingLevel != 0)
		{
			SDL_Log("Couldn't create SDL window with the requested MSAA level. Retrying without MSAA...");

			// retry without MSAA
			gGamePrefs.antialiasingLevel = 0;
			SDL_QuitSubSystem(SDL_INIT_VIDEO);
			goto retryVideo;
		}
		else
		{
			throw std::runtime_error("Couldn't create SDL window.");
		}
	}

	// If dual-screen mode was requested, set up a second window for the
	// bottom screen (menus/HUD), and place both windows appropriately:
	// on real dual-screen hardware (2+ displays reported), one fullscreen
	// window per physical display; otherwise (dev machine, 1 display),
	// two regular windows stacked vertically so the mode is still testable.
	if (gDualScreenMode)
	{
		gSDLWindow2 = SDL_CreateWindow(
			GAME_FULL_NAME " (" GAME_VERSION ") - Bottom Screen", 640, 480,
			SDL_WINDOW_OPENGL | SDL_WINDOW_RESIZABLE | SDL_WINDOW_HIGH_PIXEL_DENSITY);

		if (!gSDLWindow2)
		{
			throw std::runtime_error("Couldn't create second SDL window for dual-screen mode.");
		}

		int numDisplays = 0;
		SDL_DisplayID* displays = SDL_GetDisplays(&numDisplays);

		SDL_Rect topBounds, bottomBounds;
		bool haveTwoDisplays = displays != nullptr
			&& numDisplays >= 2
			&& SDL_GetDisplayBounds(displays[0], &topBounds)
			&& SDL_GetDisplayBounds(displays[1], &bottomBounds);

		if (haveTwoDisplays)
		{
			// Real dual-screen hardware: one fullscreen window per physical display.
			SDL_SetWindowPosition(gSDLWindow, topBounds.x, topBounds.y);
			SDL_SetWindowFullscreen(gSDLWindow, true);
			SDL_SyncWindow(gSDLWindow);

			SDL_SetWindowPosition(gSDLWindow2, bottomBounds.x, bottomBounds.y);
			SDL_SetWindowFullscreen(gSDLWindow2, true);
			SDL_SyncWindow(gSDLWindow2);
		}
		else
		{
			// Dev machine with a single display: stack both windows vertically.
			int topX = 0, topY = 0, topW = 640, topH = 480;
			SDL_GetWindowPosition(gSDLWindow, &topX, &topY);
			SDL_GetWindowSize(gSDLWindow, &topW, &topH);
			SDL_SetWindowPosition(gSDLWindow2, topX, topY + topH + 40);
		}

		if (displays)
		{
			SDL_free(displays);
		}
	}

	// Init gamepad subsystem
	SDL_Init(SDL_INIT_GAMEPAD);
	auto gamecontrollerdbPath8 = (dataPath / "System" / "gamecontrollerdb.txt").u8string();
	if (-1 == SDL_AddGamepadMappingsFromFile((const char*)gamecontrollerdbPath8.c_str()))
	{
		SDL_ShowSimpleMessageBox(SDL_MESSAGEBOX_WARNING, GAME_FULL_NAME, "Couldn't load gamecontrollerdb.txt!", gSDLWindow);
	}
}

static void Shutdown()
{
	// Always restore the user's mouse acceleration before exiting.
	SetMacLinearMouse(false);

	Pomme::Shutdown();

	if (gSDLWindow2)
	{
		SDL_DestroyWindow(gSDLWindow2);
		gSDLWindow2 = NULL;
	}

	if (gSDLWindow)
	{
		SDL_DestroyWindow(gSDLWindow);
		gSDLWindow = NULL;
	}

	SDL_Quit();
}

int main(int argc, char** argv)
{
	bool success = true;
	std::string uncaught = "";

	try
	{
		Boot(argc, argv);
		GameMain();
	}
	catch (Pomme::QuitRequest&)
	{
		// no-op, the game may throw this exception to shut us down cleanly
	}
#if !(_DEBUG)
	// In release builds, catch anything that might be thrown by GameMain
	// so we can show an error dialog to the user.
	catch (std::exception& ex)		// Last-resort catch
	{
		success = false;
		uncaught = ex.what();
	}
	catch (...)						// Last-resort catch
	{
		success = false;
		uncaught = "unknown";
	}
#endif

	Shutdown();

	if (!success)
	{
		SDL_LogError(SDL_LOG_CATEGORY_APPLICATION, "Uncaught exception: %s", uncaught.c_str());
		SDL_ShowSimpleMessageBox(0, GAME_FULL_NAME, uncaught.c_str(), nullptr);
	}

	return success ? 0 : 1;
}
