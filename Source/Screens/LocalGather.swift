// LocalGather.swift - Port of LocalGather.c to Swift

private let FULL_CHANNEL_VOLUME: UInt32 = 0x0100
private let NORMAL_CHANNEL_RATE: UInt = 0x10000

private var gGatherPrompt: UnsafeMutablePointer<ObjNode>!
private var gNumControllersMissing: Int32 = 4

private func UpdateGatherPrompt(_ numControllersMissing: Int32) {
    if numControllersMissing <= 0 {
        TextMesh_Update("OK", 0, gGatherPrompt)
        gGatherPrompt.pointee.Scale.x = 1
        gGatherPrompt.pointee.Scale.y = 1
        UpdateObjectTransforms(gGatherPrompt)
        // gGameViewInfoPtr->fadeOutDuration = .3f;
    } else {
        let message = numControllersMissing == 1
            ? localized(STR_CONNECT_1_CONTROLLER)
            : localized(STR_CONNECT_2_CONTROLLERS)

        TextMesh_Update(message, 0, gGatherPrompt)
    }
}

// Return true if user aborts.
func DoLocalGatherScreen() -> UInt8 {
    gNumControllersMissing = Int32(gNumPlayers)
    // UnlockPlayerControllerMapping();

    if GetNumGamepad() >= Int32(gNumPlayers) {
        // Skip gather screen if we already have enough controllers
        return 0
    }

    SetupLocalGatherScreen()
    _ = MakeFadeEvent(UInt8(kFadeFlags_In), 3)

    // MAIN LOOP

    CalcFramesPerSecond()
    DoSDLMaintenance() // ReadKeyboard();

    var outcome: Int32 = 0

    while outcome == 0 {
        // SEE IF MAKE SELECTION
        outcome = DoLocalGatherControls()

        let numControllers = GetNumGamepad()

        gNumControllersMissing = Int32(gNumPlayers) - numControllers
        if gNumControllersMissing < 0 {
            gNumControllersMissing = 0
        }

        UpdateGatherPrompt(gNumControllersMissing)

        // DRAW STUFF

        CalcFramesPerSecond()
        DoSDLMaintenance() // ReadKeyboard();
        MoveObjects()
        OGL_DrawScene(DrawObjects)
    }

    // SHOW 'OK!'

    if outcome >= 0 {
        UpdateGatherPrompt(0)
    }

    // CLEANUP

    OGL_FadeOutScene(DrawObjects, MoveObjects)

    DeleteAllObjects()
    FreeAllSkeletonFiles(-1)
    DisposeAllBG3DContainers()
    OGL_DisposeGameView()

    // SET CHARACTER TYPE SELECTED

    return outcome < 0 ? 1 : 0
}

private func SetupLocalGatherScreen() {
    var viewDef = OGLSetupInputType()
    let ambientColor = OGLColorRGBA(r: 0.5, g: 0.5, b: 0.5, a: 1)
    let fillColor1 = OGLColorRGBA(r: 1.0, g: 1.0, b: 1.0, a: 1)
    let fillDirection1 = OGLVector3D(x: 0.9, y: -0.3, z: -1)

    // SETUP VIEW

    OGL_NewViewDef(&viewDef)

    viewDef.camera.fov = 0.3
    viewDef.camera.hither = 10
    viewDef.camera.yon = 3000
    viewDef.camera.from.0.z = 700

    viewDef.view.clearColor = OGLColorRGBA(r: 0, g: 0, b: 0, a: 1)
    viewDef.styles.useFog = 0
    // viewDef.view.pillarboxRatio = PILLARBOX_RATIO_4_3;

    viewDef.lights.ambientColor = ambientColor
    viewDef.lights.numFillLights = 1
    viewDef.lights.fillDirection.0 = fillDirection1
    viewDef.lights.fillColor.0 = fillColor1

    // viewDef.view.fontName = "rockfont";

    OGL_SetupGameView(&viewDef)

    // LOAD ART

    // MAKE BACKGROUND PICTURE OBJECT
    // MakeBackgroundPictureObject(":images:CharSelectScreen.jpg");
    // MakeScrollingBackgroundPattern();

    // BUILD OBJECTS

    var def2 = NewObjectDefinitionType()
    def2.scale = 0.4
    def2.coord = OGLPoint3D(x: 640 / 2, y: 480 / 2, z: 0)
    def2.slot = Int16(SPRITE_SLOT)
    def2.group = UInt8(ATLAS_GROUP_FONT2)

    gGatherPrompt = TextMesh_NewEmpty(256, &def2)
    SendNodeToOverlayPane(gGatherPrompt)

    def2.coord.y = 480 / 2 + 220
    def2.scale = 0.27
    let pressEsc = TextMesh_New(localized(STR_PRESS_ESC_TO_GO_BACK), 0, &def2)
    SendNodeToOverlayPane(pressEsc)
    pressEsc.pointee.ColorFilter = OGLColorRGBA(r: 0.5, g: 0.5, b: 0.5, a: 1)
    _ = MakeTwitch(pressEsc, Int32(kTwitchPreset_PressKeyPrompt))
}

private func DoLocalGatherControls() -> Int32 {
    if gNumControllersMissing == 0 {
        return 1
    }

    if SwIsNeedDown(kNeed_UIBack, ANY_PLAYER) {
        return -1
    }

    // SEE IF SELECT THIS ONE

    if SwIsKeyDown(Int(SDL_SCANCODE_RETURN.rawValue)) || SwIsKeyDown(Int(SDL_SCANCODE_KP_ENTER.rawValue)) {
        // User pressed [ENTER] on keyboard
        if gNumControllersMissing == 1 {
            PlayEffect_Parms(Int16(EFFECT_MENUSELECT), FULL_CHANNEL_VOLUME, FULL_CHANNEL_VOLUME, NORMAL_CHANNEL_RATE * 2 / 3)
            return 1
        } else {
            PlayEffect_Parms(Int16(EFFECT_BADSELECT), FULL_CHANNEL_VOLUME / 4, FULL_CHANNEL_VOLUME / 4, NORMAL_CHANNEL_RATE)
            _ = MakeTwitch(gGatherPrompt, Int32(kTwitchPreset_PadlockWiggle))
        }
    } else if SwIsNeedDown(kNeed_UIConfirm, ANY_PLAYER) {
        // User pressed [A] on gamepad
        if gNumControllersMissing > 0 {
            PlayEffect_Parms(Int16(EFFECT_BADSELECT), FULL_CHANNEL_VOLUME / 4, FULL_CHANNEL_VOLUME / 4, NORMAL_CHANNEL_RATE)
            _ = MakeTwitch(gGatherPrompt, Int32(kTwitchPreset_PadlockWiggle))
        }
    } else if IsCheatKeyComboDown() != 0 { // useful to test local multiplayer without having all controllers plugged in
        PlayEffect(Int16(EFFECT_CRYSTALSHATTER))
        return 1
    }

    return 0
}

private let ANY_PLAYER: Int = -1
