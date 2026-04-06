//
//  ExpandedDashboardWindow.swift
//  boringNotch
//

import Cocoa
import SwiftUI

class ExpandedDashboardWindow: NSPanel {
    static let shared = ExpandedDashboardWindow()

    private static let panelWidth: CGFloat = 500
    private static let panelHeight: CGFloat = 480

    private init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: Self.panelWidth, height: Self.panelHeight),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isMovableByWindowBackground = true
        hidesOnDeactivate = false
        // Above the notch window (mainMenu + 3) so it's always visible
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.maximumWindow)) - 1)
        isReleasedWhenClosed = false
        appearance = NSAppearance(named: .darkAqua)
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]

        let hostingView = NSHostingView(rootView: ExpandedDashboardView())
        hostingView.wantsLayer = true
        hostingView.layer?.cornerRadius = 16
        hostingView.layer?.masksToBounds = true
        contentView = hostingView
    }

    func toggle() {
        if isVisible {
            close()
        } else {
            show()
        }
    }

    private func show() {
        // Position below the notch on the screen that has the notch window
        let screen = NSScreen.screens.first(where: { $0.frame.maxY == NSScreen.screens.map(\.frame.maxY).max() })
                     ?? NSScreen.main
                     ?? NSScreen.screens[0]
        let screenFrame = screen.frame
        let notchBottom = screenFrame.maxY - openNotchSize.height - 6

        let x = screenFrame.midX - Self.panelWidth / 2
        let y = notchBottom - Self.panelHeight

        setFrameOrigin(NSPoint(x: x, y: y))
        orderFrontRegardless()
        makeKey()
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        return frameRect
    }
}
