import CoreGraphics
import Foundation

/// Pure frame arithmetic for restoring the floating panel. AppKit supplies
/// the visible frames; this type decides whether a saved frame is still on a
/// display and how to pull it back inside one.
enum PanelFrameMemory {
    /// The autosave key AppKit uses to persist the panel frame across launches.
    static let autosaveName = "QuotrackPanel"

    /// Returns the saved frame clamped inside the visible frame of the display
    /// it belongs to, or `nil` when it is no longer on any visible display.
    static func clamped(_ frame: CGRect, to visibleFrames: [CGRect]) -> CGRect? {
        guard let screen = bestScreen(for: frame, in: visibleFrames) else {
            return nil
        }
        let maxX = max(screen.minX, screen.maxX - frame.width)
        let maxY = max(screen.minY, screen.maxY - frame.height)
        return CGRect(
            x: min(max(frame.minX, screen.minX), maxX),
            y: min(max(frame.minY, screen.minY), maxY),
            width: frame.width,
            height: frame.height
        )
    }

    /// Centers a window of `size` inside a visible frame, which excludes the
    /// menu bar and Dock.
    static func centered(size: CGSize, in visibleFrame: CGRect) -> CGRect {
        CGRect(
            x: visibleFrame.midX - size.width / 2,
            y: visibleFrame.midY - size.height / 2,
            width: size.width,
            height: size.height
        )
    }

    /// A frame can straddle displays. The one with the largest overlap owns
    /// the window so clamping never teleports it to another display.
    private static func bestScreen(
        for frame: CGRect,
        in visibleFrames: [CGRect]
    ) -> CGRect? {
        visibleFrames
            .map { screen in (screen, screen.intersection(frame)) }
            .filter { !$0.1.isNull && !$0.1.isEmpty }
            .max { lhs, rhs in
                lhs.1.width * lhs.1.height < rhs.1.width * rhs.1.height
            }?
            .0
    }
}
