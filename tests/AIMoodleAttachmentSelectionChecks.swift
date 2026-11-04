import Foundation

@main
struct AIMoodleAttachmentSelectionChecks {
    static func main() {
        precondition(AIMoodleAttachmentSelection.select(keyword: "", names: ["lecture.pdf"], labels: ["Announcement"]) == 0)
        precondition(AIMoodleAttachmentSelection.select(keyword: "", names: ["a.pdf", "b.pdf"], labels: ["A", "B"]) == nil)
        precondition(AIMoodleAttachmentSelection.select(keyword: "WEEK 3", names: ["week3.pdf", "week4.pdf"], labels: ["A", "A"]) == 0)
        precondition(AIMoodleAttachmentSelection.select(keyword: "考試說明", names: ["notes.pdf"], labels: ["公告 期中考試說明"]) == 0)
        precondition(AIMoodleAttachmentSelection.select(keyword: "考試說明", names: ["a.pdf", "b.pdf"], labels: ["考試說明", "考試說明"]) == nil)
        precondition(AIMoodleAttachmentSelection.select(keyword: "no-match", names: ["a.pdf"], labels: ["A"]) == nil)
        precondition(AIMoodleAttachmentSelection.select(keyword: "a.pdf", names: ["a.pdf", "aa.pdf"], labels: ["A", "B"]) == 0)
        precondition(AIMoodleAttachmentSelection.select(keyword: "a.pdf", names: ["a.pdf", "a.pdf"], labels: ["A", "B"]) == nil)
        precondition(AIMoodleAttachmentSelection.select(keyword: "", names: [], labels: []) == nil)
        let parsed = AIContextRequest.parse(#"{"sources":["moodleContent"],"courseKeyword":"R course","moodleFileKeyword":"week3.pdf","readMoodleFiles":true}"#, allowed: [.moodleContent])!
        precondition(parsed.moodleFileKeyword == "week3.pdf" && !parsed.readMoodleFiles)
        precondition(AIContextRequest.parse(#"{"sources":["moodleContent"],"moodleFileKeyword":"https://example.test/file"}"#, allowed: [.moodleContent]) == nil)
        precondition(AIContextRequest.parse(#"{"sources":["moodleContent"],"moodleFileKeyword":"latest"}"#, allowed: [])?.sources.isEmpty == true)
        let upload = AIUploadAttachment(name: "<original>&.pdf", mimeType: "application/pdf", data: Data([1, 2, 3]), isMoodle: true)
        precondition(upload.isValid && !upload.uploadName.contains("<") && upload.data == Data([1, 2, 3]))
        precondition(!AIUploadAttachment(name: "empty.pdf", mimeType: "application/pdf", data: Data()).isValid)
        print("PASS: unique attachment, ambiguous names, exact/partial filename, announcement labels and missing matches")
    }
}
