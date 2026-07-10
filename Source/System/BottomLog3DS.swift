// BottomLog3DS.swift - the 3DS DebugLog console, rendered on the bottom
// screen with the game's own font via SDL software blits (never libctru's
// built-in console, and never any GL - the bottom screen shows images
// only, see OGL_Support.swift's 3DS dual-screen comments).
//
// DebugLog itself is implemented HERE in Swift (@c @implementation against
// game_3ds.h's declaration, so C callers like main.cpp's heap print still
// link against it): each line goes to the SD-card log file immediately
// (via console_shim.c's DebugLogFile3DS, so a crash can't eat it), into a
// small ring buffer, and the whole buffer is redrawn onto the bottom
// screen. Lines logged before the bottom window or the font exist are
// buffered and appear once they do.
//
// Everything here only exists under -DDEBUGLOG (same flag as every
// DebugLog call site); without it the bottom screen belongs to
// dual-screen mode instead (menu background/minimap).

#if NANOSAUR_3DS && DEBUGLOG

private struct LogGlyph {
    var x: Float = 0
    var y: Float = 0
    var w: Float = 0
    var h: Float = 0
    var xoff: Float = 0
    var yoff: Float = 0
    var xadv: Float = 0
}

private let kMaxLogLines = 16
private let kLogScale: Float = 0.20 // game font lineHeight is ~64px; ~13px rows fit 16 lines in 240px

private var gLogLines: [String] = []
private var gLogFontSurface: UnsafeMutablePointer<SDL_Surface>?
private var gLogGlyphs = [LogGlyph](repeating: LogGlyph(), count: 128)
private var gLogFontLineHeight: Float = 64
private var gLogFontLoadAttempted = false
private var gLogRendering = false // reentrancy guard (SDL calls in here must not recurse via the SDL_Log hook)

@c @implementation
public func DebugLog(_ message: UnsafePointer<CChar>?) {
    guard let message else { return }

    DebugLogFile3DS(message) // SD-card log file, unconditionally and first

    gLogLines.append(String(cString: message))
    if gLogLines.count > kMaxLogLines {
        gLogLines.removeFirst(gLogLines.count - kMaxLogLines)
    }

    renderBottomLog3DS()
}

private func loadLogFont3DS() {
    gLogFontLoadAttempted = true

    // METRICS (same format Atlas.swift parses: header "nGlyphs lineHeight
    // name", then per glyph "codepoint x y w h xoff yoff xadv yadv NAME")

    var length = 0
    guard let txtData = LoadDataFile(":Sprites:fonts:font.txt", &length) else { return }
    defer { SafeDisposePtr(UnsafeMutableRawPointer(txtData)) }

    let fullText = String(cString: UnsafeRawPointer(txtData).assumingMemoryBound(to: CChar.self))
    var lines = fullText.split(separator: "\n", omittingEmptySubsequences: false)[...]

    func nextLineFields() -> [Substring]? {
        guard let line = lines.first else { return nil }
        lines = lines.dropFirst()
        return line.split(whereSeparator: { $0 == " " || $0 == "\t" || $0 == "\r" })
    }

    guard let header = nextLineFields(), header.count >= 2,
          let nGlyphs = Int(header[0]), let lineHeight = Float(header[1]) else { return }
    gLogFontLineHeight = lineHeight

    for _ in 0..<nGlyphs {
        guard let f = nextLineFields(), f.count >= 9,
              let cp = UInt32(f[0]),
              let x = Float(f[1]), let y = Float(f[2]),
              let w = Float(f[3]), let h = Float(f[4]),
              let xoff = Float(f[5]), let yoff = Float(f[6]),
              let xadv = Float(f[7]) else { continue }
        if cp < 128 {
            gLogGlyphs[Int(cp)] = LogGlyph(x: x, y: y, w: w, h: h, xoff: xoff, yoff: yoff, xadv: xadv)
        }
    }

    // IMAGE (white glyphs on transparent - alpha blends over the dark fill)

    gLogFontSurface = LoadSDLSurface3DS(":Sprites:fonts:font")
}

private func renderBottomLog3DS() {
    guard !gLogRendering else { return }
    guard let window2 = gSDLWindow2 else { return } // too early - lines stay buffered

    gLogRendering = true
    defer { gLogRendering = false }

    if !gLogFontLoadAttempted {
        loadLogFont3DS()
    }

    guard let winSurf = SDL_GetWindowSurface(window2) else { return }

    _ = SDL_FillSurfaceRect(winSurf, nil, SDL_MapSurfaceRGB(winSurf, 8, 8, 24))

    if let font = gLogFontSurface {
        let lineH = Int32(gLogFontLineHeight * kLogScale) + 1
        var y: Int32 = 2
        for line in gLogLines {
            drawLogLine3DS(line, x0: 2, y0: y, dst: winSurf, font: font)
            y += lineH
        }
    }

    _ = SDL_UpdateWindowSurface(window2)
}

private func drawLogLine3DS(_ text: String, x0: Int32, y0: Int32, dst: UnsafeMutablePointer<SDL_Surface>, font: UnsafeMutablePointer<SDL_Surface>) {
    var penX = Float(x0)

    for scalar in text.unicodeScalars {
        var cp = scalar.value
        if cp >= 97 && cp <= 122 { cp -= 32 } // a-z -> A-Z: the game font is uppercase-only

        if cp >= 128 || (gLogGlyphs[Int(cp)].w <= 0 && gLogGlyphs[Int(cp)].xadv <= 0) {
            penX += 12 * kLogScale // unknown glyph: small gap
            continue
        }

        let g = gLogGlyphs[Int(cp)]
        if g.w > 0 { // SPACE has w=0 but a real xadv
            var src = SDL_Rect(x: Int32(g.x), y: Int32(g.y), w: Int32(g.w), h: Int32(g.h))
            var dstR = SDL_Rect(
                x: Int32(penX + g.xoff * kLogScale),
                y: y0 + Int32(g.yoff * kLogScale),
                w: max(1, Int32(g.w * kLogScale)),
                h: max(1, Int32(g.h * kLogScale)))
            _ = SDL_BlitSurfaceScaled(font, &src, dst, &dstR, SDL_SCALEMODE_NEAREST)
        }
        penX += g.xadv * kLogScale

        if penX >= 318 { break } // clip to the bottom screen's width
    }
}

#endif // NANOSAUR_3DS && DEBUGLOG
