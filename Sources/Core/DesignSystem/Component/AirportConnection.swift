import SwiftUI

struct AirportConnection: View {
    let segment: FlightSegmentDisplay
    let departureName: String?
    let arrivalName: String?
    var surface = NexusSemanticColors.surfaceBase
    var dashLength = NexusSpacing.space8
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var timelineWidth: CGFloat {
        dynamicTypeSize.isAccessibilitySize
            ? NexusSpacing.space64 + NexusSpacing.space48
            : NexusSpacing.space64
    }

    var body: some View {
        VStack(alignment: .leading, spacing: NexusSpacing.space8) {
            endpoint(segment.departureAirportCode, name: departureName,
                     time: segment.departureTime, isDeparture: true)
            Text(segment.detail)
                .nexusTextStyle(NexusText.styles.bodySmall)
                .frame(width: timelineWidth)
                .fixedSize(horizontal: false, vertical: true)
                .hidden()
                .accessibilityHidden(true)
            endpoint(segment.arrivalAirportCode, name: arrivalName,
                     time: segment.arrivalTime, isDeparture: false)
            if let layover = segment.layover {
                Text(layover).nexusTextStyle(NexusText.styles.bodySmall)
                    .foregroundStyle(NexusSemanticColors.textSecondary)
            }
        }
        .padding(.leading, timelineWidth)
        .backgroundPreferenceValue(TimelineCodeAnchorsKey.self) { anchors in
            GeometryReader { geometry in
                Canvas { context, _ in
                    guard let departure = anchors.departure, let arrival = anchors.arrival else { return }
                    let start = geometry[departure].midY
                    let end = geometry[arrival].midY
                    let radius = NexusSpacing.space12 / 2
                    guard end > start + 2 * radius else { return }
                    let centerX = timelineWidth / 2
                    var connector = Path()
                    connector.move(to: CGPoint(x: centerX, y: start + radius))
                    connector.addLine(to: CGPoint(x: centerX, y: end - radius))
                    context.stroke(connector, with: .color(NexusSemanticColors.borderDefault),
                                   style: StrokeStyle(lineWidth: NexusBorder.hairline,
                                                      dash: [dashLength, dashLength]))
                    for y in [start, end] {
                        let dot = Path(ellipseIn: CGRect(x: centerX - radius, y: y - radius,
                                                          width: 2 * radius, height: 2 * radius))
                        context.stroke(dot, with: .color(NexusSemanticColors.brandPrimary.opacity(NexusOpacity.flightTimelineMarker)),
                                       lineWidth: NexusBorder.iconStroke)
                    }
                }
                .accessibilityHidden(true)
            }
        }
        .overlayPreferenceValue(TimelineCodeAnchorsKey.self) { anchors in
            GeometryReader { geometry in
                if let departure = anchors.departure, let arrival = anchors.arrival {
                    let centerY = (geometry[departure].midY + geometry[arrival].midY) / 2
                    Text(segment.detail)
                        .nexusTextStyle(NexusText.styles.bodySmall)
                        .foregroundStyle(NexusSemanticColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.vertical, NexusSpacing.space4)
                        .padding(.horizontal, NexusSpacing.space4)
                        .frame(width: timelineWidth)
                        .background(surface)
                        .position(x: timelineWidth / 2, y: centerY)
                }
            }
        }
    }

    @ViewBuilder private func endpoint(_ code: String, name: String?, time: String, isDeparture: Bool) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: NexusSpacing.space4) {
                airportLabel(code, name: name, isDeparture: isDeparture)
                Text(time).nexusTextStyle(NexusText.styles.flightTime)
            }
            .foregroundStyle(NexusSemanticColors.textHeading)
        } else {
            HStack(alignment: .firstTextBaseline, spacing: NexusSpacing.space8) {
                airportLabel(code, name: name, isDeparture: isDeparture)
                Spacer(minLength: NexusSpacing.space0)
                Text(time).nexusTextStyle(NexusText.styles.flightTime)
                    .lineLimit(1)
                    .minimumScaleFactor(NexusLayout.flightTimeMinimumScale)
            }
            .foregroundStyle(NexusSemanticColors.textHeading)
        }
    }

    private func airportLabel(_ code: String, name: String?, isDeparture: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: NexusSpacing.space8) {
            codeText(code, isDeparture: isDeparture)
            if let name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               name.trimmingCharacters(in: .whitespacesAndNewlines).localizedCaseInsensitiveCompare(code) != .orderedSame {
                Text(name).nexusTextStyle(NexusText.styles.bodySmall)
                    .foregroundStyle(NexusSemanticColors.textSecondary)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
            }
        }
    }

    private func codeText(_ code: String, isDeparture: Bool) -> some View {
        Text(code)
            .nexusTextStyle(NexusText.styles.airportCode)
            .anchorPreference(key: TimelineCodeAnchorsKey.self, value: .bounds) { anchor in
                isDeparture ? TimelineCodeAnchors(departure: anchor) : TimelineCodeAnchors(arrival: anchor)
            }
    }
}

private struct TimelineCodeAnchors {
    var departure: Anchor<CGRect>?
    var arrival: Anchor<CGRect>?
}

private struct TimelineCodeAnchorsKey: PreferenceKey {
    static let defaultValue = TimelineCodeAnchors()

    static func reduce(value: inout TimelineCodeAnchors, nextValue: () -> TimelineCodeAnchors) {
        let next = nextValue()
        value.departure = next.departure ?? value.departure
        value.arrival = next.arrival ?? value.arrival
    }
}
