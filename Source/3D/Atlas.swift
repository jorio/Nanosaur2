// Atlas.swift - Port of Atlas.c to Swift
//
// gAtlases isn't `extern`'d anywhere (not `static` in the original C, but
// nothing else declares `extern Atlas* gAtlases[]` either), so it moves
// into private Swift state. Atlas/AtlasGlyph themselves stay as plain C
// structs (declared in atlas.h) since nothing else in this file needed to
// change about them - they're never touched by any other C or Swift file.
//
// SDL_snprintf/SDL_sscanf are variadic, which Swift can't call (same
// reasoning as DoAlert/DoFatalAlert staying in Misc.c). The two
// SDL_snprintf("%s", ...) calls are plain string copies, so they're
// replaced with direct Swift string handling; the SDL_sscanf-based file
// parsers (ParseAtlasMetrics/ParseKerningFile) are reimplemented using
// Swift string/pointer parsing instead of the C format-string engine.

private let TAB_STOP: Float = 128.0
private let MAX_LINEBREAKS_PER_OBJNODE = 16
private let MAX_IMMEDIATEMODE_QUADS = 1024
private let SUBSCRIPT_SCALE: Float = 0.8

private let kControlChar_LineBreak: UInt32 = 10 // '\n'
private let kControlChar_Tab: UInt32 = 9 // '\t'
private let kControlChar_Subscript: UInt32 = 11 // '\v'
private let kControlChar_ResetInlineFormatting: UInt32 = 13 // '\r'

// NOTE: keep this literal count (16) in sync with MAX_LINEBREAKS_PER_OBJNODE
// above - InlineArray's size is a compile-time generic parameter, so it
// can't reference the `let` constant directly.
private struct TextMetrics {
    var numQuads: Int32 = 0
    var numLines: Int32 = 0
    var bbWidth: Float = 0
    var bbHeight: Float = 0
    var lineWidths: InlineArray<16, Float> = InlineArray(repeating: 0)
    var lineHeights: InlineArray<16, Float> = InlineArray(repeating: 0)
    var lineOffsetX: InlineArray<16, Float> = InlineArray(repeating: 0)
    var lineOffsetY: InlineArray<16, Float> = InlineArray(repeating: 0)
}

private let gImmediateModePoints = AllocPtrClear(MemoryLayout<OGLPoint3D>.size * MAX_IMMEDIATEMODE_QUADS * 4)!.assumingMemoryBound(to: OGLPoint3D.self)
private let gImmediateModeUVs = AllocPtrClear(MemoryLayout<OGLTextureCoord>.size * MAX_IMMEDIATEMODE_QUADS * 4)!.assumingMemoryBound(to: OGLTextureCoord.self)

private var gAtlases = [UnsafeMutablePointer<Atlas>?](repeating: nil, count: Int(MAX_ATLASES))

// MARK: - UTF-8

private func toUpperUnicode(_ c: UInt32) -> UInt32 {
    if (c >= 0x0061 && c <= 0x007A) // ascii: a...z
        || (c >= 0x00E0 && c <= 0x00F6) // latin-1: agrave...ouml
        || (c >= 0x00F8 && c <= 0x00FE) { // latin-1: oslash...thorn
        return c - 0x0020
    } else if c == 0x00FF { // yuml
        return 0x0178
    } else if (c >= 0x0100 && c <= 0x0137) // latin extended-A (uppercase even indices)
        || (c >= 0x014A && c <= 0x0177) {
        return c & ~1
    } else if (c >= 0x0139 && c <= 0x0148) // latin extended-A (uppercase odd indices)
        || (c >= 0x179 && c <= 0x017E) {
        return c | 1
    } else if c >= 0x0430 && c <= 0x044F { // cyrillic
        return c - 0x0020
    } else if c >= 0x0450 && c <= 0x045F { // cyrillic extensions
        return c - 0x0050
    }

    return c
}

// MARK: - Get/set glyphs

private func atlasGetGlyphPtr(_ atlas: UnsafePointer<Atlas>, _ codepoint: UInt32) -> UnsafeMutablePointer<AtlasGlyph>? {
    let page = Int(codepoint >> 8)

    if page >= Int(atlas.pointee.maxPages) || atlas.pointee.glyphPages![page] == nil {
        return nil
    }

    return atlas.pointee.glyphPages![page]! + Int(codepoint & 0xFF)
}

func Atlas_GetGlyph(_ atlas: UnsafePointer<Atlas>, _ codepoint: UInt32) -> UnsafePointer<AtlasGlyph>? {
    UnsafePointer(atlasGetGlyphPtr(atlas, codepoint))
}

private func atlasSetGlyph(_ atlas: UnsafeMutablePointer<Atlas>, _ codepoint: UInt32, _ src: AtlasGlyph) {
    // Compute page for codepoint
    let page = Int(codepoint >> 8)
    if page >= Int(atlas.pointee.maxPages) {
        SwLog("WARNING: codepoint exceeds supported maximum")
        return
    }

    // Allocate codepoint page
    if atlas.pointee.glyphPages![page] == nil {
        atlas.pointee.glyphPages![page] = AllocPtrClear(MemoryLayout<AtlasGlyph>.size * 256)?.assumingMemoryBound(to: AtlasGlyph.self)
    }

    // Store glyph
    atlas.pointee.glyphPages![page]![Int(codepoint & 0xFF)] = src
}

// MARK: - Parse metrics file

private func skipWhitespace(_ data: inout UnsafePointer<CChar>?) {
    while let d = data, d.pointee != 0, d.pointee == 9 || d.pointee == 13 || d.pointee == 10 || d.pointee == 32 {
        data = d + 1
    }
}

private func parseAtlasMetrics(_ atlas: UnsafeMutablePointer<Atlas>, _ dataPtr: UnsafePointer<CChar>, _ imageWidth: Int, _ imageHeight: Int) {
    let fullText = String(cString: dataPtr)
    var lines = fullText.split(separator: "\n", omittingEmptySubsequences: false)[...]

    func nextLineFields() -> [Substring]? {
        guard let line = lines.first else {
            return nil
        }
        lines = lines.dropFirst()
        return line.split(whereSeparator: { $0 == " " || $0 == "\t" || $0 == "\r" })
    }

    guard let headerFields = nextLineFields(), headerFields.count >= 2,
        let nGlyphs = Int(headerFields[0]), let lineHeight = Float(headerFields[1]) else {
        SwGameAssert(false)
        return
    }
    atlas.pointee.lineHeight = lineHeight

    for _ in 0..<nGlyphs {
        guard let fields = nextLineFields(), fields.count >= 9,
            let codepoint = UInt32(fields[0]),
            let x = Float(fields[1]), let y = Float(fields[2]),
            let w = Float(fields[3]), let h = Float(fields[4]),
            let xoff = Float(fields[5]), let yoff = Float(fields[6]),
            let xadv = Float(fields[7]), let yadv = Float(fields[8]) else {
            SwGameAssert(false)
            continue
        }

        var newGlyph = AtlasGlyph()
        newGlyph.w = w
        newGlyph.h = h
        newGlyph.xoff = xoff
        newGlyph.yoff = yoff
        newGlyph.xadv = xadv
        newGlyph.yadv = yadv

        newGlyph.u1 = x / Float(imageWidth)
        newGlyph.u2 = (x + w) / Float(imageWidth)
        newGlyph.v1 = y / Float(imageHeight)
        newGlyph.v2 = (y + h) / Float(imageHeight)

        atlasSetGlyph(atlas, codepoint, newGlyph)
    }

    // Force monospaced numbers
    if atlas.pointee.isASCIIFont {
        let asciiPage = atlas.pointee.glyphPages![0]!
        let referenceNumber = asciiPage[Int(UInt8(ascii: "4"))]
        for c in UInt8(ascii: "0")...UInt8(ascii: "9") {
            asciiPage[Int(c)].xoff += (referenceNumber.w - asciiPage[Int(c)].w) / 2.0
            asciiPage[Int(c)].xadv = referenceNumber.xadv
        }
    }
}

// MARK: - Parse kerning table

private func parseKerningFile(_ atlas: UnsafeMutablePointer<Atlas>, _ dataPtr: UnsafePointer<CChar>) {
    var kernTableOffset = 0
    var data: UnsafePointer<CChar>? = dataPtr

    while let d = data, d.pointee != 0 {
        var cursor: UnsafePointer<CChar>? = d

        let codepoint1 = SDL_StepUTF8(&cursor, nil)
        SwGameAssert(codepoint1 != 0)

        let codepoint2 = SDL_StepUTF8(&cursor, nil)
        SwGameAssert(codepoint2 != 0)

        skipWhitespace(&cursor)
        SwGameAssert(cursor!.pointee != 0)

        // Parse a plain decimal integer (SDL_sscanf("%d%n", ...) is variadic; Swift can't call it)
        var neg = false
        if cursor!.pointee == 45 { // '-'
            neg = true
            cursor = cursor! + 1
        }
        var tracking = 0
        var consumedDigit = false
        while cursor!.pointee >= 48 && cursor!.pointee <= 57 { // '0'-'9'
            tracking = tracking * 10 + Int(cursor!.pointee - 48)
            cursor = cursor! + 1
            consumedDigit = true
        }
        SwGameAssert(consumedDigit)
        if neg {
            tracking = -tracking
        }

        if let g = atlasGetGlyphPtr(atlas, codepoint1) {
            if g.pointee.numKernPairs == 0 {
                SwGameAssert(g.pointee.kernTableOffset == 0)
                g.pointee.kernTableOffset = UInt16(kernTableOffset)
            }

            SwGameAssertMessage(Int(g.pointee.numKernPairs) == kernTableOffset - Int(g.pointee.kernTableOffset), "kern pair blocks aren't contiguous!")

            atlas.pointee.kernPairs![kernTableOffset] = UInt16(truncatingIfNeeded: codepoint2)
            atlas.pointee.kernTracking![kernTableOffset] = UInt8(truncatingIfNeeded: tracking)
            kernTableOffset += 1
            SwGameAssert(kernTableOffset <= Int(MAX_KERNPAIRS))
            g.pointee.numKernPairs += 1
        }

        skipWhitespace(&cursor)
        data = cursor
    }
}

// MARK: - Init/shutdown

func LoadSpriteAtlas(_ groupNum: Int32, _ atlasName: String, _ flags: Int32) {
    if let existing = gAtlases[Int(groupNum)] {
        // Sprite group busy
        let existingName = withUnsafePointer(to: existing.pointee.name) {
            String(cString: UnsafeRawPointer($0).assumingMemoryBound(to: CChar.self))
        }
        if atlasName == existingName {
            // This atlas is already loaded
            return
        } else {
            // Make room for new atlas
            DisposeSpriteAtlas(groupNum)
        }
    }

    SwGameAssertMessage(gAtlases[Int(groupNum)] == nil, "Sprite group already loaded!")
    gAtlases[Int(groupNum)] = Atlas_Load(atlasName, flags)
}

func DisposeSpriteAtlas(_ groupNum: Int32) {
    if let atlas = gAtlases[Int(groupNum)] {
        Atlas_Dispose(atlas)
        gAtlases[Int(groupNum)] = nil
    }
}

func DisposeAllSpriteAtlases() {
    for i in 0..<Int(MAX_ATLASES) {
        DisposeSpriteAtlas(Int32(i))
    }
}

func Atlas_Load(_ fontName: String, _ flags: Int32) -> UnsafeMutablePointer<Atlas> {
    let atlas = AllocPtrClear(MemoryLayout<Atlas>.size)!.assumingMemoryBound(to: Atlas.self)

    if flags & Int32(kAtlasLoadFont) != 0 {
        atlas.pointee.isASCIIFont = true
        atlas.pointee.isASCIIFontUpperCaseOnly = (flags & Int32(kAtlasLoadFontIsUpperCaseOnly)) != 0

        atlas.pointee.maxPages = UInt32(MAX_CODEPOINT_PAGES)
        atlas.pointee.glyphPages = AllocPtrClear(MemoryLayout<UnsafeMutablePointer<AtlasGlyph>?>.size * Int(atlas.pointee.maxPages))?.assumingMemoryBound(to: UnsafeMutablePointer<AtlasGlyph>?.self)

        atlas.pointee.kernPairs = AllocPtrClear(MemoryLayout<UInt16>.size * Int(MAX_KERNPAIRS))?.assumingMemoryBound(to: UInt16.self)
        atlas.pointee.kernTracking = AllocPtrClear(MemoryLayout<UInt8>.size * Int(MAX_KERNPAIRS))?.assumingMemoryBound(to: UInt8.self)
    } else {
        atlas.pointee.maxPages = 1
        atlas.pointee.glyphPages = AllocPtrClear(MemoryLayout<UnsafeMutablePointer<AtlasGlyph>?>.size * Int(atlas.pointee.maxPages))?.assumingMemoryBound(to: UnsafeMutablePointer<AtlasGlyph>?.self)

        atlas.pointee.kernPairs = nil
        atlas.pointee.kernTracking = nil
    }

    let fontNameString = fontName

    let nameCapacity = MemoryLayout.size(ofValue: atlas.pointee.name)
    let nameBytes = Array(fontNameString.utf8CString.prefix(nameCapacity - 1)) + [0] // truncate, keep room for nul terminator
    withUnsafeMutablePointer(to: &atlas.pointee.name) {
        UnsafeMutableRawPointer($0).assumingMemoryBound(to: CChar.self)
    }.update(from: nameBytes, count: nameBytes.count)

    let pathString = (flags & Int32(kAtlasLoadAltSkin1)) != 0 ? fontNameString + ".alt1" : fontNameString

    // Create font material
    var outWidth: Int32 = 0
    var outHeight: Int32 = 0
    let textureName = OGL_TextureMap_LoadImageFile(pathString, &outWidth, &outHeight, nil)
    atlas.pointee.textureWidth = outWidth
    atlas.pointee.textureHeight = outHeight

    SwGameAssert(atlas.pointee.textureWidth != 0)
    SwGameAssert(atlas.pointee.textureHeight != 0)

    SwGameAssertMessage(atlas.pointee.material == nil, "atlas material already created")
    var matData = MOMaterialData()
    matData.flags = UInt32(BG3D_MATERIALFLAG_ALWAYSBLEND | BG3D_MATERIALFLAG_TEXTURED | BG3D_MATERIALFLAG_CLAMP_U | BG3D_MATERIALFLAG_CLAMP_V)
    matData.diffuseColor = OGLColorRGBA(r: 1, g: 1, b: 1, a: 1)
    matData.numMipmaps = 1
    matData.width = UInt32(atlas.pointee.textureWidth)
    matData.height = UInt32(atlas.pointee.textureHeight)
    matData.textureName.0 = textureName
    atlas.pointee.material = MO_CreateNewObjectOfType(.material, 0, &matData)?.assumingMemoryBound(to: MOMaterialObject.self)

    if flags & Int32(kAtlasLoadAsSingleSprite) == 0 {
        // Parse metrics from SFL file
        let sflPath = fontNameString + ".txt"
        guard let data = LoadTextFile(sflPath, nil) else {
            SwGameAssert(false)
            return atlas
        }
        parseAtlasMetrics(atlas, data, Int(atlas.pointee.textureWidth), Int(atlas.pointee.textureHeight))
        SafeDisposePtr(data)
    } else {
        // Create single glyph #1
        let w = Float(atlas.pointee.material!.width)
        let h = Float(atlas.pointee.material!.height)
        var newGlyph = AtlasGlyph()
        newGlyph.xadv = w
        newGlyph.yadv = h
        newGlyph.w = w
        newGlyph.h = h
        newGlyph.u2 = 1
        newGlyph.v2 = 1
        newGlyph.xoff = 0
        newGlyph.yoff = 0
        atlasSetGlyph(atlas, 1, newGlyph)
    }

    if flags & Int32(kAtlasLoadFont) != 0 {
        let kerningPath = fontNameString + ".kerning.txt"

        // Parse kerning table
        if let data = LoadTextFile(kerningPath, nil) {
            parseKerningFile(atlas, data)
            SafeDisposePtr(data)
        }
    }

    return atlas
}

func Atlas_Dispose(_ atlas: UnsafeMutablePointer<Atlas>) {
    MO_DisposeObjectReference(UnsafeMutableRawPointer(atlas.pointee.material))
    atlas.pointee.material = nil

    for i in 0..<Int(atlas.pointee.maxPages) {
        if let page = atlas.pointee.glyphPages![i] {
            SafeDisposePtr(page)
            atlas.pointee.glyphPages![i] = nil
        }
    }

    SafeDisposePtr(atlas.pointee.glyphPages)
    atlas.pointee.glyphPages = nil

    if let kernPairs = atlas.pointee.kernPairs {
        SafeDisposePtr(kernPairs)
        atlas.pointee.kernPairs = nil
    }

    if let kernTracking = atlas.pointee.kernTracking {
        SafeDisposePtr(kernTracking)
        atlas.pointee.kernTracking = nil
    }

    SafeDisposePtr(atlas)
}

// MARK: - Mesh allocation/layout

private func kern(_ font: UnsafePointer<Atlas>, _ glyph: UnsafePointer<AtlasGlyph>?, _ nextCodepoint: UInt32, _ flags: Int32) -> Float {
    guard let glyph, glyph.pointee.numKernPairs != 0 else {
        return 1
    }

    var buddy = nextCodepoint

    if font.pointee.isASCIIFontUpperCaseOnly || (flags & Int32(kTextMeshSmallCaps | kTextMeshAllCaps)) != 0 {
        buddy = toUpperUnicode(buddy)
    }

    for i in Int(glyph.pointee.kernTableOffset)..<(Int(glyph.pointee.kernTableOffset) + Int(glyph.pointee.numKernPairs)) {
        if font.pointee.kernPairs![i] == buddy {
            return Float(font.pointee.kernTracking![i]) * 0.01
        }
    }

    return 1
}

private func computeMetrics(_ atlas: UnsafePointer<Atlas>, _ codepoints: [UInt32], _ flags: Int32, _ m: inout TextMetrics) {
    var currentLine = 0
    var glyphScale: Float = 1

    // Compute number of quads and line width
    m.numLines = 1
    m.numQuads = 0
    m.lineWidths[0] = 0
    m.lineHeights[0] = 0
    m.bbWidth = 0
    m.bbHeight = 0

    for (i, rawCodepoint) in codepoints.enumerated() {
        var codepoint = rawCodepoint

        if atlas.pointee.isASCIIFont { // Parse control characters if it's a font
            switch codepoint {
            case kControlChar_LineBreak:
                m.bbWidth = max(m.bbWidth, m.lineWidths[currentLine])
                m.bbHeight += m.lineHeights[currentLine]

                currentLine += 1
                SwGameAssert(currentLine < MAX_LINEBREAKS_PER_OBJNODE)

                m.lineWidths[currentLine] = 0 // init next line
                m.lineHeights[currentLine] = 0
                continue

            case kControlChar_Tab:
                m.lineWidths[currentLine] = TAB_STOP * ceilf((m.lineWidths[currentLine] + 1.0) / TAB_STOP)
                continue

            case kControlChar_Subscript:
                glyphScale *= SUBSCRIPT_SCALE
                continue

            case kControlChar_ResetInlineFormatting:
                glyphScale = 1
                continue

            default:
                break
            }

            if flags & Int32(kTextMeshSmallCaps) != 0 {
                let oldCodepoint = codepoint
                codepoint = toUpperUnicode(codepoint)
                glyphScale = (codepoint == oldCodepoint) ? 1 : SUBSCRIPT_SCALE
            } else if (flags & Int32(kTextMeshAllCaps)) != 0 || atlas.pointee.isASCIIFontUpperCaseOnly {
                codepoint = toUpperUnicode(codepoint)
            }
        }

        guard let glyph = Atlas_GetGlyph(atlas, codepoint) else {
            continue
        }

        var kernFactor: Float
        var glyphHeight: Float

        if atlas.pointee.isASCIIFont {
            let next = i + 1 < codepoints.count ? codepoints[i + 1] : 0
            kernFactor = kern(atlas, glyph, next, flags)
            glyphHeight = atlas.pointee.lineHeight
        } else {
            kernFactor = 1
            glyphHeight = glyph.pointee.yadv
        }

        m.lineWidths[currentLine] += glyphScale * (glyph.pointee.xadv * kernFactor)
        m.lineHeights[currentLine] = max(m.lineHeights[currentLine], glyphHeight)

        if glyph.pointee.w > 0 { // zero-width glyphs don't produce a quad (e.g. space)
            m.numQuads += 1
        }
    }

    // Commit last line
    m.bbWidth = max(m.bbWidth, m.lineWidths[currentLine])
    m.bbHeight += m.lineHeights[currentLine]

    // Commit line count
    m.numLines = Int32(currentLine + 1)

    switch flags & Int32(kTextMeshAlignCenter | kTextMeshAlignLeft | kTextMeshAlignRight) {
    case Int32(kTextMeshAlignLeft):
        for i in 0..<MAX_LINEBREAKS_PER_OBJNODE {
            m.lineOffsetX[i] = 0
        }

    case Int32(kTextMeshAlignRight):
        for i in 0..<Int(m.numLines) {
            m.lineOffsetX[i] = -m.lineWidths[i]
        }

    default:
        for i in 0..<Int(m.numLines) {
            m.lineOffsetX[i] = -m.lineWidths[i] * 0.5
        }
    }

    var startY: Float = 0
    switch flags & Int32(kTextMeshAlignMiddle | kTextMeshAlignTop | kTextMeshAlignBottom) {
    case Int32(kTextMeshAlignTop):
        startY = 0

    case Int32(kTextMeshAlignBottom):
        startY = -m.bbHeight

    default:
        startY = -m.bbHeight * 0.5
    }

    for i in 0..<Int(m.numLines) {
        m.lineOffsetY[i] = startY
        startY += m.lineHeights[i]
    }
}

private func prepVertices(
    _ atlas: UnsafePointer<Atlas>,
    _ codepoints: [UInt32],
    _ flags: Int32,
    _ metrics: TextMetrics,
    _ points: UnsafeMutablePointer<OGLPoint3D>,
    _ uvs: UnsafeMutablePointer<OGLTextureCoord>
) {
    let z: Float = 0

    // Get top-left corner of text
    var x = metrics.lineOffsetX[0]
    var y = metrics.lineOffsetY[0]

    var p = 0 // point counter
    var currentLine = 0
    var glyphScale: Float = 1

    for (i, rawCodepoint) in codepoints.enumerated() {
        var codepoint = rawCodepoint

        if atlas.pointee.isASCIIFont { // Parse control characters if it's a font
            switch codepoint {
            case kControlChar_LineBreak:
                currentLine += 1
                x = metrics.lineOffsetX[currentLine]
                y = metrics.lineOffsetY[currentLine]
                glyphScale = 1
                continue

            case kControlChar_Tab:
                x = TAB_STOP * ceilf((x + 1.0) / TAB_STOP)
                continue

            case kControlChar_Subscript:
                y += atlas.pointee.lineHeight * (1.0 - SUBSCRIPT_SCALE * 1.05)
                glyphScale *= SUBSCRIPT_SCALE
                continue

            case kControlChar_ResetInlineFormatting:
                y = metrics.lineOffsetY[currentLine]
                glyphScale = 1
                continue

            default:
                break
            }

            if flags & Int32(kTextMeshSmallCaps) != 0 {
                let oldCodepoint = codepoint
                codepoint = toUpperUnicode(codepoint)

                if codepoint == oldCodepoint {
                    y = metrics.lineOffsetY[currentLine]
                    glyphScale = 1
                } else {
                    y = metrics.lineOffsetY[currentLine] + atlas.pointee.lineHeight * (1.0 - SUBSCRIPT_SCALE * 1.05)
                    glyphScale = SUBSCRIPT_SCALE
                }
            } else if (flags & Int32(kTextMeshAllCaps)) != 0 || atlas.pointee.isASCIIFontUpperCaseOnly {
                codepoint = toUpperUnicode(codepoint)
            }
        }

        guard let g = Atlas_GetGlyph(atlas, codepoint) else {
            continue
        }

        if g.pointee.w <= 0 { // e.g. space codepoint
            x += g.pointee.xadv
            continue
        }

        let left = x + glyphScale * g.pointee.xoff
        let top = y + glyphScale * g.pointee.yoff
        let right = left + glyphScale * g.pointee.w
        let bottom = top + glyphScale * g.pointee.h

        uvs[p + 0] = OGLTextureCoord(u: g.pointee.u1, v: g.pointee.v2)
        uvs[p + 1] = OGLTextureCoord(u: g.pointee.u2, v: g.pointee.v2)
        uvs[p + 2] = OGLTextureCoord(u: g.pointee.u2, v: g.pointee.v1)
        uvs[p + 3] = OGLTextureCoord(u: g.pointee.u1, v: g.pointee.v1)
        points[p + 0] = OGLPoint3D(x: left, y: bottom, z: z)
        points[p + 1] = OGLPoint3D(x: right, y: bottom, z: z)
        points[p + 2] = OGLPoint3D(x: right, y: top, z: z)
        points[p + 3] = OGLPoint3D(x: left, y: top, z: z)

        var xadv = g.pointee.xadv
        if atlas.pointee.isASCIIFont {
            let next = i + 1 < codepoints.count ? codepoints[i + 1] : 0
            xadv *= kern(atlas, g, next, flags)
        }

        x += glyphScale * xadv
        p += 4 // 4 more vertices
    }
}

private func getExtentsFromMetrics(_ metrics: TextMetrics) -> OGLRect {
    var rect = OGLRect()
    rect.left = metrics.lineOffsetX[0]
    rect.top = metrics.lineOffsetY[0]
    rect.right = metrics.lineOffsetX[0] + metrics.bbWidth
    rect.bottom = metrics.lineOffsetY[0] + metrics.bbHeight
    return rect
}

func TextMesh_Update(_ text: String, _ flags: Int32, _ textNode: UnsafeMutablePointer<ObjNode>) {
    let font = gAtlases[Int(textNode.pointee.Group)]!
    let codepoints = text.unicodeScalars.map(\.value)

    // Get mesh from ObjNode
    let mesh = GetQuadMeshWithin(textNode)

    // Compute number of quads and line width
    var metrics = TextMetrics()
    computeMetrics(font, codepoints, flags, &metrics)

    // Save extents
    let extents = getExtentsFromMetrics(metrics)
    textNode.pointee.LeftOff = extents.left
    textNode.pointee.TopOff = extents.top
    textNode.pointee.RightOff = extents.right
    textNode.pointee.BottomOff = extents.bottom

    // Ensure mesh has capacity for quads
    var quadCapacity = mesh.pointee.triangleCapacity / 2
    if quadCapacity < metrics.numQuads {
        quadCapacity = metrics.numQuads * 2 // avoid reallocating often if text keeps growing
        ReallocateQuadMesh(mesh, quadCapacity)
    }

    // Set # of triangles and points
    mesh.pointee.numTriangles = metrics.numQuads * 2
    mesh.pointee.numPoints = metrics.numQuads * 4

    SwGameAssert(mesh.pointee.numTriangles >= metrics.numQuads * 2)
    SwGameAssert(mesh.pointee.numPoints >= metrics.numQuads * 4)

    if metrics.numQuads == 0 {
        return
    }

    SwGameAssert(mesh.pointee.uvs.0 != nil)
    SwGameAssert(mesh.pointee.triangles != nil)
    SwGameAssert(mesh.pointee.numMaterials == 1)
    SwGameAssert(mesh.pointee.materials.0 != nil)

    // Lay out triangles
    prepVertices(font, codepoints, flags, metrics, mesh.pointee.points!, mesh.pointee.uvs.0!)
}

// MARK: - API implementation

func TextMesh_NewEmpty(_ capacity: Int32, _ newObjDef: UnsafeMutablePointer<NewObjectDefinitionType>) -> UnsafeMutablePointer<ObjNode> {
    // Patch newObjDef with bare minimum flags for TextMesh
    newObjDef.pointee.genre = UInt8(TEXTMESH_GENRE)
    newObjDef.pointee.flags |= UInt32(SwStatusBitsFor2D)

    let fontAtlasNum = Int(newObjDef.pointee.group)
    SwGameAssert(gAtlases[fontAtlasNum] != nil)
    let material = gAtlases[fontAtlasNum]!.pointee.material

    // Create mesh object
    return MakeQuadMeshObject(newObjDef, capacity, material)
}

func TextMesh_New(_ text: String, _ align: Int32, _ newObjDef: UnsafeMutablePointer<NewObjectDefinitionType>) -> UnsafeMutablePointer<ObjNode> {
    let textNode = TextMesh_NewEmpty(0, newObjDef)
    TextMesh_Update(text, align, textNode)
    return textNode
}

func TextMesh_GetExtents(_ textNode: UnsafeMutablePointer<ObjNode>) -> OGLRect {
    SwGameAssert(Int32(textNode.pointee.Genre) == Int32(TEXTMESH_GENRE))

    var rect = OGLRect()
    rect.left = textNode.pointee.Coord.x + textNode.pointee.Scale.x * textNode.pointee.LeftOff
    rect.right = textNode.pointee.Coord.x + textNode.pointee.Scale.x * textNode.pointee.RightOff
    rect.top = textNode.pointee.Coord.y + textNode.pointee.Scale.y * textNode.pointee.TopOff
    rect.bottom = textNode.pointee.Coord.y + textNode.pointee.Scale.y * textNode.pointee.BottomOff
    return rect
}

private func drawExtents(_ extents: OGLRect, _ z: Float) {
    OGL_PushState() // keep state
    OGL_DisableTexture2D()

    gEngine.renderer.setColor4f(1, 1, 1, 1)
    gEngine.renderer.beginImmediate(.lineLoop)
    gEngine.renderer.vertex3f(extents.left, extents.top, z)
    gEngine.renderer.vertex3f(extents.right, extents.top, z)
    gEngine.renderer.setColor4f(0, 0.5, 1, 1)
    gEngine.renderer.vertex3f(extents.right, extents.bottom, z)
    gEngine.renderer.vertex3f(extents.left, extents.bottom, z)
    gEngine.renderer.endImmediate()

    OGL_PopState()
}

func TextMesh_DrawExtents(_ textNode: UnsafeMutablePointer<ObjNode>) {
    SwGameAssert(Int32(textNode.pointee.Genre) == Int32(TEXTMESH_GENRE))

    OGL_PushState() // keep state
    gEngine.renderer.disableTexture2D()

    let extents = TextMesh_GetExtents(textNode)
    let z = textNode.pointee.Coord.z

    gEngine.renderer.setColor4f(1, 1, 1, 1)
    gEngine.renderer.beginImmediate(.lineLoop)
    gEngine.renderer.vertex3f(extents.left, extents.top, z)
    gEngine.renderer.vertex3f(extents.right, extents.top, z)
    gEngine.renderer.setColor4f(0, 0.5, 1, 1)
    gEngine.renderer.vertex3f(extents.right, extents.bottom, z)
    gEngine.renderer.vertex3f(extents.left, extents.bottom, z)
    gEngine.renderer.endImmediate()

    OGL_PopState()
}

func Atlas_ImmediateDraw(_ groupNum: Int32, _ text: String, _ flags: UInt32) {
    SwGameAssert(Int(groupNum) < Int(MAX_ATLASES))

    let font = gAtlases[Int(groupNum)]!
    let codepoints = text.unicodeScalars.map(\.value)

    // GET TEXT METRICS
    var metrics = TextMetrics()
    computeMetrics(font, codepoints, Int32(bitPattern: flags), &metrics)

    SwGameAssertMessage(Int(metrics.numQuads) < MAX_IMMEDIATEMODE_QUADS, "Can't draw this many quads in immediate mode!")

    prepVertices(font, codepoints, Int32(bitPattern: flags), metrics, gImmediateModePoints, gImmediateModeUVs)

    // DRAW BOUNDING RECT
    if gDebugMode >= 2 {
        let extents = getExtentsFromMetrics(metrics)
        drawExtents(extents, 0)
    }

    // ACTIVATE THE MATERIAL
    MO_DrawMaterial(font.pointee.material)

    // DRAW IT
    gEngine.renderer.beginImmediate(.quads)
    let pt = gImmediateModePoints
    let uv = gImmediateModeUVs
    var p = 0
    while p < 4 * Int(metrics.numQuads) {
        gEngine.renderer.texCoord2f(uv[p + 0].u, uv[p + 0].v); gEngine.renderer.vertex3f(pt[p + 0].x, pt[p + 0].y, 0)
        gEngine.renderer.texCoord2f(uv[p + 1].u, uv[p + 1].v); gEngine.renderer.vertex3f(pt[p + 1].x, pt[p + 1].y, 0)
        gEngine.renderer.texCoord2f(uv[p + 2].u, uv[p + 2].v); gEngine.renderer.vertex3f(pt[p + 2].x, pt[p + 2].y, 0)
        gEngine.renderer.texCoord2f(uv[p + 3].u, uv[p + 3].v); gEngine.renderer.vertex3f(pt[p + 3].x, pt[p + 3].y, 0)
        p += 4
    }
    gEngine.renderer.endImmediate()
    gPolysThisFrame += 2 * metrics.numQuads // 2 tris drawn per quad
}

func Atlas_DrawString2(
    _ groupNum: Int32,
    _ text: String,
    _ x: Float,
    _ y: Float,
    _ scaleX: Float,
    _ scaleY: Float,
    _ rot: Float,
    _ flags: UInt32
) {
    // SET STATE
    OGL_PushState() // keep state

    OGL_DisableLighting()
    OGL_DisableCullFace()
    OGL_DisableDepthTest()

    if flags & UInt32(kTextMeshGlow) != 0 {
        OGL_BlendFunc(GLenum(GL_SRC_ALPHA), GLenum(GL_ONE))
    }

    gEngine.renderer.translate(x, y, 0)
    gEngine.renderer.scale(scaleX, scaleY, 1) // Assume ortho projection

    if rot != 0 {
        gEngine.renderer.rotate(rot * 180.0 / Float(PI), 0, 0, 1) // remember: rotation is in degrees, not radians!
    }

    Atlas_ImmediateDraw(groupNum, text, flags)

    // CLEAN UP
    OGL_PopState() // restore state
}
