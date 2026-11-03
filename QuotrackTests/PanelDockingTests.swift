import CoreGraphics
import Testing

struct PanelDockingTests {
    private let visibleFrame = CGRect(x: 0, y: 0, width: 1440, height: 900)

    @Test
    func aPanelWhoseRightEdgeTouchesTheScreenEdgeDocks() {
        let frame = CGRect(x: 980, y: 100, width: 460, height: 640)

        #expect(
            PanelDocking.shouldDock(
                frame: frame,
                visibleFrame: visibleFrame
            )
        )
    }

    @Test
    func aPanelWithinTheThresholdDocks() {
        let frame = CGRect(x: 968, y: 100, width: 460, height: 640)

        #expect(
            PanelDocking.shouldDock(
                frame: frame,
                visibleFrame: visibleFrame
            )
        )
    }

    @Test
    func aPanelFurtherFromTheEdgeDoesNotDock() {
        let frame = CGRect(x: 960, y: 100, width: 460, height: 640)

        #expect(
            !PanelDocking.shouldDock(
                frame: frame,
                visibleFrame: visibleFrame
            )
        )
    }

    @Test
    func aPanelOnAnotherDisplayDoesNotDock() {
        let otherDisplay = CGRect(x: 1440, y: 0, width: 1440, height: 900)
        let frame = CGRect(x: 980, y: 100, width: 460, height: 640)

        #expect(
            !PanelDocking.shouldDock(
                frame: frame,
                visibleFrame: otherDisplay
            )
        )
    }

    @Test
    func restoringADockedPanelLeavesAnInsetFromTheEdge() {
        let frame = CGRect(x: 990, y: 100, width: 460, height: 640)

        let restored = PanelDocking.restoreFrame(frame, in: visibleFrame)

        #expect(restored.width == frame.width)
        #expect(restored.height == frame.height)
        #expect(restored.maxX == visibleFrame.maxX - PanelDocking.restoreInset)
        #expect(!PanelDocking.shouldDock(frame: restored, visibleFrame: visibleFrame))
    }

    @Test
    func restoringANonDockedPanelLeavesItAlone() {
        let frame = CGRect(x: 200, y: 100, width: 460, height: 640)

        #expect(
            PanelDocking.restoreFrame(frame, in: visibleFrame) == frame
        )
    }
}
