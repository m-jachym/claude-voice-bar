import SwiftUI

struct PermissionPopupView: View {
    let data: PermissionData
    @ObservedObject var model: PopoverModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text(data.title)
                    .font(.headline)
                Spacer()
            }

            if !data.description.isEmpty {
                Text(data.description)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(3)
            }

            Divider()

            Text("Press § to focus · arrows to navigate · Enter to confirm")
                .font(.system(size: 10))
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(data.options.enumerated()), id: \.offset) { i, option in
                    Button(action: {
                        model.onSelectPermission?(i + 1, data)
                    }) {
                        HStack(spacing: 10) {
                            Text("\(i + 1)")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                                .frame(width: 20, height: 20)
                                .background(model.permissionSelectedIndex == i ? Color.accentColor : Color(NSColor.darkGray))
                                .cornerRadius(4)
                            Text(option)
                                .font(.system(size: 12))
                                .foregroundColor(model.permissionSelectedIndex == i ? .primary : .secondary)
                                .multilineTextAlignment(.leading)
                            Spacer()
                        }
                        .padding(.vertical, 3)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(12)
        .frame(width: 280)
        .background(.regularMaterial)
        .cornerRadius(10)
        .shadow(radius: 8)
    }
}
