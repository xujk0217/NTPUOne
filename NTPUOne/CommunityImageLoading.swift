import Foundation
import Combine
import CloudKit

/// User-facing failures contain no record IDs, account details, or raw server messages.
struct CommunityImageFailure: Equatable {
    enum Kind { case network, account, permission, missing, configuration, other }
    let kind: Kind
    let cloudKitCode: Int?

    init(_ error: Error) {
        cloudKitCode = (error as? CKError)?.code.rawValue
        switch (error as? CKError)?.code {
        case .networkFailure, .networkUnavailable, .serviceUnavailable, .requestRateLimited, .zoneBusy, .serverResponseLost:
            kind = .network
        case .notAuthenticated: kind = .account
        case .permissionFailure: kind = .permission
        case .unknownItem: kind = .missing
        case .missingEntitlement, .badContainer, .badDatabase: kind = .configuration
        default: kind = error is URLError ? .network : .other
        }
    }

    var message: String {
        String(localized: "community_image_unavailable_hint")
    }

    static func retryDelay(for error: Error, attempt: Int) -> TimeInterval? {
        guard attempt == 0 else { return nil }
        let failure = Self(error)
        guard failure.kind == .network else { return nil }
        let suggested = (error as? CKError)?.retryAfterSeconds ?? 0.6
        // Longer throttling is left for an explicit retry rather than keeping the UI waiting.
        guard suggested <= 5 else { return nil }
        return max(0.6, suggested)
    }
}

/// A failed or cancelled request can be retried; a late response must not replace a newer image.
@MainActor
final class CommunityImageLoadState<Image>: ObservableObject {
    @Published private(set) var image: Image?
    @Published private(set) var failure: CommunityImageFailure?
    @Published private(set) var isLoading = false
    var failed: Bool { failure != nil }
    private var loadedRecordName: String?
    private var generation = UUID()
    private let fetchImage: (String) async throws -> Image
    private let sleep: (TimeInterval) async throws -> Void

    init(fetchImage: @escaping (String) async throws -> Image,
         sleep: @escaping (TimeInterval) async throws -> Void = { seconds in
             try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
         }) {
        self.fetchImage = fetchImage
        self.sleep = sleep
    }

    func load(recordName: String, force: Bool = false) async {
        if !force, loadedRecordName == recordName, image != nil || isLoading { return }
        let request = UUID()
        generation = request
        loadedRecordName = recordName
        image = nil
        failure = nil
        isLoading = true
        defer { if generation == request { isLoading = false } }
        for attempt in 0...1 {
            do {
                try Task.checkCancellation()
                let result = try await fetchImage(recordName)
                try Task.checkCancellation()
                guard generation == request else { return }
                image = result
                return
            } catch {
                guard generation == request else { return }
                if Task.isCancelled || error is CancellationError || (error as? URLError)?.code == .cancelled { return }
                if let delay = CommunityImageFailure.retryDelay(for: error, attempt: attempt) {
                    do { try await sleep(delay) } catch { return }
                    guard generation == request else { return }
                    continue
                }
                failure = CommunityImageFailure(error)
                return
            }
        }
    }
}
