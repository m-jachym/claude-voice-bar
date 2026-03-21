import SwiftUI

class PopoverModel: ObservableObject {
    @Published var sessions: [String] = []
    @Published var isRecording: Bool = false
    @Published var isLoadingSessions: Bool = false

    var onSelectSession: ((String) -> Void)?
    var onCancel: (() -> Void)?
}

struct SessionPopoverContentView: View {
    @ObservedObject var model: PopoverModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            // Nagłówek
            HStack(spacing: 8) {
                Circle()
                    .fill(model.isRecording ? Color.red : Color.gray)
                    .frame(width: 10, height: 10)
                    .opacity(model.isRecording ? 1 : 0.4)
                Text(model.isRecording ? "Nagrywanie..." : "Gotowy")
                    .font(.headline)
                Spacer()
            }

            Divider()

            // Sesje
            if model.isLoadingSessions {
                HStack {
                    ProgressView().scaleEffect(0.7)
                    Text("Szukam sesji...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else if model.sessions.isEmpty {
                Text("Brak aktywnych sesji Claude")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ForEach(Array(model.sessions.enumerated()), id: \.offset) { i, session in
                    Button(action: {
                        model.onSelectSession?(session)
                    }) {
                        HStack {
                            Text("\(i + 1)")
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(.secondary)
                                .frame(width: 16, alignment: .trailing)
                            Text(session)
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        .padding(.vertical, 3)
                        .padding(.horizontal, 6)
                        .background(Color.accentColor.opacity(0.08))
                        .cornerRadius(5)
                    }
                    .buttonStyle(.plain)
                }
            }

            Divider()

            // Anuluj
            Button(action: {
                model.onCancel?()
            }) {
                Text("Anuluj")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(12)
        .frame(width: 240)
    }
}
