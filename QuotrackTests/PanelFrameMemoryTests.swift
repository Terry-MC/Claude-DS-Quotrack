import CoreGraphics
import Foundation
import Testing

struct PanelFrameMemoryTests {
    private let mainScreen = CGRect(x: 0, y: 0, width: 1_440, height: 900)
    private let secondScreen = CGRect(x: 1_440, y: 0, width: 1_920, height: 1_080)

    @Test
    func aFrameOnScreenIsRestoredUnchanged() throws {
        let frame = CGRect(x: 200, y: 300, width: 360, height: 420)

        let restored = try #require(
            PanelFrameMemory.clamped(frame, to: [mainScreen, secondScreen])
        )

        #expect(restored == frame)
    }

    @Test
    func aFramePartlyOffscreenIsMovedBackInsideTheVisibleFrame() throws {
        let frame = CGRect(x: 1_300, y: -50, width: 360, height: 420)

        let restored = try #require(
            PanelFrameMemory.clamped(frame, to: [mainScreen])
        )

        #expect(restored.maxX <= mainScreen.maxX)
        #expect(restored.minY >= mainScreen.minY)
        #expect(restored.size == frame.size)
    }

    @Test
    func aFrameOnASecondDisplayIsClampedToThatDisplay() throws {
        let frame = CGRect(x: 3_300, y: 500, width: 360, height: 420)

        let restored = try #require(
            PanelFrameMemory.clamped(frame, to: [mainScreen, secondScreen])
        )

        #expect(restored.maxX <= secondScreen.maxX)
        #expect(restored.minX >= secondScreen.minX)
        #expect(restored.size == frame.size)
        #expect(restored.minX == secondScreen.maxX - frame.width)
    }

    @Test
    func aFrameOnNoVisibleScreenFallsBackToCentering() {
        let frame = CGRect(x: 9_000, y: 9_000, width: 360, height: 420)

        #expect(PanelFrameMemory.clamped(frame, to: [mainScreen, secondScreen]) == nil)
    }

    @Test
    func centeringUsesTheVisibleFrameNotTheFullScreen() {
        let visible = CGRect(x: 0, y: 25, width: 1_440, height: 850)

        let centered = PanelFrameMemory.centered(
            size: CGSize(width: 360, height: 420),
            in: visible
        )

        #expect(centered.midX == visible.midX)
        #expect(centered.midY == visible.midY)
    }
}
