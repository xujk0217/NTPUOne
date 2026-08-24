import Foundation
import SwiftUI

struct QuickFeatureItem: Codable, Identifiable, Equatable {
    let id: String
    var title: String
    var systemImage: String
    var destination: String
    var isFavorite: Bool
}

struct NewStudentChecklistItem: Codable, Identifiable, Equatable {
    let id: String
    var title: String
    var detail: String
    var isCompleted: Bool
    var actions: [NewStudentChecklistAction]

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case detail
        case isCompleted
    }

    init(id: String, title: String, detail: String, isCompleted: Bool, actions: [NewStudentChecklistAction] = []) {
        self.id = id
        self.title = title
        self.detail = detail
        self.isCompleted = isCompleted
        self.actions = actions
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        detail = try container.decode(String.self, forKey: .detail)
        isCompleted = try container.decode(Bool.self, forKey: .isCompleted)
        actions = []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(detail, forKey: .detail)
        try container.encode(isCompleted, forKey: .isCompleted)
    }
}

struct NewStudentChecklistAction: Identifiable, Equatable {
    enum Destination: Equatable {
        case external(URL)
        case restaurant
        case ubike
    }

    let id: String
    var label: String
    var systemImage: String
    var destination: Destination
}

struct EventFavorite: Codable, Identifiable, Equatable {
    let id: String
    var title: String
    var source: String
    var dateText: String?
    var link: String?
    var savedAt: Date
}

struct StudentInterest: Codable, Identifiable, Equatable {
    let id: String
    var title: String
    var isSelected: Bool
}

struct TaskTemplate: Codable, Identifiable, Equatable {
    let id: String
    var title: String
    var defaultTag: String
    var isEnabled: Bool
}

@MainActor
final class StudentImpactStore: ObservableObject {
    static let shared = StudentImpactStore()

    @Published private(set) var quickFeatures: [QuickFeatureItem]
    @Published private(set) var checklist: [NewStudentChecklistItem]
    @Published private(set) var eventFavorites: [EventFavorite]
    @Published private(set) var studentInterests: [StudentInterest]
    @Published private(set) var taskTemplates: [TaskTemplate]

    @AppStorage("homeQuickFeatureOrder") private var homeQuickFeatureOrderJSON: String = ""
    @AppStorage("homeQuickFeatureFavorites") private var homeQuickFeatureFavoritesJSON: String = ""
    @AppStorage("newStudentChecklistState") private var newStudentChecklistStateJSON: String = ""
    @AppStorage("eventFavorites") private var eventFavoritesJSON: String = ""
    @AppStorage("studentInterests") private var studentInterestsJSON: String = ""
    @AppStorage("taskTemplatesEnabled") private var taskTemplatesEnabledJSON: String = ""

    init() {
        let order = Self.safeDecode([String].self, from: UserDefaults.standard.string(forKey: "homeQuickFeatureOrder"), fallback: Self.defaultQuickFeatures.map(\.id))
        let favorites = Self.safeDecode(Set<String>.self, from: UserDefaults.standard.string(forKey: "homeQuickFeatureFavorites"), fallback: Set(Self.defaultQuickFeatures.filter(\.isFavorite).map(\.id)))
        let checklistState = Self.safeDecode([String: Bool].self, from: UserDefaults.standard.string(forKey: "newStudentChecklistState"), fallback: [:])
        let events = Self.safeDecode([EventFavorite].self, from: UserDefaults.standard.string(forKey: "eventFavorites"), fallback: [])
        let interests = Self.safeDecode([StudentInterest].self, from: UserDefaults.standard.string(forKey: "studentInterests"), fallback: Self.defaultStudentInterests)
        let templateState = Self.safeDecode([String: Bool].self, from: UserDefaults.standard.string(forKey: "taskTemplatesEnabled"), fallback: [:])

        quickFeatures = Self.mergeQuickFeatures(order: order, favorites: favorites)
        checklist = Self.defaultChecklist.map { item in
            var copy = item
            copy.isCompleted = checklistState[item.id] ?? item.isCompleted
            return copy
        }
        eventFavorites = events
        studentInterests = Self.mergeStudentInterests(interests)
        taskTemplates = Self.defaultTaskTemplates.map { template in
            var copy = template
            copy.isEnabled = templateState[template.id] ?? template.isEnabled
            return copy
        }
    }

    func toggleQuickFeatureFavorite(id: String) {
        guard let index = quickFeatures.firstIndex(where: { $0.id == id }) else { return }
        quickFeatures[index].isFavorite.toggle()
        persistQuickFeatures()
    }

    func moveQuickFeature(from source: IndexSet, to destination: Int) {
        quickFeatures.move(fromOffsets: source, toOffset: destination)
        persistQuickFeatures()
    }

    func applyNewStudentShortcutPreference(isNewStudent: Bool) {
        let checklistID = "new-student-checklist"
        guard let index = quickFeatures.firstIndex(where: { $0.id == checklistID }) else { return }

        var checklistFeature = quickFeatures.remove(at: index)
        checklistFeature.isFavorite = isNewStudent

        if isNewStudent {
            quickFeatures.insert(checklistFeature, at: 0)
        } else {
            quickFeatures.insert(checklistFeature, at: index)
        }

        persistQuickFeatures()
    }

    func setChecklistItem(_ id: String, isCompleted: Bool) {
        guard let index = checklist.firstIndex(where: { $0.id == id }) else { return }
        checklist[index].isCompleted = isCompleted
        persistChecklist()
    }

    func toggleChecklistItem(id: String) {
        guard let item = checklist.first(where: { $0.id == id }) else { return }
        setChecklistItem(id, isCompleted: !item.isCompleted)
    }

    func resetChecklist() {
        checklist = Self.defaultChecklist
        persistChecklist()
    }

    func toggleEventFavorite(_ favorite: EventFavorite) {
        if let index = eventFavorites.firstIndex(where: { $0.id == favorite.id }) {
            eventFavorites.remove(at: index)
        } else {
            eventFavorites.append(favorite)
        }
        eventFavoritesJSON = Self.safeEncode(eventFavorites)
    }

    func isEventFavorite(id: String) -> Bool {
        eventFavorites.contains(where: { $0.id == id })
    }

    func setInterest(_ id: String, isSelected: Bool) {
        if let index = studentInterests.firstIndex(where: { $0.id == id }) {
            studentInterests[index].isSelected = isSelected
        } else if let defaultInterest = Self.defaultStudentInterests.first(where: { $0.id == id }) {
            var copy = defaultInterest
            copy.isSelected = isSelected
            studentInterests.append(copy)
        } else {
            studentInterests.append(StudentInterest(id: id, title: id, isSelected: isSelected))
        }
        studentInterestsJSON = Self.safeEncode(studentInterests)
    }

    func toggleInterest(id: String) {
        let current = studentInterests.first(where: { $0.id == id })?.isSelected ?? false
        setInterest(id, isSelected: !current)
    }

    func setTaskTemplate(_ id: String, isEnabled: Bool) {
        guard let index = taskTemplates.firstIndex(where: { $0.id == id }) else { return }
        taskTemplates[index].isEnabled = isEnabled
        persistTaskTemplates()
    }

    private func persistQuickFeatures() {
        homeQuickFeatureOrderJSON = Self.safeEncode(quickFeatures.map(\.id))
        homeQuickFeatureFavoritesJSON = Self.safeEncode(Set(quickFeatures.filter(\.isFavorite).map(\.id)))
    }

    private func persistChecklist() {
        let state = Dictionary(uniqueKeysWithValues: checklist.map { ($0.id, $0.isCompleted) })
        newStudentChecklistStateJSON = Self.safeEncode(state)
    }

    private func persistTaskTemplates() {
        let state = Dictionary(uniqueKeysWithValues: taskTemplates.map { ($0.id, $0.isEnabled) })
        taskTemplatesEnabledJSON = Self.safeEncode(state)
    }

    static func safeDecode<T: Decodable>(_ type: T.Type, from json: String?, fallback: T) -> T {
        guard let json, !json.isEmpty, let data = json.data(using: .utf8) else { return fallback }
        return (try? JSONDecoder().decode(type, from: data)) ?? fallback
    }

    static func safeEncode<T: Encodable>(_ value: T) -> String {
        guard let data = try? JSONEncoder().encode(value), let json = String(data: data, encoding: .utf8) else {
            return ""
        }
        return json
    }

    private static func mergeQuickFeatures(order: [String], favorites: Set<String>) -> [QuickFeatureItem] {
        var byID = Dictionary(uniqueKeysWithValues: defaultQuickFeatures.map { ($0.id, $0) })
        var ordered = order.compactMap { id -> QuickFeatureItem? in
            guard var item = byID.removeValue(forKey: id) else { return nil }
            item.isFavorite = favorites.contains(id)
            return item
        }
        let remaining = byID.values.sorted { $0.id < $1.id }.map { item -> QuickFeatureItem in
            var copy = item
            copy.isFavorite = favorites.contains(item.id)
            return copy
        }
        ordered.append(contentsOf: remaining)
        return ordered.isEmpty ? defaultQuickFeatures : ordered
    }

    private static func mergeStudentInterests(_ interests: [StudentInterest]) -> [StudentInterest] {
        var merged = interests
        let existingIDs = Set(merged.map(\.id))

        for interest in defaultStudentInterests where !existingIDs.contains(interest.id) {
            merged.append(interest)
        }

        return merged
    }

    static let defaultQuickFeatures: [QuickFeatureItem] = [
        QuickFeatureItem(id: "student-info", title: String(localized: "quick_feature_student_info"), systemImage: "person.text.rectangle", destination: "studentInfo", isFavorite: true),
        QuickFeatureItem(id: "past-exams", title: String(localized: "quick_feature_past_exams"), systemImage: "doc.text.magnifyingglass", destination: "pastExams", isFavorite: true),
        QuickFeatureItem(id: "school-announcements", title: String(localized: "quick_feature_school_announcements"), systemImage: "megaphone", destination: "schoolAnnouncements", isFavorite: true),
        QuickFeatureItem(id: "common-links", title: String(localized: "quick_feature_common_links"), systemImage: "link", destination: "commonLinks", isFavorite: true),
        QuickFeatureItem(id: "ubike", title: "Ubike", systemImage: "bicycle", destination: "ubike", isFavorite: true),
        QuickFeatureItem(id: "campus-map", title: String(localized: "campus_map_title"), systemImage: "map", destination: "campusMap", isFavorite: true),
        QuickFeatureItem(id: "lms", title: String(localized: "web_lms"), systemImage: "graduationcap.circle", destination: "lms", isFavorite: true),
        QuickFeatureItem(id: "course-reviews", title: String(localized: "quick_feature_course_reviews"), systemImage: "ellipsis.message", destination: "courseReviews", isFavorite: true),
        QuickFeatureItem(id: "leave-system", title: String(localized: "quick_feature_leave_system"), systemImage: "figure.mind.and.body", destination: "leaveSystem", isFavorite: true),
        QuickFeatureItem(id: "library", title: String(localized: "quick_feature_library"), systemImage: "book.closed", destination: "library", isFavorite: true),
        QuickFeatureItem(id: "food-wheel", title: String(localized: "quick_feature_food_wheel"), systemImage: "chart.pie", destination: "foodWheel", isFavorite: true),
        QuickFeatureItem(id: "new-student-checklist", title: String(localized: "new_student_checklist_title"), systemImage: "checklist.checked", destination: "newStudentChecklist", isFavorite: true)
    ]

    static let defaultChecklist: [NewStudentChecklistItem] = [
        NewStudentChecklistItem(id: "open-student-info", title: String(localized: "new_student_checklist_student_info_title"), detail: String(localized: "new_student_checklist_student_info_detail"), isCompleted: false, actions: [
            NewStudentChecklistAction(id: "open-student-info-url", label: String(localized: "new_student_checklist_open_action"), systemImage: "safari", destination: .external(URL(string: "https://cof.ntpu.edu.tw/student_new.htm")!))
        ]),
        NewStudentChecklistItem(id: "course-selection", title: String(localized: "new_student_checklist_course_selection_title"), detail: String(localized: "new_student_checklist_course_selection_detail"), isCompleted: false, actions: [
            NewStudentChecklistAction(id: "course-selection-url", label: String(localized: "new_student_checklist_open_action"), systemImage: "safari", destination: .external(URL(string: "https://sea.cc.ntpu.edu.tw/pls/dev_stud/course_query_all.chi_main")!))
        ]),
        NewStudentChecklistItem(id: "past-exams", title: String(localized: "new_student_checklist_past_exams_title"), detail: String(localized: "new_student_checklist_past_exams_detail"), isCompleted: false, actions: [
            NewStudentChecklistAction(id: "past-exams-url", label: String(localized: "new_student_checklist_open_action"), systemImage: "safari", destination: .external(URL(string: "https://past-exam.ntpu.cc")!))
        ]),
        NewStudentChecklistItem(id: "login-lms", title: String(localized: "new_student_checklist_lms_title"), detail: String(localized: "new_student_checklist_lms_detail"), isCompleted: false, actions: [
            NewStudentChecklistAction(id: "login-lms-url", label: String(localized: "new_student_checklist_open_action"), systemImage: "safari", destination: .external(URL(string: "https://lms3.ntpu.edu.tw/")!))
        ]),
        NewStudentChecklistItem(id: "join-clubs", title: String(localized: "new_student_checklist_clubs_title"), detail: String(localized: "new_student_checklist_clubs_detail"), isCompleted: false, actions: [
            NewStudentChecklistAction(id: "join-clubs-url", label: String(localized: "new_student_checklist_open_action"), systemImage: "safari", destination: .external(URL(string: "https://www.extracurricular-activities-section.com.tw/")!))
        ]),
        NewStudentChecklistItem(id: "library-login", title: String(localized: "new_student_checklist_library_title"), detail: String(localized: "new_student_checklist_library_detail"), isCompleted: false, actions: [
            NewStudentChecklistAction(id: "library-login-url", label: String(localized: "new_student_checklist_open_action"), systemImage: "safari", destination: .external(URL(string: "https://library.ntpu.edu.tw/masses/showMassesLogin")!))
        ]),
        NewStudentChecklistItem(id: "campus-directory", title: String(localized: "new_student_checklist_directory_title"), detail: String(localized: "new_student_checklist_directory_detail"), isCompleted: false, actions: [
            NewStudentChecklistAction(id: "campus-directory-url", label: String(localized: "new_student_checklist_open_action"), systemImage: "safari", destination: .external(URL(string: "https://sea.cc.ntpu.edu.tw/pls/ld/campus_dir_m.main")!))
        ]),
        NewStudentChecklistItem(id: "student-union", title: String(localized: "new_student_checklist_student_union_title"), detail: String(localized: "new_student_checklist_student_union_detail"), isCompleted: false, actions: [
            NewStudentChecklistAction(id: "student-union-url", label: String(localized: "new_student_checklist_open_action"), systemImage: "safari", destination: .external(URL(string: "https://linktr.ee/ntpusu")!))
        ]),
        NewStudentChecklistItem(id: "food-traffic", title: String(localized: "new_student_checklist_food_traffic_title"), detail: String(localized: "new_student_checklist_food_traffic_detail"), isCompleted: false, actions: foodTrafficActions)
    ]

    private static var foodTrafficActions: [NewStudentChecklistAction] {
        #if canImport(FirebaseCore) && canImport(GoogleMobileAds)
        return [
            NewStudentChecklistAction(id: "food-traffic-restaurant", label: String(localized: "restaurant"), systemImage: "fork.knife", destination: .restaurant),
            NewStudentChecklistAction(id: "food-traffic-ubike", label: "Ubike", systemImage: "bicycle", destination: .ubike)
        ]
        #else
        return []
        #endif
    }

    static let defaultStudentInterests: [StudentInterest] = [
        StudentInterest(id: "activity", title: String(localized: "student_interest_activity"), isSelected: false),
        StudentInterest(id: "club", title: String(localized: "student_interest_club"), isSelected: false),
        StudentInterest(id: "other", title: String(localized: "student_interest_other"), isSelected: false)
    ]

    static let defaultTaskTemplates: [TaskTemplate] = [
        TaskTemplate(id: "homework", title: "作業", defaultTag: "課業", isEnabled: true),
        TaskTemplate(id: "exam", title: "考試", defaultTag: "考試", isEnabled: true),
        TaskTemplate(id: "report", title: "報告", defaultTag: "報告", isEnabled: true),
        TaskTemplate(id: "club-activity", title: "社團活動", defaultTag: "活動", isEnabled: true),
        TaskTemplate(id: "course-add-drop", title: "選課加退選", defaultTag: "選課", isEnabled: true),
        TaskTemplate(id: "course-withdrawal", title: "棄修", defaultTag: "選課", isEnabled: true),
        TaskTemplate(id: "quiz", title: "小考", defaultTag: "考試", isEnabled: true),
        TaskTemplate(id: "midterm-final", title: "期中/期末", defaultTag: "考試", isEnabled: true),
        TaskTemplate(id: "group-report", title: "分組報告", defaultTag: "報告", isEnabled: true)
    ]
}

struct NewStudentChecklistView: View {
    @StateObject private var store = StudentImpactStore.shared
    @Environment(\.openURL) private var openURL
    @State private var showResetConfirmation = false
    @State private var showRestaurantPicker = false
    @State private var goBreakfast = false
    @State private var goLunch = false
    @State private var goDinner = false
    @State private var goMidnightSnack = false
    @State private var goTraffic = false

    private var completedCount: Int {
        store.checklist.filter(\.isCompleted).count
    }

    var body: some View {
        ZStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(String(localized: "new_student_checklist_title"))
                                    .font(.headline)
                                Text(String(localized: "new_student_checklist_subtitle"))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Text("\(completedCount)/\(store.checklist.count)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.blue)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.12), in: Capsule())
                        }

                        ProgressView(value: Double(completedCount), total: Double(max(store.checklist.count, 1)))
                            .tint(.blue)
                    }
                    .padding(.vertical, 6)
                }

                Section {
                    ForEach(store.checklist) { item in
                        VStack(alignment: .leading, spacing: 8) {
                            Button {
                                store.toggleChecklistItem(id: item.id)
                            } label: {
                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: item.isCompleted ? "checkmark.circle" : "circle")
                                        .font(.title3)
                                        .foregroundStyle(item.isCompleted ? .green : .secondary)

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(item.title)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(.primary)
                                        Text(item.detail)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer(minLength: 0)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            if !item.actions.isEmpty {
                                HStack(spacing: 6) {
                                    ForEach(item.actions) { action in
                                        actionChip(action)
                                    }

                                    Spacer(minLength: 0)
                                }
                                .padding(.leading, 32)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text(String(localized: "new_student_checklist_precheck"))
                }
            }

            #if canImport(FirebaseCore) && canImport(GoogleMobileAds)
            NavigationLink(destination: BreakfastView(), isActive: $goBreakfast) { EmptyView() }.hidden()
            NavigationLink(destination: LunchView(), isActive: $goLunch) { EmptyView() }.hidden()
            NavigationLink(destination: dinnerView(), isActive: $goDinner) { EmptyView() }.hidden()
            NavigationLink(destination: MSView(), isActive: $goMidnightSnack) { EmptyView() }.hidden()
            if #available(iOS 17.0, *) {
                NavigationLink(destination: TrafficView(), isActive: $goTraffic) { EmptyView() }.hidden()
            } else {
                NavigationLink(destination: BackTrafficView(), isActive: $goTraffic) { EmptyView() }.hidden()
            }
            #endif
        }
        .navigationTitle(String(localized: "new_student_checklist_title"))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(String(localized: "reset")) {
                    showResetConfirmation = true
                }
                .disabled(completedCount == 0)
            }
        }
        .confirmationDialog(String(localized: "new_student_checklist_reset_title"), isPresented: $showResetConfirmation, titleVisibility: .visible) {
            Button(String(localized: "reset"), role: .destructive) {
                store.resetChecklist()
            }
            Button(String(localized: "cancel"), role: .cancel) { }
        } message: {
            Text(String(localized: "new_student_checklist_reset_hint"))
        }
        .sheet(isPresented: $showRestaurantPicker) {
            restaurantPickerSheet
        }
    }

    private var restaurantPickerSheet: some View {
        NavigationStack {
            List {
                mealPickerRow(icon: "cup.and.saucer", title: String(localized: "breakfast"), tint: .orange) {
                    goBreakfast = true
                    showRestaurantPicker = false
                }

                mealPickerRow(icon: "carrot", title: String(localized: "lunch"), tint: .green) {
                    goLunch = true
                    showRestaurantPicker = false
                }

                mealPickerRow(icon: "wineglass", title: String(localized: "dinner"), tint: .purple) {
                    goDinner = true
                    showRestaurantPicker = false
                }

                mealPickerRow(icon: "moon.stars", title: String(localized: "midnight_snack"), tint: .indigo) {
                    goMidnightSnack = true
                    showRestaurantPicker = false
                }
            }
            .navigationTitle(String(localized: "choose_meal"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "close")) {
                        showRestaurantPicker = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func mealPickerRow(icon: String, title: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(tint)
                    .frame(width: 40)
                Text(title)
                    .font(.headline)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func actionChip(_ action: NewStudentChecklistAction) -> some View {
        Button {
            perform(action)
        } label: {
            Label(action.label, systemImage: action.systemImage)
                .font(.caption.weight(.semibold))
                .labelStyle(.titleAndIcon)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .foregroundStyle(.blue)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(Color.blue.opacity(0.12), in: Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color.blue.opacity(0.16), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(action.label)
    }

    private func perform(_ action: NewStudentChecklistAction) {
        switch action.destination {
        case .external(let url):
            openURL(url)
        case .restaurant:
            showRestaurantPicker = true
        case .ubike:
            goTraffic = true
        }
    }

}
