import Foundation
import OSLog
import Security

/// Keychain accessibility choices supported by session persistence.
enum KeychainAccessibility: Equatable, Sendable {
    case afterFirstUnlockThisDeviceOnly
}

/// Unexpected native Keychain failure.
struct KeychainError: Error, Equatable, Sendable {
    let status: OSStatus
}

/// Minimal async Keychain seam used by secure storage and deterministic tests.
protocol KeychainClient: Sendable {
    func read(service: String, account: String) async throws -> Data?
    func write(
        _ data: Data,
        service: String,
        account: String,
        accessibility: KeychainAccessibility,
        synchronizable: Bool
    ) async throws
    func delete(service: String, account: String) async throws
}

/// Native Security-framework Keychain adapter.
struct SecurityKeychainClient: KeychainClient {
    func read(service: String, account: String) async throws -> Data? {
        let query = Self.readQuery(service: service, account: account)
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        switch status {
        case errSecSuccess:
            guard let data = result as? Data else { throw KeychainError(status: errSecDecode) }
            return data
        case errSecItemNotFound:
            return nil
        default:
            Logger(subsystem: "com.nexustravel.NexusTravel", category: "Auth").error(
                "Keychain read failed status=\(status, privacy: .public)"
            )
            throw KeychainError(status: status)
        }
    }

    func write(
        _ data: Data,
        service: String,
        account: String,
        accessibility: KeychainAccessibility,
        synchronizable: Bool
    ) async throws {
        let item = Self.writeQuery(
            data: data,
            service: service,
            account: account,
            accessibility: accessibility,
            synchronizable: synchronizable
        )
        let match = Self.deleteQuery(service: service, account: account)
        let attributes: [CFString: Any] = [
            kSecValueData: data,
            kSecAttrAccessible: Self.nativeAccessibility(accessibility)
        ]
        let updateStatus = SecItemUpdate(match as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess { return }
        guard updateStatus == errSecItemNotFound else { throw KeychainError(status: updateStatus) }

        let addStatus = SecItemAdd(item as CFDictionary, nil)
        guard addStatus == errSecSuccess else { throw KeychainError(status: addStatus) }
    }

    func delete(service: String, account: String) async throws {
        let status = SecItemDelete(Self.deleteQuery(service: service, account: account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError(status: status)
        }
    }

    // Security.framework requires heterogeneous CFDictionary queries; these factories keep that
    // unavoidable `Any` use at the native boundary and make every security attribute testable.
    static func readQuery(service: String, account: String) -> [CFString: Any] {
        var query = deleteQuery(service: service, account: account)
        query[kSecReturnData] = true
        query[kSecMatchLimit] = kSecMatchLimitOne
        return query
    }

    static func writeQuery(
        data: Data,
        service: String,
        account: String,
        accessibility: KeychainAccessibility,
        synchronizable: Bool
    ) -> [CFString: Any] {
        var query = deleteQuery(service: service, account: account)
        query[kSecValueData] = data
        query[kSecAttrAccessible] = nativeAccessibility(accessibility)
        query[kSecAttrSynchronizable] = synchronizable
        return query
    }

    static func deleteQuery(service: String, account: String) -> [CFString: Any] {
        [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecAttrSynchronizable: false
        ]
    }

    private static func nativeAccessibility(_ accessibility: KeychainAccessibility) -> CFString {
        switch accessibility {
        case .afterFirstUnlockThisDeviceOnly:
            kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        }
    }
}
