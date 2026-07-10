// Items.swift - Port of Items.c to Swift

private let leafDefaultWobbleMag: Float = 4.0
private let leafDefaultWobbleSpeed: Float = 1.0

private var gCloudScroll = OGLVector2D()

// MARK: - Init items manager

func InitItemsManager() {
    InitForestDoors()
    InitZaps()
    InitWormholes()
    InitDustDevilMemory()

    CreateCyclorama()
    createCloudLayer()

    // UPDATE SONG

    // if (gSongMovie)
    //     MoviesTask(gSongMovie, 0);
}

// MARK: - Create cyclorama

func CreateCyclorama() {
    var def = NewObjectDefinitionType()
    def.group = UInt8(MODEL_GROUP_LEVELSPECIFIC)
    def.type = 0 // cyc is always 1st model in level bg3d files
    def.coord = OGLPoint3D(x: 0, y: 0, z: 0)
    def.flags = UInt32(STATUS_BIT_DONTCULL | STATUS_BIT_NOLIGHTING | STATUS_BIT_NOFOG) // |STATUS_BIT_NOZWRITES;
    def.slot = Int16(TERRAIN_SLOT) + 1 // draw after terrain for better performance since terrain blocks much of the pixels
    def.moveCall = nil
    def.drawCall = DrawCyclorama
    def.rot = 0
    def.scale = gGameViewInfoPtr!.pointee.yon * 0.01

    _ = MakeNewDisplayGroupObject(&def)
}

// MARK: - Draw cyclorama

func DrawCyclorama(_ theNodeOpt: UnsafeMutablePointer<ObjNode>?) {
    let theNode = theNodeOpt!
    let cameraCoord = cameraPlacementsBase()[Int(gCurrentSplitScreenPane)].cameraLocation

    gRenderBackend.setAlphaTestEnabled(false) // --------

    // UPDATE CYCLORAMA COORD INFO

    theNode.pointee.Coord.x = cameraCoord.x
    theNode.pointee.Coord.y = cameraCoord.y
    theNode.pointee.Coord.z = cameraCoord.z
    theNode.updateTransforms()

    // DRAW THE OBJECT

    MO_DrawObject(theNode.pointee.BaseGroup)

    gRenderBackend.setAlphaTestEnabled(true) // --------
}

// cameraPlacement is a fixed-size array (imports as a tuple); rebind to a pointer so it can be dynamically indexed.
@inline(__always) private func cameraPlacementsBase() -> UnsafeMutablePointer<OGLCameraPlacement> {
    UnsafeMutableRawPointer(gGameViewInfoPtr!.pointer(to: \.cameraPlacement)!).assumingMemoryBound(to: OGLCameraPlacement.self)
}

// MARK: - Create cloud layer

private func createCloudLayer() {
    if gGamePrefs.isLowRenderQuality { // don't do clouds in low-quality mode
        return
    }

    var def = NewObjectDefinitionType()
    def.group = UInt8(MODEL_GROUP_LEVELSPECIFIC)
    def.type = UInt8(LEVEL1_ObjType_CloudGrid)
    def.coord = OGLPoint3D(x: 0, y: 0, z: 0)
    def.flags = UInt32(STATUS_BIT_DONTCULL | STATUS_BIT_NOLIGHTING | STATUS_BIT_NOFOG | STATUS_BIT_DOUBLESIDED | STATUS_BIT_NOZWRITES)
    def.slot = Int16(TERRAIN_SLOT) + 2 // draw after sky dome
    def.rot = 0
    def.scale = gGameViewInfoPtr!.pointee.yon * 0.85
    def.moveCall = cMoveCloudLayer
    def.drawCall = cDrawCloudLayer

    let newObj = MakeNewDisplayGroupObject(&def)!

    newObj.pointee.TextureTransformU = 0
    newObj.pointee.TextureTransformV = 0
}

// MARK: - Move cloud layer

private let cMoveCloudLayer: @convention(c) (UnsafeMutablePointer<ObjNode>?) -> Void = { _ in
    gCloudScroll.x += gFramesPerSecondFrac * 0.02
    gCloudScroll.y += gFramesPerSecondFrac * 0.03
}

// MARK: - Draw cloud layer

private let cDrawCloudLayer: @convention(c) (UnsafeMutablePointer<ObjNode>?) -> Void = { theNodeOpt in
    let theNode = theNodeOpt!
    let cameraCoord = cameraPlacementsBase()[Int(gCurrentSplitScreenPane)].cameraLocation

    gRenderBackend.setAlphaTestEnabled(false) // --------

    // UPDATE CYCLORAMA COORD INFO

    theNode.pointee.Coord.x = cameraCoord.x
    theNode.pointee.Coord.y = 4000
    theNode.pointee.Coord.z = cameraCoord.z
    theNode.updateTransforms()

    // UPDATE SCROLLING

    theNode.pointee.TextureTransformU = cameraCoord.x * 0.0001 + gCloudScroll.x
    theNode.pointee.TextureTransformV = cameraCoord.z * -0.0001 + gCloudScroll.y

    gRenderBackend.matrixMode(.texture) // set texture matrix
    gRenderBackend.translate(theNode.pointee.TextureTransformU, theNode.pointee.TextureTransformV, 0)
    gRenderBackend.matrixMode(.modelview)

    // DRAW THE OBJECT

    MO_DrawObject(theNode.pointee.BaseGroup)

    // RESET UV MATRIX

    gRenderBackend.matrixMode(.texture)
    gRenderBackend.loadIdentity()
    gRenderBackend.matrixMode(.modelview)

    gRenderBackend.setAlphaTestEnabled(true) // --------
}

// MARK: -

// MARK: - Add rock

extension UnsafeMutablePointer where Pointee == TerrainItemEntryType {
    @discardableResult
    func addRock(x: Float, z: Float) -> UInt8 {
        let base: Int32
        let rot = Int(pointee.parm.1)

        switch gLevelNum {
        case Int16(LevelNum.adventure1.rawValue), Int16(LevelNum.flag2.rawValue), Int16(LevelNum.battle1.rawValue):
            base = Int32(LEVEL1_ObjType_Rock1)

        case Int16(LevelNum.adventure2.rawValue), Int16(LevelNum.race2.rawValue), Int16(LevelNum.battle2.rawValue):
            base = Int32(LEVEL2_ObjType_Rock_Small1)

        default:
            SwFatal("AddRock: brian needs to assign rocks to this level")
            return 0
        }

        var def = NewObjectDefinitionType()
        def.group = UInt8(MODEL_GROUP_LEVELSPECIFIC)
        def.type = UInt8(base + Int32(pointee.parm.0))
        def.scale = 2.0 + RandomFloat2() * 0.3
        def.coord.x = x
        def.coord.z = z
        def.flags = gAutoFadeStatusBits
        def.slot = 491
        def.moveCall = MoveStaticObject
        def.rot = (rot == 0) ? (RandomFloat() * SwPI2) : (Float(rot - 1) * (SwPI2 / 8.0))

        def.coord.y = GetMinTerrainY(x, z, Int16(def.group), Int16(def.type), def.scale) - GetObjectGroupBBox(Int32(def.group), Int32(def.type)).min.y

        let newObj = MakeNewDisplayGroupObject(&def)!

        newObj.pointee.TerrainItemPtr = self // keep ptr to item list

        // SET COLLISION STUFF

        newObj.pointee.CType = UInt32(CTYPE_SOLIDTOENEMY | CTYPE_PLAYERTEST | CTYPE_WEAPONTEST)
        newObj.pointee.CBits = UInt32(CBITS_ALLSOLID)
        CreateCollisionBoxFromBoundingBox_Rotated(newObj, 0.7, 0.8)

        return 1 // item was added
    }
}

// MARK: - Add river rock

extension UnsafeMutablePointer where Pointee == TerrainItemEntryType {
    @discardableResult
    func addRiverRock(x: Float, z: Float) -> UInt8 {
        var def = NewObjectDefinitionType()
        def.group = UInt8(MODEL_GROUP_LEVELSPECIFIC)
        def.type = UInt8(Int32(LEVEL1_ObjType_RiverRock1) + Int32(pointee.parm.0))
        def.scale = 2.0 + RandomFloat2() * 0.3
        def.coord.x = x
        def.coord.z = z
        def.flags = gAutoFadeStatusBits
        def.slot = 491
        def.moveCall = MoveStaticObject
        def.rot = RandomFloat() * SwPI2

        def.coord.y = GetMinTerrainY(x, z, Int16(def.group), Int16(def.type), def.scale) - GetObjectGroupBBox(Int32(def.group), Int32(def.type)).min.y

        let newObj = MakeNewDisplayGroupObject(&def)!

        newObj.pointee.TerrainItemPtr = self // keep ptr to item list

        // SET COLLISION STUFF

        newObj.pointee.CType = UInt32(CTYPE_SOLIDTOENEMY | CTYPE_PLAYERTEST | CTYPE_WEAPONTEST)
        newObj.pointee.CBits = UInt32(CBITS_ALLSOLID)
        CreateCollisionBoxFromBoundingBox_Rotated(newObj, 1, 1)

        return 1 // item was added
    }
}

// MARK: -

// MARK: - Add gas mound

extension UnsafeMutablePointer where Pointee == TerrainItemEntryType {
    @discardableResult
    func addGasMound(x: Float, z: Float) -> UInt8 {
        var def = NewObjectDefinitionType()
        def.group = UInt8(MODEL_GROUP_LEVELSPECIFIC)
        def.type = UInt8(Int32(LEVEL1_ObjType_GasMound1) + Int32(pointee.parm.0))
        def.scale = 3.0 + RandomFloat2() * 0.3
        def.coord.x = x
        def.coord.z = z
        def.flags = gAutoFadeStatusBits
        def.slot = 197
        def.moveCall = cMoveGasMound
        def.rot = RandomFloat() * SwPI2

        def.coord.y = GetMinTerrainY(x, z, Int16(def.group), Int16(def.type), def.scale) - GetObjectGroupBBox(Int32(def.group), Int32(def.type)).min.y

        let newObj = MakeNewDisplayGroupObject(&def)!

        newObj.pointee.TerrainItemPtr = self // keep ptr to item list

        newObj.pointee.Kind = Int32(pointee.parm.0)

        // SET COLLISION STUFF

        newObj.pointee.CType = UInt32(CTYPE_SOLIDTOENEMY | CTYPE_PLAYERTEST | CTYPE_WEAPONTEST)
        newObj.pointee.CBits = UInt32(CBITS_ALLSOLID)
        CreateCollisionBoxFromBoundingBox_Rotated(newObj, 1, 1)

        return 1 // item was added
    }
}

// MARK: - Move gas mound

private let ventOff: [OGLPoint3D] = [
    OGLPoint3D(x: 2.163, y: 125.091, z: -1.907),
    OGLPoint3D(x: 19.385, y: 69.243, z: 2.243),
    OGLPoint3D(x: 5.189, y: 22.168, z: -5.504),
]

private let cMoveGasMound: @convention(c) (UnsafeMutablePointer<ObjNode>?) -> Void = { theNodeOpt in
    let theNode = theNodeOpt!
    let fps = gFramesPerSecondFrac

    if TrackTerrainItem(theNode) != 0 { // just check to see if it's gone
        DeleteObject(theNode)
        return
    }

    // SEE IF SMOKE HITS PLAYER

    for i in 0..<Int(gNumPlayers) {
        if GetPlayerIsDead(Int32(i)) == 0 { // ingore dead players
            let pi = GetPlayerInfoEntry(Int32(i))
            var dist = CalcQuickDistance(theNode.pointee.Coord.x, theNode.pointee.Coord.z, pi.pointee.coord.x, pi.pointee.coord.z)

            if dist < 150.0 {
                dist = pi.pointee.coord.y - theNode.pointee.Coord.y
                if dist < 700.0 {
                    if !pi.pointee.objNode!.pointee.Skeleton!.isAnim(.disoriented) { // play effect on 1st hit
                        PlayEffect3D(Int16(EFFECT_BODYHIT), &pi.pointee.coord)
                        PlayRumbleEffect(Int16(EFFECT_BODYHIT), Int32(i))
                    }

                    _ = PlayerLoseHealth(Int16(i), fps * 0.1, .deathDive, nil, 1)
                }
            }
        }
    }

    // MAKE SMOKE

    theNode.pointee.ParticleTimer -= fps // see if add smoke
    if theNode.pointee.ParticleTimer <= 0.0 {
        theNode.pointee.ParticleTimer += 0.05 // reset timer

        var particleGroup = theNode.pointee.ParticleGroup
        let magicNum = theNode.pointee.ParticleMagicNum

        if particleGroup == -1 || VerifyParticleGroupMagicNum(particleGroup, magicNum) == 0 {
            let newMagicNum = MyRandomLong() // generate a random magic num
            theNode.pointee.ParticleMagicNum = newMagicNum

            gNewParticleGroupDef.magicNum = newMagicNum
            gNewParticleGroupDef.particleType = .fallingSparks
            gNewParticleGroupDef.flags = UInt32(PARTICLE_FLAGS_DONTCHECKGROUND)
            gNewParticleGroupDef.gravity = 100
            gNewParticleGroupDef.magnetism = 0
            gNewParticleGroupDef.baseScale = 15.0
            gNewParticleGroupDef.decayRate = -2.5
            gNewParticleGroupDef.fadeRate = 0.25
            gNewParticleGroupDef.particleTextureNum = UInt8(PARTICLE_SObjType_GasCloud)
            gNewParticleGroupDef.srcBlend = GL_SRC_ALPHA
            gNewParticleGroupDef.dstBlend = GL_ONE_MINUS_SRC_ALPHA
            particleGroup = NewParticleGroup(&gNewParticleGroupDef)
            theNode.pointee.ParticleGroup = particleGroup
        }

        if particleGroup != -1 {
            var p = ventOff[Int(theNode.pointee.Kind)].transformed(by: theNode.pointee.BaseTransformMatrix)

            let x = p.x
            let y = p.y
            let z = p.z

            for _ in 0..<2 {
                var d = OGLVector3D()

                p.x = x + RandomFloat2() * 15.0
                p.y = y + RandomFloat() * 10.0
                p.z = z + RandomFloat2() * 15.0

                d.x = RandomFloat2() * 30.0
                d.y = 300.0 + RandomFloat() * 150.0
                d.z = RandomFloat2() * 30.0

                var newParticleDef = NewParticleDefType()
                newParticleDef.groupNum = particleGroup
                newParticleDef.scale = RandomFloat() + 1.0
                newParticleDef.rotZ = RandomFloat() * SwPI2
                newParticleDef.rotDZ = RandomFloat2() * 2.0
                newParticleDef.alpha = 0.6

                let stop: Bool = withUnsafeMutablePointer(to: &p) { pPtr in
                    withUnsafeMutablePointer(to: &d) { dPtr in
                        newParticleDef.where = pPtr
                        newParticleDef.delta = dPtr
                        return AddParticleToGroup(&newParticleDef) != 0
                    }
                }
                if stop {
                    theNode.pointee.ParticleGroup = -1
                    break
                }
            }
        }
    }
}

// MARK: -

// MARK: - Trigger callback: misc smackable object

// Returns TRUE if want to handle hit as a solid
func DoTrig_MiscSmackableObject(_ trigger: UnsafeMutablePointer<ObjNode>!, _ theNode: UnsafeMutablePointer<ObjNode>!) -> UInt8 {
    if PlayerSmackedIntoObject(theNode, trigger, .explode) != 0 {
        return 0
    }

    return 1
}

// MARK: -

// MARK: - Add asteroid

extension UnsafeMutablePointer where Pointee == TerrainItemEntryType {
    @discardableResult
    func addAsteroid(x: Float, z: Float) -> UInt8 {
        var def = NewObjectDefinitionType()
        def.group = UInt8(MODEL_GROUP_LEVELSPECIFIC)
        def.type = UInt8(Int32(LEVEL3_ObjType_Asteroid_Cracked) + Int32(pointee.parm.0))
        def.scale = 4.0 + RandomFloat2() * 1.0
        def.coord.x = x
        def.coord.z = z
        def.flags = gAutoFadeStatusBits
        def.slot = 197
        def.moveCall = nil
        def.rot = RandomFloat() * SwPI2

        def.coord.y = GetMinTerrainY(x, z, Int16(def.group), Int16(def.type), def.scale) - GetObjectGroupBBox(Int32(def.group), Int32(def.type)).min.y

        let newObj = MakeNewDisplayGroupObject(&def)!

        newObj.pointee.TerrainItemPtr = self // keep ptr to item list

        newObj.pointee.Kind = Int32(pointee.parm.0)

        // SET COLLISION STUFF

        newObj.pointee.CType = UInt32(CTYPE_SOLIDTOENEMY | CTYPE_PLAYERTEST | CTYPE_WEAPONTEST)
        newObj.pointee.CBits = UInt32(CBITS_ALLSOLID)
        CreateCollisionBoxFromBoundingBox_Rotated(newObj, 1, 1)

        return 1 // item was added
    }
}
