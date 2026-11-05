import SwiftUI
import TablerIcons

/// Icon families supported by the centralized product catalog.
enum NexusIconSource: Equatable {
    case system(String)
    case tabler(NexusTablerIconName)
    case custom(String)
}

/// Tabler names approved for Nexus travel objects.
enum NexusTablerIconName: Equatable {
    case home
    case user
    case wallet
    case calendar
    case plane
    case planeDeparture
    case planeArrival
    case buildings
    case car
    case map
    case mapPin
    case armchair
    case briefcase
    case ticket
    case qrCode
    case airport
    case creditCard
    case eye
    case eyeOff
}

/// Platform-control names, with password visibility using the installed Tabler family.
enum NexusPlatformIconName: String {
    case concealedPassword = "eye"
    case deletionRequested = "clock.badge.checkmark"
    case documentAdd = "doc.badge.plus"
    case guestProfile = "person.crop.circle"
    case passengerError = "person.crop.circle.badge.exclamationmark"
    case password = "lock"
    case revealedPassword = "eye.slash"
    case savedTravelers = "person.2"
    case settings = "gearshape"
    case success = "checkmark.circle.fill"
    case unavailableNetwork = "wifi.exclamationmark"
    case warningFilled = "exclamationmark.triangle.fill"

    var source: NexusIconSource {
        switch self {
        case .concealedPassword: .tabler(.eye)
        case .revealedPassword: .tabler(.eyeOff)
        default: .system(rawValue)
        }
    }
}

/// A centrally mapped Apple-only symbol.
struct NexusPlatformIcon: View {
    private let name: NexusPlatformIconName

    /// Creates a decorative Apple-only symbol.
    init(_ name: NexusPlatformIconName) {
        self.name = name
    }

    @ViewBuilder var body: some View {
        switch name.source {
        case let .tabler(tablerName):
            Image(uiImage: tablerName.image.withRenderingMode(.alwaysTemplate))
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .accessibilityHidden(true)
        case let .system(systemName):
            Image(systemName: systemName)
                .accessibilityHidden(true)
        case let .custom(assetName):
            Image(assetName)
            .accessibilityHidden(true)
        }
    }
}

/// Product icon names mirrored from Android.
enum NexusIconName: String, CaseIterable, Equatable, Hashable {
    case home
    case search
    case trips
    case profile
    case more
    case back
    case close
    case chevronDown
    case chevronRight
    case share
    case download
    case wallet
    case calendar
    case filter
    case sort
    case flight
    case flightDeparture
    case flightArrival
    case hotel
    case car
    case map
    case location
    case seat
    case seatAlt
    case seatSide
    case armchair
    case baggage
    case boardingPass
    case ticket
    case qr
    case gate
    case payment
    case shield
    case headset
    case chat
    case phone
    case email
    case help
    case check
    case info
    case warning
    case error
    case clock
    case offline
    case loading
    case bell
    case tag
    case refund
    case `continue`
    case arrowsExchange

    /// Approved visual source for this semantic icon.
    var source: NexusIconSource {
        switch self {
        case .home: .tabler(.home)
        case .trips: .tabler(.ticket)
        case .profile: .tabler(.user)
        case .wallet: .tabler(.wallet)
        case .calendar: .tabler(.calendar)
        case .flight: .tabler(.plane)
        case .flightDeparture: .tabler(.planeDeparture)
        case .flightArrival: .tabler(.planeArrival)
        case .hotel: .tabler(.buildings)
        case .car: .tabler(.car)
        case .map: .tabler(.map)
        case .location: .tabler(.mapPin)
        case .seat: .custom("airline-seat-outline")
        case .armchair: .tabler(.armchair)
        case .baggage: .tabler(.briefcase)
        case .ticket: .tabler(.ticket)
        case .qr: .tabler(.qrCode)
        case .gate: .tabler(.airport)
        case .payment: .tabler(.creditCard)
        case .continue: .custom("continue-outline")
        default: .system(systemName)
        }
    }

    /// Closest native SF Symbol preserving this icon's product meaning.
    var systemName: String {
        switch self {
        case .home: "house"
        case .search: "magnifyingglass"
        case .trips: "ticket"
        case .profile: "person"
        case .more: "ellipsis"
        case .back: "chevron.left"
        case .close: "xmark"
        case .chevronDown: "chevron.down"
        case .chevronRight: "chevron.right"
        case .share: "square.and.arrow.up"
        case .download: "arrow.down.to.line"
        case .wallet: "wallet.bifold"
        case .calendar: "calendar"
        case .filter: "line.3.horizontal.decrease"
        case .sort: "arrow.up.arrow.down"
        case .flight: "airplane"
        case .flightDeparture: "airplane.departure"
        case .flightArrival: "airplane.arrival"
        case .hotel: "building.2"
        case .car: "car"
        case .map: "map"
        case .location: "mappin"
        case .seat: "chair"
        case .seatAlt: "chair.lounge"
        case .seatSide: "figure.roll"
        case .armchair: "chair.lounge"
        case .baggage: "suitcase"
        case .boardingPass: "rectangle"
        case .ticket: "ticket"
        case .qr: "qrcode"
        case .gate: "building.columns"
        case .payment: "creditcard"
        case .shield: "shield"
        case .headset: "headphones"
        case .chat: "message"
        case .phone: "phone"
        case .email: "envelope"
        case .help: "questionmark.circle"
        case .check: "checkmark"
        case .info: "info.circle"
        case .warning: "exclamationmark.triangle"
        case .error: "xmark.circle"
        case .clock: "clock"
        case .offline: "wifi.slash"
        case .loading: "arrow.clockwise"
        case .bell: "bell"
        case .tag: "tag"
        case .refund: "arrow.uturn.left.circle"
        case .continue: "arrow.right"
        case .arrowsExchange: "arrow.left.arrow.right"
        }
    }

    /// Android enum name used by gallery labels.
    var displayName: String {
        rawValue.prefix(1).uppercased() + String(rawValue.dropFirst())
    }
}

/// A centrally sourced Nexus icon with optional VoiceOver labeling.
struct NexusIcon: View {
    private let name: NexusIconName
    private let size: CGFloat
    private let accessibilityLabel: String?

    /// Creates a decorative or explicitly labeled product icon.
    init(
        name: NexusIconName,
        size: CGFloat = NexusIconSize.md,
        accessibilityLabel: String? = nil
    ) {
        self.name = name
        self.size = size
        self.accessibilityLabel = accessibilityLabel
    }

    /// Catalog icon content.
    @ViewBuilder
    var body: some View {
        if let accessibilityLabel {
            icon
                .accessibilityLabel(Text(accessibilityLabel))
        } else {
            icon
                .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private var icon: some View {
        switch name.source {
        case let .system(systemName):
            Image(systemName: systemName)
                .font(.system(size: size))
                .frame(width: size, height: size)
        case let .tabler(tablerName):
            Image(uiImage: tablerName.image.withRenderingMode(.alwaysTemplate))
                .renderingMode(.template)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
        case let .custom(assetName):
            Image(assetName)
                .renderingMode(.template)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
        }
    }
}

private extension NexusTablerIconName {
    var image: UIImage {
        switch self {
        case .home: TablerIcons.homeOutlined
        case .user: TablerIcons.userOutlined
        case .wallet: TablerIcons.walletOutlined
        case .calendar: TablerIcons.calendarOutlined
        case .plane: TablerIcons.planeOutlined
        case .planeDeparture: TablerIcons.planeDepartureOutlined
        case .planeArrival: TablerIcons.planeArrivalOutlined
        case .buildings: TablerIcons.buildingsOutlined
        case .car: TablerIcons.carOutlined
        case .map: TablerIcons.mapOutlined
        case .mapPin: TablerIcons.mapPinOutlined
        case .armchair: TablerIcons.armchairOutlined
        case .briefcase: TablerIcons.briefcaseOutlined
        case .ticket: TablerIcons.ticketOutlined
        case .qrCode: TablerIcons.qrcodeOutlined
        case .airport: TablerIcons.buildingAirportOutlined
        case .creditCard: TablerIcons.creditCardOutlined
        case .eye: TablerIcons.eyeOutlined
        case .eyeOff: TablerIcons.eyeOffOutlined
        }
    }
}
