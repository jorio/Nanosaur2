// Nanosaur2SaverView+Preview.swift - Xcode canvas preview for the saver
// view. Debug-only (see CMakeLists.txt's -DDEBUG guard on the
// Nanosaur2Saver target's Swift compile options) so it compiles to
// nothing in Release; lets the wormhole scene be inspected live in
// Xcode's canvas without installing the .saver bundle or opening System
// Settings.
//
// isPreview: true mirrors what legacyScreenSaver passes for the System
// Settings thumbnail. startAnimation() is called explicitly because the
// preview canvas only adds the view to its host window - it doesn't
// invoke ScreenSaverView's normal start/stop lifecycle on its own.

#if DEBUG

import AppKit

#Preview("Nanosaur 2 Screen Saver") {
    let view = Nanosaur2SaverView(frame: NSRect(x: 0, y: 0, width: 640, height: 480), isPreview: true)!
    view.startAnimation()
    return view
}

#endif
