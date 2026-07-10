// LevelIntro.swift - Port of LevelIntro.c to Swift

// MARK: - Level intro save menu

private let cGetLevelSpecificMenuLayoutFlags: @convention(c) (UnsafePointer<MenuItem>?) -> Int32 = { mi in
    guard let mi = mi else { return Int32(kMILayoutFlagHidden | kMILayoutFlagDisabled) }
    let id = mi.pointee.id
    if (gLevelNum == 1 && id == fourCC("lvl1")) || (gLevelNum == 2 && id == fourCC("lvl2")) {
        return 0
    }
    return Int32(kMILayoutFlagHidden | kMILayoutFlagDisabled)
}

private let gSaveMenuTreePtr: UnsafeMutablePointer<MenuItem> = makeMenuTreeBuffer([
    miRoot(fourCC("lvin")),
    miPick(STR_SAVE_GAME, next: fourCC("save"), customHeight: 1),
    miPick(STR_CONTINUE_WITHOUT_SAVING, next: fourCC("EXIT"), id: fourCC("nosv"), customHeight: 1),

    miRoot(fourCC("save")),
    miLabel(STR_ENTERING_LEVEL_2, id: fourCC("lvl1"), getLayoutFlags: cGetLevelSpecificMenuLayoutFlags),
    miLabel(STR_ENTERING_LEVEL_3, id: fourCC("lvl2"), getLayoutFlags: cGetLevelSpecificMenuLayoutFlags),
    miFileSlot(STR_FILE, id: fourCC("sf#0"), fileSlot: 0, next: fourCC("EXIT")),
    miFileSlot(STR_FILE, id: fourCC("sf#1"), fileSlot: 1, next: fourCC("EXIT")),
    miFileSlot(STR_FILE, id: fourCC("sf#2"), fileSlot: 2, next: fourCC("EXIT")),
    miFileSlot(STR_FILE, id: fourCC("sf#3"), fileSlot: 3, next: fourCC("EXIT")),
    miFileSlot(STR_FILE, id: fourCC("sf#4"), fileSlot: 4, next: fourCC("EXIT")),
    miPick(STR_CONTINUE_WITHOUT_SAVING, next: fourCC("EXIT"), id: fourCC("nosv")),
    miSpacer(customHeight: 1.5),
    miRoot(),
])

func MakeLevelIntroSaveSprites() {
    var style = kDefaultMenuStyle
    style.darkenPaneOpacity = 0.6
    style.yOffset = 400
    style.standardScale *= 0.75
    style.rowHeight *= 0.75
    MakeMenu(gSaveMenuTreePtr, &style)
    _ = MakeMouseCursorObject()
}

private let kCreditLineDuration: Float = 3.5
private let kCreditLinePause: Float = 0.5
private let kCreditFirstDelay: Float = 1.0
private let kCreditFadeInTime: Float = 0.2
private let kCreditFadeOutTime: Float = 0.3

private let kCreditsText: [(role: String, name: String)] = [
    ("PROGRAMMING & DESIGN", "Brian Greenstone"),
    ("ART & DESIGN", "Scott Harper"),
    ("MUSIC", "Aleksander Dimitrijevic"),
    ("ANIMATION", "Peter Greenstone"),
    ("ILLUSTRATOR", "Rich Bonk"),
    ("COLORIST", "Ben Prenevost"),
    ("ADDITIONAL PROGRAMMING", "Iliyas Jorio"),
]

private var gWormholeDeformPoints = [OGLPoint3D](repeating: OGLPoint3D(), count: 30)
private var gIntroMode: UInt8 = 0

private let FULL_CHANNEL_VOLUME: UInt32 = 0x0100

// IsStereo/IsStereoAnaglyph are parameterized C macros, which Swift can't import as callable symbols.
private func isStereo() -> Bool { gGamePrefs.stereoGlassesMode != UInt8(StereoGlassesMode.off.rawValue) }
private func isStereoAnaglyph() -> Bool {
    gGamePrefs.stereoGlassesMode == UInt8(StereoGlassesMode.anaglyphColor.rawValue) || gGamePrefs.stereoGlassesMode == UInt8(StereoGlassesMode.anaglyphMono.rawValue)
}

// MARK: - Do level intro screen

func DoLevelIntroScreen(_ mode: UInt8) {
    var bail = false
    var timer: Float = 5.0

    // (SKIPFLUFF is hardcoded off in this build, so this early-return never fires.)

    gIntroMode = mode

    // SETUP

    setupLevelIntroScreen()
    _ = MakeFadeEvent(UInt8(kFadeFlags_In), 1.5)

    // MAIN LOOP

    repeat {
        CalcFramesPerSecond()
        DoSDLMaintenance()

        MoveObjects()
        OGL_DrawScene(DrawObjects)

        switch Int(gIntroMode) {
        case INTRO_MODE_SCREENSAVER, INTRO_MODE_CREDITS:
            if UserWantsOut() != 0 {
                bail = true
            }

        case INTRO_MODE_NOSAVE:
            timer -= gFramesPerSecondFrac
            if timer < 0.0 || UserWantsOut() != 0 {
                bail = true
            }

        case INTRO_MODE_SAVEGAME:
            if gMenuOutcome != 0 {
                bail = true
            }

        default:
            break
        }
    } while !bail

    // FADE OUT

    OGL_FadeOutScene(DrawObjects, MoveObjects)

    // DO SAVE

    switch gMenuOutcome {
    case 0x7366_2330...0x7366_2339: // 'sf#0'...'sf#9'
        _ = SaveGame(gMenuOutcome - 0x7366_2330)

    default: // 'dont'
        break
    }

    // CLEANUP

    freeLevelIntroScreen()
}

// MARK: - Setup level intro screen

private func setupLevelIntroScreen() {
    var spec = FSSpec()
    var viewDef = OGLSetupInputType()
    let fillDirection1 = OGLVector3D(x: -0.3, y: -0.5, z: -1.0)

    // SETUP VIEW

    OGL_NewViewDef(&viewDef)

    viewDef.camera.fov = 1.1
    viewDef.camera.hither = 50
    viewDef.camera.yon = 8000

    viewDef.styles.useFog = 1
    viewDef.styles.fogStart = viewDef.camera.yon * 0.1
    viewDef.styles.fogEnd = viewDef.camera.yon * 0.9
    viewDef.view.clearColor.r = 0
    viewDef.view.clearColor.g = 0
    viewDef.view.clearColor.b = 0
    viewDef.view.clearBackBuffer = 1

    viewDef.camera.from.0.x = 0
    viewDef.camera.from.0.y = 0
    viewDef.camera.from.0.z = 0

    viewDef.camera.to.0.x = 0.0
    viewDef.camera.to.0.y = 0.0
    viewDef.camera.to.0.z = -1500.0

    viewDef.lights.ambientColor.r = 0.3
    viewDef.lights.ambientColor.g = 0.3
    viewDef.lights.ambientColor.b = 0.3
    viewDef.lights.fillDirection.0 = fillDirection1

    // INIT ANAGLYPH INFO

    if isStereo() {
        gAnaglyphFocallength = 300.0
        gAnaglyphEyeSeparation = 20.0

        if isStereoAnaglyph() {
            viewDef.lights.ambientColor = OGLColorRGBA(r: 0.8, g: 0.8, b: 0.8, a: 1.0)
        }
    }

    OGL_SetupGameView(&viewDef)

    // LOAD ART

    InitParticleSystem()
    InitSparkles()

    // LOAD MODELS

    SwFSMakeFSSpec(gDataSpec.vRefNum, gDataSpec.parID, ":Models:playerparts.bg3d", &spec)
    ImportBG3D(&spec, Int32(MODEL_GROUP_PLAYER), Int16(VertexArrayRangeType.bg3dModels.rawValue))

    SwFSMakeFSSpec(gDataSpec.vRefNum, gDataSpec.parID, ":Models:levelintro.bg3d", &spec)
    ImportBG3D(&spec, Int32(MODEL_GROUP_LEVELINTRO), Int16(VertexArrayRangeType.bg3dModels.rawValue))

    // LOAD SPRITES

    LoadSpriteGroupFromFile(Int32(SPRITE_GROUP_LEVELSPECIFIC), ":Sprites:menu:nanologo", 0)

    // LOAD SKELETONS

    LoadASkeleton(UInt8(SkeletonType.bonusWormhole.rawValue))
    LoadASkeleton(UInt8(SkeletonType.player.rawValue))

    // MAKE WORMHOLE

    var wormholeDef = NewObjectDefinitionType()
    wormholeDef.type = UInt8(SkeletonType.bonusWormhole.rawValue)
    wormholeDef.animNum = 0
    wormholeDef.coord.x = 0.0
    wormholeDef.coord.y = 0
    wormholeDef.coord.z = 0
    wormholeDef.flags = UInt32(STATUS_BIT_DONTCULL | STATUS_BIT_DOUBLESIDED | STATUS_BIT_UVTRANSFORM | STATUS_BIT_GLOW | STATUS_BIT_NOZWRITES | STATUS_BIT_NOLIGHTING)
    wormholeDef.slot = 100
    wormholeDef.moveCall = cMoveLevelIntroWorm
    wormholeDef.rot = 0
    wormholeDef.scale = 26

    let newObj = MakeNewSkeletonObject(&wormholeDef)!
    newObj.pointee.Skeleton!.jointsAreGlobal = true
    newObj.updateTransforms()
    updateLevelIntroWormJoints(newObj)

    if Int(gIntroMode) != INTRO_MODE_SCREENSAVER && Int(gIntroMode) != INTRO_MODE_CREDITS {
        PlayEffect_Parms(Int16(EFFECT_WORMHOLE), FULL_CHANNEL_VOLUME / 2, FULL_CHANNEL_VOLUME / 3, UInt(NORMAL_CHANNEL_RATE))
    }

    // MAKE PLAYER

    makeLevelIntroWormNano()

    // MAKE STAR DOME

    makeLevelIntroStarDome()

    // DO MODE SPECIFICS

    switch Int(gIntroMode) {
    case INTRO_MODE_SAVEGAME:
        MakeLevelIntroSaveSprites()

    case INTRO_MODE_SCREENSAVER:
        setupScreensaverObjects()

    case INTRO_MODE_CREDITS:
        setupCreditsObjects()

    default:
        break
    }
}

// MARK: - Make level intro worm player

private func makeLevelIntroWormNano() {
    // MAKE SKELETON

    var def = NewObjectDefinitionType()
    def.type = UInt8(SkeletonType.player.rawValue)
    def.animNum = UInt8(PlayerAnim.flap.rawValue)
    def.flags = UInt32(STATUS_BIT_NOTEXTUREWRAP | STATUS_BIT_USEALIGNMENTMATRIX)
    def.slot = 200
    def.moveCall = cMoveLevelIntroNano
    def.rot = 0
    def.scale = 0.6

    let newObj = MakeNewSkeletonObject(&def)!

    newObj.pointee.Skeleton!.pointee.AnimSpeed = 2.0

    moveLevelIntroNano(newObj) // prime it

    // MAKE JETPACK

    def.group = UInt8(MODEL_GROUP_PLAYER)
    def.type = UInt8(PLAYER_ObjType_JetPack)
    def.flags = 0
    def.slot = Int16(SLOT_OF_DUMB)
    def.moveCall = MovePlayerJetpack
    let jetpack = MakeNewDisplayGroupObject(&def)!

    newObj.pointee.ChainNode = jetpack
    jetpack.pointee.ChainHead = newObj

    // BLUE THING

    def.type = UInt8(PLAYER_ObjType_JetPackBlue)
    def.flags = UInt32(STATUS_BIT_UVTRANSFORM | STATUS_BIT_GLOW | STATUS_BIT_NOLIGHTING)
    def.slot = Int16(SLOT_OF_DUMB) + 1
    def.moveCall = nil
    let blue = MakeNewDisplayGroupObject(&def)!

    blue.pointee.ColorFilter.a = 0.99
    jetpack.pointee.ChainNode = blue
    blue.pointee.ChainHead = jetpack

    // MAKE SPARKLES FOR GUN TURRETS

    let sparkleOff: [OGLPoint3D] = [
        OGLPoint3D(x: 21.21, y: 19.068, z: 21.183),
        OGLPoint3D(x: -21.21, y: 19.068, z: 21.183),
    ]

    for j in 0..<2 {
        let i = GetFreeSparkle(jetpack)
        if i != -1 {
            let sparkle = GetSparkleSlot(Int32(i))!
            sparkle.pointee.flags = UInt32(SPARKLE_FLAG_OMNIDIRECTIONAL | SPARKLE_FLAG_TRANSFORMWITHOWNER)
            sparkle.pointee.where = sparkleOff[j]

            sparkle.pointee.color.r = 1
            sparkle.pointee.color.g = 1
            sparkle.pointee.color.b = 1
            sparkle.pointee.color.a = 1

            sparkle.pointee.scale = 30.0
            sparkle.pointee.separation = 0.0

            sparkle.pointee.textureNum = Int16(PARTICLE_SObjType_GreenGlint)
        }
    }
}

// MARK: - Make level intro star dome

private func makeLevelIntroStarDome() {
    var width: Int32 = 0
    var height: Int32 = 0
    let textureName = OGL_TextureMap_LoadImageFile(":Sprites:textures:stardome", &width, &height, nil)

    var matData = MOMaterialData()
    matData.flags = UInt32(BG3D_MATERIALFLAG_TEXTURED)
    matData.diffuseColor = OGLColorRGBA(r: 1, g: 1, b: 1, a: 1)
    matData.numMipmaps = 1
    matData.width = UInt32(width)
    matData.height = UInt32(height)
    matData.textureName.0 = textureName

    let matRef = MO_CreateNewObjectOfType(.material, 0, &matData)!.assumingMemoryBound(to: MOMaterialObject.self)

    var def = NewObjectDefinitionType()
    def.genre = UInt8(QUADMESH_GENRE)
    def.coord.x = 0
    def.coord.y = 0
    def.coord.z = -5500
    def.flags = UInt32(STATUS_BIT_DONTCULL | STATUS_BIT_NOLIGHTING | STATUS_BIT_NOFOG | STATUS_BIT_DOUBLESIDED | STATUS_BIT_NOZBUFFER)
    def.slot = 0
    def.moveCall = cMoveIntroStarDome
    def.rot = 0
    def.scale = 10000

    let stardome = MakeQuadMeshObject(&def, 1, matRef)
    let stardomeVAD = GetQuadMeshWithin(stardome)
    stardomeVAD.pointee.numPoints = 4
    stardomeVAD.pointee.numTriangles = 2
    stardomeVAD.pointee.points[0] = OGLPoint3D(x: -1, y: -1, z: 0)
    stardomeVAD.pointee.points[1] = OGLPoint3D(x: 1, y: -1, z: 0)
    stardomeVAD.pointee.points[2] = OGLPoint3D(x: 1, y: 1, z: 0)
    stardomeVAD.pointee.points[3] = OGLPoint3D(x: -1, y: 1, z: 0)
    stardomeVAD.pointee.uvs.0![0] = OGLTextureCoord(u: 0, v: 0)
    stardomeVAD.pointee.uvs.0![1] = OGLTextureCoord(u: 6, v: 0)
    stardomeVAD.pointee.uvs.0![2] = OGLTextureCoord(u: 6, v: 6)
    stardomeVAD.pointee.uvs.0![3] = OGLTextureCoord(u: 0, v: 6)

    UnsafeMutableRawPointer(matRef).release()
}

// MARK: - Free level intro screen

private func freeLevelIntroScreen() {
    StopAllEffectChannels()
    MyFlushEvents()
    DeleteAllObjects()
    FreeAllSkeletonFiles(-1)
    InitSparkles() // this will actually delete all the sparkles
    DisposeSpriteGroup(Int32(SPRITE_GROUP_LEVELSPECIFIC))
    DisposeAllBG3DContainers()
    OGL_DisposeGameView()
}

// MARK: -

// MARK: - Move intro star dome

private let cMoveIntroStarDome: @convention(c) (UnsafeMutablePointer<ObjNode>?) -> Void = { theNodeOpt in
    let theNode = theNodeOpt!
    theNode.pointee.Rot.z += gFramesPerSecondFrac * 0.6
    theNode.updateTransforms()
}

// MARK: - Move level intro nano

private let cMoveLevelIntroNano: @convention(c) (UnsafeMutablePointer<ObjNode>?) -> Void = { theNodeOpt in
    moveLevelIntroNano(theNodeOpt!)
}

private func moveLevelIntroNano(_ theNode: UnsafeMutablePointer<ObjNode>) {
    var v = OGLVector3D()
    var p = OGLPoint3D()

    theNode.pointee.Coord = gWormholeDeformPoints[1]

    OGLPoint3D_Subtract(&gWormholeDeformPoints[4], &gWormholeDeformPoints[8], &v)
    v = v.normalized()

    SetAlignmentMatrix(&theNode.pointee.AlignmentMatrix, &v)

    theNode.updateTransforms()

    p.x = theNode.pointee.Coord.x * 0.5
    p.y = theNode.pointee.Coord.y * 0.5
    p.z = theNode.pointee.Coord.z - 500.0

    OGL_UpdateCameraFromTo(&gGameViewInfoPtr!.pointee.cameraPlacement.0.cameraLocation, &p, 0)
}

// MARK: - Move level intro worm

private let cMoveLevelIntroWorm: @convention(c) (UnsafeMutablePointer<ObjNode>?) -> Void = { theNodeOpt in
    let theNode = theNodeOpt!

    updateLevelIntroWormJoints(theNode)

    theNode.pointee.TextureTransformU += gFramesPerSecondFrac * 0.6
    theNode.pointee.TextureTransformV -= gFramesPerSecondFrac * 0.9
}

// MARK: - Update level intro worm joints

private var waveX: Float = 0
private var waveY: Float = 1.0

private func updateLevelIntroWormJoints(_ theNode: UnsafeMutablePointer<ObjNode>) {
    let skeleton = theNode.pointee.Skeleton!
    let skeletonDef = skeleton.pointee.skeletonDefinition!
    let fps = gFramesPerSecondFrac

    let numJoints = Int(skeletonDef.pointee.NumBones) // get # joints in this skeleton

    let scale = theNode.pointee.Scale.x

    // BUILD JOINT COORD TABLE

    waveX += fps * 0.5
    waveY += fps * 2.0

    var z: Float = 0
    var w: Float = 0
    for jointNum in 0..<numJoints {
        let q = Float(jointNum) * 80.0 // gets more wiggly the farther down the skeleton we go

        gWormholeDeformPoints[jointNum].x = sin(waveX + w) * q
        gWormholeDeformPoints[jointNum].y = sin(waveY + w) * q
        gWormholeDeformPoints[jointNum].z = z

        w += 0.16
        z -= 350.0
    }

    // TRANSFORM EACH JOINT TO WORLD-SPACE

    let up = OGLVector3D(x: 0, y: 1, z: 0)
    let jointMatricesBase = UnsafeMutableRawPointer(skeleton.pointer(to: \.jointTransformMatrix)!).assumingMemoryBound(to: OGLMatrix4x4.self)

    for jointNum in 0..<numJoints {
        var m = OGLMatrix4x4()
        var m2 = OGLMatrix4x4()
        var m3 = OGLMatrix4x4()

        // GET COORDS OF THIS SEGMENT

        let coord = gWormholeDeformPoints[jointNum]

        // GET PREVIOUS COORD FOR ROTATION CALCULATION

        var prevCoord = OGLPoint3D()
        if jointNum > 0 {
            prevCoord = gWormholeDeformPoints[jointNum - 1]
        }

        // TRANSFORM JOINT'S MATRIX TO WORLD COORDS

        m.setScale(scale, scale, scale)

        if jointNum > 0 {
            var coordVar = coord
            withUnsafePointer(to: up) { upPtr in
                SetLookAtMatrix(&m2, upPtr, &prevCoord, &coordVar)
            }
            m3 = m.multiplied(by: m2)
        } else {
            m3 = m
        }

        m.setTranslate(coord.x, coord.y, coord.z)
        jointMatricesBase[jointNum] = m3.multiplied(by: m)
    }
}

// MARK: -

// MARK: - Make screensaver objects

private func setupScreensaverObjects() {
    // PRESS ANY KEY

    var textDef = NewObjectDefinitionType()
    textDef.group = UInt8(ATLAS_GROUP_FONT1)
    textDef.coord = OGLPoint3D(x: 640 / 2, y: 450, z: 0)
    textDef.slot = Int16(SPRITE_SLOT)
    textDef.moveCall = cMovePressAnyKey
    textDef.scale = 0.35

    let text = gUserPrefersGamepad != 0 ? STR_PRESS_START : STR_PRESS_ANY_KEY
    let newObj = TextMesh_New(localized(text), Int32(kTextMeshAlignCenter), &textDef)
    newObj.pointee.ColorFilter.a = 0.6
    newObj.pointee.AnaglyphZ = 6.0

    // NANO LOGO

    var logoDef = NewObjectDefinitionType()
    logoDef.group = UInt8(SPRITE_GROUP_LEVELSPECIFIC)
    logoDef.type = UInt8(MAINMENU_SObjType_NanoLogo)
    logoDef.coord = OGLPoint3D(x: 20, y: 0, z: 0)
    logoDef.slot = Int16(SPRITE_SLOT)
    logoDef.scale = 150

    let logoObj = MakeSpriteObject(&logoDef, 0)!
    logoObj.pointee.AnaglyphZ = 6.0
}

// MARK: - Make credits objects

private func setupCreditsObjects() {
    // MAKE GRADIENT SO TEXT IS MORE READABLE

    var gradientDef = NewObjectDefinitionType()
    gradientDef.genre = UInt8(CUSTOM_GENRE)
    gradientDef.coord = OGLPoint3D(x: 0, y: 0, z: 0)
    gradientDef.slot = 150 // between wormhole and nano
    gradientDef.scale = 1
    gradientDef.drawCall = cDrawBottomGradient
    _ = MakeNewObject(&gradientDef)

    // MAKE TEXT

    var delay = kCreditFirstDelay

    for credit in kCreditsText {
        var textDef = NewObjectDefinitionType()
        textDef.group = UInt8(ATLAS_GROUP_FONT2)
        textDef.coord = OGLPoint3D(x: 640 / 2, y: 400, z: 0)
        textDef.slot = Int16(SPRITE_SLOT)
        textDef.scale = 0.4
        textDef.moveCall = cMoveCreditsLine

        let obj0 = TextMesh_New(credit.role, Int32(kTextMeshAlignCenter), &textDef)
        obj0.pointee.AnaglyphZ = 6.0
        obj0.pointee.ColorFilter = OGLColorRGBA(r: 1, g: 0.6, b: 0.2, a: 1)

        textDef.group = UInt8(ATLAS_GROUP_FONT1)
        textDef.coord.y += 32
        textDef.scale = 0.6
        let obj1 = TextMesh_New(credit.name, Int32(kTextMeshAlignCenter | kTextMeshSmallCaps), &textDef)
        obj1.pointee.AnaglyphZ = 6.0

        for obj in [obj0, obj1] {
            obj.pointee.ColorFilter.a = 0
            obj.pointee.Timer = -delay
        }

        delay += kCreditLineDuration + kCreditLinePause
    }

    // MAKE END LOGO

    var logoDef = NewObjectDefinitionType()
    logoDef.group = UInt8(SPRITE_GROUP_LEVELSPECIFIC)
    logoDef.type = UInt8(MAINMENU_SObjType_NanoLogo)
    logoDef.coord = OGLPoint3D(x: 640 / 2, y: 400 + 15, z: 0)
    logoDef.slot = Int16(SPRITE_SLOT)
    logoDef.scale = 250
    logoDef.moveCall = cMoveCreditsLine
    let logo = MakeSpriteObject(&logoDef, 1)!
    logo.pointee.AnaglyphZ = 6.0
    logo.pointee.Timer = -delay
    logo.pointee.Flag.0 = 1
    logo.pointee.ColorFilter.a = 0
}

// MARK: - Move press any key text

private let cMovePressAnyKey: @convention(c) (UnsafeMutablePointer<ObjNode>?) -> Void = { theNodeOpt in
    let theNode = theNodeOpt!
    theNode.pointee.Timer += gFramesPerSecondFrac * 4.0
    theNode.pointee.ColorFilter.a = 0.66 + sin(theNode.pointee.Timer) * 0.33
}

// MARK: - Move credits line

private let cMoveCreditsLine: @convention(c) (UnsafeMutablePointer<ObjNode>?) -> Void = { theNodeOpt in
    let theNode = theNodeOpt!
    theNode.pointee.Timer += gFramesPerSecondFrac
    let t = theNode.pointee.Timer

    let liveForever = theNode.pointee.Flag.0 != 0

    if t <= 0.0 {
        SetObjectVisible(theNode, 0)
    } else if !liveForever && t >= kCreditLineDuration {
        DeleteObject(theNode)
        return
    } else {
        SetObjectVisible(theNode, 1)

        var a: Float
        if t < kCreditFadeInTime {
            a = t / kCreditFadeInTime
        } else if !liveForever && t > kCreditLineDuration - kCreditFadeOutTime {
            a = 1 - (t - kCreditLineDuration + kCreditFadeOutTime) / kCreditFadeOutTime
        } else {
            a = 1
        }

        theNode.pointee.ColorFilter.a = a
    }
}

// MARK: - Draw bottom gradient

private let cDrawBottomGradient: @convention(c) (UnsafeMutablePointer<ObjNode>?) -> Void = { _ in
    OGL_PushState()
    SetInfobarSpriteState(0, 1)
    OGL_DisableTexture2D()
    OGL_EnableBlend()

    let y: Float = 200

    gRenderBackend.beginImmediate(.quads)
    gRenderBackend.setColor4f(0, 0, 0, 0)
    gRenderBackend.vertex2f(gLogicalRect.left, y)
    gRenderBackend.vertex2f(gLogicalRect.right, y)
    gRenderBackend.setColor4f(0, 0, 0, 1)
    gRenderBackend.vertex2f(gLogicalRect.right, gLogicalRect.bottom)
    gRenderBackend.vertex2f(gLogicalRect.left, gLogicalRect.bottom)
    gRenderBackend.endImmediate()

    OGL_PopState()
}
