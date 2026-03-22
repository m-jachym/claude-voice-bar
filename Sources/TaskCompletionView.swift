import SwiftUI

struct TaskCompletionView: View {
    let session: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text(session.isEmpty ? "Claude finished" : "Claude finished · \(session)")
                .font(.system(size: 13))
                .lineLimit(1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .fixedSize()
        .background(.regularMaterial)
        .cornerRadius(8)
        .shadow(radius: 6)
    }
}
