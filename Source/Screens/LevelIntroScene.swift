// LevelIntroScene.swift - the "flying through the wormhole" scene itself,
// split out of LevelIntro.swift so the macOS screen-saver port
// (ports/Darwin, built with -DNANOSAUR_SCREENSAVER) can compile the scene
// without LevelIntro.swift's screen driver, which drags in the menu system
// (save-game menu tree), credits, and sound. Desktop builds compile BOTH
// files: DoLevelIntroScreen (LevelIntro.swift) drives this scene for the
// save-game/no-save/credits/screensaver modes exactly as before.

// IsStereo/IsStereoAnaglyph are parameterized C macros, which Swift can't import as callable symbols.
private func isStereo() -> Bool { gGamePrefs.stereoGlassesMode != UInt8(StereoGlassesMode.off.rawValue) }
private func isStereoAnaglyph() -> Bool {
    gGamePrefs.stereoGlassesMode == UInt8(StereoGlassesMode.anaglyphColor.rawValue) || gGamePrefs.stereoGlassesMode == UInt8(StereoGlassesMode.anaglyphMono.rawValue)
}

// MARK: - Setup level intro scene

// Builds the wormhole scene: view/fog/lights, the models+skeletons+sprites
// it needs, the wormhole skeleton, the nano+jetpack rig, and the star dome.
// Mode-specific extras (save menu, credits, screensaver text) and sound are
// the caller's business.
func SetupLevelIntroScene() {
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
        gEngine.view.anaglyphFocallength = 300.0
        gEngine.view.anaglyphEyeSeparation = 20.0

        if isStereoAnaglyph() {
            viewDef.lights.ambientColor = OGLColorRGBA(r: 0.8, g: 0.8, b: 0.8, a: 1.0)
        }
    }

    OGL_SetupGameView(&viewDef)

    // LOAD ART

    InitParticleSystem()
    InitSparkles()

    // LOAD MODELS

    ResolveDataFileSpec(":Models:playerparts.bg3d", &spec)
    ImportBG3D(&spec, Int32(MODEL_GROUP_PLAYER), Int16(VertexArrayRangeType.bg3dModels.rawValue))

    ResolveDataFileSpec(":Models:levelintro.bg3d", &spec)
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

    // MAKE PLAYER

    makeLevelIntroWormNano()

    // MAKE STAR DOME

    makeLevelIntroStarDome()
}

// MARK: - Make level intro worm player

#if NANOSAUR_SCREENSAVER
// Trimmed jetpack-alignment mover for the screen-saver build, replacing
// Player_Terrain.swift's MovePlayerJetpack (which belongs to the gameplay
// code this build doesn't compile). Reproduces exactly what the intro scene
// exercises: glue the jetpack+blue glow to the player skeleton's root joint
// and scroll the blue glow's UVs. The gun-turret sparkle shrink and the jet
// exhaust are skipped - the exhaust never fires in the intro (jetpackActive
// is never set), and the sparkle shrink just settles the glint scale.
private let cMoveIntroJetpack: @convention(c) (UnsafeMutablePointer<ObjNode>?) -> Void = { jetpackOpt in
    guard let jetpack = jetpackOpt else { return }
    let player = jetpack.pointee.ChainHead!
    let blue = jetpack.pointee.ChainNode!
    let fps = gEngine.framesPerSecondFrac

    var m = OGLMatrix4x4()
    FindJointFullMatrix(player, 0, &m)
    m.value.13 += 3.0 // offset y a tad to help alignment
    jetpack.pointee.BaseTransformMatrix = m
    SetObjectTransformMatrix(jetpack)

    jetpack.pointee.Coord.x = jetpack.pointee.BaseTransformMatrix.value.12
    jetpack.pointee.Coord.y = jetpack.pointee.BaseTransformMatrix.value.13
    jetpack.pointee.Coord.z = jetpack.pointee.BaseTransformMatrix.value.14

    blue.pointee.TextureTransformV -= fps * 1.5
    blue.pointee.TextureTransformU -= fps * 0.2

    blue.pointee.BaseTransformMatrix = m
    SetObjectTransformMatrix(blue)

    blue.pointee.Coord = jetpack.pointee.Coord
}
#endif

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
    #if NANOSAUR_SCREENSAVER
    def.moveCall = cMoveIntroJetpack
    #else
    def.moveCall = MovePlayerJetpack
    #endif
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

// MARK: - Free level intro scene

// Tears down everything SetupLevelIntroScene (and the mode-specific object
// makers layered on top of it) created. Sound teardown is the caller's
// business, matching setup.
func FreeLevelIntroScene() {
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
    theNode.pointee.Rot.z += gEngine.framesPerSecondFrac * 0.6
    theNode.updateTransforms()
}

// MARK: - Move level intro nano

private let cMoveLevelIntroNano: @convention(c) (UnsafeMutablePointer<ObjNode>?) -> Void = { theNodeOpt in
    moveLevelIntroNano(theNodeOpt!)
}

private func moveLevelIntroNano(_ theNode: UnsafeMutablePointer<ObjNode>) {
    var v = OGLVector3D()
    var p = OGLPoint3D()

    theNode.pointee.Coord = gEngine.screens.wormholeDeformPoints[1]

    OGLPoint3D_Subtract(&gEngine.screens.wormholeDeformPoints[4], &gEngine.screens.wormholeDeformPoints[8], &v)
    v = v.normalized()

    SetAlignmentMatrix(&theNode.pointee.AlignmentMatrix, &v)

    theNode.updateTransforms()

    p.x = theNode.pointee.Coord.x * 0.5
    p.y = theNode.pointee.Coord.y * 0.5
    p.z = theNode.pointee.Coord.z - 500.0

    OGL_UpdateCameraFromTo(&gEngine.game.viewInfoPtr!.pointee.cameraPlacement.0.cameraLocation, &p, 0)
}

// MARK: - Move level intro worm

private let cMoveLevelIntroWorm: @convention(c) (UnsafeMutablePointer<ObjNode>?) -> Void = { theNodeOpt in
    let theNode = theNodeOpt!

    updateLevelIntroWormJoints(theNode)

    theNode.pointee.TextureTransformU += gEngine.framesPerSecondFrac * 0.6
    theNode.pointee.TextureTransformV -= gEngine.framesPerSecondFrac * 0.9
}

// MARK: - Update level intro worm joints

private var waveX: Float = 0
private var waveY: Float = 1.0

private func updateLevelIntroWormJoints(_ theNode: UnsafeMutablePointer<ObjNode>) {
    let skeleton = theNode.pointee.Skeleton!
    let skeletonDef = skeleton.pointee.skeletonDefinition!
    let fps = gEngine.framesPerSecondFrac

    let numJoints = Int(skeletonDef.pointee.NumBones) // get # joints in this skeleton

    let scale = theNode.pointee.Scale.x

    // BUILD JOINT COORD TABLE

    waveX += fps * 0.5
    waveY += fps * 2.0

    var z: Float = 0
    var w: Float = 0
    for jointNum in 0..<numJoints {
        let q = Float(jointNum) * 80.0 // gets more wiggly the farther down the skeleton we go

        gEngine.screens.wormholeDeformPoints[jointNum].x = sin(waveX + w) * q
        gEngine.screens.wormholeDeformPoints[jointNum].y = sin(waveY + w) * q
        gEngine.screens.wormholeDeformPoints[jointNum].z = z

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

        let coord = gEngine.screens.wormholeDeformPoints[jointNum]

        // GET PREVIOUS COORD FOR ROTATION CALCULATION

        var prevCoord = OGLPoint3D()
        if jointNum > 0 {
            prevCoord = gEngine.screens.wormholeDeformPoints[jointNum - 1]
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

// MARK: - Make screensaver objects

func SetupLevelIntroScreensaverObjects() {
    // PRESS ANY KEY

    var textDef = NewObjectDefinitionType()
    textDef.group = UInt8(ATLAS_GROUP_FONT1)
    textDef.coord = OGLPoint3D(x: 640 / 2, y: 450, z: 0)
    textDef.slot = Int16(SPRITE_SLOT)
    textDef.moveCall = cMovePressAnyKey
    textDef.scale = 0.35

    #if NANOSAUR_SCREENSAVER
    // No gamepad concept in the screen saver - it's always a keyboard
    // (any input ends the saver anyway; the prompt is just flavor).
    let text = STR_PRESS_ANY_KEY
    #else
    let text = gEngine.input.userPrefersGamepad != 0 ? STR_PRESS_START : STR_PRESS_ANY_KEY
    #endif
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

// MARK: - Move press any key text

private let cMovePressAnyKey: @convention(c) (UnsafeMutablePointer<ObjNode>?) -> Void = { theNodeOpt in
    let theNode = theNodeOpt!
    theNode.pointee.Timer += gEngine.framesPerSecondFrac * 4.0
    theNode.pointee.ColorFilter.a = 0.66 + sin(theNode.pointee.Timer) * 0.33
}
