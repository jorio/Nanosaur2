// SmokeTest.swift - headless smoke test for the screen-saver engine build
// (ports/Darwin). Creates an offscreen CGL context + FBO, drives the same
// four C entry points the ScreenSaverView host uses (saver_api.h), and
// dumps a frame to a PPM file for visual inspection. Lets the whole
// engine path (boot -> asset load -> scene -> render loop) be exercised
// from a plain terminal, with no screen saver installation.
//
// Usage: SaverSmoke <path-to-Data-folder> <output.ppm> [numFrames]

import Foundation
import OpenGL.GL

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

let width: GLsizei = 640
let height: GLsizei = 480

// MARK: - Offscreen GL context (CGL)

var pixelFormat: CGLPixelFormatObj?
var numPixelFormats: GLint = 0
let attribs: [CGLPixelFormatAttribute] = [
    kCGLPFAAccelerated,
    kCGLPFAColorSize, CGLPixelFormatAttribute(24),
    kCGLPFADepthSize, CGLPixelFormatAttribute(24),
    CGLPixelFormatAttribute(0),
]
guard CGLChoosePixelFormat(attribs, &pixelFormat, &numPixelFormats) == kCGLNoError, let pixelFormat else {
    fail("CGLChoosePixelFormat failed")
}

var context: CGLContextObj?
guard CGLCreateContext(pixelFormat, nil, &context) == kCGLNoError, let context else {
    fail("CGLCreateContext failed")
}
CGLSetCurrentContext(context)

// MARK: - FBO as the "default framebuffer" (the engine never rebinds)

var fbo: GLuint = 0
var colorRB: GLuint = 0
var depthRB: GLuint = 0
glGenFramebuffersEXT(1, &fbo)
glBindFramebufferEXT(GLenum(GL_FRAMEBUFFER_EXT), fbo)

glGenRenderbuffersEXT(1, &colorRB)
glBindRenderbufferEXT(GLenum(GL_RENDERBUFFER_EXT), colorRB)
glRenderbufferStorageEXT(GLenum(GL_RENDERBUFFER_EXT), GLenum(GL_RGBA8), width, height)
glFramebufferRenderbufferEXT(GLenum(GL_FRAMEBUFFER_EXT), GLenum(GL_COLOR_ATTACHMENT0_EXT), GLenum(GL_RENDERBUFFER_EXT), colorRB)

glGenRenderbuffersEXT(1, &depthRB)
glBindRenderbufferEXT(GLenum(GL_RENDERBUFFER_EXT), depthRB)
glRenderbufferStorageEXT(GLenum(GL_RENDERBUFFER_EXT), GLenum(GL_DEPTH_COMPONENT24), width, height)
glFramebufferRenderbufferEXT(GLenum(GL_FRAMEBUFFER_EXT), GLenum(GL_DEPTH_ATTACHMENT_EXT), GLenum(GL_RENDERBUFFER_EXT), depthRB)

guard glCheckFramebufferStatusEXT(GLenum(GL_FRAMEBUFFER_EXT)) == GLenum(GL_FRAMEBUFFER_COMPLETE_EXT) else {
    fail("FBO incomplete")
}

// MARK: - Drive the saver entry points

print("SaverSmoke: booting engine (data: \(dataPath))")
dataPath.withCString { Nanosaur2Saver_Boot($0) }

print("SaverSmoke: starting scene")
Nanosaur2Saver_StartScene()

print("SaverSmoke: running \(numFrames) frames")
for _ in 0..<numFrames {
    Nanosaur2Saver_Frame(Int32(width), Int32(height))
    glFinish()
}

// MARK: - Read back + write PPM

var pixels = [UInt8](repeating: 0, count: Int(width) * Int(height) * 4)
glReadPixels(0, 0, width, height, GLenum(GL_RGBA), GLenum(GL_UNSIGNED_BYTE), &pixels)

var ppm = "P6\n\(width) \(height)\n255\n".data(using: .ascii)!
for row in stride(from: Int(height) - 1, through: 0, by: -1) { // GL reads bottom-up
    for col in 0..<Int(width) {
        let i = (row * Int(width) + col) * 4
        ppm.append(contentsOf: pixels[i..<i+3])
    }
}
try! ppm.write(to: URL(fileURLWithPath: outPath))
print("SaverSmoke: wrote \(outPath)")

Nanosaur2Saver_StopScene()
print("SaverSmoke: scene stopped cleanly")

// Second start/stop cycle - the system restarts animation without
// rebooting the process (System Settings preview, display sleep/wake),
// so scene teardown must leave the engine reusable.
print("SaverSmoke: second scene cycle")
Nanosaur2Saver_StartScene()
for _ in 0..<10 {
    Nanosaur2Saver_Frame(Int32(width), Int32(height))
}
Nanosaur2Saver_StopScene()
print("SaverSmoke: second cycle OK")
