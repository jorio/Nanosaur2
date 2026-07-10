// PrefsTypeExtensions.swift - Bool sugar for PrefsType's Boolean (UInt8)
// flags, replacing `== 0` / `!= 0` / `= 1` / `= 0` boilerplate at call
// sites. PrefsType itself stays UInt8-backed at the C-ABI level: Boot.cpp
// and the Settings/Paused/AnaglyphCalibration menu shims (SettingsInternal.h
// etc.) take raw Byte* addresses of specific gGamePrefs fields for use as
// MenuItem valuePtrs, so the underlying field types can't change - only
// these Swift-side accessors are new.

extension PrefsType {
    var isKiddieMode: Bool {
        get { kiddieMode != 0 }
        set { kiddieMode = newValue ? 1 : 0 }
    }

    var isLowRenderQuality: Bool {
        get { lowRenderQuality != 0 }
        set { lowRenderQuality = newValue ? 1 : 0 }
    }
}
