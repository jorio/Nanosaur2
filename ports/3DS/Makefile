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
LD		:=	$(PREFIX)gcc

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

LDFLAGS		:=	-specs=3dsx.specs -g $(ARCH) \
			-Wl,-Map,$(TARGET).map -Wl,--gc-sections \
			-L$(CTRULIB)/lib

LIBS		:=	-lcitro2d -lcitro3d -lctru -lm

BIN2S		?=	bin2s

#---------------------------------------------------------------------------------
# PICA200 GPU shaders (Phase 3 of docs/3DS_PORT_PLAN.md: the GL-compatibility
# shim backing OGL_Support.swift's immediate-mode calls needs a real compiled
# vertex shader, since the PICA200 has no fixed-function vertex pipeline).
# Each %.v.pica assembles to a %.shbin (via picasso), which then gets
# embedded as linkable data the same way devkitPro's example Makefiles do it
# (bin2s generates a .s + a _shbin.h with the byte array's extents, then the
# .s assembles into a normal .o) - see $(DEVKITARM)/base_tools's `bin2o`.
#---------------------------------------------------------------------------------
SHADERS		:=	shaders/


#---------------------------------------------------------------------------------
# Real-engine paths. game_3ds.h (see common/) is the 3DS-specific substitute
# for Source/Headers/game.h + Nanosaur2-Bridging-Header.h - see its header
# comment and docs/3DS_PORT_PLAN.md, Phase 2.
#---------------------------------------------------------------------------------
ENGINE_ROOT	:=	../..
ENGINE_SOURCE	:=	$(ENGINE_ROOT)/Source
POMME_SOURCE	:=	$(ENGINE_ROOT)/extern/Pomme/src

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

OFILES		:=	$(BUILD)/nanosaur2.swift.o $(BUILD)/shim.o $(BUILD)/glcompat_shbin.o $(BUILD)/glcompat.o $(BUILD)/sdlcompat.o

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

$(BUILD)/glcompat.o: $(COMMON)glcompat.c $(COMMON)SDL3/SDL_opengl.h $(BUILD)/glcompat_shbin.h | $(BUILD)
	@echo $(notdir $<)
	$(CC) $(CFLAGS) -I$(BUILD) -I$(COMMON) -c $< -o $@

$(BUILD)/sdlcompat.o: $(COMMON)sdlcompat.c $(COMMON)SDL3/SDL.h | $(BUILD)
	@echo $(notdir $<)
	$(CC) $(CFLAGS) -I$(COMMON) -c $< -o $@

$(SHADERS)glcompat.shbin $(SHADERS)glcompat_shbin.h: $(SHADERS)glcompat.v.pica
	@echo $(notdir $<)
	picasso -o $(SHADERS)glcompat.shbin -h $(SHADERS)glcompat_shbin.h $<

$(BUILD)/glcompat_shbin.h $(BUILD)/glcompat_shbin.s: $(SHADERS)glcompat.shbin | $(BUILD)
	@echo $(notdir $<)
	$(BIN2S) -a 4 -H $(BUILD)/glcompat_shbin.h $< > $(BUILD)/glcompat_shbin.s

$(BUILD)/glcompat_shbin.o: $(BUILD)/glcompat_shbin.s
	$(CC) -x assembler-with-cpp $(CFLAGS) -c $< -o $@

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
	@rm -fr $(BUILD) $(TARGET).elf $(TARGET).3dsx $(TARGET).map $(SHADERS)glcompat.shbin $(SHADERS)glcompat_shbin.h
