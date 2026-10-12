import SwiftUI

/// A card with a title, an optional explanation and its content.
struct SectionCard<Content: View>: View {
    let title: String
    let description: String?
    @ViewBuilder let content: () -> Content

    init(_ title: String, _ description: String? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.description = description
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline).foregroundColor(Theme.ink)
            if let description { Text(description).font(.subheadline).foregroundColor(Theme.muted) }
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Theme.card)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.outline, lineWidth: 0.5))
    }
}

/// What to expect after pressing a button.
struct Expect: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text).font(.caption).foregroundColor(Theme.muted).fixedSize(horizontal: false, vertical: true)
    }
}

/// Buttons wrapped onto as many rows as needed.
struct Flow<Content: View>: View {
    @ViewBuilder let content: () -> Content
    var body: some View {
        WrapLayout(spacing: 8) { content() }
    }
}

/// A simple wrapping layout.
struct WrapLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: width == .infinity ? x : width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > bounds.minX && x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

struct PrimaryButton: View {
    let title: String
    let action: () -> Void
    init(_ title: String, action: @escaping () -> Void) { self.title = title; self.action = action }
    var body: some View {
        Button(action: action) { Text(title).font(.subheadline.weight(.semibold)).padding(.horizontal, 14).padding(.vertical, 8) }
            .background(Theme.sky).foregroundColor(.white).cornerRadius(10)
    }
}

struct TonalButton: View {
    let title: String
    let action: () -> Void
    init(_ title: String, action: @escaping () -> Void) { self.title = title; self.action = action }
    var body: some View {
        Button(action: action) { Text(title).font(.subheadline.weight(.medium)).padding(.horizontal, 14).padding(.vertical, 8) }
            .background(Theme.skyContainer).foregroundColor(Theme.ink).cornerRadius(10)
    }
}

struct OutlineButton: View {
    let title: String
    let action: () -> Void
    init(_ title: String, action: @escaping () -> Void) { self.title = title; self.action = action }
    var body: some View {
        Button(action: action) { Text(title).font(.subheadline).padding(.horizontal, 14).padding(.vertical, 8) }
            .foregroundColor(Theme.sky)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.sky, lineWidth: 1))
    }
}

struct StatusPill: View {
    let text: String
    let color: Color
    init(_ text: String, _ color: Color) { self.text = text; self.color = color }
    var body: some View {
        Text(text).font(.caption.weight(.semibold)).padding(.horizontal, 8).padding(.vertical, 3)
            .background(color.opacity(0.15)).foregroundColor(color).cornerRadius(8)
    }
}

struct Field: View {
    let label: String
    @Binding var text: String
    var supporting: String?

    init(_ label: String, _ text: Binding<String>, supporting: String? = nil) {
        self.label = label
        _text = text
        self.supporting = supporting
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(.caption).foregroundColor(Theme.muted)
            TextField(label, text: $text).textFieldStyle(.roundedBorder).autocorrectionDisabled().textInputAutocapitalization(.never)
            if let supporting { Text(supporting).font(.caption2).foregroundColor(Theme.muted) }
        }
    }
}

/// One choice among a few, as chips.
struct ChoiceChips<T: Hashable>: View {
    let options: [T]
    @Binding var selected: T
    let label: (T) -> String

    var body: some View {
        Flow {
            ForEach(options, id: \.self) { option in
                Button { selected = option } label: {
                    Text(label(option)).font(.caption.weight(.medium)).padding(.horizontal, 10).padding(.vertical, 6)
                }
                .background(selected == option ? Theme.sky : Theme.skyContainer)
                .foregroundColor(selected == option ? .white : Theme.ink)
                .cornerRadius(8)
            }
        }
    }
}

/// Several choices, as chips.
struct MultiChips<T: Hashable>: View {
    let options: [T]
    @Binding var selected: Set<T>
    let label: (T) -> String

    var body: some View {
        Flow {
            ForEach(options, id: \.self) { option in
                Button {
                    if selected.contains(option) { selected.remove(option) } else { selected.insert(option) }
                } label: {
                    Text(label(option)).font(.caption.weight(.medium)).padding(.horizontal, 10).padding(.vertical, 6)
                }
                .background(selected.contains(option) ? Theme.sky : Theme.skyContainer)
                .foregroundColor(selected.contains(option) ? .white : Theme.ink)
                .cornerRadius(8)
            }
        }
    }
}

struct SwitchRow: View {
    let title: String
    @Binding var isOn: Bool
    var supporting: String?

    init(_ title: String, _ isOn: Binding<Bool>, _ supporting: String? = nil) {
        self.title = title
        _isOn = isOn
        self.supporting = supporting
    }

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline)
                if let supporting { Text(supporting).font(.caption2).foregroundColor(Theme.muted) }
            }
        }
        .tint(Theme.sky)
    }
}

struct KeyValueLine: View {
    let key: String
    let value: String
    init(_ key: String, _ value: String) { self.key = key; self.value = value }
    var body: some View {
        HStack(alignment: .top) {
            Text(key).font(.caption).foregroundColor(Theme.muted)
            Spacer()
            Text(value).font(.caption.monospaced()).multilineTextAlignment(.trailing)
        }
    }
}

struct CodeLine: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text).font(.caption.monospaced()).padding(8).frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.paper).cornerRadius(8).textSelection(.enabled)
    }
}

struct StatTile: View {
    let label: String
    let value: String
    var color: Color = Theme.ink
    var body: some View {
        VStack(spacing: 2) {
            Text(value).font(.title3.weight(.bold)).foregroundColor(color)
            Text(label).font(.caption).foregroundColor(Theme.muted)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 10).background(Theme.card).cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.outline, lineWidth: 0.5))
    }
}

/// The tab's scrolling page with the standard spacing.
struct Page<Content: View>: View {
    @ViewBuilder let content: () -> Content
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) { content() }.padding(16)
        }
        .background(Theme.paper)
    }
}
