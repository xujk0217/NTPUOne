import Foundation

@main
struct AIChangeExecutionChecks {
    static func main() {
        let raw = "<ntpu-change>[{\"kind\":\"memo\",\"operation\":\"create\",\"title\":\"閱讀作業\",\"executionID\":\"injected\"},{\"kind\":\"memo\",\"operation\":\"create\",\"title\":\"閱讀作業\"}]</ntpu-change>"
        var proposals = AIChangeProposal.extractAll(from: raw)!
        precondition(proposals.allSatisfy { $0.executionID == nil }, "Model cannot forge local execution IDs")
        for i in proposals.indices { proposals[i].executionID = "message-A:\(i)" }
        var state = AIChangeExecutionState()
        state.mark([proposals[0]], account: "user-A")
        precondition(state.contains(proposals[0], account: "user-A"))
        precondition(!state.contains(proposals[1], account: "user-A"), "Identical titles in one turn remain independent")
        precondition(!state.contains(proposals[0], account: "user-B"), "Status stays account-scoped")
        let pending = proposals.filter { !state.contains($0, account: "user-A") }
        precondition(pending.count == 1)
        state.mark(pending, account: "user-A")
        precondition(proposals.allSatisfy { state.contains($0, account: "user-A") })
        var freshTurn = proposals[0]; freshTurn.executionID = "message-B:0"
        precondition(!state.contains(freshTurn, account: "user-A"), "New requests can intentionally reuse the same text")
        state.mark(proposals, account: "user-A")
        precondition(state.contains(proposals[0], account: "user-A"))
        print("PASS: single/batch execution identity, account isolation, pending selection, model ID rejection")
    }
}
