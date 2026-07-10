// Settings.swift - Port of Settings.c to Swift

private let kSettingsFULL_CHANNEL_VOLUME: UInt32 = 0x0100 // kFullVolume

// MARK: - Layout flag callbacks

private let cDisableMenuEntryInGame: @convention(c) (UnsafePointer<MenuItem>?) -> Int32 = { _ in
    gEngine.screens.playNow != 0 ? Int32(kMILayoutFlagDisabled) : 0
}

private let cHideMenuEntryInGame: @convention(c) (UnsafePointer<MenuItem>?) -> Int32 = { _ in
    gEngine.screens.playNow != 0 ? Int32(kMILayoutFlagHidden) : 0
}

private let cShowMenuEntryInGameOnly: @convention(c) (UnsafePointer<MenuItem>?) -> Int32 = { _ in
    gEngine.screens.playNow != 0 ? 0 : Int32(kMILayoutFlagHidden)
}

private let cShouldDisplayMonitorCycler: @convention(c) (UnsafePointer<MenuItem>?) -> Int32 = { _ in
    GetNumDisplays() <= 1 ? Int32(kMILayoutFlagHidden) : 0
}

// MARK: - Simple callbacks

private let cOnEnterSettingsMenu: @convention(c) () -> Void = { SavePrefs() }

private let cOnPickLanguage: @convention(c) () -> Void = {
    let language = gGamePrefs.language
    gGamePrefs.cutsceneSubtitles = (Int32(language) != LANGUAGE_ENGLISH.rawValue || !IsNativeEnglishSystem()) ? 1 : 0
    LoadLocalizedStrings(GameLanguageID(rawValue: Int32(language)))
    LayoutCurrentMenuAgain(true)
}

private let cOnToggleFullscreen: @convention(c) () -> Void = { SetFullscreenMode(true) }

private let cOnPickResetKeyboardBindings: @convention(c) () -> Void = {
    ResetDefaultKeyboardBindings()
    PlayEffect_Parms(Int16(EFFECT_TURRETEXPLOSION), kSettingsFULL_CHANNEL_VOLUME / 3, kSettingsFULL_CHANNEL_VOLUME / 3, UInt(NORMAL_CHANNEL_RATE))
    LayoutCurrentMenuAgain(true)
}

private let cOnPickResetGamepadBindings: @convention(c) () -> Void = {
    ResetDefaultGamepadBindings()
    PlayEffect_Parms(Int16(EFFECT_TURRETEXPLOSION), kSettingsFULL_CHANNEL_VOLUME / 3, kSettingsFULL_CHANNEL_VOLUME / 3, UInt(NORMAL_CHANNEL_RATE))
    LayoutCurrentMenuAgain(true)
}

private let cOnPickResetMouseBindings: @convention(c) () -> Void = {
    ResetDefaultMouseBindings()
    PlayEffect_Parms(Int16(EFFECT_TURRETEXPLOSION), kSettingsFULL_CHANNEL_VOLUME / 3, kSettingsFULL_CHANNEL_VOLUME / 3, UInt(NORMAL_CHANNEL_RATE))
    LayoutCurrentMenuAgain(true)
}

private let cTestGamepadRumble: @convention(c) () -> Void = { Rumble(1, 1, 200, Int32(ANY_PLAYER)) }

private let cOnChangeVSync: @convention(c) () -> Void = {
    gEngine.renderer.setVSync(Int32(gGamePrefs.vsync))
}

// MARK: - Graphics / Gamepad menu callbacks


private let cMoveTemporaryGraphicsMenuText: @convention(c) (UnsafeMutablePointer<ObjNode>?) -> Void = { theNode in
    guard let theNode = theNode else { return }
    if GetCurrentMenu() != fourCC("graf") {
        if theNode == gEngine.screens.msaaWarningNode { gEngine.screens.msaaWarningNode = nil }
        DeleteObject(theNode)
    }
}

private let cMoveTemporaryGamepadMenuText: @convention(c) (UnsafeMutablePointer<ObjNode>?) -> Void = { theNode in
    guard let theNode = theNode else { return }
    if GetCurrentMenu() != fourCC("gpad") { DeleteObject(theNode) }
}

private let cOnChangeMSAA: @convention(c) () -> Void = {
    if gCurrentAntialiasingLevel == Int32(gGamePrefs.antialiasingLevel) {
        if let n = gEngine.screens.msaaWarningNode { DeleteObject(n); gEngine.screens.msaaWarningNode = nil }
        return
    } else if gEngine.screens.msaaWarningNode != nil {
        return
    }
    var def = NewObjectDefinitionType()
    def.group = UInt8(ATLAS_GROUP_FONT2)
    def.coord = OGLPoint3D(x: 320, y: 435, z: 0)
    def.scale = 0.25
    def.slot = Int16(SPRITE_SLOT)
    def.flags = UInt32(STATUS_BIT_MOVEINPAUSE)
    def.moveCall = cMoveTemporaryGraphicsMenuText
    let node = TextMesh_New(localized(STR_ANTIALIASING_CHANGE_WARNING), 0, &def)
    node.pointee.ColorFilter = OGLColorRGBA(r: 1, g: 0, b: 0, a: 1)
    gEngine.screens.msaaWarningNode = node
    SendNodeToOverlayPane(node)
    MakeTwitch(node, Int32(kTwitchPreset_MenuSelect))
}

private let cOnEnterGraphicsMenu: @convention(c) () -> Void = {
    var def = NewObjectDefinitionType()
    def.coord = OGLPoint3D(x: 320, y: 480 - 8, z: 0)
    def.group = UInt8(ATLAS_GROUP_FONT2)
    def.scale = 0.15
    def.slot = Int16(SPRITE_SLOT)
    def.moveCall = cMoveTemporaryGraphicsMenuText
    def.flags = UInt32(STATUS_BIT_MOVEINPAUSE)
    let driverStr   = String(cString: SDL_GetCurrentVideoDriver()!)
    let info = "\(gEngine.renderer.rendererInfo()), \(driverStr)"
    let text = TextMesh_New(info, Int32(kTextMeshSmallCaps | kTextMeshAlignBottom), &def)
    text.pointee.ColorFilter.a = 0.75
    SendNodeToOverlayPane(text)
    cOnChangeMSAA()
}

private let cOnEnterGamepadMenu: @convention(c) () -> Void = {
    let sdlGamepad = GetGamepad(0)
    let name = sdlGamepad.flatMap { SDL_GetGamepadName($0) }.map { String(cString: $0) } ?? localized(STR_NO_GAMEPAD_DETECTED)
    var def = NewObjectDefinitionType()
    def.coord = OGLPoint3D(x: 320, y: 480 - 8, z: 0)
    def.group = UInt8(ATLAS_GROUP_FONT2)
    def.scale = 0.15
    def.slot = Int16(SPRITE_SLOT)
    def.moveCall = cMoveTemporaryGamepadMenuText
    def.flags = UInt32(STATUS_BIT_MOVEINPAUSE)
    let text = TextMesh_New(name, Int32(kTextMeshSmallCaps | kTextMeshAlignBottom), &def)
    text.pointee.ColorFilter.a = 0.75
    SendNodeToOverlayPane(text)
}

// MARK: - Settings menu tree
//
// Split into sections to avoid type-checker timeout on a single large literal.

private let gSettingsMenuTreePtr: UnsafeMutablePointer<MenuItem> = {
    // ROOT
    let root: [MenuItem] = [
        miRoot(fourCC("sett"), callback: cOnEnterSettingsMenu),
        miLabel(STR_SETTINGS),
        miSpacer(customHeight: 0.3),
        miCycler1(STR_DIFFICULTY, valuePtr: SettingsInternal_GetKiddieModePtr(),
                  choices: [(STR_NORMAL_DIFFICULTY, 0), (STR_KIDDIE_MODE, 1)]),
        miPick(STR_CONTROLS,   next: fourCC("ctrl")),
        miPick(STR_GRAPHICS,   next: fourCC("graf")),
        miPick(STR_SOUND,      next: fourCC("soun")),
        miPick(STR_INTERFACE,  next: fourCC("ifac")),
        miPick(STR_BACK_SYMBOL, next: fourCC("BACK")),
    ]

    // INTERFACE
    let langChoices: [(LocStrID, UInt8)] = [
        (STR_ENGLISH, UInt8(LANGUAGE_ENGLISH.rawValue)),
        (STR_FRENCH,  UInt8(LANGUAGE_FRENCH.rawValue)),
        (STR_GERMAN,  UInt8(LANGUAGE_GERMAN.rawValue)),
        (STR_SPANISH, UInt8(LANGUAGE_SPANISH.rawValue)),
        (STR_ITALIAN, UInt8(LANGUAGE_ITALIAN.rawValue)),
        (STR_DUTCH,   UInt8(LANGUAGE_DUTCH.rawValue)),
        (STR_SWEDISH, UInt8(LANGUAGE_SWEDISH.rawValue)),
        (STR_RUSSIAN, UInt8(LANGUAGE_RUSSIAN.rawValue)),
    ]
    let ifac: [MenuItem] = [
        miRoot(fourCC("ifac")),
        miLabel(STR_INTERFACE),
        miSpacer(customHeight: 0.3),
        miCycler2(STR_LANGUAGE, valuePtr: SettingsInternal_GetLanguagePtr(),
                  choices: langChoices, callback: cOnPickLanguage),
        miCycler2(STR_CROSSHAIRS, valuePtr: SettingsInternal_GetShowCrosshairsPtr(),
                  choices: [(STR_CROSSHAIRS_OFF, 0), (STR_CROSSHAIRS_ON, 1)]),
        miCycler2(STR_HUD_POSITION, valuePtr: SettingsInternal_GetForce4x3HUDPtr(),
                  choices: [(STR_HUD_FULLSCREEN, 0), (STR_HUD_4X3, 1)]),
        miSlider(STR_HUD_SCALE, valuePtr: SettingsInternal_GetHUDScalePtr(),
                 minValue: 50, maxValue: 200, equilibrium: 100, increment: 5, continuousCallback: true),
        miPick(STR_BACK_SYMBOL, next: fourCC("BACK")),
    ]

    // CONTROLS
    let ctrl: [MenuItem] = [
        miRoot(fourCC("ctrl")),
        miLabel(STR_CONTROLS),
        miSpacer(customHeight: 0.3),
        miPick(STR_CONFIGURE_GAMEPAD,  next: fourCC("gpad")),
        miPick(STR_CONFIGURE_KEYBOARD, next: fourCC("keyb")),
        miPick(STR_CONFIGURE_MOUSE,    next: fourCC("mous")),
        miCycler2(STR_VERTICAL_STEERING, valuePtr: SettingsInternal_GetInvertVerticalSteeringPtr(),
                  choices: [(STR_NORMAL, 0), (STR_INVERTED, 1)]),
        miSlider(STR_GAMEPAD_RUMBLE, valuePtr: SettingsInternal_GetRumbleIntensityPtr(),
                 minValue: 0, maxValue: 100, equilibrium: 100, increment: 25, continuousCallback: false,
                 callback: cTestGamepadRumble),
        miPick(STR_BACK_SYMBOL, next: fourCC("BACK")),
    ]

    // GRAPHICS
    let graf: [MenuItem] = [
        miRoot(fourCC("graf"), callback: cOnEnterGraphicsMenu),
        miLabel(STR_GRAPHICS),
        miSpacer(customHeight: 0.3),
        miCycler2(STR_FULLSCREEN, valuePtr: SettingsInternal_GetFullscreenPtr(),
                  choices: [(STR_NO, 0), (STR_YES, 1)], callback: cOnToggleFullscreen),
        miCycler2Dynamic(STR_PREFERRED_DISPLAY, valuePtr: SettingsInternal_GetDisplayNumPtr(),
                         generateNumChoices: GetNumDisplays,
                         generateChoiceString: SettingsInternal_GetDisplayName,
                         callback: cOnToggleFullscreen, getLayoutFlags: cShouldDisplayMonitorCycler),
        miCycler2(STR_VSYNC, valuePtr: SettingsInternal_GetVSyncPtr(),
                  choices: [(STR_NO, 0), (STR_YES, 1)], callback: cOnChangeVSync),
        miCycler2(STR_ANTIALIASING, valuePtr: SettingsInternal_GetAntialiasingLevelPtr(),
                  choices: [(STR_NO, 0), (STR_MSAA_2X, 1), (STR_MSAA_4X, 2), (STR_MSAA_8X, 3)],
                  callback: cOnChangeMSAA),
        miPick(STR_3D_GLASSES_CALIBRATE, next: fourCC("cali"), callback: SetUpAnaglyphCalibrationScreen),
        miPick(STR_BACK_SYMBOL, next: fourCC("BACK")),
    ]

    // AUDIO
    let soun: [MenuItem] = [
        miRoot(fourCC("soun")),
        miLabel(STR_SOUND),
        miSpacer(customHeight: 0.3),
        miSlider(STR_MUSIC, valuePtr: SettingsInternal_GetMusicVolumePercentPtr(),
                 minValue: 0, maxValue: 100, equilibrium: 70, increment: 5, continuousCallback: true,
                 callback: UpdateGlobalVolume),
        miSlider(STR_SFX, valuePtr: SettingsInternal_GetSFXVolumePercentPtr(),
                 minValue: 0, maxValue: 100, equilibrium: 70, increment: 5, continuousCallback: true,
                 callback: UpdateGlobalVolume),
        miPick(STR_BACK_SYMBOL, next: fourCC("BACK")),
    ]

    // KEYBOARD
    let keyb: [MenuItem] = [
        miRoot(fourCC("keyb")),
        miLabel(STR_CONFIGURE_KEYBOARD_HELP, customHeight: 0.7),
        miSpacer(customHeight: 0.4),
        miKeyBinding(Int32(kNeed_PitchUp)),
        miKeyBinding(Int32(kNeed_PitchDown)),
        miKeyBinding(Int32(kNeed_YawLeft)),
        miKeyBinding(Int32(kNeed_YawRight)),
        miKeyBinding(Int32(kNeed_Fire)),
        miKeyBinding(Int32(kNeed_Jetpack)),
        miKeyBinding(Int32(kNeed_NextWeapon)),
        miKeyBinding(Int32(kNeed_PrevWeapon)),
        miKeyBinding(Int32(kNeed_Drop)),
        miKeyBinding(Int32(kNeed_CameraMode)),
        miSpacer(customHeight: 0.25),
        miPick(STR_RESTORE_DEFAULT_CONFIG, callback: cOnPickResetKeyboardBindings, customHeight: 0.5),
        miSpacer(customHeight: 0.25),
        miPick(STR_BACK_SYMBOL, next: fourCC("BACK")),
        miSpacer(customHeight: 2.2, getLayoutFlags: cHideMenuEntryInGame),
    ]

    // MOUSE
    let mous: [MenuItem] = [
        miRoot(fourCC("mous")),
        miSlider(STR_MOUSE_SENSITIVITY, valuePtr: SettingsInternal_GetMouseSensitivityLevelPtr(),
                 minValue: 10, maxValue: UInt8(MAX_MOUSE_SENSITIVITY_LEVEL),
                 equilibrium: UInt8(DEFAULT_MOUSE_SENSITIVITY_LEVEL), increment: 5, continuousCallback: true),
        miSpacer(customHeight: 0.25),
        miMouseBinding(Int32(kNeed_Fire)),
        miMouseBinding(Int32(kNeed_Jetpack)),
        miMouseBinding(Int32(kNeed_Drop)),
        miMouseBinding(Int32(kNeed_NextWeapon)),
        miMouseBinding(Int32(kNeed_PrevWeapon)),
        miMouseBinding(Int32(kNeed_CameraMode)),
        miSpacer(customHeight: 0.25),
        miPick(STR_RESTORE_DEFAULT_CONFIG, callback: cOnPickResetMouseBindings, customHeight: 0.5),
        miSpacer(customHeight: 0.25),
        miPick(STR_BACK_SYMBOL, next: fourCC("BACK")),
    ]

    // GAMEPAD
    let gpad: [MenuItem] = [
        miRoot(fourCC("gpad"), callback: cOnEnterGamepadMenu),
        miLabel(STR_CONFIGURE_GAMEPAD_HELP, customHeight: 0.6),
        miSpacer(customHeight: 0.25),
        miPadBinding(Int32(kNeed_PitchUp)),
        miPadBinding(Int32(kNeed_PitchDown)),
        miPadBinding(Int32(kNeed_YawLeft)),
        miPadBinding(Int32(kNeed_YawRight)),
        miPadBinding(Int32(kNeed_Fire)),
        miPadBinding(Int32(kNeed_Jetpack)),
        miPadBinding(Int32(kNeed_NextWeapon)),
        miPadBinding(Int32(kNeed_PrevWeapon)),
        miPadBinding(Int32(kNeed_Drop)),
        miPadBinding(Int32(kNeed_CameraMode)),
        miPick(STR_RESTORE_DEFAULT_CONFIG, callback: cOnPickResetGamepadBindings, customHeight: 0.5),
        miSpacer(customHeight: 0.25),
        miPick(STR_BACK_SYMBOL, next: fourCC("BACK")),
        miSpacer(customHeight: 2.8, getLayoutFlags: cHideMenuEntryInGame),
        miRoot(),
    ]

    return makeMenuTreeBuffer(root + ifac + ctrl + graf + soun + keyb + mous + gpad)
}()

// MARK: - RegisterSettingsMenu

func RegisterSettingsMenu() {
    RegisterMenu(gSettingsMenuTreePtr)
}
