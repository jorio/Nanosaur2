// PlayerInfoExtensions.swift - typed sugar for PlayerInfoType fields whose
// C representation is a raw integer holding a Swift enum's rawValue.
// Same UnsafeMutablePointer-extension pattern as ObjNodeExtensions.swift.

extension UnsafeMutablePointer where Pointee == PlayerInfoType {
    /// The C field is a `short` holding a WeaponType rawValue (-1 = none).
    var currentWeapon: WeaponType {
        get { WeaponType(rawValue: Int32(pointee.currentWeapon)) ?? .none }
        nonmutating set { pointee.currentWeapon = Int16(newValue.rawValue) }
    }
}
