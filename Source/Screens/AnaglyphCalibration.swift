// AnaglyphCalibration.swift - Port of AnaglyphCalibration.c to Swift

private var gAnaglyphScreenHead: UnsafeMutablePointer<ObjNode>?

// MARK: - Anaglyph menu trees

private let cOnChangeAnaglyphMode: @convention(c) () -> Void = {
    gAnaglyphPass = 0
    for _ in 0..<4 {
        gEngine.renderer.setColorMask(true, true, true, true)
        gEngine.renderer.clearColorAndDepth()
        gEngine.renderer.present()
    }
    SetUpAnaglyphCalibrationScreen()
    LayoutCurrentMenuAgain(true)
}

private let cOnTweakAnaglyphLevels: @convention(c) () -> Void = {
    SetUpAnaglyphCalibrationScreen()
    LayoutCurrentMenuAgain(false)
}

private let cGetAnaglyphDisplayFlags: @convention(c) (UnsafePointer<MenuItem>?) -> Int32 = { _ in
    isStereoAnaglyph() ? 0 : Int32(kMILayoutFlagHidden)
}

private let cGetAnaglyphDisplayFlags_ColorOnly: @convention(c) (UnsafePointer<MenuItem>?) -> Int32 = { _ in
    isStereoAnaglyphColor() ? 0 : Int32(kMILayoutFlagHidden)
}

private let cResetAnaglyphSettings: @convention(c) () -> Void = {
    gGamePrefs.doAnaglyphChannelBalancing = UInt8(1)
    gGamePrefs.anaglyphCalibrationRed   = UInt8(DEFAULT_ANAGLYPH_R)
    gGamePrefs.anaglyphCalibrationGreen = UInt8(DEFAULT_ANAGLYPH_G)
    gGamePrefs.anaglyphCalibrationBlue  = UInt8(DEFAULT_ANAGLYPH_B)
    SetUpAnaglyphCalibrationScreen()
    LayoutCurrentMenuAgain(true)
}

private let cShouldShowResetAnaglyphSettings: @convention(c) (UnsafePointer<MenuItem>?) -> Int32 = { _ in
    isStereo() ? 0 : Int32(kMILayoutFlagHidden)
}

private let gInGameAnaglyphMenuPtr: UnsafeMutablePointer<MenuItem> = makeMenuTreeBuffer([
    miRoot(fourCC("cali")),
    miSpacer(customHeight: 1.5),
    miLabel(STR_NO_ANAGLYPH_CALIBRATION_IN_GAME, customHeight: 1.0),
    miSpacer(customHeight: 1.5),
    miPick(STR_BACK_SYMBOL, next: fourCC("BACK")),
    miRoot(),
])

private let gAnaglyphMenuPtr: UnsafeMutablePointer<MenuItem> = makeMenuTreeBuffer([
    miRoot(fourCC("cali")),
    miCycler2(STR_3D_GLASSES_MODE,
              valuePtr: AnaglyphInternal_GetStereoGlassesModePtr(),
              choices: [
                (STR_3D_GLASSES_DISABLED,        UInt8(StereoGlassesMode.off.rawValue)),
                (STR_3D_GLASSES_ANAGLYPH_COLOR,  UInt8(StereoGlassesMode.anaglyphColor.rawValue)),
                (STR_3D_GLASSES_ANAGLYPH_MONO,   UInt8(StereoGlassesMode.anaglyphMono.rawValue)),
              ],
              callback: cOnChangeAnaglyphMode),
    miSlider(STR_3D_GLASSES_R,
             valuePtr: AnaglyphInternal_GetCalibRedPtr(),
             minValue: 0, maxValue: 255, equilibrium: UInt8(DEFAULT_ANAGLYPH_R), increment: 5,
             continuousCallback: false,
             callback: cOnTweakAnaglyphLevels,
             getLayoutFlags: cGetAnaglyphDisplayFlags),
    miSlider(STR_3D_GLASSES_G,
             valuePtr: AnaglyphInternal_GetCalibGreenPtr(),
             minValue: 0, maxValue: 255, equilibrium: UInt8(DEFAULT_ANAGLYPH_G), increment: 5,
             continuousCallback: false,
             callback: cOnTweakAnaglyphLevels,
             getLayoutFlags: cGetAnaglyphDisplayFlags_ColorOnly),
    miSlider(STR_3D_GLASSES_B,
             valuePtr: AnaglyphInternal_GetCalibBluePtr(),
             minValue: 0, maxValue: 255, equilibrium: UInt8(DEFAULT_ANAGLYPH_B), increment: 5,
             continuousCallback: false,
             callback: cOnTweakAnaglyphLevels,
             getLayoutFlags: cGetAnaglyphDisplayFlags),
    miCycler2(STR_3D_GLASSES_CHANNEL_BALANCING,
              valuePtr: AnaglyphInternal_GetChannelBalancingPtr(),
              choices: [(STR_NO, 0), (STR_YES, 1)],
              callback: cOnTweakAnaglyphLevels,
              getLayoutFlags: cGetAnaglyphDisplayFlags_ColorOnly),
    miPick(STR_RESTORE_DEFAULT_CONFIG,
           callback: cResetAnaglyphSettings,
           getLayoutFlags: cShouldShowResetAnaglyphSettings,
           customHeight: 0.7),
    miPick(STR_BACK_SYMBOL, next: fourCC("BACK")),
    miSpacer(customHeight: 8),
    miRoot(),
])

// IsStereo/IsStereoAnaglyphColor/IsStereoAnaglyphMono are C macros, not callable from Swift.
private func isStereo() -> Bool { gGamePrefs.stereoGlassesMode != UInt8(StereoGlassesMode.off.rawValue) }
private func isStereoAnaglyphColor() -> Bool { gGamePrefs.stereoGlassesMode == UInt8(StereoGlassesMode.anaglyphColor.rawValue) }
private func isStereoAnaglyph() -> Bool { isStereoAnaglyphColor() || isStereoAnaglyphMono() }
private func isStereoAnaglyphMono() -> Bool { gGamePrefs.stereoGlassesMode == UInt8(StereoGlassesMode.anaglyphMono.rawValue) }

private let cMoveAnaglyphScreenHeadObject: @convention(c) (UnsafeMutablePointer<ObjNode>?) -> Void = { _ in
    if GetCurrentMenu() != 0x6361_6C69 { // 'cali'
        DisposeAnaglyphCalibrationScreen()
    }
}

private func DisposeAnaglyphCalibrationScreen() {
    DisposeSpriteAtlas(Int32(ATLAS_GROUP_FONT3))
    DisposeSpriteGroup(Int32(SPRITE_GROUP_LEVELSPECIFIC))

    if let head = gAnaglyphScreenHead {
        DeleteObject(head)
        gAnaglyphScreenHead = nil
    }
}

func SetUpAnaglyphCalibrationScreen() {
    // REGISTER MENU

    if gPlayNow != 0 {
        RegisterMenu(gInGameAnaglyphMenuPtr) // can't show actual menu in-game
        return
    } else {
        RegisterMenu(gAnaglyphMenuPtr)
    }

    // NUKE AND RELOAD TEXTURES SO THE CURRENT ANAGLYPH FILTER APPLIES TO THEM

    DisposeAnaglyphCalibrationScreen()

    DisposeGlobalAssets() // reload the font - won't apply to current menu because it keeps a reference to the
    LoadGlobalAssets() // old material, but at least the text will look correct when we exit the menu.

    BuildMainMenuObjects() // rebuild background image

    DisposeSpriteAtlas(Int32(ATLAS_GROUP_FONT3))
    LoadSpriteAtlas(Int32(ATLAS_GROUP_FONT3), ":Sprites:fonts:swiss", Int32(kAtlasLoadFont))

    // CREATE HEAD SENTINEL - ALL ANAGLYPH CALIB OBJECTS WILL BE CHAINED TO IT

    var headSentinelDef = NewObjectDefinitionType()
    headSentinelDef.group = UInt8(CUSTOM_GENRE)
    headSentinelDef.scale = 1
    headSentinelDef.slot = Int16(SPRITE_SLOT)
    headSentinelDef.flags = UInt32(STATUS_BIT_HIDDEN | STATUS_BIT_MOVEINPAUSE)
    headSentinelDef.moveCall = cMoveAnaglyphScreenHeadObject
    let anaglyphScreenHead = MakeNewObject(&headSentinelDef)!
    gAnaglyphScreenHead = anaglyphScreenHead

    // MAKE TEST PATTERN

    var imageDef = NewObjectDefinitionType()
    imageDef.group = UInt8(SPRITE_GROUP_LEVELSPECIFIC)
    imageDef.type = 0 // 0th image in sprite group
    imageDef.coord = OGLPoint3D(x: 500, y: 380, z: 0)
    imageDef.slot = Int16(SPRITE_SLOT) + 1
    imageDef.scale = 250

    if isStereo() {
        LoadSpriteGroupFromFile(Int32(SPRITE_GROUP_LEVELSPECIFIC), ":Sprites:calibration:calibration000", 0)
    } else {
        imageDef.scale = 350
        imageDef.coord = OGLPoint3D(x: 320, y: 350, z: 0)
        LoadSpriteGroupFromFile(Int32(SPRITE_GROUP_LEVELSPECIFIC), ":Sprites:calibration:glasses", 0)
    }

    let sampleImage = MakeSpriteObject(&imageDef, 1)!
    sampleImage.pointee.AnaglyphZ = 4.0

    AppendNodeToChain(anaglyphScreenHead, sampleImage)

    // MAKE HELP BLURB

    var blurbDef = NewObjectDefinitionType()
    blurbDef.group = UInt8(ATLAS_GROUP_FONT3)
    blurbDef.scale = 0.16
    blurbDef.slot = Int16(SPRITE_SLOT) + 2
    blurbDef.coord = OGLPoint3D(x: 10, y: 470, z: 0)

    let blurb: String

    if isStereoAnaglyphColor() {
        blurb = "\(localized(STR_ANAGLYPH_HELP_WHILEWEARING))\n \n"
            + "1. \(localized(STR_ANAGLYPH_HELP_ADJUSTRB))\n \n"
            + "2. \(localized(STR_ANAGLYPH_HELP_ADJUSTG))\n \n"
            + "3. \(localized(STR_ANAGLYPH_HELP_CHANNELBALANCING))"
    } else if isStereoAnaglyphMono() {
        blurb = "\(localized(STR_ANAGLYPH_HELP_WHILEWEARING))\n \n\(localized(STR_ANAGLYPH_HELP_ADJUSTRB))"
    } else {
        blurb = localized(STR_ANAGLYPH_HELP_GRABYOURGLASSES)
        blurbDef.coord = OGLPoint3D(x: 320, y: 470, z: 0)
    }

    let alignFlag: Int32 = (isStereo() ? Int32(kTextMeshAlignLeft) : Int32(kTextMeshAlignCenter)) | Int32(kTextMeshAlignBottom)
    let blurbNode = TextMesh_New(blurb, alignFlag, &blurbDef)
    AppendNodeToChain(anaglyphScreenHead, blurbNode)
}
