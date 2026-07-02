// TerrainItemEntryTypeExtensions.swift - method-call sugar for the
// already-ported Crystals.swift free function that takes a
// TerrainItemEntryType as its logical receiver. See ObjNodeExtensions.swift
// for why this is a plain Swift extension rather than swift_name(self:).

extension UnsafeMutablePointer where Pointee == TerrainItemEntryType {
    @discardableResult func addCrystal(x: Float, z: Float) -> UInt8 { AddCrystal(self, x, z) }
}
