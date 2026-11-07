import SwiftUI

/// A compact status label with optional leading content.
struct NexusStatusChip<LeadingContent: View>: View {
    private let text: String
    private let status: NexusStatus
    private let leadingContent: () -> LeadingContent

    /// Creates a status chip with leading content.
    init(
        text: String,
        status: NexusStatus,
        @ViewBuilder leadingContent: @escaping () -> LeadingContent
    ) {
        self.text = text
        self.status = status
        self.leadingContent = leadingContent
    }

    /// The status-chip content.
    var body: some View {
        HStack(spacing: NexusSpacing.space8) {
            leadingContent()
            Text(text)
                .nexusTextStyle(NexusText.styles.statusBadge)
        }
        .foregroundStyle(status.colors.content)
        .padding(.horizontal, NexusSpacing.space12)
        .padding(.vertical, NexusSpacing.space8)
        .background(status.colors.container)
        .clipShape(RoundedRectangle(cornerRadius: NexusRadius.xl))
        .overlay {
            RoundedRectangle(cornerRadius: NexusRadius.xl)
                .stroke(status.colors.border, lineWidth: NexusBorder.hairline)
        }
    }
}

extension NexusStatusChip where LeadingContent == EmptyView {
    /// Creates a status chip without leading content.
    init(text: String, status: NexusStatus) {
        self.text = text
        self.status = status
        leadingContent = EmptyView.init
    }
}

/// Compact inline feedback with a status icon and optional retry.
struct NexusInlineStatusBanner: View {
    let text: String
    let status: NexusStatus
    var onRetry: (() -> Void)?
    var icon: NexusIconName?

    var body: some View {
        let colors = status.inlineColors
        HStack(spacing: NexusSpacing.space8) {
            NexusIcon(name: icon ?? (status == .offline ? .offline : .error), size: NexusIconSize.sm)
                .accessibilityHidden(true)
            Text(text)
                .nexusTextStyle(NexusText.styles.bodySmall)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let onRetry {
                NexusTextButton("Try again", action: onRetry)
            }
        }
        .foregroundStyle(colors.content)
        .padding(.leading, NexusSpacing.space12)
        .padding(.trailing, NexusSpacing.space4)
        .padding(.vertical, NexusSpacing.space4)
        .background(colors.container, in: RoundedRectangle(cornerRadius: NexusRadius.md))
        .overlay {
            RoundedRectangle(cornerRadius: NexusRadius.md)
                .strokeBorder(colors.border, lineWidth: NexusBorder.hairline)
        }
    }
}

/// A full-width status banner with optional leading and trailing content.
struct NexusBanner<LeadingContent: View, TrailingAction: View>: View {
    private let text: String
    private let status: NexusStatus
    private let leadingContent: () -> LeadingContent
    private let trailingAction: () -> TrailingAction

    /// Creates a banner with leading and trailing content.
    init(
        text: String,
        status: NexusStatus,
        @ViewBuilder leadingContent: @escaping () -> LeadingContent,
        @ViewBuilder trailingAction: @escaping () -> TrailingAction
    ) {
        self.text = text
        self.status = status
        self.leadingContent = leadingContent
        self.trailingAction = trailingAction
    }

    /// The status-banner content.
    var body: some View {
        HStack(spacing: NexusSpacing.space12) {
            leadingContent()
            Text(text)
                .foregroundStyle(status.colors.content)
                .nexusTextStyle(NexusText.styles.body)
                .frame(maxWidth: .infinity, alignment: .leading)
            trailingAction()
        }
        .foregroundStyle(status.colors.content)
        .padding(NexusSpacing.space16)
        .frame(maxWidth: .infinity)
        .background(status.colors.container)
        .clipShape(RoundedRectangle(cornerRadius: NexusRadius.md))
        .overlay {
            RoundedRectangle(cornerRadius: NexusRadius.md)
                .stroke(status.colors.border, lineWidth: NexusBorder.hairline)
        }
    }
}

extension NexusBanner where LeadingContent == EmptyView, TrailingAction == EmptyView {
    /// Creates a text-only banner.
    init(text: String, status: NexusStatus) {
        self.text = text
        self.status = status
        leadingContent = EmptyView.init
        trailingAction = EmptyView.init
    }
}

extension NexusBanner where TrailingAction == EmptyView {
    /// Creates a banner with leading content.
    init(
        text: String,
        status: NexusStatus,
        @ViewBuilder leadingContent: @escaping () -> LeadingContent
    ) {
        self.text = text
        self.status = status
        self.leadingContent = leadingContent
        trailingAction = EmptyView.init
    }
}

extension NexusBanner where LeadingContent == EmptyView {
    /// Creates a banner with trailing action content.
    init(
        text: String,
        status: NexusStatus,
        @ViewBuilder trailingAction: @escaping () -> TrailingAction
    ) {
        self.text = text
        self.status = status
        leadingContent = EmptyView.init
        self.trailingAction = trailingAction
    }
}

/// Status-colored feedback with optional recovery actions.
struct NexusFeedbackPanel: View {
    let title: String
    let message: String
    var status: NexusStatus = .error
    var primaryActionLabel: String?
    var onPrimaryAction: (() -> Void)?
    var secondaryActionLabel: String?
    var onSecondaryAction: (() -> Void)?
    var icon: NexusIconName?
    var compact = false

    var body: some View {
        VStack(alignment: .leading, spacing: NexusSpacing.space16) {
            HStack(alignment: .top, spacing: NexusSpacing.space12) {
                NexusIcon(name: icon ?? (status == .error ? .error : .info), size: NexusIconSize.sm)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: NexusSpacing.space4) {
                    Text(title).nexusTextStyle(NexusText.styles.listTitle)
                    Text(message).nexusTextStyle(NexusText.styles.bodySmall)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            if let primaryActionLabel, let onPrimaryAction {
                VStack(spacing: NexusSpacing.space8) {
                    NexusPrimaryButton(primaryActionLabel, fillsWidth: true, action: onPrimaryAction)
                    if let secondaryActionLabel, let onSecondaryAction {
                        NexusSecondaryButton(secondaryActionLabel, fillsWidth: true, action: onSecondaryAction)
                    }
                }
            }
        }
        .foregroundStyle(status.colors.content)
        .padding(compact ? NexusSpacing.space12 : NexusSpacing.space16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(status.colors.container)
        .clipShape(RoundedRectangle(cornerRadius: NexusRadius.lg))
        .overlay {
            RoundedRectangle(cornerRadius: NexusRadius.lg)
                .stroke(status.colors.border, lineWidth: NexusBorder.hairline)
        }
        .accessibilityElement(children: .contain)
    }
}
