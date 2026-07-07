// MenuBuilder.swift - A Swift-side replacement for the C99 designated-
// initializer array literals (`{ kMICycler2, STR_X, .cycler = {...} }`) and
// four-char-code literals (`.id='sett'`) that used to be the only reason
// Settings.c/Paused.c/AnaglyphCalibration.c/LevelIntro.c/MainMenu.c stayed
// in C.
//
// MenuItem's C struct/ABI is unchanged - RegisterMenu/MakeMenu still take
// UnsafePointer<MenuItem>, and all union-field *reads* still go through the
// existing shims in MenuInternal.h. This file only changes who *constructs*
// the array values.
//
// Construction uses plain property assignment (`item.cycler = MenuCyclerData(...)`),
// never `pointer(to:)`/`withUnsafeMutablePointer(to:)` on a union field - the
// latter type-checks but crashes at runtime for C union members (see
// SwiftSupport.swift's OGLMatrix4x4 note and MenuInternal.h's comments).
// Property assignment goes through ClangImporter's generated setter instead,
// which is the safe, supported path.

/// Converts a 4-character string into the Int32 four-char-code MenuItem
/// uses for `.id`/`.next` (e.g. `fourCC("sett")` replaces C's `'sett'`).
func fourCC(_ s: String) -> Int32 {
    let scalars = Array(s.unicodeScalars)
    precondition(scalars.count == 4, "fourCC requires exactly 4 characters")
    var result: UInt32 = 0
    for scalar in scalars {
        result = (result << 8) | (scalar.value & 0xFF)
    }
    return Int32(bitPattern: result)
}

/// Fills the fixed 8-element `MenuCyclerData.choices` tuple
/// (MAX_MENU_CYCLER_CHOICES) from a plain array, zero-filling the rest.
/// Mutates field-by-field (`cycler.choices.0.text = ...`) instead of
/// constructing the tuple's anonymous element type by name, since Clang's
/// generated name for that type isn't part of any stable, spellable API.
private func setCyclerChoices(_ cycler: inout MenuCyclerData, _ pairs: [(LocStrID, UInt8)]) {
    precondition(pairs.count <= 8, "at most MAX_MENU_CYCLER_CHOICES (8) choices")
    for i in 0..<8 {
        let text: LocStrID = i < pairs.count ? pairs[i].0 : STR_NULL
        let value: UInt8  = i < pairs.count ? pairs[i].1 : 0
        MenuCyclerData_SetChoiceText(&cycler, Int32(i), text)
        MenuCyclerData_SetChoiceValue(&cycler, Int32(i), value)
    }
}

/// A fixed-size, never-deallocated buffer of `MenuItem` - same storage-
/// duration contract as the C `static`/file-scope arrays this replaces.
/// `gNav.pointee.menu`/`gMenuRegistry` cache raw pointers into these for the
/// menu's (or app's) lifetime, so this can't be a Swift `Array`.
func makeMenuTreeBuffer(_ items: [MenuItem]) -> UnsafeMutablePointer<MenuItem> {
    let buffer = UnsafeMutablePointer<MenuItem>.allocate(capacity: items.count)
    for (i, item) in items.enumerated() {
        buffer[i] = item
    }
    return buffer
}

/// Returns a stable UnsafePointer<CChar> for a string literal.
/// `StaticString.utf8Start` holds a pointer directly into the binary's read-only
/// data, which has static storage duration — safe to store in a MenuItem.rawText field.
func staticCStr(_ s: StaticString) -> UnsafePointer<CChar> {
    UnsafeRawPointer(s.utf8Start).assumingMemoryBound(to: CChar.self)
}

// MARK: - MenuItem factories

private func baseItem(_ type: MenuItemType) -> MenuItem {
    var item = MenuItem()
    item.type = type
    return item
}

func miPick(_ text: LocStrID, next: Int32 = 0, id: Int32 = 0, rawText: UnsafePointer<CChar>? = nil, callback: (@convention(c) () -> Void)? = nil, getLayoutFlags: (@convention(c) (UnsafePointer<MenuItem>?) -> Int32)? = nil, customHeight: Float = 0) -> MenuItem {
    var item = baseItem(.pick)
    item.text = text
    item.rawText = rawText
    item.next = next
    item.id = id
    item.callback = callback
    item.getLayoutFlags = getLayoutFlags
    item.customHeight = customHeight
    return item
}

func miLabel(_ text: LocStrID = STR_NULL, rawText: UnsafePointer<CChar>? = nil, id: Int32 = 0, customHeight: Float = 0, getLayoutFlags: (@convention(c) (UnsafePointer<MenuItem>?) -> Int32)? = nil) -> MenuItem {
    var item = baseItem(.label)
    item.text = text
    item.rawText = rawText
    item.id = id
    item.customHeight = customHeight
    item.getLayoutFlags = getLayoutFlags
    return item
}

func miSpacer(customHeight: Float, getLayoutFlags: (@convention(c) (UnsafePointer<MenuItem>?) -> Int32)? = nil) -> MenuItem {
    var item = baseItem(.spacer)
    item.customHeight = customHeight
    item.getLayoutFlags = getLayoutFlags
    return item
}

func miCycler1(_ text: LocStrID, valuePtr: UnsafeMutablePointer<UInt8>, choices: [(LocStrID, UInt8)], callback: (@convention(c) () -> Void)? = nil) -> MenuItem {
    var item = baseItem(.cycler1)
    item.text = text
    item.callback = callback
    var cycler = MenuCyclerData()
    cycler.valuePtr = valuePtr
    cycler.isDynamicallyGenerated = false
    setCyclerChoices(&cycler, choices)
    item.cycler = cycler
    return item
}

func miCycler2(_ text: LocStrID, valuePtr: UnsafeMutablePointer<UInt8>, choices: [(LocStrID, UInt8)], callback: (@convention(c) () -> Void)? = nil, getLayoutFlags: (@convention(c) (UnsafePointer<MenuItem>?) -> Int32)? = nil) -> MenuItem {
    var item = baseItem(.cycler2)
    item.text = text
    item.callback = callback
    item.getLayoutFlags = getLayoutFlags
    var cycler = MenuCyclerData()
    cycler.valuePtr = valuePtr
    cycler.isDynamicallyGenerated = false
    setCyclerChoices(&cycler, choices)
    item.cycler = cycler
    return item
}

func miCycler2Dynamic(_ text: LocStrID, valuePtr: UnsafeMutablePointer<UInt8>, generateNumChoices: @convention(c) () -> Int32, generateChoiceString: @convention(c) (UInt8) -> UnsafePointer<CChar>?, callback: (@convention(c) () -> Void)? = nil, getLayoutFlags: (@convention(c) (UnsafePointer<MenuItem>?) -> Int32)? = nil) -> MenuItem {
    var item = baseItem(.cycler2)
    item.text = text
    item.callback = callback
    item.getLayoutFlags = getLayoutFlags
    var cycler = MenuCyclerData()
    cycler.valuePtr = valuePtr
    cycler.isDynamicallyGenerated = true
    MenuCyclerData_SetGeneratorNumChoices(&cycler, generateNumChoices)
    MenuCyclerData_SetGeneratorChoiceString(&cycler, generateChoiceString)
    item.cycler = cycler
    return item
}

func miSlider(_ text: LocStrID, valuePtr: UnsafeMutablePointer<UInt8>, minValue: UInt8, maxValue: UInt8, equilibrium: UInt8, increment: UInt8, continuousCallback: Bool, callback: (@convention(c) () -> Void)? = nil, getLayoutFlags: (@convention(c) (UnsafePointer<MenuItem>?) -> Int32)? = nil) -> MenuItem {
    var item = baseItem(.slider)
    item.text = text
    item.callback = callback
    item.getLayoutFlags = getLayoutFlags
    var slider = MenuSliderData()
    slider.valuePtr = valuePtr
    slider.minValue = minValue
    slider.maxValue = maxValue
    slider.equilibrium = equilibrium
    slider.increment = increment
    slider.continuousCallback = continuousCallback
    item.slider = slider
    return item
}

func miKeyBinding(_ inputNeed: Int32, getLayoutFlags: (@convention(c) (UnsafePointer<MenuItem>?) -> Int32)? = nil, customHeight: Float = 0) -> MenuItem {
    var item = baseItem(.keyBinding)
    item.inputNeed = inputNeed
    item.getLayoutFlags = getLayoutFlags
    item.customHeight = customHeight
    return item
}

func miPadBinding(_ inputNeed: Int32) -> MenuItem {
    var item = baseItem(.padBinding)
    item.inputNeed = inputNeed
    return item
}

func miMouseBinding(_ inputNeed: Int32) -> MenuItem {
    var item = baseItem(.mouseBinding)
    item.inputNeed = inputNeed
    return item
}

func miFileSlot(_ text: LocStrID, id: Int32, fileSlot: Int32, next: Int32 = 0, getLayoutFlags: (@convention(c) (UnsafePointer<MenuItem>?) -> Int32)? = nil, callback: (@convention(c) () -> Void)? = nil) -> MenuItem {
    var item = baseItem(.fileSlot)
    item.text = text
    item.id = id
    item.next = next
    item.getLayoutFlags = getLayoutFlags
    item.callback = callback
    item.fileSlot = fileSlot
    return item
}

/// A sentinel-only entry: either a menu root (`id != 0`, optionally with a
/// `callback` fired on entering that menu) or the array terminator (`id == 0`).
func miRoot(_ id: Int32 = 0, callback: (@convention(c) () -> Void)? = nil) -> MenuItem {
    var item = baseItem(.sentinel)
    item.id = id
    item.callback = callback
    return item
}
