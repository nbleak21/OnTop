import CoreVideo
import Foundation
import os

/// Frames-per-second actually presented on the display, measured with a
/// CVDisplayLink (one callback per vsync). On a fixed 60 Hz display this reads
/// ~60; on a ProMotion display it tracks the live adaptive refresh rate. This
/// is the display's real frame cadence, not any single app's render rate.
final class FPSReader: StatReader {
    let id = "fps"
    let name = "FPS"
    let symbolName = "speedometer"

    private var link: CVDisplayLink?
    private let frames = OSAllocatedUnfairLock(initialState: UInt64(0))
    private var lastFrames: UInt64 = 0
    private var lastTime = Date()
    private var available = false

    init() {
        var created: CVDisplayLink?
        guard CVDisplayLinkCreateWithActiveCGDisplays(&created) == kCVReturnSuccess, let created else {
            return
        }
        link = created

        let context = Unmanaged.passUnretained(self).toOpaque()
        CVDisplayLinkSetOutputCallback(created, { _, _, _, _, _, ctx in
            if let ctx {
                Unmanaged<FPSReader>.fromOpaque(ctx).takeUnretainedValue()
                    .frames.withLock { $0 &+= 1 }
            }
            return kCVReturnSuccess
        }, context)

        CVDisplayLinkStart(created)
        available = true
        lastTime = Date()
    }

    deinit {
        if let link {
            CVDisplayLinkStop(link)
        }
    }

    func sample() -> StatReading {
        guard available else {
            return StatReading(barText: "—", menuValue: "unavailable")
        }

        let current = frames.withLock { $0 }
        let now = Date()
        let elapsed = now.timeIntervalSince(lastTime)

        // Skip the first, near-zero window so we don't report a spike.
        guard elapsed >= 0.3 else {
            return StatReading(barText: "–", menuValue: "measuring…")
        }

        let fps = Double(current - lastFrames) / elapsed
        lastFrames = current
        lastTime = now

        return StatReading(
            barText: String(format: "%.0f", fps),
            menuValue: String(format: "%.0f fps  ·  display refresh", fps)
        )
    }
}
