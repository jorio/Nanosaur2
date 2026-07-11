// main.swift (SaverSmoke) - headless smoke test for the screen-saver
// engine build (ports/Darwin). Creates a headless CAMetalLayer (no window
// needed), drives the same C entry points the ScreenSaverView host uses
// (saver_api.h), and dumps a rendered frame to a PPM file via the
// engine's capture hooks. Lets the whole engine path (boot -> asset load
// -> scene -> Metal render loop) be exercised from a plain terminal, with
// no screen saver installation.
// (Named main.swift: Swift only allows top-level statements there.)
//
// Usage: SaverSmoke <path-to-Data-folder> <output.ppm> [numFrames]

import Foundation
import QuartzCore

func fail(_ msg: String) -> Never {
    FileHandle.standardError.write(("SaverSmoke: " + msg + "\n").data(using: .utf8)!)
    exit(1)
}

let args = CommandLine.arguments
guard args.count >= 3 else {
    fail("usage: SaverSmoke <dataPath> <out.ppm> [numFrames]")
}
let dataPath = args[1]
let outPath = args[2]
let numFrames = args.count >= 4 ? Int(args[3]) ?? 120 : 120

let width: Int32 = 640
let height: Int32 = 480

// MARK: - Headless CAMetalLayer

let metalLayer = CAMetalLayer()
metalLayer.frame = CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height))
let layerPtr = Unmanaged.passUnretained(metalLayer).toOpaque()

// MARK: - Drive the saver entry points

print("SaverSmoke: booting engine (data: \(dataPath))")
let booted = dataPath.withCString { Nanosaur2Saver_Boot($0, layerPtr, width, height) }
guard booted else {
    fail("engine boot failed (no Metal device?)")
}

print("SaverSmoke: starting scene")
Nanosaur2Saver_StartScene()

print("SaverSmoke: running \(numFrames) frames")
for i in 0..<numFrames {
    // Capture only the last frame - readback stalls the GPU every frame
    // it's enabled for.
    Nanosaur2Saver_SetCaptureEnabled(i == numFrames - 1)
    Nanosaur2Saver_Frame(width, height)
}

// MARK: - Read back + write PPM

var pixels = [UInt8](repeating: 0, count: Int(width) * Int(height) * 4)
var capturedWidth: Int32 = 0
var capturedHeight: Int32 = 0
let captured = pixels.withUnsafeMutableBufferPointer { buf in
    Nanosaur2Saver_CopyLastFrame(buf.baseAddress!, Int32(buf.count), &capturedWidth, &capturedHeight)
}
guard captured, capturedWidth == width, capturedHeight == height else {
    fail("frame capture failed (got \(capturedWidth)x\(capturedHeight))")
}

var ppm = "P6\n\(width) \(height)\n255\n".data(using: .ascii)!
for row in 0..<Int(height) { // Metal reads back top-down already
    for col in 0..<Int(width) {
        let i = (row * Int(width) + col) * 4
        ppm.append(contentsOf: [pixels[i + 2], pixels[i + 1], pixels[i + 0]]) // BGRA -> RGB
    }
}
try! ppm.write(to: URL(fileURLWithPath: outPath))
print("SaverSmoke: wrote \(outPath)")

Nanosaur2Saver_StopScene()
print("SaverSmoke: scene stopped cleanly")

// Second cycle THROUGH A LAYER HANDOFF - the system swaps views (System
// Settings thumbnail <-> full-screen preview), which rebinds the renderer
// and reloads every texture. Exercise exactly that path.
print("SaverSmoke: second cycle via AttachLayer handoff")
let metalLayer2 = CAMetalLayer()
metalLayer2.frame = CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height))
let layer2Ptr = Unmanaged.passUnretained(metalLayer2).toOpaque()
guard Nanosaur2Saver_AttachLayer(layer2Ptr, width, height) else {
    fail("AttachLayer handoff failed")
}
Nanosaur2Saver_StartScene()
for _ in 0..<10 {
    Nanosaur2Saver_Frame(width, height)
}
Nanosaur2Saver_StopScene()
print("SaverSmoke: second cycle OK")
