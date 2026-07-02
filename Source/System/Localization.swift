// Localization.swift - Port of Localization.c to Swift (partial)
//
// LocalizeWithPlaceholder stays in Localization.c: it takes C variadic
// arguments (...), which Swift can't implement. IsNativeEnglishSystem and
// GetBestLanguageIDFromSystemLocale also stay in C since they consume
// kLanguageCodesISO639_1, a 2D fixed char array that isn't practical to
// build from Swift.

private let kCsvPath = ":System:strings.csv"

private let kNullPlaceholder = strdup("???")
private let kNotLoadedMsg = strdup("STRINGS NOT LOADED")
private let kIllegalIdMsg = strdup("ILLEGAL STRING ID")
private let kEmptyMsg = strdup("")

private var gCurrentStringsLanguage: GameLanguageID = LANGUAGE_ILLEGAL
private var gStringsBuffer: UnsafeMutablePointer<CChar>?
private var gStringsTable: [UnsafeMutablePointer<CChar>?] = []

@c @implementation
public func LoadLocalizedStrings(_ languageID: GameLanguageID) {
    // Don't bother reloading strings if we've already loaded this language
    if languageID == gCurrentStringsLanguage {
        return
    }

    // Free previous strings buffer
    DisposeLocalizedStrings()

    SwGameAssert(languageID.rawValue >= 0)
    SwGameAssert(languageID.rawValue < NUM_LANGUAGES.rawValue)

    var count: Int = 0
    gStringsBuffer = LoadTextFile(kCsvPath, &count)

    let maxStrings = Int(NUM_LOCALIZED_STRINGS.rawValue) + 1
    gStringsTable = [UnsafeMutablePointer<CChar>?](repeating: nil, count: maxStrings)
    gStringsTable[Int(STR_NULL.rawValue)] = kNullPlaceholder
    SwGameAssert(STR_NULL.rawValue == 0) // STR_NULL must be 0!

    var row: Int32 = 1 // start row at 1, so that 0 is an illegal index (STR_NULL)

    var csvReader: UnsafeMutablePointer<CChar>? = gStringsBuffer
    while csvReader != nil {
        var myPhrase: UnsafeMutablePointer<CChar>?
        var eol = false

        var x: Int32 = 0
        while !eol {
            let phrase = CSVIterator(&csvReader, &eol)

            if let phrase, phrase.pointee != 0, (x == languageID.rawValue || myPhrase == nil) {
                myPhrase = phrase
            }
            x += 1
        }

        if let myPhrase {
            SwGameAssert(row < NUM_LOCALIZED_STRINGS.rawValue)
            gStringsTable[Int(row)] = myPhrase
            row += 1
        }
    }

    SwGameAssert(row == NUM_LOCALIZED_STRINGS.rawValue)
}

@c @implementation
public func Localize(_ stringID: LocStrID) -> UnsafePointer<CChar>! {
    guard gStringsBuffer != nil else { return UnsafePointer(kNotLoadedMsg) }

    let id = Int(stringID.rawValue)
    guard id >= 0 && id < gStringsTable.count else { return UnsafePointer(kIllegalIdMsg) }

    guard let entry = gStringsTable[id] else { return UnsafePointer(kEmptyMsg) }

    return UnsafePointer(entry)
}

@c @implementation
public func DisposeLocalizedStrings() {
    if gStringsBuffer != nil {
        SafeDisposePtr(gStringsBuffer)
        gStringsBuffer = nil
    }
}
