import CoreGraphics
import Testing
@testable import NexusTravel

struct NexusTokensTests {
    @Test func scalarTokensMatchAndroidValues() {
        #expect([
            NexusSpacing.space0, NexusSpacing.space2, NexusSpacing.space4,
            NexusSpacing.space8, NexusSpacing.space12, NexusSpacing.space16,
            NexusSpacing.space20, NexusSpacing.space24, NexusSpacing.space32,
            NexusSpacing.space40, NexusSpacing.space48, NexusSpacing.space56,
            NexusSpacing.space64
        ] == [0, 2, 4, 8, 12, 16, 20, 24, 32, 40, 48, 56, 64])

        #expect([
            NexusRadius.xs, NexusRadius.sm, NexusRadius.md, NexusRadius.lg,
            NexusRadius.xl, NexusRadius.xxl, NexusRadius.xxxl
        ] == [4, 8, 12, 16, 20, 24, 32])

        #expect([
            NexusLayout.screenMargin, NexusLayout.screenMarginCompact,
            NexusLayout.inputHeight, NexusLayout.buttonHeight,
            NexusLayout.authControlHeight, NexusLayout.touchMin,
            NexusLayout.touchRecommended, NexusLayout.bottomCtaMinHeight,
            NexusLayout.iconDefault, NexusLayout.iconSmall, NexusLayout.iconLarge,
            NexusLayout.contentMaxWidth, NexusLayout.formMaxWidth
        ] == [24, 16, 56, 56, 60, 44, 48, 88, 24, 20, 32, 480, 360])

        #expect([
            NexusBorder.hairline, NexusBorder.focus,
            NexusBorder.iconStroke, NexusBorder.focusOffset
        ] == [1, 2, 2, 2])

        #expect([
            NexusIconSize.xs, NexusIconSize.sm, NexusIconSize.md,
            NexusIconSize.lg, NexusIconSize.xl, NexusIconSize.xxl
        ] == [16, 20, 24, 32, 40, 48])

        #expect([
            NexusMotion.durationFastMillis, NexusMotion.durationBaseMillis,
            NexusMotion.durationSheetMillis, NexusMotion.durationSuccessMillis,
            NexusMotion.durationShimmerMillis
        ] == [120, 180, 250, 300, 1_400])
        #expect(NexusMotion.durationFastSeconds == 0.12)

        #expect([
            NexusElevation.mainBottomBarAmbientOpacity,
            NexusElevation.mainBottomBarDirectionalOpacity
        ] == [0.035, 0.23])
        #expect([
            NexusElevation.mainBottomBarAmbientRadius,
            NexusElevation.mainBottomBarAmbientY,
            NexusElevation.mainBottomBarDirectionalRadius,
            NexusElevation.mainBottomBarDirectionalY
        ] == [6, 1, 12, 15])
    }

    @Test func mainBottomBarSitsInTheHomeIndicatorBandLikeTheSystemTabBar() {
        // Face ID iPhone portrait, iPhone landscape, iPad, Home-button iPhone, keyboard showing
        #expect([34, 21, 20, 0, 336].map { NexusLayout.mainBottomBarScreenGap(bottomSafeArea: $0) }
                == [21, 12, 12, 12, 348])
    }

    @Test func adaptiveSpacingUsesExactAndroidProfiles() throws {
        let compact = try #require(NexusAdaptiveSpacing(screenWidth: 360, screenHeight: 1_000))
        let regular = try #require(NexusAdaptiveSpacing(screenWidth: 390, screenHeight: 844))
        let spacious = try #require(NexusAdaptiveSpacing(screenWidth: 430, screenHeight: 840))

        #expect(compact.mode == .compact)
        #expect(compact.values == [16, 16, 24, 16, 16, 14, 12, 20, 12, 16, 8, 16, 16, 12, 88, 112])
        #expect(regular.mode == .regular)
        #expect(regular.values == [24, 24, 32, 24, 20, 16, 16, 24, 16, 16, 8, 24, 24, 12, 96, 128])
        #expect(spacious.mode == .spacious)
        #expect(spacious.values == [24, 32, 40, 32, 24, 20, 16, 32, 16, 20, 12, 24, 24, 16, 104, 144])
    }

    @Test func adaptiveSpacingMatchesAndroidBoundaries() throws {
        let widthBoundaryCompact = try #require(NexusAdaptiveSpacing(screenWidth: 360, screenHeight: 1_000))
        let heightBoundaryCompact = try #require(NexusAdaptiveSpacing(screenWidth: 1_000, screenHeight: 720))
        let boundarySpacious = try #require(NexusAdaptiveSpacing(screenWidth: 430, screenHeight: 840))
        let widthBelowSpacious = try #require(NexusAdaptiveSpacing(screenWidth: 429, screenHeight: 840))
        let heightBelowSpacious = try #require(NexusAdaptiveSpacing(screenWidth: 430, screenHeight: 839))
        let ordinaryRegular = try #require(NexusAdaptiveSpacing(screenWidth: 390, screenHeight: 844))

        #expect(widthBoundaryCompact.mode == .compact)
        #expect(heightBoundaryCompact.mode == .compact)
        #expect(boundarySpacious.mode == .spacious)
        #expect(widthBelowSpacious.mode == .regular)
        #expect(heightBelowSpacious.mode == .regular)
        #expect(ordinaryRegular.mode == .regular)
    }

    @Test func adaptiveSpacingRejectsInvalidGeometry() {
        #expect(NexusAdaptiveSpacing(screenWidth: 0, screenHeight: 800) == nil)
        #expect(NexusAdaptiveSpacing(screenWidth: -1, screenHeight: 800) == nil)
        #expect(NexusAdaptiveSpacing(screenWidth: 390, screenHeight: 0) == nil)
        #expect(NexusAdaptiveSpacing(screenWidth: 390, screenHeight: -1) == nil)
        #expect(NexusAdaptiveSpacing(screenWidth: .nan, screenHeight: 800) == nil)
        #expect(NexusAdaptiveSpacing(screenWidth: 390, screenHeight: .nan) == nil)
        #expect(NexusAdaptiveSpacing(screenWidth: .infinity, screenHeight: 800) == nil)
        #expect(NexusAdaptiveSpacing(screenWidth: 390, screenHeight: .infinity) == nil)
    }
}

private extension NexusAdaptiveSpacing {
    var values: [CGFloat] {
        [
            screenMargin,
            screenTopPadding,
            sectionGap,
            sectionGapCompact,
            componentPadding,
            componentPaddingCompact,
            formFieldGap,
            formGroupGap,
            listGap,
            rowPaddingH,
            chipGap,
            bottomSheetPaddingH,
            stickyCtaPaddingH,
            stickyCtaPaddingV,
            stickyCtaZoneMinHeight,
            contentBottomPaddingWithCta
        ]
    }
}
