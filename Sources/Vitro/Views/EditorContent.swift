import SwiftUI

/// The content of a single note window: the rich-text editor floating on the
/// window's vibrancy base. The tabs now live in the titlebar (native), so there
/// is no in-app tab strip here anymore.
struct EditorContent: View {
    @ObservedObject var note: Note
    var onChange: () -> Void

    var body: some View {
        RichTextEditor(note: note, onChange: onChange)
            .padding(.trailing, 12)
            .padding(.bottom, 12)
            .background(VisualEffectBackground().ignoresSafeArea())
    }
}
