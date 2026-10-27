import SwiftUI

enum Theme {
    static let background = Color(red: 0.07, green: 0.07, blue: 0.08)
    static let panel = Color(red: 0.095, green: 0.095, blue: 0.105)
    static let card = Color(red: 0.13, green: 0.13, blue: 0.145)
    static let cardHover = Color(red: 0.17, green: 0.17, blue: 0.19)
    static let text = Color(red: 0.95, green: 0.94, blue: 0.92)
    static let muted = Color(red: 0.55, green: 0.55, blue: 0.58)
    static let accent = Color(red: 1.0, green: 0.30, blue: 0.24)
    static let ok = Color(red: 0.35, green: 0.85, blue: 0.55)
    static let warn = Color(red: 1.0, green: 0.78, blue: 0.28)

    static func font(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

struct SectionTitle: View {
    let title: String
    var body: some View {
        Text(title.uppercased())
            .font(Theme.font(10, .bold))
            .tracking(1.2)
            .foregroundStyle(Theme.muted)
    }
}

struct Logo: View {
    var body: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(Theme.accent)
                .frame(width: 8, height: 8)
            Text("rec")
                .font(Theme.font(17, .heavy))
        }
    }
}

struct AppIcon: View {
    let item: WindowItem
    let size: CGFloat

    var body: some View {
        if let icon = item.icon {
            Image(nsImage: icon).resizable().frame(width: size, height: size)
        } else {
            Image(systemName: "macwindow").frame(width: size, height: size)
        }
    }
}

struct Placeholder: View {
    let text: String
    var body: some View {
        Text(text)
            .font(Theme.font(12))
            .foregroundStyle(Theme.muted)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct IconButton: View {
    let symbol: String
    let help: String
    let action: () -> Void
    @Environment(\.isEnabled) private var isEnabled
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 28, height: 28)
                .foregroundStyle(hover ? Theme.text : Theme.muted)
                .background(hover ? Theme.card : .clear, in: Circle())
                .contentShape(Circle())
        }
        .onHover { hover = $0 }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(help)
        .opacity(isEnabled ? 1 : 0.4)
    }
}

struct Chip: View {
    let title: String
    let symbol: String
    @Binding var isOn: Bool
    let help: String

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: symbol).font(.system(size: 9, weight: .bold))
                Text(title).font(Theme.font(11, .semibold))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .foregroundStyle(isOn ? Theme.text : Theme.muted)
            .background(isOn ? Theme.cardHover : .clear, in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(title)
        .accessibilityValue(isOn ? "On" : "Off")
    }
}

struct BigButtonStyle: ButtonStyle {
    let fill: Color
    let foreground: Color
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.font(13, .bold))
            .foregroundStyle(foreground)
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .background(fill.opacity(configuration.isPressed ? 0.75 : 1), in: RoundedRectangle(cornerRadius: 11))
            .opacity(isEnabled ? 1 : 0.35)
            .contentShape(RoundedRectangle(cornerRadius: 11))
    }
}

struct PillButtonStyle: ButtonStyle {
    let fill: Color
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.font(11, .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(fill.opacity(configuration.isPressed ? 0.75 : 1), in: Capsule())
            .opacity(isEnabled ? 1 : 0.4)
            .contentShape(Capsule())
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        let height = rows.last.map { $0.y + $0.height } ?? 0
        return CGSize(width: proposal.width ?? rows.map(\.width).max() ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for row in arrange(width: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: bounds.minY + row.y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
        }
    }

    private struct Row {
        var indices: [Int] = []
        var y: CGFloat = 0
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = [Row()]
        for (index, subview) in subviews.enumerated() {
            let size = subview.sizeThatFits(.unspecified)
            var row = rows[rows.count - 1]
            if !row.indices.isEmpty && row.width + spacing + size.width > width {
                row = Row(y: row.y + row.height + spacing)
                rows.append(row)
            }
            row.width += (row.indices.isEmpty ? 0 : spacing) + size.width
            row.height = max(row.height, size.height)
            row.indices.append(index)
            rows[rows.count - 1] = row
        }
        return rows
    }
}
