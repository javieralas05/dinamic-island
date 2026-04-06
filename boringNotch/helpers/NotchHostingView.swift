//
//  NotchHostingView.swift
//  boringNotch
//

import AppKit
import SwiftUI

/// NSHostingView subclass that overrides safeAreaInsets to zero.
/// Required so the notch content renders flush against the physical notch,
/// without macOS pushing the content down by the notch safe area height.
class NotchHostingView<Content: View>: NSHostingView<Content> {
    override var safeAreaInsets: NSEdgeInsets {
        .init()
    }
}
