import CoreGraphics

/// Pure frame arithmetic for the docked side panel. AppKit supplies the
/// visible frames; this type decides where the right-edge tab belongs and how
/// it stays inside the screen when the display is small or changes.
enum DockFrameCalculator {
    /// The dock's fixed content size. The SwiftUI content fills this exactly.
    static let defaultSize = CGSize(width: 60, height: 148)

    /// Places the dock flush with the right edge and centered vertically in
    /// `visibleFrame`. A dock larger than the display shrinks to fit instead of
    /// hanging off the edge; the visible frame already excludes the menu bar
    /// and Dock.
    static func frame(
        for size: CGSize = defaultSize,
        in visibleFrame: CGRect
    ) -> CGRect {
        let width = min(max(size.width, 0), max(visibleFrame.width, 0))
        let height = min(max(size.height, 0), max(visibleFrame.height, 0))
        return CGRect(
            x: visibleFrame.maxX - width,
            y: visibleFrame.minY + (visibleFrame.height - height) / 2,
            width: width,
            height: height
        )
    }

    /// Places the dock on the display that best matches `preferred`, which the
    /// controller supplies from `NSScreen.main`. When that display disappears,
    /// the first attached display is used so the dock never remains on a
    /// disconnected screen. No displays means no frame; the caller hides the
    /// panel.
    static func frame(
        for size: CGSize = defaultSize,
        in visibleFrames: [CGRect],
        on preferred: CGRect? = nil
    ) -> CGRect? {
        guard let target = targetVisibleFrame(
            in: visibleFrames,
            preferred: preferred
        ) else {
            return nil
        }
        return frame(for: size, in: target)
    }

    private static func targetVisibleFrame(
        in visibleFrames: [CGRect],
        preferred: CGRect?
    ) -> CGRect? {
        guard let preferred else {
            return visibleFrames.first
        }
        return visibleFrames.max { lhs, rhs in
            overlapArea(lhs, preferred) < overlapArea(rhs, preferred)
        }.flatMap { overlapArea($0, preferred) > 0 ? $0 : nil }
            ?? visibleFrames.first
    }

    private static func overlapArea(_ lhs: CGRect, _ rhs: CGRect) -> CGFloat {
        let intersection = lhs.intersection(rhs)
        guard !intersection.isNull, !intersection.isEmpty else {
            return 0
        }
        return intersection.width * intersection.height
    }
}
