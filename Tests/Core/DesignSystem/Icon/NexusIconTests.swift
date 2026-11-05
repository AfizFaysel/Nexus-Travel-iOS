import SwiftUI
import Testing
@testable import NexusTravel

@Suite("Nexus icon catalog")
struct NexusIconTests {
    @Test("Catalog retains the ported Android icon names")
    func catalogMirrorsAndroidNames() {
        let expectedNames = [
            "home", "search", "trips", "profile", "users", "device", "sun", "moon", "more", "back", "close",
            "chevronDown", "chevronRight", "share", "download", "wallet", "calendar",
            "filter", "sort", "flight", "flightDeparture", "flightArrival", "hotel", "car",
            "map", "location", "seat", "seatAlt", "seatSide", "armchair", "baggage",
            "boardingPass", "ticket", "qr", "gate", "payment", "shield", "headset", "chat",
            "phone", "whatsApp", "email", "help", "check", "info", "warning", "error", "clock",
            "offline", "loading", "bell", "tag", "refund", "continue", "arrowsExchange"
        ]

        #expect(NexusIconName.allCases.map(\.rawValue) == expectedNames)
    }

    @Test("Travel objects use approved Tabler icons")
    func travelObjectsUseTablerIcons() {
        let expected: [NexusIconName: NexusTablerIconName] = [
            .home: .home,
            .trips: .ticket,
            .profile: .user,
            .wallet: .wallet,
            .calendar: .calendar,
            .flight: .plane,
            .flightDeparture: .planeDeparture,
            .flightArrival: .planeArrival,
            .hotel: .buildings,
            .car: .car,
            .map: .map,
            .location: .mapPin,
            .armchair: .armchair,
            .baggage: .briefcase,
            .ticket: .ticket,
            .qr: .qrCode,
            .gate: .airport,
            .payment: .creditCard
        ]

        for (name, tablerName) in expected {
            #expect(name.source == .tabler(tablerName))
        }
    }

    @Test("Navigation and platform actions remain native")
    func platformActionsRemainNative() {
        let nativeNames: [NexusIconName] = [
            .search, .more, .back, .close,
            .chevronDown, .share, .download, .filter, .sort,
            .shield, .chat, .help, .check, .info, .warning,
            .error, .clock, .offline, .loading, .bell
        ]

        for name in nativeNames {
            guard case let .system(systemName) = name.source else {
                Issue.record("Expected SF Symbol for \(name.rawValue)")
                continue
            }
            #expect(!systemName.isEmpty)
        }
    }

    @Test("Bottom navigation uses Tabler icons")
    func bottomNavigationUsesTablerIcons() {
        #expect(NexusIconName.home.source == .tabler(.home))
        #expect(NexusIconName.map.source == .tabler(.map))
        #expect(NexusIconName.trips.source == .tabler(.ticket))
        #expect(NexusIconName.profile.source == .tabler(.user))
    }

    @Test("Airline seat uses copied Nexus artwork")
    func airlineSeatUsesCustomArtwork() {
        #expect(NexusIconName.seat.source == .custom("airline-seat-outline"))
    }

    @Test("Icons construct decorative and labeled forms")
    @MainActor
    func iconsConstructDecorativeAndLabeledForms() {
        _ = NexusIcon(name: .flight)
        _ = NexusIcon(name: .flight, accessibilityLabel: "Flight")
        _ = NexusIcon(name: .home, size: NexusIconSize.lg, accessibilityLabel: "Home")
    }
}
