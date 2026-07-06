#---------------------------------------------------------------------------------
# ports/3DS -- Nintendo 3DS port of Nanosaur 2, built with Embedded Swift.
#
# THIS IS A MINIMAL BOOT SMOKE TEST, not the real game (see
# ../../docs/3DS_PORT_PLAN.md, Phase 2). It exists to prove the toolchain/
# link pipeline works: the ARM11 binary is just source/main.swift + citro2d/
# citro3d, targeting armv6-none-none-eabi (the 3DS's ARM11/ARM946E-S
# application CPU is an ARMv6K core), linked against libctru+citro2d+citro3d,
# and packaged as a homebrew .3dsx with 3dsxtool/smdhtool - modeled on
# junkbot-swift's ports/3DS/Makefile
# (https://github.com/colemancda/junkbot-swift/tree/main/ports/3DS), minus
# that project's asset-generation steps (nothing to embed yet) and its
# CORE_SWIFT engine sources (Nanosaur2's engine is pervasively SDL3/Pomme
# typed, unlike junkbot-swift's already-portable JunkbotCore, so wiring it in
# is a separate, larger follow-up pass - see the plan doc).
#
# Prerequisites:
#   - devkitPro with devkitARM and libctru+citro2d+citro3d
#     (`dkp-pacman -S 3ds-dev`; export DEVKITPRO=/opt/devkitpro,
#     DEVKITARM=$DEVKITPRO/devkitARM)
#   - 3dsxtool and smdhtool (part of devkitPro's 3ds-tools/general-tools,
#     normally installed alongside 3ds-dev to $(DEVKITPRO)/tools/bin)
#   - A Swift toolchain whose Embedded stdlib ships an armv6-none-none-eabi
#     slice (release toolchains as of 6.3.2+ already do).
#---------------------------------------------------------------------------------
.SUFFIXES:

ifeq ($(strip $(DEVKITPRO)),)
$(error "Please set DEVKITPRO in your environment. export DEVKITPRO=<path to>devkitpro")
endif
ifeq ($(strip $(DEVKITARM)),)
$(error "Please set DEVKITARM in your environment. export DEVKITARM=$$DEVKITPRO/devkitARM")
endif

SWIFTC		?=	swiftc

TARGET		:=	Nanosaur2
BUILD		:=	build
COMMON		:=	common/

# Override with `make CTRULIB=/path/to/libctru` to point at a libctru build
# that isn't installed under $(DEVKITPRO) (e.g. a local build/prefix).
CTRULIB		?=	$(DEVKITPRO)/libctru

PREFIX		:=	$(DEVKITARM)/bin/arm-none-eabi-
CC		:=	$(PREFIX)gcc
CXX		:=	$(PREFIX)g++
# Linking with g++ (not gcc) once Pomme's C++ file-manager objects are in
# OFILES - g++ pulls in libstdc++/libsupc++ needed by std::filesystem/
# iostream/exceptions, which plain gcc linking wouldn't add automatically.
LD		:=	$(PREFIX)g++

# devkitPro's 3ds-tools (3dsxtool, smdhtool) install to $(DEVKITPRO)/tools/bin,
# which a standard devkitPro environment already has on PATH.
3DSXTOOL	?=	3dsxtool
SMDHTOOL	?=	smdhtool
ICON		:=	$(CTRULIB)/default_icon.png

#---------------------------------------------------------------------------------
# code generation -- the 3DS's ARM11 application CPU, armv6k/mpcore, hard float.
#---------------------------------------------------------------------------------
ARCH		:=	-march=armv6k -mtune=mpcore -mfloat-abi=hard -mtp=soft

CTRUDEFS	:=	-D__3DS__ -I$(COMMON) -I$(CTRULIB)/include

CFLAGS		:=	-g -Wall -O2 -mword-relocations -ffunction-sections -fdata-sections \
			$(ARCH) $(CTRUDEFS)

BIN2S		?=	bin2s

#---------------------------------------------------------------------------------
# Real SDL3 (vendor/SDL3, see its VENDORED.md) - the official upstream 3DS
# backend (src/video|audio|joystick/n3ds), built from libsdl-org/SDL via
# devkitPro's own $DEVKITPRO/cmake/3DS.cmake toolchain file. Replaces this
# project's own hand-rolled common/SDL3/SDL.h stub + sdlcompat.c (deleted -
# every function in it duplicated something real SDL3 already implements,
# which would now be a duplicate-symbol link error) for events/audio/
# joystick/timers/locale. Software rendering only (no GPU/OpenGL from SDL3
# itself) - common/SDL3/SDL_opengl.h still forwards to picaGL for that, not
# real SDL3's own copy of that header.
#---------------------------------------------------------------------------------
SDL3_INCLUDE	:=	vendor/SDL3/include/
SDL3_LIB	:=	vendor/SDL3/lib/

LDFLAGS		:=	-specs=3dsx.specs -g $(ARCH) \
			-Wl,-Map,$(TARGET).map -Wl,--gc-sections \
			-L$(CTRULIB)/lib -L$(SDL3_LIB)

LIBS		:=	-lSDL3 -lctru -lm

#---------------------------------------------------------------------------------
# picaGL (vendor/picaGL, see its VENDORED.md) - a real OpenGL 1.x-style
# implementation for the PICA200 GPU (talks to the GPU command queue
# directly, not citro3d/citro2d - so those libs aren't linked here at all).
# Backs SDL3/SDL_opengl.h's real <GL/gl.h> forward and PlatformBackend.swift's
# CTRUGraphicsBackend (via picaGL_shim.c). Its own vertex shader
# (vendor/picaGL/source/shaders/vshader.v.pica + clear.v.pica) needs the
# same picasso -> bin2s -> .o pipeline as any PICA200 shader.
#---------------------------------------------------------------------------------
PICAGL		:=	vendor/picaGL/
PICAGL_SOURCE	:=	$(PICAGL)source/
PICAGL_UTILS	:=	$(PICAGL)source/utils/
PICAGL_SHADERS	:=	$(PICAGL)source/shaders/
PICAGL_INCLUDE	:=	$(PICAGL)include/

# Kept as two separate lists (not one `source/**/*.c` glob) - source/ and
# source/utils/ need distinct pattern rules below, and source/'s pattern
# would otherwise ambiguously also match source/utils/*.c (it's a prefix
# of that path), producing wrongly-named objects like
# `picagl_utils/hashtable.o` (with the literal "utils/" in the name,
# breaking the build - hit this exact bug when this was one combined list).
PICAGL_MAIN_CFILES  := $(wildcard $(PICAGL_SOURCE)*.c)
PICAGL_UTILS_CFILES := $(wildcard $(PICAGL_UTILS)*.c)
PICAGL_OFILES	:=	$(patsubst $(PICAGL_SOURCE)%.c,$(BUILD)/picagl_%.o,$(PICAGL_MAIN_CFILES)) \
			$(patsubst $(PICAGL_UTILS)%.c,$(BUILD)/picagl_%.o,$(PICAGL_UTILS_CFILES))
PICAGL_SHADER_OFILES := $(BUILD)/picagl_vshader_shbin.o $(BUILD)/picagl_clear_shbin.o


#---------------------------------------------------------------------------------
# Real-engine paths. game_3ds.h (see common/) is the 3DS-specific substitute
# for Source/Headers/game.h + Nanosaur2-Bridging-Header.h - see its header
# comment and docs/3DS_PORT_PLAN.md, Phase 2.
#---------------------------------------------------------------------------------
ENGINE_ROOT	:=	../..
ENGINE_SOURCE	:=	$(ENGINE_ROOT)/Source
POMME_SOURCE	:=	$(ENGINE_ROOT)/extern/Pomme/src

#---------------------------------------------------------------------------------
# Pomme's real file/resource-manager C++ implementation (milestone step 4,
# File I/O) - compile-tested directly against this toolchain, confirmed to
# compile+link with just a C++ standard bump (c++17 -> c++20, for
# PommeSound.h's std::span - needed even though sound itself is compiled
# out below, since Pomme.cpp's top-level Pomme.h include still parses that
# header). Built with -DPOMME_NO_GRAPHICS -DPOMME_NO_SOUND_FORMATS
# -DPOMME_NO_SOUND_MIXER -DPOMME_NO_INPUT so Pomme::Init() (in
# ports/3DS/common/pomme_shim.cpp) only bootstraps the file layer -
# graphics/sound/input on 3DS go through picaGL/PlatformBackend.swift's own
# conformances instead, not Pomme's SDL-backed equivalents for those.
# Explicit per-file rules below (not a pattern rule) - a pattern rule over
# multiple source directories with only-sometimes-unique basenames is
# exactly what broke picaGL's Makefile wiring earlier (see PICAGL_OFILES's
# comment); not worth risking again for just 11 files.
#---------------------------------------------------------------------------------
POMME_DEFS	:=	-DPOMME_NO_GRAPHICS -DPOMME_NO_SOUND_FORMATS -DPOMME_NO_SOUND_MIXER -DPOMME_NO_INPUT

#---------------------------------------------------------------------------------
# Embedded Swift flags, targeting armv6-none-none-eabi.
#---------------------------------------------------------------------------------
SWIFTFLAGS	:=	-target armv6-none-none-eabi \
			-enable-experimental-feature Embedded \
			-wmo -Osize \
			-module-name Nanosaur2 \
			-DNANOSAUR_3DS \
			-import-objc-header $(COMMON)game_3ds.h \
			-Xcc -D__3DS__ \
			-Xcc -march=armv6k -Xcc -mtune=mpcore -Xcc -mfloat-abi=hard \
			-Xcc -isystem -Xcc $(DEVKITARM)/arm-none-eabi/include \
			-Xcc -I$(COMMON) \
			-Xcc -I$(CTRULIB)/include \
			-Xcc -I$(POMME_SOURCE) \
			-Xcc -I$(ENGINE_SOURCE)/Headers \
			-Xcc -I$(PICAGL_INCLUDE) \
			-Xcc -I$(SDL3_INCLUDE) \
			-Xcc -fmodule-map-file=$(COMMON)module.modulemap

#---------------------------------------------------------------------------------
# Sources: the minimal boot smoke test (source/*.swift) plus real engine
# files being wired in one at a time as they're proven to compile+link for
# 3DS (see docs/3DS_PORT_PLAN.md, Phase 2 "first real engine file linked").
# Add to ENGINE_SWIFT as more files are confirmed to work, in the same
# incremental spirit.
#
# As of the "GL-compat shim"/"SDL-compat shim" updates in the port plan,
# the ENTIRE real engine (all Source/**/*.swift, not just this curated
# subset) compile-checks cleanly against game_3ds.h and even compiles as a
# whole into one real linkable object (verified via an ad hoc `swiftc -c`
# invocation covering every file, not this Makefile) - but LINKING the
# whole thing fails: the engine's C side (bg3d.c, main.c, and every other
# still-unported .c file, plus Pomme's own C++ runtime) isn't part of this
# Makefile at all, so the real gGamePrefs/DoFatalAlert/SndDoImmediate/etc.
# symbols Swift calls into don't exist yet to link against. Bringing that
# in is real, separate follow-up work (milestone steps 4/6 - File/Sound),
# not something to flip on by widening this list - hence still a curated
# subset here, not `find`, so `make` keeps producing a working `.3dsx`.
#---------------------------------------------------------------------------------
PORT_SWIFT	:=	$(wildcard source/*.swift)
ENGINE_SWIFT	:=	$(ENGINE_SOURCE)/3D/OGLTypes.swift \
			$(ENGINE_SOURCE)/System/GameEnums.swift \
			$(ENGINE_SOURCE)/System/SwiftEnumExtensions.swift \
			$(ENGINE_SOURCE)/System/MenuItemExtensions.swift \
			$(ENGINE_SOURCE)/System/EmbeddedMath.swift

OFILES		:=	$(BUILD)/nanosaur2.swift.o $(BUILD)/shim.o $(BUILD)/picaGL_shim.o \
			$(BUILD)/romfs_shim.o $(BUILD)/pomme_shim.o \
			$(BUILD)/pomme_Files.o $(BUILD)/pomme_HostVolume.o $(BUILD)/pomme_Resources.o \
			$(BUILD)/pomme_Memory.o $(BUILD)/pomme_Pomme.o $(BUILD)/pomme_PommeDebug.o \
			$(BUILD)/pomme_StringUtils.o $(BUILD)/pomme_bigendianstreams.o \
			$(BUILD)/pomme_memstream.o $(BUILD)/pomme_structpack.o $(BUILD)/pomme_IEEEExtended.o \
			$(PICAGL_OFILES) $(PICAGL_SHADER_OFILES)

#---------------------------------------------------------------------------------
.PHONY: all clean

all: $(TARGET).3dsx

$(BUILD):
	@mkdir -p $@

# All Swift (port smoke-test files + wired-in real engine files) -> one
# object, whole-module.
$(BUILD)/nanosaur2.swift.o: $(PORT_SWIFT) $(ENGINE_SWIFT) $(COMMON)module.modulemap $(COMMON)ctru_umbrella.h $(COMMON)game_3ds.h | $(BUILD)
	@echo compiling Swift
	$(SWIFTC) $(SWIFTFLAGS) -c $(PORT_SWIFT) $(ENGINE_SWIFT) -o $@

$(BUILD)/shim.o: $(COMMON)shim.c $(COMMON)shim.h | $(BUILD)
	@echo $(notdir $<)
	$(CC) $(CFLAGS) -c $< -o $@

$(BUILD)/picaGL_shim.o: $(COMMON)picaGL_shim.c $(COMMON)picaGL_shim.h | $(BUILD)
	@echo $(notdir $<)
	$(CC) $(CFLAGS) -I$(COMMON) -I$(PICAGL_INCLUDE) -c $< -o $@

$(BUILD)/romfs_shim.o: $(COMMON)romfs_shim.c $(COMMON)romfs_shim.h | $(BUILD)
	@echo $(notdir $<)
	$(CC) $(CFLAGS) -I$(COMMON) -c $< -o $@

#---------------------------------------------------------------------------------
# Pomme's real file/resource-manager C++ implementation - see this file's
# earlier POMME_FILES_CFILES comment. -std=c++20 (not c++17) because
# PommeSound.h uses std::span, even with sound compiled out via
# POMME_DEFS - Pomme.h's own top-level include still parses that header.
#---------------------------------------------------------------------------------
POMME_CXXFLAGS := -g -Wall -O2 -mword-relocations -ffunction-sections -fdata-sections \
			$(ARCH) -D__3DS__ -std=c++20 $(POMME_DEFS) -I$(POMME_SOURCE)

$(BUILD)/pomme_shim.o: $(COMMON)pomme_shim.cpp | $(BUILD)
	@echo $(notdir $<)
	$(CXX) $(POMME_CXXFLAGS) -c $< -o $@

$(BUILD)/pomme_Files.o: $(POMME_SOURCE)/Files/Files.cpp | $(BUILD)
	@echo $(notdir $<)
	$(CXX) $(POMME_CXXFLAGS) -c $< -o $@

$(BUILD)/pomme_HostVolume.o: $(POMME_SOURCE)/Files/HostVolume.cpp | $(BUILD)
	@echo $(notdir $<)
	$(CXX) $(POMME_CXXFLAGS) -c $< -o $@

$(BUILD)/pomme_Resources.o: $(POMME_SOURCE)/Files/Resources.cpp | $(BUILD)
	@echo $(notdir $<)
	$(CXX) $(POMME_CXXFLAGS) -c $< -o $@

$(BUILD)/pomme_Memory.o: $(POMME_SOURCE)/Memory/Memory.cpp | $(BUILD)
	@echo $(notdir $<)
	$(CXX) $(POMME_CXXFLAGS) -c $< -o $@

$(BUILD)/pomme_Pomme.o: $(POMME_SOURCE)/Pomme.cpp | $(BUILD)
	@echo $(notdir $<)
	$(CXX) $(POMME_CXXFLAGS) -c $< -o $@

$(BUILD)/pomme_PommeDebug.o: $(POMME_SOURCE)/PommeDebug.cpp | $(BUILD)
	@echo $(notdir $<)
	$(CXX) $(POMME_CXXFLAGS) -c $< -o $@

$(BUILD)/pomme_StringUtils.o: $(POMME_SOURCE)/Utilities/StringUtils.cpp | $(BUILD)
	@echo $(notdir $<)
	$(CXX) $(POMME_CXXFLAGS) -c $< -o $@

$(BUILD)/pomme_bigendianstreams.o: $(POMME_SOURCE)/Utilities/bigendianstreams.cpp | $(BUILD)
	@echo $(notdir $<)
	$(CXX) $(POMME_CXXFLAGS) -c $< -o $@

$(BUILD)/pomme_memstream.o: $(POMME_SOURCE)/Utilities/memstream.cpp | $(BUILD)
	@echo $(notdir $<)
	$(CXX) $(POMME_CXXFLAGS) -c $< -o $@

$(BUILD)/pomme_structpack.o: $(POMME_SOURCE)/Utilities/structpack.cpp | $(BUILD)
	@echo $(notdir $<)
	$(CXX) $(POMME_CXXFLAGS) -c $< -o $@

$(BUILD)/pomme_IEEEExtended.o: $(POMME_SOURCE)/Utilities/IEEEExtended.cpp | $(BUILD)
	@echo $(notdir $<)
	$(CXX) $(POMME_CXXFLAGS) -c $< -o $@

#---------------------------------------------------------------------------------
# picaGL: its own vertex/clear shaders (picasso -> bin2s -> .o, same
# pipeline as any PICA200 shader - see the earlier version of this
# Makefile's now-removed glcompat shader rules for the from-scratch
# explanation), then its C sources (need the shaders' generated headers,
# per state.c's own #include "vshader_shbin.h"/"clear_shbin.h").
#---------------------------------------------------------------------------------
# state.c does `#include "vshader_shbin.h"`/`"clear_shbin.h"` (unprefixed -
# it's vendored code, not patched to match this Makefile's picagl_ naming
# convention for its .o files). bin2s derives the byte-array symbol names
# (vshader_shbin/vshader_shbin_size) from the .shbin file's own name, so
# that file (not just the header) must be named unprefixed too, or the
# symbols wouldn't match what state.c references.
$(BUILD)/vshader_shbin.h $(BUILD)/picagl_vshader_shbin.s: $(PICAGL_SHADERS)vshader.v.pica | $(BUILD)
	@echo $(notdir $<)
	picasso -o $(BUILD)/vshader.shbin -h $(BUILD)/vshader_shbin.h $<
	$(BIN2S) -a 4 -H $(BUILD)/vshader_shbin.h $(BUILD)/vshader.shbin > $(BUILD)/picagl_vshader_shbin.s

$(BUILD)/clear_shbin.h $(BUILD)/picagl_clear_shbin.s: $(PICAGL_SHADERS)clear.v.pica | $(BUILD)
	@echo $(notdir $<)
	picasso -o $(BUILD)/clear.shbin -h $(BUILD)/clear_shbin.h $<
	$(BIN2S) -a 4 -H $(BUILD)/clear_shbin.h $(BUILD)/clear.shbin > $(BUILD)/picagl_clear_shbin.s

$(BUILD)/picagl_vshader_shbin.o: $(BUILD)/picagl_vshader_shbin.s
	$(CC) -x assembler-with-cpp $(CFLAGS) -c $< -o $@

$(BUILD)/picagl_clear_shbin.o: $(BUILD)/picagl_clear_shbin.s
	$(CC) -x assembler-with-cpp $(CFLAGS) -c $< -o $@

# picaGL still uses its original -DARM11 -D_3DS defines (not __3DS__) -
# kept as-is rather than patched, since it's vendored code (see VENDORED.md).
$(BUILD)/picagl_%.o: $(PICAGL_SOURCE)%.c $(BUILD)/vshader_shbin.h $(BUILD)/clear_shbin.h | $(BUILD)
	@echo $(notdir $<)
	$(CC) $(CFLAGS) -DARM11 -D_3DS -I$(PICAGL_INCLUDE) -I$(PICAGL_SOURCE) -I$(BUILD) -c $< -o $@

$(BUILD)/picagl_%.o: $(PICAGL_UTILS)%.c | $(BUILD)
	@echo $(notdir $<)
	$(CC) $(CFLAGS) -DARM11 -D_3DS -I$(PICAGL_INCLUDE) -I$(PICAGL_SOURCE) -c $< -o $@

$(TARGET).elf: $(OFILES)
	@echo linking $(notdir $@)
	$(LD) $(LDFLAGS) $(OFILES) $(LIBS) -o $@

$(BUILD)/icon.smdh: | $(BUILD)
	@echo packaging icon
	$(SMDHTOOL) --create Nanosaur2 "Nanosaur 2 (swift-3ds)" "nanosaur2-swift" $(ICON) $@

$(TARGET).3dsx: $(TARGET).elf $(BUILD)/icon.smdh
	@echo packaging $(notdir $@)
	$(3DSXTOOL) $(TARGET).elf $@ --smdh=$(BUILD)/icon.smdh

clean:
	@echo clean ...
	@rm -fr $(BUILD) $(TARGET).elf $(TARGET).3dsx $(TARGET).map
