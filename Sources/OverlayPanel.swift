import SwiftUI

/// Small floating HUD showing how long the current session has been running and its settings.
/// Stays on top of other windows, follows you across Spaces, and can be dragged anywhere.
@MainActor
final class OverlayPanel {
    private let panel: NSPanel

    init(caffeinator: Caffeinator) {
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 80),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false

        let host = NSHostingController(rootView: OverlayView(c: caffeinator))
        host.sizingOptions = .preferredContentSize
        panel.contentViewController = host

        // Default to the top-right corner, then remember wherever the user drags it.
        if !panel.setFrameUsingName("CaffeineOverlay"), let screen = NSScreen.main {
            let size = host.view.fittingSize
            let frame = screen.visibleFrame
            panel.setFrameOrigin(NSPoint(x: frame.maxX - size.width - 16, y: frame.maxY - size.height - 16))
        }
        panel.setFrameAutosaveName("CaffeineOverlay")
    }

    func show() { panel.orderFrontRegardless() }
    func hide() { panel.orderOut(nil) }
}

private struct OverlayView: View {
    @ObservedObject var c: Caffeinator

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "cup.and.saucer.fill")
                if let start = c.startDate {
                    Text(start, style: .timer)
                        .font(.system(.title3, design: .monospaced).weight(.semibold))
                }
            }

            Text(c.flagNames.joined(separator: " · "))
                .font(.caption)

            Group {
                if !c.trimmedUtility.isEmpty {
                    Text("Until `\(c.trimmedUtility)` exits")
                } else if let end = c.endDate {
                    Text("\(Text(end, style: .timer)) left · until \(end.formatted(date: .omitted, time: .shortened))")
                } else {
                    Text("Indefinitely")
                }
                if c.trimmedUtility.isEmpty, let pid = Int32(c.trimmedPID) {
                    Text("Until PID \(String(pid)) exits")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .lineLimit(1)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .fixedSize()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
        .contextMenu {
            Button("Hide Overlay") { c.showOverlay = false }
            Button("Turn Off Caffeine") { c.stop() }
        }
        .help("Drag to move · right-click for options")
    }
}
