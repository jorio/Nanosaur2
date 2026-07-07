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

# Embedded Swift's Unicode-support library (grapheme-cluster breaking,
# normalization, etc.) - needed the moment any String operation touches
# extended-grapheme-cluster logic, which this engine's ported Swift does
# constantly (e.g. `String(cString:)`). The toolchain ships a prebuilt copy
# for armv6-none-none-eabi, but it's soft-float ABI, while this whole
# project (like libctru itself) is hard-float - linking them together fails
# outright ("uses VFP register arguments, ... does not"). Recompiled from
# upstream Swift source with the right ABI instead - see
# vendor/swiftUnicodeDataTables/VENDORED.md for how/why.
SWIFT_UNICODE_DATA_TABLES_LIBDIR := vendor/swiftUnicodeDataTables

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
#
# -fno-pic -fno-pie matter a lot more than they look: without them, Swift's
# codegen for this target emits thousands of R_ARM_GOT_PREL/R_ARM_TLS_LE32/
# R_ARM_TLS_LDO32 relocations (2747 GOT_PREL alone, found in
# nanosaur2.swift.o via `arm-none-eabi-readelf -r`) that the .3dsx format's
# relocation converter (3dsxtool) doesn't understand and silently drops -
# not an error, just corrupted code at those addresses. This is why an
# earlier build linked with zero errors/warnings about it, produced a
# well-formed .3dsx (right magic bytes, sane header, correct file size),
# and still failed to even launch in an emulator - the file format was
# fine, the machine code inside wasn't. Confirmed fixed by recompiling and
# checking relocation types dropped to zero GOT_PREL/TLS_LE32/TLS_LDO32
# (a few R_ARM_TLS_IE32 remain, which 3dsxtool does support).
#---------------------------------------------------------------------------------
# -fno-short-enums: devkitARM's default 3DS target ABI packs C enums into
# the smallest integer type that fits their range (1 byte for e.g.
# MenuItemType/LocStrID, which only have a handful of cases) - but Swift's
# ClangImporter always assumes a plain C enum occupies a full 4 bytes when
# computing struct field offsets for imported C types (Source/Headers/
# menu.h's MenuItem, among others). Left at its default, every field after
# an enum-typed field in a struct shared between C and Swift is offset by
# however many bytes were "saved", so Swift reads garbage/zeroed padding
# instead of the real field value (root-caused via a raw memory dump
# showing MenuItem's id field 4 bytes earlier than Swift's accessor
# expected). This must be applied consistently to BOTH the C/C++ compiler
# (via $(ARCH), used by every C/C++ compile rule) and Swift's own
# ClangImporter invocation (via -Xcc below in SWIFTFLAGS) - if only one
# side used 4-byte enums, the mismatch would just move rather than go away.
ARCH		:=	-march=armv6k -mtune=mpcore -mfloat-abi=hard -mtp=soft -fno-short-enums
PIC_FLAGS	:=	-fno-pic -fno-pie

CTRUDEFS	:=	-D__3DS__ -I$(COMMON) -I$(CTRULIB)/include

CFLAGS		:=	-g -Wall -O2 -mword-relocations -ffunction-sections -fdata-sections \
			$(ARCH) $(PIC_FLAGS) $(CTRUDEFS)

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

LIBS		:=	-lSDL3 -lctru -lm -L$(SWIFT_UNICODE_DATA_TABLES_LIBDIR) -lswiftUnicodeDataTables

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
# PommeSound.h's std::span). Built with -DPOMME_NO_GRAPHICS -DPOMME_NO_INPUT
# so Pomme::Init() (in ports/3DS/common/pomme_shim.cpp) skips its own
# QuickDraw-emulation graphics and legacy Mac Toolbox input glue (Button()/
# GetKeys()/etc, unrelated to and unused alongside this engine's own
# Input.swift/CTRUInputBackend) - nothing in Source/**/*.swift calls either
# (grep confirms). Sound IS enabled (no -DPOMME_NO_SOUND_MIXER/
# -DPOMME_NO_SOUND_FORMATS): Pomme's SoundMixer (cmixer.cpp) calls real
# SDL3 audio APIs (SDL_OpenAudioDeviceStream/SDL_AudioStream/etc.) directly
# - now that real SDL3 (vendor/SDL3) provides an actual n3ds audio backend,
# this is real, working audio, not something needing its own 3DS-specific
# implementation.
# Explicit per-file rules below (not a pattern rule) - a pattern rule over
# multiple source directories with only-sometimes-unique basenames is
# exactly what broke picaGL's Makefile wiring earlier (see PICAGL_OFILES's
# comment); not worth risking again for a modest file count.
#---------------------------------------------------------------------------------
POMME_DEFS	:=	-DPOMME_NO_GRAPHICS -DPOMME_NO_INPUT -DPOMME_NO_SOUND_MIXER

#---------------------------------------------------------------------------------
# Embedded Swift flags, targeting armv6-none-none-eabi.
#---------------------------------------------------------------------------------
SWIFTFLAGS	:=	-target armv6-none-none-eabi \
			-enable-experimental-feature Embedded \
			-wmo -Osize \
			-module-name Nanosaur2 \
			-DNANOSAUR_3DS \
			-import-objc-header $(COMMON)game_3ds.h \
			-Xllvm -relocation-model=static \
			-Xcc -D__3DS__ -Xcc -DNANOSAUR_3DS \
			-Xcc -march=armv6k -Xcc -mtune=mpcore -Xcc -mfloat-abi=hard \
			-Xcc -fno-short-enums \
			-Xcc -fno-pic -Xcc -fno-pie \
			-Xcc -isystem -Xcc $(DEVKITARM)/arm-none-eabi/include \
			-Xcc -I$(COMMON) \
			-Xcc -I$(CTRULIB)/include \
			-Xcc -I$(POMME_SOURCE) \
			-Xcc -I$(ENGINE_SOURCE)/Headers \
			-Xcc -I$(PICAGL_INCLUDE) \
			-Xcc -I$(SDL3_INCLUDE) \
			-Xcc -fmodule-map-file=$(COMMON)module.modulemap

#---------------------------------------------------------------------------------
# Sources: the real entry point (source/main.cpp - see its own header
# comment) plus the ENTIRE real engine. Was a curated subset while File I/O
# (Pomme) and Sound (Pomme's SoundMixer) weren't linked in yet - now that
# both are (see docs/3DS_PORT_PLAN.md's milestone updates) and there's a
# real `main()` calling `GameMain()` unmodified, there's no reason left to
# hold back to a subset: the whole engine already compile-checks and
# links cleanly except for `main` (verified repeatedly via ad hoc
# `swiftc`/g++ invocations covering every Source/**/*.swift and
# Source/**/*.c file) - this Makefile now does the same via `find`.
#---------------------------------------------------------------------------------
PORT_CPP	:=	$(wildcard source/*.cpp)
ENGINE_SWIFT	:=	$(shell find $(ENGINE_SOURCE) -name '*.swift')
ENGINE_CFILES	:=	$(shell find $(ENGINE_SOURCE) -name '*.c')

# All 72 basenames are unique (checked via `find ... | xargs -n1 basename |
# sort | uniq -d` - empty output), so a `vpath`-based single pattern rule
# is safe here: make searches each of these directories in turn for a
# matching `%.c`, rather than matching against one combined glob pattern
# (which is what broke picaGL's Makefile wiring earlier - see
# PICAGL_OFILES's comment - since patsubst is pure text substitution with
# no "does this file actually exist" check, unlike vpath's directory
# search).
vpath %.c $(sort $(dir $(ENGINE_CFILES)))
ENGINE_COFILES	:=	$(addprefix $(BUILD)/engine_,$(notdir $(ENGINE_CFILES:.c=.o)))

OFILES		:=	$(BUILD)/nanosaur2.swift.o $(BUILD)/main.o $(BUILD)/shim.o $(BUILD)/picaGL_shim.o \
			$(BUILD)/romfs_shim.o $(BUILD)/pomme_shim.o $(BUILD)/boot_shim.o $(BUILD)/fatal_shim.o \
			$(BUILD)/console_shim.o \
			$(BUILD)/pomme_Files.o $(BUILD)/pomme_HostVolume.o $(BUILD)/pomme_Resources.o \
			$(BUILD)/pomme_Memory.o $(BUILD)/pomme_Pomme.o $(BUILD)/pomme_PommeDebug.o \
			$(BUILD)/pomme_StringUtils.o $(BUILD)/pomme_bigendianstreams.o \
			$(BUILD)/pomme_memstream.o $(BUILD)/pomme_structpack.o $(BUILD)/pomme_IEEEExtended.o \
			$(BUILD)/pomme_cmixer.o $(BUILD)/pomme_ChannelImpl.o $(BUILD)/pomme_SoundManager.o \
			$(BUILD)/pomme_AIFF.o $(BUILD)/pomme_IMA4.o $(BUILD)/pomme_MACE.o $(BUILD)/pomme_Midi.o \
			$(BUILD)/pomme_SoundFormats.o $(BUILD)/pomme_mp3.o $(BUILD)/pomme_xlaw.o \
			$(BUILD)/pomme_TimeManager.o \
			$(ENGINE_COFILES) \
			$(PICAGL_OFILES) $(PICAGL_SHADER_OFILES)

#---------------------------------------------------------------------------------
.PHONY: all clean

all: $(TARGET).3dsx

$(BUILD):
	@mkdir -p $@

# All Swift (the entire real engine) -> one object, whole-module.
$(BUILD)/nanosaur2.swift.o: $(ENGINE_SWIFT) $(COMMON)module.modulemap $(COMMON)ctru_umbrella.h $(COMMON)game_3ds.h | $(BUILD)
	@echo compiling Swift
	$(SWIFTC) $(SWIFTFLAGS) -c $(ENGINE_SWIFT) -o $@

# The real entry point (source/main.cpp) - needs Pomme.h (for
# Pomme::QuitRequest) but not picaGL, since it only declares plain
# C-linkage functions for that, not its real headers. Does need real
# SDL3/SDL.h now, to create the real (if GL-unused) SDL_Window several
# engine call sites dereference every frame (see boot_shim.c's comment).
$(BUILD)/main.o: $(PORT_CPP) | $(BUILD)
	@echo $(notdir $<)
	$(CXX) -g -Wall -O2 -mword-relocations -ffunction-sections -fdata-sections \
		$(ARCH) $(PIC_FLAGS) -D__3DS__ -std=c++20 -I$(COMMON) -I$(POMME_SOURCE) -I$(SDL3_INCLUDE) -I$(CTRULIB)/include -c $(PORT_CPP) -o $@

# Real engine C files (bg3d.c, Main.c, etc. - global-storage-only leftovers
# after the Swift port, plus a couple of still-C functions like
# DoAlert/DoFatalAlert that take C varargs Swift can't implement).
#
# -DSTBI_NO_THREAD_LOCALS: stb_image.h uses `thread_local`/`__thread` for
# two static flip-on-load flags (real, deliberate C11 thread-local storage,
# not a PIC-codegen artifact like the Swift/Unicode-tables GOT_PREL issue -
# -fno-pic doesn't touch this). This engine is single-threaded on 3DS (no
# threads ever load images concurrently), and those extra R_ARM_TLS_LE32/
# R_ARM_TLS_LDO32 relocations are exactly the kind 3dsxtool's relocation
# converter silently drops - this macro (stb_image.h's own supported
# opt-out) makes them plain statics instead, functionally identical here.
$(BUILD)/engine_%.o: %.c | $(BUILD)
	@echo $(notdir $<)
	$(CC) $(CFLAGS) -DSTBI_NO_THREAD_LOCALS -I$(POMME_SOURCE) -I$(ENGINE_SOURCE)/Headers -I$(PICAGL_INCLUDE) -I$(SDL3_INCLUDE) -c $< -o $@

$(BUILD)/shim.o: $(COMMON)shim.c $(COMMON)shim.h | $(BUILD)
	@echo $(notdir $<)
	$(CC) $(CFLAGS) -c $< -o $@

$(BUILD)/picaGL_shim.o: $(COMMON)picaGL_shim.c $(COMMON)picaGL_shim.h | $(BUILD)
	@echo $(notdir $<)
	$(CC) $(CFLAGS) -I$(COMMON) -I$(PICAGL_INCLUDE) -c $< -o $@

$(BUILD)/romfs_shim.o: $(COMMON)romfs_shim.c $(COMMON)romfs_shim.h | $(BUILD)
	@echo $(notdir $<)
	$(CC) $(CFLAGS) -I$(COMMON) -c $< -o $@

$(BUILD)/boot_shim.o: $(COMMON)boot_shim.c | $(BUILD)
	@echo $(notdir $<)
	$(CC) $(CFLAGS) -I$(POMME_SOURCE) -I$(SDL3_INCLUDE) -c $< -o $@

$(BUILD)/fatal_shim.o: $(COMMON)fatal_shim.c $(COMMON)fatal_shim.h | $(BUILD)
	@echo $(notdir $<)
	$(CC) $(CFLAGS) -c $< -o $@

$(BUILD)/console_shim.o: $(COMMON)console_shim.c $(COMMON)console_shim.h | $(BUILD)
	@echo $(notdir $<)
	$(CC) $(CFLAGS) -I$(SDL3_INCLUDE) -c $< -o $@

#---------------------------------------------------------------------------------
# Pomme's real file/resource-manager C++ implementation - see this file's
# earlier POMME_FILES_CFILES comment. -std=c++20 (not c++17) because
# PommeSound.h uses std::span, even with sound compiled out via
# POMME_DEFS - Pomme.h's own top-level include still parses that header.
#---------------------------------------------------------------------------------
POMME_CXXFLAGS := -g -Wall -O2 -mword-relocations -ffunction-sections -fdata-sections \
			$(ARCH) $(PIC_FLAGS) -D__3DS__ -std=c++20 $(POMME_DEFS) -I$(POMME_SOURCE) -I$(SDL3_INCLUDE)

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

# Sound (SoundMixer/cmixer.cpp calls real SDL3 audio APIs directly - see
# POMME_DEFS's comment above for why this is enabled, not stubbed).
$(BUILD)/pomme_cmixer.o: $(POMME_SOURCE)/SoundMixer/cmixer.cpp | $(BUILD)
	@echo $(notdir $<)
	$(CXX) $(POMME_CXXFLAGS) -c $< -o $@

$(BUILD)/pomme_ChannelImpl.o: $(POMME_SOURCE)/SoundMixer/ChannelImpl.cpp | $(BUILD)
	@echo $(notdir $<)
	$(CXX) $(POMME_CXXFLAGS) -c $< -o $@

$(BUILD)/pomme_SoundManager.o: $(POMME_SOURCE)/SoundMixer/SoundManager.cpp | $(BUILD)
	@echo $(notdir $<)
	$(CXX) $(POMME_CXXFLAGS) -c $< -o $@

$(BUILD)/pomme_AIFF.o: $(POMME_SOURCE)/SoundFormats/AIFF.cpp | $(BUILD)
	@echo $(notdir $<)
	$(CXX) $(POMME_CXXFLAGS) -c $< -o $@

$(BUILD)/pomme_IMA4.o: $(POMME_SOURCE)/SoundFormats/IMA4.cpp | $(BUILD)
	@echo $(notdir $<)
	$(CXX) $(POMME_CXXFLAGS) -c $< -o $@

$(BUILD)/pomme_MACE.o: $(POMME_SOURCE)/SoundFormats/MACE.cpp | $(BUILD)
	@echo $(notdir $<)
	$(CXX) $(POMME_CXXFLAGS) -c $< -o $@

$(BUILD)/pomme_Midi.o: $(POMME_SOURCE)/SoundFormats/Midi.cpp | $(BUILD)
	@echo $(notdir $<)
	$(CXX) $(POMME_CXXFLAGS) -c $< -o $@

$(BUILD)/pomme_SoundFormats.o: $(POMME_SOURCE)/SoundFormats/SoundFormats.cpp | $(BUILD)
	@echo $(notdir $<)
	$(CXX) $(POMME_CXXFLAGS) -c $< -o $@

$(BUILD)/pomme_mp3.o: $(POMME_SOURCE)/SoundFormats/mp3.cpp | $(BUILD)
	@echo $(notdir $<)
	$(CXX) $(POMME_CXXFLAGS) -c $< -o $@

$(BUILD)/pomme_xlaw.o: $(POMME_SOURCE)/SoundFormats/xlaw.cpp | $(BUILD)
	@echo $(notdir $<)
	$(CXX) $(POMME_CXXFLAGS) -c $< -o $@

# Time (Microseconds/TickCount/GetDateTime - Mac Toolbox time emulation,
# called directly by Misc.swift's CalcFramesPerSecond and Main.swift's
# random-seed init).
$(BUILD)/pomme_TimeManager.o: $(POMME_SOURCE)/Time/TimeManager.cpp | $(BUILD)
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

# RomFS: embeds the real game data folder (../../Data - the same
# Sprites/Models/Skeletons/Terrain/Audio/System tree the desktop build
# reads via Pomme's Mac resource-fork emulation, per Boot.cpp's own
# `gDataSpec = HostPathToFSSpec(dataPath / "System")` - .parID there is
# Data/ itself, not System/, so file paths like ":Sprites:menu:menuback"
# resolve relative to Data/, which is why the whole folder (not just
# System/) needs to be the RomFS root). No reformatting: Pomme's resource
# parser operates on file *contents*, not host filesystem features, so
# these exact same bytes should parse identically once accessible via
# RomFS - 3dsxtool builds the RomFS image directly from this directory,
# no separate packaging tool needed.

# A separate, 3DS-only copy of Data/ (ports/3DS/Data), NOT the shared
# desktop Data/ folder - images here are compressed to roughly 1/3 their
# original linear dimensions (real PICA200 hardware caps textures at
# 1024px/axis anyway, and the 3DS's tiny heap can't hold many full-size
# desktop textures at once - see docs/3DS_PORT_PLAN.md). Font atlases
# (font.png/font.alt1.png/swiss.png) are intentionally left at full size:
# their companion .txt/.kerning.txt files encode pixel-exact glyph
# coordinates that would desync if the atlas image were resized without
# also rescaling those coordinates. Non-image assets (Models/*.bg3d,
# Terrain/*.ter, Audio/*, Skeletons/*) are plain copies, untouched.
DATA_DIR	:=	Data

$(TARGET).3dsx: $(TARGET).elf $(BUILD)/icon.smdh
	@echo packaging $(notdir $@)
	$(3DSXTOOL) $(TARGET).elf $@ --smdh=$(BUILD)/icon.smdh --romfs=$(DATA_DIR)

clean:
	@echo clean ...
	@rm -fr $(BUILD) $(TARGET).elf $(TARGET).3dsx $(TARGET).map
