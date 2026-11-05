import SwiftUI

/// One accessible code input presented as six visual positions.
struct AuthCodeField: View {
    @Binding var code: String
    let error: String?
    let isSuccess: Bool
    var isEnabled = true
    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack {
            HStack(spacing: NexusSpacing.space8) {
                ForEach(0..<6, id: \.self) { index in
                    ZStack {
                            if isFocused && index == min(code.count, 5) && character(at: index).isEmpty {
                                Capsule()
                                    .fill(NexusSemanticColors.brandPrimary)
                                    .frame(width: NexusSpacing.space2, height: NexusSpacing.space24)
                            } else {
                                Text(character(at: index))
                                    .nexusTextStyle(NexusText.styles.bodyLarge)
                                    .foregroundStyle(NexusSemanticColors.textHeading)
                            }
                    }
                        .padding(.vertical, NexusSpacing.space16)
                        .frame(maxWidth: .infinity, minHeight: NexusLayout.inputHeight)
                        .background {
                            RoundedRectangle(cornerRadius: NexusRadius.md)
                                .strokeBorder(borderColor(at: index), lineWidth: NexusBorder.hairline)
                        }
                        .accessibilityHidden(true)
                }
            }
            TextField("", text: $code)
                .textContentType(.oneTimeCode)
                .keyboardType(.numberPad)
                .focused($isFocused)
                .foregroundStyle(.clear)
                .tint(.clear)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityLabel("Six-digit email code")
                .disabled(!isEnabled)
        }
        .contentShape(Rectangle())
        .onTapGesture { if isEnabled { isFocused = true } }
    }

    private func borderColor(at index: Int) -> Color {
        if error != nil { return NexusSemanticColors.errorText }
        if isSuccess { return NexusSemanticColors.successText }
        return isFocused && index == min(code.count, 5)
            ? NexusSemanticColors.borderFocus : NexusSemanticColors.borderDefault
    }

    private func character(at index: Int) -> String {
        let digits = Array(code)
        guard digits.indices.contains(index) else { return "" }
        return String(digits[index])
    }
}
