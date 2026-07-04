// Camera.swift - Port of Camera.c to Swift
//
// gCameraInExitMode, gDrawLensFlare, gCameraInDeathDiveMode, and
// gCameraMode stay defined in the stubbed Camera.c because other
// already-ported files read/write them directly via `extern` (including
// PlayerInternal.h's/InfobarInternal.h's Get/Set shims).

private let numFlares = 6

private let cameraDefaultDistFromMe: Float = 280.0
private let cameraWormholeDistFromMe: Float = cameraDefaultDistFromMe * 6.0

private let cameraLookAtYOff: Float = 100.0

private let maxCameraAccel: Float = 2.0

private let cameraTerrainMinDist: Float = 80.0

private var gAnaglyphCameraBackup = [OGLCameraPlacement](repeating: OGLCameraPlacement(), count: Int(MAX_PLAYERS)) // backup of original camera info before offsets applied

private var gCameraLookAtAccel: Float = 0
private var gCameraFromAccel: Float = 0

private var gSunCoord = OGLPoint3D()

private let gFlareOffsetTable: [Float] = [
    1.0,
    0.6,
    0.3,
    1.0 / 8.0,
    -0.25,
    -0.5,
]

private let gFlareScaleTable: [Float] = [
    0.30 * (4.0 / 3.0),
    0.06 * (4.0 / 3.0),
    0.10 * (4.0 / 3.0),
    0.20 * (4.0 / 3.0),
    0.03 * (4.0 / 3.0),
    0.10 * (4.0 / 3.0),
]

private let gFlareImageTable: [UInt8] = [
    UInt8(PARTICLE_SObjType_LensFlare0),
    UInt8(PARTICLE_SObjType_LensFlare1),
    UInt8(PARTICLE_SObjType_LensFlare2),
    UInt8(PARTICLE_SObjType_LensFlare3),
    UInt8(PARTICLE_SObjType_LensFlare2),
    UInt8(PARTICLE_SObjType_LensFlare1),
]

// IsStereo is a parameterized C macro, which Swift can't import as a callable symbol.
private func isStereo() -> Bool { gGamePrefs.stereoGlassesMode != UInt8(StereoGlassesMode.off.rawValue) }

// cameraPlacement is a fixed-size array (imports as a tuple); rebind to a pointer so it can be dynamically indexed.
@inline(__always) private func cameraPlacementsBase() -> UnsafeMutablePointer<OGLCameraPlacement> {
    UnsafeMutableRawPointer(gGameViewInfoPtr!.pointer(to: \.cameraPlacement)!).assumingMemoryBound(to: OGLCameraPlacement.self)
}

// MARK: - Get FOV depending on splitscreen mode

@c @implementation
public func GetSplitscreenPaneFOV() -> Float {
    if gVSMode == .none { // set FOV differently for multiplayer
        return 1.15
    } else {
        if gGamePrefs.splitScreenMode == UInt8(SplitscreenMode.horizontal.rawValue) { // smaller FOV for wide panes
            return 0.7
        } else {
            return 1.1
        }
    }
}

// MARK: - Draw lens flare

@c @implementation
public func DrawLensFlare() {
    var transColor = OGLColorRGBA(r: 1, g: 1, b: 1, a: 1)

    if gDrawLensFlare == 0 {
        return
    }

    // SET TAGS

    OGL_PushState()

    OGL_DisableLighting() // Turn OFF lighting
    OGL_DisableCullFace()
    glDisable(GLenum(GL_DEPTH_TEST))
    OGL_BlendFunc(GLenum(GL_SRC_ALPHA), GLenum(GL_ONE))
    OGL_SetColor4f(1, 1, 1, 1) // full white & alpha to start with

    // CALC SUN COORD

    let from = (cameraPlacementsBase() + Int(Int32(gCurrentSplitScreenPane))).pointee.cameraLocation
    gSunCoord.x = from.x - (gWorldSunDirection.x * gGameViewInfoPtr!.pointee.yon)
    gSunCoord.y = from.y - (gWorldSunDirection.y * gGameViewInfoPtr!.pointee.yon)
    gSunCoord.z = from.z - (gWorldSunDirection.z * gGameViewInfoPtr!.pointee.yon)

    // CALC DOT PRODUCT BETWEEN VIEW AND LIGHT VECTORS TO SEE IF OUT OF RANGE

    var sunVector = OGLVector3D()
    FastNormalizeVector(from.x - gSunCoord.x,
                         from.y - gSunCoord.y,
                         from.z - gSunCoord.z,
                         &sunVector)

    let placement = (cameraPlacementsBase() + Int(Int32(gCurrentSplitScreenPane)))
    var lookAtVector = OGLVector3D()
    FastNormalizeVector(placement.pointee.pointOfInterest.x - from.x,
                         placement.pointee.pointOfInterest.y - from.y,
                         placement.pointee.pointOfInterest.z - from.z,
                         &lookAtVector)

    var dot = lookAtVector.dot(sunVector)
    if dot >= 0.0 {
        gGlobalTransparency = 1.0
        OGL_PopState()
        return
    }

    dot = acos(dot) * -2.0 // get angle & modify it
    transColor.a = cos(dot) // get cos of modified angle

    // CALC SCREEN COORDINATE OF LIGHT

    let sunScreenCoord = gSunCoord.transformed(by: GetWorldToWindowMatrixEntry(Int32(gCurrentSplitScreenPane)).pointee)

    // CALC CENTER OF VIEWPORT

    var px: Int32 = 0
    var py: Int32 = 0
    var pw: Int32 = 0
    var ph: Int32 = 0
    OGL_GetCurrentViewport(&px, &py, &pw, &ph, gCurrentSplitScreenPane)
    let cx = Float(pw) / 2 + Float(px)
    let cy = Float(ph) / 2 + Float(py)

    // CALC VECTOR FROM CENTER TO LIGHT

    let dx = sunScreenCoord.x - cx
    let dy = sunScreenCoord.y - cy
    let length = sqrt(dx * dx + dy * dy)
    var axis = OGLVector3D()
    FastNormalizeVector(dx, dy, 0, &axis)

    // DRAW FLARES

    // INIT MATRICES

    glMatrixMode(GLenum(GL_MODELVIEW))
    glLoadIdentity()

    glMatrixMode(GLenum(GL_PROJECTION))
    glLoadIdentity()

    for i in 0..<numFlares {
        if i == 0 {
            gGlobalTransparency = 0.99 // sun is always full brightness (leave @ < 1 to ensure GL_BLEND)
        } else {
            gGlobalTransparency = transColor.a
        }

        MO_DrawMaterial(GetSpriteGroupPtr(Int32(SPRITE_GROUP_PARTICLES))![Int(gFlareImageTable[i])].materialObject?.assumingMemoryBound(to: MOMaterialObject.self)) // activate material

        if i == 1 { // always draw sun, but fade flares based on dot
            if transColor.a <= 0.0 { // see if faded all out
                break
            }
            OGL_SetColor4fv(&transColor)
        }

        let o = gFlareOffsetTable[i]

        let sy = gFlareScaleTable[i]
        let sx = sy * gCurrentPaneAspectRatio

        let x = cx + axis.x * length * o
        let y = cy + axis.y * length * o

        let fx = x / (Float(pw) / 2) - 1.0
        let fy = (Float(ph) - y) / (Float(ph) / 2) - 1.0

        glBegin(GLenum(GL_QUADS))
        glTexCoord2f(0, 0); glVertex2f(fx - sx, fy - sy)
        glTexCoord2f(1, 0); glVertex2f(fx + sx, fy - sy)
        glTexCoord2f(1, 1); glVertex2f(fx + sx, fy + sy)
        glTexCoord2f(0, 1); glVertex2f(fx - sx, fy + sy)
        glEnd()
    }

    // RESTORE MODES

    gGlobalTransparency = 1.0
    OGL_PopState()
}

// MARK: -

// MARK: - Init camera: terrain
//
// This MUST be called after the players have been created so that we know
// where to put the camera.

@c @implementation
public func InitCamera_Terrain(_ playerNum: Int16) {
    let playerObj = GetPlayerInfoEntry(Int32(playerNum))!.pointee.objNode

    resetCameraSettings()

    SetCameraInDeathDiveMode(Int32(playerNum), 0)

    // SET CAMERA STARTING COORDS

    if let playerObj {
        var r = playerObj.pointee.Rot.y

        let placement = (cameraPlacementsBase() + Int(Int32(playerNum)))

        // SPECIAL INIT FOR WORMHOLE START

        if Int(playerObj.pointee.Skeleton!.pointee.AnimNum) == Int(PlayerAnim.appearWormhole.rawValue) { // if coming out of a wormhole, move camera farther out to init
            let wormhole = GetPlayerInfoEntry(Int32(playerNum))!.pointee.wormhole!

            r += Float.pi * 0.8

            let dx = sin(r) * cameraWormholeDistFromMe
            let dz = cos(r) * cameraWormholeDistFromMe

            let x = wormhole.pointee.Coord.x + dx
            let z = wormhole.pointee.Coord.z + dz
            placement.pointee.cameraLocation.x = x
            placement.pointee.cameraLocation.z = z
            placement.pointee.cameraLocation.y = GetTerrainY(x, z) + 600.0

            gCameraFromAccel = 0
        }

        // START IN REGULAR TRACKING POSITION

        else {
            let dx = sin(r) * cameraDefaultDistFromMe
            let dz = cos(r) * cameraDefaultDistFromMe

            let x = playerObj.pointee.Coord.x + dx
            let z = playerObj.pointee.Coord.z + dz
            placement.pointee.cameraLocation.x = x
            placement.pointee.cameraLocation.z = z
            placement.pointee.cameraLocation.y = GetTerrainY(x, z) + 200.0

            gCameraFromAccel = maxCameraAccel
        }

        // SET LOOK-AT PT

        placement.pointee.pointOfInterest.x = playerObj.pointee.Coord.x
        placement.pointee.pointOfInterest.y = playerObj.pointee.Coord.y + cameraLookAtYOff
        placement.pointee.pointOfInterest.z = playerObj.pointee.Coord.z
    }
}

// MARK: - Reset camera settings

private func resetCameraSettings() {
    gCameraFromAccel = maxCameraAccel
    gCameraInExitMode = 0
    gCameraLookAtAccel = 8.0
}

// MARK: - Update cameras

@c @implementation
public func UpdateCameras() {
    let fps = gFramesPerSecondFrac
    var from = OGLPoint3D()
    var to = OGLPoint3D()
    var target = OGLPoint3D()
    var v = OGLVector3D()
    let up = OGLVector3D(x: 0, y: 1, z: 0)
    var m = OGLMatrix4x4()
    let tailOff = OGLPoint3D(x: 0, y: 60, z: cameraDefaultDistFromMe)
    let noseOff = OGLPoint3D(x: 0, y: 0, z: -600)

    if gTimeDemo != 0 { // don't do anything in time demo mode
        return
    }

    // ACCELERATE CAMERA TO MAX
    //
    // When starting @ a wormhole, gCameraFromAccel is 0.0 to prevent
    // the camera from moving.  Once we're out of the wormhole, we
    // accelerate gCameraFromAccel to it's regular value.

    if Int(GetPlayerInfoEntry(0)!.pointee.objNode!.pointee.Skeleton!.pointee.AnimNum) != Int(PlayerAnim.appearWormhole.rawValue) {
        gCameraFromAccel += fps * 0.6
        if gCameraFromAccel > maxCameraAccel {
            gCameraFromAccel = maxCameraAccel
        }
    }

    for playerNum in 0..<Int(gNumPlayers) {
        let pi = GetPlayerInfoEntry(Int32(playerNum))!
        guard let playerObj = pi.pointee.objNode else {
            continue
        }

        // SEE IF TOGGLE CAMERA MODE

        if SwIsNeedDown(Int(kNeed_CameraMode), Int(playerNum)) { // is button pressed?
            SetCameraMode(Int32(playerNum), GetCameraMode(Int32(playerNum)) + 1)
            if false { // gGamePrefs.stereoGlassesMode != StereoGlassesMode.off.rawValue)
                if GetCameraMode(Int32(playerNum)) > UInt8(CameraMode.anaglyphClose.rawValue) {
                    SetCameraMode(Int32(playerNum), 0)
                }
            } else {
                if GetCameraMode(Int32(playerNum)) > UInt8(CameraMode.firstPerson.rawValue) {
                    SetCameraMode(Int32(playerNum), 0)
                }
            }
        }

        if GetCameraMode(Int32(playerNum)) == UInt8(CameraMode.firstPerson.rawValue) {
            updateCamera_FirstPerson(Int16(playerNum))
            continue
        }

        guard let skeleton = playerObj.pointee.Skeleton else {
            SwFatal("MoveCameras: player has no skeleton!")
            continue
        }

        // SPECIAL FOR DUST DEVIL

        if Int(skeleton.pointee.AnimNum) == Int(PlayerAnim.dustDevil.rawValue) {
            moveCamera_DustDevil(playerObj)
            continue
        }

        // GET COORD DATA

        let placement = (cameraPlacementsBase() + Int(Int32(playerNum)))

        let oldCamX = placement.pointee.cameraLocation.x // get current/old cam coords
        let oldCamY = placement.pointee.cameraLocation.y
        let oldCamZ = placement.pointee.cameraLocation.z

        let oldPointOfInterestX = placement.pointee.pointOfInterest.x
        let oldPointOfInterestY = placement.pointee.pointOfInterest.y
        let oldPointOfInterestZ = placement.pointee.pointOfInterest.z

        // CALC LOOK AT POINT

        target = noseOff.transformed(by: playerObj.pointee.BaseTransformMatrix)

        var distX = target.x - oldPointOfInterestX
        var distY = target.y - oldPointOfInterestY
        var distZ = target.z - oldPointOfInterestZ

        // MOVE "TO"

        var delta = distX * (fps * gCameraLookAtAccel) // calc delta to move
        if abs(delta) > abs(distX) { // see if will overshoot
            delta = distX
        }
        to.x = oldPointOfInterestX + delta // move x

        delta = distY * (fps * gCameraLookAtAccel) // calc delta to move
        if abs(delta) > abs(distY) { // see if will overshoot
            delta = distY
        }
        to.y = oldPointOfInterestY + delta // move y

        delta = distZ * (fps * gCameraLookAtAccel) // calc delta to move
        if abs(delta) > abs(distZ) { // see if will overshoot
            delta = distZ
        }
        to.z = oldPointOfInterestZ + delta // move z

        // CALC FROM POINT

        if GetCameraInDeathDiveMode(Int32(playerNum)) == 0 {
            var fromAcc = gCameraFromAccel

            if gCameraInExitMode != 0 {
                target.x = gExitWormhole!.pointee.Coord.x
                target.z = gExitWormhole!.pointee.Coord.z

                target.y = GetTerrainY(target.x, target.z) + 600.0

                fromAcc *= 0.4 // don't go so fast
            } else {
                target = tailOff.transformed(by: playerObj.pointee.BaseTransformMatrix)
            }

            // MOVE CAMERA TOWARDS POINT

            distX = target.x - oldCamX
            distY = target.y - oldCamY
            distZ = target.z - oldCamZ

            delta = distX * (fps * fromAcc) // calc delta to move
            if abs(delta) > abs(distX) { // see if will overshoot
                delta = distX
            }
            from.x = oldCamX + delta // move x

            delta = distZ * (fps * fromAcc) // calc delta to move
            if abs(delta) > abs(distZ) { // see if will overshoot
                delta = distX
            }
            from.z = oldCamZ + delta // move z

            delta = distY * (fps * fromAcc) // calc delta to move
            if abs(delta) > abs(distY) { // see if will overshoot
                delta = distY
            }
            from.y = oldCamY + delta // move y
        } else {
            var mm = OGLMatrix4x4()

            OGLMatrix4x4_SetRotateAboutPoint(&mm, &playerObj.pointee.Coord, 0, fps * 0.4, 0)
            from = placement.pointee.cameraLocation.transformed(by: mm)
            from.y += fps * 100.0
        }

        // KEEP BELOW CEILING

        var terrainY = CalcPlayerMaxAltitude(from.x, from.z) - 300.0
        if from.y > terrainY {
            from.y = terrainY
        }

        // MAKE SURE ABOVE TERRAIN

        terrainY = GetTerrainY(from.x, from.z) + cameraTerrainMinDist
        if from.y < terrainY {
            from.y = terrainY
        }

        // UPDATE CAMERA INFO

        // CALC CAMERA TILT

        v.x = to.x - from.x // calc sight vector
        v.y = to.y - from.y
        v.z = to.z - from.z
        FastNormalizeVector(v.x, v.y, v.z, &v)

        pi.pointee.camera.cameraAim = v

        if isStereo() { // exaggerate z-rot in anaglyph mode
            OGLMatrix4x4_SetRotateAboutAxis(&m, &v, playerObj.pointee.Rot.z * 0.3)
        } else {
            OGLMatrix4x4_SetRotateAboutAxis(&m, &v, playerObj.pointee.Rot.z * 0.2)
        }

        v = up.transformed(by: m) // transform the "up" vector to give us tilt
        OGL_UpdateCameraFromToUp(&from, &to, &v, Int32(playerNum)) // update camera settings

        // UPDATE PLAYER'S CAMERA INFO

        pi.pointee.camera.cameraLocation = from
        pi.pointee.camera.pointOfInterest = to
    }
}

// MARK: - Move camera: dust devil

private func moveCamera_DustDevil(_ player: UnsafeMutablePointer<ObjNode>) {
    let p = player.pointee.PlayerNum
    let fps = gFramesPerSecondFrac

    let devil = GetPlayerInfoEntry(Int32(p))!.pointee.dustDevilObj!

    let placement = (cameraPlacementsBase() + Int(Int32(p)))
    var camCoord = placement.pointee.cameraLocation // get old cam coords

    // CALC VECTOR FROM DEVIL TO CAMERA

    var v = OGLVector3D()
    v.x = camCoord.x - devil.pointee.Coord.x
    v.z = camCoord.z - devil.pointee.Coord.z
    FastNormalizeVector(v.x, 0, v.z, &v)

    // MOVE CAMERA

    camCoord.x += v.x * 600.0 * fps
    camCoord.z += v.z * 600.0 * fps
    camCoord.y -= 400.0 * fps

    let terrainY = GetTerrainY(camCoord.x, camCoord.z) + cameraTerrainMinDist // keep above terrain
    if camCoord.y < terrainY {
        camCoord.y = terrainY
    }

    OGL_UpdateCameraFromTo(&camCoord, nil, Int32(p)) // update camera settings
}

// MARK: - Update camera: first person

private func updateCamera_FirstPerson(_ i: Int16) {
    var to = OGLPoint3D()
    var v = OGLVector3D()
    var up = OGLVector3D()
    let forward = OGLVector3D(x: 0, y: 0, z: -1)

    let pi = GetPlayerInfoEntry(Int32(i))!
    guard let player = pi.pointee.objNode else {
        return
    }

    // CALC FORWARD VECTOR

    v = forward.transformed(by: player.pointee.BaseTransformMatrix)

    // CALC UP VECTOR

    up = gUp.transformed(by: player.pointee.BaseTransformMatrix)

    to.x = player.pointee.Coord.x + v.x
    to.y = player.pointee.Coord.y + v.y
    to.z = player.pointee.Coord.z + v.z

    OGL_UpdateCameraFromToUp(&player.pointee.Coord, &to, &up, Int32(i)) // update camera settings

    // UPDATE PLAYER'S CAMERA INFO

    pi.pointee.camera.cameraLocation = player.pointee.Coord
    pi.pointee.camera.pointOfInterest = to
}

// MARK: -

// MARK: - Prep anaglyph cameras
//
// Make a copy of the camera's real coord info before we do anaglyph offsetting.

@c @implementation
public func PrepAnaglyphCameras() {
    for i in 0..<Int(gNumPlayers) {
        gAnaglyphCameraBackup[i] = (cameraPlacementsBase() + Int(Int32(i))).pointee
    }
}

// MARK: - Restore cameras from anaglyph

@c @implementation
public func RestoreCamerasFromAnaglyph() {
    for i in 0..<Int(gNumPlayers) {
        (cameraPlacementsBase() + Int(Int32(i))).pointee = gAnaglyphCameraBackup[i]
    }
}

// MARK: - Calc anaglyph camera offset

@c @implementation
public func CalcAnaglyphCameraOffset(_ pane: UInt8, _ pass: UInt8) {
    var sep = gAnaglyphEyeSeparation

    if pass > 0 {
        sep = -sep
    }

    // CALC CAMERA'S X-AXIS

    var aim = OGLVector3D()
    aim.x = gAnaglyphCameraBackup[Int(pane)].pointOfInterest.x - gAnaglyphCameraBackup[Int(pane)].cameraLocation.x
    aim.y = gAnaglyphCameraBackup[Int(pane)].pointOfInterest.y - gAnaglyphCameraBackup[Int(pane)].cameraLocation.y
    aim.z = gAnaglyphCameraBackup[Int(pane)].pointOfInterest.z - gAnaglyphCameraBackup[Int(pane)].cameraLocation.z
    aim = aim.normalized()

    let xaxis = gAnaglyphCameraBackup[Int(pane)].upVector.cross(aim)

    // OFFSET CAMERA FROM

    let placement = (cameraPlacementsBase() + Int(Int32(pane)))
    placement.pointee.cameraLocation.x = gAnaglyphCameraBackup[Int(pane)].cameraLocation.x + (xaxis.x * sep)
    placement.pointee.cameraLocation.z = gAnaglyphCameraBackup[Int(pane)].cameraLocation.z + (xaxis.z * sep)
    placement.pointee.cameraLocation.y = gAnaglyphCameraBackup[Int(pane)].cameraLocation.y + (xaxis.y * sep)

    // OFFSET CAMERA TO

    placement.pointee.pointOfInterest.x = gAnaglyphCameraBackup[Int(pane)].pointOfInterest.x + (xaxis.x * sep)
    placement.pointee.pointOfInterest.z = gAnaglyphCameraBackup[Int(pane)].pointOfInterest.z + (xaxis.z * sep)
    placement.pointee.pointOfInterest.y = gAnaglyphCameraBackup[Int(pane)].pointOfInterest.y + (xaxis.y * sep)
}
