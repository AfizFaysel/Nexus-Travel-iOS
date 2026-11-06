import SwiftUI

/// A filled primary action button with optional leading content and progress state.
struct NexusPrimaryButton<LeadingIcon: View>: View {
    private let title: String
    private let isEnabled: Bool
    private let isLoading: Bool
    private let loadingTitle: String?
    private let fillsWidth: Bool
    private let minWidth: CGFloat?
    private let minHeight: CGFloat
    private let cornerRadius: CGFloat
    private let action: () -> Void
    private let leadingIcon: () -> LeadingIcon

    /// Creates a primary button with leading content.
    init(
        _ title: String,
        isEnabled: Bool = true,
        isLoading: Bool = false,
        loadingTitle: String? = nil,
        fillsWidth: Bool = false,
        minWidth: CGFloat? = nil,
        minHeight: CGFloat = NexusLayout.buttonHeight,
        cornerRadius: CGFloat = NexusRadius.md,
        action: @escaping () -> Void,
        @ViewBuilder leadingIcon: @escaping () -> LeadingIcon
    ) {
        self.title = title
        self.isEnabled = isEnabled
        self.isLoading = isLoading
        self.loadingTitle = loadingTitle
        self.fillsWidth = fillsWidth
        self.minWidth = minWidth
        self.minHeight = minHeight
        self.cornerRadius = cornerRadius
        self.action = action
        self.leadingIcon = leadingIcon
    }

    /// The styled primary button content.
    var body: some View {
        Button(action: action) {
            Group {
                if isLoading {
                    HStack(spacing: NexusSpacing.space8) {
                        ProgressView()
                            .controlSize(.small)
                            .tint(NexusSemanticColors.actionPrimaryText)
                            .frame(width: NexusIconSize.sm, height: NexusIconSize.sm)
                        if let loadingTitle {
                            Text(loadingTitle).nexusTextStyle(NexusText.styles.button)
                        }
                    }
                } else {
                    HStack(spacing: NexusSpacing.space8) {
                        leadingIcon()
                        Text(title)
                            .nexusTextStyle(NexusText.styles.button)
                    }
                }
            }
            .padding(.horizontal, NexusSpacing.space16)
            .padding(.vertical, NexusSpacing.space12)
            .frame(minWidth: minWidth, minHeight: minHeight)
            .frame(maxWidth: fillsWidth ? .infinity : nil)
        }
        .buttonStyle(NexusPrimaryButtonStyle(cornerRadius: cornerRadius))
        .disabled(!isEnabled || isLoading)
        .accessibilityLabel(Text(title))
        .accessibilityValue(isLoading ? Text("In progress") : Text(""))
    }
}

extension NexusPrimaryButton where LeadingIcon == EmptyView {
    /// Creates a text-only primary button.
    init(
        _ title: String,
        isEnabled: Bool = true,
        isLoading: Bool = false,
        loadingTitle: String? = nil,
        fillsWidth: Bool = false,
        minWidth: CGFloat? = nil,
        minHeight: CGFloat = NexusLayout.buttonHeight,
        cornerRadius: CGFloat = NexusRadius.md,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.isEnabled = isEnabled
        self.isLoading = isLoading
        self.loadingTitle = loadingTitle
        self.fillsWidth = fillsWidth
        self.minWidth = minWidth
        self.minHeight = minHeight
        self.cornerRadius = cornerRadius
        self.action = action
        leadingIcon = EmptyView.init
    }
}

/// An outlined secondary action button with optional leading content.
struct NexusSecondaryButton<LeadingIcon: View>: View {
    private let title: String
    private let isEnabled: Bool
    private let fillsWidth: Bool
    private let minHeight: CGFloat
    private let action: () -> Void
    private let leadingIcon: () -> LeadingIcon

    /// Creates a secondary button with leading content.
    init(
        _ title: String,
        isEnabled: Bool = true,
        fillsWidth: Bool = false,
        minHeight: CGFloat = NexusLayout.buttonHeight,
        action: @escaping () -> Void,
        @ViewBuilder leadingIcon: @escaping () -> LeadingIcon
    ) {
        self.title = title
        self.isEnabled = isEnabled
        self.fillsWidth = fillsWidth
        self.minHeight = minHeight
        self.action = action
        self.leadingIcon = leadingIcon
    }

    /// The styled secondary button content.
    var body: some View {
        Button(action: action) {
            HStack(spacing: NexusSpacing.space8) {
                leadingIcon()
                Text(title)
                    .nexusTextStyle(NexusText.styles.button)
            }
            .padding(.horizontal, NexusSpacing.space16)
            .padding(.vertical, NexusSpacing.space12)
            .frame(minHeight: minHeight)
            .frame(maxWidth: fillsWidth ? .infinity : nil)
        }
        .buttonStyle(NexusSecondaryButtonStyle())
        .disabled(!isEnabled)
        .accessibilityLabel(Text(title))
    }
}

extension NexusSecondaryButton where LeadingIcon == EmptyView {
    /// Creates a text-only secondary button.
    init(
        _ title: String,
        isEnabled: Bool = true,
        fillsWidth: Bool = false,
        minHeight: CGFloat = NexusLayout.buttonHeight,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.isEnabled = isEnabled
        self.fillsWidth = fillsWidth
        self.minHeight = minHeight
        self.action = action
        leadingIcon = EmptyView.init
    }
}

private struct NexusPrimaryButtonStyle: ButtonStyle {
    let cornerRadius: CGFloat
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(
                isEnabled
                    ? NexusSemanticColors.actionPrimaryText
                    : NexusSemanticColors.disabledText
            )
            .background(
                isEnabled
                    ? configuration.isPressed
                        ? NexusSemanticColors.actionPressed
                        : NexusSemanticColors.actionPrimary
                    : NexusSemanticColors.disabledBg
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .scaleEffect(configuration.isPressed && isEnabled && !reduceMotion ? NexusMotion.buttonPressedScale : 1)
            .animation(.easeOut(duration: NexusMotion.durationFastSeconds), value: configuration.isPressed)
    }
}

private struct NexusSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(
                isEnabled
                    ? NexusSemanticColors.actionSecondaryText
                    : NexusSemanticColors.disabledText
            )
            .background(
                configuration.isPressed && isEnabled
                    ? NexusSemanticColors.surfaceActive
                    : NexusSemanticColors.actionSecondary
            )
            .clipShape(RoundedRectangle(cornerRadius: NexusRadius.md))
            .overlay {
                RoundedRectangle(cornerRadius: NexusRadius.md)
                    .stroke(NexusSemanticColors.borderDefault, lineWidth: NexusBorder.hairline)
            }
    }
}
