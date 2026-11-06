import Network

/// Waits for an unsatisfied network path to become usable while the caller remains active.
enum NetworkRecovery {
    static func waitForConnectionReturn() async -> Bool {
        let monitor = NWPathMonitor()
        let availability = AsyncStream<Bool>(bufferingPolicy: .bufferingNewest(1)) { continuation in
            monitor.pathUpdateHandler = { path in
                continuation.yield(path.status == .satisfied)
            }
            continuation.onTermination = { _ in monitor.cancel() }
            monitor.start(queue: DispatchQueue(label: "com.nexustravel.network-recovery"))
        }
        defer { monitor.cancel() }

        var wasOffline = false
        for await isOnline in availability {
            guard !Task.isCancelled else { return false }
            if isOnline && wasOffline { return true }
            wasOffline = !isOnline
        }
        return false
    }
}
