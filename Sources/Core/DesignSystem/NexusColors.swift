import SwiftUI
import UIKit

/// Android-mirrored primitive and compatibility color tokens.
enum NexusColors {
    static let charcoalPage = Color(argb: 0xFF090B0E)
    static let charcoalSurface = Color(argb: 0xFF171A1F)
    static let charcoalMuted = Color(argb: 0xFF242830)
    static let charcoalText = Color(argb: 0xFFEDF0F4)
    static let charcoalSecondary = Color(argb: 0xFFB8BEC9)
    static let charcoalOutline = Color(argb: 0xFF79828F)
    static let charcoalDivider = Color(argb: 0xFF3C424C)
    static let charcoalAction = Color(argb: 0xFFA5C8FF)
    static let charcoalPressed = Color(argb: 0xFF8AB7FA)
    static let charcoalAccentSurface = Color(argb: 0xFF20314A)
    static let charcoalSuccessBg = Color(argb: 0xFF142D23)
    static let charcoalSuccessText = Color(argb: 0xFF8BD9AD)
    static let charcoalWarningBg = Color(argb: 0xFF352A16)
    static let charcoalWarningText = Color(argb: 0xFFF1CB83)
    static let charcoalErrorBg = Color(argb: 0xFF3B2024)
    static let charcoalErrorText = Color(argb: 0xFFFFB4AB)
    static let black = Color(argb: 0xFF000000)
    static let charcoalScrim = black.opacity(NexusOpacity.darkScrim)

    static let blue50 = Color(argb: 0xFFEAF2FF)
    static let blue100 = Color(argb: 0xFFD8E7FF)
    static let blue500 = Color(argb: 0xFF0B63F6)
    static let blue600 = Color(argb: 0xFF0052CC)
    static let blue700 = Color(argb: 0xFF0046B8)

    static let navy950 = Color(argb: 0xFF07162F)

    static let neutral900 = Color(argb: 0xFF111827)
    static let neutral700 = Color(argb: 0xFF4B5B73)
    static let neutral500 = Color(argb: 0xFF6B7280)
    static let neutral300 = Color(argb: 0xFFDDE6F2)
    static let neutral200 = Color(argb: 0xFFE6EDF7)
    static let neutral100 = Color(argb: 0xFFF3F6FA)

    static let white = Color(argb: 0xFFFFFFFF)
    static let background = Color(argb: 0xFFF8FAFC)
    static let surface = white

    static let success50 = Color(argb: 0xFFECFDF3)
    static let successText = Color(argb: 0xFF15803D)

    static let warning50 = Color(argb: 0xFFFFF7ED)
    static let warningText = Color(argb: 0xFFB45309)

    static let error50 = Color(argb: 0xFFFEF2F2)
    static let errorText = Color(argb: 0xFFDC2626)
    static let errorStrong = Color(argb: 0xFFB91C1C)

    static let disabledText = Color(argb: 0xFF9AA7B8)
    static let disabledBg = Color(argb: 0xFFEEF2F7)
    static let overlayScrim = Color(argb: 0x9907162F)
    static let etAirlineGreen = Color(argb: 0xFF2E7D32)
    static let etAirlineYellow = Color(argb: 0xFFFBC02D)
    static let etAirlineRed = Color(argb: 0xFFD32F2F)

    static let brand900 = navy950
    static let brand600 = blue500
    static let brand500 = blue600
    static let brand300 = blue100
    static let brand100 = blue50
    static let blue200 = blue100
    static let blue300 = blue100
    static let blue400 = blue500
    static let blue800 = navy950
    static let navy900 = navy950
    static let ink900 = neutral900
    static let slate700 = neutral700
    static let slate500 = neutral500
    static let slate400 = disabledText
    static let slate300 = neutral300
    static let slate200 = neutral200
    static let slate100 = neutral100
    static let slate50 = neutral100
    static let offWhite = background
    static let lightGray = neutral100
    static let pageBackground = background
    static let success500 = successText
    static let warning500 = warningText
    static let error500 = errorText
    static let info500 = blue500
    static let info50 = blue50
    static let infoText = blue600
    static let neutral600 = neutral500
    static let neutral400 = disabledText
}

/// Android-mirrored semantic color roles.
enum NexusSemanticColors {
    static let brandPrimary = adaptive(NexusColors.blue500, NexusColors.charcoalAction)
    static let brandPressed = adaptive(NexusColors.blue700, NexusColors.charcoalPressed)
    static let brandSoft = adaptive(NexusColors.blue50, NexusColors.charcoalAccentSurface)
    static let textHeading = adaptive(NexusColors.navy950, NexusColors.charcoalText)
    static let textSecondary = adaptive(NexusColors.neutral700, NexusColors.charcoalSecondary)
    static let textTertiary = adaptive(NexusColors.neutral500, NexusColors.charcoalSecondary)
    static let textDisabled = adaptive(NexusColors.disabledText, NexusColors.charcoalOutline)
    static let surfaceBase = adaptive(NexusColors.white, NexusColors.charcoalSurface)
    static let surfaceMuted = adaptive(NexusColors.neutral100, NexusColors.charcoalMuted)
    static let backgroundPage = adaptive(NexusColors.background, NexusColors.charcoalPage)
    static let borderDefault = adaptive(NexusColors.neutral300, NexusColors.charcoalOutline)
    static let borderSubtle = adaptive(NexusColors.neutral200, NexusColors.charcoalDivider)
    static let borderDecorative = adaptive(NexusColors.neutral300, NexusColors.charcoalDivider)
    static let selectionStart = adaptive(NexusColors.blue600, NexusColors.charcoalAction)
    static let selectionEnd = adaptive(NexusColors.blue700, NexusColors.charcoalAction)
    static let searchFieldChevron = adaptive(NexusColors.slate700, NexusColors.charcoalSecondary)
    static let searchPanelShadow = adaptive(NexusColors.navy950, NexusColors.black)
    static let borderFocus = adaptive(NexusColors.blue600, NexusColors.charcoalAction)
    static let actionPrimaryText = adaptive(NexusColors.white, NexusColors.navy950)
    static let successBg = adaptive(NexusColors.success50, NexusColors.charcoalSuccessBg)
    static let successText = adaptive(NexusColors.successText, NexusColors.charcoalSuccessText)
    static let warningBg = adaptive(NexusColors.warning50, NexusColors.charcoalWarningBg)
    static let warningText = adaptive(NexusColors.warningText, NexusColors.charcoalWarningText)
    static let errorBg = adaptive(NexusColors.error50, NexusColors.charcoalErrorBg)
    static let errorText = adaptive(NexusColors.errorText, NexusColors.charcoalErrorText)
    static let disabledBg = adaptive(NexusColors.disabledBg, NexusColors.charcoalMuted)
    static let overlayScrim = adaptive(NexusColors.overlayScrim, NexusColors.charcoalScrim)
    static let textPrimary = textHeading
    static let surfaceElevated = surfaceBase
    static let surfaceSubtle = surfaceMuted
    static let surfaceHover = surfaceMuted
    static let surfaceActive = brandSoft
    static let borderStrong = borderDefault
    static let focus = borderFocus
    static let actionPrimary = brandPrimary
    static let actionPressed = brandPressed
    static let actionSecondary = surfaceBase
    static let actionSecondaryText = textPrimary
    static let link = borderFocus
    static let success = successText
    static let warning = warningText
    static let error = errorText
    static let info = brandPrimary
    static let disabledText = textDisabled
    static let mainBottomBarBorder = adaptive(
        NexusColors.neutral300.opacity(NexusOpacity.mainBottomBarBorder),
        .clear
    )
    static let mainBottomBarShadow = NexusColors.black

    private static func adaptive(_ light: Color, _ dark: Color) -> Color {
        let lightColor = UIColor(light)
        let darkColor = UIColor(dark)
        return Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? darkColor : lightColor
        })
    }
}

private extension Color {
    init(argb: UInt32) {
        self.init(
            .sRGB,
            red: Double((argb >> 16) & 0xFF) / 255,
            green: Double((argb >> 8) & 0xFF) / 255,
            blue: Double(argb & 0xFF) / 255,
            opacity: Double((argb >> 24) & 0xFF) / 255
        )
    }
}
