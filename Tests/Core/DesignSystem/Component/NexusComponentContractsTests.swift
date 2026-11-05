import SwiftUI
import Testing
@testable import NexusTravel

@Suite("Nexus component contracts")
struct NexusComponentContractsTests {
    @Test("Buttons construct every Android-proven state and slot")
    @MainActor
    func buttonsConstructEveryProvenStateAndSlot() {
        _ = NexusPrimaryButton("Continue", action: {})
        _ = NexusPrimaryButton("Continue", isEnabled: false, isLoading: true, action: {})
        _ = NexusPrimaryButton("Continue", action: {}) {
            Image(systemName: "airplane")
        }

        _ = NexusSecondaryButton("Download", action: {})
        _ = NexusSecondaryButton("Download", isEnabled: false, action: {}) {
            Image(systemName: "arrow.down")
        }

        _ = NexusTextButton("View fare rules", action: {})
        _ = NexusTextButton("View fare rules", isEnabled: false, action: {}) {
            Image(systemName: "doc.text")
        }

        _ = NexusIconButton("Show password", action: {}) {
            Image(systemName: "eye")
        }
        _ = NexusIconButton("Selected filter", isEnabled: false, isSelected: true, action: {}) {
            Image(systemName: "line.3.horizontal.decrease")
        }
    }

    @Test("Icon actions construct every finite variant and badge form")
    @MainActor
    func iconActionsConstructEveryVariantAndBadgeForm() {
        for variant in NexusIconButtonVariant.allCases {
            _ = NexusIconActionButton(
                "Notifications",
                variant: variant,
                showsBadge: variant == .plain,
                action: {}
            ) {
                Image(systemName: "bell")
            }
        }

        #expect(NexusIconButtonVariant.allCases.count == 3)
        #expect(NexusIconName.continue.source == .custom("continue-outline"))
    }

    @Test("Fields construct standard and auth state combinations")
    @MainActor
    func fieldsConstructStandardAndAuthStateCombinations() {
        _ = NexusTextField(text: .constant(""), label: "Email")
        _ = NexusTextField(
            text: .constant("passenger@example.com"),
            label: "Email",
            placeholder: "name@example.com",
            error: "Enter a valid email.",
            isEnabled: false,
            leadingIcon: { Image(systemName: "envelope") }
        )
        _ = NexusTextField(
            text: .constant("secret"),
            label: "Password",
            isSecure: true,
            leadingIcon: { Image(systemName: "lock") },
            trailingContent: {
                NexusIconButton("Show password", action: {}) {
                    Image(systemName: "eye")
                }
            }
        )

        _ = NexusAuthTextField(text: .constant(""), placeholder: "Email")
        _ = NexusAuthTextField(
            text: .constant("secret"),
            placeholder: "Password",
            label: "Password",
            error: "Password is required.",
            isEnabled: false,
            isSecure: true,
            leadingIcon: { Image(systemName: "lock") },
            trailingContent: {
                NexusIconButton("Show password", action: {}) {
                    Image(systemName: "eye")
                }
            }
        )
    }

    @Test("Top bars construct both alignments with optional trailing content")
    @MainActor
    func topBarsConstructBothAlignmentsAndTrailingContent() {
        _ = NexusTopBar("Trip details")
        _ = NexusTopBar("Search results", titleAlignment: .start) {
            NexusIconActionButton("Notifications", showsBadge: true, action: {}) {
                Image(systemName: "bell")
            }
        }

        #expect(NexusTopBarTitleAlignment.allCases.count == 2)
    }

    @Test("Feedback constructs every status and optional slot form")
    @MainActor
    func feedbackConstructsEveryStatusAndSlotForm() {
        for status in NexusStatus.allCases {
            _ = NexusStatusChip(text: "Status", status: status)
            _ = NexusStatusChip(text: "Status", status: status) {
                Image(systemName: "info.circle")
            }
            _ = NexusBanner(text: "Status update", status: status)
            _ = NexusBanner(
                text: "Status update",
                status: status,
                leadingContent: { Image(systemName: "info.circle") },
                trailingAction: { Button("Retry", action: {}) }
            )
        }

        #expect(NexusStatus.allCases.count == 8)
    }

    @Test("Feedback panel constructs blocking and recoverable states")
    @MainActor
    func feedbackPanelConstructsBlockingAndRecoverableStates() {
        _ = NexusFeedbackPanel(title: "Could not load", message: "Check your connection.")
        _ = NexusFeedbackPanel(
            title: "Receipt submitted", message: "Your trip is being reviewed.", status: .success
        )
        _ = NexusFeedbackPanel(
            title: "Trips couldn't refresh", message: "Saved tickets remain available.",
            primaryActionLabel: "Try again", onPrimaryAction: {}
        )
    }
}
