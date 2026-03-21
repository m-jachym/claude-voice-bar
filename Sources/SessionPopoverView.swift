import SwiftUI

class SessionPopoverView: ObservableObject {
    @Published var sessions: [String] = []
    @Published var isRecording: Bool = false
}

struct SessionPopoverContentView: View {
    @ObservedObject var model: SessionPopoverView

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: model.isRecording ? "mic.fill" : "mic")
                    .foregroundColor(model.isRecording ? .red : .secondary)
                Text(model.isRecording ? "Nagrywanie..." : "Gotowy")
                    .font(.headline)
            }

            Divider()

            if model.sessions.isEmpty {
                Text("Brak aktywnych sesji Claude")
                    .foregroundColor(.secondary)
                    .font(.caption)
            } else {
                ForEach(Array(model.sessions.enumerated()), id: \.offset) { i, session in
                    Text("\(i + 1)  →  \(session)")
                        .font(.system(.body, design: .monospaced))
                }
            }
        }
        .padding()
        .frame(width: 220, alignment: .leading)
    }
}
