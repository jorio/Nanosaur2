// FourCC.swift - four-char-code literals. C code spells these as
// multi-char character constants ('Hedr', 'sett'), which Clang's
// macro-constant importer can't fold for Swift, so ported call sites used
// raw hex (0x48656472) with a trailing comment naming the characters.
// These helpers make the characters the source of truth instead.
//
// Two overloads because the codebase uses both signednesses: menu ids
// (MenuItem.id/.next) are Int32, while resource/file types (ResType/OSType
// = FourCharCode = UInt32) and memory cookies are UInt32. The context's
// expected type picks the overload.

func fourCC(_ s: String) -> UInt32 {
    let scalars = Array(s.unicodeScalars)
    precondition(scalars.count == 4, "fourCC requires exactly 4 characters")
    var result: UInt32 = 0
    for scalar in scalars {
        result = (result << 8) | (scalar.value & 0xFF)
    }
    return result
}

func fourCC(_ s: String) -> Int32 {
    Int32(bitPattern: fourCC(s))
}
