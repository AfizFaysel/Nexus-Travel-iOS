import SwiftUI
import Testing
import UIKit
@testable import NexusTravel

struct NexusColorsTests {
    @Test func primitiveColorsMatchAndroidArgbValues() throws {
        let contracts: [(name: String, color: Color, rgba: RGBAComponents)] = [
            ("blue50", NexusColors.blue50, .init(red: 234, green: 242, blue: 255)),
            ("blue100", NexusColors.blue100, .init(red: 216, green: 231, blue: 255)),
            ("blue500", NexusColors.blue500, .init(red: 11, green: 99, blue: 246)),
            ("blue600", NexusColors.blue600, .init(red: 0, green: 82, blue: 204)),
            ("blue700", NexusColors.blue700, .init(red: 0, green: 70, blue: 184)),
            ("navy950", NexusColors.navy950, .init(red: 7, green: 22, blue: 47)),
            ("neutral900", NexusColors.neutral900, .init(red: 17, green: 24, blue: 39)),
            ("neutral700", NexusColors.neutral700, .init(red: 75, green: 91, blue: 115)),
            ("neutral500", NexusColors.neutral500, .init(red: 107, green: 114, blue: 128)),
            ("neutral300", NexusColors.neutral300, .init(red: 221, green: 230, blue: 242)),
            ("neutral200", NexusColors.neutral200, .init(red: 230, green: 237, blue: 247)),
            ("neutral100", NexusColors.neutral100, .init(red: 243, green: 246, blue: 250)),
            ("white", NexusColors.white, .init(red: 255, green: 255, blue: 255)),
            ("background", NexusColors.background, .init(red: 248, green: 250, blue: 252)),
            ("success50", NexusColors.success50, .init(red: 236, green: 253, blue: 243)),
            ("successText", NexusColors.successText, .init(red: 21, green: 128, blue: 61)),
            ("warning50", NexusColors.warning50, .init(red: 255, green: 247, blue: 237)),
            ("warningText", NexusColors.warningText, .init(red: 180, green: 83, blue: 9)),
            ("error50", NexusColors.error50, .init(red: 254, green: 242, blue: 242)),
            ("errorText", NexusColors.errorText, .init(red: 220, green: 38, blue: 38)),
            ("errorStrong", NexusColors.errorStrong, .init(red: 185, green: 28, blue: 28)),
            ("disabledText", NexusColors.disabledText, .init(red: 154, green: 167, blue: 184)),
            ("disabledBg", NexusColors.disabledBg, .init(red: 238, green: 242, blue: 247)),
            ("overlayScrim", NexusColors.overlayScrim, .init(red: 7, green: 22, blue: 47, alpha: 153)),
            ("etAirlineGreen", NexusColors.etAirlineGreen, .init(red: 46, green: 125, blue: 50)),
            ("etAirlineYellow", NexusColors.etAirlineYellow, .init(red: 251, green: 192, blue: 45)),
            ("etAirlineRed", NexusColors.etAirlineRed, .init(red: 211, green: 47, blue: 47))
        ]

        for contract in contracts {
            let actual = try rgbaComponents(of: contract.color)
            #expect(actual.isApproximatelyEqual(to: contract.rgba), "\(contract.name) differs from Android")
        }
    }

    @Test func compatibilityAliasesReferenceCanonicalColors() throws {
        let contracts: [(name: String, alias: Color, canonical: Color)] = [
            ("surface", NexusColors.surface, NexusColors.white),
            ("brand900", NexusColors.brand900, NexusColors.navy950),
            ("brand600", NexusColors.brand600, NexusColors.blue500),
            ("brand500", NexusColors.brand500, NexusColors.blue600),
            ("brand300", NexusColors.brand300, NexusColors.blue100),
            ("brand100", NexusColors.brand100, NexusColors.blue50),
            ("blue200", NexusColors.blue200, NexusColors.blue100),
            ("blue300", NexusColors.blue300, NexusColors.blue100),
            ("blue400", NexusColors.blue400, NexusColors.blue500),
            ("blue800", NexusColors.blue800, NexusColors.navy950),
            ("navy900", NexusColors.navy900, NexusColors.navy950),
            ("ink900", NexusColors.ink900, NexusColors.neutral900),
            ("slate700", NexusColors.slate700, NexusColors.neutral700),
            ("slate500", NexusColors.slate500, NexusColors.neutral500),
            ("slate400", NexusColors.slate400, NexusColors.disabledText),
            ("slate300", NexusColors.slate300, NexusColors.neutral300),
            ("slate200", NexusColors.slate200, NexusColors.neutral200),
            ("slate100", NexusColors.slate100, NexusColors.neutral100),
            ("slate50", NexusColors.slate50, NexusColors.neutral100),
            ("offWhite", NexusColors.offWhite, NexusColors.background),
            ("lightGray", NexusColors.lightGray, NexusColors.neutral100),
            ("pageBackground", NexusColors.pageBackground, NexusColors.background),
            ("success500", NexusColors.success500, NexusColors.successText),
            ("warning500", NexusColors.warning500, NexusColors.warningText),
            ("error500", NexusColors.error500, NexusColors.errorText),
            ("info500", NexusColors.info500, NexusColors.blue500),
            ("info50", NexusColors.info50, NexusColors.blue50),
            ("infoText", NexusColors.infoText, NexusColors.blue600),
            ("neutral600", NexusColors.neutral600, NexusColors.neutral500),
            ("neutral400", NexusColors.neutral400, NexusColors.disabledText)
        ]

        for contract in contracts {
            let alias = try rgbaComponents(of: contract.alias)
            let canonical = try rgbaComponents(of: contract.canonical)
            #expect(alias.isApproximatelyEqual(to: canonical), "\(contract.name) differs from its Android canonical color")
        }
    }

    @Test func semanticColorsReferenceAndroidMappings() throws {
        let contracts: [(name: String, semantic: Color, canonical: Color)] = [
            ("brandPrimary", NexusSemanticColors.brandPrimary, NexusColors.blue500),
            ("brandPressed", NexusSemanticColors.brandPressed, NexusColors.blue700),
            ("brandSoft", NexusSemanticColors.brandSoft, NexusColors.blue50),
            ("textHeading", NexusSemanticColors.textHeading, NexusColors.navy950),
            ("textPrimary", NexusSemanticColors.textPrimary, NexusColors.navy950),
            ("textSecondary", NexusSemanticColors.textSecondary, NexusColors.neutral700),
            ("textTertiary", NexusSemanticColors.textTertiary, NexusColors.neutral500),
            ("textDisabled", NexusSemanticColors.textDisabled, NexusColors.disabledText),
            ("surfaceBase", NexusSemanticColors.surfaceBase, NexusColors.white),
            ("surfaceElevated", NexusSemanticColors.surfaceElevated, NexusColors.white),
            ("surfaceMuted", NexusSemanticColors.surfaceMuted, NexusColors.neutral100),
            ("surfaceSubtle", NexusSemanticColors.surfaceSubtle, NexusSemanticColors.surfaceMuted),
            ("surfaceHover", NexusSemanticColors.surfaceHover, NexusColors.neutral100),
            ("surfaceActive", NexusSemanticColors.surfaceActive, NexusColors.blue50),
            ("backgroundPage", NexusSemanticColors.backgroundPage, NexusColors.background),
            ("borderDefault", NexusSemanticColors.borderDefault, NexusColors.neutral300),
            ("borderSubtle", NexusSemanticColors.borderSubtle, NexusColors.neutral200),
            ("borderStrong", NexusSemanticColors.borderStrong, NexusColors.neutral300),
            ("borderFocus", NexusSemanticColors.borderFocus, NexusColors.blue600),
            ("focus", NexusSemanticColors.focus, NexusColors.blue600),
            ("actionPrimary", NexusSemanticColors.actionPrimary, NexusColors.blue500),
            ("actionPressed", NexusSemanticColors.actionPressed, NexusColors.blue700),
            ("actionPrimaryText", NexusSemanticColors.actionPrimaryText, NexusColors.white),
            ("actionSecondary", NexusSemanticColors.actionSecondary, NexusColors.white),
            ("actionSecondaryText", NexusSemanticColors.actionSecondaryText, NexusColors.navy950),
            ("link", NexusSemanticColors.link, NexusColors.blue600),
            ("success", NexusSemanticColors.success, NexusColors.successText),
            ("successBg", NexusSemanticColors.successBg, NexusColors.success50),
            ("successText", NexusSemanticColors.successText, NexusColors.successText),
            ("warning", NexusSemanticColors.warning, NexusColors.warningText),
            ("warningBg", NexusSemanticColors.warningBg, NexusColors.warning50),
            ("warningText", NexusSemanticColors.warningText, NexusColors.warningText),
            ("error", NexusSemanticColors.error, NexusColors.errorText),
            ("errorBg", NexusSemanticColors.errorBg, NexusColors.error50),
            ("errorText", NexusSemanticColors.errorText, NexusColors.errorText),
            ("info", NexusSemanticColors.info, NexusColors.blue500),
            ("disabledText", NexusSemanticColors.disabledText, NexusColors.disabledText),
            ("disabledBg", NexusSemanticColors.disabledBg, NexusColors.disabledBg),
            ("overlayScrim", NexusSemanticColors.overlayScrim, NexusColors.overlayScrim)
        ]

        for contract in contracts {
            let semantic = try rgbaComponents(of: contract.semantic)
            let canonical = try rgbaComponents(of: contract.canonical)
            #expect(semantic.isApproximatelyEqual(to: canonical), "\(contract.name) differs from its Android canonical color")
        }
    }
}

private struct RGBAComponents {
    let red: CGFloat
    let green: CGFloat
    let blue: CGFloat
    let alpha: CGFloat

    init(red: Int, green: Int, blue: Int, alpha: Int = 255) {
        self.red = CGFloat(red) / 255
        self.green = CGFloat(green) / 255
        self.blue = CGFloat(blue) / 255
        self.alpha = CGFloat(alpha) / 255
    }

    init(red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    func isApproximatelyEqual(to other: RGBAComponents) -> Bool {
        let tolerance: CGFloat = 0.000_001
        return abs(red - other.red) < tolerance
            && abs(green - other.green) < tolerance
            && abs(blue - other.blue) < tolerance
            && abs(alpha - other.alpha) < tolerance
    }
}

private func rgbaComponents(of color: Color) throws -> RGBAComponents {
    var red: CGFloat = 0
    var green: CGFloat = 0
    var blue: CGFloat = 0
    var alpha: CGFloat = 0
    let resolved = UIColor(color).resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
    let isRGB = resolved.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
    try #require(isRGB)
    return RGBAComponents(red: red, green: green, blue: blue, alpha: alpha)
}
