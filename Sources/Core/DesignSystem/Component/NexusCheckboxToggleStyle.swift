import SwiftUI

/// A rounded-square checkbox with a full-row target and native Toggle accessibility.
struct NexusCheckboxToggleStyle: ToggleStyle {
    var isInvalid = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        Button { configuration.isOn.toggle() } label: {
            HStack(spacing: NexusSpacing.space12) {
                RoundedRectangle(cornerRadius: NexusRadius.xs)
                    .fill(configuration.isOn ? fillColor : .clear)
                    .overlay {
                        RoundedRectangle(cornerRadius: NexusRadius.xs)
                            .strokeBorder(borderColor(isOn: configuration.isOn), lineWidth: NexusBorder.hairline)
                    }
                    .overlay {
                        if configuration.isOn {
                            NexusIcon(name: .check, size: NexusIconSize.xs)
                                .foregroundStyle(isEnabled ? NexusSemanticColors.actionPrimaryText : NexusSemanticColors.disabledText)
                        }
                    }
                    .frame(width: NexusIconSize.md, height: NexusIconSize.md)
                configuration.label
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(minHeight: NexusLayout.touchRecommended)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityRepresentation {
            Toggle(isOn: configuration.$isOn) { configuration.label }
                .toggleStyle(.switch)
        }
    }

    private var fillColor: Color {
        isEnabled ? NexusSemanticColors.brandPrimary : NexusSemanticColors.disabledBg
    }

    private func borderColor(isOn: Bool) -> Color {
        if !isEnabled { return NexusSemanticColors.disabledText }
        if isInvalid { return NexusSemanticColors.errorText }
        return isOn ? NexusSemanticColors.brandPrimary : NexusSemanticColors.textTertiary
    }
}
