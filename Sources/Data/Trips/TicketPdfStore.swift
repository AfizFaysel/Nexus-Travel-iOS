import CryptoKit
import Foundation

struct TicketPdfStore: Sendable {
    let directory: URL

    init(directory: URL? = nil) {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        self.directory = directory ?? appSupport.appending(path: "Tickets", directoryHint: .isDirectory)
    }

    func store(id: String, version: String? = nil, data: Data) throws -> URL {
        guard data.starts(with: Data("%PDF".utf8)) else { throw CocoaError(.fileReadCorruptFile) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = ticketURL(id: id, version: version)
        try data.write(to: url, options: .atomic)
        return url
    }

    func cached(id: String, version: String?) -> CachedTicketResult? {
        let current = ticketURL(id: id, version: version)
        if FileManager.default.fileExists(atPath: current.path) { return .success(current) }
        let prefix = key(for: id) + "."
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return nil }
        let earlier = files.filter { $0.lastPathComponent.hasPrefix(prefix) && $0.pathExtension == "pdf" }
            .max { date(for: $0) < date(for: $1) }
        return earlier.map(CachedTicketResult.previousVersion)
    }

    private func ticketURL(id: String, version: String?) -> URL {
        let name = [key(for: id), version.map(key(for:))].compactMap { $0 }.joined(separator: ".")
        return directory.appending(path: name + ".pdf")
    }

    private func key(for value: String) -> String {
        SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private func date(for url: URL) -> Date {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
    }
}
