import ActivityKit
import SwiftUI
import WidgetKit

@available(iOSApplicationExtension 16.1, *)
struct NextCourseLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: NextCourseLiveActivityAttributes.self) { context in
            if #available(iOSApplicationExtension 18.0, *) {
                NextCourseLiveActivityAdaptiveView(context: context)
                    .activityBackgroundTint(.black)
                    .activitySystemActionForegroundColor(.white)
            } else {
                TimelineView(.periodic(from: Date(), by: 1)) { timeline in
                    NextCourseLiveActivityLockScreenView(
                        state: context.state,
                        isStale: context.state.isDisplayStale(activityIsStale(context), at: timeline.date),
                        now: timeline.date
                    )
                }
                .activityBackgroundTint(.black)
                .activitySystemActionForegroundColor(.white)
            }
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    TimelineView(.periodic(from: Date(), by: 1)) { timeline in
                        NextCourseLiveActivityTimeView(
                            course: context.state.displayCourse(at: timeline.date),
                            isStale: context.state.isDisplayStale(activityIsStale(context), at: timeline.date),
                            now: timeline.date
                        )
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    NextCourseLiveActivityTodoCountView(todos: context.state.todos)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    TimelineView(.periodic(from: Date(), by: 1)) { timeline in
                        NextCourseLiveActivityExpandedBottomView(
                            state: context.state,
                            isStale: context.state.isDisplayStale(activityIsStale(context), at: timeline.date),
                            now: timeline.date
                        )
                    }
                }
            } compactLeading: {
                Image(systemName: "book.closed")
                    .foregroundStyle(.blue)
            } compactTrailing: {
                TimelineView(.periodic(from: Date(), by: 1)) { timeline in
                    if context.state.isDisplayStale(activityIsStale(context), at: timeline.date) {
                        Text("Refresh")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.secondary)
                    } else if let course = context.state.displayCourse(at: timeline.date) {
                        Text(course.startsAt, style: .time)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.blue)
                    } else {
                        Text("Today")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.secondary)
                    }
                }
            } minimal: {
                Image(systemName: "book.closed")
                    .foregroundStyle(.blue)
            }
            .widgetURL(URL(string: "ntpuone://timetable"))
            .keylineTint(.blue)
        }
        .supplementalActivityFamiliesIfAvailable()
    }
}

@available(iOSApplicationExtension 16.1, *)
private func activityIsStale(_ context: ActivityViewContext<NextCourseLiveActivityAttributes>) -> Bool {
    if #available(iOSApplicationExtension 16.2, *) {
        return context.isStale
    }
    return false
}

@available(iOSApplicationExtension 16.1, *)
private extension WidgetConfiguration {
    func supplementalActivityFamiliesIfAvailable() -> some WidgetConfiguration {
        if #available(iOSApplicationExtension 18.0, *) {
            return self.supplementalActivityFamilies([.small])
        }
        return self
    }
}

@available(iOSApplicationExtension 18.0, *)
private struct NextCourseLiveActivityAdaptiveView: View {
    let context: ActivityViewContext<NextCourseLiveActivityAttributes>
    @Environment(\.activityFamily) private var activityFamily

    var body: some View {
        TimelineView(.periodic(from: Date(), by: 1)) { timeline in
            let resolvedStale = context.state.isDisplayStale(activityIsStale(context), at: timeline.date)
            switch activityFamily {
            case .small:
                NextCourseLiveActivitySmallView(state: context.state, isStale: resolvedStale, now: timeline.date)
            default:
                NextCourseLiveActivityLockScreenView(state: context.state, isStale: resolvedStale, now: timeline.date)
            }
        }
    }
}

@available(iOSApplicationExtension 18.0, *)
private struct NextCourseLiveActivitySmallView: View {
    let state: NextCourseLiveActivityAttributes.ContentState
    let isStale: Bool
    let now: Date

    var body: some View {
        let course = state.displayCourse(at: now)
        VStack(spacing: 4) {
            if let course {
                Text(isStale ? "Needs Refresh" : "Course")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.white.opacity(0.72))
                    .lineLimit(1)

                Text(course.name.isEmpty ? "Course" : course.name)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                if isStale {
                    Text("Open app")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Color.white.opacity(0.72))
                        .lineLimit(1)
                } else {
                    Text("\(timeText(course.startsAt))-\(timeText(course.endsAt))")
                        .font(.caption2.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(Color.cyan)
                        .lineLimit(1)
                }
            } else {
                Image(systemName: state.todos.isEmpty ? "checkmark.circle" : "checklist")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(state.todos.isEmpty ? Color.white.opacity(0.55) : Color.orange)

                Text("No course")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)

                if !state.todos.isEmpty {
                    Text(todoSummary)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.white.opacity(0.72))
                        .lineLimit(1)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(8)
        .background(Color.black, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var todoSummary: String {
        state.todos.count == 1 ? "1 todo" : "\(state.todos.count) todos"
    }

    private func timeText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

@available(iOSApplicationExtension 16.1, *)
private struct NextCourseLiveActivityLockScreenView: View {
    let state: NextCourseLiveActivityAttributes.ContentState
    let isStale: Bool
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                statusIcon
                courseSummary
            }

            if !state.todos.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(displayedTodos) { todo in
                        NextCourseLiveActivityTodoRow(todo: todo)
                    }
                }
            }
        }
        .padding(14)
        // 背景固定為黑（activityBackgroundTint），文字必須走深色模式才會是白字
        .environment(\.colorScheme, .dark)
    }

    private var displayedTodos: ArraySlice<NextCourseLiveActivityTodoSnapshot> {
        state.todos.prefix(state.displayCourse(at: now) == nil ? 3 : 1)
    }

    private var statusIcon: some View {
        Image(systemName: statusIconName)
            .font(.system(size: 22, weight: .semibold))
            .foregroundStyle(statusTint)
            .frame(width: 42, height: 42)
            .background(statusTint.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var courseSummary: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(statusTitle)
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.white.opacity(0.72))

            if let course = state.displayCourse(at: now) {
                Text(course.name.isEmpty ? "Untitled Course" : course.name)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Color.white)
                    .lineLimit(1)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Label(timeRangeText(for: course), systemImage: "clock")
                            .foregroundStyle(Color.cyan)

                        if !course.location.isEmpty {
                            Label(course.location, systemImage: "mappin.and.ellipse")
                                .foregroundStyle(Color.white.opacity(0.72))
                                .lineLimit(1)
                        }
                    }
                    .font(.caption.weight(.semibold))

                    if isStale {
                        Text("Open app to refresh")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.white.opacity(0.72))
                            .lineLimit(1)
                    } else {
                        Text("Class time · \(timeRangeText(for: course))")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.cyan)
                            .lineLimit(1)

                        ProgressView(timerInterval: course.startsAt...course.endsAt, countsDown: false)
                            .tint(.cyan)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 5) {
                    Text("No next course today")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(Color.white)
                        .lineLimit(1)
                    Text(state.todos.isEmpty ? "Today is clear" : "Urgent todos below")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.white.opacity(0.72))
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var statusIconName: String {
        guard let course = state.displayCourse(at: now) else { return "checkmark.circle" }
        return "calendar.badge.clock"
    }

    private var statusTint: Color {
        guard let course = state.displayCourse(at: now) else { return .secondary }
        return .blue
    }

    private var statusTitle: String {
        if isStale { return "Needs Refresh" }
        guard let course = state.displayCourse(at: now) else { return "Today" }
        return "Course"
    }

    private func timeRangeText(for course: NextCourseLiveActivitySnapshot) -> String {
        "\(course.startTime)-\(timeText(course.endsAt))"
    }

    private func timeText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

@available(iOSApplicationExtension 16.1, *)
private struct NextCourseLiveActivityTimeView: View {
    let course: NextCourseLiveActivitySnapshot?
    let isStale: Bool
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if isStale {
                Text("Open")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text("App")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.secondary)
            } else if let course {
                Text("Time")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(course.startsAt, style: .time)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.blue)
            } else {
                Text("Free")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

@available(iOSApplicationExtension 16.1, *)
private struct NextCourseLiveActivityTodoCountView: View {
    let todos: [NextCourseLiveActivityTodoSnapshot]

    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text("Todos")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text("\(todos.count)")
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
        }
    }
}

@available(iOSApplicationExtension 16.1, *)
private struct NextCourseLiveActivityExpandedBottomView: View {
    let state: NextCourseLiveActivityAttributes.ContentState
    let isStale: Bool
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 8) {
                Image(systemName: "book.closed")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.blue)

                VStack(alignment: .leading, spacing: 1) {
                    Text(courseName)
                        .font(.subheadline.weight(.bold))
                        .lineLimit(1)
                    Text(detailText)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    if let course = state.displayCourse(at: now), !isStale {
                        Text("Class time · \(formatTime(course.startsAt))-\(formatTime(course.endsAt))")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.blue)
                            .lineLimit(1)
                    } else if isStale {
                        Text("Open app to refresh")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)
            }

            ForEach(state.todos.prefix(2)) { todo in
                NextCourseLiveActivityTodoRow(todo: todo)
            }
        }
    }

    private var courseName: String {
        guard let course = state.displayCourse(at: now), !course.name.isEmpty else { return "No next course today" }
        return course.name
    }

    private var detailText: String {
        guard let course = state.displayCourse(at: now) else { return state.todos.isEmpty ? "No urgent todos" : "Top urgent todos below" }

        let timeText = "\(formatTime(course.startsAt))-\(formatTime(course.endsAt))"
        if !course.location.isEmpty { return "\(timeText) · \(course.location)" }

        if !course.teacher.isEmpty && !course.day.isEmpty {
            return "\(course.day) · \(course.teacher)"
        }

        if !course.teacher.isEmpty { return course.teacher }
        if !course.day.isEmpty { return course.day }
        return course.startTime
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

@available(iOSApplicationExtension 16.1, *)
private extension NextCourseLiveActivityAttributes.ContentState {
    func displayCourse(at now: Date = Date()) -> NextCourseLiveActivitySnapshot? {
        if let course, now < course.endsAt {
            return course.resolvedProgress(at: now)
        }

        if let nextCourse, now < nextCourse.endsAt {
            return nextCourse.resolvedProgress(at: now)
        }

        return nil
    }

    func isDisplayStale(_ contextIsStale: Bool, at now: Date = Date()) -> Bool {
        guard contextIsStale else { return false }

        if let course, now < course.endsAt {
            return !course.isInProgress && now >= course.startsAt
        }

        if let nextCourse, now < nextCourse.endsAt { return false }
        return true
    }
}

private extension NextCourseLiveActivitySnapshot {
    func isInProgress(at now: Date) -> Bool {
        startsAt <= now && now < endsAt
    }

    func resolvedProgress(at now: Date) -> NextCourseLiveActivitySnapshot {
        NextCourseLiveActivitySnapshot(
            courseID: courseID,
            name: name,
            day: day,
            startTime: startTime,
            location: location,
            teacher: teacher,
            startsAt: startsAt,
            endsAt: endsAt,
            isInProgress: isInProgress(at: now)
        )
    }
}

@available(iOSApplicationExtension 16.1, *)
private struct NextCourseLiveActivityTodoRow: View {
    let todo: NextCourseLiveActivityTodoSnapshot

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(tint)
                .frame(width: 6, height: 6)
            Text(todo.title.isEmpty ? "Untitled todo" : todo.title)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
            Spacer(minLength: 0)
            Text(todo.detail)
                .font(.caption.weight(.bold))
                .foregroundStyle(todo.isOverdue ? .red : .secondary)
                .lineLimit(1)
        }
    }

    private var tint: Color {
        if todo.isOverdue { return .red }
        switch todo.priority {
        case 0: return .red
        case 1: return .orange
        default: return .secondary
        }
    }
}
