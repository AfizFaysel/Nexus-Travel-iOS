import CoreGraphics
import SwiftUI

/// Android-mirrored spacing tokens in points.
enum NexusSpacing {
    static let space0: CGFloat = 0
    static let space2: CGFloat = 2
    static let space4: CGFloat = 4
    static let space8: CGFloat = 8
    static let space12: CGFloat = 12
    static let space16: CGFloat = 16
    static let space20: CGFloat = 20
    static let space24: CGFloat = 24
    static let space32: CGFloat = 32
    static let space40: CGFloat = 40
    static let space48: CGFloat = 48
    static let space56: CGFloat = 56
    static let space64: CGFloat = 64
}

/// Available Android-mirrored adaptive spacing modes.
enum NexusSpacingMode: Equatable {
    case compact
    case regular
    case spacious
}

/// Android-mirrored spacing selected from valid screen geometry.
struct NexusAdaptiveSpacing: Equatable {
    let mode: NexusSpacingMode
    let screenMargin: CGFloat
    let screenTopPadding: CGFloat
    let sectionGap: CGFloat
    let sectionGapCompact: CGFloat
    let componentPadding: CGFloat
    let componentPaddingCompact: CGFloat
    let formFieldGap: CGFloat
    let formGroupGap: CGFloat
    let listGap: CGFloat
    let rowPaddingH: CGFloat
    let chipGap: CGFloat
    let bottomSheetPaddingH: CGFloat
    let stickyCtaPaddingH: CGFloat
    let stickyCtaPaddingV: CGFloat
    let stickyCtaZoneMinHeight: CGFloat
    let contentBottomPaddingWithCta: CGFloat

    /// Creates adaptive spacing for finite, positive screen dimensions.
    ///
    /// - Parameters:
    ///   - screenWidth: Screen width in points.
    ///   - screenHeight: Screen height in points.
    init?(screenWidth: CGFloat, screenHeight: CGFloat) {
        guard screenWidth.isFinite,
              screenHeight.isFinite,
              screenWidth > 0,
              screenHeight > 0
        else {
            return nil
        }

        let mode: NexusSpacingMode
        if screenWidth <= 360 || screenHeight <= 720 {
            mode = .compact
        } else if screenWidth >= 430 && screenHeight >= 840 {
            mode = .spacious
        } else {
            mode = .regular
        }

        self = switch mode {
        case .compact:
            Self(
                mode: mode,
                screenMargin: 16,
                screenTopPadding: 16,
                sectionGap: 24,
                sectionGapCompact: 16,
                componentPadding: 16,
                componentPaddingCompact: 14,
                formFieldGap: 12,
                formGroupGap: 20,
                listGap: 12,
                rowPaddingH: 16,
                chipGap: 8,
                bottomSheetPaddingH: 16,
                stickyCtaPaddingH: 16,
                stickyCtaPaddingV: 12,
                stickyCtaZoneMinHeight: 88,
                contentBottomPaddingWithCta: 112
            )
        case .regular:
            Self(
                mode: mode,
                screenMargin: 24,
                screenTopPadding: 24,
                sectionGap: 32,
                sectionGapCompact: 24,
                componentPadding: 20,
                componentPaddingCompact: 16,
                formFieldGap: 16,
                formGroupGap: 24,
                listGap: 16,
                rowPaddingH: 16,
                chipGap: 8,
                bottomSheetPaddingH: 24,
                stickyCtaPaddingH: 24,
                stickyCtaPaddingV: 12,
                stickyCtaZoneMinHeight: 96,
                contentBottomPaddingWithCta: 128
            )
        case .spacious:
            Self(
                mode: mode,
                screenMargin: 24,
                screenTopPadding: 32,
                sectionGap: 40,
                sectionGapCompact: 32,
                componentPadding: 24,
                componentPaddingCompact: 20,
                formFieldGap: 16,
                formGroupGap: 32,
                listGap: 16,
                rowPaddingH: 20,
                chipGap: 12,
                bottomSheetPaddingH: 24,
                stickyCtaPaddingH: 24,
                stickyCtaPaddingV: 16,
                stickyCtaZoneMinHeight: 104,
                contentBottomPaddingWithCta: 144
            )
        }
    }

    private init(
        mode: NexusSpacingMode,
        screenMargin: CGFloat,
        screenTopPadding: CGFloat,
        sectionGap: CGFloat,
        sectionGapCompact: CGFloat,
        componentPadding: CGFloat,
        componentPaddingCompact: CGFloat,
        formFieldGap: CGFloat,
        formGroupGap: CGFloat,
        listGap: CGFloat,
        rowPaddingH: CGFloat,
        chipGap: CGFloat,
        bottomSheetPaddingH: CGFloat,
        stickyCtaPaddingH: CGFloat,
        stickyCtaPaddingV: CGFloat,
        stickyCtaZoneMinHeight: CGFloat,
        contentBottomPaddingWithCta: CGFloat
    ) {
        self.mode = mode
        self.screenMargin = screenMargin
        self.screenTopPadding = screenTopPadding
        self.sectionGap = sectionGap
        self.sectionGapCompact = sectionGapCompact
        self.componentPadding = componentPadding
        self.componentPaddingCompact = componentPaddingCompact
        self.formFieldGap = formFieldGap
        self.formGroupGap = formGroupGap
        self.listGap = listGap
        self.rowPaddingH = rowPaddingH
        self.chipGap = chipGap
        self.bottomSheetPaddingH = bottomSheetPaddingH
        self.stickyCtaPaddingH = stickyCtaPaddingH
        self.stickyCtaPaddingV = stickyCtaPaddingV
        self.stickyCtaZoneMinHeight = stickyCtaZoneMinHeight
        self.contentBottomPaddingWithCta = contentBottomPaddingWithCta
    }
}

/// Android-mirrored corner-radius tokens in points.
enum NexusRadius {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 24
    static let xxxl: CGFloat = 32
}

/// Android-mirrored layout tokens in points.
enum NexusLayout {
    static let screenMargin: CGFloat = 24
    static let screenMarginCompact: CGFloat = 16
    static let inputHeight: CGFloat = 56
    static let buttonHeight: CGFloat = 56
    static let authControlHeight: CGFloat = 60
    static let touchMin: CGFloat = 44
    static let touchRecommended: CGFloat = 48
    static let bottomCtaMinHeight: CGFloat = 88
    static let stickyCtaButtonWidthCompact: CGFloat = 144
    static let stickyCtaButtonWidthRegular: CGFloat = 164
    static let stickyCtaButtonWidthSpacious: CGFloat = 180
    static let mainBottomBarHeight: CGFloat = 78
    static let iconDefault: CGFloat = 24
    static let iconSmall: CGFloat = 20
    static let iconLarge: CGFloat = 32
    static let contentMaxWidth: CGFloat = 480
    static let homeContentMaxWidthWide: CGFloat = 720
    static let homeWideLayoutMinimumWidth: CGFloat = 700
    static let formMaxWidth: CGFloat = 360
    static let authCodeMaxWidth: CGFloat = 384
    static let authCodeSheetInitialHeight: CGFloat = 480
    static let homeChoiceSheetInitialHeight: CGFloat = 320
    static let exploreCardMinWidth: CGFloat = 144
    static let exploreCardMaxWidth: CGFloat = 188
    static let exploreDetailHeroCompactHeight: CGFloat = 240
    static let exploreDetailHeroRegularHeight: CGFloat = 280
    static let exploreDetailHeroSpaciousHeight: CGFloat = 320
}

/// Responsive geometry used by Android and iOS search-result rows.
enum NexusSearchResultLayout {
    static let summaryCardHeightCompact: CGFloat = 64
    static let summaryCardHeightRegular: CGFloat = 70
    static let rowVerticalPaddingCompact: CGFloat = 14
    static let rowVerticalPaddingRegular: CGFloat = 16
    static let rowVerticalPaddingSpacious: CGFloat = 18
    static let logoSlotWidthCompact: CGFloat = 40
    static let logoSlotWidthRegular: CGFloat = 44
    static let logoSlotWidthSpacious: CGFloat = 48
    static let logoSlotHeight: CGFloat = 40
    static let legLabelWidthCompact: CGFloat = 26
    static let legLabelWidthRegular: CGFloat = 30
    static let endpointWidthCompact: CGFloat = 72
    static let endpointWidthRegular: CGFloat = 76
    static let endpointWidthSpacious: CGFloat = 78
}

/// iOS shadow values approximating Android surface elevation.
enum NexusElevation {
    static let mainBottomBarAmbientOpacity: Double = 0.08
    static let mainBottomBarAmbientRadius: CGFloat = 12
    static let mainBottomBarAmbientY: CGFloat = 2
    static let mainBottomBarContactOpacity: Double = 0.06
    static let mainBottomBarContactRadius: CGFloat = 3
    static let mainBottomBarContactY: CGFloat = 1
}

/// Android-mirrored border tokens in points.
enum NexusBorder {
    static let hairline: CGFloat = 1
    static let focus: CGFloat = 2
    static let iconStroke: CGFloat = 2
    static let focusOffset: CGFloat = 2
}

/// Android-mirrored icon-size tokens in points.
enum NexusIconSize {
    static let xs: CGFloat = 16
    static let sm: CGFloat = 20
    static let formField: CGFloat = 22
    static let md: CGFloat = 24
    static let lg: CGFloat = 32
    static let xl: CGFloat = 40
    static let xxl: CGFloat = 48
}

/// Android-mirrored motion durations in milliseconds.
enum NexusMotion {
    static let durationFastMillis = 120
    static let durationBaseMillis = 180
    static let durationSheetMillis = 250
    static let durationSuccessMillis = 300
    static let durationShimmerMillis = 1_400
    static let durationFastSeconds = Double(durationFastMillis) / 1_000
    static let homeServiceTransition = Animation.spring(response: 0.4, dampingFraction: 1)
    static let authModeTransition = Animation.spring(response: 0.4, dampingFraction: 1)
    static let reducedHomeServiceTransition = Animation.easeOut(duration: durationFastSeconds)
}
