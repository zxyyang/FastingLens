import SwiftUI

#if os(iOS)
public struct AISettingsView: View {
    @State private var draft = AISettingsDraft(rawJSON: "")
    @State private var validationMessage = "等待校验"

    public init() {}

    public var body: some View {
        ZStack {
            LinearGradient(
                colors: [FastingLensTheme.ink, FastingLensTheme.ink.opacity(0.92), FastingLensTheme.tomato.opacity(0.82)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 18) {
                Text("模型控制台")
                    .font(.fastingHero)
                    .foregroundStyle(FastingLensTheme.paper)

                Text("粘贴 Provider JSON，先在本地校验，再保存为当前识别配置。")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(FastingLensTheme.paper.opacity(0.78))

                TextEditor(text: $draft.rawJSON)
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .padding(16)
                    .frame(minHeight: 300)
                    .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .stroke(FastingLensTheme.paper.opacity(0.18), lineWidth: 1)
                    )

                HStack(spacing: 12) {
                    Button("校验 JSON") {
                        do {
                            let config = try draft.validate()
                            validationMessage = "校验通过：\(config.name)"
                        } catch {
                            validationMessage = "校验失败：\(error.localizedDescription)"
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(FastingLensTheme.citron)

                    Text(validationMessage)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(FastingLensTheme.paper)
                }

                Spacer()
            }
            .padding(24)
        }
    }
}

#Preview {
    AISettingsView()
}
#endif
