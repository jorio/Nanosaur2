// NANOSAUR 2 ENTRY POINT
// (C) 2025 Iliyas Jorio
// This file is part of Nanosaur 2. https://github.com/jorio/nanosaur2

#include <cstring>

// Not std::filesystem: this project's CMAKE_OSX_DEPLOYMENT_TARGET (10.13,
// synced with SDL3's own minimum) predates std::filesystem's macOS 10.15
// availability, which the SDK enforces as a hard compile error. ghc::filesystem
// (vendored under extern/ghc-filesystem, MIT-licensed) is a pure-userspace
// implementation with no such requirement - this is exactly what Pomme used
// to use for the same reason (see its CompilerSupport/filesystem.h).
#include "filesystem.hpp"

#include <SDL3/SDL.h>
#include <SDL3/SDL_main.h>

namespace fs = ghc::filesystem;

extern "C"
{
	// gSDLWindow/gSDLWindow2/gDualScreenMode/gDataSpec/gCurrentAntialiasingLevel
	// are now defined in BootGlobals.c (see that file for why).
	#include "game.h"
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
	gDataSpec = SwHostPathToFSSpec((const char*)(dataPath / "System").u8string().c_str());

	FSSpec someDataFileSpec;
	OSErr iErr = SwFSMakeFSSpec(gDataSpec.vRefNum, gDataSpec.parID, ":System:gamecontrollerdb.txt", &someDataFileSpec);
	if (iErr)
	{
		goto tryAgain;
	}

	return dataPath;
}

// Phase 0 Metal spike (docs/metal-renderer-plan.md): `--metal-spike`
// bypasses the normal GL boot/game path entirely and just proves SDL's
// Metal layer -> MetalRenderer module -> on-screen present path works.
// Deliberately kept isolated from Boot()/GameMain() and gSDLWindow's usual
// GL setup so this throwaway spike can't affect the real (still GL)
// rendering path. Superseded by `--metal` (see SwMetalBackend_Activate() in
// main()) for actually rendering the game via Metal, but kept around as a
// minimal regression check for the SDL-layer -> Metal present path in
// isolation.
static int RunMetalSpike()
{
	SDL_SetAppMetadata(GAME_FULL_NAME, GAME_VERSION, GAME_IDENTIFIER);
	SDL_SetLogPriorities(SDL_LOG_PRIORITY_VERBOSE);

	if (!SDL_Init(SDL_INIT_VIDEO))
	{
		SDL_LogError(SDL_LOG_CATEGORY_APPLICATION, "SDL_Init failed: %s", SDL_GetError());
		return 1;
	}

	// No SDL_WINDOW_OPENGL here -- SDL_Metal_CreateView wants a window that
	// wasn't set up for GL. gSDLWindow is reused (rather than a local
	// variable) purely because SwMetalSpike_Init() (MetalSpike.swift) reads
	// that existing global; nothing else in this spike path touches it.
	gSDLWindow = SDL_CreateWindow(
		GAME_FULL_NAME " (" GAME_VERSION ") - Metal Spike", 640, 480,
		SDL_WINDOW_METAL | SDL_WINDOW_RESIZABLE | SDL_WINDOW_HIGH_PIXEL_DENSITY);

	if (!gSDLWindow)
	{
		SDL_LogError(SDL_LOG_CATEGORY_APPLICATION, "Couldn't create Metal window: %s", SDL_GetError());
		return 1;
	}

	if (!SwMetalSpike_Init())
	{
		SDL_LogError(SDL_LOG_CATEGORY_APPLICATION, "SwMetalSpike_Init failed");
		return 1;
	}

	SDL_Log("Metal spike running -- close the window or press Escape to quit.");

	bool running = true;
	float hue = 0.0f;
	while (running)
	{
		SDL_Event event;
		while (SDL_PollEvent(&event))
		{
			if (event.type == SDL_EVENT_QUIT)
				running = false;
			else if (event.type == SDL_EVENT_KEY_DOWN && event.key.key == SDLK_ESCAPE)
				running = false;
		}

		// Cycle the clear colour every frame so it's visually obvious this is
		// a live Metal-rendered (not a static) frame.
		hue += 0.01f;
		if (hue > 1.0f)
			hue -= 1.0f;
		SwMetalSpike_ClearFrame(
			0.5f + 0.5f * SDL_sinf(hue * 6.28318f),
			0.5f + 0.5f * SDL_sinf(hue * 6.28318f + 2.09439f),
			0.5f + 0.5f * SDL_sinf(hue * 6.28318f + 4.18879f));
	}

	SwMetalSpike_Shutdown();
	SDL_DestroyWindow(gSDLWindow);
	gSDLWindow = NULL;
	SDL_Quit();
	return 0;
}

static void Boot(int argc, char** argv)
{
	SDL_SetAppMetadata(GAME_FULL_NAME, GAME_VERSION, GAME_IDENTIFIER);
#if _DEBUG
	SDL_SetLogPriorities(SDL_LOG_PRIORITY_VERBOSE);
#else
	SDL_SetLogPriorities(SDL_LOG_PRIORITY_INFO);
#endif

	// Scan command-line flags
	for (int i = 1; i < argc; i++)
	{
		if (0 == strcmp(argv[i], "--dual-screen"))
		{
			gDualScreenMode = true;
		}
		else if (0 == strcmp(argv[i], "--metal"))
		{
			gMetalMode = true;
		}
	}

	// Find path to game data folder
	const char* executablePath = argc > 0 ? argv[0] : NULL;
	fs::path dataPath = FindGameData(executablePath);

	// Load game prefs before starting
	LoadPrefs();

retryVideo:
	// Initialize SDL video subsystem. AUDIO used to be initialized
	// implicitly by Pomme::Init() (Sound::InitMixer) - now that Sound.swift
	// opens its own SDL_AudioStreams directly (SoundEngine.swift), this
	// needs to request it explicitly.
	if (!SDL_Init(SDL_INIT_VIDEO | SDL_INIT_AUDIO))
	{
		throw std::runtime_error("Couldn't initialize SDL video/audio subsystems.");
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

// Callable from Swift's SwExitToShell() (Misc.swift), which replaces
// Pomme's exception-based ExitToShell()/QuitRequest unwind - see
// SwExitToShell's own comment for why. CleanQuit() runs this before
// exiting the process so the mouse-acceleration restore and window
// teardown above still happen, matching what used to happen when the
// unwind reached here via main()'s own post-try/catch call to Shutdown().
extern "C" void SwPlatformShutdown()
{
	Shutdown();
}

int main(int argc, char** argv)
{
	// Phase 0 Metal spike (docs/metal-renderer-plan.md) -- takes over the
	// process entirely instead of going through the normal Boot()/GameMain()
	// GL path; see RunMetalSpike()'s comment for why. Kept behind its own
	// flag as a minimal regression check, separate from `--metal` (real
	// integration, handled below via gMetalMode).
	for (int i = 1; i < argc; i++)
	{
		if (0 == strcmp(argv[i], "--metal-spike"))
		{
			return RunMetalSpike();
		}
	}

	// Normal clean-quit path: CleanQuit() (Misc.swift) runs its own cleanup,
	// then SwExitToShell() calls Shutdown() and exits the process directly -
	// main() never regains control in that case (see SwExitToShell's
	// comment). What's left for main() to catch here is genuinely
	// unexpected termination (used to also include Pomme::QuitRequest, a
	// normal-quit signal thrown via exceptions - no longer needed now that
	// SwExitToShell() exits directly instead of unwinding the stack).
#if _DEBUG
	// In debug builds, don't catch anything so a debugger can break on an
	// uncaught exception.
	// Real Metal integration (docs/metal-renderer-plan.md Phase 2): activating
	// Metal (SwMetalBackend_Activate, called from OGL_CreateDrawContext once
	// the GL context exists - see that function's comment for why it must
	// come AFTER, not before) happens inside GameMain()'s normal screen
	// setup, not here. gMetalMode just carries the flag through to there.
	Boot(argc, argv);
	GameMain();
	Shutdown();
	return 0;
#else
	bool success = true;
	std::string uncaught = "";

	try
	{
		Boot(argc, argv);
		GameMain();
	}
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

	Shutdown();

	if (!success)
	{
		SDL_LogError(SDL_LOG_CATEGORY_APPLICATION, "Uncaught exception: %s", uncaught.c_str());
		SDL_ShowSimpleMessageBox(0, GAME_FULL_NAME, uncaught.c_str(), nullptr);
	}

	return success ? 0 : 1;
#endif
}
