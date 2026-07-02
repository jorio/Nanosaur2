// AnaglyphCalibration.swift - Port of AnaglyphCalibration.c to Swift
// The menu tree data tables and their embedded callbacks stay in
// AnaglyphCalibration.c; see AnaglyphCalibrationInternal.h.

private var gAnaglyphScreenHead: UnsafeMutablePointer<ObjNode>?

// IsStereo/IsStereoAnaglyphColor/IsStereoAnaglyphMono are parameterized
// C macros, which Swift can't import as callable symbols.
private func isStereo() -> Bool { gGamePrefs.stereoGlassesMode != UInt8(STEREO_GLASSES_MODE_OFF) }
private func isStereoAnaglyphColor() -> Bool { gGamePrefs.stereoGlassesMode == UInt8(STEREO_GLASSES_MODE_ANAGLYPH_COLOR) }
private func isStereoAnaglyphMono() -> Bool { gGamePrefs.stereoGlassesMode == UInt8(STEREO_GLASSES_MODE_ANAGLYPH_MONO) }

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

@c @implementation
public func SetUpAnaglyphCalibrationScreen() {
    // REGISTER MENU

    if gPlayNow != 0 {
        RegisterMenu(GetInGameAnaglyphMenu()) // can't show actual menu in-game
        return
    } else {
        RegisterMenu(GetAnaglyphMenu())
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
        blurb = "\(String(cString: Localize(STR_ANAGLYPH_HELP_WHILEWEARING)))\n \n"
            + "1. \(String(cString: Localize(STR_ANAGLYPH_HELP_ADJUSTRB)))\n \n"
            + "2. \(String(cString: Localize(STR_ANAGLYPH_HELP_ADJUSTG)))\n \n"
            + "3. \(String(cString: Localize(STR_ANAGLYPH_HELP_CHANNELBALANCING)))"
    } else if isStereoAnaglyphMono() {
        blurb = "\(String(cString: Localize(STR_ANAGLYPH_HELP_WHILEWEARING)))\n \n\(String(cString: Localize(STR_ANAGLYPH_HELP_ADJUSTRB)))"
    } else {
        blurb = String(cString: Localize(STR_ANAGLYPH_HELP_GRABYOURGLASSES))
        blurbDef.coord = OGLPoint3D(x: 320, y: 470, z: 0)
    }

    let alignFlag: Int32 = (isStereo() ? Int32(kTextMeshAlignLeft) : Int32(kTextMeshAlignCenter)) | Int32(kTextMeshAlignBottom)
    let blurbNode = TextMesh_New(blurb, alignFlag, &blurbDef)!
    AppendNodeToChain(anaglyphScreenHead, blurbNode)
}
