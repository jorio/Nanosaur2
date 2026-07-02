// Menu.swift - Port of Menu.c to Swift using @c @implementation (Swift 6.3)

// MARK: - Constants

private let kMouseHoverTolerance: Float = 5
private let kMinClickableWidth: Float = 80
private let kDefaultX: Float = 320
private let k2ColumnLeftX: Float = kDefaultX - 220
private let k2ColumnRightX: Float = kDefaultX + 140
private let kSfxCycle: Int16 = Int16(EFFECT_GRABEGG)
private let kTextMeshUserFlag_AltFont: Int32 = Int32(kTextMeshUserFlag1)
private let kTextMeshAlignCenterFlag: Int32 = Int32(kTextMeshAlignCenter)
private let kTextMeshAlignLeftFlag: Int32 = Int32(kTextMeshAlignLeft)
private let kTextMeshAllCapsFlag: Int32 = Int32(kTextMeshAllCaps)
private let kTextMeshSmallCapsFlag: Int32 = Int32(kTextMeshSmallCaps)
private let kJoystickDeadZone_BindingThreshold: Int32 = 75 * 32767 / 100
private let FULL_CHANNEL_VOLUME: UInt32 = 0x0100
private let NORMAL_CHANNEL_RATE: UInt = 0x10000
private let CLEAR_BINDING_SCANCODE: Int32 = Int32(SDL_SCANCODE_X.rawValue)
private let BACK_FOURCC: Int32 = 0x4241434B
private let EXIT_FOURCC: Int32 = 0x45584954
private let NOOP_FOURCC: Int32 = 0x4E4F4F50
private let ANY_PLAYER: Int = -1

@inline(__always) private func playEffectForMenu(_ x: Int16) { PlayEffect_Parms(x, FULL_CHANNEL_VOLUME/4, FULL_CHANNEL_VOLUME/4, NORMAL_CHANNEL_RATE) }
@inline(__always) private func playNavigateEffect() { playEffectForMenu(Int16(EFFECT_CHANGESELECT)) }
@inline(__always) private func playConfirmEffect() { playEffectForMenu(Int16(EFFECT_MENUSELECT)) }
@inline(__always) private func playBackEffect() { playEffectForMenu(Int16(EFFECT_CHANGEWEAPON)) }
@inline(__always) private func playErrorEffect() { playEffectForMenu(Int16(EFFECT_BADSELECT)) }
@inline(__always) private func playDeleteEffect() { playEffectForMenu(Int16(EFFECT_CRYSTALSHATTER)) }
@inline(__always) private func playStartBindingEffect() { playEffectForMenu(Int16(EFFECT_GRABEGG)) }
@inline(__always) private func playEndBindingEffect() { playEffectForMenu(Int16(EFFECT_MENUSELECT)) }

@inline(__always)
private func getMenuNodeData(_ node: UnsafeMutablePointer<ObjNode>!) -> UnsafeMutablePointer<MenuNodeData> {
    UnsafeMutableRawPointer(node.withMemoryRebound(to: UInt8.self, capacity: Int(MAX_SPECIAL_DATA_BYTES)) { $0 })
        .assumingMemoryBound(to: MenuNodeData.self)
}

// MARK: - Array access helpers

@inline(__always) private func mObj(_ i: Int) -> UnsafeMutablePointer<ObjNode>? { Nav_GetMenuObject(gNav, Int32(i)) }
@inline(__always) private func setMObj(_ i: Int, _ v: UnsafeMutablePointer<ObjNode>?) { Nav_SetMenuObject(gNav, Int32(i), v) }
@inline(__always) private func mRowY(_ i: Int) -> Float { Nav_GetMenuRowY(gNav, Int32(i)) }
@inline(__always) private func setMRowY(_ i: Int, _ v: Float) { Nav_SetMenuRowY(gNav, Int32(i), v) }
@inline(__always) private func histMID(_ i: Int32) -> Int32 { Int32(Nav_GetHistoryMenuID(gNav, i)) }
@inline(__always) private func setHistMID(_ i: Int32, _ v: Int32) { Nav_SetHistoryMenuID(gNav, i, v) }
@inline(__always) private func histRow(_ i: Int32) -> Int32 { Nav_GetHistoryRow(gNav, i) }
@inline(__always) private func setHistRow(_ i: Int32, _ v: Int32) { Nav_SetHistoryRow(gNav, i, v) }

// MARK: - Menu item height dispatch

private func menuItemHeight(_ type: MenuItemType) -> Float {
    switch type {
    case kMISENTINEL: return 0.0; case kMILabel: return 0.9; case kMISpacer: return 0.5
    case kMICycler1, kMICycler2, kMISlider, kMIPick, kMIFileSlot: return 1.0
    case kMIKeyBinding, kMIPadBinding, kMIMouseBinding: return 0.8
    default: return 1.0
    }
}

// MARK: - Navigation struct

private func initMenuNavigation() {
    SwGameAssert(gNav == nil)
    gNav = AllocPtrClear(MemoryLayout<MenuNavigation>.size)!.assumingMemoryBound(to: MenuNavigation.self)
    let nav = gNav!
    CopyDefaultMenuStyle(&nav.pointee.style)
    nav.pointee.menuPick = -1; nav.pointee.menuState = .kMenuStateOff
    nav.pointee.mouseState = .kMouseOff; nav.pointee.mouseFocusComponent = -1
    var arrowDef = NewObjectDefinitionType()
    arrowDef.scale = 1; arrowDef.slot = nav.pointee.style.textSlot
    arrowDef.group = UInt8(nav.pointee.style.fontAtlas); arrowDef.flags = UInt32(STATUS_BIT_MOVEINPAUSE)
    for i in 0..<2 {
        let arrow = TextMesh_New(i == 0 ? "(" : ")", 0, &arrowDef)!
        arrow.pointee.ColorFilter = nav.pointee.style.arrowColor
        SendNodeToOverlayPane(arrow)
        Nav_SetArrow(nav, Int32(i), arrow)
    }
}

private func disposeMenuNavigation() {
    let nav = gNav!
    for i in 0..<2 { if let a = Nav_GetArrow(nav, Int32(i)) { DeleteObject(a); Nav_SetArrow(nav, Int32(i), nil) } }
    SafeDisposePtr(UnsafeMutableRawPointer(nav))
    gNav = nil
}

// MARK: - Public API

@c @implementation
public func GetCurrentMenu() -> Int32 { gNav != nil ? gNav!.pointee.menuID : 0 }

@c @implementation
public func GetMenuIdleTime() -> Float { gNav != nil ? gNav!.pointee.idleTime : 0.0 }

@c @implementation
public func IsMenuMouseControlled() -> Bool { gNav != nil ? gNav!.pointee.mouseState != .kMouseOff : false }

@c @implementation
public func GetCurrentMenuItemID() -> Int32 {
    guard let nav = gNav, nav.pointee.focusRow >= 0 else { return -1 }
    return nav.pointee.menu![Int(nav.pointee.focusRow)].id
}

@c @implementation
public func GetCurrentMenuItemObject() -> UnsafeMutablePointer<ObjNode>? {
    guard let nav = gNav, nav.pointee.focusRow >= 0 else { return nil }
    return mObj(Int(nav.pointee.focusRow))
}

@c @implementation
public func IsMenuTreeEndSentinel(_ menuItem: UnsafePointer<MenuItem>) -> Bool {
    menuItem.pointee.id == 0 && menuItem.pointee.type == kMISENTINEL
}

@c @implementation
public func DisableEmptyFileSlots(_ menuItem: UnsafePointer<MenuItem>) -> Int32 {
    let mask = gNav?.pointee.validSaveSlotMask ?? 0
    let need = Int64(MenuItem_GetInputNeed(menuItem))
    let isValid = (mask >> UInt64(need)) & 1
    return isValid != 0 ? 0 : Int32(kMILayoutFlagDisabled)
}

@c @implementation
public func KillMenu(_ returnCode: Int32) {
    if gNav!.pointee.menuState == .kMenuStateReady {
        gNav!.pointee.menuPick = returnCode; gNav!.pointee.menuState = .kMenuStateFadeOut
    }
}

@c @implementation
public func LayoutCurrentMenuAgain(_ animate: Bool) {
    SwGameAssert(gNav != nil); SwGameAssert(gNav!.pointee.menu != nil)
    gNav!.pointee.sweepDelay = animate ? 0 : -100000
    saveSelectedRowInHistory()
    layOutMenu(gNav!.pointee.menuID)
}

@c @implementation
public func RegisterMenu(_ menuTree: UnsafePointer<MenuItem>) {
    var mi = menuTree
    while mi.pointee.type != kMISENTINEL || mi.pointee.id != 0 {
        if mi.pointee.type == kMISENTINEL {
            if mi.pointee.id == 0 { break }
            if lookUpMenu(mi.pointee.id) != nil { mi = mi.successor(); continue }
            SwGameAssert(gNumMenusRegistered < MAX_REGISTERED_MENUS)
            SetRegistryEntry(gNumMenusRegistered, mi)
            gNumMenusRegistered += 1
        }
        mi = mi.successor()
    }
}

@c @implementation
public func MakeMenu(_ menu: UnsafePointer<MenuItem>, _ style: UnsafePointer<MenuStyle>?) -> UnsafeMutablePointer<ObjNode> {
    var driverDef = NewObjectDefinitionType()
    driverDef.scale = 1; driverDef.slot = Int16(MENU_SLOT); driverDef.genre = UInt8(EVENT_GENRE)
    driverDef.flags = UInt32(STATUS_BIT_MOVEINPAUSE | STATUS_BIT_DONTCULL)
    driverDef.moveCall = cMoveMenuDriver
    let driverNode = MakeNewObject(&driverDef)!
    gNumMenusRegistered = 0
    RegisterMenu(menu)
    initMenuNavigation()
    gMenuOutcome = 0
    gNav!.pointee.menuState = .kMenuStateFadeIn; gNav!.pointee.menuFadeAlpha = 0; gNav!.pointee.focusRow = -1
    if let style { SDL_memcpy(&gNav!.pointee.style, style, MemoryLayout<MenuStyle>.size) }
    gNav!.pointee.sweepDelay = 0; gNav!.pointee.sweepRTL = false
    gNav!.pointee.darkenPane = nil
    if gNav!.pointee.style.darkenPaneOpacity > 0.0 { gNav!.pointee.darkenPane = makeDarkenPane() }
    layOutMenu(menu.pointee.id)
    return driverNode
}

// MARK: - Utilities

private func getLayoutFlags(_ mi: UnsafePointer<MenuItem>!) -> Int32 {
    if let cb = mi.pointee.getLayoutFlags { return Int32(cb(mi)) }; return 0
}
private func isMenuItemSelectable(_ mi: UnsafePointer<MenuItem>!) -> Bool {
    switch mi.pointee.type { case kMISpacer, kMILabel: return false
    default: return (getLayoutFlags(mi) & Int32(kMILayoutFlagHidden | kMILayoutFlagDisabled)) == 0 }
}
private func getMenuItemHeight(_ row: Int32) -> Float {
    let mi = gNav!.pointee.menu!.advanced(by: Int(row))
    if (getLayoutFlags(mi) & Int32(kMILayoutFlagHidden)) != 0 { return 0 }
    if mi.pointee.customHeight > 0 { return mi.pointee.customHeight }
    return menuItemHeight(mi.pointee.type)
}
private func getMenuItemText(_ entry: UnsafePointer<MenuItem>!) -> String {
    if let raw = entry.pointee.rawText { return String(cString: raw) }
    return String(cString: Localize(entry.pointee.text))
}
private func pulsateColor(_ time: UnsafeMutablePointer<Float>!) -> OGLColorRGBA {
    time.pointee += gFramesPerSecondFrac
    let intensity = (1.0 + sinf(time.pointee * 10.0)) * Float(0.5)
    return OGLColorRGBA(r: 1, g: 1, b: 1, a: intensity)
}
private func setMaxTextWidth(_ textNode: UnsafeMutablePointer<ObjNode>!, _ maxWidth: Float) {
    getMenuNodeData(textNode).pointee.maxWidth = maxWidth
    textNode.pointee.Scale.x = textNode.pointee.Scale.y
    if maxWidth <= Float(EPS) { return }
    let ext = TextMesh_GetExtents(textNode); let w = ext.right - ext.left
    if w > maxWidth { textNode.pointee.Scale.x *= maxWidth / w; UpdateObjectTransforms(textNode) }
}
private func setMinClickableWidth(_ textNode: UnsafeMutablePointer<ObjNode>!, _ minWidth: Float) {
    let ext = TextMesh_GetExtents(textNode); let w = ext.right - ext.left
    if w < minWidth { let pad = Float(0.5) * (minWidth - w); textNode.pointee.LeftOff -= pad; textNode.pointee.RightOff += pad }
}

// MARK: - Binding helpers

private func getBindingAtRow(_ row: Int32) -> UnsafeMutablePointer<InputBinding> {
    let need = Int(MenuItem_GetInputNeed(gNav!.pointee.menu!.advanced(by: Int(row))))
    return withUnsafeMutablePointer(to: &gGamePrefs.bindings) {
        $0.withMemoryRebound(to: InputBinding.self, capacity: need + 1) { $0.advanced(by: need) }
    }
}

// MARK: - Current interactable item

private func getCurrentInteractableMenuItemObject() -> UnsafeMutablePointer<ObjNode>? {
    guard let obj = GetCurrentMenuItemObject() else { return nil }
    let nav = gNav!; let t = nav.pointee.menu![Int(nav.pointee.focusRow)].type
    switch t {
    case kMIKeyBinding, kMIPadBinding: return GetNthChainedNode(obj, nav.pointee.focusComponent, nil)
    case kMIMouseBinding, kMICycler2, kMIFileSlot: return GetNthChainedNode(obj, 1, nil)
    case kMISlider: return GetNthChainedNode(obj, 4, nil)
    default: return obj
    }
}

// MARK: - Twitch effects

private func twitchSelectionInOrOut(_ scaleIn: Bool) {
    guard let obj = getCurrentInteractableMenuItemObject() else { return }
    let xSquish = obj.pointee.Scale.x / obj.pointee.Scale.y
    let s = getMenuItemHeight(gNav!.pointee.focusRow) * gNav!.pointee.style.standardScale
    obj.pointee.Scale.x = s * (scaleIn ? Float(1.1) : Float(1.0)) * xSquish
    obj.pointee.Scale.y = s * (scaleIn ? Float(1.1) : Float(1.0))
    _ = MakeTwitch(obj, Int32((scaleIn ? kTwitchPreset_MenuSelect : kTwitchPreset_MenuDeselect) | kTwitchFlags_Chain))
}
private func twitchSelection() { twitchSelectionInOrOut(true) }
private func twitchOutSelection() { twitchSelectionInOrOut(false) }
private func twitchSelectionNopeWiggle() {
    _ = MakeTwitch(getCurrentInteractableMenuItemObject(), Int32(kTwitchPreset_MenuSelect))
    _ = MakeTwitch(Nav_GetArrow(gNav!, 0), Int32(kTwitchPreset_PadlockWiggle))
    _ = MakeTwitch(Nav_GetArrow(gNav!, 1), Int32(kTwitchPreset_PadlockWiggle))
    playErrorEffect()
}

// MARK: - Darken pane

private let cMoveDarkenPane: @convention(c) (UnsafeMutablePointer<ObjNode>?) -> Void = { node in
    guard let node = node else { return }
    var t = node.pointee.Timer + gFramesPerSecondFrac * Float(5.0); if t > 1 { t = 1 }
    node.pointee.Scale.y = node.pointee.SpecialF.0 * (1 - t) + node.pointee.SpecialF.1 * t
    node.pointee.Timer = t
}
private let cDrawDarkenPane: @convention(c) (UnsafeMutablePointer<ObjNode>?) -> Void = { node in
    guard let node = node else { return }
    OGL_PushState(); SetInfobarSpriteState(0, 1); OGL_DisableTexture2D(); OGL_EnableBlend(); OGL_EnableCullFace()
    glBegin(UInt32(GL_QUADS))
    let s = node.pointee.Scale.y; let menuTop = node.pointee.Coord.y - s/2; let menuBottom = node.pointee.Coord.y + s/2
    let taper: Float = 16; let c = node.pointee.ColorFilter
    glColor4f(c.r, c.g, c.b, 0); glVertex2f(gLogicalRect.right, menuTop - taper); glVertex2f(gLogicalRect.left, menuTop - taper)
    glColor4f(c.r, c.g, c.b, c.a); glVertex2f(gLogicalRect.left, menuTop); glVertex2f(gLogicalRect.right, menuTop)
    glVertex2f(gLogicalRect.right, menuTop); glVertex2f(gLogicalRect.left, menuTop); glVertex2f(gLogicalRect.left, menuBottom); glVertex2f(gLogicalRect.right, menuBottom)
    glVertex2f(gLogicalRect.right, menuBottom); glVertex2f(gLogicalRect.left, menuBottom)
    glColor4f(c.r, c.g, c.b, 0); glVertex2f(gLogicalRect.left, menuBottom + taper); glVertex2f(gLogicalRect.right, menuBottom + taper)
    glEnd(); OGL_PopState()
}
private func rescaleDarkenPane(_ node: UnsafeMutablePointer<ObjNode>!, _ totalHeight: Float) {
    node.pointee.SpecialF.0 = node.pointee.SpecialF.1; node.pointee.SpecialF.1 = totalHeight; node.pointee.Timer = 0
}
private func makeDarkenPane() -> UnsafeMutablePointer<ObjNode> {
    var def = NewObjectDefinitionType()
    def.genre = UInt8(CUSTOM_GENRE); def.flags = UInt32(SwStatusBitsFor2D) | UInt32(STATUS_BIT_MOVEINPAUSE)
    def.slot = Int16(gNav!.pointee.style.textSlot - 1); def.scale = 1
    def.coord = (OGLPoint3D(x: kDefaultX, y: gNav!.pointee.style.yOffset, z: 0))
    def.moveCall = cMoveDarkenPane; def.drawCall = cDrawDarkenPane
    let pane = MakeNewObject(&def)!
    pane.pointee.Scale.y = Float(EPS)
    pane.pointee.ColorFilter = OGLColorRGBA(r: 0, g: 0, b: 0, a: gNav!.pointee.style.darkenPaneOpacity)
    SendNodeToOverlayPane(pane)
    return pane
}

// MARK: - Move callbacks

private func moveGenericMenuItem(_ node: UnsafeMutablePointer<ObjNode>!, _ baseAlpha: Float) {
    var a = baseAlpha; if getMenuNodeData(node).pointee.muted != 0 { a *= Float(0.5) }
    node.pointee.ColorFilter.a = a
}
private let cMoveLabel: @convention(c) (UnsafeMutablePointer<ObjNode>?) -> Void = { node in
    guard let node = node else { return }; moveGenericMenuItem(node, 1)
}
private let cMoveAction: @convention(c) (UnsafeMutablePointer<ObjNode>?) -> Void = { node in
    guard let node = node else { return }
    if getMenuNodeData(node).pointee.row == gNav!.pointee.focusRow { node.pointee.ColorFilter = gNav!.pointee.style.highlightColor }
    else { node.pointee.ColorFilter = gNav!.pointee.style.idleColor }
    moveGenericMenuItem(node, 1)
}
private let cMoveControlBinding: @convention(c) (UnsafeMutablePointer<ObjNode>?) -> Void = { node in
    guard let node = node else { return }
    let data = getMenuNodeData(node)
    let miType = gNav!.pointee.menu![Int(data.pointee.row)].type
    var ps: MenuState = .kMenuStateOff
    switch miType {
    case kMIKeyBinding: ps = .kMenuStateAwaitingKeyPress
    case kMIPadBinding: ps = .kMenuStateAwaitingPadPress
    case kMIMouseBinding: ps = .kMenuStateAwaitingMouseClick
    default: SwFatal("MoveControlBinding: unknown MI type")
    }
    if data.pointee.row == gNav!.pointee.focusRow && data.pointee.component == gNav!.pointee.focusComponent {
        if gNav!.pointee.menuState == ps { node.pointee.ColorFilter = pulsateColor(&data.pointee.pulsateTimer) }
        else { node.pointee.ColorFilter = gNav!.pointee.style.highlightColor }
    } else { node.pointee.ColorFilter = gNav!.pointee.style.idleColor }
    moveGenericMenuItem(node, node.pointee.ColorFilter.a)
}

// MARK: - History

private func saveSelectedRowInHistory() { setHistRow(gNav!.pointee.historyPos, gNav!.pointee.focusRow) }
private func goBackInHistory() {
    MyFlushEvents()
    if gNav!.pointee.historyPos != 0 {
        playBackEffect(); gNav!.pointee.historyPos -= 1
        gNav!.pointee.sweepRTL = true; layOutMenu(histMID(gNav!.pointee.historyPos))
        gNav!.pointee.sweepRTL = false
    } else if MenuStyle_GetCanBackOutOfRootMenu(&gNav!.pointee.style) { playBackEffect(); gNav!.pointee.menuState = .kMenuStateFadeOut }
    else { playErrorEffect() }
}

// MARK: - Navigation dispatch

private func navigateMenuItem(_ type: MenuItemType, _ entry: UnsafePointer<MenuItem>!) {
    switch type {
    case kMICycler1, kMICycler2: navigateCycler(entry)
    case kMISlider: navigateSlider(entry)
    case kMIPick, kMIFileSlot: navigatePick(entry)
    case kMIKeyBinding: navigateKeyBinding(entry)
    case kMIPadBinding: navigatePadBinding(entry)
    case kMIMouseBinding: navigateMouseBinding(entry)
    default: break
    }
}
private func navigateMenu() {
    SwGameAssert(MenuStyle_GetIsInteractive(&gNav!.pointee.style))
    if SwIsNeedDown(kNeed_UIBack, ANY_PLAYER) || SwIsClickDown(Int(SDL_BUTTON_X1)) { goBackInHistory(); return }
    if SwIsNeedDown(kNeed_UIUp, ANY_PLAYER) { navigateMenuVertically(-1); saveSelectedRowInHistory(); gNav!.pointee.mouseState = .kMouseOff }
    else if SwIsNeedDown(kNeed_UIDown, ANY_PLAYER) { navigateMenuVertically(1); saveSelectedRowInHistory(); gNav!.pointee.mouseState = .kMouseOff }
    else { navigateMenuMouseHover() }
    let entry = gNav!.pointee.menu!.advanced(by: Int(gNav!.pointee.focusRow))
    navigateMenuItem(entry.pointee.type, entry)
}
private func navigateMenuVertically(_ delta: Int32) {
    let makeSound = gNav!.pointee.focusRow >= 0; var browsed = 0
    twitchOutSelection()
    var skip = true
    while skip {
        gNav!.pointee.focusRow += delta
        gNav!.pointee.focusRow = Int32(PositiveModulo(gNav!.pointee.focusRow, UInt32(gNav!.pointee.numRows)))
        skip = !isMenuItemSelectable(gNav!.pointee.menu!.advanced(by: Int(gNav!.pointee.focusRow)))
        browsed += 1; if browsed > gNav!.pointee.numRows { return }
    }
    gNav!.pointee.idleTime = 0
    if makeSound { playNavigateEffect(); twitchSelection() }
}
private func navigateMenuMouseHover() {
    if gNav!.pointee.mouseState == .kMouseGrabbing { return }
    var cursor = OGLPoint2D(x: -1, y: -1)
    if cursor.x == gCursorCoord.x && cursor.y == gCursorCoord.y { return }
    cursor = gCursorCoord
    gNav!.pointee.mouseState = .kMouseWandering; gNav!.pointee.mouseFocusComponent = -1
    for row in 0..<gNav!.pointee.numRows {
        let mi = gNav!.pointee.menu!.advanced(by: Int(row))
        if !isMenuItemSelectable(mi) { continue }
        var fe = OGLRect(top: 100000, bottom: -100000, left: 100000, right: -100000)
        var textNode = mObj(Int(row)); var fc: Int32 = -1; var comp: Int32 = 0
        while let tn = textNode {
            let e = TextMesh_GetExtents(tn)
            if e.top < fe.top { fe.top = e.top }; if e.left < fe.left { fe.left = e.left }
            if e.bottom > fe.bottom { fe.bottom = e.bottom }; if e.right > fe.right { fe.right = e.right }
            if cursor.y >= e.top && cursor.y <= e.bottom && cursor.x >= e.left - kMouseHoverTolerance && cursor.x <= e.right + kMouseHoverTolerance { fc = comp }
            textNode = tn.pointee.ChainNode; comp += 1
        }
        if cursor.y >= fe.top && cursor.y <= fe.bottom && cursor.x >= fe.left - kMouseHoverTolerance && cursor.x <= fe.right + kMouseHoverTolerance {
            gNav!.pointee.mouseState = .kMouseHovering; gNav!.pointee.mouseFocusComponent = fc
            if gNav!.pointee.focusRow != Int32(row) {
                gNav!.pointee.idleTime = 0; twitchSelectionInOrOut(false)
                gNav!.pointee.focusRow = Int32(row); playNavigateEffect(); twitchSelectionInOrOut(true)
            }
            return
        }
    }
}
private func updateArrows() {
    var snapTo: UnsafeMutablePointer<ObjNode>? = getCurrentInteractableMenuItemObject()
    let chainRoot = GetCurrentMenuItemObject(); var visible = [false, false]
    let entry = gNav!.pointee.menu!.advanced(by: Int(gNav!.pointee.focusRow))
    switch entry.pointee.type {
    case kMICycler1, kMICycler2:
        let vp = MenuItem_GetCyclerValuePtr(entry)!; let v = vp.pointee; let i = getValueIndexInCycler(entry, v)
        visible[0] = i != 0; visible[1] = i != getCyclerNumChoices(entry) - 1
    case kMIKeyBinding, kMIPadBinding:
        visible = [true, true]
        if gNav!.pointee.menuState == .kMenuStateAwaitingKeyPress || gNav!.pointee.menuState == .kMenuStateAwaitingPadPress || gNav!.pointee.menuState == .kMenuStateAwaitingMouseClick { visible = [false, false] }
    case kMISlider:
        visible[0] = MenuItem_GetSliderValuePtr(entry)!.pointee != MenuItem_GetSliderMin(entry)
        visible[1] = MenuItem_GetSliderValuePtr(entry)!.pointee != MenuItem_GetSliderMax(entry)
        snapTo = chainRoot?.pointee.ChainNode
    case kMIMouseBinding: snapTo = nil
    default: break
    }
    if gNav!.pointee.mouseState != .kMouseOff { snapTo = nil }
    guard let snapTo = snapTo else { for i in 0..<2 { SetObjectVisible(Nav_GetArrow(gNav!, Int32(i))!, 0) }; return }
    let ext = TextMesh_GetExtents(snapTo); let spacing: Float = 45 * snapTo.pointee.Scale.x
    for i in 0..<2 {
        let a = Nav_GetArrow(gNav!, Int32(i))!; SetObjectVisible(a, 1)
        a.pointee.Coord.x = i == 0 ? ext.left - spacing : ext.right + spacing
        a.pointee.Coord.y = snapTo.pointee.Coord.y; a.pointee.Scale = snapTo.pointee.Scale
        a.pointee.ColorFilter.a = visible[i] ? 1 : 0
    }
    for i in 0..<2 { UpdateObjectTransforms(Nav_GetArrow(gNav!, Int32(i))!) }
}

// MARK: - Widget layouts

private func layOutLabel(_ row: Int32) -> UnsafeMutablePointer<ObjNode> {
    let e = gNav!.pointee.menu!.advanced(by: Int(row))
    let l = makeText(getMenuItemText(e), row, 0, kTextMeshSmallCapsFlag | kTextMeshUserFlag_AltFont)
    l.pointee.ColorFilter = gNav!.pointee.style.labelColor; l.pointee.MoveCall = cMoveLabel
    setMaxTextWidth(l, 620); return l
}
private func layOutPick(_ row: Int32) -> UnsafeMutablePointer<ObjNode> {
    let e = gNav!.pointee.menu!.advanced(by: Int(row))
    let o = makeText(getMenuItemText(e), row, 0, 0); o.pointee.MoveCall = cMoveAction
    setMinClickableWidth(o, 80); return o
}
private func navigatePick(_ entry: UnsafePointer<MenuItem>!) {
    let validClick = gNav!.pointee.mouseState == .kMouseHovering && SwIsClickDown(Int(SDL_BUTTON_LEFT))
    if SwIsNeedDown(kNeed_UIConfirm, ANY_PLAYER) || validClick {
        if !validClick { gNav!.pointee.mouseState = .kMouseOff }
        if entry.pointee.next != BACK_FOURCC { playConfirmEffect() }
        gNav!.pointee.idleTime = 0; gNav!.pointee.menuPick = entry.pointee.id
        if let cb = entry.pointee.callback { cb() }
        switch entry.pointee.next {
        case 0, NOOP_FOURCC: twitchSelection()
        case EXIT_FOURCC: gNav!.pointee.menuState = .kMenuStateFadeOut
        case BACK_FOURCC: goBackInHistory()
        default:
            saveSelectedRowInHistory(); gNav!.pointee.historyPos += 1
            setHistMID(gNav!.pointee.historyPos, entry.pointee.next); setHistRow(gNav!.pointee.historyPos, 0)
            layOutMenu(entry.pointee.next)
        }
    }
}

// MARK: - Cycler

private func getCyclerValueText(_ row: Int32) -> String {
    let e = gNav!.pointee.menu!.advanced(by: Int(row))
    if MenuItem_GetCyclerDynamic(e) {
        if let g = MenuItem_GetGenChoiceString(e) { return String(cString: g(MenuItem_GetCyclerValuePtr(e)!.pointee)!) }
        return ""
    }
    let i = getValueIndexInCycler(e, MenuItem_GetCyclerValuePtr(e)!.pointee)
    if i >= 0 { return String(cString: Localize(MenuItem_GetCyclerChoiceText(e, i))) }
    return "VALUE NOT FOUND???"
}
private func layOutCycler2ColumnsValueText(_ row: Int32) -> UnsafeMutablePointer<ObjNode> {
    let n = makeText(getCyclerValueText(row), row, 1, kTextMeshAlignCenterFlag)
    n.pointee.MoveCall = cMoveAction; setMinClickableWidth(n, kMinClickableWidth); setMaxTextWidth(n, 150); return n
}
private func layOutCycler2Columns(_ row: Int32) -> UnsafeMutablePointer<ObjNode> {
    let e = gNav!.pointee.menu!.advanced(by: Int(row))
    let n1 = makeText("\(getMenuItemText(e)):", row, 0, kTextMeshAlignLeftFlag | kTextMeshSmallCapsFlag | kTextMeshUserFlag_AltFont)
    n1.pointee.Coord.x = k2ColumnLeftX; n1.pointee.MoveCall = cMoveAction; setMaxTextWidth(n1, 230); UpdateObjectTransforms(n1)
    let n2 = layOutCycler2ColumnsValueText(row); n2.pointee.Coord.x = k2ColumnRightX; UpdateObjectTransforms(n2)
    return n1
}
private func layOutCycler1Column(_ row: Int32) -> UnsafeMutablePointer<ObjNode> {
    let e = gNav!.pointee.menu!.advanced(by: Int(row))
    let buf: String
    if e.pointee.text == STR_NULL && e.pointee.rawText == nil { buf = getCyclerValueText(row) }
    else { buf = "\(getMenuItemText(e)): \(getCyclerValueText(row))" }
    let n = makeText(buf, row, 0, kTextMeshSmallCapsFlag); n.pointee.MoveCall = cMoveAction; return n
}
private func getCyclerNumChoices(_ e: UnsafePointer<MenuItem>!) -> Int32 {
    if MenuItem_GetCyclerDynamic(e) { if let g = MenuItem_GetGenNumChoices(e) { return g() }; return 0 }
    for i in 0..<MAX_MENU_CYCLER_CHOICES { if MenuItem_GetCyclerChoiceText(e, i) == STR_NULL { return Int32(i) } }
    return Int32(MAX_MENU_CYCLER_CHOICES)
}
private func getValueIndexInCycler(_ e: UnsafePointer<MenuItem>!, _ value: UInt8) -> Int32 {
    if MenuItem_GetCyclerDynamic(e) { return Int32(value) }
    for i in 0..<MAX_MENU_CYCLER_CHOICES { if MenuItem_GetCyclerChoiceText(e, i) == STR_NULL { break }; if MenuItem_GetCyclerChoiceValue(e, i) == value { return Int32(i) } }
    return -1
}
private func getCyclerValueForIndex(_ e: UnsafePointer<MenuItem>!, _ index: Int32) -> UInt8 {
    if MenuItem_GetCyclerDynamic(e) { return UInt8(index) }
    return MenuItem_GetCyclerChoiceValue(e, index)
}
private func navigateCycler(_ e: UnsafePointer<MenuItem>!) {
    var delta: Int32 = 0; var allowWrap = false
    if SwIsNeedDown(kNeed_UIPrev, ANY_PLAYER) { delta = -1; gNav!.pointee.mouseState = .kMouseOff }
    else if SwIsNeedDown(kNeed_UINext, ANY_PLAYER) { delta = 1; gNav!.pointee.mouseState = .kMouseOff }
    else if SwIsNeedDown(kNeed_UIConfirm, ANY_PLAYER) { gNav!.pointee.mouseState = .kMouseOff; twitchSelectionNopeWiggle(); return }
    else if gNav!.pointee.mouseState == .kMouseHovering {
        if SwIsClickDown(Int(SDL_BUTTON_LEFT)) { delta = 1; allowWrap = true }
        else if SwIsClickDown(Int(SDL_BUTTON_RIGHT)) { delta = -1; allowWrap = true }
        else if SwIsClickDown(Int(SDL_BUTTON_WHEELDOWN)) || SwIsClickDown(Int(SDL_BUTTON_WHEELLEFT)) { delta = -1 }
        else if SwIsClickDown(Int(SDL_BUTTON_WHEELUP)) || SwIsClickDown(Int(SDL_BUTTON_WHEELRIGHT)) { delta = 1 }
    }
    if delta != 0 {
        gNav!.pointee.idleTime = 0; gNav!.pointee.sweepRTL = delta == -1
        if let vp = MenuItem_GetCyclerValuePtr(e) {
            var i = getValueIndexInCycler(e, vp.pointee)
            if !allowWrap && ((i == 0 && delta < 0) || (i == getCyclerNumChoices(e) - 1 && delta > 0)) { twitchSelectionNopeWiggle(); return }
            if i >= 0 { i = Int32(PositiveModulo(i + delta, UInt32(getCyclerNumChoices(e)))) } else { i = 0 }
            vp.pointee = getCyclerValueForIndex(e, i)
            PlayEffect_Parms(kSfxCycle, FULL_CHANNEL_VOLUME/4, FULL_CHANNEL_VOLUME/4, NORMAL_CHANNEL_RATE)
        } else {
            PlayEffect_Parms(kSfxCycle, FULL_CHANNEL_VOLUME/4, FULL_CHANNEL_VOLUME/4, UInt(Float(NORMAL_CHANNEL_RATE) * 2/3 + RandomFloat2() * Float(0x3000)))
        }
        if let cb = e.pointee.callback { cb() }
        if e.pointee.type == kMICycler1 { _ = layOutCycler1Column(gNav!.pointee.focusRow) }
        else { _ = layOutCycler2ColumnsValueText(gNav!.pointee.focusRow) }
        _ = MakeTwitch(delta < 0 ? Nav_GetArrow(gNav!, 0) : Nav_GetArrow(gNav!, 1), Int32(delta < 0 ? kTwitchPreset_DisplaceLTR : kTwitchPreset_DisplaceRTL))
    }
}

// MARK: - Slider

private func getSliderComponents(_ e: UnsafePointer<MenuItem>!, _ root: UnsafeMutablePointer<ObjNode>!) -> SliderComponents {
    var n: [UnsafeMutablePointer<ObjNode>?] = [root, nil, nil, nil, nil]
    for i in 1..<5 { n[i] = n[i-1]!.pointee.ChainNode; SwGameAssert(n[i] != nil) }
    var si = SliderComponents(); si.caption = n[0]; si.bar = n[1]; si.notch = n[2]; si.meter = n[3]; si.knob = n[4]
    let be = TextMesh_GetExtents(si.bar!)
    si.vmin = Float(MenuItem_GetSliderMin(e)); si.vmax = Float(MenuItem_GetSliderMax(e))
    si.xmin = be.left; si.xmax = be.right; return si
}
private func sliderKnobXToValue(_ i: SliderComponents, _ x: Float) -> Float { var v = RangeTranspose(x, i.xmin, i.xmax, i.vmin, i.vmax); v = SwGameClampF(v, i.vmin, i.vmax); return v }
private func sliderValueToKnobX(_ i: SliderComponents, _ v: Float) -> Float { RangeTranspose(v, i.vmin, i.vmax, i.xmin, i.xmax) }
private func layOutSlider(_ row: Int32) -> UnsafeMutablePointer<ObjNode> {
    let e = gNav!.pointee.menu!.advanced(by: Int(row))
    var chain: Int32 = 0
    let root = makeText("\(getMenuItemText(e)):", row, chain, kTextMeshAlignLeftFlag | kTextMeshSmallCapsFlag | kTextMeshUserFlag_AltFont); chain += 1
    root.pointee.Coord.x = k2ColumnLeftX; setMaxTextWidth(root, 230)
    var n = makeText("\u{00A2}", row, chain, kTextMeshAlignCenterFlag); chain += 1; n.pointee.Coord.x = k2ColumnRightX
    n = makeText("\u{00A3}", row, chain, kTextMeshAlignCenterFlag); chain += 1; n.pointee.Coord.x = k2ColumnRightX; n.pointee.ColorFilter.a = Float(0.5)
    n = makeText("\(MenuItem_GetSliderValuePtr(e)!.pointee) ", row, chain, kTextMeshAlignCenterFlag); chain += 1
    n.pointee.Scale.x /= 3; n.pointee.Scale.y /= 3; n.pointee.Coord.y -= 12
    n = makeText("#", row, chain, kTextMeshAlignCenterFlag)
    var p = getSliderComponents(e, root); let kx = sliderValueToKnobX(p, Float(MenuItem_GetSliderValuePtr(e)!.pointee))
    p.notch!.pointee.Coord.x = sliderValueToKnobX(p, Float(MenuItem_GetSliderEquilibrium(e)))
    p.knob!.pointee.Coord.x = kx; p.meter!.pointee.Coord.x = kx
    var cn: UnsafeMutablePointer<ObjNode>? = root
    while let c = cn { c.pointee.MoveCall = cMoveAction; UpdateObjectTransforms(c); cn = c.pointee.ChainNode }
    return root
}
private func setNewSliderValue(_ e: UnsafePointer<MenuItem>!, _ p: inout SliderComponents, _ mv: Float) -> Float {
    let kx = sliderValueToKnobX(p, mv)
    p.knob!.pointee.Coord.x = kx; p.meter!.pointee.Coord.x = kx
    "\(Int(mv)) ".withCString { TextMesh_Update($0, kTextMeshAlignCenterFlag, p.meter!) }
    UpdateObjectTransforms(p.knob!); UpdateObjectTransforms(p.meter!)
    let bv = UInt8(mv)
    if MenuItem_GetSliderValuePtr(e)!.pointee != bv {
        let mvi = SwGameClampI(Int32(mv), Int32(MenuItem_GetSliderMin(e)), Int32(MenuItem_GetSliderMax(e)))
        MenuItem_GetSliderValuePtr(e)!.pointee = UInt8(mvi)
        if let cb = e.pointee.callback, MenuItem_GetSliderContinuous(e) { cb() }
    }
    return kx
}
private func navigateSlider(_ e: UnsafePointer<MenuItem>!) {
    var prevTickX: Float = -1; var grabOffset: Float = -1; var heldCooldown: Float = -1
    var beingDragged = false; var didRamEdge = false
    let root = GetCurrentMenuItemObject(); var p = getSliderComponents(e, root)
    if gNav!.pointee.mouseState == .kMouseHovering && SwIsClickDown(Int(SDL_BUTTON_LEFT)) {
        switch gNav!.pointee.mouseFocusComponent {
        case 1: _ = setNewSliderValue(e, &p, sliderKnobXToValue(p, gCursorCoord.x)); beingDragged = true
        case 3, 4: beingDragged = true
        default: break
        }
        if beingDragged {
            prevTickX = p.knob!.pointee.Coord.x; grabOffset = gCursorCoord.x - p.knob!.pointee.Coord.x
            gNav!.pointee.mouseState = .kMouseGrabbing; playStartBindingEffect(); twitchSelection()
        }
    } else if beingDragged && SwIsClickHeld(Int(SDL_BUTTON_LEFT)) {
        let kx = setNewSliderValue(e, &p, sliderKnobXToValue(p, gCursorCoord.x - grabOffset))
        if abs(prevTickX - kx) >= 7 {
            let pitch = RangeTranspose(sliderKnobXToValue(p, gCursorCoord.x - grabOffset), p.vmin, p.vmax, Float(0.5), Float(0.9))
            PlayEffect_Parms(Int16(EFFECT_CHANGESELECT), FULL_CHANNEL_VOLUME/3, FULL_CHANNEL_VOLUME/3, UInt(Float(NORMAL_CHANNEL_RATE) * pitch))
            playNavigateEffect(); prevTickX = kx; twitchSelection()
        }
    } else if beingDragged && (SwIsClickUp(Int(SDL_BUTTON_LEFT)) || SwIsNeedUp(kNeed_UIPrev, ANY_PLAYER) || SwIsNeedUp(kNeed_UINext, ANY_PLAYER)) {
        beingDragged = false
        if gNav!.pointee.mouseState == .kMouseGrabbing { gNav!.pointee.mouseState = .kMouseWandering }
        playConfirmEffect(); if let cb = e.pointee.callback { cb() }
    } else if SwIsNeedDown(kNeed_UIConfirm, ANY_PLAYER) {
        _ = MakeTwitch(getCurrentInteractableMenuItemObject(), Int32(kTwitchPreset_MenuSelect))
        _ = MakeTwitch(Nav_GetArrow(gNav!, 0), Int32(kTwitchPreset_PadlockWiggle))
        _ = MakeTwitch(Nav_GetArrow(gNav!, 1), Int32(kTwitchPreset_PadlockWiggle)); playErrorEffect()
    } else if SwIsNeedActive(kNeed_UIPrev, ANY_PLAYER) || SwIsNeedActive(kNeed_UINext, ANY_PLAYER) {
        let dir: Int32 = SwIsNeedActive(kNeed_UIPrev, ANY_PLAYER) ? -1 : 1
        let need = dir < 0 ? kNeed_UIPrev : kNeed_UINext; let didJustPress = SwIsNeedDown(need, ANY_PLAYER)
        if didJustPress { didRamEdge = false }
        else {
            heldCooldown -= gFramesPerSecondFrac * Float(12) * (GetNeedAnalogValue(Int32(kNeed_UIPrev), Int32(ANY_PLAYER)) + GetNeedAnalogValue(Int32(kNeed_UINext), Int32(ANY_PLAYER)))
            if heldCooldown > 0 { return }
        }
        let vp = MenuItem_GetSliderValuePtr(e)!
        if (dir < 0 && vp.pointee == MenuItem_GetSliderMin(e)) || (dir > 0 && vp.pointee == MenuItem_GetSliderMax(e)) {
            if !didRamEdge {
                _ = MakeTwitch(getCurrentInteractableMenuItemObject(), Int32(kTwitchPreset_MenuSelect))
                _ = MakeTwitch(Nav_GetArrow(gNav!, 0), Int32(kTwitchPreset_PadlockWiggle))
                _ = MakeTwitch(Nav_GetArrow(gNav!, 1), Int32(kTwitchPreset_PadlockWiggle)); playErrorEffect(); didRamEdge = true
            }
        } else {
            gNav!.pointee.mouseState = .kMouseOff; let inc = Float(MenuItem_GetSliderIncrement(e))
            var v = Float(vp.pointee); v = inc * (v / inc).rounded(); v += Float(dir) * inc; v = v.rounded()
            v = SwGameClampF(v, Float(MenuItem_GetSliderMin(e)), Float(MenuItem_GetSliderMax(e)))
            _ = setNewSliderValue(e, &p, v)
            let pitch = RangeTranspose(v, p.vmin, p.vmax, Float(0.5), Float(0.9))
            PlayEffect_Parms(Int16(EFFECT_CHANGESELECT), FULL_CHANNEL_VOLUME/3, FULL_CHANNEL_VOLUME/3, UInt(Float(NORMAL_CHANNEL_RATE) * pitch))
            playNavigateEffect(); twitchSelection(); beingDragged = true; heldCooldown = didJustPress ? Float(2.5) : Float(1.0)
            _ = MakeTwitch(dir < 0 ? Nav_GetArrow(gNav!, 0) : Nav_GetArrow(gNav!, 1), Int32(dir < 0 ? kTwitchPreset_DisplaceLTR : kTwitchPreset_DisplaceRTL))
        }
    }
}

// MARK: - File slot layout

private func layOutFileSlot(_ row: Int32) -> UnsafeMutablePointer<ObjNode> {
    let e = gNav!.pointee.menu!.advanced(by: Int(row))
    let n1 = makeText("\(getMenuItemText(e)) \(1 + MenuItem_GetFileSlot(e))", row, 0, kTextMeshAlignLeftFlag | kTextMeshSmallCapsFlag | kTextMeshUserFlag_AltFont)
    n1.pointee.Coord.x = k2ColumnLeftX; n1.pointee.MoveCall = cMoveAction; setMaxTextWidth(n1, 100); UpdateObjectTransforms(n1)
    var sd = SaveGameType(); let valid = LoadSavedGame(MenuItem_GetFileSlot(e), &sd)
    if valid != 0 { gNav!.pointee.validSaveSlotMask |= (1 << UInt64(MenuItem_GetFileSlot(e))) }
    let buf2: String
    if valid == 0 { buf2 = "---------------- \(String(cString: Localize(STR_EMPTY_SLOT))) ----------------" }
    else {
        var dt = SDL_DateTime(); SDL_TimeToDateTime(Int64(sd.timestamp) * 1_000_000_000, &dt, true)
        let month = String(cString: Localize(LocStrID(rawValue: UInt32(dt.month - 1) + STR_JANUARY.rawValue))); let day = Int(dt.day); let year = Int(dt.year)
        let db: String
        switch gGamePrefs.language {
        case UInt8(LANGUAGE_ENGLISH.rawValue): db = "\(month) \(day), \(year)"
        case UInt8(LANGUAGE_GERMAN.rawValue): db = "\(day). \(month) \(year)"
        case UInt8(LANGUAGE_RUSSIAN.rawValue): db = "\(day) \(month) \(year) \u{0433}."
        default: db = "\(day) \(month) \(year)"
        }
        buf2 = "\(String(cString: Localize(STR_LEVEL))) \(sd.level + 1)   \(db)"
    }
    let n2 = makeText(buf2, row, 1, kTextMeshAlignLeftFlag | kTextMeshSmallCapsFlag)
    n2.pointee.Coord.x = k2ColumnLeftX + 120; n2.pointee.MoveCall = cMoveAction; UpdateObjectTransforms(n2)
    return n1
}

// MARK: - Binding layouts

private func layOutKeyBinding(_ row: Int32) -> UnsafeMutablePointer<ObjNode> {
    let e = gNav!.pointee.menu!.advanced(by: Int(row))
    let l = makeText("\(String(cString: Localize(LocStrID(rawValue: STR_KEYBINDING_DESCRIPTION_0.rawValue + UInt32(MenuItem_GetInputNeed(e)))))):", row, 0, kTextMeshAlignLeftFlag | kTextMeshSmallCapsFlag | kTextMeshUserFlag_AltFont)
    l.pointee.Coord.x = 100; l.pointee.ColorFilter = gNav!.pointee.style.labelColor; l.pointee.MoveCall = cMoveAction
    setMaxTextWidth(l, 110); UpdateObjectTransforms(l)
    for j in 0..<MAX_USER_BINDINGS_PER_NEED { let k = makeKbText(row, Int32(j)); k.pointee.Coord.x = 300 + Float(j) * 170; k.pointee.MoveCall = cMoveControlBinding; UpdateObjectTransforms(k) }
    return l
}
private func layOutPadBinding(_ row: Int32) -> UnsafeMutablePointer<ObjNode> {
    let e = gNav!.pointee.menu!.advanced(by: Int(row))
    let l = makeText("\(String(cString: Localize(LocStrID(rawValue: STR_KEYBINDING_DESCRIPTION_0.rawValue + UInt32(MenuItem_GetInputNeed(e)))))):", row, 0, kTextMeshAlignLeftFlag | kTextMeshSmallCapsFlag | kTextMeshUserFlag_AltFont)
    l.pointee.Coord.x = 100; l.pointee.ColorFilter = gNav!.pointee.style.labelColor; l.pointee.MoveCall = cMoveAction
    setMaxTextWidth(l, 110); UpdateObjectTransforms(l)
    for j in 0..<MAX_USER_BINDINGS_PER_NEED { let k = makePbText(row, Int32(j)); k.pointee.Coord.x = 300 + Float(j) * 170; k.pointee.MoveCall = cMoveControlBinding; UpdateObjectTransforms(k) }
    return l
}
private func layOutMouseBinding(_ row: Int32) -> UnsafeMutablePointer<ObjNode> {
    let e = gNav!.pointee.menu!.advanced(by: Int(row))
    let l = makeText("\(String(cString: Localize(LocStrID(rawValue: STR_KEYBINDING_DESCRIPTION_0.rawValue + UInt32(MenuItem_GetInputNeed(e)))))):", row, 0, kTextMeshAlignLeftFlag | kTextMeshSmallCapsFlag | kTextMeshUserFlag_AltFont)
    l.pointee.Coord.x = k2ColumnLeftX; l.pointee.ColorFilter = gNav!.pointee.style.labelColor; l.pointee.MoveCall = cMoveAction
    setMaxTextWidth(l, 150); UpdateObjectTransforms(l)
    let k = makeMbText(row); k.pointee.Coord.x = k2ColumnRightX; k.pointee.MoveCall = cMoveControlBinding; setMinClickableWidth(k, 70); UpdateObjectTransforms(k)
    return l
}

// MARK: - Binding text helpers

private func makeKbText(_ row: Int32, _ keyNo: Int32) -> UnsafeMutablePointer<ObjNode> {
    let name: String = gNav!.pointee.menuState == .kMenuStateAwaitingKeyPress ? String(cString: Localize(STR_PRESS)) : getKeyBindingName(row, keyNo)
    let n = makeText(name, row, 1 + keyNo, kTextMeshSmallCapsFlag | kTextMeshAlignCenterFlag)
    setMinClickableWidth(n, kMinClickableWidth); setMaxTextWidth(n, 110); return n
}
private func makePbText(_ row: Int32, _ btnNo: Int32) -> UnsafeMutablePointer<ObjNode> {
    let name: String = gNav!.pointee.menuState == .kMenuStateAwaitingPadPress ? String(cString: Localize(STR_PRESS)) : getPadBindingName(row, btnNo)
    let n = makeText(name, row, 1 + btnNo, kTextMeshSmallCapsFlag | kTextMeshAlignCenterFlag)
    setMinClickableWidth(n, kMinClickableWidth); setMaxTextWidth(n, 110); return n
}
private func makeMbText(_ row: Int32) -> UnsafeMutablePointer<ObjNode> {
    let name: String = gNav!.pointee.menuState == .kMenuStateAwaitingMouseClick ? String(cString: Localize(STR_CLICK)) : getMouseBindingName(row)
    let n = makeText(name, row, 1, kTextMeshAllCapsFlag | kTextMeshAlignCenterFlag)
    setMinClickableWidth(n, kMinClickableWidth); setMaxTextWidth(n, 110); return n
}

// MARK: - Binding name helpers

private func getKeyBindingName(_ row: Int32, _ col: Int32) -> String {
    let sc = InputBinding_GetKey(getBindingAtRow(row), col)
    switch Int32(sc) {
    case 0: return String(cString: Localize(STR_UNBOUND_PLACEHOLDER))
    case Int32(SDL_SCANCODE_APOSTROPHE.rawValue): return "Apostrophe"; case Int32(SDL_SCANCODE_BACKSLASH.rawValue): return "Backslash"
    case Int32(SDL_SCANCODE_GRAVE.rawValue): return "Backtick"; case Int32(SDL_SCANCODE_SEMICOLON.rawValue): return "Semicolon"
    case Int32(SDL_SCANCODE_SLASH.rawValue): return "Slash"; case Int32(SDL_SCANCODE_LEFTBRACKET.rawValue): return "Left Bracket"
    case Int32(SDL_SCANCODE_RIGHTBRACKET.rawValue): return "Right Bracket"; case Int32(SDL_SCANCODE_EQUALS.rawValue): return "Equals"
    case Int32(SDL_SCANCODE_MINUS.rawValue): return "Dash"; case Int32(SDL_SCANCODE_PERIOD.rawValue): return "Period"
    case Int32(SDL_SCANCODE_KP_PLUS.rawValue): return "Keypad Plus"; case Int32(SDL_SCANCODE_KP_MINUS.rawValue): return "Keypad Minus"
    case Int32(SDL_SCANCODE_KP_DIVIDE.rawValue): return "Keypad Slash"; case Int32(SDL_SCANCODE_KP_MULTIPLY.rawValue): return "Keypad Star"
    case Int32(SDL_SCANCODE_KP_PERIOD.rawValue): return "Keypad Period"; case Int32(SDL_SCANCODE_NONUSBACKSLASH.rawValue): return "ISO Extra Key"
    default: return String(cString: SDL_GetScancodeName(SDL_Scancode(rawValue: UInt32(sc))))
    }
}
private func getPadBindingName(_ row: Int32, _ col: Int32) -> String {
    let binding = getBindingAtRow(row)
    let pbType = InputBinding_GetPadType(binding, col)
    let pbID = InputBinding_GetPadID(binding, col)
    switch Int32(pbType) {
    case Int32(kInputTypeUnbound): return String(cString: Localize(STR_UNBOUND_PLACEHOLDER))
    case Int32(kInputTypeButton):
        switch Int32(pbID) {
        case Int32(SDL_GAMEPAD_BUTTON_INVALID.rawValue): return String(cString: Localize(STR_UNBOUND_PLACEHOLDER))
        case Int32(SDL_GAMEPAD_BUTTON_SOUTH.rawValue): return String(cString: Localize(STR_GAMEPAD_BUTTON_A))
        case Int32(SDL_GAMEPAD_BUTTON_EAST.rawValue): return String(cString: Localize(STR_GAMEPAD_BUTTON_B))
        case Int32(SDL_GAMEPAD_BUTTON_WEST.rawValue): return String(cString: Localize(STR_GAMEPAD_BUTTON_X))
        case Int32(SDL_GAMEPAD_BUTTON_NORTH.rawValue): return String(cString: Localize(STR_GAMEPAD_BUTTON_Y))
        case Int32(SDL_GAMEPAD_BUTTON_LEFT_SHOULDER.rawValue): return String(cString: Localize(STR_GAMEPAD_BUTTON_LEFT_SHOULDER))
        case Int32(SDL_GAMEPAD_BUTTON_RIGHT_SHOULDER.rawValue): return String(cString: Localize(STR_GAMEPAD_BUTTON_RIGHT_SHOULDER))
        case Int32(SDL_GAMEPAD_BUTTON_LEFT_STICK.rawValue): return String(cString: Localize(STR_GAMEPAD_BUTTON_LEFT_STICK))
        case Int32(SDL_GAMEPAD_BUTTON_RIGHT_STICK.rawValue): return String(cString: Localize(STR_GAMEPAD_BUTTON_RIGHT_STICK))
        case Int32(SDL_GAMEPAD_BUTTON_DPAD_UP.rawValue): return String(cString: Localize(STR_GAMEPAD_BUTTON_DPAD_UP))
        case Int32(SDL_GAMEPAD_BUTTON_DPAD_DOWN.rawValue): return String(cString: Localize(STR_GAMEPAD_BUTTON_DPAD_DOWN))
        case Int32(SDL_GAMEPAD_BUTTON_DPAD_LEFT.rawValue): return String(cString: Localize(STR_GAMEPAD_BUTTON_DPAD_LEFT))
        case Int32(SDL_GAMEPAD_BUTTON_DPAD_RIGHT.rawValue): return String(cString: Localize(STR_GAMEPAD_BUTTON_DPAD_RIGHT))
        default: return String(cString: SDL_GetGamepadStringForButton(SDL_GamepadButton(rawValue: Int32(pbID))))
        }
    case Int32(kInputTypeAxisPlus):
        switch Int32(pbID) {
        case Int32(SDL_GAMEPAD_AXIS_INVALID.rawValue): return String(cString: Localize(STR_UNBOUND_PLACEHOLDER))
        case Int32(SDL_GAMEPAD_AXIS_LEFTX.rawValue): return String(cString: Localize(STR_GAMEPAD_AXIS_LEFT_STICK_RIGHT))
        case Int32(SDL_GAMEPAD_AXIS_LEFTY.rawValue): return String(cString: Localize(STR_GAMEPAD_AXIS_LEFT_STICK_DOWN))
        case Int32(SDL_GAMEPAD_AXIS_RIGHTX.rawValue): return String(cString: Localize(STR_GAMEPAD_AXIS_RIGHT_STICK_RIGHT))
        case Int32(SDL_GAMEPAD_AXIS_RIGHTY.rawValue): return String(cString: Localize(STR_GAMEPAD_AXIS_RIGHT_STICK_DOWN))
        case Int32(SDL_GAMEPAD_AXIS_LEFT_TRIGGER.rawValue): return String(cString: Localize(STR_GAMEPAD_AXIS_LEFT_TRIGGER))
        case Int32(SDL_GAMEPAD_AXIS_RIGHT_TRIGGER.rawValue): return String(cString: Localize(STR_GAMEPAD_AXIS_RIGHT_TRIGGER))
        default: return String(cString: SDL_GetGamepadStringForAxis(SDL_GamepadAxis(rawValue: Int32(pbID))))
        }
    case Int32(kInputTypeAxisMinus):
        switch Int32(pbID) {
        case Int32(SDL_GAMEPAD_AXIS_INVALID.rawValue): return String(cString: Localize(STR_UNBOUND_PLACEHOLDER))
        case Int32(SDL_GAMEPAD_AXIS_LEFTX.rawValue): return String(cString: Localize(STR_GAMEPAD_AXIS_LEFT_STICK_LEFT))
        case Int32(SDL_GAMEPAD_AXIS_LEFTY.rawValue): return String(cString: Localize(STR_GAMEPAD_AXIS_LEFT_STICK_UP))
        case Int32(SDL_GAMEPAD_AXIS_RIGHTX.rawValue): return String(cString: Localize(STR_GAMEPAD_AXIS_RIGHT_STICK_LEFT))
        case Int32(SDL_GAMEPAD_AXIS_RIGHTY.rawValue): return String(cString: Localize(STR_GAMEPAD_AXIS_RIGHT_STICK_UP))
        case Int32(SDL_GAMEPAD_AXIS_LEFT_TRIGGER.rawValue): return String(cString: Localize(STR_GAMEPAD_AXIS_LEFT_TRIGGER))
        case Int32(SDL_GAMEPAD_AXIS_RIGHT_TRIGGER.rawValue): return String(cString: Localize(STR_GAMEPAD_AXIS_RIGHT_TRIGGER))
        default: return String(cString: SDL_GetGamepadStringForAxis(SDL_GamepadAxis(rawValue: Int32(pbID))))
        }
    default: return "???"
    }
}
private func getMouseBindingName(_ row: Int32) -> String {
    let b = getBindingAtRow(row)
    switch Int32(b.pointee.mouseButton) {
    case 0: return String(cString: Localize(STR_UNBOUND_PLACEHOLDER))
    case SDL_BUTTON_LEFT: return String(cString: Localize(STR_MOUSE_BUTTON_LEFT))
    case SDL_BUTTON_MIDDLE: return String(cString: Localize(STR_MOUSE_BUTTON_MIDDLE))
    case SDL_BUTTON_RIGHT: return String(cString: Localize(STR_MOUSE_BUTTON_RIGHT))
    case SDL_BUTTON_WHEELUP: return String(cString: Localize(STR_MOUSE_WHEEL_UP))
    case SDL_BUTTON_WHEELDOWN: return String(cString: Localize(STR_MOUSE_WHEEL_DOWN))
    case SDL_BUTTON_WHEELLEFT: return String(cString: Localize(STR_MOUSE_WHEEL_LEFT))
    case SDL_BUTTON_WHEELRIGHT: return String(cString: Localize(STR_MOUSE_WHEEL_RIGHT))
    default: return "\(String(cString: Localize(STR_BUTTON))) \(b.pointee.mouseButton)"
    }
}

// MARK: - Key/Pad/Mouse binding navigation

private func navigateKeyBinding(_ e: UnsafePointer<MenuItem>!) {
    var keyNo = Int32(PositiveModulo(gNav!.pointee.focusComponent - 1, UInt32(MAX_USER_BINDINGS_PER_NEED)))
    gNav!.pointee.focusComponent = keyNo + 1; let row = gNav!.pointee.focusRow
    if gNav!.pointee.mouseState == .kMouseHovering && (gNav!.pointee.mouseFocusComponent == 1 || gNav!.pointee.mouseFocusComponent == 2) && keyNo != gNav!.pointee.mouseFocusComponent - 1 {
        keyNo = gNav!.pointee.mouseFocusComponent - 1; twitchOutSelection(); gNav!.pointee.idleTime = 0
        gNav!.pointee.focusComponent = keyNo + 1; playNavigateEffect(); twitchSelection(); return
    }
    if SwIsNeedDown(kNeed_UIPrev, ANY_PLAYER) { twitchOutSelection(); keyNo = Int32(PositiveModulo(keyNo - 1, UInt32(MAX_USER_BINDINGS_PER_NEED))); gNav!.pointee.idleTime = 0; gNav!.pointee.focusComponent = keyNo + 1; playNavigateEffect(); gNav!.pointee.mouseState = .kMouseOff; twitchSelection(); return }
    if SwIsNeedDown(kNeed_UINext, ANY_PLAYER) { twitchOutSelection(); keyNo = Int32(PositiveModulo(keyNo + 1, UInt32(MAX_USER_BINDINGS_PER_NEED))); gNav!.pointee.idleTime = 0; gNav!.pointee.focusComponent = keyNo + 1; playNavigateEffect(); gNav!.pointee.mouseState = .kMouseOff; twitchSelection(); return }
    if SwIsNeedDown(kNeed_UIDelete, ANY_PLAYER) || SwIsKeyDown(Int(CLEAR_BINDING_SCANCODE)) || (gNav!.pointee.mouseState == .kMouseHovering && SwIsClickDown(Int(SDL_BUTTON_MIDDLE))) {
        twitchOutSelection(); gNav!.pointee.idleTime = 0; InputBinding_SetKey(getBindingAtRow(row), keyNo, 0); playDeleteEffect(); _ = makeKbText(row, keyNo); twitchSelection(); return
    }
    if SwIsKeyDown(Int(SDL_SCANCODE_RETURN.rawValue)) || SwIsKeyDown(Int(SDL_SCANCODE_KP_ENTER.rawValue)) || (gNav!.pointee.mouseState == .kMouseHovering && SwIsClickDown(Int(SDL_BUTTON_LEFT))) {
        playStartBindingEffect(); InvalidateAllInputs(); gNav!.pointee.idleTime = 0; gNav!.pointee.menuState = .kMenuStateAwaitingKeyPress; _ = makeKbText(row, keyNo); twitchSelection(); replaceMenuText(STR_CONFIGURE_KEYBOARD_HELP, STR_CONFIGURE_KEYBOARD_HELP_CANCEL); return
    }
}
private func navigatePadBinding(_ e: UnsafePointer<MenuItem>!) {
    var btnNo = Int32(PositiveModulo(gNav!.pointee.focusComponent - 1, UInt32(MAX_USER_BINDINGS_PER_NEED)))
    gNav!.pointee.focusComponent = btnNo + 1; let row = gNav!.pointee.focusRow
    if gNav!.pointee.mouseState == .kMouseHovering && (gNav!.pointee.mouseFocusComponent == 1 || gNav!.pointee.mouseFocusComponent == 2) && btnNo != gNav!.pointee.mouseFocusComponent - 1 {
        btnNo = gNav!.pointee.mouseFocusComponent - 1; twitchOutSelection(); gNav!.pointee.idleTime = 0; gNav!.pointee.focusComponent = btnNo + 1; playNavigateEffect(); twitchSelection(); return
    }
    if SwIsNeedDown(kNeed_UIPrev, ANY_PLAYER) { twitchOutSelection(); btnNo = Int32(PositiveModulo(btnNo - 1, UInt32(MAX_USER_BINDINGS_PER_NEED))); gNav!.pointee.focusComponent = btnNo + 1; gNav!.pointee.idleTime = 0; gNav!.pointee.mouseState = .kMouseOff; playNavigateEffect(); twitchSelection(); return }
    if SwIsNeedDown(kNeed_UINext, ANY_PLAYER) { twitchOutSelection(); btnNo = Int32(PositiveModulo(btnNo + 1, UInt32(MAX_USER_BINDINGS_PER_NEED))); gNav!.pointee.focusComponent = btnNo + 1; gNav!.pointee.idleTime = 0; gNav!.pointee.mouseState = .kMouseOff; playNavigateEffect(); twitchSelection(); return }
    if SwIsNeedDown(kNeed_UIDelete, ANY_PLAYER) || SwIsKeyDown(Int(CLEAR_BINDING_SCANCODE)) || (gNav!.pointee.mouseState == .kMouseHovering && SwIsClickDown(Int(SDL_BUTTON_MIDDLE))) {
        twitchOutSelection(); gNav!.pointee.idleTime = 0; InputBinding_SetPad(getBindingAtRow(row), btnNo, Int8(kInputTypeUnbound), 0); playDeleteEffect(); _ = makePbText(row, btnNo); twitchSelection(); return
    }
    if SwIsNeedDown(kNeed_UIConfirm, ANY_PLAYER) || SwIsKeyDown(Int(SDL_SCANCODE_KP_ENTER.rawValue)) || (gNav!.pointee.mouseState == .kMouseHovering && SwIsClickDown(Int(SDL_BUTTON_LEFT))) {
        playStartBindingEffect(); gNav!.pointee.idleTime = 0; gNav!.pointee.menuState = .kMenuStateAwaitingPadPress; _ = makePbText(row, btnNo); twitchSelection(); replaceMenuText(STR_CONFIGURE_GAMEPAD_HELP, STR_CONFIGURE_GAMEPAD_HELP_CANCEL); return
    }
}
private func navigateMouseBinding(_ e: UnsafePointer<MenuItem>!) {
    let row = gNav!.pointee.focusRow; gNav!.pointee.focusComponent = 1
    if SwIsNeedDown(kNeed_UIDelete, ANY_PLAYER) || SwIsKeyDown(Int(CLEAR_BINDING_SCANCODE)) || (gNav!.pointee.mouseState == .kMouseHovering && SwIsClickDown(Int(SDL_BUTTON_MIDDLE))) {
        gNav!.pointee.idleTime = 0; getBindingAtRow(row).pointee.mouseButton = 0; playDeleteEffect(); _ = makeMbText(row); twitchSelection(); return
    }
    if SwIsNeedDown(kNeed_UIConfirm, ANY_PLAYER) || SwIsKeyDown(Int(SDL_SCANCODE_KP_ENTER.rawValue)) || (gNav!.pointee.mouseState == .kMouseHovering && SwIsClickDown(Int(SDL_BUTTON_LEFT))) {
        playStartBindingEffect(); gNav!.pointee.idleTime = 0; gNav!.pointee.menuState = .kMenuStateAwaitingMouseClick; _ = makeMbText(row); twitchSelection(); InvalidateAllInputs(); return
    }
}

// MARK: - Unbind helpers

private func unbindScancodeFromAllRemappableInputNeeds(_ sc: Int16) {
    for row in 0..<gNav!.pointee.numRows {
        if gNav!.pointee.menu![Int(row)].type != kMIKeyBinding { continue }
        let b = getBindingAtRow(row)
        for j in 0..<MAX_USER_BINDINGS_PER_NEED { if InputBinding_GetKey(b, j) == sc { InputBinding_SetKey(b, j, 0); _ = makeText(String(cString: Localize(STR_UNBOUND_PLACEHOLDER)), row, j+1, kTextMeshAllCapsFlag | kTextMeshAlignCenterFlag) } }
    }
}
private func unbindPadButtonFromAllRemappableInputNeeds(_ type: Int8, _ id: Int8) {
    for row in 0..<gNav!.pointee.numRows {
        if gNav!.pointee.menu![Int(row)].type != kMIPadBinding { continue }
        let b = getBindingAtRow(row)
        for j in 0..<MAX_USER_BINDINGS_PER_NEED { if InputBinding_GetPadType(b, j) == type && InputBinding_GetPadID(b, j) == id { InputBinding_SetPad(b, j, Int8(kInputTypeUnbound), 0); _ = makeText(String(cString: Localize(STR_UNBOUND_PLACEHOLDER)), row, j+1, kTextMeshAllCapsFlag | kTextMeshAlignCenterFlag) } }
    }
}
private func unbindMouseButtonFromAllRemappableInputNeeds(_ id: Int8) {
    for row in 0..<gNav!.pointee.numRows {
        if gNav!.pointee.menu![Int(row)].type != kMIMouseBinding { continue }
        let b = getBindingAtRow(row)
        if b.pointee.mouseButton == id { b.pointee.mouseButton = 0; _ = makeText(String(cString: Localize(STR_UNBOUND_PLACEHOLDER)), row, 1, kTextMeshAllCapsFlag | kTextMeshAlignCenterFlag) }
    }
}

// MARK: - Await input

private func awaitKeyPress() {
    let row = gNav!.pointee.focusRow; let keyNo = gNav!.pointee.focusComponent - 1
    var doWiggle = false
    if SwIsKeyDown(Int(SDL_SCANCODE_ESCAPE.rawValue)) || SwIsClickDown(Int(SDL_BUTTON_LEFT)) || SwIsClickDown(Int(SDL_BUTTON_RIGHT)) { doWiggle = true }
    else {
        for sc: Int16 in 0..<Int16(SDL_SCANCODE_COUNT.rawValue) {
            if SwIsKeyDown(Int(sc)) {
                unbindScancodeFromAllRemappableInputNeeds(sc); InputBinding_SetKey(getBindingAtRow(row), keyNo, sc); playEndBindingEffect()
                gNav!.pointee.menuState = .kMenuStateReady; gNav!.pointee.idleTime = 0; _ = makeKbText(row, keyNo); replaceMenuText(STR_CONFIGURE_KEYBOARD_HELP, STR_CONFIGURE_KEYBOARD_HELP)
                return
            }
        }
        return
    }
    gNav!.pointee.menuState = .kMenuStateReady; gNav!.pointee.idleTime = 0; _ = makeKbText(row, keyNo); replaceMenuText(STR_CONFIGURE_KEYBOARD_HELP, STR_CONFIGURE_KEYBOARD_HELP); if doWiggle { twitchSelectionNopeWiggle() }
}
private func awaitGamepadPress(_ controller: OpaquePointer) -> Bool {
    let row = gNav!.pointee.focusRow; let btnNo = gNav!.pointee.focusComponent - 1
    var doWiggle = false
    if SwIsKeyDown(Int(SDL_SCANCODE_ESCAPE.rawValue)) || SDL_GetGamepadButton(controller, SDL_GAMEPAD_BUTTON_START) || SwIsClickDown(Int(SDL_BUTTON_LEFT)) || SwIsClickDown(Int(SDL_BUTTON_RIGHT)) { doWiggle = true }
    else {
        let b = getBindingAtRow(gNav!.pointee.focusRow)
        for button: Int8 in 0..<Int8(SDL_GAMEPAD_BUTTON_COUNT.rawValue) {
            if SDL_GetGamepadButton(controller, SDL_GamepadButton(rawValue: Int32(button))) {
                playEndBindingEffect(); unbindPadButtonFromAllRemappableInputNeeds(Int8(kInputTypeButton), button); InputBinding_SetPad(b, btnNo, Int8(kInputTypeButton), button)
                gNav!.pointee.menuState = .kMenuStateReady; gNav!.pointee.idleTime = 0; _ = makePbText(row, btnNo); replaceMenuText(STR_CONFIGURE_GAMEPAD_HELP, STR_CONFIGURE_GAMEPAD_HELP); return true
            }
        }
        for axis: Int8 in 0..<Int8(SDL_GAMEPAD_AXIS_COUNT.rawValue) {
            let av = SDL_GetGamepadAxis(controller, SDL_GamepadAxis(rawValue: Int32(axis)))
            if abs(Int32(av)) > kJoystickDeadZone_BindingThreshold {
                playEndBindingEffect(); let at: Int8 = av < 0 ? Int8(kInputTypeAxisMinus) : Int8(kInputTypeAxisPlus); unbindPadButtonFromAllRemappableInputNeeds(at, axis); InputBinding_SetPad(b, btnNo, at, axis)
                gNav!.pointee.menuState = .kMenuStateReady; gNav!.pointee.idleTime = 0; _ = makePbText(row, btnNo); replaceMenuText(STR_CONFIGURE_GAMEPAD_HELP, STR_CONFIGURE_GAMEPAD_HELP); return true
            }
        }
        return false
    }
    gNav!.pointee.menuState = .kMenuStateReady; gNav!.pointee.idleTime = 0; _ = makePbText(row, btnNo); replaceMenuText(STR_CONFIGURE_GAMEPAD_HELP, STR_CONFIGURE_GAMEPAD_HELP); if doWiggle { twitchSelectionNopeWiggle() }; return true
}
private func awaitMetaGamepadPress() {
    let row = gNav!.pointee.focusRow; let btnNo = gNav!.pointee.focusComponent - 1
    if SwIsNeedActive(kNeed_UIConfirm, ANY_PLAYER) && !SwIsNeedDown(kNeed_UIConfirm, ANY_PLAYER) { return }
    var anyFound = false
    for i in 0..<Int32(MAX_PLAYERS) { if let gp = GetGamepad(i) { anyFound = true; if awaitGamepadPress(gp) { return } } }
    if !anyFound { gNav!.pointee.menuState = .kMenuStateReady; gNav!.pointee.idleTime = 0; _ = makePbText(row, btnNo); replaceMenuText(STR_CONFIGURE_GAMEPAD_HELP, STR_NO_GAMEPAD_DETECTED); twitchSelectionNopeWiggle() }
}
private func awaitMouseClick() {
    var doWiggle = false
    if SwIsKeyDown(Int(SDL_SCANCODE_ESCAPE.rawValue)) || SwIsNeedDown(kNeed_UIConfirm, ANY_PLAYER) || SwIsNeedDown(kNeed_UIBack, ANY_PLAYER) { doWiggle = true }
    else {
        let b = getBindingAtRow(gNav!.pointee.focusRow)
        for mb: Int8 in 0..<Int8(NUM_SUPPORTED_MOUSE_BUTTONS) {
            if SwIsClickDown(Int(mb)) { unbindMouseButtonFromAllRemappableInputNeeds(mb); b.pointee.mouseButton = mb; playEndBindingEffect(); gNav!.pointee.menuState = .kMenuStateReady; gNav!.pointee.idleTime = 0; _ = makeMbText(gNav!.pointee.focusRow); return }
        }
        return
    }
    gNav!.pointee.menuState = .kMenuStateReady; gNav!.pointee.idleTime = 0; _ = makeMbText(gNav!.pointee.focusRow); if doWiggle { twitchSelectionNopeWiggle() }
}

// MARK: - Page layout

private func deleteAllText() {
    for row in 0..<Int(MAX_MENU_ROWS) { if let o = mObj(row) { DeleteObject(o); setMObj(row, nil) } }
}
private func layOutMenuItem(_ type: MenuItemType, _ row: Int32) -> UnsafeMutablePointer<ObjNode>? {
    switch type {
    case kMILabel: return layOutLabel(row); case kMIPick: return layOutPick(row)
    case kMICycler1: return layOutCycler1Column(row); case kMICycler2: return layOutCycler2Columns(row)
    case kMISlider: return layOutSlider(row)
    case kMIKeyBinding: return layOutKeyBinding(row); case kMIPadBinding: return layOutPadBinding(row)
    case kMIMouseBinding: return layOutMouseBinding(row); case kMIFileSlot: return layOutFileSlot(row)
    default: return nil
    }
}
private func makeText(_ text: String, _ row: Int32, _ chainItem: Int32, _ textMeshFlags: Int32) -> UnsafeMutablePointer<ObjNode> {
    let chainHead = mObj(Int(row))
    SwGameAssert(GetNodeChainLength(chainHead) >= chainItem)
    var node = GetNthChainedNode(chainHead, chainItem, nil)
    var fontAtlas = gNav!.pointee.style.fontAtlas
    if (textMeshFlags & kTextMeshUserFlag_AltFont) != 0 { fontAtlas = gNav!.pointee.style.fontAtlas2 }
    if node != nil {
        text.withCString { TextMesh_Update($0, textMeshFlags, node!) }
        setMaxTextWidth(node, getMenuNodeData(node).pointee.maxWidth)
    } else {
        var def = NewObjectDefinitionType()
        def.coord = (OGLPoint3D(x: kDefaultX, y: mRowY(Int(row)), z: 0))
        def.scale = getMenuItemHeight(row) * gNav!.pointee.style.standardScale
        def.group = UInt8(fontAtlas); def.slot = gNav!.pointee.style.textSlot + Int16(chainItem); def.flags = UInt32(STATUS_BIT_MOVEINPAUSE)
        node = text.withCString { TextMesh_New($0, textMeshFlags, &def) }
        SendNodeToOverlayPane(node!)
        if let chainHead { AppendNodeToChain(chainHead, node!) } else { setMObj(Int(row), node) }
    }
    let data = getMenuNodeData(node)
    data.pointee.row = UInt8(row); data.pointee.component = UInt8(chainItem)
    if gNav!.pointee.sweepDelay >= 0 {
        if let fe = MakeTwitch(node, Int32(kTwitchPreset_MenuFadeIn)) {
            fe.pointee.delay = gNav!.pointee.sweepDelay * fe.pointee.duration
            if let de = MakeTwitch(node, Int32(kTwitchPreset_MenuSweep | kTwitchFlags_Chain)) {
                de.pointee.delay = fe.pointee.delay; de.pointee.amplitude *= (gNav!.pointee.sweepRTL ? 1 : -1); de.pointee.amplitude *= Float(1.0 + Double(de.pointee.delay))
            }
        }
    }
    return node!
}
private func replaceMenuText(_ origID: LocStrID, _ newText: LocStrID) {
    for i in 0..<Int(MAX_MENU_ROWS) {
        let mi = gNav!.pointee.menu!.advanced(by: i)
        if mi.pointee.type == kMISENTINEL { break }
        if mi.pointee.text == origID { _ = makeText(String(cString: Localize(newText)), Int32(i), 0, kTextMeshSmallCapsFlag) }
    }
}
private func layOutMenu(_ menuID: Int32) {
    let sentinel = lookUpMenu(menuID)
    SwGameAssert(sentinel != nil); SwGameAssert(sentinel!.pointee.id == menuID); SwGameAssert(sentinel!.pointee.type == kMISENTINEL)
    let menu = sentinel!.advanced(by: 1)
    setHistMID(gNav!.pointee.historyPos, menuID)
    gNav!.pointee.menu = menu; gNav!.pointee.menuID = menuID; gNav!.pointee.menuPick = -1
    gNav!.pointee.numRows = 0; gNav!.pointee.idleTime = 0; gNav!.pointee.validSaveSlotMask = 0
    deleteAllText()
    var row = 0; while menu[row].type != kMISENTINEL { gNav!.pointee.numRows += 1; SwGameAssert(gNav!.pointee.numRows <= MAX_MENU_ROWS); row += 1 }
    var totalHeight: Float = 0; var firstHeight: Float = 0; row = 0
    while menu[row].type != kMISENTINEL { let h = getMenuItemHeight(Int32(row)); if firstHeight == 0 { firstHeight = h }; totalHeight += h * gNav!.pointee.style.rowHeight; row += 1 }
    var y = -totalHeight * Float(0.5) + gNav!.pointee.style.yOffset; y += firstHeight * gNav!.pointee.style.rowHeight / Float(2.0)
    if let dp = gNav!.pointee.darkenPane { rescaleDarkenPane(dp, totalHeight) }
    row = 0
    while menu[row].type != kMISENTINEL {
        setMRowY(row, y); let entry = menu.advanced(by: row); let et = entry.pointee.type
        if (getLayoutFlags(entry) & Int32(kMILayoutFlagHidden)) != 0 { row += 1; continue }
        if let node = layOutMenuItem(et, Int32(row)) {
            if (getLayoutFlags(entry) & Int32(kMILayoutFlagDisabled)) != 0 { var cn: UnsafeMutablePointer<ObjNode>? = node; while let c = cn { getMenuNodeData(c).pointee.muted = 1; cn = c.pointee.ChainNode } }
        }
        y += getMenuItemHeight(Int32(row)) * gNav!.pointee.style.rowHeight
        if et != kMISpacer { gNav!.pointee.sweepDelay += Float(0.2) }
        row += 1
    }
    gNav!.pointee.sweepDelay = 0.0
    gNav!.pointee.focusRow = histRow(gNav!.pointee.historyPos)
    if gNav!.pointee.focusRow <= 0 || !isMenuItemSelectable(gNav!.pointee.menu!.advanced(by: Int(gNav!.pointee.focusRow))) { gNav!.pointee.focusRow = -1; navigateMenuVertically(1) }
    twitchSelection()
    if let cb = sentinel!.pointee.callback { cb() }
}

// MARK: - Menu registry

private func lookUpMenu(_ menuID: Int32) -> UnsafePointer<MenuItem>? {
    for i in 0..<gNumMenusRegistered { let e = GetRegistryEntry(i); if e!.pointee.id == menuID { return e } }
    return nil
}

// MARK: - Menu driver

private let cMoveMenuDriver: @convention(c) (UnsafeMutablePointer<ObjNode>?) -> Void = { theNode in
    guard let theNode = theNode else { return }
    if gNav!.pointee.menuState == .kMenuStateOff { return }
    gNav!.pointee.idleTime += gFramesPerSecondFrac
    if SwIsNeedDown(kNeed_UIStart, ANY_PLAYER) && MenuStyle_GetStartButtonExits(&gNav!.pointee.style) && MenuStyle_GetCanBackOutOfRootMenu(&gNav!.pointee.style)
        && gNav!.pointee.menuState != .kMenuStateAwaitingPadPress && gNav!.pointee.menuState != .kMenuStateAwaitingKeyPress && gNav!.pointee.menuState != .kMenuStateAwaitingMouseClick {
        gNav!.pointee.menuState = .kMenuStateFadeOut
    }
    switch gNav!.pointee.menuState {
    case .kMenuStateFadeIn:
        gNav!.pointee.menuFadeAlpha += gFramesPerSecondFrac * gNav!.pointee.style.fadeInSpeed
        if gNav!.pointee.menuFadeAlpha >= 1.0 { gNav!.pointee.menuFadeAlpha = 1.0; gNav!.pointee.menuState = .kMenuStateReady }
    case .kMenuStateFadeOut:
        if MenuStyle_GetAsyncFadeOut(&gNav!.pointee.style) { gNav!.pointee.menuState = .kMenuStateOff }
        else { gNav!.pointee.menuFadeAlpha -= gFramesPerSecondFrac * gNav!.pointee.style.fadeOutSpeed; if gNav!.pointee.menuFadeAlpha <= 0 { gNav!.pointee.menuFadeAlpha = 0; gNav!.pointee.menuState = .kMenuStateOff } }
    case .kMenuStateReady:
        if MenuStyle_GetIsInteractive(&gNav!.pointee.style) { navigateMenu() }
        else if SwIsNeedDown(kNeed_UIBack, ANY_PLAYER) || SwIsNeedDown(kNeed_UIPause, ANY_PLAYER) { goBackInHistory() }
    case .kMenuStateAwaitingKeyPress: awaitKeyPress()
    case .kMenuStateAwaitingPadPress: awaitMetaGamepadPress()
    case .kMenuStateAwaitingMouseClick: awaitMouseClick()
    default: break
    }
    updateArrows()
    if gNav!.pointee.menuState == .kMenuStateOff { cleanUpMenuDriver(theNode) }
}

private func cleanUpMenuDriver(_ theNode: UnsafeMutablePointer<ObjNode>!) {
    if MenuStyle_GetFadeOutSceneOnExit(&gNav!.pointee.style) { OGL_FadeOutScene(DrawObjects, nil) }
    if MenuStyle_GetAsyncFadeOut(&gNav!.pointee.style) {
        if let dp = gNav!.pointee.darkenPane { rescaleDarkenPane(dp, Float(EPS)); _ = MakeTwitch(dp, Int32(kTwitchPreset_MenuFadeOut | kTwitchFlags_KillPuppet)) }
        for row in 0..<Int(MAX_MENU_ROWS) { var cn = mObj(row); while let c = cn { c.pointee.MoveCall = nil; _ = MakeTwitch(c, Int32(kTwitchPreset_MenuFadeOut | kTwitchFlags_KillPuppet)); cn = c.pointee.ChainNode } }
        for row in 0..<Int(MAX_MENU_ROWS) { setMObj(row, nil) }
    } else {
        deleteAllText()
        if let dp = gNav!.pointee.darkenPane { DeleteObject(dp); gNav!.pointee.darkenPane = nil }
    }
    DoSDLMaintenance(); MyFlushEvents()
    let exitCall = gNav!.pointee.style.exitCall
    gMenuOutcome = gNav!.pointee.menuPick
    disposeMenuNavigation(); DeleteObject(theNode)
    if let ec = exitCall { ec(gMenuOutcome) }
}
