import SwiftUI

/// Search form field shared by Home and destination flight planning.
struct NexusSearchField: View {
    let label: String
    let value: String
    let icon: NexusIconName
    var showsChevron = false
    let action: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: NexusSpacing.space2) {
                HStack(spacing: 0) {
                    NexusIcon(name: icon, size: NexusIconSize.formField)
                        .foregroundStyle(NexusSemanticColors.brandPrimary)
                    Text(label)
                        .nexusTextStyle(NexusText.styles.label)
                        .foregroundStyle(NexusSemanticColors.textSecondary)
                        .padding(.leading, NexusSpacing.space12)
                    if showsChevron {
                        Spacer(minLength: 0)
                        NexusIcon(name: .chevronDown, size: NexusIconSize.formField)
                            .foregroundStyle(NexusColors.slate700)
                    }
                }
                Text(value)
                    .nexusTextStyle(NexusText.styles.formInput)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                    .truncationMode(.tail)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, minHeight: NexusLayout.inputHeight, alignment: .leading)
            .contentShape(Rectangle())
        }
        .frame(maxWidth: .infinity)
        .buttonStyle(.plain)
        .accessibilityLabel("\(label), \(value)")
    }
}
