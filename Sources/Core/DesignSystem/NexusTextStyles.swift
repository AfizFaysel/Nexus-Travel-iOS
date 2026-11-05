import SwiftUI

/// An embedded Plus Jakarta Sans font face used by Nexus typography.
enum NexusFontWeight: String, Sendable {
    /// The regular font face.
    case regular = "PlusJakartaSans-Regular"

    /// The medium font face.
    case medium = "PlusJakartaSans-Medium"

    /// The semibold font face.
    case semibold = "PlusJakartaSans-SemiBold"

    /// The bold font face.
    case bold = "PlusJakartaSans-Bold"

    /// The extra-bold font face.
    case extrabold = "PlusJakartaSans-ExtraBold"

    /// The PostScript name stored in the embedded font metadata.
    var postScriptName: String { rawValue }
}

/// A semantic Nexus text style that preserves Android base metrics while supporting Dynamic Type.
struct NexusTextStyle: Sendable {
    /// The embedded font face.
    let fontWeight: NexusFontWeight

    /// The Android base font size in points at the default content size.
    let baseSize: CGFloat

    /// The Android base line height in points at the default content size.
    let baseLineHeight: CGFloat

    /// The Apple text role that controls Dynamic Type scaling.
    let relativeTo: Font.TextStyle

    /// Whether the style uses tabular figures for stable numeric alignment.
    let usesTabularNumbers: Bool

    /// The custom SwiftUI font scaled relative to its semantic Apple text role.
    var font: Font {
        .custom(fontWeight.postScriptName, size: baseSize, relativeTo: relativeTo)
    }

    init(
        fontWeight: NexusFontWeight,
        baseSize: CGFloat,
        baseLineHeight: CGFloat,
        relativeTo: Font.TextStyle,
        usesTabularNumbers: Bool = false
    ) {
        self.fontWeight = fontWeight
        self.baseSize = baseSize
        self.baseLineHeight = baseLineHeight
        self.relativeTo = relativeTo
        self.usesTabularNumbers = usesTabularNumbers
    }

    var baseLineSpacing: CGFloat {
        baseLineHeight - baseSize
    }

    /// Returns this semantic style using another bundled font face.
    func withFontWeight(_ fontWeight: NexusFontWeight) -> NexusTextStyle {
        NexusTextStyle(
            fontWeight: fontWeight,
            baseSize: baseSize,
            baseLineHeight: baseLineHeight,
            relativeTo: relativeTo,
            usesTabularNumbers: usesTabularNumbers
        )
    }
}

/// The complete semantic text-style catalog from Android `NexusText.styles`.
struct NexusTravelTextStyles: Sendable {
    /// The largest hero display style.
    let displayHero: NexusTextStyle

    /// The compact hero display style.
    let displayHeroCompact: NexusTextStyle

    /// The primary screen-title style.
    let screenTitle: NexusTextStyle

    /// The primary section-title style.
    let sectionTitle: NexusTextStyle

    /// The compact section-title style.
    let sectionTitleSmall: NexusTextStyle

    /// The standard list-title style.
    let listTitle: NexusTextStyle

    /// The large list-title style.
    let listTitleLarge: NexusTextStyle

    /// The standard body style.
    let body: NexusTextStyle

    /// The large body style.
    let bodyLarge: NexusTextStyle

    /// The small body style.
    let bodySmall: NexusTextStyle

    /// The caption style.
    let caption: NexusTextStyle

    /// The standard control-label style.
    let label: NexusTextStyle

    /// The form-input style.
    let formInput: NexusTextStyle

    /// The button-label style.
    let button: NexusTextStyle

    /// The link style.
    let link: NexusTextStyle

    /// The primary price-amount style.
    let priceAmount: NexusTextStyle

    /// The compact price-amount style.
    let priceAmountSmall: NexusTextStyle

    /// The currency-label style.
    let currencyLabel: NexusTextStyle

    /// The primary flight-time style.
    let flightTime: NexusTextStyle

    /// The compact flight-time style.
    let flightTimeCompact: NexusTextStyle

    /// The airport-code style.
    let airportCode: NexusTextStyle

    /// The duration-and-stop style.
    let durationStop: NexusTextStyle

    /// The booking-reference style.
    let bookingReference: NexusTextStyle

    /// The ticket-number style.
    let ticketNumber: NexusTextStyle

    /// The status-badge style.
    let statusBadge: NexusTextStyle

    /// The inline error-text style.
    let errorText: NexusTextStyle
}

/// The shared Nexus typography namespace.
enum NexusText {
    /// The single semantic typography catalog used by Nexus views.
    static let styles = NexusTravelTextStyles(
        displayHero: NexusTextStyle(fontWeight: .bold, baseSize: 36, baseLineHeight: 44, relativeTo: .largeTitle),
        displayHeroCompact: NexusTextStyle(fontWeight: .bold, baseSize: 32, baseLineHeight: 40, relativeTo: .largeTitle),
        screenTitle: NexusTextStyle(fontWeight: .bold, baseSize: 24, baseLineHeight: 32, relativeTo: .title),
        sectionTitle: NexusTextStyle(fontWeight: .bold, baseSize: 20, baseLineHeight: 28, relativeTo: .title2),
        sectionTitleSmall: NexusTextStyle(fontWeight: .semibold, baseSize: 18, baseLineHeight: 24, relativeTo: .title3),
        listTitle: NexusTextStyle(fontWeight: .semibold, baseSize: 16, baseLineHeight: 22, relativeTo: .headline),
        listTitleLarge: NexusTextStyle(fontWeight: .semibold, baseSize: 18, baseLineHeight: 24, relativeTo: .title3),
        body: NexusTextStyle(fontWeight: .regular, baseSize: 16, baseLineHeight: 24, relativeTo: .body),
        bodyLarge: NexusTextStyle(fontWeight: .regular, baseSize: 18, baseLineHeight: 28, relativeTo: .body),
        bodySmall: NexusTextStyle(fontWeight: .regular, baseSize: 14, baseLineHeight: 20, relativeTo: .subheadline),
        caption: NexusTextStyle(fontWeight: .medium, baseSize: 12, baseLineHeight: 16, relativeTo: .caption),
        label: NexusTextStyle(fontWeight: .medium, baseSize: 14, baseLineHeight: 18, relativeTo: .headline),
        formInput: NexusTextStyle(fontWeight: .regular, baseSize: 17, baseLineHeight: 24, relativeTo: .body),
        button: NexusTextStyle(fontWeight: .semibold, baseSize: 16, baseLineHeight: 20, relativeTo: .headline),
        link: NexusTextStyle(fontWeight: .semibold, baseSize: 16, baseLineHeight: 22, relativeTo: .headline),
        priceAmount: NexusTextStyle(fontWeight: .extrabold, baseSize: 28, baseLineHeight: 34, relativeTo: .title3, usesTabularNumbers: true),
        priceAmountSmall: NexusTextStyle(fontWeight: .extrabold, baseSize: 23, baseLineHeight: 29, relativeTo: .title3, usesTabularNumbers: true),
        currencyLabel: NexusTextStyle(fontWeight: .medium, baseSize: 12, baseLineHeight: 16, relativeTo: .caption),
        flightTime: NexusTextStyle(fontWeight: .bold, baseSize: 22, baseLineHeight: 28, relativeTo: .title3, usesTabularNumbers: true),
        flightTimeCompact: NexusTextStyle(fontWeight: .bold, baseSize: 21, baseLineHeight: 27, relativeTo: .title3, usesTabularNumbers: true),
        airportCode: NexusTextStyle(fontWeight: .bold, baseSize: 18, baseLineHeight: 24, relativeTo: .title3),
        durationStop: NexusTextStyle(fontWeight: .medium, baseSize: 14, baseLineHeight: 18, relativeTo: .subheadline, usesTabularNumbers: true),
        bookingReference: NexusTextStyle(fontWeight: .bold, baseSize: 18, baseLineHeight: 24, relativeTo: .title3, usesTabularNumbers: true),
        ticketNumber: NexusTextStyle(fontWeight: .semibold, baseSize: 16, baseLineHeight: 22, relativeTo: .headline, usesTabularNumbers: true),
        statusBadge: NexusTextStyle(fontWeight: .semibold, baseSize: 12, baseLineHeight: 16, relativeTo: .caption),
        errorText: NexusTextStyle(fontWeight: .medium, baseSize: 14, baseLineHeight: 20, relativeTo: .subheadline)
    )
}

extension View {
    /// Applies a Nexus text style with Dynamic Type line spacing and optional tabular figures.
    func nexusTextStyle(_ style: NexusTextStyle) -> some View {
        modifier(NexusTextStyleModifier(style: style))
    }
}

/// Auth-scoped hierarchy; shared typography and other screens remain unchanged.
enum NexusAuthTypography {
    static let sheetTitle = NexusTextStyle(
        fontWeight: .bold, baseSize: 28, baseLineHeight: 36, relativeTo: .title
    )
}

private struct NexusTextStyleModifier: ViewModifier {
    let style: NexusTextStyle

    @ScaledMetric private var lineSpacing: CGFloat

    init(style: NexusTextStyle) {
        self.style = style
        _lineSpacing = ScaledMetric(
            wrappedValue: style.baseLineSpacing,
            relativeTo: style.relativeTo
        )
    }

    @ViewBuilder
    func body(content: Content) -> some View {
        let styledContent = content
            .font(style.font)
            .lineSpacing(lineSpacing)

        if style.usesTabularNumbers {
            styledContent.monospacedDigit()
        } else {
            styledContent
        }
    }
}
