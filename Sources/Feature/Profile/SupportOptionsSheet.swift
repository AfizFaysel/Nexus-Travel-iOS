import SwiftUI

struct SupportOptionsSheet: View {
    let repository: RemoteSupportRepository
    let horizontalPadding: CGFloat
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.openURL) private var openURL
    @State private var contacts: [SupportContact] = []
    @State private var status = Status.loading
    @State private var request = 0
    @State private var contentHeight: CGFloat = .zero
    @State private var linkFailed = false

    private enum Status { case loading, loaded, failed }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: NexusSpacing.space0) {
                Text("Support")
                    .nexusTextStyle(NexusText.styles.sectionTitle)
                    .foregroundStyle(NexusSemanticColors.textHeading)
                    .accessibilityAddTraits(.isHeader)
                    .padding(.bottom, NexusSpacing.space24)
                panel
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, NexusSpacing.space24)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
        }
        .presentationDetents([detent])
        .presentationBackground(NexusSemanticColors.surfaceElevated)
        .presentationDragIndicator(.visible)
        .task(id: request) { await load() }
        .alert("No app available to open this support option.", isPresented: $linkFailed) {
            Button("OK", role: .cancel) {}
        }
    }

    private var detent: PresentationDetent {
        if dynamicTypeSize.isAccessibilitySize { return .large }
        return contentHeight == .zero ? .medium : .height(contentHeight)
    }

    @ViewBuilder private var panel: some View {
        if contacts.isEmpty && status == .loading {
            message("Loading support contacts…")
        } else if contacts.isEmpty && status == .loaded {
            message("Support channels are being set up. You can check your booking status here.")
        } else {
            ForEach(contacts) { contact in
                if contact.id != contacts.first?.id {
                    Divider().overlay(NexusSemanticColors.borderSubtle)
                }
                contactRow(contact)
            }
        }
        if status == .failed {
            message(contacts.isEmpty
                ? "Couldn’t load support contacts. Try again."
                : "Couldn’t refresh support contacts. Showing saved details.")
                .padding(.top, NexusSpacing.space16)
            NexusTextButton("Try again") { request += 1 }
        }
    }

    private func contactRow(_ contact: SupportContact) -> some View {
        let icon: NexusIconName = switch contact.kind {
        case .call: .phone
        case .whatsApp: .whatsApp
        case .email: .email
        }
        return Button {
            openURL(contact.url) { accepted in linkFailed = !accepted }
        } label: {
            HStack(spacing: NexusSpacing.space16) {
                NexusIcon(name: icon)
                    .foregroundStyle(NexusSemanticColors.textSecondary)
                VStack(alignment: .leading, spacing: NexusSpacing.space4) {
                    Text(contact.kind.rawValue)
                        .nexusTextStyle(NexusText.styles.listTitle)
                        .foregroundStyle(NexusSemanticColors.textPrimary)
                    message(contact.detail)
                }
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, NexusSpacing.space16)
            .frame(minHeight: NexusLayout.touchRecommended)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(contact.kind.rawValue) support")
        .accessibilityHint(contact.detail)
    }

    private func message(_ text: String) -> some View {
        Text(text)
            .nexusTextStyle(NexusText.styles.bodySmall, matchesLineHeight: true)
            .foregroundStyle(NexusSemanticColors.textSecondary)
    }

    private func load() async {
        contacts = repository.cached()
        status = .loading
        do {
            contacts = try await repository.refresh()
            status = .loaded
        } catch is CancellationError {
            return
        } catch {
            if !Task.isCancelled { status = .failed }
        }
    }
}
