import CoreGraphics
import Testing

struct DockFrameCalculatorTests {
    private let visibleFrame = CGRect(x: 0, y: 25, width: 1_440, height: 850)
    private let secondDisplay = CGRect(x: 1_440, y: 0, width: 1_920, height: 1_080)

    @Test
    func theDockSitsFlushWithTheRightEdgeAndCenteredVertically() {
        let size = CGSize(width: 60, height: 148)

        let frame = DockFrameCalculator.frame(for: size, in: visibleFrame)

        #expect(frame.maxX == visibleFrame.maxX)
        #expect(frame.midY == visibleFrame.midY)
        #expect(frame.size == size)
    }

    @Test
    func theDockStaysInsideAVisibleFrameOffsetByTheMenuBarAndDock() {
        let frame = DockFrameCalculator.frame(
            for: CGSize(width: 60, height: 148),
            in: visibleFrame
        )

        #expect(frame.minX >= visibleFrame.minX)
        #expect(frame.minY >= visibleFrame.minY)
        #expect(frame.maxY <= visibleFrame.maxY)
    }

    @Test
    func aDockTallerThanTheVisibleFrameShrinksToFit() {
        let shortScreen = CGRect(x: 0, y: 25, width: 800, height: 80)

        let frame = DockFrameCalculator.frame(
            for: CGSize(width: 60, height: 148),
            in: shortScreen
        )

        #expect(frame.height == shortScreen.height)
        #expect(frame.minY == shortScreen.minY)
        #expect(frame.maxY == shortScreen.maxY)
        #expect(frame.maxX == shortScreen.maxX)
    }

    @Test
    func aDockWiderThanTheVisibleFrameShrinksToFit() {
        let narrowScreen = CGRect(x: 0, y: 25, width: 40, height: 600)

        let frame = DockFrameCalculator.frame(
            for: CGSize(width: 60, height: 148),
            in: narrowScreen
        )

        #expect(frame.width == narrowScreen.width)
        #expect(frame.minX == narrowScreen.minX)
        #expect(frame.maxX == narrowScreen.maxX)
    }

    @Test
    func theDockUsesThePreferredDisplayWhenSeveralAreAttached() throws {
        let frame = try #require(
            DockFrameCalculator.frame(
                for: CGSize(width: 60, height: 148),
                in: [visibleFrame, secondDisplay],
                on: secondDisplay
            )
        )

        #expect(frame.maxX == secondDisplay.maxX)
        #expect(frame.midY == secondDisplay.midY)
        #expect(frame.minX >= secondDisplay.minX)
        #expect(frame.minY >= secondDisplay.minY)
    }

    @Test
    func aDisconnectedPreferredDisplayFallsBackToAnAttachedDisplay() throws {
        let frame = try #require(
            DockFrameCalculator.frame(
                for: CGSize(width: 60, height: 148),
                in: [visibleFrame],
                on: secondDisplay
            )
        )

        #expect(frame.maxX == visibleFrame.maxX)
        #expect(frame.midY == visibleFrame.midY)
    }

    @Test
    func noAttachedDisplaysProducesNoFrame() {
        let frame = DockFrameCalculator.frame(
            for: CGSize(width: 60, height: 148),
            in: [],
            on: visibleFrame
        )

        #expect(frame == nil)
    }
}
