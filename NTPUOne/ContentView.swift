//
//  ContentView.swift
//  NTPUOne
//
//  Created by 許君愷 on 2024/6/24.
//

import SwiftUI
import CoreData
import UIKit
import FirebaseCore
import FirebaseFirestore
import FirebaseAuth
import FirebaseFunctions
import GoogleSignIn

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var courseData: CourseData
    
    @ObservedObject var webManager = WebManager()
    @ObservedObject var bikeManager = UbikeManager()
    @ObservedObject var weatherManager = WeatherManager()
    @StateObject private var orderManager = OrderManager()
    @ObservedObject var fManager = FManager()
    @StateObject private var memoManager: MemoManager
    @AppStorage("hasCompletedFirstRunOnboarding") private var hasCompletedFirstRunOnboarding = false
    
    @State var selectedTab = 0
    @State private var showFirstRunOnboarding = false
    
    init() {
        let context = CoreDataManager.shared.persistentContainer.viewContext
        self._memoManager = StateObject(wrappedValue: MemoManager(context: context))
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            LinkView(courseData: courseData, memoManager: memoManager).tabItem {
                Image(systemName: "house")
                Text("Main")
            }.tag(0)
            
            TodayView(memoManager: memoManager, courseData: courseData).tabItem {
                Image(systemName: "note.text")
                Text(String(localized: "memo"))
            }.tag(1)
            
            TimeTableView(memoManager: memoManager).tabItem {
                Image(systemName: "list.bullet.clipboard")
                Text(String(localized: "timetable"))
            }.tag(2)

            CommunityView().tabItem {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                Text(String(localized: "community_title"))
            }.tag(3)
            
            AboutView().tabItem {
                Image(systemName: "info.circle")
                Text(String(localized: "my"))
            }.tag(4)
        }
        .onOpenURL { url in
            handleDeepLink(url: url)
        }
        .fullScreenCover(isPresented: $showFirstRunOnboarding) {
            FirstRunOnboardingView {
                hasCompletedFirstRunOnboarding = true
                showFirstRunOnboarding = false
            }
            .interactiveDismissDisabled()
        }
        .onAppear {
            if !hasCompletedFirstRunOnboarding {
                showFirstRunOnboarding = true
            }
        }
    }
    
    private func handleDeepLink(url: URL) {
        if GIDSignIn.sharedInstance.handle(url) { return }
        if Auth.auth().canHandle(url) { return }

        guard url.scheme == "ntpuone" else { return }
        
        switch url.host {
        case "memo":
            // 切換到 Memo 頁面
            selectedTab = 1
        case "timetable":
            // 切換到 Timetable 頁面
            selectedTab = 2
        default:
            break
        }
    }
}

#Preview {
    ContentView()
}

struct FirstRunOnboardingView: View {
    @State private var selection = 0
    let onFinish: () -> Void

    private let pages: [FirstRunOnboardingPage] = [
        .init(
            titleKey: "onboarding_dashboard_title",
            messageKey: "onboarding_dashboard_message",
            systemImage: "rectangle.grid.2x2.fill",
            tint: .blue
        ),
        .init(
            titleKey: "onboarding_timetable_title",
            messageKey: "onboarding_timetable_message",
            systemImage: "calendar.badge.clock",
            tint: .green
        ),
        .init(
            titleKey: "onboarding_community_title",
            messageKey: "onboarding_community_message",
            systemImage: "person.text.rectangle.fill",
            tint: .orange
        ),
        .init(
            titleKey: "onboarding_privacy_title",
            messageKey: "onboarding_privacy_message",
            systemImage: "hand.raised.fill",
            tint: .purple
        )
    ]

    private var isLastPage: Bool {
        selection == pages.count - 1
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                VStack(spacing: 6) {
                    Text(String(localized: "onboarding_welcome_title"))
                        .font(.largeTitle.weight(.bold))
                        .multilineTextAlignment(.center)
                    Text(String(localized: "onboarding_welcome_subtitle"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal)
                .padding(.top, 20)

                TabView(selection: $selection) {
                    ForEach(Array(pages.enumerated()), id: \.element.id) { index, page in
                        FirstRunOnboardingCard(page: page)
                            .padding(.horizontal)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))

                VStack(spacing: 10) {
                    Button {
                        if isLastPage {
                            onFinish()
                        } else {
                            withAnimation(.easeInOut(duration: 0.22)) {
                                selection += 1
                            }
                        }
                    } label: {
                        Text(String(localized: isLastPage ? "onboarding_start_button" : "onboarding_next_button"))
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.blue, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .foregroundStyle(.white)
                    }
                    .accessibilityLabel(String(localized: isLastPage ? "onboarding_start_accessibility" : "onboarding_next_accessibility"))

                    Button(String(localized: "onboarding_skip_button")) {
                        onFinish()
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(String(localized: "onboarding_skip_accessibility"))
                }
                .padding(.horizontal)
                .padding(.bottom, 22)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(String(localized: "onboarding_navigation_title"))
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct FirstRunOnboardingPage: Identifiable {
    let id = UUID()
    let titleKey: LocalizedStringResource
    let messageKey: LocalizedStringResource
    let systemImage: String
    let tint: Color
}

private struct FirstRunOnboardingCard: View {
    let page: FirstRunOnboardingPage

    var body: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 10)

            Image(systemName: page.systemImage)
                .font(.system(size: 48, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(page.tint)
                .frame(width: 94, height: 94)
                .background(page.tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 24, style: .continuous))

            VStack(spacing: 10) {
                Text(String(localized: page.titleKey))
                    .font(.title2.weight(.semibold))
                    .multilineTextAlignment(.center)
                Text(String(localized: page.messageKey))
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }

            Spacer(minLength: 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(.secondarySystemBackground))
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(page.tint.opacity(0.18), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.08), radius: 14, x: 0, y: 7)
        }
        .accessibilityElement(children: .combine)
    }
}

private enum CommunityCategory: String, CaseIterable, Identifiable {
    case all
    case food
    case course
    case campus
    case question
    case trade
    case meetup

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return String(localized: "community_category_all")
        case .food: return String(localized: "community_category_food")
        case .course: return String(localized: "community_category_course")
        case .campus: return String(localized: "community_category_campus")
        case .question: return String(localized: "community_category_question")
        case .trade: return String(localized: "community_category_trade")
        case .meetup: return String(localized: "community_category_meetup")
        }
    }

    var icon: String {
        switch self {
        case .all: return "sparkles"
        case .food: return "fork.knife"
        case .course: return "book.closed.fill"
        case .campus: return "building.columns.fill"
        case .question: return "questionmark.circle.fill"
        case .trade: return "bag.fill"
        case .meetup: return "person.2.fill"
        }
    }

    var tint: Color {
        switch self {
        case .all: return .blue
        case .food: return .orange
        case .course: return .indigo
        case .campus: return .green
        case .question: return .teal
        case .trade: return .purple
        case .meetup: return .pink
        }
    }
}

private struct CommunityTopic: Identifiable, Equatable {
    let id: String
    var title: String
    var body: String
    var category: CommunityCategory
    var authorName: String
    var authorDeviceId: String
    var authorDepartment: String
    var authorEntryYear: String
    var authorShowsYear: Bool
    var authorShowsBadge: Bool = false
    var authorBadgeLevel: Int = CommentBadgeManager.BadgeLevel.newbie.rawValue
    var createdAt: Date
    var replyCount: Int
}

struct CommunityProfile: Equatable {
    var nickname: String
    var deviceId: String
    var schoolEmail: String
    var department: String
    var entryYear: String
    var showDepartment: Bool
    var showYear: Bool
    var showBadge: Bool
    var ownerUid: String
    var ownerEmail: String

    var displayLine: String {
        var parts: [String] = []
        if showDepartment, !department.isEmpty { parts.append(department) }
        if showYear, let gradeLine = currentGradeLine(entryYear: entryYear) { parts.append(gradeLine) }
        if showBadge {
            let badge = CommentBadgeManager.shared.getCurrentBadge()
            parts.append("\(badge.icon) \(badge.title)")
        }
        return parts.joined(separator: " · ")
    }
}

private struct CommunityReply: Identifiable, Equatable {
    let id: String
    var body: String
    var authorName: String
    var authorDeviceId: String
    var authorDepartment: String
    var authorEntryYear: String
    var authorShowsYear: Bool
    var authorShowsBadge: Bool = false
    var authorBadgeLevel: Int = CommentBadgeManager.BadgeLevel.newbie.rawValue
    var createdAt: Date
}

private struct CommunityManagedTopic: Identifiable, Equatable {
    let id: String
    let topicId: String
    var category: CommunityCategory
    var title: String
    var body: String
    var bodyPreview: String
    var createdAt: Date
    var updatedAt: Date
    var isDeleted: Bool

    static func from(_ data: [String: Any]) -> CommunityManagedTopic? {
        guard let topicId = data["topicId"] as? String,
              let rawCategory = data["category"] as? String,
              let category = CommunityCategory(rawValue: rawCategory),
              let title = data["title"] as? String else {
            return nil
        }

        return CommunityManagedTopic(
            id: data["id"] as? String ?? topicId,
            topicId: topicId,
            category: category,
            title: title,
            body: data["body"] as? String ?? data["bodyPreview"] as? String ?? "",
            bodyPreview: data["bodyPreview"] as? String ?? "",
            createdAt: communityDate(from: data["createdAt"]),
            updatedAt: communityDate(from: data["updatedAt"]),
            isDeleted: data["isDeleted"] as? Bool ?? false
        )
    }
}

private struct CommunityManagedReply: Identifiable, Equatable {
    let id: String
    let topicId: String
    let replyId: String
    var category: CommunityCategory?
    var title: String
    var body: String
    var bodyPreview: String
    var createdAt: Date
    var updatedAt: Date
    var isDeleted: Bool

    static func from(_ data: [String: Any]) -> CommunityManagedReply? {
        guard let topicId = data["topicId"] as? String,
              let replyId = data["replyId"] as? String else {
            return nil
        }

        let category = (data["category"] as? String).flatMap(CommunityCategory.init(rawValue:))
        return CommunityManagedReply(
            id: data["id"] as? String ?? "\(topicId)_\(replyId)",
            topicId: topicId,
            replyId: replyId,
            category: category,
            title: data["title"] as? String ?? "",
            body: data["body"] as? String ?? data["bodyPreview"] as? String ?? "",
            bodyPreview: data["bodyPreview"] as? String ?? "",
            createdAt: communityDate(from: data["createdAt"]),
            updatedAt: communityDate(from: data["updatedAt"]),
            isDeleted: data["isDeleted"] as? Bool ?? false
        )
    }
}

private struct CommunityMyContentSnapshot: Equatable {
    var topics: [CommunityManagedTopic]
    var replies: [CommunityManagedReply]
}

final class CommunityContentFunctionsService {
    private let functions = Functions.functions()

    func createTopic(payload: [String: Any], completion: @escaping (Error?) -> Void) {
        call("createCommunityTopic", data: payload) { result in
            completion(result.error)
        }
    }

    func createReply(payload: [String: Any], completion: @escaping (Error?) -> Void) {
        call("createCommunityReply", data: payload) { result in
            completion(result.error)
        }
    }

    fileprivate func listMyContent(deviceSecret: String, completion: @escaping (Result<CommunityMyContentSnapshot, Error>) -> Void) {
        call("listMyCommunityContent", data: ["deviceSecret": deviceSecret]) { result in
            switch result {
            case .success(let data):
                let topicDictionaries = data["topics"] as? [[String: Any]] ?? []
                let replyDictionaries = data["replies"] as? [[String: Any]] ?? []
                completion(.success(CommunityMyContentSnapshot(
                    topics: topicDictionaries.compactMap(CommunityManagedTopic.from),
                    replies: replyDictionaries.compactMap(CommunityManagedReply.from)
                )))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func updateTopic(deviceSecret: String, topicId: String, title: String, body: String, completion: @escaping (Error?) -> Void) {
        call("updateCommunityTopic", data: [
            "deviceSecret": deviceSecret,
            "topicId": topicId,
            "title": title,
            "body": body
        ]) { result in
            completion(result.error)
        }
    }

    func deleteTopic(deviceSecret: String, topicId: String, completion: @escaping (Error?) -> Void) {
        call("deleteCommunityTopic", data: [
            "deviceSecret": deviceSecret,
            "topicId": topicId
        ]) { result in
            completion(result.error)
        }
    }

    func updateReply(deviceSecret: String, topicId: String, replyId: String, body: String, completion: @escaping (Error?) -> Void) {
        call("updateCommunityReply", data: [
            "deviceSecret": deviceSecret,
            "topicId": topicId,
            "replyId": replyId,
            "body": body
        ]) { result in
            completion(result.error)
        }
    }

    func deleteReply(deviceSecret: String, topicId: String, replyId: String, completion: @escaping (Error?) -> Void) {
        call("deleteCommunityReply", data: [
            "deviceSecret": deviceSecret,
            "topicId": topicId,
            "replyId": replyId
        ]) { result in
            completion(result.error)
        }
    }

    func deleteCommunityDeviceData(deviceSecret: String, completion: @escaping (Error?) -> Void) {
        call("deleteCommunityDeviceData", data: [
            "deviceSecret": deviceSecret
        ]) { result in
            completion(result.error)
        }
    }

    private func call(_ name: String, data: [String: Any], completion: @escaping (Result<[String: Any], Error>) -> Void) {
        functions.httpsCallable(name).call(data) { result, error in
            if let error {
                completion(.failure(error))
                return
            }

            if let dictionary = result?.data as? [String: Any] {
                completion(.success(dictionary))
            } else {
                completion(.success([:]))
            }
        }
    }
}

private extension Result {
    var error: Failure? {
        if case .failure(let error) = self { return error }
        return nil
    }
}

private final class FirebaseAuthPresentationDelegate: NSObject, AuthUIDelegate {
    func present(_ viewControllerToPresent: UIViewController, animated flag: Bool, completion: (() -> Void)? = nil) {
        DispatchQueue.main.async {
            Self.topViewController()?.present(viewControllerToPresent, animated: flag, completion: completion)
        }
    }

    func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        DispatchQueue.main.async {
            Self.topViewController()?.dismiss(animated: flag, completion: completion)
        }
    }

    static func topViewController() -> UIViewController? {
        let root = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }?
            .rootViewController
        return topViewController(from: root)
    }

    private static func topViewController(from viewController: UIViewController?) -> UIViewController? {
        if let presented = viewController?.presentedViewController {
            return topViewController(from: presented)
        }
        if let navigation = viewController as? UINavigationController {
            return topViewController(from: navigation.topViewController)
        }
        if let tab = viewController as? UITabBarController {
            return topViewController(from: tab.selectedViewController)
        }
        return viewController
    }
}

final class CommunityProfileManager: ObservableObject {
    @Published var profile: CommunityProfile
    @Published var authStatusMessage: String?

    private let db = Firestore.firestore()
    private var authStateHandle: AuthStateDidChangeListenerHandle?

    init() {
        let defaults = UserDefaults.standard
        let deviceId = Self.ensureDeviceId()
        let nickname = Self.ensureDefaultNickname(deviceId: deviceId)
        let currentUser = Auth.auth().currentUser
        profile = CommunityProfile(
            nickname: nickname,
            deviceId: deviceId,
            schoolEmail: defaults.string(forKey: "communitySchoolEmail") ?? "",
            department: defaults.string(forKey: "communityDepartment") ?? "",
            entryYear: defaults.string(forKey: "communityEntryYear") ?? "",
            showDepartment: Self.defaultBool(forKey: "communityShowDepartment", defaultValue: true),
            showYear: defaults.bool(forKey: "communityShowYear"),
            showBadge: Self.defaultBool(forKey: "communityShowBadge", defaultValue: true),
            ownerUid: currentUser?.uid ?? defaults.string(forKey: "communityOwnerUid") ?? "",
            ownerEmail: currentUser?.email ?? defaults.string(forKey: "communityOwnerEmail") ?? ""
        )

        if profile.schoolEmail.isEmpty,
           let currentEmail = currentUser?.email?.lowercased(),
           let studentId = Self.studentId(fromSchoolEmail: currentEmail) {
            profile.schoolEmail = currentEmail
            applyStudentId(studentId)
        }

        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self else { return }
            DispatchQueue.main.async {
                if let user {
                    self.profile.ownerUid = user.uid
                    self.profile.ownerEmail = user.email ?? ""
                    if let email = user.email?.lowercased(), let studentId = Self.studentId(fromSchoolEmail: email) {
                        self.profile.schoolEmail = email
                        self.profile.ownerEmail = email
                        self.applyStudentId(studentId)
                    }
                    self.saveProfileLocally()
                } else {
                    self.profile.ownerUid = ""
                    self.profile.ownerEmail = ""
                    self.saveProfileLocally()
                }
            }
        }
    }

    deinit {
        if let handle = authStateHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }

    static func ensureDeviceId() -> String {
        let defaults = UserDefaults.standard
        let key = "commentDeviceId"
        if let existing = defaults.string(forKey: key), !existing.isEmpty { return existing }
        let generated = UUID().uuidString
        defaults.set(generated, forKey: key)
        return generated
    }

    static func ensureDeviceSecret() -> String {
        let defaults = UserDefaults.standard
        let key = "communityDeviceSecret"
        if let existing = defaults.string(forKey: key), !existing.isEmpty { return existing }
        let generated = UUID().uuidString
        defaults.set(generated, forKey: key)
        return generated
    }

    static func ensureDefaultNickname(deviceId: String? = nil) -> String {
        let defaults = UserDefaults.standard
        let key = "commentNickname"
        if let existing = defaults.string(forKey: key), !existing.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return existing
        }

        let resolvedDeviceId = deviceId ?? ensureDeviceId()
        let generated = String(format: String(localized: "community_default_user_format"), String(resolvedDeviceId.prefix(4)).uppercased())
        defaults.set(generated, forKey: key)
        return generated
    }

    private static func defaultBool(forKey key: String, defaultValue: Bool) -> Bool {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: key) != nil else { return defaultValue }
        return defaults.bool(forKey: key)
    }

    func saveProfile() {
        saveProfileLocally()

        let deviceSecret = Self.ensureDeviceSecret()
        db.collection("communityProfiles").document(deviceSecret).setData([
            "nickname": profile.nickname,
            "deviceId": profile.deviceId,
            "deviceSecret": deviceSecret,
            "schoolEmail": profile.schoolEmail,
            "department": profile.department,
            "entryYear": profile.entryYear,
            "showDepartment": profile.showDepartment,
            "showYear": profile.showYear,
            "showBadge": profile.showBadge,
            "ownerUid": profile.ownerUid,
            "ownerEmail": profile.ownerEmail,
            "updatedAt": FieldValue.serverTimestamp()
        ], merge: true)
    }

    private func saveProfileLocally() {
        let defaults = UserDefaults.standard
        defaults.set(profile.nickname, forKey: "commentNickname")
        defaults.set(profile.deviceId, forKey: "commentDeviceId")
        defaults.set(profile.schoolEmail, forKey: "communitySchoolEmail")
        defaults.set(profile.department, forKey: "communityDepartment")
        defaults.set(profile.entryYear, forKey: "communityEntryYear")
        defaults.set(profile.showDepartment, forKey: "communityShowDepartment")
        defaults.set(profile.showYear, forKey: "communityShowYear")
        defaults.set(profile.showBadge, forKey: "communityShowBadge")
        defaults.set(profile.ownerUid, forKey: "communityOwnerUid")
        defaults.set(profile.ownerEmail, forKey: "communityOwnerEmail")
    }

    private func applyStudentId(_ studentId: String) {
        let trimmed = studentId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 5 else { return }

        let yearDigits = String(trimmed.dropFirst().prefix(3))
        let departmentCode = Self.departmentCode(from: trimmed)
        profile.entryYear = yearDigits
        profile.department = Self.departmentName(for: departmentCode)
    }

    func signInWithGoogleSchoolEmail() {
        if let setupIssue = Self.googleOAuthSetupIssue() {
            authStatusMessage = setupIssue
            return
        }

        authStatusMessage = String(localized: "community_google_auth_opening")

        guard let clientID = FirebaseApp.app()?.options.clientID else {
            authStatusMessage = String(localized: "community_google_auth_missing_client_id")
            return
        }
        guard let presenter = FirebaseAuthPresentationDelegate.topViewController() else {
            authStatusMessage = String(localized: "community_google_auth_missing_presenter")
            return
        }

        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.signIn(withPresenting: presenter) { [weak self] signInResult, error in
            guard let self else { return }
            if let error {
                DispatchQueue.main.async {
                    self.authStatusMessage = String(format: String(localized: "community_google_auth_failed_format"), error.localizedDescription)
                }
                return
            }

            guard let user = signInResult?.user,
                  let idToken = user.idToken?.tokenString else {
                DispatchQueue.main.async {
                    self.authStatusMessage = String(localized: "community_google_auth_missing_credential")
                }
                return
            }

            let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: user.accessToken.tokenString)
            Auth.auth().signIn(with: credential) { [weak self] result, error in
                guard let self else { return }
                DispatchQueue.main.async {
                    if let error {
                        self.authStatusMessage = String(format: String(localized: "community_google_auth_failed_format"), error.localizedDescription)
                        return
                    }

                    guard let email = result?.user.email?.lowercased(), let studentId = Self.studentId(fromSchoolEmail: email) else {
                        try? Auth.auth().signOut()
                        self.authStatusMessage = String(localized: "community_google_auth_school_account_required")
                        return
                    }

                    self.profile.schoolEmail = email
                    self.profile.ownerUid = result?.user.uid ?? self.profile.ownerUid
                    self.profile.ownerEmail = email
                    self.applyStudentId(studentId)
                    self.saveProfile()
                    self.authStatusMessage = String(format: String(localized: "community_google_auth_verified_format"), email)
                }
            }
        }
    }

    private static func googleOAuthSetupIssue() -> String? {
        guard let plistURL = Bundle.main.url(forResource: "GoogleService-Info", withExtension: "plist"),
              let plistData = try? Data(contentsOf: plistURL),
              let plist = try? PropertyListSerialization.propertyList(from: plistData, options: [], format: nil) as? [String: Any] else {
            return String(localized: "community_google_config_missing_plist")
        }

        let clientId = plist["CLIENT_ID"] as? String ?? ""
        let reversedClientId = plist["REVERSED_CLIENT_ID"] as? String ?? ""
        if clientId.contains("PLACEHOLDER") || reversedClientId.contains("PLACEHOLDER") || clientId.isEmpty || reversedClientId.isEmpty {
            return String(localized: "community_google_config_placeholder_client")
        }

        let urlTypes = Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]] ?? []
        let schemes = urlTypes.flatMap { $0["CFBundleURLSchemes"] as? [String] ?? [] }
        if !schemes.contains(reversedClientId) {
            return String(localized: "community_google_config_missing_url_scheme")
        }

        return nil
    }

    private static func studentId(fromSchoolEmail email: String) -> String? {
        let normalized = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let parts = normalized.split(separator: "@", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2, ["gn.ntpu.edu.tw", "gm.ntpu.edu.tw"].contains(String(parts[1])) else { return nil }

        let localPart = parts[0]
        guard localPart.hasPrefix("s") else { return nil }

        let studentId = localPart.dropFirst()
        guard !studentId.isEmpty, studentId.allSatisfy(\.isNumber) else { return nil }
        return String(studentId)
    }

    private static func departmentCode(from studentId: String) -> String {
        let codeDigits = String(studentId.dropFirst(4))
        for code in departmentCandidatesByCode.keys.sorted(by: { $0.count > $1.count }) where codeDigits.hasPrefix(code) {
            return code
        }
        return String(codeDigits.prefix(2))
    }

    private static let departmentCandidatesByCode: [String: [String]] = [
        "31": ["企管碩", "企管博"],
        "32": ["會計碩", "會計博"],
        "33": ["統計碩"],
        "34": ["金融碩"],
        "35": ["國企所"],
        "36": ["資管所"],
        "37": ["財金英碩"],
        "41": ["民俗所"],
        "42": ["古典所"],
        "43": ["中文碩"],
        "44": ["歷史碩"],
        "51": ["法律碩", "法律博"],
        "52": ["法律碩專業組"],
        "61": ["經濟碩", "經濟博"],
        "62": ["社會碩"],
        "63": ["社工碩"],
        "64": ["犯罪所"],
        "71": ["公行碩", "公行博"],
        "712": ["法律系法學組"],
        "714": ["法律系司法組"],
        "716": ["法律系財法組"],
        "72": ["公行系", "財政碩"],
        "73": ["經濟系", "不動碩", "不動博"],
        "742": ["社學系"],
        "744": ["社工系"],
        "74": ["都計所", "都計博"],
        "75": ["財政系", "自環所", "自環博"],
        "76": ["不動系", "城市治理英碩", "電資博"],
        "77": ["會計系", "會計在職"],
        "78": ["統計系", "統計在職"],
        "79": ["企管系", "企管在職"],
        "80": ["金融系"],
        "81": ["中文系", "通訊碩"],
        "82": ["應外系", "電機碩"],
        "83": ["歷史系", "資工碩"],
        "84": ["休運系"],
        "85": ["資工系"],
        "86": ["通訊系"],
        "87": ["電機系"],
        "91": ["智慧醫療英碩"]
    ]

    private static func departmentName(for code: String) -> String {
        let map = departmentCandidatesByCode.mapValues { $0.joined(separator: " / ") }

        if let mapped = map[code] {
            return mapped
        }

        return String(format: String(localized: "community_department_code_format"), code)
    }
}

private final class CommunitySubscriptionManager: ObservableObject {
    @Published var categorySubscriptions: Set<String> = []
    @Published var topicSubscriptions: Set<String> = []

    private let db = Firestore.firestore()
    private let deviceId: String
    private let deviceSecret: String

    init(deviceId: String = CommunityProfileManager.ensureDeviceId(), deviceSecret: String = CommunityProfileManager.ensureDeviceSecret()) {
        self.deviceId = deviceId
        self.deviceSecret = deviceSecret
        loadLocalSubscriptions()
    }

    func isSubscribed(to category: CommunityCategory) -> Bool {
        categorySubscriptions.contains(category.rawValue)
    }

    func isSubscribed(to topicID: String) -> Bool {
        topicSubscriptions.contains(topicID)
    }

    func toggleCategory(_ category: CommunityCategory) {
        guard category != .all else { return }
        AppDelegate.requestCommunityNotificationRegistration()

        if categorySubscriptions.contains(category.rawValue) {
            categorySubscriptions.remove(category.rawValue)
            CommunityNotificationFallbackService.shared.noteCategorySubscriptionChanged(category.rawValue, isSubscribed: false)
            db.collection("communityCategorySubscriptions").document(category.rawValue).collection("devices").document(deviceSecret).setData(subscriptionPayload(extra: [
                "active": false
            ]), merge: true)
        } else {
            categorySubscriptions.insert(category.rawValue)
            CommunityNotificationFallbackService.shared.noteCategorySubscriptionChanged(category.rawValue, isSubscribed: true)
            db.collection("communityCategorySubscriptions").document(category.rawValue).collection("devices").document(deviceSecret).setData(subscriptionPayload(), merge: true)
        }

        persistSubscriptions()
    }

    func toggleTopic(_ topic: CommunityTopic) {
        AppDelegate.requestCommunityNotificationRegistration()

        if topicSubscriptions.contains(topic.id) {
            topicSubscriptions.remove(topic.id)
            CommunityNotificationFallbackService.shared.noteTopicSubscriptionChanged(topic.id, isSubscribed: false)
            db.collection("communityTopicSubscriptions").document(topic.id).collection("devices").document(deviceSecret).setData(subscriptionPayload(extra: [
                "active": false
            ]), merge: true)
        } else {
            topicSubscriptions.insert(topic.id)
            CommunityNotificationFallbackService.shared.noteTopicSubscriptionChanged(topic.id, isSubscribed: true)
            db.collection("communityTopicSubscriptions").document(topic.id).collection("devices").document(deviceSecret).setData(subscriptionPayload(extra: [
                "topicTitle": topic.title,
                "category": topic.category.rawValue
            ]), merge: true)
        }

        persistSubscriptions()
    }

    private func subscriptionPayload(extra: [String: Any] = [:]) -> [String: Any] {
        var data = extra
        data["deviceId"] = deviceId
        data["deviceSecret"] = deviceSecret
        data["active"] = extra["active"] ?? true
        data["updatedAt"] = FieldValue.serverTimestamp()
        return data
    }

    private func loadLocalSubscriptions() {
        let defaults = UserDefaults.standard
        categorySubscriptions = Set(defaults.stringArray(forKey: "communityCategorySubscriptions") ?? [])
        topicSubscriptions = Set(defaults.stringArray(forKey: "communityTopicSubscriptions") ?? [])
    }

    private func persistSubscriptions() {
        let defaults = UserDefaults.standard
        defaults.set(Array(categorySubscriptions), forKey: "communityCategorySubscriptions")
        defaults.set(Array(topicSubscriptions), forKey: "communityTopicSubscriptions")

        db.collection("communityDeviceTokens").document(deviceSecret).setData([
            "deviceId": deviceId,
            "deviceSecret": deviceSecret,
            "categorySubscriptions": Array(categorySubscriptions),
            "topicSubscriptions": Array(topicSubscriptions),
            "updatedAt": FieldValue.serverTimestamp()
        ], merge: true)
    }
}

private final class CommunityTopicManager: ObservableObject {
    @Published var topics: [CommunityTopic] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let db = Firestore.firestore()
    private let communityFunctions = CommunityContentFunctionsService()
    private var listener: ListenerRegistration?

    deinit { listener?.remove() }

    func loadTopics() {
        listener?.remove()
        isLoading = true

        listener = db.collection("communityTopics")
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                if let error {
                    DispatchQueue.main.async {
                        self.errorMessage = error.localizedDescription
                        self.isLoading = false
                    }
                    return
                }

                let mapped = snapshot?.documents.compactMap { document -> CommunityTopic? in
                    let data = document.data()
                    guard let title = data["title"] as? String,
                          let body = data["body"] as? String,
                          let rawCategory = data["category"] as? String,
                          let category = CommunityCategory(rawValue: rawCategory),
                          let authorName = data["authorName"] as? String else {
                        return nil
                    }

                    let timestamp = data["createdAt"] as? Timestamp
                    return CommunityTopic(
                        id: document.documentID,
                        title: title,
                        body: body,
                        category: category,
                        authorName: authorName,
                        authorDeviceId: data["authorDeviceId"] as? String ?? "",
                        authorDepartment: data["authorDepartment"] as? String ?? "",
                        authorEntryYear: data["authorEntryYear"] as? String ?? "",
                        authorShowsYear: data["authorShowsYear"] as? Bool ?? false,
                        authorShowsBadge: data["authorShowsBadge"] as? Bool ?? ((data["authorBadgeCount"] as? Int ?? 0) > 0),
                        authorBadgeLevel: authorBadgeLevel(from: data),
                        createdAt: timestamp?.dateValue() ?? Date(),
                        replyCount: data["replyCount"] as? Int ?? 0
                    )
                } ?? []

                DispatchQueue.main.async {
                    self.topics = mapped
                    self.errorMessage = nil
                    self.isLoading = false
                }
            }
    }

    func addTopic(title: String, body: String, category: CommunityCategory, authorName: String, deviceId: String, publishDepartment: Bool, publishYear: Bool, publishBadge: Bool, completion: ((Error?) -> Void)? = nil) {
        let defaults = UserDefaults.standard
        let payload: [String: Any] = [
            "deviceSecret": CommunityProfileManager.ensureDeviceSecret(),
            "title": title.trimmingCharacters(in: .whitespacesAndNewlines),
            "body": body.trimmingCharacters(in: .whitespacesAndNewlines),
            "category": category.rawValue,
            "authorName": authorName.trimmingCharacters(in: .whitespacesAndNewlines),
            "authorDeviceId": deviceId,
            "authorDepartment": publishDepartment ? (defaults.string(forKey: "communityDepartment") ?? "") : "",
            "authorEntryYear": publishYear ? (defaults.string(forKey: "communityEntryYear") ?? "") : "",
            "authorShowsYear": publishYear,
            "authorShowsBadge": publishBadge,
            "authorBadgeLevel": publishBadge ? CommentBadgeManager.shared.getCurrentBadge().rawValue : CommentBadgeManager.BadgeLevel.newbie.rawValue
        ]

        communityFunctions.createTopic(payload: payload) { [weak self] error in
            DispatchQueue.main.async {
                self?.errorMessage = error?.localizedDescription
                completion?(error)
            }
        }
    }
}

private final class CommunityReplyManager: ObservableObject {
    @Published var replies: [CommunityReply] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let topicID: String
    private let db = Firestore.firestore()
    private let communityFunctions = CommunityContentFunctionsService()
    private var listener: ListenerRegistration?

    init(topicID: String) {
        self.topicID = topicID
    }

    deinit { listener?.remove() }

    func loadReplies() {
        listener?.remove()
        isLoading = true

        listener = db.collection("communityTopics")
            .document(topicID)
            .collection("replies")
            .order(by: "createdAt", descending: false)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                if let error {
                    DispatchQueue.main.async {
                        self.errorMessage = error.localizedDescription
                        self.isLoading = false
                    }
                    return
                }

                let mapped = snapshot?.documents.compactMap { document -> CommunityReply? in
                    let data = document.data()
                    guard let body = data["body"] as? String,
                          let authorName = data["authorName"] as? String else {
                        return nil
                    }

                    let timestamp = data["createdAt"] as? Timestamp
                    return CommunityReply(
                        id: document.documentID,
                        body: body,
                        authorName: authorName,
                        authorDeviceId: data["authorDeviceId"] as? String ?? "",
                        authorDepartment: data["authorDepartment"] as? String ?? "",
                        authorEntryYear: data["authorEntryYear"] as? String ?? "",
                        authorShowsYear: data["authorShowsYear"] as? Bool ?? false,
                        authorShowsBadge: data["authorShowsBadge"] as? Bool ?? ((data["authorBadgeCount"] as? Int ?? 0) > 0),
                        authorBadgeLevel: authorBadgeLevel(from: data),
                        createdAt: timestamp?.dateValue() ?? Date()
                    )
                } ?? []

                DispatchQueue.main.async {
                    self.replies = mapped
                    self.errorMessage = nil
                    self.isLoading = false
                }
            }
    }

    func addReply(body: String, authorName: String, deviceId: String, publishDepartment: Bool, publishYear: Bool, publishBadge: Bool, completion: ((Error?) -> Void)? = nil) {
        let defaults = UserDefaults.standard
        let payload: [String: Any] = [
            "deviceSecret": CommunityProfileManager.ensureDeviceSecret(),
            "topicId": topicID,
            "body": body.trimmingCharacters(in: .whitespacesAndNewlines),
            "authorName": authorName.trimmingCharacters(in: .whitespacesAndNewlines),
            "authorDeviceId": deviceId,
            "authorDepartment": publishDepartment ? (defaults.string(forKey: "communityDepartment") ?? "") : "",
            "authorEntryYear": publishYear ? (defaults.string(forKey: "communityEntryYear") ?? "") : "",
            "authorShowsYear": publishYear,
            "authorShowsBadge": publishBadge,
            "authorBadgeLevel": publishBadge ? CommentBadgeManager.shared.getCurrentBadge().rawValue : CommentBadgeManager.BadgeLevel.newbie.rawValue
        ]

        communityFunctions.createReply(payload: payload) { [weak self] error in
            DispatchQueue.main.async {
                self?.errorMessage = error?.localizedDescription
                completion?(error)
            }
        }
    }
}

private struct CommunityView: View {
    @StateObject private var manager = CommunityTopicManager()
    @StateObject private var subscriptionManager = CommunitySubscriptionManager()
    @StateObject private var profileManager = CommunityProfileManager()
    @State private var selectedCategory: CommunityCategory = .all
    @State private var showComposer = false
    @State private var searchText = ""

    private var visibleTopics: [CommunityTopic] {
        let categorized = selectedCategory == .all ? manager.topics : manager.topics.filter { $0.category == selectedCategory }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return categorized }
        return categorized.filter {
            $0.title.localizedCaseInsensitiveContains(query) ||
            $0.body.localizedCaseInsensitiveContains(query)
        }
    }

    private var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            List {
                communityHero
                    .listRowInsets(.init(top: 8, leading: 0, bottom: 4, trailing: 0))
                    .listRowBackground(Color.clear)

                categoryPicker
                    .listRowInsets(.init(top: 4, leading: 0, bottom: 4, trailing: 0))
                    .listRowBackground(Color.clear)

                if let errorMessage = manager.errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    if manager.isLoading && manager.topics.isEmpty {
                        ProgressView(String(localized: "community_loading"))
                            .frame(maxWidth: .infinity, alignment: .center)
                    } else if visibleTopics.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "bubble.left.and.bubble.right")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                            Text(String(localized: isSearching ? "community_empty_search_title" : "community_empty_title"))
                                .font(.headline)
                            Text(String(localized: isSearching ? "community_empty_search_subtitle" : "community_empty_subtitle"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 20)
                    } else {
                        ForEach(visibleTopics) { topic in
                            NavigationLink {
                                CommunityTopicDetailView(topic: topic, subscriptionManager: subscriptionManager)
                            } label: {
                                CommunityTopicRow(topic: topic)
                            }
                        }
                    }
                } header: {
                    Text(selectedCategory == .all ? String(localized: "community_latest_topics") : selectedCategory.title)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.gray.opacity(0.1))
            .navigationTitle(String(localized: "community_title"))
            .searchable(text: $searchText, prompt: String(localized: "community_search_prompt"))
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showComposer = true
                    } label: {
                        Label(String(localized: "community_add_topic"), systemImage: "square.and.pencil")
                    }
                }
            }
            .sheet(isPresented: $showComposer) {
                CommunityComposerView(manager: manager, initialCategory: selectedCategory == .all ? .question : selectedCategory)
            }
            .onAppear { manager.loadTopics() }
        }
    }

    private var communityHero: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.title2)
                    .foregroundStyle(.blue)
                    .frame(width: 42, height: 42)
                    .background(Color.blue.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                Spacer()

                Text("NTPU")
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .foregroundStyle(.blue)
                    .background(Color.blue.opacity(0.12), in: Capsule())
            }

            Text(String(localized: "community_hero_title"))
                .font(.title3.weight(.semibold))
            if !profileManager.profile.displayLine.isEmpty {
                Label(profileManager.profile.displayLine, systemImage: "person.text.rectangle")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            Label(String(localized: "community_hero_profile_hint"), systemImage: "info.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(.secondarySystemBackground))
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.blue.opacity(0.20), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.08), radius: 14, x: 0, y: 7)
        }
    }

    private var categoryPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(CommunityCategory.allCases) { category in
                    HStack(spacing: 4) {
                        Button {
                            selectedCategory = category
                        } label: {
                            Label(category.title, systemImage: category.icon)
                                .font(.caption.weight(.semibold))
                                .padding(.leading, 11)
                                .padding(.trailing, category == .all ? 11 : 4)
                                .padding(.vertical, 8)
                                .foregroundStyle(selectedCategory == category ? .white : category.tint)
                        }
                        .buttonStyle(.plain)

                        if category != .all {
                            Button {
                                subscriptionManager.toggleCategory(category)
                            } label: {
                                Image(systemName: subscriptionManager.isSubscribed(to: category) ? "bell.fill" : "bell")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(selectedCategory == category ? .white : category.tint)
                                    .padding(.trailing, 10)
                                    .padding(.vertical, 8)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(String(format: String(localized: subscriptionManager.isSubscribed(to: category) ? "community_unsubscribe_category_accessibility_format" : "community_subscribe_category_accessibility_format"), category.title))
                        }
                    }
                    .background(selectedCategory == category ? category.tint : category.tint.opacity(0.12), in: Capsule())
                }
            }
        }
    }
}

private struct CommunityTopicRow: View {
    let topic: CommunityTopic

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Label(topic.category.title, systemImage: topic.category.icon)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(topic.category.tint)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(topic.category.tint.opacity(0.12), in: Capsule())

                Spacer()

                Text(relativeTime(topic.createdAt))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Text(topic.title)
                .font(.headline)
                .lineLimit(2)

            Text(topic.body)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            HStack(spacing: 10) {
                Label(topic.authorName, systemImage: "person.fill")
                if topic.authorShowsBadge {
                    BadgeTagView(badge: badgeLevel(from: topic.authorBadgeLevel))
                }
                if !authorProfileLine(department: topic.authorDepartment, entryYear: topic.authorEntryYear, showsYear: topic.authorShowsYear).isEmpty {
                    Label(authorProfileLine(department: topic.authorDepartment, entryYear: topic.authorEntryYear, showsYear: topic.authorShowsYear), systemImage: "person.text.rectangle")
                }
                Label(String(format: String(localized: "community_reply_count_format"), topic.replyCount), systemImage: "text.bubble.fill")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
    }
}

private struct CommunityComposerView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var manager: CommunityTopicManager
    @AppStorage("commentNickname") private var nickname: String = ""
    @AppStorage("commentDeviceId") private var deviceId: String = ""
    @AppStorage("communityDepartment") private var communityDepartment: String = ""
    @AppStorage("communityEntryYear") private var communityEntryYear: String = ""
    @AppStorage("communityShowDepartment") private var defaultShowDepartment: Bool = true
    @AppStorage("communityShowYear") private var defaultShowYear: Bool = false
    @AppStorage("communityShowBadge") private var defaultShowBadge: Bool = true
    @StateObject private var badgeManager = CommentBadgeManager.shared

    @State private var category: CommunityCategory
    @State private var title = ""
    @State private var topicBody = ""
    @State private var publishDepartment = true
    @State private var publishYear = false
    @State private var publishBadge = true
    @State private var didLoadDisclosureDefaults = false
    @State private var isSubmitting = false
    @State private var submitErrorMessage: String?

    init(manager: CommunityTopicManager, initialCategory: CommunityCategory) {
        self.manager = manager
        self._category = State(initialValue: initialCategory)
    }

    private var canSubmit: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !topicBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !isSubmitting
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(String(localized: "community_identity_section")) {
                    Label(nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? String(localized: "community_identity_not_set") : nickname, systemImage: "person.text.rectangle")
                    Text(String(localized: "community_identity_setup_hint"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section(String(localized: "community_category_section")) {
                    Picker(String(localized: "community_category_section"), selection: $category) {
                        ForEach(CommunityCategory.allCases.filter { $0 != .all }) { category in
                            Label(category.title, systemImage: category.icon).tag(category)
                        }
                    }
                }

                Section(String(localized: "community_topic_section")) {
                    TextField(String(localized: "community_topic_title_placeholder"), text: $title)
                    TextField(String(localized: "community_topic_body_placeholder"), text: $topicBody, axis: .vertical)
                        .lineLimit(5...10)
                }

                Section {
                    Toggle(String(localized: "community_publish_department"), isOn: $publishDepartment)
                        .disabled(communityDepartment.isEmpty)
                    Toggle(String(localized: "community_publish_year"), isOn: $publishYear)
                        .disabled(communityEntryYear.isEmpty)
                    Toggle(String(localized: "community_publish_badge"), isOn: $publishBadge)
                    if publishBadge {
                        HStack(spacing: 8) {
                            Text(String(localized: "community_preview"))
                                .foregroundStyle(.secondary)
                            BadgeTagView(badge: badgeManager.getCurrentBadge(), compact: false)
                        }
                        .font(.caption)
                    }
                } header: {
                    Text(String(localized: "community_publish_disclosure_header"))
                } footer: {
                    Text(String(localized: "community_publish_disclosure_footer"))
                }

                if let submitErrorMessage {
                    Section {
                        Label(submitErrorMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(String(localized: "community_add_topic"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "community_publish_button")) { submit() }
                        .disabled(!canSubmit)
                }
            }
            .onAppear {
                if deviceId.isEmpty { deviceId = UUID().uuidString }
                if nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    nickname = CommunityProfileManager.ensureDefaultNickname(deviceId: deviceId)
                }
                loadDisclosureDefaultsIfNeeded()
            }
        }
    }

    private func loadDisclosureDefaultsIfNeeded() {
        guard !didLoadDisclosureDefaults else { return }
        publishDepartment = defaultShowDepartment
        publishYear = defaultShowYear
        publishBadge = defaultShowBadge
        didLoadDisclosureDefaults = true
    }

    private func submit() {
        guard canSubmit else { return }
        if deviceId.isEmpty { deviceId = UUID().uuidString }
        submitErrorMessage = nil
        isSubmitting = true
        manager.addTopic(title: title, body: topicBody, category: category, authorName: nickname, deviceId: deviceId, publishDepartment: publishDepartment, publishYear: publishYear, publishBadge: publishBadge) { error in
            isSubmitting = false
            if let error {
                submitErrorMessage = String(format: String(localized: "community_publish_failed_format"), error.localizedDescription)
            } else {
                dismiss()
            }
        }
    }
}

private struct CommunityTopicDetailView: View {
    let topic: CommunityTopic
    @ObservedObject var subscriptionManager: CommunitySubscriptionManager
    @StateObject private var replyManager: CommunityReplyManager
    @AppStorage("commentNickname") private var nickname: String = ""
    @AppStorage("commentDeviceId") private var deviceId: String = ""
    @AppStorage("communityDepartment") private var communityDepartment: String = ""
    @AppStorage("communityEntryYear") private var communityEntryYear: String = ""
    @AppStorage("communityShowDepartment") private var defaultShowDepartment: Bool = true
    @AppStorage("communityShowYear") private var defaultShowYear: Bool = false
    @AppStorage("communityShowBadge") private var defaultShowBadge: Bool = true
    @StateObject private var badgeManager = CommentBadgeManager.shared
    @State private var replyBody = ""
    @State private var publishDepartment = true
    @State private var publishYear = false
    @State private var publishBadge = true
    @State private var didLoadDisclosureDefaults = false
    @State private var isSubmitting = false
    @State private var isReplyPublicInfoExpanded = false

    init(topic: CommunityTopic, subscriptionManager: CommunitySubscriptionManager) {
        self.topic = topic
        self.subscriptionManager = subscriptionManager
        self._replyManager = StateObject(wrappedValue: CommunityReplyManager(topicID: topic.id))
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Label(topic.category.title, systemImage: topic.category.icon)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(topic.category.tint)

                    Text(topic.title)
                        .font(.title3.weight(.semibold))
                    Text(topic.body)
                        .font(.body)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Label("\(topic.authorName) · \(relativeTime(topic.createdAt))", systemImage: "person.fill")
                            if topic.authorShowsBadge {
                                BadgeTagView(badge: badgeLevel(from: topic.authorBadgeLevel))
                            }
                        }
                        let profileLine = authorProfileLine(department: topic.authorDepartment, entryYear: topic.authorEntryYear, showsYear: topic.authorShowsYear)
                        if !profileLine.isEmpty {
                            Label(profileLine, systemImage: "person.text.rectangle")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
            }

            Section(String(localized: "community_replies_section")) {
                if replyManager.isLoading && replyManager.replies.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                } else if let errorMessage = replyManager.errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                } else if replyManager.replies.isEmpty {
                    Text(String(localized: "community_no_replies"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(replyManager.replies) { reply in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(reply.authorName)
                                    .font(.caption.weight(.semibold))
                                if reply.authorShowsBadge {
                                    BadgeTagView(badge: badgeLevel(from: reply.authorBadgeLevel))
                                }
                                let profileLine = authorProfileLine(department: reply.authorDepartment, entryYear: reply.authorEntryYear, showsYear: reply.authorShowsYear)
                                if !profileLine.isEmpty {
                                    Text(profileLine)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(relativeTime(reply.createdAt))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Text(reply.body)
                                .font(.body)
                        }
                        .padding(.vertical, 4)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    if nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(String(localized: "community_reply_identity_required"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    TextField(String(localized: "community_reply_placeholder"), text: $replyBody, axis: .vertical)
                        .lineLimit(2...5)
                    replyPublicInfoCard
                    Button {
                        submitReply()
                    } label: {
                        Label(String(localized: "community_send_reply"), systemImage: "paperplane.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canSubmitReply)
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle(String(localized: "community_topic_navigation_title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    subscriptionManager.toggleTopic(topic)
                } label: {
                    Label(String(localized: subscriptionManager.isSubscribed(to: topic.id) ? "community_unsubscribe" : "community_subscribe_topic"), systemImage: subscriptionManager.isSubscribed(to: topic.id) ? "bell.fill" : "bell")
                }
            }
        }
        .onAppear {
            if deviceId.isEmpty { deviceId = UUID().uuidString }
            loadDisclosureDefaultsIfNeeded()
            replyManager.loadReplies()
        }
    }

    private var replyPublicInfoCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.easeInOut(duration: 0.22)) {
                    isReplyPublicInfoExpanded.toggle()
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "person.text.rectangle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.blue)
                        .frame(width: 28, height: 28)
                        .background(Color.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(localized: "community_public_info"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text(replyPublicInfoSummary)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isReplyPublicInfoExpanded ? 180 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isReplyPublicInfoExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    replyPublicInfoOption(
                        title: String(localized: "community_publish_department"),
                        detail: communityDepartment.isEmpty ? String(localized: "community_department_unavailable") : communityDepartment,
                        systemImage: "building.columns.fill",
                        isOn: $publishDepartment,
                        isEnabled: !communityDepartment.isEmpty
                    )
                    replyPublicInfoOption(
                        title: String(localized: "community_publish_year"),
                        detail: communityEntryYear.isEmpty ? String(localized: "community_entry_year_unavailable") : String(format: String(localized: "community_entry_year_format"), communityEntryYear),
                        systemImage: "calendar",
                        isOn: $publishYear,
                        isEnabled: !communityEntryYear.isEmpty
                    )
                    replyPublicInfoOption(
                        title: String(localized: "community_publish_badge"),
                        detail: String(localized: "community_badge_reply_detail"),
                        systemImage: "tag.fill",
                        isOn: $publishBadge
                    )
                    if publishBadge {
                        HStack(spacing: 8) {
                            Text(String(localized: "community_badge_preview"))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            BadgeTagView(badge: badgeManager.getCurrentBadge(), compact: false)
                            Spacer(minLength: 0)
                        }
                        .padding(10)
                        .background(Color.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
                .padding(.top, 2)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemBackground))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.blue.opacity(0.16), lineWidth: 1)
                }
        }
    }

    private func replyPublicInfoOption(title: String, detail: String, systemImage: String, isOn: Binding<Bool>, isEnabled: Bool = true) -> some View {
        Button {
            guard isEnabled else { return }
            withAnimation(.easeInOut(duration: 0.18)) {
                isOn.wrappedValue.toggle()
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isEnabled ? Color.blue : Color.secondary)
                    .frame(width: 34, height: 34)
                    .background(isEnabled ? Color.blue.opacity(isOn.wrappedValue ? 0.16 : 0.10) : Color.gray.opacity(0.10), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isEnabled ? Color.primary : Color.secondary)
                    Text(detail)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Image(systemName: isOn.wrappedValue ? "checkmark.circle.fill" : "circle")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(isEnabled && isOn.wrappedValue ? Color.blue : Color.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isEnabled ? Color(.tertiarySystemBackground) : Color.gray.opacity(0.08))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(isEnabled && isOn.wrappedValue ? Color.blue.opacity(0.26) : Color.secondary.opacity(0.12), lineWidth: 1)
                    }
            }
            .opacity(isEnabled ? 1 : 0.58)
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel(title)
        .accessibilityValue(String(localized: isOn.wrappedValue ? "community_accessibility_selected" : "community_accessibility_not_selected"))
        .accessibilityHint(String(localized: isEnabled ? "community_accessibility_toggle_hint" : "community_accessibility_unavailable_hint"))
    }

    private var replyPublicInfoSummary: String {
        var parts: [String] = []
        if publishDepartment && !communityDepartment.isEmpty { parts.append(String(localized: "community_public_part_department")) }
        if publishYear && !communityEntryYear.isEmpty { parts.append(String(localized: "community_public_part_year")) }
        if publishBadge { parts.append(String(localized: "community_public_part_badge")) }
        return parts.isEmpty ? String(localized: "community_public_info_none") : String(format: String(localized: "community_public_info_summary_format"), parts.joined(separator: String(localized: "community_list_separator")))
    }

    private func loadDisclosureDefaultsIfNeeded() {
        guard !didLoadDisclosureDefaults else { return }
        publishDepartment = defaultShowDepartment
        publishYear = defaultShowYear
        publishBadge = defaultShowBadge
        didLoadDisclosureDefaults = true
    }

    private var canSubmitReply: Bool {
        !replyBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !isSubmitting
    }

    private func submitReply() {
        guard canSubmitReply else { return }
        if deviceId.isEmpty { deviceId = UUID().uuidString }
        isSubmitting = true
        replyManager.addReply(body: replyBody, authorName: nickname, deviceId: deviceId, publishDepartment: publishDepartment, publishYear: publishYear, publishBadge: publishBadge) { error in
            isSubmitting = false
            if error == nil { replyBody = "" }
        }
    }
}

private enum CommunityManagedContentEditItem: Identifiable, Equatable {
    case topic(CommunityManagedTopic)
    case reply(CommunityManagedReply)

    var id: String {
        switch self {
        case .topic(let topic): return "topic-\(topic.topicId)"
        case .reply(let reply): return "reply-\(reply.topicId)-\(reply.replyId)"
        }
    }

    var bodyPreview: String {
        switch self {
        case .topic(let topic): return topic.bodyPreview
        case .reply(let reply): return reply.bodyPreview
        }
    }
}

private enum CommunityManagedContentDeletionItem: Identifiable, Equatable {
    case topic(CommunityManagedTopic)
    case reply(CommunityManagedReply)

    var id: String {
        switch self {
        case .topic(let topic): return "topic-\(topic.topicId)"
        case .reply(let reply): return "reply-\(reply.topicId)-\(reply.replyId)"
        }
    }
}

private final class CommunityMyContentManager: ObservableObject {
    @Published var topics: [CommunityManagedTopic] = []
    @Published var replies: [CommunityManagedReply] = []
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var errorMessage: String?

    private let communityFunctions = CommunityContentFunctionsService()
    private let deviceSecret: String

    init(deviceSecret: String = CommunityProfileManager.ensureDeviceSecret()) {
        self.deviceSecret = deviceSecret
    }

    func load() {
        isLoading = true
        errorMessage = nil

        communityFunctions.listMyContent(deviceSecret: deviceSecret) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isLoading = false
                switch result {
                case .success(let snapshot):
                    self.topics = snapshot.topics
                    self.replies = snapshot.replies
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func updateTopic(_ topic: CommunityManagedTopic, title: String, body: String, completion: @escaping (Error?) -> Void) {
        isSaving = true
        errorMessage = nil
        communityFunctions.updateTopic(deviceSecret: deviceSecret, topicId: topic.topicId, title: title, body: body) { [weak self] error in
            DispatchQueue.main.async {
                self?.finishMutation(error: error, completion: completion)
            }
        }
    }

    func deleteTopic(_ topic: CommunityManagedTopic) {
        isSaving = true
        errorMessage = nil
        communityFunctions.deleteTopic(deviceSecret: deviceSecret, topicId: topic.topicId) { [weak self] error in
            DispatchQueue.main.async {
                self?.finishMutation(error: error)
            }
        }
    }

    func updateReply(_ reply: CommunityManagedReply, body: String, completion: @escaping (Error?) -> Void) {
        isSaving = true
        errorMessage = nil
        communityFunctions.updateReply(deviceSecret: deviceSecret, topicId: reply.topicId, replyId: reply.replyId, body: body) { [weak self] error in
            DispatchQueue.main.async {
                self?.finishMutation(error: error, completion: completion)
            }
        }
    }

    func deleteReply(_ reply: CommunityManagedReply) {
        isSaving = true
        errorMessage = nil
        communityFunctions.deleteReply(deviceSecret: deviceSecret, topicId: reply.topicId, replyId: reply.replyId) { [weak self] error in
            DispatchQueue.main.async {
                self?.finishMutation(error: error)
            }
        }
    }

    private func finishMutation(error: Error?, completion: ((Error?) -> Void)? = nil) {
        isSaving = false
        errorMessage = error?.localizedDescription
        completion?(error)
        if error == nil { load() }
    }
}

struct CommunityMyContentView: View {
    var body: some View {
        CommunityMyContentListView()
    }
}

private struct CommunityMyContentListView: View {
    @StateObject private var manager = CommunityMyContentManager()
    @State private var editingItem: CommunityManagedContentEditItem?
    @State private var deletionItem: CommunityManagedContentDeletionItem?

    var body: some View {
        List {
            Section {
                Label(String(localized: "community_my_content_private_notice"), systemImage: "lock.shield.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let errorMessage = manager.errorMessage {
                Section {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section(String(localized: "community_my_topics_section")) {
                if manager.isLoading && manager.topics.isEmpty {
                    ProgressView(String(localized: "community_loading_topics"))
                        .frame(maxWidth: .infinity, alignment: .center)
                } else if manager.topics.isEmpty {
                    emptyManagedContentRow(title: String(localized: "community_no_managed_topics"), systemImage: "bubble.left")
                } else {
                    ForEach(manager.topics) { topic in
                        CommunityManagedTopicRow(topic: topic)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                if !topic.isDeleted {
                                    Button(role: .destructive) {
                                        deletionItem = .topic(topic)
                                    } label: {
                                        Label(String(localized: "delete"), systemImage: "trash")
                                    }
                                }
                            }
                            .swipeActions(edge: .leading) {
                                if !topic.isDeleted {
                                    Button {
                                        editingItem = .topic(topic)
                                    } label: {
                                        Label(String(localized: "edit"), systemImage: "pencil")
                                    }
                                    .tint(.blue)
                                }
                            }
                    }
                }
            }

            Section(String(localized: "community_my_replies_section")) {
                if manager.isLoading && manager.replies.isEmpty {
                    ProgressView(String(localized: "community_loading_replies"))
                        .frame(maxWidth: .infinity, alignment: .center)
                } else if manager.replies.isEmpty {
                    emptyManagedContentRow(title: String(localized: "community_no_managed_replies"), systemImage: "text.bubble")
                } else {
                    ForEach(manager.replies) { reply in
                        CommunityManagedReplyRow(reply: reply)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                if !reply.isDeleted {
                                    Button(role: .destructive) {
                                        deletionItem = .reply(reply)
                                    } label: {
                                        Label(String(localized: "delete"), systemImage: "trash")
                                    }
                                }
                            }
                            .swipeActions(edge: .leading) {
                                if !reply.isDeleted {
                                    Button {
                                        editingItem = .reply(reply)
                                    } label: {
                                        Label(String(localized: "edit"), systemImage: "pencil")
                                    }
                                    .tint(.blue)
                                }
                            }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(String(localized: "community_my_content_title"))
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    manager.load()
                } label: {
                    Label(String(localized: "refresh"), systemImage: "arrow.clockwise")
                }
                .disabled(manager.isLoading || manager.isSaving)
            }
        }
        .onAppear {
            if manager.topics.isEmpty && manager.replies.isEmpty {
                manager.load()
            }
        }
        .sheet(item: $editingItem) { item in
            CommunityManagedContentEditView(item: item) { title, body, completion in
                save(item: item, title: title, body: body, completion: completion)
            }
        }
        .alert(String(localized: "community_delete_confirm_title"), isPresented: deleteAlertBinding) {
            Button(String(localized: "cancel"), role: .cancel) { deletionItem = nil }
            Button(String(localized: "delete"), role: .destructive) { deleteSelectedItem() }
        } message: {
            Text(String(localized: "community_delete_confirm_message"))
        }
        .overlay {
            if manager.isSaving {
                ProgressView(String(localized: "processing"))
                    .padding(16)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 4)
            }
        }
        .disabled(manager.isSaving)
    }

    private var deleteAlertBinding: Binding<Bool> {
        Binding(
            get: { deletionItem != nil },
            set: { isPresented in
                if !isPresented { deletionItem = nil }
            }
        )
    }

    private func save(item: CommunityManagedContentEditItem, title: String, body: String, completion: @escaping (Error?) -> Void) {
        switch item {
        case .topic(let topic):
            manager.updateTopic(topic, title: title, body: body, completion: completion)
        case .reply(let reply):
            manager.updateReply(reply, body: body, completion: completion)
        }
    }

    private func deleteSelectedItem() {
        guard let deletionItem else { return }
        switch deletionItem {
        case .topic(let topic):
            manager.deleteTopic(topic)
        case .reply(let reply):
            manager.deleteReply(reply)
        }
        self.deletionItem = nil
    }

    private func emptyManagedContentRow(title: String, systemImage: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(.secondary)
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 16)
    }
}

private struct CommunityManagedTopicRow: View {
    let topic: CommunityManagedTopic

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 8) {
                Label(topic.category.title, systemImage: topic.category.icon)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(topic.category.tint)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(topic.category.tint.opacity(0.12), in: Capsule())

                if topic.isDeleted {
                    Text(String(localized: "deleted"))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(relativeTime(topic.updatedAt))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Text(topic.title)
                .font(.headline)
                .foregroundStyle(topic.isDeleted ? .secondary : .primary)
                .lineLimit(2)

            if !topic.bodyPreview.isEmpty {
                Text(topic.bodyPreview)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 5)
    }
}

private struct CommunityManagedReplyRow: View {
    let reply: CommunityManagedReply

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 8) {
                Label(String(localized: "community_reply_label"), systemImage: "text.bubble.fill")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.12), in: Capsule())

                if reply.isDeleted {
                    Text(String(localized: "deleted"))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(relativeTime(reply.updatedAt))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Text(reply.bodyPreview.isEmpty ? String(localized: "community_no_content_placeholder") : reply.bodyPreview)
                .font(.subheadline)
                .foregroundStyle(reply.isDeleted ? .secondary : .primary)
                .lineLimit(3)

            Text(replyContextLine)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.vertical, 5)
    }

    private var replyContextLine: String {
        if !reply.title.isEmpty { return String(format: String(localized: "community_reply_topic_format"), reply.title) }
        return String(format: String(localized: "community_reply_topic_id_format"), reply.topicId)
    }
}

private struct CommunityManagedContentEditView: View {
    @Environment(\.dismiss) private var dismiss
    let item: CommunityManagedContentEditItem
    let save: (String, String, @escaping (Error?) -> Void) -> Void

    @State private var title: String
    @State private var bodyText: String
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(item: CommunityManagedContentEditItem, save: @escaping (String, String, @escaping (Error?) -> Void) -> Void) {
        self.item = item
        self.save = save
        switch item {
        case .topic(let topic):
            _title = State(initialValue: topic.title)
            _bodyText = State(initialValue: topic.body)
        case .reply(let reply):
            _title = State(initialValue: "")
            _bodyText = State(initialValue: reply.body)
        }
    }

    private var isTopic: Bool {
        if case .topic = item { return true }
        return false
    }

    private var canSave: Bool {
        let trimmedBody = bodyText.trimmingCharacters(in: .whitespacesAndNewlines)
        if isTopic {
            return !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !trimmedBody.isEmpty && !isSaving
        }
        return !trimmedBody.isEmpty && !isSaving
    }

    var body: some View {
        NavigationStack {
            Form {
                if isTopic {
                    Section {
                        TextField(String(localized: "community_topic_title_placeholder"), text: $title)
                        TextField(String(localized: "community_content_placeholder"), text: $bodyText, axis: .vertical)
                            .lineLimit(5...10)
                    } header: {
                        Text(String(localized: "community_topic_section"))
                    } footer: {
                        previewFooter
                    }
                } else {
                    Section {
                        TextField(String(localized: "community_content_placeholder"), text: $bodyText, axis: .vertical)
                            .lineLimit(4...8)
                    } header: {
                        Text(String(localized: "community_reply_label"))
                    } footer: {
                        previewFooter
                    }
                }

                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(String(localized: isTopic ? "community_edit_topic" : "community_edit_reply"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "save")) { submit() }
                        .disabled(!canSave)
                }
            }
        }
    }

    @ViewBuilder
    private var previewFooter: some View {
        if item.bodyPreview.hasSuffix("...") {
            Text(String(localized: "community_preview_only_footer"))
        }
    }

    private func submit() {
        guard canSave else { return }
        isSaving = true
        errorMessage = nil
        save(
            title.trimmingCharacters(in: .whitespacesAndNewlines),
            bodyText.trimmingCharacters(in: .whitespacesAndNewlines)
        ) { error in
            isSaving = false
            if let error {
                errorMessage = error.localizedDescription
            } else {
                dismiss()
            }
        }
    }
}

struct CommunityProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var profileManager: CommunityProfileManager
    @State private var nickname: String = ""
    @State private var showDepartment = true
    @State private var showYear = false
    @State private var showBadge = true

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(String(localized: "community_nickname_placeholder"), text: $nickname)
                    Toggle(String(localized: "community_default_show_department"), isOn: $showDepartment)
                    Toggle(String(localized: "community_publish_year"), isOn: $showYear)
                    Toggle(String(localized: "community_default_show_badge"), isOn: $showBadge)
                } header: {
                    Text(String(localized: "community_profile_title"))
                } footer: {
                    Text(String(localized: "community_profile_footer"))
                }

                if !profilePreviewLine.isEmpty || !profileManager.profile.schoolEmail.isEmpty {
                    Section(String(localized: "community_display_preview")) {
                        Label(profileManager.profile.nickname.isEmpty ? String(localized: "community_nickname_not_set") : profileManager.profile.nickname, systemImage: "person.fill")
                        if !profilePreviewLine.isEmpty {
                            Label(profilePreviewLine, systemImage: "person.text.rectangle")
                        }
                        if !profileManager.profile.schoolEmail.isEmpty {
                            Label(profileManager.profile.schoolEmail, systemImage: "envelope.fill")
                        }
                    }
                }

                Section {
                    Button {
                        profileManager.signInWithGoogleSchoolEmail()
                    } label: {
                        Label(String(localized: profileManager.profile.schoolEmail.isEmpty ? "community_google_verify_identity" : "community_google_change_account"), systemImage: "person.badge.key.fill")
                    }
                } footer: {
                    Text(String(localized: profileManager.profile.schoolEmail.isEmpty ? "community_google_verify_footer" : "community_google_change_footer"))
                }

                if let message = profileManager.authStatusMessage {
                    Section {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    Button {
                        save()
                    } label: {
                        Label(String(localized: "community_save_profile"), systemImage: "checkmark.circle.fill")
                    }
                }
            }
            .navigationTitle(String(localized: "community_profile_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "close")) { dismiss() }
                }
            }
            .onAppear {
                nickname = profileManager.profile.nickname
                showDepartment = profileManager.profile.showDepartment
                showYear = profileManager.profile.showYear
                showBadge = profileManager.profile.showBadge
            }
        }
    }

    private var profilePreviewLine: String {
        var preview = profileManager.profile
        preview.showDepartment = showDepartment
        preview.showYear = showYear
        preview.showBadge = showBadge
        return preview.displayLine
    }

    private func save() {
        let trimmedNickname = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        profileManager.profile.nickname = trimmedNickname.isEmpty ? CommunityProfileManager.ensureDefaultNickname(deviceId: profileManager.profile.deviceId) : trimmedNickname
        profileManager.profile.showDepartment = showDepartment
        profileManager.profile.showYear = showYear
        profileManager.profile.showBadge = showBadge
        profileManager.saveProfile()
        nickname = profileManager.profile.nickname
        profileManager.authStatusMessage = String(localized: "community_profile_saved")
    }
}

private func relativeTime(_ date: Date) -> String {
    let formatter = RelativeDateTimeFormatter()
    formatter.locale = Locale(identifier: "zh_Hant_TW")
    formatter.unitsStyle = .short
    return formatter.localizedString(for: date, relativeTo: Date())
}

private func authorProfileLine(department: String, entryYear: String, showsYear: Bool) -> String {
    var parts: [String] = []
    if !department.isEmpty { parts.append(department) }
    if showsYear, let gradeLine = currentGradeLine(entryYear: entryYear) { parts.append(gradeLine) }
    return parts.joined(separator: " · ")
}

private func badgeLevel(from rawValue: Int) -> CommentBadgeManager.BadgeLevel {
    CommentBadgeManager.BadgeLevel(rawValue: rawValue) ?? .newbie
}

private func authorBadgeLevel(from data: [String: Any]) -> Int {
    if let level = data["authorBadgeLevel"] as? Int {
        return badgeLevel(from: level).rawValue
    }
    if let count = data["authorBadgeCount"] as? Int {
        return CommentBadgeManager.badgeLevel(for: count).rawValue
    }
    return CommentBadgeManager.BadgeLevel.newbie.rawValue
}

private func communityDate(from value: Any?) -> Date {
    if let timestamp = value as? Timestamp {
        return timestamp.dateValue()
    }
    if let date = value as? Date {
        return date
    }
    if let isoString = value as? String {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = isoFormatter.date(from: isoString) {
            return date
        }
        isoFormatter.formatOptions = [.withInternetDateTime]
        if let date = isoFormatter.date(from: isoString) {
            return date
        }
    }
    if let seconds = value as? TimeInterval {
        return Date(timeIntervalSince1970: seconds)
    }
    return Date()
}

private func currentGradeLine(entryYear: String, now: Date = Date()) -> String? {
    guard let entryYear = Int(entryYear) else { return nil }

    let calendar = Calendar(identifier: .gregorian)
    let year = calendar.component(.year, from: now)
    let month = calendar.component(.month, from: now)
    let rocYear = year - 1911
    let academicYear = month >= 9 ? rocYear : rocYear - 1
    let grade = academicYear - entryYear + 1

    switch grade {
    case 1: return String(localized: "community_grade_first")
    case 2: return String(localized: "community_grade_second")
    case 3: return String(localized: "community_grade_third")
    case 4: return String(localized: "community_grade_fourth")
    case 5...: return String(format: String(localized: "community_grade_upper_format"), grade)
    default: return nil
    }
}
