import RecCore
import SwiftUI

struct MainView: View {
    var body: some View {
        HStack(spacing: 0) {
            BrowserPane()
            InspectorPane().frame(width: 320)
        }
        .frame(minWidth: 860, minHeight: 600)
        .foregroundStyle(Theme.text)
        .environment(\.colorScheme, .dark)
    }
}

// MARK: - Window browser

private struct BrowserPane: View {
    @EnvironmentObject var model: AppModel
    @State private var query = ""

    private var filtered: [WindowItem] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return model.windows }
        return model.windows.filter {
            $0.title.localizedCaseInsensitiveContains(q) || $0.appName.localizedCaseInsensitiveContains(q)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Logo()
                Text("Pick a window to record")
                    .font(Theme.font(13))
                    .foregroundStyle(Theme.muted)
                Spacer()
                SearchField(text: $query)
                    .frame(width: 220)
                IconButton(symbol: "arrow.clockwise", help: "Refresh windows") {
                    Task { await model.refreshWindows() }
                }
                IconButton(symbol: "folder", help: "Open recordings folder") {
                    model.openRecordingsFolder()
                }
            }
            .disabled(!model.screenGranted)
            .padding(.horizontal, 20)
            .padding(.bottom, 12)

            if !model.screenGranted {
                Onboarding()
            } else if filtered.isEmpty {
                Placeholder(text: model.windows.isEmpty ? "No windows found" : "No windows match “\(query)”")
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 210), spacing: 14)], spacing: 14) {
                        ForEach(filtered) { item in
                            // A real Button, so selecting a window also works through Accessibility (AXPress).
                            Button {
                                model.selection = item.id
                            } label: {
                                WindowCard(item: item, image: model.thumbnails[item.id], selected: model.selection == item.id)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(item.appName), \(item.title)")
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background.ignoresSafeArea())
    }
}

private struct SearchField: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.muted)
            TextField("Search apps or titles", text: $text)
                .textFieldStyle(.plain)
                .font(Theme.font(12))
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.muted)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 28)
        .background(Theme.card, in: Capsule())
    }
}

private struct Onboarding: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "rectangle.dashed.badge.record")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(Theme.accent)
            Text("Let rec see your windows")
                .font(Theme.font(20, .heavy))
            VStack(spacing: 8) {
                PermissionRow(title: "Screen Recording", symbol: "rectangle.dashed.badge.record",
                              detail: "Lists your windows and records the one you pick. Nothing else on your screen is captured.",
                              granted: model.screenGranted) { model.requestScreenRecording() }
                PermissionRow(title: "Accessibility", symbol: "hand.raised.fill",
                              detail: "Resizes the window to fit the video. Optional: without it rec still records.",
                              granted: model.accessibilityGranted) { model.requestAccessibility() }
            }
            .frame(maxWidth: 420)
            Text("If macOS asks you to quit and reopen rec, do that and you'll land back here.")
                .font(Theme.font(11))
                .foregroundStyle(Theme.muted)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct PermissionRow: View {
    let title: String
    let symbol: String
    let detail: String
    let granted: Bool
    let allow: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 16))
                .foregroundStyle(Theme.accent)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(Theme.font(13, .semibold))
                Text(detail)
                    .font(Theme.font(11))
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            if granted {
                Label("Allowed", systemImage: "checkmark.circle.fill")
                    .font(Theme.font(11, .semibold))
                    .foregroundStyle(Theme.ok)
            } else {
                Button("Allow", action: allow)
                    .buttonStyle(PillButtonStyle(fill: Theme.accent))
                    .accessibilityLabel("Allow \(title)")
            }
        }
        .padding(12)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 10))
    }
}

private struct WindowCard: View {
    let item: WindowItem
    let image: NSImage?
    let selected: Bool
    @State private var hover = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topTrailing) {
                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ProgressView().controlSize(.small)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.white, Theme.accent)
                        .padding(6)
                }
            }
            .frame(height: 150)
            HStack(spacing: 8) {
                AppIcon(item: item, size: 20)
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.title).font(Theme.font(12, .semibold)).lineLimit(1)
                    Text("\(item.appName) · \(Int(item.window.frame.width))×\(Int(item.window.frame.height))")
                        .font(Theme.font(10.5).monospacedDigit())
                        .foregroundStyle(Theme.muted)
                        .lineLimit(1)
                }
            }
        }
        .padding(10)
        .contentShape(Rectangle())
        .background(selected ? Theme.accent.opacity(0.12) : (hover ? Theme.card : .clear), in: RoundedRectangle(cornerRadius: 12))
        .onHover { hover = $0 }
    }
}

// MARK: - Inspector

private struct InspectorPane: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 8) {
                        SectionTitle(title: "Video size")
                        VStack(spacing: 2) {
                            ForEach(VideoPreset.all) { preset in
                                PresetRow(preset: preset, selected: model.preset == preset)
                                    .onTapGesture { model.preset = preset }
                                    .accessibilityAddTraits(.isButton)
                                    .accessibilityLabel(preset.name)
                            }
                        }
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        SectionTitle(title: "Preview")
                        OutputPreview()
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        SectionTitle(title: "Options")
                        Options()
                    }
                    if model.screenGranted && !model.accessibilityGranted {
                        AccessibilityBanner()
                    }
                    if model.lastRecording != nil {
                        LastRecordingCard()
                    }
                }
                .padding(20)
            }
            .scrollIndicators(.never)
            ActionBar().padding(.horizontal, 20).padding(.vertical, 16)
        }
        .background(Theme.panel.ignoresSafeArea())
    }
}

private struct PresetRow: View {
    let preset: VideoPreset
    let selected: Bool
    @State private var hover = false

    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 2.5)
                .strokeBorder(selected ? Theme.accent : Theme.muted.opacity(0.6), lineWidth: 1.2)
                .aspectRatio(preset.aspectRatio, contentMode: .fit)
                .frame(width: 22, height: 22)
            Text(preset.name).font(Theme.font(12.5, .semibold))
            Spacer()
            Text(preset.sizeLabel)
                .font(Theme.font(11).monospacedDigit())
                .foregroundStyle(Theme.muted)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .foregroundStyle(selected ? Theme.text : Theme.muted)
        .background(selected ? Theme.card : (hover ? Theme.card.opacity(0.5) : .clear), in: RoundedRectangle(cornerRadius: 8))
        .onHover { hover = $0 }
    }
}

/// What the video frame will look like if recording starts with the window as it is now.
private struct OutputPreview: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        let preset = model.preset
        VStack(alignment: .leading, spacing: 8) {
            Color.black
                .aspectRatio(preset.aspectRatio, contentMode: .fit)
                .overlay {
                    if let item = model.selectedItem, let image = model.thumbnails[item.id] {
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: model.selectionMatchesPreset || model.cropToFill ? .fill : .fit)
                    } else {
                        Text("Select a window")
                            .font(Theme.font(11))
                            .foregroundStyle(Theme.muted)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .frame(maxWidth: .infinity, maxHeight: 200)

            HStack(spacing: 6) {
                Text("\(preset.sizeLabel) · \(preset.ratioLabel)")
                    .font(Theme.font(11).monospacedDigit())
                    .foregroundStyle(Theme.muted)
                Spacer()
                PreviewBadge()
            }
        }
    }
}

private struct PreviewBadge: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        if model.selectedItem == nil {
            EmptyView()
        } else if model.selectionMatchesPreset {
            badge("Window fits", symbol: "checkmark.circle.fill", color: Theme.ok)
        } else if model.fitBeforeRecording && model.accessibilityGranted {
            badge("Resizes on record", symbol: "aspectratio", color: Theme.muted)
        } else {
            badge(model.cropToFill ? "Cropped" : "Black bars", symbol: "exclamationmark.triangle.fill", color: Theme.warn)
        }
    }

    private func badge(_ text: String, symbol: String, color: Color) -> some View {
        Label(text, systemImage: symbol)
            .font(Theme.font(11, .semibold))
            .foregroundStyle(color)
    }
}

private struct Options: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        FlowLayout(spacing: 6) {
            Chip(title: "Fit on record", symbol: "aspectratio", isOn: $model.fitBeforeRecording,
                 help: "Resize the window to the video ratio when recording starts")
            Chip(title: "2× Retina", symbol: "sparkles", isOn: $model.useRetina2x,
                 help: "On: one window point becomes 2 video pixels (larger UI). Off: one point becomes one pixel (window twice as large, more fits).")
            Chip(title: "Crop to fill", symbol: "crop", isOn: $model.cropToFill,
                 help: "If the app won't resize to the video ratio, record a centered crop instead of adding black bars")
            Chip(title: "Cursor", symbol: "cursorarrow", isOn: $model.showsCursor, help: "Show the mouse cursor")
            Chip(title: "Audio", symbol: "speaker.wave.2", isOn: $model.captureAudio, help: "Record system audio")
        }
        VStack(alignment: .leading, spacing: 6) {
            Text("Countdown")
                .font(Theme.font(11, .semibold))
                .foregroundStyle(Theme.muted)
            HStack(spacing: 6) {
                ForEach([0, 3, 5, 10], id: \.self) { seconds in
                    CountdownChoice(seconds: seconds, selection: $model.countdownSeconds)
                }
            }
        }
        .padding(.top, 4)
    }
}

private struct CountdownChoice: View {
    let seconds: Int
    @Binding var selection: Int

    var body: some View {
        let isOn = Binding<Bool>(get: { selection == seconds }, set: { _ in selection = seconds })
        if seconds == 0 {
            Chip(title: "Off", symbol: "xmark", isOn: isOn, help: "Start recording right away")
        } else {
            Chip(title: "\(seconds)s", symbol: "timer", isOn: isOn, help: "\(seconds)-second countdown before recording")
        }
    }
}

private struct AccessibilityBanner: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "hand.raised.fill").foregroundStyle(Theme.warn)
            VStack(alignment: .leading, spacing: 6) {
                Text("Allow Accessibility to resize windows")
                    .font(Theme.font(12, .semibold))
                Text("Without it rec can still record, but can't fit the window to the video size.")
                    .font(Theme.font(11))
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Allow") { model.requestAccessibility() }
                    .buttonStyle(PillButtonStyle(fill: Theme.accent))
            }
        }
        .padding(12)
        .background(Theme.warn.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }
}

private struct LastRecordingCard: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle(title: "Last recording")
            HStack(spacing: 10) {
                Image(systemName: "film.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Theme.accent)
                Text(model.lastRecording?.deletingPathExtension().lastPathComponent ?? "")
                    .font(Theme.font(12, .medium))
                    .lineLimit(2)
                    .truncationMode(.middle)
                Spacer(minLength: 0)
            }
            HStack(spacing: 6) {
                Button("Play") { model.openLastRecording() }
                    .buttonStyle(PillButtonStyle(fill: Theme.accent))
                Button("Show in Finder") { model.revealLastRecording() }
                    .buttonStyle(PillButtonStyle(fill: Theme.cardHover))
            }
        }
        .padding(12)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 10))
    }
}

private struct ActionBar: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        let ready = model.selectedItem != nil
        VStack(alignment: .leading, spacing: 10) {
            if let status = model.status {
                Text(status)
                    .font(Theme.font(11))
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
            HStack(spacing: 8) {
                Button {
                    model.fitWindow()
                } label: {
                    Label("Fit", systemImage: "aspectratio").frame(maxWidth: .infinity)
                }
                .buttonStyle(BigButtonStyle(fill: Theme.card, foreground: Theme.text))
                .frame(width: 92)
                .help("Resize the window to the video ratio now")
                .disabled(!ready || model.isBusy)

                Button {
                    model.startRecording()
                } label: {
                    HStack(spacing: 6) {
                        Circle().fill(.white).frame(width: 9, height: 9)
                        Text("Record")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(BigButtonStyle(fill: Theme.accent, foreground: .white))
                .keyboardShortcut(.defaultAction)
                .disabled(!ready || model.isBusy)
            }
        }
    }
}
