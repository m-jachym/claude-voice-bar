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

            HStack(spacing: 8) {
                Circle()
                    .fill(model.isRecording ? Color.red : Color.gray)
                    .frame(width: 8, height: 8)
                Text(model.isRecording ? "Recording..." : "Ready")
                    .font(.headline)
                Spacer()
            }

            Divider()

            if model.isLoadingSessions {
                HStack {
                    ProgressView().scaleEffect(0.7)
                    Text("Looking for Claude sessions...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else if model.sessions.isEmpty {
                Text("No active Claude sessions")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Press number key or click to send:")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    ForEach(Array(model.sessions.enumerated()), id: \.offset) { i, session in
                        Button(action: {
                            model.onSelectSession?(session)
                        }) {
                            HStack(spacing: 10) {
                                Text("\(i + 1)")
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white)
                                    .frame(width: 20, height: 20)
                                    .background(Color(NSColor.darkGray))
                                    .cornerRadius(4)
                                Text(session)
                                    .font(.system(size: 13, design: .monospaced))
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                            .padding(.vertical, 3)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Divider()

            Button(action: {
                model.onCancel?()
            }) {
                Text("Cancel (Esc)")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(12)
        .frame(width: 240)
        .background(.regularMaterial)
        .cornerRadius(10)
        .shadow(radius: 8)
    }
}
