import Foundation

#if canImport(ActivityKit)
import ActivityKit
#endif

struct NextCourseLiveActivitySnapshot: Codable, Hashable, Identifiable {
    let courseID: String
    let name: String
    let day: String
    let startTime: String
    let location: String
    let teacher: String
    let startsAt: Date
    let endsAt: Date
    let isInProgress: Bool

    var id: String { courseID }
}

struct NextCourseLiveActivityTodoSnapshot: Codable, Hashable, Identifiable {
    let id: String
    let title: String
    let detail: String
    let priority: Int
    let isOverdue: Bool
}

#if canImport(ActivityKit)
@available(iOS 16.1, *)
@available(iOSApplicationExtension 16.1, *)
struct NextCourseLiveActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        let course: NextCourseLiveActivitySnapshot?
        let nextCourse: NextCourseLiveActivitySnapshot?
        let todos: [NextCourseLiveActivityTodoSnapshot]
        let updatedAt: Date
    }

    let activityID: String
}
#endif
