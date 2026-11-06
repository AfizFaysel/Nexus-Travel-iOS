import SwiftUI

/// Product statuses mirrored from Android.
enum NexusStatus: CaseIterable, Equatable {
    case info
    case success
    case warning
    case error
    case empty
    case offline
    case restored
    case loading

    /// Colors for compact feedback next to live booking content.
    var inlineColors: NexusStatusColors {
        self == .offline ? NexusStatus.warning.colors : colors
    }

    /// Colors assigned to this status by Android design semantics.
    var colors: NexusStatusColors {
        switch self {
        case .info:
            NexusStatusColors(
                container: NexusSemanticColors.brandSoft,
                content: NexusSemanticColors.link,
                border: NexusSemanticColors.link.opacity(0.28)
            )
        case .success, .restored:
            NexusStatusColors(
                container: NexusSemanticColors.successBg,
                content: NexusSemanticColors.successText,
                border: NexusSemanticColors.successText.opacity(0.28)
            )
        case .warning:
            NexusStatusColors(
                container: NexusSemanticColors.warningBg,
                content: NexusSemanticColors.warningText,
                border: NexusSemanticColors.warningText.opacity(0.28)
            )
        case .error:
            NexusStatusColors(
                container: NexusSemanticColors.errorBg,
                content: NexusSemanticColors.errorText,
                border: NexusSemanticColors.errorText.opacity(0.28)
            )
        case .empty:
            NexusStatusColors(
                container: NexusSemanticColors.surfaceMuted,
                content: NexusSemanticColors.textSecondary,
                border: NexusSemanticColors.borderDefault
            )
        case .offline:
            NexusStatusColors(
                container: NexusColors.navy950,
                content: NexusSemanticColors.actionPrimaryText,
                border: NexusColors.navy950
            )
        case .loading:
            NexusStatusColors(
                container: NexusSemanticColors.brandSoft,
                content: NexusSemanticColors.actionPrimary,
                border: NexusSemanticColors.actionPrimary.opacity(0.28)
            )
        }
    }
}

/// Container, content, and border colors for a product status.
struct NexusStatusColors {
    let container: Color
    let content: Color
    let border: Color
}
