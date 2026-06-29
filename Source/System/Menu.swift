// MARK: - Swift 6.3 C Interop Using @c @implementation
//
// This file implements C functions declared in menu.h using Swift 6.3's @c @implementation feature.
// C types (MenuItem, MenuItemType, ObjNode, etc.) are imported via the bridging header
// (Nanosaur2-Bridging-Header.h) which includes game.h.

// MARK: - Simple Utility Functions

@c @implementation
public func GetCurrentMenu() -> Int32 {
    return MenuSwift_GetCurrentMenuID()
}

@c @implementation
public func GetMenuIdleTime() -> Float {
    return MenuSwift_GetIdleTime()
}

@c @implementation
public func IsMenuMouseControlled() -> Bool {
    return MenuSwift_IsMouseControlled()
}

@c @implementation
public func GetCurrentMenuItemID() -> Int32 {
    let focusRow = MenuSwift_GetFocusRow()
    if focusRow < 0 {
        return -1
    }

    guard let menuItem = MenuSwift_GetCurrentMenuItem() else {
        return -1
    }

    let typedPtr = UnsafeMutablePointer<MenuItem>(mutating: menuItem)
    return typedPtr.pointee.id
}

@c @implementation
public func GetCurrentMenuItemObject() -> UnsafeMutablePointer<ObjNode>? {
    let focusRow = MenuSwift_GetFocusRow()
    if focusRow < 0 {
        return nil
    }
    return MenuSwift_GetMenuItemObject(focusRow)
}

@c @implementation
public func IsMenuTreeEndSentinel(_ menuItem: UnsafePointer<MenuItem>!) -> Bool {
    let item = menuItem.pointee
    return item.id == 0 && item.type == kMISENTINEL
}

@c @implementation
public func DisableEmptyFileSlots(_ menuItem: UnsafePointer<MenuItem>!) -> Int32 {
    let item = menuItem.pointee

    let validSaveSlotMask = MenuSwift_GetValidSaveSlotMask()
    let isValid = (validSaveSlotMask >> UInt64(bitPattern: Int64(item.fileSlot))) & 1
    let kMILayoutFlagDisabled: Int32 = 1 << 0

    return isValid != 0 ? 0 : kMILayoutFlagDisabled
}

// MARK: - C Accessor Functions
// These provide access to internal C state not exposed in headers.
// They are implemented in Menu.c.

@_silgen_name("MenuSwift_GetCurrentMenuID")
private func MenuSwift_GetCurrentMenuID() -> Int32

@_silgen_name("MenuSwift_GetIdleTime")
private func MenuSwift_GetIdleTime() -> Float

@_silgen_name("MenuSwift_IsMouseControlled")
private func MenuSwift_IsMouseControlled() -> Bool

@_silgen_name("MenuSwift_GetFocusRow")
private func MenuSwift_GetFocusRow() -> Int32

@_silgen_name("MenuSwift_GetCurrentMenuItem")
private func MenuSwift_GetCurrentMenuItem() -> UnsafePointer<MenuItem>?

@_silgen_name("MenuSwift_GetValidSaveSlotMask")
private func MenuSwift_GetValidSaveSlotMask() -> UInt64

@_silgen_name("MenuSwift_GetMenuItemObject")
private func MenuSwift_GetMenuItemObject(_ row: Int32) -> UnsafeMutablePointer<ObjNode>?
