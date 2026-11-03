import CoreGraphics

/// Pure geometry for the drag-to-edge dock. AppKit owns the window; this type
/// decides when a dragged panel is close enough to the screen edge to dock and
/// where it should reappear when the user clicks the dock.
enum PanelDocking {
    /// How close the panel's right edge must get to the visible frame's right
    /// edge before releasing the drag docks it.
    static let edgeThreshold: CGFloat = 12

    /// The gap left between the panel and the screen edge when it is restored,
    /// so the first user drag does not immediately dock it again.
    static let restoreInset: CGFloat = 28

    static func shouldDock(frame: CGRect, visibleFrame: CGRect) -> Bool {
        guard frame.width > 0,
              visibleFrame.width > 0,
              frame.intersects(visibleFrame) else {
            return false
        }
        return frame.maxX >= visibleFrame.maxX - edgeThreshold
    }

    /// Moves a docked panel back inside the screen. A frame that was not at the
    /// edge is returned unchanged.
    static func restoreFrame(_ frame: CGRect, in visibleFrame: CGRect) -> CGRect {
        guard shouldDock(frame: frame, visibleFrame: visibleFrame) else {
            return frame
        }
        var restored = frame
        restored.origin.x = max(
            visibleFrame.minX,
            visibleFrame.maxX - frame.width - restoreInset
        )
        return restored
    }
}
