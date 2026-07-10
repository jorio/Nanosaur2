// OGLSetupOutputTypeExtensions.swift - Bool sugar for OGLSetupOutputType's
// Boolean (UInt8) flags, replacing `pointee.fadeSound != 0` / `= 1` / `= 0`
// boilerplate at call sites. Same pattern as ObjNodeExtensions.swift.

extension UnsafeMutablePointer where Pointee == OGLSetupOutputType {
    var fadeSound: Bool {
        get { pointee.fadeSound != 0 }
        nonmutating set { pointee.fadeSound = newValue ? 1 : 0 }
    }
}
