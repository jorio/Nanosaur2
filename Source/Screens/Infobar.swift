// Infobar.swift - Port of Infobar.c to Swift
//
// gLogicalRect stays defined in Infobar.c and `extern`'d via game.h:
// LevelIntro.c and IntroStory.c (still unported) read it directly.
// g640x480Scaling and gHideInfobar aren't referenced by any other file, so
// they move into private Swift state along with everything else here (the
// blinking-egg state, the overhead-map/health/shield/fuel mesh data), which
// was all `static` (file-private) in C.

private let SPLITSCREEN_DIVIDER_THICKNESS: Float = 1

private var g640x480Scaling: Float = 1
private var gHideInfobar: UInt8 = 0

private func isStereo() -> Bool { gGamePrefs.stereoGlassesMode != UInt8(STEREO_GLASSES_MODE_OFF) }

private let MAP_SCALE: Float = 80.0
private let MAP_SCALE2: Float = MAP_SCALE * 0.8 * 0.5

private let LIVES_SCALE: Float = 25.0

private let WEAPON_SCALE: Float = 85.0

private let HEALTH_SCALE: Float = 43.0
private let HEALTH_SCALE2: Float = HEALTH_SCALE * 0.9 * 0.5 // smaller scale for the red meter sprite

private let SHIELD_SCALE: Float = HEALTH_SCALE
private let SHIELD_SCALE2: Float = HEALTH_SCALE2

private let FUEL_SCALE: Float = HEALTH_SCALE
private let FUEL_SCALE2: Float = HEALTH_SCALE2

private let PLAYER_SCALE: Float = 60.0

private let EGGS_SCALE: Float = 14.0

private let CAP_EGGS_SCALE: Float = 25.0

private let ARROW_SCALE: Float = 37.5
private let GUNSIGHT_SCALE: Float = 15.0
private let DIGIT_WIDTH: Float = 0.58
private let INFOBAR_ANAGLYPHZ_Z: Float = 0.0

private func mapX() -> Float { anchorRight(MAP_SCALE - 25) }
private func mapY() -> Float { anchorBottom(MAP_SCALE * 0.6) }

private func livesX() -> Float { anchorLeft(0) }
private func livesY() -> Float { anchorBottom(LIVES_SCALE * 0.6 + 22.5) }

private func weaponX() -> Float { anchorLeft(150) }
private func weaponY() -> Float { anchorTop(0) }

private func healthX() -> Float { anchorLeft(HEALTH_SCALE / 2) }
private func healthY() -> Float { anchorTop(HEALTH_SCALE / 2) }

private func shieldX() -> Float { healthX() + HEALTH_SCALE }
private func shieldY() -> Float { healthY() }

private func fuelX() -> Float { shieldX() + SHIELD_SCALE }
private func fuelY() -> Float { healthY() }

private func playerX() -> Float { anchorLeft(0) }
private func playerY() -> Float { anchorTop(HEALTH_SCALE) }

private func eggsX() -> Float { anchorRight(82) }
private func eggsY() -> Float { anchorTop(0) }

private func capEggsX() -> Float { anchorRight(120) }
private func capEggsY() -> Float { anchorTop(0) }

// MARK: - State

private var gBlinkingEggType: Int32 = -1
private var gBlinkingEggTimer: Float = 0

// OVERHEAD MAP
private var gOverheadMapMaterial: UnsafeMutablePointer<MOMaterialObject>?

private var gOHMTriMesh = MOVertexArrayData()
private let gOHMTriangles = AllocPtrClear(MemoryLayout<MOTriangleIndecies>.size * 2)!.assumingMemoryBound(to: MOTriangleIndecies.self)
private let gOHMuv1 = AllocPtrClear(MemoryLayout<OGLTextureCoord>.size * 4)!.assumingMemoryBound(to: OGLTextureCoord.self)
private let gOHMuv2 = AllocPtrClear(MemoryLayout<OGLTextureCoord>.size * 4)!.assumingMemoryBound(to: OGLTextureCoord.self)
private let gOHMPoints = AllocPtrClear(MemoryLayout<OGLPoint3D>.size * 4)!.assumingMemoryBound(to: OGLPoint3D.self)

// HEALTH
private var gHealthTriMesh = MOVertexArrayData()
private let gHealthTriangles = AllocPtrClear(MemoryLayout<MOTriangleIndecies>.size * 2)!.assumingMemoryBound(to: MOTriangleIndecies.self)
private let gHealthuv1 = AllocPtrClear(MemoryLayout<OGLTextureCoord>.size * 4)!.assumingMemoryBound(to: OGLTextureCoord.self)
private let gHealthuv2 = AllocPtrClear(MemoryLayout<OGLTextureCoord>.size * 4)!.assumingMemoryBound(to: OGLTextureCoord.self)
private let gHealthPoints = AllocPtrClear(MemoryLayout<OGLPoint3D>.size * 4)!.assumingMemoryBound(to: OGLPoint3D.self)

// SHIELD
private var gShieldTriMesh = MOVertexArrayData()
private let gShieldTriangles = AllocPtrClear(MemoryLayout<MOTriangleIndecies>.size * 2)!.assumingMemoryBound(to: MOTriangleIndecies.self)
private let gShielduv1 = AllocPtrClear(MemoryLayout<OGLTextureCoord>.size * 4)!.assumingMemoryBound(to: OGLTextureCoord.self)
private let gShielduv2 = AllocPtrClear(MemoryLayout<OGLTextureCoord>.size * 4)!.assumingMemoryBound(to: OGLTextureCoord.self)
private let gShieldPoints = AllocPtrClear(MemoryLayout<OGLPoint3D>.size * 4)!.assumingMemoryBound(to: OGLPoint3D.self)

// FUEL
private var gFuelTriMesh = MOVertexArrayData()
private let gFuelTriangles = AllocPtrClear(MemoryLayout<MOTriangleIndecies>.size * 2)!.assumingMemoryBound(to: MOTriangleIndecies.self)
private let gFueluv1 = AllocPtrClear(MemoryLayout<OGLTextureCoord>.size * 4)!.assumingMemoryBound(to: OGLTextureCoord.self)
private let gFueluv2 = AllocPtrClear(MemoryLayout<OGLTextureCoord>.size * 4)!.assumingMemoryBound(to: OGLTextureCoord.self)
private let gFuelPoints = AllocPtrClear(MemoryLayout<OGLPoint3D>.size * 4)!.assumingMemoryBound(to: OGLPoint3D.self)

// The three meter meshes (health/shield/fuel) all share the same quad
// geometry/triangle layout and UV scroll setup; this factors out the
// one-time setup shared by all three.
private func setUpMeterQuad(triangles: UnsafeMutablePointer<MOTriangleIndecies>, uv1: UnsafeMutablePointer<OGLTextureCoord>, uv2: UnsafeMutablePointer<OGLTextureCoord>, points: UnsafeMutablePointer<OGLPoint3D>, halfSize: Float) {
    triangles[0].vertexIndices = (0, 1, 2)
    triangles[1].vertexIndices = (2, 0, 3)

    for i in 0..<4 {
        uv1[i] = OGLTextureCoord(u: 0, v: 1)
        uv2[i] = OGLTextureCoord(u: 0, v: 1)
    }
    uv1[1].u = 1; uv1[1].v = 1
    uv1[2].u = 1; uv1[2].v = 0
    uv1[3].u = 0; uv1[3].v = 0
    uv2[1].u = 1; uv2[1].v = 1
    uv2[2].u = 1; uv2[2].v = 0
    uv2[3].u = 0; uv2[3].v = 0

    points[0] = OGLPoint3D(x: -halfSize, y: -halfSize, z: 0)
    points[1] = OGLPoint3D(x: halfSize, y: -halfSize, z: 0)
    points[2] = OGLPoint3D(x: halfSize, y: halfSize, z: 0)
    points[3] = OGLPoint3D(x: -halfSize, y: halfSize, z: 0)
}

private func anchorLeft(_ x: Float) -> Float {
    gGamePrefs.force4x3HUD != 0 ? x : (gLogicalRect.left + x)
}

private func anchorRight(_ x: Float) -> Float {
    gGamePrefs.force4x3HUD != 0 ? (640 * g640x480Scaling - x) : (gLogicalRect.right - x)
}

private func anchorTop(_ y: Float) -> Float {
    gGamePrefs.force4x3HUD != 0 ? y : (gLogicalRect.top + y)
}

private func anchorBottom(_ y: Float) -> Float {
    gGamePrefs.force4x3HUD != 0 ? (480 * g640x480Scaling - y) : (gLogicalRect.bottom - y)
}

private func anchorCenterX(_ x: Float) -> Float {
    x + (640 * g640x480Scaling) * 0.5
}

private func anchorCenterY(_ y: Float) -> Float {
    y + (480 * g640x480Scaling) * 0.5
}

// MARK: - Pane divider

private let cDrawPaneDivider: @convention(c) (UnsafeMutablePointer<ObjNode>?) -> Void = { theNode in
    drawPaneDivider(theNode!)
}

private func drawPaneDivider(_ theNode: UnsafeMutablePointer<ObjNode>) {
    if gActiveSplitScreenMode == UInt8(SPLITSCREEN_MODE_NONE) {
        return
    }

    OGL_PushState()

    SetInfobarSpriteState(0, 1)
    OGL_EnableCullFace()
    OGL_DisableTexture2D()

    let overlayLogicalWidth = gLogicalRect.right - gLogicalRect.left
    let overlayLogicalHeight = gLogicalRect.bottom - gLogicalRect.top

    let halfThickness = (SPLITSCREEN_DIVIDER_THICKNESS + 1.0) / 2.0
    let halfLW = overlayLogicalWidth * 0.5 + 10
    let halfLH = overlayLogicalHeight * 0.5 + 10

    withUnsafePointer(to: &theNode.pointee.ColorFilter.r) {
        glColor4fv($0)
    }
    glTranslatef(640 / 2, 480 / 2, 0)
    glBegin(GLenum(GL_QUADS))

    switch gActiveSplitScreenMode {
    case UInt8(SPLITSCREEN_MODE_HORIZ):
        glVertex2f(-halfLW, -halfThickness)
        glVertex2f(-halfLW, +halfThickness)
        glVertex2f(+halfLW, +halfThickness)
        glVertex2f(+halfLW, -halfThickness)

    case UInt8(SPLITSCREEN_MODE_VERT):
        glVertex2f(-halfThickness, -halfLH)
        glVertex2f(-halfThickness, +halfLH)
        glVertex2f(+halfThickness, +halfLH)
        glVertex2f(+halfThickness, -halfLH)

    default:
        break
    }

    glEnd()

    OGL_PopState()
}

@discardableResult
private func makePaneDivider() -> UnsafeMutablePointer<ObjNode> {
    var def = NewObjectDefinitionType()
    def.genre = UInt8(CUSTOM_GENRE)
    def.scale = 1
    def.slot = Int16(PANEDIVIDER_SLOT)
    def.flags = UInt32(SwStatusBitsFor2D) | UInt32(STATUS_BIT_MOVEINPAUSE)
    def.drawCall = cDrawPaneDivider
    def.coord = OGLPoint3D(x: 640 / 2, y: 480 / 2, z: 0)

    let paneDivider = MakeNewObject(&def)!
    paneDivider.pointee.ColorFilter = OGLColorRGBA(r: 0, g: 0, b: 0, a: 1)
    SendNodeToOverlayPane(paneDivider)
    return paneDivider
}

// MARK: - Init

@c @implementation
public func InitInfobar() {
    gBlinkingEggType = -1
    gBlinkingEggTimer = 0

    // CREATE PANE DIVIDER FOR MULTIPLAYER
    makePaneDivider()

    // CREATE DUMMY OBJECT
    do {
        var def = NewObjectDefinitionType()
        def.genre = UInt8(CUSTOM_GENRE)
        def.slot = Int16(INFOBAR_SLOT)
        def.moveCall = nil
        def.drawCall = cDrawInfobar
        def.flags = UInt32(STATUS_BIT_DOUBLESIDED | STATUS_BIT_NOLIGHTING | STATUS_BIT_DONTCULL | STATUS_BIT_NOZBUFFER | STATUS_BIT_NOFOG)
        def.scale = 1
        MakeNewObject(&def)
    }

    // CREATE EVENT TO DRAW ANAGLYPH CROSSHAIRS
    //
    // In Anaglyph mode we actually need to draw the crosshairs into the 3D space
    // instead of as faux sprites
    if isStereo() {
        var def = NewObjectDefinitionType()
        def.genre = UInt8(CUSTOM_GENRE)
        def.slot = Int16(PARTICLE_SLOT) - 1
        def.moveCall = nil
        def.drawCall = cDrawAnaglyphCrosshairs
        def.flags = UInt32(STATUS_BIT_NOLIGHTING | STATUS_BIT_DONTCULL | STATUS_BIT_NOFOG)
        def.scale = 1
        MakeNewObject(&def)
    }

    // LOAD OVERHEAD MAP
    var haveOHM = true
    if GetNumSpritesInGroup(Int32(SPRITE_GROUP_OVERHEADMAP)) != 0 {
        gOverheadMapMaterial = GetSpriteGroupPtr(Int32(SPRITE_GROUP_OVERHEADMAP))![0].materialObject?.assumingMemoryBound(to: MOMaterialObject.self) // get illegal ref to texture
    } else {
        gOverheadMapMaterial = nil
        haveOHM = false
    }

    if haveOHM {
        // SET TO BE MULTI-TEXTURE FOR MASKING
        let ohm = gOverheadMapMaterial!
        ohm.flags |= UInt32(BG3D_MATERIALFLAG_MULTITEXTURE)
        ohm.multiTextureCombine = UInt16(MULTI_TEXTURE_COMBINE_MODULATE)

        // INIT OHM TRIMESH
        for i in 0..<4 {
            gOHMPoints[i].z = 0
        }

        gOHMTriangles[0].vertexIndices = (0, 1, 2)
        gOHMTriangles[1].vertexIndices = (2, 0, 3)
        gOHMuv2[0] = OGLTextureCoord(u: 0, v: 0)
        gOHMuv2[1] = OGLTextureCoord(u: 0, v: 1)
        gOHMuv2[2] = OGLTextureCoord(u: 1, v: 1)
        gOHMuv2[3] = OGLTextureCoord(u: 1, v: 0)

        gOHMTriMesh.VARtype = -1
        gOHMTriMesh.numMaterials = 2
        gOHMTriMesh.materials.0 = ohm
        gOHMTriMesh.materials.1 = GetSpriteGroupPtr(Int32(SPRITE_GROUP_INFOBAR))![Int(INFOBAR_SObjType_MapMask)].materialObject?.assumingMemoryBound(to: MOMaterialObject.self)

        gOHMTriMesh.numPoints = 4
        gOHMTriMesh.numTriangles = 2
        gOHMTriMesh.points = gOHMPoints
        gOHMTriMesh.normals = nil
        gOHMTriMesh.uvs.0 = gOHMuv1
        gOHMTriMesh.uvs.1 = gOHMuv2
        gOHMTriMesh.colorsFloat = nil
        gOHMTriMesh.triangles = gOHMTriangles
    }

    // INIT HEALTH MESH
    do {
        let mo = GetSpriteGroupPtr(Int32(SPRITE_GROUP_INFOBAR))![Int(INFOBAR_SObjType_HealthRed)].materialObject!.assumingMemoryBound(to: MOMaterialObject.self)
        mo.flags |= UInt32(BG3D_MATERIALFLAG_MULTITEXTURE) | UInt32(BG3D_MATERIALFLAG_ALWAYSBLEND)
        mo.multiTextureCombine = UInt16(MULTI_TEXTURE_COMBINE_MODULATE)

        setUpMeterQuad(triangles: gHealthTriangles, uv1: gHealthuv1, uv2: gHealthuv2, points: gHealthPoints, halfSize: HEALTH_SCALE2)

        gHealthTriMesh.VARtype = -1
        gHealthTriMesh.numMaterials = 2
        gHealthTriMesh.materials.0 = mo
        gHealthTriMesh.materials.1 = GetSpriteGroupPtr(Int32(SPRITE_GROUP_INFOBAR))![Int(INFOBAR_SObjType_MapMask)].materialObject?.assumingMemoryBound(to: MOMaterialObject.self)

        gHealthTriMesh.numPoints = 4
        gHealthTriMesh.numTriangles = 2
        gHealthTriMesh.points = gHealthPoints
        gHealthTriMesh.normals = nil
        gHealthTriMesh.uvs.0 = gHealthuv1
        gHealthTriMesh.uvs.1 = gHealthuv2
        gHealthTriMesh.colorsFloat = nil
        gHealthTriMesh.triangles = gHealthTriangles
    }

    // INIT SHIELD MESH
    do {
        let mo = GetSpriteGroupPtr(Int32(SPRITE_GROUP_INFOBAR))![Int(INFOBAR_SObjType_ShieldRed)].materialObject!.assumingMemoryBound(to: MOMaterialObject.self)
        mo.flags |= UInt32(BG3D_MATERIALFLAG_MULTITEXTURE) | UInt32(BG3D_MATERIALFLAG_ALWAYSBLEND)
        mo.multiTextureCombine = UInt16(MULTI_TEXTURE_COMBINE_MODULATE)

        setUpMeterQuad(triangles: gShieldTriangles, uv1: gShielduv1, uv2: gShielduv2, points: gShieldPoints, halfSize: SHIELD_SCALE2)

        gShieldTriMesh.VARtype = -1
        gShieldTriMesh.numMaterials = 2
        gShieldTriMesh.materials.0 = mo
        gShieldTriMesh.materials.1 = GetSpriteGroupPtr(Int32(SPRITE_GROUP_INFOBAR))![Int(INFOBAR_SObjType_MapMask)].materialObject?.assumingMemoryBound(to: MOMaterialObject.self)

        gShieldTriMesh.numPoints = 4
        gShieldTriMesh.numTriangles = 2
        gShieldTriMesh.points = gShieldPoints
        gShieldTriMesh.normals = nil
        gShieldTriMesh.uvs.0 = gShielduv1
        gShieldTriMesh.uvs.1 = gShielduv2
        gShieldTriMesh.colorsFloat = nil
        gShieldTriMesh.triangles = gShieldTriangles
    }

    // INIT FUEL MESH
    do {
        let mo = GetSpriteGroupPtr(Int32(SPRITE_GROUP_INFOBAR))![Int(INFOBAR_SObjType_FuelRed)].materialObject!.assumingMemoryBound(to: MOMaterialObject.self)
        mo.flags |= UInt32(BG3D_MATERIALFLAG_MULTITEXTURE) | UInt32(BG3D_MATERIALFLAG_ALWAYSBLEND)
        mo.multiTextureCombine = UInt16(MULTI_TEXTURE_COMBINE_MODULATE)

        setUpMeterQuad(triangles: gFuelTriangles, uv1: gFueluv1, uv2: gFueluv2, points: gFuelPoints, halfSize: FUEL_SCALE2)

        gFuelTriMesh.VARtype = -1
        gFuelTriMesh.numMaterials = 2
        gFuelTriMesh.materials.0 = mo
        gFuelTriMesh.materials.1 = GetSpriteGroupPtr(Int32(SPRITE_GROUP_INFOBAR))![Int(INFOBAR_SObjType_MapMask)].materialObject?.assumingMemoryBound(to: MOMaterialObject.self)

        gFuelTriMesh.numPoints = 4
        gFuelTriMesh.numTriangles = 2
        gFuelTriMesh.points = gFuelPoints
        gFuelTriMesh.normals = nil
        gFuelTriMesh.uvs.0 = gFueluv1
        gFuelTriMesh.uvs.1 = gFueluv2
        gFuelTriMesh.colorsFloat = nil
        gFuelTriMesh.triangles = gFuelTriangles
    }
}

@c @implementation
public func DisposeInfobar() {
}

// MARK: - Set infobar sprite state
//
// anaglyphZ: +5...-5 where + values are in front of screen, and - values are in back

@c @implementation
public func Get2DLogicalRect(_ splitScreenPane: UInt8, _ zoom: Float) -> OGLRect {
    var dontcare1: Int32 = 0
    var dontcare2: Int32 = 0
    var drawableW: Int32 = 1
    var drawableH: Int32 = 1
    OGL_GetCurrentViewport(&dontcare1, &dontcare2, &drawableW, &drawableH, splitScreenPane)

    var referenceW: Float = 640
    var referenceH: Float = 480

    g640x480Scaling = 1.0 / zoom
    referenceW *= g640x480Scaling
    referenceH *= g640x480Scaling

    let referenceAR = referenceW / referenceH

    let logicalW: Float
    let logicalH: Float

    let drawableAR = Float(drawableW) / Float(drawableH)
    if drawableAR >= referenceAR {
        // wide
        logicalW = referenceH * drawableAR
        logicalH = referenceH
    } else {
        // tall
        logicalW = referenceW
        logicalH = referenceW / drawableAR
    }

    let left = (referenceW - logicalW) * 0.5
    let top = (referenceH - logicalH) * 0.5
    let right = left + logicalW
    let bottom = top + logicalH

    var rect = OGLRect()
    rect.left = left
    rect.top = top
    rect.right = right
    rect.bottom = bottom
    return rect
}

@c @implementation
public func SetInfobarSpriteState(_ anaglyphZ: Float, _ zoom: Float) {
    OGL_DisableLighting()
    OGL_DisableCullFace()
    glDisable(GLenum(GL_DEPTH_TEST)) // no z-buffer

    // SET MATERIAL FLAGS
    //
    // Assume that all sprites have clamped edges.
    // Assume that most sprites have alpha, so enable blending (this won't hurt if it doesn't have an alpha)
    gGlobalMaterialFlags = UInt32(BG3D_MATERIALFLAG_CLAMP_V) | UInt32(BG3D_MATERIALFLAG_CLAMP_U) | UInt32(BG3D_MATERIALFLAG_ALWAYSBLEND)

    // INIT MATRICES
    glMatrixMode(GLenum(GL_PROJECTION))
    glLoadIdentity()

    gLogicalRect = Get2DLogicalRect(gCurrentSplitScreenPane, zoom)
    let left = gLogicalRect.left
    let top = gLogicalRect.top
    let right = gLogicalRect.right
    let bottom = gLogicalRect.bottom

    if isStereo() {
        if gAnaglyphPass == 0 {
            glOrtho(GLdouble(left - anaglyphZ), GLdouble(right - anaglyphZ), GLdouble(bottom), GLdouble(top), 0, 1)
        } else {
            glOrtho(GLdouble(left + anaglyphZ), GLdouble(right + anaglyphZ), GLdouble(bottom), GLdouble(top), 0, 1)
        }
    } else {
        glOrtho(GLdouble(left), GLdouble(right), GLdouble(bottom), GLdouble(top), 0, 1)
    }

    glMatrixMode(GLenum(GL_MODELVIEW))
    glLoadIdentity()
}

// MARK: - Draw infobar

private let cDrawInfobar: @convention(c) (UnsafeMutablePointer<ObjNode>?) -> Void = { _ in
    DrawInfobar(nil)
}

@c @implementation
public func DrawInfobar(_ theNode: UnsafeMutablePointer<ObjNode>?) {
    // DRAW SOME OTHER GOODIES WHILE WE'RE HERE
    DrawLensFlare() // draw lens flare

    if gCurrentSplitScreenPane == 0
        && gAnaglyphPass == 0
        && SwIsKeyDown(Int(SDL_SCANCODE_F9.rawValue)) { // see if toggle statbar
        gHideInfobar = gHideInfobar == 0 ? 1 : 0
    }

    if gHideInfobar != 0 {
        return
    }

    // SET TAGS
    OGL_PushState()

    let zoom = Float(gGamePrefs.hudScale) * 0.01
    SetInfobarSpriteState(INFOBAR_ANAGLYPHZ_Z, zoom)

    // DRAW THINGS
    infobarDrawCrosshairs()
    infobarDrawWeaponInventory()
    infobarDrawHealth()
    infobarDrawShield()
    infobarDrawFuel()
    infobarDrawMap()

    switch gVSMode {
    // ADVENTURE MODE
    case .none:
        infobarDrawLives()
        infobarDrawEggs()
        infobarDrawMissionStatus()

    // RACE MODE
    case .race:
        infobarDrawPlayerLabels()
        infobarDrawRaceInfo()
        infobarDrawPlayerArrows()

    // CAPTURE THE FLAG MODE
    case .captureTheFlag:
        infobarDrawPlayerLabels()
        infobarCaptureFlagEggs()
        infobarDrawPlayerArrows()

    // BATTLE MODE
    case .battle:
        infobarDrawPlayerLabels()
        infobarDrawLives()
        infobarDrawPlayerArrows()

    default:
        break
    }

    // CLEANUP
    OGL_PopState()
    gGlobalMaterialFlags = 0
}

// MARK: - Draw infobar sprite

@c @implementation
public func DrawInfobarSprite(_ x: Float, _ y: Float, _ size: Float, _ texNum: Int16) {
    SwGameAssert(GetNumSpritesInGroup(Int32(SPRITE_GROUP_INFOBAR)) > Int32(texNum))

    // ACTIVATE THE MATERIAL
    let mo = GetSpriteGroupPtr(Int32(SPRITE_GROUP_INFOBAR))![Int(texNum)].materialObject?.assumingMemoryBound(to: MOMaterialObject.self)
    MO_DrawMaterial(mo)

    let aspect = Float(mo!.height) / Float(mo!.width)

    // DRAW IT
    glBegin(GLenum(GL_QUADS))
    glTexCoord2f(0, 0); glVertex2f(x, y)
    glTexCoord2f(1, 0); glVertex2f(x + size, y)
    glTexCoord2f(1, 1); glVertex2f(x + size, y + (size * aspect))
    glTexCoord2f(0, 1); glVertex2f(x, y + (size * aspect))
    glEnd()
}

// MARK: - Draw infobar sprite: centered
//
// Coords are for center of sprite, not upper left

@c @implementation
public func DrawInfobarSprite_Centered(_ x0: Float, _ y0: Float, _ size: Float, _ texNum: Int16) {
    // ACTIVATE THE MATERIAL
    let mo = GetSpriteGroupPtr(Int32(SPRITE_GROUP_INFOBAR))![Int(texNum)].materialObject?.assumingMemoryBound(to: MOMaterialObject.self)
    MO_DrawMaterial(mo)

    let aspect = Float(mo!.height) / Float(mo!.width)

    let x = x0 - size * 0.5
    let y = y0 - (size * aspect) * 0.5

    // DRAW IT
    glBegin(GLenum(GL_QUADS))
    glTexCoord2f(0, 0); glVertex2f(x, y)
    glTexCoord2f(1, 0); glVertex2f(x + size, y)
    glTexCoord2f(1, 1); glVertex2f(x + size, y + (size * aspect))
    glTexCoord2f(0, 1); glVertex2f(x, y + (size * aspect))
    glEnd()
}

// MARK: - Draw infobar sprite 2
//
// This version lets user pass in the sprite group

@c @implementation
public func DrawInfobarSprite2(_ x: Float, _ y: Float, _ size: Float, _ group: Int16, _ texNum: Int16) {
    // ACTIVATE THE MATERIAL
    let mo = GetSpriteGroupPtr(Int32(group))![Int(texNum)].materialObject?.assumingMemoryBound(to: MOMaterialObject.self)
    MO_DrawMaterial(mo)

    let aspect = Float(mo!.height) / Float(mo!.width)

    // DRAW IT
    glBegin(GLenum(GL_QUADS))
    glTexCoord2f(0, 0); glVertex2f(x, y)
    glTexCoord2f(1, 0); glVertex2f(x + size, y)
    glTexCoord2f(1, 1); glVertex2f(x + size, y + (size * aspect))
    glTexCoord2f(0, 1); glVertex2f(x, y + (size * aspect))
    glEnd()
}

// MARK: - Draw infobar sprite 3
//
// Same as above, but where size is the vertical size, not horiz.

@c @implementation
public func DrawInfobarSprite3(_ x: Float, _ y: Float, _ size: Float, _ texNum: Int16) {
    // ACTIVATE THE MATERIAL
    let mo = GetSpriteGroupPtr(Int32(SPRITE_GROUP_INFOBAR))![Int(texNum)].materialObject?.assumingMemoryBound(to: MOMaterialObject.self)
    MO_DrawMaterial(mo)

    let aspect = Float(mo!.width) / Float(mo!.height)

    // DRAW IT
    glBegin(GLenum(GL_QUADS))
    glTexCoord2f(0, 0); glVertex2f(x, y)
    glTexCoord2f(1, 0); glVertex2f(x + (size * aspect), y)
    glTexCoord2f(1, 1); glVertex2f(x + (size * aspect), y + size)
    glTexCoord2f(0, 1); glVertex2f(x, y + size)
    glEnd()
}

// MARK: - Draw infobar sprite 3: centered

@c @implementation
public func DrawInfobarSprite3_Centered(_ x0: Float, _ y0: Float, _ size: Float, _ texNum: Int16) {
    // ACTIVATE THE MATERIAL
    let mo = GetSpriteGroupPtr(Int32(SPRITE_GROUP_INFOBAR))![Int(texNum)].materialObject?.assumingMemoryBound(to: MOMaterialObject.self)
    MO_DrawMaterial(mo)

    let aspect = Float(mo!.width) / Float(mo!.height)

    let y = y0 - size * 0.5
    let x = x0 - (size * aspect) * 0.5

    // DRAW IT
    glBegin(GLenum(GL_QUADS))
    glTexCoord2f(0, 0); glVertex2f(x, y)
    glTexCoord2f(1, 0); glVertex2f(x + (size * aspect), y)
    glTexCoord2f(1, 1); glVertex2f(x + (size * aspect), y + size)
    glTexCoord2f(0, 1); glVertex2f(x, y + size)
    glEnd()
}

// MARK: - Draw infobar sprite 2: centered
//
// This version lets user pass in the sprite group

@c @implementation
public func DrawInfobarSprite2_Centered(_ x0: Float, _ y0: Float, _ size: Float, _ group: Int16, _ texNum: Int16) {
    if Int32(texNum) >= GetNumSpritesInGroup(Int32(group)) {
        SwFatal("DrawInfobarSprite2_Centered: sprite # > max in group!")
    }

    // ACTIVATE THE MATERIAL
    let mo = GetSpriteGroupPtr(Int32(group))![Int(texNum)].materialObject?.assumingMemoryBound(to: MOMaterialObject.self)
    MO_DrawMaterial(mo)

    let aspect = Float(mo!.height) / Float(mo!.width)

    let x = x0 - size * 0.5
    let y = y0 - (size * aspect) * 0.5

    // DRAW IT
    glBegin(GLenum(GL_QUADS))
    glTexCoord2f(0, 0); glVertex2f(x, y)
    glTexCoord2f(1, 0); glVertex2f(x + size, y)
    glTexCoord2f(1, 1); glVertex2f(x + size, y + (size * aspect))
    glTexCoord2f(0, 1); glVertex2f(x, y + (size * aspect))
    glEnd()
}

// MARK: - Draw infobar sprite: rotated

private func drawInfobarSpriteRotated(_ x: Float, _ y: Float, _ size: Float, _ texNum: Int16, _ rot: Float) {
    // ACTIVATE THE MATERIAL
    let mo = GetSpriteGroupPtr(Int32(SPRITE_GROUP_INFOBAR))![Int(texNum)].materialObject?.assumingMemoryBound(to: MOMaterialObject.self)
    MO_DrawMaterial(mo)

    // SET COORDS
    let aspect = Float(mo!.height) / Float(mo!.width)

    let xoff = size * 0.5
    let yoff = (size * aspect) * 0.5

    var p = (OGLPoint2D(), OGLPoint2D(), OGLPoint2D(), OGLPoint2D())
    p.0.x = -xoff; p.0.y = -yoff
    p.1.x = xoff; p.1.y = -yoff
    p.2.x = xoff; p.2.y = yoff
    p.3.x = -xoff; p.3.y = yoff

    var m = OGLMatrix3x3()
    OGLMatrix3x3_SetRotate(&m, Double(rot))
    withUnsafeMutablePointer(to: &p) {
        $0.withMemoryRebound(to: OGLPoint2D.self, capacity: 4) { pPtr in
            OGLPoint2D_TransformArray(pPtr, &m, pPtr, 4)
        }
    }

    // DRAW IT
    glBegin(GLenum(GL_QUADS))
    glTexCoord2f(0, 0); glVertex2f(p.0.x + x, p.0.y + y)
    glTexCoord2f(1, 0); glVertex2f(p.1.x + x, p.1.y + y)
    glTexCoord2f(1, 1); glVertex2f(p.2.x + x, p.2.y + y)
    glTexCoord2f(0, 1); glVertex2f(p.3.x + x, p.3.y + y)
    glEnd()
}

// MARK: - Infobar: draw number

@c @implementation
public func Infobar_DrawNumber(_ number0: Int32, _ x0: Float, _ y0: Float, _ scale: Float, _ numDigits: Int32, _ showLeading: UInt8) {
    var number = number0
    var x = x0
    let sep = scale * DIGIT_WIDTH

    x += Float(numDigits - 1) * sep // start on right

    for _ in 0..<numDigits {
        let n = number / 10
        var r = number - (n * 10)
        if r == 10 {
            r = 0
        }
        number = n

        DrawInfobarSprite(x, y0, scale, Int16(Int32(INFOBAR_SObjType_0) + r))

        x -= sep

        if showLeading == 0 {
            if number == 0 {
                return
            }
        }
    }
}

// MARK: - Draw map

private func infobarDrawMap() {
    guard gOverheadMapMaterial != nil else {
        return
    }

    let rot = GetPlayerInfoEntry(Int32(gCurrentSplitScreenPane))!.pointee.objNode!.pointee.Rot.y

    let y = mapY()

    // SET COORDS OF THE QUAD
    let xoff = MAP_SCALE2
    let yoff = MAP_SCALE2

    var p2D = (OGLPoint2D(), OGLPoint2D(), OGLPoint2D(), OGLPoint2D())
    p2D.0.x = -xoff; p2D.0.y = yoff
    p2D.1.x = xoff; p2D.1.y = yoff
    p2D.2.x = xoff; p2D.2.y = -yoff
    p2D.3.x = -xoff; p2D.3.y = -yoff

    var m = OGLMatrix3x3()
    OGLMatrix3x3_SetRotate(&m, Double(rot))
    withUnsafeMutablePointer(to: &p2D) {
        $0.withMemoryRebound(to: OGLPoint2D.self, capacity: 4) { pPtr in
            OGLPoint2D_TransformArray(pPtr, &m, pPtr, 4)
        }
    }

    let mapXValue = mapX()
    gOHMPoints[0].x = p2D.0.x + mapXValue; gOHMPoints[0].y = p2D.0.y + y // translate and convert to 3D point variable
    gOHMPoints[1].x = p2D.1.x + mapXValue; gOHMPoints[1].y = p2D.1.y + y
    gOHMPoints[2].x = p2D.2.x + mapXValue; gOHMPoints[2].y = p2D.2.y + y
    gOHMPoints[3].x = p2D.3.x + mapXValue; gOHMPoints[3].y = p2D.3.y + y

    // CALC UV COORDS
    //
    // First we need to adjust the world left/top to the texture's
    // left/top (since we've cropped the black out of it)
    //
    // Then we need to scale the scroll value to uv coords.

    let pi = GetPlayerInfoEntry(Int32(gCurrentSplitScreenPane))!
    var leftEdge = Double(pi.pointee.coord.x * gMapToUnitValueFrac) // convert world-coord to texture-pixel-coord
    var topEdge = Double(pi.pointee.coord.z * gMapToUnitValueFrac)

    var visibleRange: Float
    var u: Float
    var v: Float

    switch gLevelNum {
    case Int16(LEVEL_NUM_ADVENTURE1):
        visibleRange = 0.18
        leftEdge -= 1175.0 // offset by the cropped black-space amount
        u = Float(leftEdge) * 0.00011
        topEdge -= 911.0 // offset by the cropped black-space amount
        v = Float(topEdge) * 0.00011

    case Int16(LEVEL_NUM_ADVENTURE2):
        visibleRange = 0.24
        leftEdge -= 527.0
        u = Float(leftEdge) * 0.0001057
        topEdge -= 275.0
        v = Float(topEdge) * 0.0001057

    case Int16(LEVEL_NUM_ADVENTURE3):
        visibleRange = 0.29
        leftEdge -= 496.0
        u = Float(leftEdge) * 0.0001029
        topEdge -= 192.0
        v = Float(topEdge) * 0.0001029

    case Int16(LEVEL_NUM_RACE1):
        visibleRange = 0.3
        leftEdge -= 779.0
        u = Float(leftEdge) * 0.0001463
        topEdge -= 317.0
        v = Float(topEdge) * 0.0001463

    case Int16(LEVEL_NUM_RACE2):
        visibleRange = 0.25
        leftEdge -= 743.0
        u = Float(leftEdge) * 0.000148853 // 1.0 / pixel width
        topEdge -= 329.0
        v = Float(topEdge) * 0.000148853

    case Int16(LEVEL_NUM_FLAG1):
        visibleRange = 0.3
        leftEdge -= 1499.0
        u = Float(leftEdge) * 0.0001999
        topEdge -= 809.0
        v = Float(topEdge) * 0.0001999

    case Int16(LEVEL_NUM_FLAG2):
        visibleRange = 0.5
        leftEdge -= 2544
        u = Float(leftEdge) * 0.0002735
        topEdge -= 728
        v = Float(topEdge) * 0.0002735

    case Int16(LEVEL_NUM_BATTLE1):
        visibleRange = 0.5
        leftEdge -= 2732.0
        u = Float(leftEdge) * 0.000371
        topEdge -= 1328.0
        v = Float(topEdge) * 0.000371

    case Int16(LEVEL_NUM_BATTLE2):
        visibleRange = 0.3
        leftEdge -= 3152.0
        u = Float(leftEdge) * 0.00054585
        topEdge -= 1692.0
        v = Float(topEdge) * 0.00054585

    default:
        return
    }

    gOHMuv1[0].u = u - visibleRange
    gOHMuv1[0].v = v + visibleRange

    gOHMuv1[1].u = u + visibleRange
    gOHMuv1[1].v = gOHMuv1[0].v

    gOHMuv1[2].u = gOHMuv1[1].u
    gOHMuv1[2].v = v - visibleRange

    gOHMuv1[3].u = gOHMuv1[0].u
    gOHMuv1[3].v = gOHMuv1[2].v

    // DRAW IT

    // DRAW SHADOW
    if gGamePrefs.lowRenderQuality == 0 {
        DrawInfobarSprite_Centered(mapXValue + 3, y + 3, MAP_SCALE * 1.3, Int16(INFOBAR_SObjType_CircleShadow))
    }

    // DRAW BACK
    DrawInfobarSprite_Centered(mapXValue, y, MAP_SCALE, Int16(INFOBAR_SObjType_MapLines))

    // DRAW MAP
    MO_DrawGeometry_VertexArray(&gOHMTriMesh)

    // DRAW FRAME OVERLAY
    drawInfobarSpriteRotated(mapXValue, y, MAP_SCALE, Int16(INFOBAR_SObjType_MapFrame), 0)

    OGL_BlendFunc(GLenum(GL_SRC_ALPHA), GLenum(GL_ONE))
    DrawInfobarSprite_Centered(mapXValue, y, MAP_SCALE, Int16(INFOBAR_SObjType_MapGlass))
    OGL_BlendFunc(GLenum(GL_SRC_ALPHA), GLenum(GL_ONE_MINUS_SRC_ALPHA))
}

// MARK: - Draw health

private func infobarDrawHealth() {
    // CALC UV COORDS
    let v = GetPlayerInfoEntry(Int32(gCurrentSplitScreenPane))!.pointee.health * 0.5

    // SET V'S FOR SCROLLING OF HEALTH BAR
    gHealthuv1[0].v = v; gHealthuv1[1].v = v
    gHealthuv1[2].v = v + 0.5; gHealthuv1[3].v = v + 0.5

    // DRAW IT
    glPushMatrix()
    glTranslatef(healthX(), healthY(), 0)

    // DRAW SHADOW
    if gGamePrefs.lowRenderQuality == 0 {
        DrawInfobarSprite_Centered(2, 2, HEALTH_SCALE * 1.3, Int16(INFOBAR_SObjType_CircleShadow))
    }

    MO_DrawGeometry_VertexArray(&gHealthTriMesh)

    // DRAW FRAME OVERLAY
    DrawInfobarSprite_Centered(0, 0, HEALTH_SCALE, Int16(INFOBAR_SObjType_HealthFrame))

    OGL_BlendFunc(GLenum(GL_SRC_ALPHA), GLenum(GL_ONE))
    DrawInfobarSprite_Centered(0, 0, HEALTH_SCALE, Int16(INFOBAR_SObjType_HealthShine))
    OGL_BlendFunc(GLenum(GL_SRC_ALPHA), GLenum(GL_ONE_MINUS_SRC_ALPHA))

    glPopMatrix()
}

// MARK: - Draw shield

private func infobarDrawShield() {
    let q = GetPlayerInfoEntry(Int32(gCurrentSplitScreenPane))!.pointee.shieldPower / MAX_SHIELD_POWER // convert shield power to 0..1 value

    // CALC UV COORDS
    let v = q * 0.5

    // SET V'S FOR SCROLLING OF SHIELD BAR
    gShielduv1[0].v = v; gShielduv1[1].v = v
    gShielduv1[2].v = v + 0.5; gShielduv1[3].v = v + 0.5

    // DRAW IT
    glPushMatrix()
    glTranslatef(shieldX(), shieldY(), 0)

    // DRAW SHADOW
    if gGamePrefs.lowRenderQuality == 0 {
        DrawInfobarSprite_Centered(2, 2, SHIELD_SCALE * 1.3, Int16(INFOBAR_SObjType_CircleShadow))
    }

    MO_DrawGeometry_VertexArray(&gShieldTriMesh)

    // DRAW FRAME OVERLAY
    DrawInfobarSprite_Centered(0, 0, SHIELD_SCALE, Int16(INFOBAR_SObjType_ShieldFrame))

    OGL_BlendFunc(GLenum(GL_SRC_ALPHA), GLenum(GL_ONE))
    DrawInfobarSprite_Centered(0, 0, SHIELD_SCALE, Int16(INFOBAR_SObjType_HealthShine))
    OGL_BlendFunc(GLenum(GL_SRC_ALPHA), GLenum(GL_ONE_MINUS_SRC_ALPHA))

    glPopMatrix()
}

// MARK: - Draw fuel

private func infobarDrawFuel() {
    // CALC UV COORDS
    let v = GetPlayerInfoEntry(Int32(gCurrentSplitScreenPane))!.pointee.jetpackFuel * 0.5

    // SET V'S FOR SCROLLING OF FUEL BAR
    gFueluv1[0].v = v; gFueluv1[1].v = v
    gFueluv1[2].v = v + 0.5; gFueluv1[3].v = v + 0.5

    // DRAW IT
    glPushMatrix()
    glTranslatef(fuelX(), fuelY(), 0)

    // DRAW SHADOW
    if gGamePrefs.lowRenderQuality == 0 {
        DrawInfobarSprite_Centered(2, 2, FUEL_SCALE * 1.3, Int16(INFOBAR_SObjType_CircleShadow))
    }

    MO_DrawGeometry_VertexArray(&gFuelTriMesh)

    // DRAW FRAME OVERLAY
    DrawInfobarSprite_Centered(0, 0, FUEL_SCALE, Int16(INFOBAR_SObjType_FuelFrame))

    OGL_BlendFunc(GLenum(GL_SRC_ALPHA), GLenum(GL_ONE))
    DrawInfobarSprite_Centered(0, 0, FUEL_SCALE, Int16(INFOBAR_SObjType_HealthShine))
    OGL_BlendFunc(GLenum(GL_SRC_ALPHA), GLenum(GL_ONE_MINUS_SRC_ALPHA))

    glPopMatrix()
}

// MARK: - Start blinking egg

@c @implementation
public func HighlightInfobarEgg(_ eggType: Int32) {
    gBlinkingEggType = eggType
    gBlinkingEggTimer = 0
}

// MARK: - Draw eggs

private func infobarDrawEggs() {
    gBlinkingEggTimer += gFramesPerSecondFrac

    var x = eggsX()
    for eggType in 0..<EggColor.allCases.count {
        if GetNumEggsToSaveSlot(Int32(eggType)).pointee <= 0 { // are there any eggs of this color?
            continue
        }

        var y = eggsY()

        for i in 0..<Int(GetNumEggsToSaveSlot(Int32(eggType)).pointee) {
            if Int(GetNumEggsSavedSlot(Int32(eggType)).pointee) > i {
                DrawInfobarSprite(x, y, EGGS_SCALE, Int16(Int(INFOBAR_SObjType_SmallRedEgg) + eggType))
            } else {
                DrawInfobarSprite(x, y, EGGS_SCALE, Int16(INFOBAR_SObjType_SmallBlankEgg))
            }

            // BLINKING HALO IF JUST SAVED THIS EGG
            if gBlinkingEggTimer < 4.66
                && eggType == Int(gBlinkingEggType)
                && i == Int(GetNumEggsSavedSlot(Int32(eggType)).pointee) - 1 {
                let flux = cosf(gBlinkingEggTimer * Float(PI) * 3 - Float(PI))
                gGlobalTransparency = RangeTranspose(flux, -1, 1, 0, 0.8)
                DrawInfobarSprite(x, y, EGGS_SCALE, Int16(INFOBAR_SObjType_SmallEggHalo))
                gGlobalTransparency = 1.0
            }

            y += EGGS_SCALE
        }

        x += EGGS_SCALE
    }
}

// MARK: - Draw capture flag eggs

private func infobarCaptureFlagEggs() {
    let eggType = Int(gCurrentSplitScreenPane) ^ 1 // egg type is OTHER player's, so ^ 1

    gBlinkingEggTimer += gFramesPerSecondFrac / Float(gNumPlayers)

    let y = capEggsY()
    var x = capEggsX()
    for i in 0..<Int(GetNumEggsToSaveSlot(Int32(eggType)).pointee) {
        if Int(GetNumEggsSavedSlot(Int32(eggType)).pointee) > i {
            DrawInfobarSprite(x, y, CAP_EGGS_SCALE, Int16(Int(INFOBAR_SObjType_SmallRedEgg) + eggType))
        } else {
            if eggType == 0 {
                DrawInfobarSprite(x, y, CAP_EGGS_SCALE, Int16(INFOBAR_SObjType_SmallBlankEggRed))
            } else {
                DrawInfobarSprite(x, y, CAP_EGGS_SCALE, Int16(INFOBAR_SObjType_SmallBlankEgg))
            }
        }

        // BLINKING HALO IF JUST CAPTURED THIS EGG
        if gBlinkingEggTimer < 4.66
            && eggType == Int(gBlinkingEggType)
            && i == Int(GetNumEggsSavedSlot(Int32(eggType)).pointee) - 1 {
            let flux = cosf(gBlinkingEggTimer * Float(PI) * 3 - Float(PI))
            gGlobalTransparency = RangeTranspose(flux, -1, 1, 0, 0.8)
            DrawInfobarSprite(x, y, CAP_EGGS_SCALE, Int16(INFOBAR_SObjType_SmallEggHalo))
            gGlobalTransparency = 1.0
        }

        x += CAP_EGGS_SCALE * 0.95
    }
}

// MARK: - Draw infobar player labels

private func infobarDrawPlayerLabels() {
    // Source port note: this is useless information and it takes up valuable real estate (dead code in the original, kept disabled)
}

// MARK: - Draw "enter wormhole" or "mission failed"

private var gMissionStatusFlux: Float = 0

private func infobarDrawMissionStatus() {
    if gGamePaused != 0 {
        gMissionStatusFlux = 0
        return
    }

    // PLAYER DEAD
    if GetPlayerIsDead(0) != 0 && GetPlayerInfoEntry(0)!.pointee.numFreeLives <= 0 {
        let x = anchorCenterX(0)
        let y = anchorCenterY(0)
        let text = Localize(STR_MISSION_FAILED)
        gGlobalColorFilter = OGLColorRGB(r: 1, g: 0, b: 0)
        Atlas_DrawString2(Int32(ATLAS_GROUP_FONT2), text, x, y, 0.66, 0.66, 0, UInt32(kTextMeshSmallCaps))
        gGlobalColorFilter = OGLColorRGB(r: 1, g: 1, b: 1)
    }
    // ENTER WORMHOLE
    else if gOpenPlayerWormhole != 0 && gCameraInExitMode == 0 {
        gMissionStatusFlux += gFramesPerSecondFrac

        var scale: Float = 0.5 * (1.0 + sinf(min(Float(PI), gMissionStatusFlux * 6.0) - (Float(PI) * 0.5)))
        var flags: Int32 = 0

        if gGamePrefs.language == UInt8(LANGUAGE_ITALIAN.rawValue) {
            // Italian text spans two lines so make it smaller
            scale *= 0.5
        } else {
            scale *= 0.66
            flags |= Int32(kTextMeshSmallCaps)
        }

        let x = anchorCenterX(0)
        let y = anchorCenterY(120)
        let text = Localize(STR_ENTER_WORMHOLE)
        gGlobalTransparency = 0.75 + 0.25 * sinf(gMissionStatusFlux * (2.0 * Float(PI)))

        Atlas_DrawString2(Int32(ATLAS_GROUP_FONT1), text, x, y, scale, scale, 0, UInt32(bitPattern: flags))
        gGlobalTransparency = 1.0
    } else {
        gMissionStatusFlux = 0
    }
}

// MARK: - Draw infobar lives

private func infobarDrawLives() {
    var x = livesX()

    for _ in 0..<GetPlayerInfoEntry(Int32(gCurrentSplitScreenPane))!.pointee.numFreeLives {
        DrawInfobarSprite(x, livesY(), LIVES_SCALE, Int16(INFOBAR_SObjType_Life))
        x += LIVES_SCALE * 1.0
    }
}

// MARK: - Draw weapon inventory

private func infobarDrawWeaponInventory() {
    // DRAW FRAME
    DrawInfobarSprite(weaponX() - 15, weaponY() - 5, WEAPON_SCALE * 1.4, Int16(INFOBAR_SObjType_WeaponShadow))

    DrawInfobarSprite(weaponX(), weaponY(), WEAPON_SCALE, Int16(INFOBAR_SObjType_WeaponFrame))

    // DRAW ICON
    let pi = GetPlayerInfoEntry(Int32(gCurrentSplitScreenPane))!
    let weaponType = pi.pointee.currentWeapon
    if Int(weaponType) == Int(WeaponType.none.rawValue) {
        return
    }

    var x = weaponX() + WEAPON_SCALE * 0.026
    var y = weaponY() + WEAPON_SCALE * 0.024

    DrawInfobarSprite(x, y, WEAPON_SCALE * 0.45, Int16(Int(INFOBAR_SObjType_Blaster) + Int(weaponType)))

    // DRAW QUANTITY
    x = weaponX() + (WEAPON_SCALE * 0.45)
    y = weaponY() + (WEAPON_SCALE * 0.222)

    if Int(weaponType) != Int(WeaponType.sonicScream.rawValue) { // dont draw quantity for SS since it's infinite
        Infobar_DrawNumber(Int32(weaponQuantityBase(pi)[Int(weaponType)]), x, y, WEAPON_SCALE * 0.2, 3, 1)
    }
    // DRAW SONIC SCREAM BARS
    else {
        // ceiling: start drawing the first bar as soon as the input is hit
        let numBars = Int(ceilf(pi.pointee.weaponCharge * 9.0))

        for _ in 0..<numBars {
            DrawInfobarSprite(x, y, WEAPON_SCALE * 0.1, Int16(INFOBAR_SObjType_SSBar))
            x += WEAPON_SCALE * 0.05
        }
    }
}

@inline(__always) private func weaponQuantityBase(_ p: UnsafeMutablePointer<PlayerInfoType>) -> UnsafeMutablePointer<Int16> {
    UnsafeMutableRawPointer(p.pointer(to: \.weaponQuantity)!).assumingMemoryBound(to: Int16.self)
}

// MARK: - Infobar: draw race info

private func infobarDrawRaceInfo() {
    let playerNum = gCurrentSplitScreenPane

    // DRAW READY-SET-GO
    let readySetGoIcon: Int32
    switch Int32(gRaceReadySetGoTimer + 1) {
    case 2: readySetGoIcon = Int32(INFOBAR_SObjType_Ready)
    case 1: readySetGoIcon = Int32(INFOBAR_SObjType_Set)
    case 0: readySetGoIcon = Int32(INFOBAR_SObjType_Go)
    default: readySetGoIcon = -1
    }
    if readySetGoIcon != -1 {
        DrawInfobarSprite_Centered(anchorCenterX(0), anchorBottom(157.5), 135, Int16(readySetGoIcon))
    }

    // DRAW PLACE
    let scale: Float = 60.0

    let pi = GetPlayerInfoEntry(Int32(playerNum))!
    let place = pi.pointee.place
    DrawInfobarSprite(playerX(), playerY(), scale, Int16(Int(INFOBAR_SObjType_Place1) + Int(place)))

    // DRAW LAP
    if gLevelCompleted == 0 {
        var lapNum = pi.pointee.lapNum
        if lapNum < 0 {
            lapNum = 0
        }

        DrawInfobarSprite(anchorRight(scale), anchorTop(0), scale, Int16(Int(INFOBAR_SObjType_Lap1) + Int(lapNum)))
    }

    // DRAW WRONG WAY
    if pi.pointee.wrongWay != 0 {
        gGlobalTransparency = 0.6
        DrawInfobarSprite_Centered(anchorCenterX(0), anchorCenterY(0), 80, Int16(INFOBAR_SObjType_WrongWay))
        gGlobalTransparency = 1.0
    }
}

// MARK: - Show lapnum
//
// Called from Checkpoints.c whenever the player completes a new lap (except for winning lap).

private let cMoveLapMessage: @convention(c) (UnsafeMutablePointer<ObjNode>?) -> Void = { theNode in
    moveLapMessage(theNode!)
}

@c @implementation
public func ShowLapNum(_ playerNum: Int16) -> UnsafeMutablePointer<ObjNode>? {
    let lapNum = GetPlayerInfoEntry(Int32(playerNum))!.pointee.lapNum

    // SEE IF TELL LAP
    if lapNum <= 0 {
        return nil
    }

    // TODO: deferred-draw sprites don't honor current 2D viewport scaling!
    var def = NewObjectDefinitionType()
    def.group = UInt8(SPRITE_GROUP_INFOBAR)
    def.type = UInt8(lapNum == 1 ? Int16(INFOBAR_SObjType_Lap2Message) : Int16(INFOBAR_SObjType_FinalLapMessage))
    def.coord = OGLPoint3D(x: anchorCenterX(0), y: anchorCenterY(75), z: 0)
    def.flags = UInt32(STATUS_BIT_ONLYSHOWTHISPLAYER) | UInt32(STATUS_BIT_MOVEINPAUSE)
    def.slot = Int16(SPRITE_SLOT)
    def.moveCall = cMoveLapMessage
    def.rot = 0
    def.scale = 170

    let newObj = MakeSpriteObject(&def, 1)!
    newObj.pointee.PlayerNum = UInt8(playerNum) // only show for this player
    newObj.pointee.ColorFilter.a = 2.0
    return newObj
}

// MARK: - Move lap message

private func moveLapMessage(_ theNode: UnsafeMutablePointer<ObjNode>) {
    theNode.pointee.Coord.x = anchorCenterX(0)
    theNode.pointee.Coord.y = anchorCenterY(75)
    UpdateObjectTransforms(theNode)

    if gGamePaused == 0 {
        theNode.pointee.ColorFilter.a -= gFramesPerSecondFrac
        if theNode.pointee.ColorFilter.a <= 0.0 {
            DeleteObject(theNode)
        }
    }
}

// MARK: - Show win lose
//
// Used for battle modes to show player if they win or lose.
//
// INPUT: mode 0 : won
//        mode 1 : lost
//        mode 2 : draw

@c @implementation
public func ShowWinLose(_ playerNum: Int16, _ mode: UInt8) -> UnsafeMutablePointer<ObjNode>? {
    let spriteNum: Int32
    switch mode {
    case 0:
        spriteNum = Int32(INFOBAR_SObjType_YouWin)
    case 1:
        spriteNum = Int32(INFOBAR_SObjType_YouLose)
    case 2:
        spriteNum = Int32(INFOBAR_SObjType_YouDraw)
    default:
        return nil
    }

    // TODO: deferred-draw sprites don't honor current 2D viewport scaling!
    var def = NewObjectDefinitionType()
    def.coord = OGLPoint3D(x: anchorCenterX(0), y: anchorBottom(80), z: 0)
    def.flags = UInt32(STATUS_BIT_ONLYSHOWTHISPLAYER)
    def.slot = Int16(SPRITE_SLOT)
    def.moveCall = nil
    def.rot = 0
    def.scale = 230
    def.group = UInt8(SPRITE_GROUP_INFOBAR)
    def.type = UInt8(spriteNum)

    let newObj = MakeSpriteObject(&def, 1)!
    newObj.pointee.PlayerNum = UInt8(playerNum) // only show for this player
    return newObj
}

// MARK: - Draw player arrows

private func infobarDrawPlayerArrows() {
    var v = OGLVector2D()
    var v2 = OGLVector2D()

    // GET ANGLE TO P2
    if gCurrentSplitScreenPane == 0 {
        let pi0 = GetPlayerInfoEntry(0)!
        let pi1 = GetPlayerInfoEntry(1)!

        v.x = pi1.pointee.coord.x - pi0.pointee.coord.x // calc vector from P1 to P2
        v.y = pi1.pointee.coord.z - pi0.pointee.coord.z
        FastNormalizeVector2D(v.x, v.y, &v, 0)

        v2.x = pi0.pointee.objNode!.pointee.MotionVector.x // get aim vector of P1
        v2.y = pi0.pointee.objNode!.pointee.MotionVector.z
    }
    // GET ANGLE TO P1
    else {
        let pi0 = GetPlayerInfoEntry(0)!
        let pi1 = GetPlayerInfoEntry(1)!

        v.x = pi0.pointee.coord.x - pi1.pointee.coord.x // calc vector from P2 to P1
        v.y = pi0.pointee.coord.z - pi1.pointee.coord.z
        FastNormalizeVector2D(v.x, v.y, &v, 0)

        v2.x = pi1.pointee.objNode!.pointee.MotionVector.x // get aim vector of P2
        v2.y = pi1.pointee.objNode!.pointee.MotionVector.z
    }

    // SEE WHICH ARROW TO DRAW
    var dot = OGLVector2D_Dot(&v, &v2) // calc angle between
    dot = acosf(dot)
    if dot > 0.8 {
        gGlobalTransparency = 0.8
        let cross = OGLVector2D_Cross(&v, &v2) // sign of cross tells us which side
        if cross > 0.0 {
            DrawInfobarSprite(anchorLeft(0), anchorCenterY(0), ARROW_SCALE, Int16(INFOBAR_SObjType_LeftArrow))
        } else {
            DrawInfobarSprite(anchorRight(ARROW_SCALE), anchorCenterY(0), ARROW_SCALE, Int16(INFOBAR_SObjType_RightArrow))
        }
        gGlobalTransparency = 1.0
    }
}

// MARK: - Draw anaglyph crosshairs

private let cDrawAnaglyphCrosshairs: @convention(c) (UnsafeMutablePointer<ObjNode>?) -> Void = { _ in
    drawAnaglyphCrosshairs()
}

private func drawAnaglyphCrosshairs() {
    let playerNum = gCurrentSplitScreenPane

    if gGamePrefs.showTargetingCrosshairs == 0 {
        return
    }

    if GetPlayerIsDead(Int32(playerNum)) != 0 { // dont draw if player is dead
        return
    }

    if GetCameraMode(Int32(playerNum)) == UInt8(CameraMode.firstPerson.rawValue) { // don't draw in 1st person camera
        return
    }

    let pi = GetPlayerInfoEntry(Int32(playerNum))!

    // ONLY SHOW CROSSHAIRS FOR CERTAIN WEAPONS
    if Int(pi.pointee.currentWeapon) == Int(WeaponType.bomb.rawValue) {
        return
    }

    // DON'T SHOW DURING DUST DEVIL
    if Int(pi.pointee.objNode!.pointee.Skeleton!.pointee.AnimNum) == Int(PlayerAnim.dustDevil.rawValue) {
        return
    }

    let lockedOn = pi.pointee.crosshairTargetObj != nil // see if an object is targeted

    var up = OGLVector3D(x: 0, y: 1, z: 0)

    for i in 0..<1 { // NUM_CROSSHAIR_LEVELS
        var m = OGLMatrix4x4()
        withUnsafeMutablePointer(to: &up) { upPtr in
            SetLookAtMatrixAndTranslate(&m, upPtr, crosshairCoordBase(pi) + i, &pi.pointee.coord)
        }

        glPushMatrix()
        withUnsafePointer(to: &m) {
            $0.withMemoryRebound(to: Float.self, capacity: 16) { glMultMatrixf($0) }
        }

        // DRAW LARGE
        if i == 0 {
            let size: Float = 45.0
            let size2: Float = 35.0

            MO_DrawMaterial(GetSpriteGroupPtr(Int32(SPRITE_GROUP_INFOBAR))![Int(INFOBAR_SObjType_GunSight_OuterRing)].materialObject?.assumingMemoryBound(to: MOMaterialObject.self)) // activate material

            glBegin(GLenum(GL_QUADS))
            glTexCoord2f(0, 0); glVertex2f(-size, -size)
            glTexCoord2f(0, 1); glVertex2f(-size, size)
            glTexCoord2f(1, 1); glVertex2f(size, size)
            glTexCoord2f(1, 0); glVertex2f(size, -size)
            glEnd()

            if lockedOn {
                MO_DrawMaterial(GetSpriteGroupPtr(Int32(SPRITE_GROUP_INFOBAR))![Int(INFOBAR_SObjType_GunSight_Locked)].materialObject?.assumingMemoryBound(to: MOMaterialObject.self)) // activate material

                glBegin(GLenum(GL_QUADS))
                glTexCoord2f(0, 0); glVertex2f(-size, -size)
                glTexCoord2f(0, 1); glVertex2f(-size, size)
                glTexCoord2f(1, 1); glVertex2f(size, size)
                glTexCoord2f(1, 0); glVertex2f(size, -size)
                glEnd()
            } else {
                MO_DrawMaterial(GetSpriteGroupPtr(Int32(SPRITE_GROUP_INFOBAR))![Int(INFOBAR_SObjType_GunSight_Normal)].materialObject?.assumingMemoryBound(to: MOMaterialObject.self)) // activate material

                glBegin(GLenum(GL_QUADS))
                glTexCoord2f(0, 0); glVertex2f(-size2, -size2)
                glTexCoord2f(0, 1); glVertex2f(-size2, size2)
                glTexCoord2f(1, 1); glVertex2f(size2, size2)
                glTexCoord2f(1, 0); glVertex2f(size2, -size2)
                glEnd()

                MO_DrawMaterial(GetSpriteGroupPtr(Int32(SPRITE_GROUP_INFOBAR))![Int(INFOBAR_SObjType_GunSight_Pointer)].materialObject?.assumingMemoryBound(to: MOMaterialObject.self)) // activate material

                glBegin(GLenum(GL_QUADS))
                glTexCoord2f(0, 0); glVertex2f(-size, -size)
                glTexCoord2f(0, 1); glVertex2f(-size, size)
                glTexCoord2f(1, 1); glVertex2f(size, size)
                glTexCoord2f(1, 0); glVertex2f(size, -size)
                glEnd()
            }
        }
        // DRAW SMALL
        else {
            let size: Float = 30.0

            MO_DrawMaterial(GetSpriteGroupPtr(Int32(SPRITE_GROUP_INFOBAR))![Int(INFOBAR_SObjType_GunSight_Normal)].materialObject?.assumingMemoryBound(to: MOMaterialObject.self)) // activate material

            glBegin(GLenum(GL_QUADS))
            glTexCoord2f(0, 0); glVertex2f(-size, -size)
            glTexCoord2f(0, 1); glVertex2f(-size, size)
            glTexCoord2f(1, 1); glVertex2f(size, size)
            glTexCoord2f(1, 0); glVertex2f(size, -size)
            glEnd()
        }

        glPopMatrix()
    }
}

@inline(__always) private func crosshairCoordBase(_ p: UnsafeMutablePointer<PlayerInfoType>) -> UnsafeMutablePointer<OGLPoint3D> {
    UnsafeMutableRawPointer(p.pointer(to: \.crosshairCoord)!).assumingMemoryBound(to: OGLPoint3D.self)
}

// MARK: - Draw infobar crosshairs

private var gCrosshairSpinAngle: Float = 0

private func infobarDrawCrosshairs() {
    let playerNum = gCurrentSplitScreenPane

    if gGamePrefs.showTargetingCrosshairs == 0 {
        return
    }

    if GetPlayerIsDead(Int32(playerNum)) != 0 { // dont draw if player is dead
        return
    }

    if gCameraInExitMode != 0 {
        return
    }

    if isStereo() {
        return
    }

    if GetCameraMode(Int32(playerNum)) == UInt8(CameraMode.firstPerson.rawValue) { // don't draw in 1st person camera
        return
    }

    let pi = GetPlayerInfoEntry(Int32(playerNum))!

    // ONLY SHOW CROSSHAIRS FOR CERTAIN WEAPONS
    if Int(pi.pointee.currentWeapon) == Int(WeaponType.bomb.rawValue) {
        return
    }

    // DON'T SHOW DURING DUST DEVIL
    if Int(pi.pointee.objNode!.pointee.Skeleton!.pointee.AnimNum) == Int(PlayerAnim.dustDevil.rawValue) {
        return
    }

    // DONT DRAW IF PLAYER IS > n DEGREES TO CAMERA
    let v1 = pi.pointee.objNode!.pointee.MotionVector
    let v2 = pi.pointee.camera.cameraAim

    var v1m = v1
    var v2m = v2
    let dot = OGLVector3D_Dot(&v1m, &v2m)
    if dot < -0.1 {
        return
    }

    // CALC ADJUSTMENT FOR SCREEN COORDS TO OUR 640X480 COORDS
    var px: Int32 = 0, py: Int32 = 0, pw: Int32 = 0, ph: Int32 = 0
    OGL_GetCurrentViewport(&px, &py, &pw, &ph, playerNum)

    let lrw = gLogicalRect.right - gLogicalRect.left
    let lrh = gLogicalRect.bottom - gLogicalRect.top

    let screenToPaneX = lrw / Float(pw)
    let screenToPaneY = lrh / Float(ph)

    // SET SCALE BASED ON ASPECT RATIO
    let scale: Float = GUNSIGHT_SCALE

    // DRAW AUTO-TARGET CROSSHAIRS
    gGlobalTransparency = 0.8

    let lockedOn = pi.pointee.crosshairTargetObj != nil // see if an object is targeted

    // CALC SCREEN COORD
    var screenCoord = OGLPoint3D()
    OGLPoint3D_Transform(crosshairCoordBase(pi) + 0, GetWorldToWindowMatrixEntry(Int32(playerNum)), &screenCoord)
    screenCoord.x = screenCoord.x * screenToPaneX
    screenCoord.y = screenCoord.y * screenToPaneY
    screenCoord.x += gLogicalRect.left
    screenCoord.y += gLogicalRect.top

    if lockedOn {
        gCrosshairSpinAngle += gFramesPerSecondFrac * SwPI2
        drawInfobarSpriteRotated(screenCoord.x, screenCoord.y, scale * 1.3, Int16(INFOBAR_SObjType_GunSight_Locked), gCrosshairSpinAngle)
        DrawInfobarSprite_Centered(screenCoord.x, screenCoord.y, scale * 1.6, Int16(INFOBAR_SObjType_GunSight_OuterRing))
    } else {
        DrawInfobarSprite_Centered(screenCoord.x, screenCoord.y, scale, Int16(INFOBAR_SObjType_GunSight_Normal))

        var v3 = OGLVector3D()
        OGLVector3D_Cross(&v1m, &v2m, &v3)
        var r: Float
        if v3.y > 0.0 {
            r = -dot + 1.0
        } else {
            r = dot - 1.0
        }

        r *= 25.0
        drawInfobarSpriteRotated(screenCoord.x, screenCoord.y, scale * 1.6, Int16(INFOBAR_SObjType_GunSight_Pointer), r)
    }

    // DRAW FAR TARGET
    gGlobalTransparency = 1.0

    OGLPoint3D_Transform(crosshairCoordBase(pi) + 1, GetWorldToWindowMatrixEntry(Int32(playerNum)), &screenCoord)
    screenCoord.x = screenCoord.x * screenToPaneX
    screenCoord.y = screenCoord.y * screenToPaneY
    screenCoord.x += gLogicalRect.left
    screenCoord.y += gLogicalRect.top

    DrawInfobarSprite_Centered(screenCoord.x, screenCoord.y, scale * 0.6, Int16(INFOBAR_SObjType_GunSight_Normal))
}
