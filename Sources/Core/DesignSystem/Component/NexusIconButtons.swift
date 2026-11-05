import SwiftUI

/// Visual variants for a Nexus icon action.
enum NexusIconButtonVariant: CaseIterable, Equatable {
    case plain
    case softContainer
    case outlined
}

/// An accessible icon action with optional container and badge.
struct NexusIconActionButton<Icon: View>: View {
    private let accessibilityLabel: String
    private let variant: NexusIconButtonVariant
    private let showsBadge: Bool
    private let action: () -> Void
    private let icon: () -> Icon

    /// Creates an icon action whose text argument is its VoiceOver label.
    init(
        _ accessibilityLabel: String,
        variant: NexusIconButtonVariant = .plain,
        showsBadge: Bool = false,
        action: @escaping () -> Void,
        @ViewBuilder icon: @escaping () -> Icon
    ) {
        self.accessibilityLabel = accessibilityLabel
        self.variant = variant
        self.showsBadge = showsBadge
        self.action = action
        self.icon = icon
    }

    /// The styled icon-action content.
    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                icon()
                    .frame(width: NexusIconSize.md, height: NexusIconSize.md)
                if showsBadge {
                    Circle()
                        .fill(NexusSemanticColors.brandPrimary)
                        .frame(
                            width: NexusIconActionMetrics.badgeDiameter,
                            height: NexusIconActionMetrics.badgeDiameter
                        )
                        .accessibilityHidden(true)
                }
            }
            .frame(width: NexusIconSize.md, height: NexusIconSize.md)
            .frame(width: NexusLayout.touchRecommended, height: NexusLayout.touchRecommended)
            .contentShape(Rectangle())
        }
        .buttonStyle(NexusIconActionButtonStyle(variant: variant))
        .accessibilityLabel(Text(accessibilityLabel))
    }
}

private enum NexusIconActionMetrics {
    static let badgeDiameter: CGFloat = 9
    static let outlinedBorderOpacity = 0.72
}

private struct NexusIconActionButtonStyle: ButtonStyle {
    let variant: NexusIconButtonVariant

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(
                isEnabled
                    ? NexusSemanticColors.textPrimary
                    : NexusSemanticColors.disabledText
            )
            .background(backgroundColor(configuration: configuration))
            .clipShape(shape)
            .overlay {
                if variant == .outlined {
                    shape.stroke(
                        NexusSemanticColors.borderDefault.opacity(
                            NexusIconActionMetrics.outlinedBorderOpacity
                        ),
                        lineWidth: NexusBorder.hairline
                    )
                }
            }
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: NexusRadius.md)
    }

    private func backgroundColor(configuration: Configuration) -> Color {
        guard isEnabled else {
            return variant == .softContainer ? NexusSemanticColors.disabledBg : .clear
        }
        switch variant {
        case .plain, .outlined:
            return configuration.isPressed ? NexusSemanticColors.surfaceHover : .clear
        case .softContainer:
            return configuration.isPressed
                ? NexusSemanticColors.surfaceHover
                : NexusSemanticColors.surfaceElevated
        }
    }
}
