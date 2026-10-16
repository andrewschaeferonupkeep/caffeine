import SwiftUI
import ServiceManagement

// MARK: - Model

enum TimeoutOption: Int, CaseIterable, Identifiable {
    case none = 0, m15 = 900, m30 = 1800, h1 = 3600, h2 = 7200, h4 = 14400, h8 = 28800, custom = -1

    var id: Int { rawValue }
    var label: String {
        switch self {
        case .none: return "Indefinitely"
        case .m15: return "15 minutes"
        case .m30: return "30 minutes"
        case .h1: return "1 hour"
        case .h2: return "2 hours"
        case .h4: return "4 hours"
        case .h8: return "8 hours"
        case .custom: return "Custom…"
        }
    }
}

@MainActor
final class Caffeinator: ObservableObject {
    // Persisted options
    @AppStorage("flagDisplay") var display = true      // -d
    @AppStorage("flagIdle") var idle = true            // -i
    @AppStorage("flagDisk") var disk = false           // -m
    @AppStorage("flagSystem") var system = false       // -s
    @AppStorage("flagUser") var user = false           // -u
    @AppStorage("timeout") var timeoutRaw = TimeoutOption.none.rawValue
    @AppStorage("customMinutes") var customMinutes = 90
    @AppStorage("waitPID") var waitPID = ""            // -w
    @AppStorage("utility") var utility = ""            // trailing utility args

    @Published private(set) var isActive = false
    @Published private(set) var endDate: Date?
    @Published var lastError: String?

    private var process: Process?

    var timeout: TimeoutOption {
        get { TimeoutOption(rawValue: timeoutRaw) ?? .none }
        set { timeoutRaw = newValue.rawValue; objectWillChange.send() }
    }

    var timeoutSeconds: Int? {
        switch timeout {
        case .none: return nil
        case .custom: return max(1, customMinutes) * 60
        default: return timeout.rawValue
        }
    }

    var trimmedUtility: String { utility.trimmingCharacters(in: .whitespacesAndNewlines) }
    var trimmedPID: String { waitPID.trimmingCharacters(in: .whitespaces) }

    /// Arguments passed to /usr/bin/caffeinate.
    var arguments: [String] {
        var args: [String] = []
        let flags = (display ? "d" : "") + (idle ? "i" : "") + (disk ? "m" : "")
            + (system ? "s" : "") + (user ? "u" : "")
        if !flags.isEmpty { args.append("-" + flags) }

        if trimmedUtility.isEmpty {
            if let secs = timeoutSeconds { args += ["-t", String(secs)] }
            // Without a user-supplied PID, tie caffeinate to this app so it never outlives us.
            let pid = Int32(trimmedPID) ?? ProcessInfo.processInfo.processIdentifier
            args += ["-w", String(pid)]
        } else {
            // caffeinate ignores -t and -w when running a utility.
            args += ["/bin/sh", "-c", trimmedUtility]
        }
        return args
    }

    var commandPreview: String {
        var shown = arguments
        // Hide the implicit "-w <our pid>" from the preview; it's an implementation detail.
        if trimmedUtility.isEmpty && Int32(trimmedPID) == nil, let i = shown.firstIndex(of: "-w") {
            shown.removeSubrange(i...i + 1)
        }
        return (["caffeinate"] + shown.map { $0.contains(" ") ? "'\($0)'" : $0 }).joined(separator: " ")
    }

    var pidIsInvalid: Bool { !trimmedPID.isEmpty && Int32(trimmedPID) == nil }

    func toggle() { isActive ? stop() : start() }

    func start() {
        guard !isActive else { return }
        lastError = nil
        if pidIsInvalid { lastError = "PID must be a number."; return }

        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/caffeinate")
        p.arguments = arguments
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        p.terminationHandler = { [weak self] proc in
            Task { @MainActor in
                guard let self, self.process === proc else { return }
                self.process = nil
                self.isActive = false
                self.endDate = nil
            }
        }
        do {
            try p.run()
            process = p
            isActive = true
            endDate = trimmedUtility.isEmpty ? timeoutSeconds.map { Date().addingTimeInterval(TimeInterval($0)) } : nil
        } catch {
            lastError = "Failed to start caffeinate: \(error.localizedDescription)"
        }
    }

    func stop() {
        guard let p = process else { return }
        process = nil
        if p.isRunning { p.terminate() }
        isActive = false
        endDate = nil
    }

    /// Restart with new options if currently running.
    func applyChanges() {
        guard isActive else { return }
        stop()
        start()
    }
}

// MARK: - App

@main
struct CaffeineApp: App {
    @StateObject private var caffeinator = Caffeinator()

    var body: some Scene {
        MenuBarExtra {
            MenuContent(c: caffeinator)
        } label: {
            Image(systemName: caffeinator.isActive ? "cup.and.saucer.fill" : "cup.and.saucer")
        }
        .menuBarExtraStyle(.window)
    }
}

struct MenuContent: View {
    @ObservedObject var c: Caffeinator
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            Divider()
            assertions
            Divider()
            duration
            Divider()
            advanced
            Divider()
            footer
        }
        .padding(14)
        .frame(width: 300)
        .onChange(of: c.display) { _ in c.applyChanges() }
        .onChange(of: c.idle) { _ in c.applyChanges() }
        .onChange(of: c.disk) { _ in c.applyChanges() }
        .onChange(of: c.system) { _ in c.applyChanges() }
        .onChange(of: c.user) { _ in c.applyChanges() }
        .onChange(of: c.timeoutRaw) { _ in c.applyChanges() }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Caffeine").font(.headline)
                if c.isActive {
                    if let end = c.endDate {
                        (Text("Until \(end.formatted(date: .omitted, time: .shortened)) · ")
                            + Text(end, style: .timer))
                            .font(.caption).foregroundStyle(.secondary)
                    } else {
                        Text("Awake").font(.caption).foregroundStyle(.secondary)
                    }
                } else {
                    Text("Off").font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Toggle("", isOn: Binding(get: { c.isActive }, set: { _ in c.toggle() }))
                .toggleStyle(.switch)
                .labelsHidden()
        }
    }

    private var assertions: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Prevent").font(.subheadline).bold()
            Toggle("Display sleep  (-d)", isOn: $c.display)
            Toggle("System idle sleep  (-i)", isOn: $c.idle)
            Toggle("Disk idle sleep  (-m)", isOn: $c.disk)
            Toggle("System sleep, AC only  (-s)", isOn: $c.system)
            Toggle("Declare user active  (-u)", isOn: $c.user)
            if !(c.display || c.idle || c.disk || c.system || c.user) {
                Text("No flags: caffeinate defaults to preventing idle sleep.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .toggleStyle(.checkbox)
    }

    private var duration: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Duration  (-t)").font(.subheadline).bold()
            Picker("", selection: Binding(get: { c.timeout }, set: { c.timeout = $0 })) {
                ForEach(TimeoutOption.allCases) { Text($0.label).tag($0) }
            }
            .labelsHidden()
            if c.timeout == .custom {
                HStack {
                    TextField("Minutes", value: $c.customMinutes, format: .number)
                        .frame(width: 70)
                        .onSubmit { c.applyChanges() }
                    Text("minutes").foregroundStyle(.secondary)
                }
            }
            if !c.trimmedUtility.isEmpty {
                Text("Ignored while running a command.").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var advanced: some View {
        DisclosureGroup("Advanced") {
            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Wait for PID  (-w)").font(.caption)
                    TextField("Process ID (optional)", text: $c.waitPID)
                        .onSubmit { c.applyChanges() }
                    if c.pidIsInvalid {
                        Text("Must be a number.").font(.caption).foregroundStyle(.red)
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Run command (stays awake until it exits)").font(.caption)
                    TextField("e.g. make build", text: $c.utility)
                        .onSubmit { c.applyChanges() }
                }
            }
            .padding(.top, 6)
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(c.commandPreview)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
            if let err = c.lastError {
                Text(err).font(.caption).foregroundStyle(.red)
            }
            HStack {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .toggleStyle(.checkbox)
                    .onChange(of: launchAtLogin) { on in
                        do {
                            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
                        } catch {
                            c.lastError = "Launch at login: \(error.localizedDescription)"
                            launchAtLogin = SMAppService.mainApp.status == .enabled
                        }
                    }
                Spacer()
                Button("Quit") {
                    c.stop()
                    NSApp.terminate(nil)
                }
            }
        }
    }
}
