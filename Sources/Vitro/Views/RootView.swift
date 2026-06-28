import SwiftUI
import AppKit

struct RootView: View {
    @EnvironmentObject private var workspace: Workspace

    var body: some View {
        VStack(spacing: 0) {
            TopBar()

            if let note = workspace.selectedNote {
                RichTextEditor(note: note) { workspace.touch(note) }
                    .id(note.id)
                    .padding(.trailing, 12)
                    .padding(.bottom, 12)
            } else {
                Spacer()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .vitroExport)) { _ in
            exportSelected()
        }
    }

    private func exportSelected() {
        guard let note = workspace.selectedNote else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = note.title + ".md"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? Markdown.string(from: note.body).write(to: url, atomically: true, encoding: .utf8)
    }
}

// MARK: - Top bar (CotEditor-style: title toolbar + tab strip below)

private struct TopBar: View {
    @EnvironmentObject private var workspace: Workspace
    // Shared animation space so the glass tabs morph/flow into one another
    // (instead of popping in/out) when tabs are opened or closed.
    @Namespace private var glass

    var body: some View {
        VStack(spacing: 0) {
            // Reserve room for the traffic-light buttons — the file name lives
            // on the tab, not in a separate title here.
            Color.clear.frame(height: 24)
            tabStrip
        }
    }

    // Full-width tab segments that fill the panel, plus "+". Wrapped in a
    // GlassEffectContainer so adjacent glass tabs merge/morph fluidly.
    private var tabStrip: some View {
        GlassEffectContainer(spacing: 6) {
            HStack(spacing: 6) {
                ForEach(workspace.openTabs) { note in
                    TabSegment(
                        note: note,
                        isSelected: note.id == workspace.selectedID,
                        glass: glass,
                        onSelect: { workspace.select(note.id) },
                        onClose: { workspace.close(note.id) }
                    )
                    .frame(maxWidth: .infinity)
                }

                Button(action: { workspace.newTab() }) {
                    Image(systemName: "plus")
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
            }
            .padding(.horizontal, 6)
            .padding(.bottom, 4)
        }
        // Animate every mutation path: the +/× buttons, ⌘T / ⌘W, and the menu
        // commands all flow through these published values.
        .animation(.smooth(duration: 0.35), value: workspace.openNoteIDs)
        .animation(.smooth(duration: 0.25), value: workspace.selectedID)
    }
}

private struct TabSegment: View {
    @ObservedObject var note: Note
    let isSelected: Bool
    let glass: Namespace.ID
    let onSelect: () -> Void
    let onClose: () -> Void

    @State private var hovering = false

    var body: some View {
        ZStack {
            Text(note.title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundStyle(isSelected ? .primary : .secondary)
                .lineLimit(1)
                .padding(.horizontal, 24)

            // Close button on the leading edge, revealed on hover.
            HStack {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .opacity(hovering ? 1 : 0)
                Spacer()
            }
            .padding(.leading, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 7)
        // Real Liquid Glass: selected tab is tinted + more prominent, the rest
        // are plain interactive glass. `interactive()` gives the pointer/press
        // reactivity that's part of the material.
        .glassEffect(
            isSelected
                ? .regular.tint(.accentColor.opacity(0.55)).interactive()
                : .regular.interactive(),
            in: .rect(cornerRadius: 10)
        )
        // Stable per-note identity in the shared namespace → tabs morph into
        // each other on open/close instead of abruptly appearing/disappearing.
        .glassEffectID(note.id, in: glass)
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .onHover { hovering = $0 }
    }
}
