import Foundation
import CloudKit

@main
struct CommunityImageLoadingChecks {
    @MainActor static func main() async {
        var requests: [String] = []
        let legacyID = "community-topic-original-post"
        let state = CommunityImageLoadState<String>(fetchImage: { id in
            requests.append(id)
            if requests.count == 1 { throw CKError(.unknownItem) }
            return "original-image"
        }, sleep: { _ in })
        await state.load(recordName: legacyID)
        precondition(state.failed && !state.isLoading)
        precondition(state.failure?.kind == .missing && state.failure?.cloudKitCode == CKError.Code.unknownItem.rawValue)
        await state.load(recordName: legacyID)
        precondition(state.image == "original-image" && !state.failed, "A failed record must be retryable")
        precondition(requests == [legacyID, legacyID], "Retry must preserve the exact stored legacy ID")
        await state.load(recordName: legacyID)
        precondition(requests.count == 2, "An already loaded image must not be fetched again")

        var transientAttempts = 0
        var delays: [TimeInterval] = []
        let transient = CommunityImageLoadState<Int>(fetchImage: { _ in
            transientAttempts += 1
            if transientAttempts == 1 { throw CKError(.serviceUnavailable, userInfo: [CKErrorRetryAfterKey: 2.0]) }
            return 7
        }, sleep: { delays.append($0) })
        await transient.load(recordName: "community-topic-original-post-edit-version-1")
        precondition(transient.image == 7 && delays == [2.0], "Transient failures honor CloudKit's retry delay")
        precondition(CommunityImageFailure.retryDelay(for: CKError(.requestRateLimited, userInfo: [CKErrorRetryAfterKey: 30.0]), attempt: 0) == nil)
        precondition(CommunityImageFailure.retryDelay(for: CKError(.unknownItem), attempt: 0) == nil)
        precondition(CommunityImageFailure.retryDelay(for: CKError(.networkFailure), attempt: 1) == nil, "Automatic retry is bounded")
        precondition(CommunityImageFailure(CKError(.missingEntitlement)).kind == .configuration)
        precondition(CommunityImageFailure(CKError(.notAuthenticated)).kind == .account)
        precondition(CommunityImageFailure(CKError(.permissionFailure)).kind == .permission)

        var cancelledAttempts = 0
        let cancelled = CommunityImageLoadState<Int>(fetchImage: { _ in
            cancelledAttempts += 1
            if cancelledAttempts == 1 { throw CancellationError() }
            return 8
        })
        await cancelled.load(recordName: "cancelled")
        precondition(!cancelled.failed && !cancelled.isLoading && cancelled.image == nil)
        await cancelled.load(recordName: "cancelled")
        precondition(cancelled.image == 8, "View cancellation cannot permanently block the record")

        var waiting: [String: CheckedContinuation<String, Error>] = [:]
        let switched = CommunityImageLoadState<String>(fetchImage: { id in
            try await withCheckedThrowingContinuation { waiting[id] = $0 }
        })
        let older = Task { await switched.load(recordName: "old") }
        while waiting["old"] == nil { await Task.yield() }
        let newer = Task { await switched.load(recordName: "new") }
        while waiting["new"] == nil { await Task.yield() }
        waiting["old"]!.resume(returning: "outdated-image")
        await older.value
        precondition(switched.image == nil && switched.isLoading, "Old response must not replace or stop a new request")
        waiting["new"]!.resume(returning: "new-image")
        await newer.value
        precondition(switched.image == "new-image" && !switched.isLoading)

        var pending: CheckedContinuation<String, Error>?
        let taskCancelled = CommunityImageLoadState<String>(fetchImage: { _ in
            try await withCheckedThrowingContinuation { pending = $0 }
        })
        let load = Task { await taskCancelled.load(recordName: "late") }
        while pending == nil { await Task.yield() }
        load.cancel()
        pending!.resume(returning: "discarded")
        await load.value
        precondition(taskCancelled.image == nil && !taskCancelled.failed && !taskCancelled.isLoading)
        print("PASS: legacy IDs preserved; failure/cancellation retry; bounded CloudKit backoff; error classification; stale responses ignored")
    }
}
