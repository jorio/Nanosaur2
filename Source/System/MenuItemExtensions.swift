// MenuItemExtensions.swift - method-call sugar for the already-ported
// Menu.swift free functions that take a MenuItem as their logical
// receiver. See ObjNodeExtensions.swift for why this is a plain Swift
// extension rather than swift_name(self:).

extension UnsafePointer where Pointee == MenuItem {
    func isTreeEndSentinel() -> Bool { IsMenuTreeEndSentinel(self) }
    func disableEmptyFileSlots() -> Int32 { DisableEmptyFileSlots(self) }
}
