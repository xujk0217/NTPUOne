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
import GoogleSignIn
import CloudKit
import PhotosUI
import Photos

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject var courseData: CourseData
    @EnvironmentObject private var adFree: AdFreeService
    @ObservedObject private var features = GlobalFeatureSettings.shared
    
    @ObservedObject var webManager = WebManager()
    @StateObject private var bikeManager = UbikeManager()
    @ObservedObject var weatherManager = WeatherManager()
    @StateObject private var orderManager = OrderManager()
    @ObservedObject var fManager = FManager()
    @StateObject private var memoManager: MemoManager
    @AppStorage("hasCompletedFirstRunOnboarding") private var hasCompletedFirstRunOnboarding = false
    
    @SceneStorage("ntpu.selectedTab") private var selectedTab = 0
    @State private var showFirstRunOnboarding = false
    @State private var aiPage: AIAppPage?
    @State private var aiChange: AIChangeProposal?
    @State private var aiBatch: AIChangeBatch?
    @StateObject private var academic = AcademicSyncStore()
    
    init() {
        let context = CoreDataManager.shared.persistentContainer.viewContext
        self._memoManager = StateObject(wrappedValue: MemoManager(context: context))
    }
    
    var body: some View {
        FloatingAIContainer(accountID: academic.uid, contextProvider: { request in
            await AIContextService.make(request, academic: academic, courses: courseData.courses,
                                        memos: memoManager.memos, bikes: bikeManager)
        }, hasSavedSchoolAccount: academic.schoolLinked,
           credentialProvider: { academic.savedSchoolCredentialForAI() }, openPage: openAIPage, reviewChange: { aiChange = $0 }, reviewBatch: { proposals, onComplete in aiBatch = AIChangeBatch(proposals: proposals, onComplete: onComplete) }) {
        TabView(selection: $selectedTab) {
            LinkView(orderManager: orderManager, courseData: courseData, memoManager: memoManager).tabItem {
                Image(systemName: "house")
                    .environment(\.symbolVariants, .none)
                Text("Main")
            }.tag(0)
            
            TodayView(memoManager: memoManager, courseData: courseData).tabItem {
                Image(systemName: "note.text")
                    .environment(\.symbolVariants, .none)
                Text(String(localized: "memo"))
            }.tag(1)
            
            TimeTableView(memoManager: memoManager).tabItem {
                Image(systemName: "list.bullet.clipboard")
                    .environment(\.symbolVariants, .none)
                Text(String(localized: "timetable"))
            }.tag(2)

            RemoteConfigFeatureGate(feature: .community) {
                CommunityView()
            }
            .tabItem {
                Image(systemName: "bubble.left.and.bubble.right")
                    .environment(\.symbolVariants, .none)
                Text(String(localized: "community_title"))
            }.tag(3)
            
            AboutView().tabItem {
                Image(systemName: "info.circle")
                    .environment(\.symbolVariants, .none)
                Text(String(localized: "my"))
            }.tag(4)
        }
        .accessibilityHidden(aiPage != nil)
        .allowsHitTesting(aiPage == nil)
        .overlay {
            if let page = aiPage {
                NavigationStack {
                    aiDestination(page)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) { Button("返回") { aiPage = nil } }
                        }
                }
                .background(Color(uiColor: .systemBackground))
            }
        }
        }
        .id(academic.uid)
        .environmentObject(academic)
        .sheet(item: $aiChange) { proposal in
            AIChangeReviewView(proposal: proposal, memoManager: memoManager, courseData: courseData)
                .environmentObject(academic)
                .environmentObject(adFree)
        }
        .sheet(item: $aiBatch) { batch in
            AIChangeBatchReviewView(batch: batch, memoManager: memoManager, courseData: courseData)
                .environmentObject(academic)
        }
        .sheet(isPresented: $academic.showConnection) {
            NavigationStack { AcademicConnectionPromptView().environmentObject(academic) }
        }
        .onChange(of: features.aiEnabled) { enabled in if !enabled { aiChange = nil; aiBatch = nil } }
        .onChange(of: academic.uid) { _ in
            aiChange = nil; aiBatch = nil; aiPage = nil
            if hasCompletedFirstRunOnboarding { academic.offerConnectionIfNeeded() }
        }
        .labelStyle(.compactIconText)
        .onOpenURL { url in
            handleDeepLink(url: url)
        }
        .fullScreenCover(isPresented: $showFirstRunOnboarding, onDismiss: { academic.offerConnectionIfNeeded() }) {
            FirstRunOnboardingView {
                hasCompletedFirstRunOnboarding = true
                showFirstRunOnboarding = false
            }
            .interactiveDismissDisabled()
        }
        .onAppear {
            academic.start(memos: memoManager, courses: courseData)
            if !hasCompletedFirstRunOnboarding {
                showFirstRunOnboarding = true
            } else { academic.offerConnectionIfNeeded() }
            NextCourseLiveActivityManager.shared.setApplicationActive(true)
            refreshLiveActivity()
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                Task { await academic.refresh() }
                NextCourseLiveActivityManager.shared.setApplicationActive(true)
                refreshLiveActivity()
            } else {
                NextCourseLiveActivityManager.shared.setApplicationActive(false)
            }
        }
    }

    private func openAIPage(_ page: AIAppPage) {
        aiPage = nil
        switch page {
        case .home: selectedTab = 0
        case .memo: selectedTab = 1
        case .timetable: selectedTab = 2
        case .community: selectedTab = 3
        case .profile: selectedTab = 4
        default: aiPage = page
        }
    }
    @ViewBuilder private func aiDestination(_ page: AIAppPage) -> some View {
        switch page {
        case .schoolAccount: AcademicConnectionView()
        case .grades: AcademicGradesView()
        case .graduation: AcademicSchoolReportView(kind: .graduation)
        case .announcements: SchoolPostView(memoManager: memoManager, courseData: courseData)
        case .links: CommonLinksView()
        case .bikes:
            if #available(iOS 17.0, *) { TrafficView() } else { BackTrafficView() }
        case .campusMap: CampusMapView()
        case .checklist: NewStudentChecklistView()
        case .breakfast: BreakfastView()
        case .lunch: LunchView()
        case .dinner: dinnerView()
        case .midnight: MSView()
        case .courseSearch: CourseGetView(courseData: courseData, isPresented: Binding(get: { aiPage != nil }, set: { if !$0 { aiPage = nil } }))
        case .privacy: PrivacyDataControlsView()
        case .feedback: FeaturesView()
        case .bugReport: ReportBugView()
        default: EmptyView()
        }
    }

    private func refreshLiveActivity() {
        Task { @MainActor in
            NextCourseLiveActivityManager.shared.sync(
                courses: courseData.courses,
                memos: memoManager.memos
            )
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

private struct CompactIconTextLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) {
            configuration.icon
            configuration.title
        }
    }
}

private extension LabelStyle where Self == CompactIconTextLabelStyle {
    static var compactIconText: CompactIconTextLabelStyle { CompactIconTextLabelStyle() }
}

#Preview {
    ContentView()
}

struct FirstRunOnboardingView: View {
    @StateObject private var profileManager = CommunityProfileManager()
    @ObservedObject private var features = GlobalFeatureSettings.shared
    @State private var selection = 0
    @State private var showFreshmanPrompt = false
    @State private var showLoginPrompt = false
    @State private var finishing = false
    @State private var loginPresenter = WeakScenePresentationController()
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let onFinish: () -> Void
    var autoFinishAfterAuth = true

    private var pages: [FirstRunOnboardingPage] {
        var pages: [FirstRunOnboardingPage] = [
        .init(
            titleKey: "onboarding_dashboard_title",
            messageKey: "onboarding_dashboard_message",
            systemImage: "rectangle.grid.2x2",
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
            systemImage: "person.text.rectangle",
            tint: .orange
        ),
        .init(
            titleKey: "onboarding_school_link_title",
            messageKey: "onboarding_school_link_message",
            systemImage: "building.columns",
            tint: .indigo
        )
        ]
        if features.aiEnabled {
            pages.append(.init(
                titleKey: "onboarding_ai_title",
                messageKey: "onboarding_ai_message",
                systemImage: "sparkles",
                tint: .purple
            ))
        }
        return pages
    }

    private var isLastPage: Bool {
        selection == pages.count - 1
    }

    private var hasGoogleSession: Bool {
        guard let user = Auth.auth().currentUser else { return false }
        return !profileManager.profile.ownerUid.isEmpty && profileManager.profile.ownerUid == user.uid
    }

    var body: some View {
        NavigationStack {
            GeometryReader { viewport in
            ScrollView {
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

                Group {
                    if showLoginPrompt {
                        FirstRunOnboardingLoginPromptCard(authStatusMessage: profileManager.authStatusMessage)
                            .padding(.horizontal)
                            .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    } else if showFreshmanPrompt {
                        FirstRunOnboardingFreshmanPromptCard()
                            .padding(.horizontal)
                            .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    } else {
                        TabView(selection: $selection) {
                            // `pages` is computed from feature settings; enumerate
                            // with a stable index so regenerated page values do not
                            // reset TabView's identity during an interactive swipe.
                            ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                                FirstRunOnboardingCard(page: page)
                                    .padding(.horizontal)
                                    .tag(index)
                            }
                        }
                        .tabViewStyle(.page(indexDisplayMode: .always))
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: dynamicTypeSize.isAccessibilitySize ? 680 : max(340, viewport.size.height - 250))

                VStack(spacing: 10) {
                    if showLoginPrompt {
                        Button {
                            profileManager.signInWithGoogleSchoolEmail(presenting: loginPresenter.controller)
                        } label: {
                            HStack(spacing: 10) {
                                if profileManager.isSigningIn { ProgressView().tint(.white) }
                                Label(String(localized: profileManager.isSigningIn ? "community_google_auth_opening" : "onboarding_google_login_button"), systemImage: "person.badge.key")
                            }
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.blue, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .foregroundStyle(.white)
                        }
                        .disabled(profileManager.isSigningIn)
                        .accessibilityLabel(String(localized: "onboarding_google_login_accessibility"))

                        Button(String(localized: "onboarding_google_continue_button")) {
                            onFinish()
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .accessibilityLabel(String(localized: "onboarding_google_continue_accessibility"))
                    } else if showFreshmanPrompt {
                        Button {
                            applyFreshmanPreference(true)
                        } label: {
                            Label(String(localized: "onboarding_freshman_yes_button"), systemImage: "checklist.checked")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.blue, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .foregroundStyle(.white)
                        }
                        .accessibilityLabel(String(localized: "onboarding_freshman_yes_accessibility"))

                        Button {
                            applyFreshmanPreference(false)
                        } label: {
                            Text(String(localized: "onboarding_freshman_no_button"))
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel(String(localized: "onboarding_freshman_no_accessibility"))
                    } else {
                        Button {
                            if isLastPage {
                                withAnimation(.easeInOut(duration: 0.22)) {
                                    showFreshmanPrompt = true
                                }
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
                }
                .padding(.horizontal)
                .padding(.bottom, 22)
            }
            }
            }
            .background(Color(.systemGroupedBackground))
            .background(ScenePresentationAnchor { loginPresenter.controller = $0 }.frame(width: 0, height: 0))
            .navigationTitle(String(localized: "onboarding_navigation_title"))
            .navigationBarTitleDisplayMode(.inline)
        }
        .task(id: "\(profileManager.profile.ownerUid):\(profileManager.isSigningIn)") {
            // Also handles an already-restored Firebase session on first presentation.
            guard autoFinishAfterAuth, !finishing, !profileManager.profile.ownerUid.isEmpty,
                  Auth.auth().currentUser?.uid == profileManager.profile.ownerUid,
                  !profileManager.isSigningIn else { return }
            do { try await Task.sleep(nanoseconds: 400_000_000) } catch { return }
            guard !Task.isCancelled, !profileManager.isSigningIn,
                  Auth.auth().currentUser?.uid == profileManager.profile.ownerUid else { return }
            finishing = true; onFinish()
        }
    }

    private func applyFreshmanPreference(_ isNewStudent: Bool) {
        StudentImpactStore.shared.applyNewStudentShortcutPreference(isNewStudent: isNewStudent)
        if hasGoogleSession {
            onFinish()
            return
        }
        withAnimation(.easeInOut(duration: 0.22)) {
            showFreshmanPrompt = false
            showLoginPrompt = true
        }
    }
}

private struct FirstRunOnboardingFreshmanPromptCard: View {
    var body: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 10)

            Image(systemName: "checklist.checked")
                .font(.system(size: 48, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.blue)
                .frame(width: 94, height: 94)
                .background(Color.blue.opacity(0.14), in: RoundedRectangle(cornerRadius: 24, style: .continuous))

            VStack(spacing: 10) {
                Text(String(localized: "onboarding_freshman_prompt_title"))
                    .font(.title2.weight(.semibold))
                    .multilineTextAlignment(.center)
                Text(String(localized: "onboarding_freshman_prompt_message"))
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
                        .stroke(Color.blue.opacity(0.18), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.08), radius: 14, x: 0, y: 7)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct FirstRunOnboardingLoginPromptCard: View {
    let authStatusMessage: String?

    var body: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 10)

            Image(systemName: "person.badge.key")
                .font(.system(size: 48, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.blue)
                .frame(width: 94, height: 94)
                .background(Color.blue.opacity(0.14), in: RoundedRectangle(cornerRadius: 24, style: .continuous))

            VStack(spacing: 10) {
                Text(String(localized: "onboarding_google_prompt_title"))
                    .font(.title2.weight(.semibold))
                    .multilineTextAlignment(.center)
                Text(String(localized: "onboarding_google_prompt_message"))
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }

            if let authStatusMessage {
                Label(authStatusMessage, systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .accessibilityLabel(String(format: String(localized: "onboarding_google_status_accessibility_format"), authStatusMessage))
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
                        .stroke(Color.blue.opacity(0.18), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.08), radius: 14, x: 0, y: 7)
        }
        .accessibilityElement(children: .combine)
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
        case .course: return "book.closed"
        case .campus: return "building.columns"
        case .question: return "questionmark.circle"
        case .trade: return "bag"
        case .meetup: return "person.2"
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

private struct CommunityTopic: Identifiable, Equatable, Hashable {
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
    var updatedAt: Date?
    var isDeleted: Bool = false
    var replyCount: Int
    var likeCount: Int = 0
    var imageRecordNames: [String] = []

    var imageRecordName: String? {
        imageRecordNames.first
    }

    var isEdited: Bool {
        !isDeleted && updatedAt != nil
    }

    static func from(document: QueryDocumentSnapshot) -> CommunityTopic? {
        from(id: document.documentID, data: document.data())
    }

    static func from(snapshot: DocumentSnapshot) -> CommunityTopic? {
        guard let data = snapshot.data() else { return nil }
        return from(id: snapshot.documentID, data: data)
    }

    private static func from(id: String, data: [String: Any]) -> CommunityTopic? {
        guard let title = data["title"] as? String,
              let body = data["body"] as? String,
              let rawCategory = data["category"] as? String,
              let category = CommunityCategory(rawValue: rawCategory),
              let authorName = data["authorName"] as? String else {
            return nil
        }

        let timestamp = data["createdAt"] as? Timestamp
        let legacyImageRecordName = (data["imageRecordName"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        let storedImageRecordNames = (data["imageRecordNames"] as? [String]) ?? []
        let imageRecordNames = Array(
            (storedImageRecordNames.isEmpty ? legacyImageRecordName.map { [$0] } ?? [] : storedImageRecordNames)
                .filter { !$0.isEmpty }
                .prefix(3)
        )
        return CommunityTopic(
            id: id,
            title: title,
            body: body,
            category: category,
            authorName: authorName,
            authorDeviceId: data["authorDeviceId"] as? String ?? "",
            authorDepartment: data["authorDepartment"] as? String ?? "",
            authorEntryYear: data["authorEntryYear"] as? String ?? "",
            authorShowsYear: data["authorShowsYear"] as? Bool ?? false,
            authorShowsBadge: data["authorShowsBadge"] as? Bool ?? ((data["authorBadgeCount"] as? Int ?? 0) > 0),
            authorBadgeLevel: communityAuthorBadgeLevel(from: data),
            createdAt: timestamp?.dateValue() ?? Date(),
            updatedAt: communityOptionalDate(from: data["updatedAt"]),
            isDeleted: data["isDeleted"] as? Bool ?? false,
            replyCount: data["replyCount"] as? Int ?? 0,
            likeCount: data["likeCount"] as? Int ?? 0,
            imageRecordNames: imageRecordNames
        )
    }
}

@MainActor
final class CommunityImageService {
    static let shared = CommunityImageService()
    nonisolated static let maximumUploadBytes = 5 * 1024 * 1024
    nonisolated static let maximumImageDimension: CGFloat = 2_048
    nonisolated static let maximumImagesPerTopic = 3

    enum ImageError: LocalizedError {
        case invalidImage
        case imageTooLarge
        case tooManyImages
        case iCloudUnavailable
        case missingAsset

        var errorDescription: String? {
            switch self {
            case .invalidImage: return String(localized: "community_image_invalid")
            case .imageTooLarge: return String(localized: "community_image_too_large")
            case .tooManyImages: return String(localized: "community_image_too_many")
            case .iCloudUnavailable: return String(localized: "community_image_icloud_required")
            case .missingAsset: return String(localized: "community_image_load_failed")
            }
        }
    }

    private let container = CKContainer(identifier: "iCloud.com.xujk.NTPUOne")
    private let cache = NSCache<NSString, UIImage>()

    private var database: CKDatabase { container.publicCloudDatabase }

    nonisolated static func recordName(for topicID: String, index: Int = 0) -> String {
        let baseName = "community-topic-\(topicID)"
        return index == 0 ? baseName : "\(baseName)-\(index)"
    }

    func preparedJPEG(from sourceData: Data) throws -> Data {
        guard let sourceImage = UIImage(data: sourceData) else { throw ImageError.invalidImage }

        let sourceSize = sourceImage.size
        let largestDimension = max(sourceSize.width, sourceSize.height)
        let scale = min(1, Self.maximumImageDimension / max(largestDimension, 1))
        let targetSize = CGSize(
            width: max(1, floor(sourceSize.width * scale)),
            height: max(1, floor(sourceSize.height * scale))
        )
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let resizedImage = renderer.image { _ in
            sourceImage.draw(in: CGRect(origin: .zero, size: targetSize))
        }

        var quality: CGFloat = 0.86
        while quality >= 0.42 {
            if let data = resizedImage.jpegData(compressionQuality: quality), data.count <= Self.maximumUploadBytes {
                return data
            }
            quality -= 0.08
        }
        throw ImageError.imageTooLarge
    }

    func uploadJPEGs(_ dataList: [Data], topicID: String, ownerUID: String) async throws -> [String] {
        let recordNames = dataList.indices.map { Self.recordName(for: topicID, index: $0) }
        return try await uploadJPEGs(
            dataList,
            topicID: topicID,
            ownerUID: ownerUID,
            recordNames: recordNames
        )
    }

    func uploadJPEGs(
        _ dataList: [Data],
        topicID: String,
        ownerUID: String,
        recordNames: [String]
    ) async throws -> [String] {
        guard dataList.count <= Self.maximumImagesPerTopic,
              dataList.count == recordNames.count,
              Set(recordNames).count == recordNames.count else {
            throw ImageError.tooManyImages
        }
        guard dataList.allSatisfy({ $0.count <= Self.maximumUploadBytes }) else { throw ImageError.imageTooLarge }
        guard !dataList.isEmpty else { return [] }
        let canonicalRecordNames = Set(
            (0..<Self.maximumImagesPerTopic).map { Self.recordName(for: topicID, index: $0) }
        )
        let editRecordPrefix = "\(Self.recordName(for: topicID))-edit-"
        guard recordNames.allSatisfy({
            canonicalRecordNames.contains($0) || $0.hasPrefix(editRecordPrefix)
        }) else {
            throw ImageError.invalidImage
        }
        guard try await iCloudAccountIsAvailable() else { throw ImageError.iCloudUnavailable }

        var uploadedRecordNames: [String] = []
        do {
            for (data, recordName) in zip(dataList, recordNames) {
                try await uploadJPEG(data, recordName: recordName, topicID: topicID, ownerUID: ownerUID)
                uploadedRecordNames.append(recordName)
            }
            return uploadedRecordNames
        } catch {
            await deleteImages(recordNames: uploadedRecordNames)
            throw error
        }
    }

    private func uploadJPEG(_ data: Data, recordName: String, topicID: String, ownerUID: String) async throws {
        let temporaryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(recordName)-\(UUID().uuidString).jpg")
        try data.write(to: temporaryURL, options: .atomic)
        defer { try? FileManager.default.removeItem(at: temporaryURL) }

        let recordID = CKRecord.ID(recordName: recordName)
        let record: CKRecord
        do {
            record = try await database.record(for: recordID)
        } catch let error as CKError where error.code == .unknownItem {
            record = CKRecord(recordType: "CommunityImage", recordID: recordID)
        }
        record["image"] = CKAsset(fileURL: temporaryURL)
        record["topicID"] = topicID as CKRecordValue
        record["ownerUID"] = ownerUID as CKRecordValue
        record["createdAt"] = Date() as CKRecordValue
        _ = try await database.save(record)

        if let image = UIImage(data: data) {
            cache.setObject(image, forKey: recordName as NSString)
        }
    }

    func image(recordName: String) async throws -> UIImage {
        if let cached = cache.object(forKey: recordName as NSString) { return cached }
        let record = try await database.record(for: CKRecord.ID(recordName: recordName))
        guard let asset = record["image"] as? CKAsset,
              let fileURL = asset.fileURL,
              let image = UIImage(data: try Data(contentsOf: fileURL)) else {
            throw ImageError.missingAsset
        }
        cache.setObject(image, forKey: recordName as NSString)
        return image
    }

    func deleteImages(topicID: String) async {
        let recordNames = (0..<Self.maximumImagesPerTopic).map { Self.recordName(for: topicID, index: $0) }
        await deleteImages(recordNames: recordNames)
    }

    func deleteImages(recordNames: [String]) async {
        for recordName in recordNames {
            await deleteImage(recordName: recordName)
        }
    }

    private func deleteImage(recordName: String) async {
        do {
            _ = try await database.deleteRecord(withID: CKRecord.ID(recordName: recordName))
            cache.removeObject(forKey: recordName as NSString)
        } catch let error as CKError where error.code == .unknownItem {
            cache.removeObject(forKey: recordName as NSString)
        } catch {
            print("Failed to delete community image: \(error.localizedDescription)")
        }
    }

    private func iCloudAccountIsAvailable() async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            container.accountStatus { status, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: status == .available)
                }
            }
        }
    }
}

@MainActor
private final class CommunityImageLoader: ObservableObject {
    @Published var image: UIImage?
    @Published var failed = false
    private var loadedRecordName: String?

    func load(recordName: String) async {
        // 當 recordName 改變（例如編輯後換成新圖片）時，必須清除舊圖並重新載入，
        // 否則同一個 loader 實例會因 guard 而保留舊圖片，導致貼文頁面只刷新文字、不刷新圖片。
        if loadedRecordName == recordName, image != nil || failed { return }
        loadedRecordName = recordName
        image = nil
        failed = false
        do {
            image = try await CommunityImageService.shared.image(recordName: recordName)
        } catch {
            failed = true
        }
    }
}

private struct CommunityTopicImageView: View {
    let recordName: String
    @StateObject private var loader = CommunityImageLoader()

    var body: some View {
        Group {
            if let image = loader.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            } else if loader.failed {
                Label(String(localized: "community_image_load_failed"), systemImage: "photo.badge.exclamationmark")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 100)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 140)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .task(id: recordName) {
            await loader.load(recordName: recordName)
        }
    }
}

private struct CommunityTopicImageThumbnail: View {
    let recordName: String
    @StateObject private var loader = CommunityImageLoader()

    var body: some View {
        Group {
            if let image = loader.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if loader.failed {
                Image(systemName: "photo.badge.exclamationmark")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.quaternary)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.quaternary)
            }
        }
        .frame(width: 52, height: 52)
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .task(id: recordName) {
            await loader.load(recordName: recordName)
        }
    }
}

private struct CommunityTopicThumbnailStrip: View {
    let recordNames: [String]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(recordNames.prefix(CommunityImageService.maximumImagesPerTopic), id: \.self) { recordName in
                CommunityTopicImageThumbnail(recordName: recordName)
            }
        }
    }
}

private struct CommunityTopicImagesView: View {
    let recordNames: [String]
    @State private var previewIndex = 0
    @State private var showBrowser = false

    var body: some View {
        Group {
            if recordNames.count == 1, let recordName = recordNames.first {
                CommunityTopicImageView(recordName: recordName)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        previewIndex = 0
                        showBrowser = true
                    }
            } else if !recordNames.isEmpty {
                TabView(selection: $previewIndex) {
                    ForEach(Array(recordNames.enumerated()), id: \.element) { index, recordName in
                        CommunityTopicImageView(recordName: recordName)
                            .padding(.horizontal, 2)
                            .tag(index)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                previewIndex = index
                                showBrowser = true
                            }
                        }
                }
                .frame(height: 300)
                .tabViewStyle(.page(indexDisplayMode: .always))
            }
        }
        .overlay(alignment: .topTrailing) {
            if !recordNames.isEmpty {
                Text("\(previewIndex + 1)/\(recordNames.count)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(.black.opacity(0.58), in: Capsule())
                    .padding(10)
                    .allowsHitTesting(false)
            }
        }
        .fullScreenCover(isPresented: $showBrowser) {
            CommunityImageBrowserView(recordNames: recordNames, initialIndex: previewIndex)
        }
    }
}

private struct CommunityImageBrowserView: View {
    @Environment(\.dismiss) private var dismiss
    let recordNames: [String]
    let initialIndex: Int

    @State private var selectedIndex: Int
    @State private var images: [String: UIImage] = [:]
    @State private var failedRecordNames = Set<String>()
    @State private var showShareSheet = false
    @State private var saveMessage: String?

    init(recordNames: [String], initialIndex: Int) {
        self.recordNames = recordNames
        self.initialIndex = initialIndex
        _selectedIndex = State(initialValue: min(max(initialIndex, 0), max(recordNames.count - 1, 0)))
    }

    private var currentRecordName: String? {
        guard recordNames.indices.contains(selectedIndex) else { return nil }
        return recordNames[selectedIndex]
    }

    private var currentImage: UIImage? {
        currentRecordName.flatMap { images[$0] }
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let currentRecordName {
                CommunityZoomableImagePage(
                    image: images[currentRecordName],
                    failed: failedRecordNames.contains(currentRecordName),
                    onDismiss: { dismiss() },
                    onPageChange: changePage
                )
                .id(currentRecordName)
            }
        }
        .safeAreaInset(edge: .top) {
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.headline.weight(.bold))
                        .frame(width: 42, height: 42)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .buttonStyle(.plain)

                Spacer()

                Text("\(selectedIndex + 1) / \(recordNames.count)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 12) {
                Button {
                    showShareSheet = true
                } label: {
                    Label(String(localized: "community_image_share"), systemImage: "square.and.arrow.up")
                }
                .disabled(currentImage == nil)

                Button {
                    saveCurrentImage()
                } label: {
                    Label(String(localized: "community_image_save"), systemImage: "arrow.down.to.line.compact")
                }
                .disabled(currentImage == nil)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial, in: Capsule())
            .padding(.bottom, 12)
        }
        .sheet(isPresented: $showShareSheet) {
            if let currentImage {
                CommunityActivitySheet(items: [currentImage])
            }
        }
        .overlay(alignment: .bottom) {
            if let saveMessage {
                Text(saveMessage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(.black.opacity(0.75), in: Capsule())
                    .padding(.bottom, 92)
            }
        }
        .task {
            await loadImages()
        }
    }

    private func loadImages() async {
        for recordName in recordNames where images[recordName] == nil && !failedRecordNames.contains(recordName) {
            do {
                images[recordName] = try await CommunityImageService.shared.image(recordName: recordName)
            } catch {
                failedRecordNames.insert(recordName)
            }
        }
    }

    private func saveCurrentImage() {
        guard let currentImage else { return }
        UIImageWriteToSavedPhotosAlbum(currentImage, nil, nil, nil)
        saveMessage = String(localized: "community_image_saved")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            saveMessage = nil
        }
    }

    private func changePage(by offset: Int) {
        let nextIndex = selectedIndex + offset
        guard recordNames.indices.contains(nextIndex) else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            selectedIndex = nextIndex
        }
    }
}

private struct CommunityZoomableImagePage: View {
    let image: UIImage?
    let failed: Bool
    let onDismiss: () -> Void
    let onPageChange: (Int) -> Void

    @State private var scale: CGFloat = 1
    @State private var transientScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var transientOffset: CGSize = .zero
    @State private var dismissOffset: CGFloat = 0
    @State private var horizontalPageOffset: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            Group {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .scaleEffect(scale * transientScale)
                        .offset(
                            x: offset.width + transientOffset.width + horizontalPageOffset,
                            y: offset.height + transientOffset.height + dismissOffset
                        )
                        .scaleEffect(1 - min(dismissOffset / 1_800, 0.08))
                        .opacity(1 - min(dismissOffset / 900, 0.35))
                } else if failed {
                    Label(String(localized: "community_image_load_failed"), systemImage: "photo.badge.exclamationmark")
                        .foregroundStyle(.white.opacity(0.85))
                } else {
                    ProgressView()
                        .tint(.white)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .contentShape(Rectangle())
            .clipped()
            .gesture(magnificationGesture)
            .modifier(
                CommunityImagePageDragModifier(
                    scale: $scale,
                    offset: $offset,
                    transientOffset: $transientOffset,
                    dismissOffset: $dismissOffset,
                    horizontalPageOffset: $horizontalPageOffset,
                    onDismiss: onDismiss,
                    onPageChange: onPageChange
                )
            )
            .onTapGesture(count: 2) {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                    if scale > 1 {
                        scale = 1
                        offset = .zero
                    } else {
                        scale = 2.5
                    }
                }
            }
        }
    }

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                transientScale = value
            }
            .onEnded { value in
                scale = min(max(scale * value, 1), 4)
                transientScale = 1
                if scale == 1 { offset = .zero }
            }
    }

}

private struct CommunityImagePageDragModifier: ViewModifier {
    @Binding var scale: CGFloat
    @Binding var offset: CGSize
    @Binding var transientOffset: CGSize
    @Binding var dismissOffset: CGFloat
    @Binding var horizontalPageOffset: CGFloat
    let onDismiss: () -> Void
    let onPageChange: (Int) -> Void

    func body(content: Content) -> some View {
        if scale > 1 {
            content.highPriorityGesture(dragGesture)
        } else {
            content.simultaneousGesture(dragGesture)
        }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if scale > 1 {
                    transientOffset = value.translation
                    dismissOffset = 0
                } else if value.translation.height > 0,
                          abs(value.translation.height) > abs(value.translation.width) {
                    dismissOffset = value.translation.height
                    horizontalPageOffset = 0
                } else if abs(value.translation.width) > abs(value.translation.height) {
                    horizontalPageOffset = value.translation.width
                    dismissOffset = 0
                }
            }
            .onEnded { value in
                if scale > 1 {
                    offset.width += value.translation.width
                    offset.height += value.translation.height
                    transientOffset = .zero
                    return
                }

                if abs(value.translation.width) > abs(value.translation.height) {
                    let pageChangeThreshold: CGFloat = 75
                    let pageOffset = value.translation.width < -pageChangeThreshold ? 1 : (value.translation.width > pageChangeThreshold ? -1 : 0)
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                        horizontalPageOffset = 0
                    }
                    if pageOffset != 0 {
                        onPageChange(pageOffset)
                    }
                    return
                }

                let predictedDownwardDistance = value.predictedEndTranslation.height
                if dismissOffset > 120 || predictedDownwardDistance > 220 {
                    onDismiss()
                } else {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                        dismissOffset = 0
                    }
                }
            }
    }
}

private struct CommunityActivitySheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct CommentIdentityBar: View {
    var showsDepartmentAndYear: Bool = true
    /// false 時僅顯示資訊、不可點擊設定（如餐廳留言）
    var interactive: Bool = true

    @AppStorage("commentNickname") private var nickname: String = ""
    @AppStorage("communityDepartment") private var department: String = ""
    @AppStorage("communityEntryYear") private var entryYear: String = ""
    @AppStorage("communityShowDepartment") private var showDepartment = true
    @AppStorage("communityShowYear") private var showYear = false
    @AppStorage("communityShowBadge") private var showBadge = true

    @State private var showEditor = false

    var body: some View {
        if interactive {
            interactiveBar
        } else {
            staticBar
        }
    }

    private var barContent: some View {
        HStack(spacing: 6) {
            Text(nicknameDisplay)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)

            if showsDepartmentAndYear {
                if showDepartment, !department.isEmpty {
                    Text(department)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                if showYear, !entryYear.isEmpty,
                   let gradeLine = currentGradeLine(entryYear: entryYear) {
                    Text(gradeLine)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            if showBadge {
                BadgeTagView(badge: CommentBadgeManager.shared.getCurrentBadge(), compact: true)
            }

            if interactive {
                Image(systemName: "slider.horizontal.3")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var interactiveBar: some View {
        Button {
            showEditor = true
        } label: {
            barContent
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showEditor) {
            NavigationStack {
                Form {
                    Toggle(String(localized: "community_publish_department"), isOn: $showDepartment)
                    Toggle(String(localized: "community_publish_year"), isOn: $showYear)
                    Toggle(String(localized: "community_publish_badge"), isOn: $showBadge)
                }
                .navigationTitle(String(localized: "community_identity_sheet_title"))
                .navigationBarTitleDisplayMode(.inline)
            }
            .presentationDetents([.medium])
            .onDisappear {
                CommunityProfileManager.persistDisplayFlagsFromDefaults()
            }
        }
    }

    private var staticBar: some View {
        barContent
    }

    private var nicknameDisplay: String {
        CommunityProfileManager.currentNicknameDisplayName()
    }
}

struct CommunityDepartmentChoice: Identifiable, Equatable {
    let name: String
    var id: String { name }
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
    // 轉系／雙主修／手動修正：設為 true 後登入自動推導不再覆蓋科系或入學年
    var departmentIsCustom: Bool = false
    var entryYearIsCustom: Bool = false

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

    var updatedAt: Date?

    var isEdited: Bool {
        updatedAt != nil
    }
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
    var imageRecordNames: [String]

    static func from(_ data: [String: Any]) -> CommunityManagedTopic? {
        guard let topicId = data["topicId"] as? String,
              let rawCategory = data["category"] as? String,
              let category = CommunityCategory(rawValue: rawCategory),
              let title = data["title"] as? String else {
            return nil
        }

        let legacyImageRecordName = (data["imageRecordName"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        let storedImageRecordNames = (data["imageRecordNames"] as? [String]) ?? []
        let imageRecordNames = Array(
            (storedImageRecordNames.isEmpty ? legacyImageRecordName.map { [$0] } ?? [] : storedImageRecordNames)
                .filter { !$0.isEmpty }
                .prefix(CommunityImageService.maximumImagesPerTopic)
        )

        return CommunityManagedTopic(
            id: data["id"] as? String ?? topicId,
            topicId: topicId,
            category: category,
            title: title,
            body: data["body"] as? String ?? data["bodyPreview"] as? String ?? "",
            bodyPreview: data["bodyPreview"] as? String ?? "",
            createdAt: communityDate(from: data["createdAt"]),
            updatedAt: communityDate(from: data["updatedAt"]),
            isDeleted: data["isDeleted"] as? Bool ?? false,
            imageRecordNames: imageRecordNames
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

private struct CommunityUserFacingError: LocalizedError {
    let message: String

    var errorDescription: String? { message }
}

private func requireCommunityUser() throws -> User {
    guard let user = Auth.auth().currentUser else {
        throw CommunityUserFacingError(message: String(localized: "community_google_sign_in_required_error"))
    }
    return user
}

private func communityErrorMessage(_ error: Error) -> String {
    if let error = error as? CommunityUserFacingError {
        return error.message
    }

    let nsError = error as NSError
    if nsError.domain == FirestoreErrorDomain,
       let code = FirestoreErrorCode.Code(rawValue: nsError.code) {
        switch code {
        case .permissionDenied:
            return String(localized: "community_firebase_permission_error")
        case .unauthenticated:
            return String(localized: "community_google_sign_in_required_error")
        case .unavailable, .deadlineExceeded:
            return String(localized: "community_firebase_unavailable_error")
        case .notFound:
            return String(localized: "community_firebase_not_found_error")
        default:
            break
        }
    }

    if nsError.localizedDescription.localizedCaseInsensitiveContains("not-found") ||
        nsError.localizedDescription.localizedCaseInsensitiveContains("not found") {
        return String(localized: "community_firebase_not_found_error")
    }

    return nsError.localizedDescription
}

final class CommunityProfileManager: ObservableObject {
    @Published var profile: CommunityProfile
    @Published private(set) var isSigningIn = false
    @Published var authStatusMessage: String?
    @Published var pendingDepartmentChoices: [CommunityDepartmentChoice]?
    private let db = Firestore.firestore()
    private var authStateHandle: AuthStateDidChangeListenerHandle?
    private static let displayPropagationQueue = DispatchQueue(label: "ntpuone.community.profilePropagation")
    private static var displayPropagationGeneration = 0

    func confirmDepartmentChoice(_ name: String) {
        profile.department = name
        profile.departmentIsCustom = true
        pendingDepartmentChoices = nil
        saveProfile()
    }

    func dismissDepartmentChoices() {
        pendingDepartmentChoices = nil
    }

    /// 手動調整科系（轉系／雙主修／輔修標示）；設定後登入推導不再覆蓋
    func updateDepartment(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        profile.department = trimmed
        profile.departmentIsCustom = true
        saveProfile()
    }

    /// 手動更新入學年（民國三位數）；年級顯示會依此即時重算，並同步到雲端與舊文
    func updateEntryYear(_ raw: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count == 3, trimmed.allSatisfy(\.isNumber),
              let value = Int(trimmed), (100...150).contains(value) else {
            authStatusMessage = String(localized: "community_entry_year_invalid")
            return
        }
        authStatusMessage = nil
        profile.entryYear = trimmed
        profile.entryYearIsCustom = true
        saveProfile()
    }

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
            ownerEmail: currentUser?.email ?? defaults.string(forKey: "communityOwnerEmail") ?? "",
            departmentIsCustom: defaults.bool(forKey: "communityDepartmentIsCustom"),
            entryYearIsCustom: defaults.bool(forKey: "communityEntryYearIsCustom")
        )

        if let currentEmail = currentUser?.email?.lowercased() {
            applyAccountIdentity(email: currentEmail)
        }

        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self else { return }
            DispatchQueue.main.async {
                if let user {
                    self.profile.ownerUid = user.uid
                    self.profile.ownerEmail = user.email ?? ""
                    if let email = user.email?.lowercased() {
                        self.applyAccountIdentity(email: email)
                    }
                    self.saveProfileLocally()
                    self.loadAccountProfile(uid: user.uid)
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

    static func currentNicknameDisplayName() -> String {
        ensureDefaultNickname().trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func currentGoogleDisplayName() -> String {
        guard let user = Auth.auth().currentUser else {
            return String(localized: "community_guest_display_name")
        }

        if let displayName = user.displayName?.trimmingCharacters(in: .whitespacesAndNewlines), !displayName.isEmpty {
            return displayName
        }

        if let email = user.email?.trimmingCharacters(in: .whitespacesAndNewlines), !email.isEmpty {
            let parts = email.split(separator: "@", maxSplits: 1, omittingEmptySubsequences: false)
            if let localPart = parts.first, !localPart.isEmpty {
                return String(localPart)
            }
            return email
        }

        return String(localized: "community_guest_display_name")
    }

    static func currentAccountDisplayName() -> String {
        let nickname = currentNicknameDisplayName()
        guard Auth.auth().currentUser != nil else { return nickname }

        let googleName = currentGoogleDisplayName()
        guard !googleName.isEmpty, googleName != nickname, googleName != String(localized: "community_guest_display_name") else {
            return nickname
        }

        return String(format: String(localized: "account_nickname_real_name_format"), nickname, googleName)
    }

    private static func defaultBool(forKey key: String, defaultValue: Bool) -> Bool {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: key) != nil else { return defaultValue }
        return defaults.bool(forKey: key)
    }

    private static func locallySavedProfile() -> CommunityProfile {
        let defaults = UserDefaults.standard
        return CommunityProfile(
            nickname: defaults.string(forKey: "commentNickname") ?? ensureDefaultNickname(),
            deviceId: defaults.string(forKey: "commentDeviceId") ?? ensureDeviceId(),
            schoolEmail: defaults.string(forKey: "communitySchoolEmail") ?? "",
            department: defaults.string(forKey: "communityDepartment") ?? "",
            entryYear: defaults.string(forKey: "communityEntryYear") ?? "",
            showDepartment: Self.defaultBool(forKey: "communityShowDepartment", defaultValue: true),
            showYear: defaults.bool(forKey: "communityShowYear"),
            showBadge: Self.defaultBool(forKey: "communityShowBadge", defaultValue: true),
            ownerUid: defaults.string(forKey: "communityOwnerUid") ?? "",
            ownerEmail: defaults.string(forKey: "communityOwnerEmail") ?? "",
            departmentIsCustom: defaults.bool(forKey: "communityDepartmentIsCustom"),
            entryYearIsCustom: defaults.bool(forKey: "communityEntryYearIsCustom")
        )
    }

    func saveProfile() {
        let previousProfile = Self.locallySavedProfile()
        saveProfileLocally()

        // 未登入時僅保留本地設定；rules 已要求雲端 profile 寫入需登入
        guard Auth.auth().currentUser != nil else {
            authStatusMessage = nil
            return
        }

        let deviceSecret = Self.ensureDeviceSecret()
        let group = DispatchGroup()
        let lock = NSLock()
        var savedError: Error?

        group.enter()
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
        ], merge: true) { error in
            if let error {
                lock.lock()
                savedError = error
                lock.unlock()
            }
            group.leave()
        }

        if !profile.ownerUid.isEmpty {
            group.enter()
            db.collection("communityUserProfiles").document(profile.ownerUid).setData([
                "nickname": profile.nickname,
                "schoolEmail": profile.schoolEmail,
                "department": profile.department,
                "entryYear": profile.entryYear,
                "showDepartment": profile.showDepartment,
                "showYear": profile.showYear,
                "showBadge": profile.showBadge,
                "ownerEmail": profile.ownerEmail,
                "updatedAt": FieldValue.serverTimestamp()
            ], merge: true) { error in
                if let error {
                    lock.lock()
                    savedError = savedError ?? error
                    lock.unlock()
                }
                group.leave()
            }
        }

        group.notify(queue: .main) { [weak self] in
            guard let self else { return }
            self.authStatusMessage = savedError.map { _ in String(localized: "community_profile_save_failed") }
        }

        propagateDisplayChangesIfNeeded(from: previousProfile)
    }

    private func propagateDisplayChangesIfNeeded(from previousProfile: CommunityProfile) {
        guard let user = Auth.auth().currentUser, user.uid == profile.ownerUid else { return }

        let nicknameChanged = previousProfile.nickname != profile.nickname
        let departmentChanged = previousProfile.department != profile.department || previousProfile.showDepartment != profile.showDepartment
        let yearChanged = previousProfile.entryYear != profile.entryYear || previousProfile.showYear != profile.showYear
        let badgeChanged = previousProfile.showBadge != profile.showBadge

        guard nicknameChanged || departmentChanged || yearChanged || badgeChanged else { return }

        Self.propagateOwnedPublicDisplay(
            uid: user.uid,
            nickname: profile.nickname,
            department: profile.showDepartment ? profile.department : "",
            entryYear: profile.showYear ? profile.entryYear : "",
            badgeLevel: profile.showBadge ? CommentBadgeManager.shared.getCurrentBadge().rawValue : CommentBadgeManager.BadgeLevel.newbie.rawValue,
            showsBadge: profile.showBadge,
            updateNickname: nicknameChanged,
            updateDepartment: departmentChanged,
            updateYear: yearChanged,
            updateBadge: badgeChanged
        )
    }

    static func propagateCurrentBadgeLevelIfNeeded() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        propagateOwnedPublicDisplay(
            uid: uid,
            nickname: currentNicknameDisplayName(),
            department: nil,
            entryYear: nil,
            badgeLevel: CommentBadgeManager.shared.getCurrentBadge().rawValue,
            showsBadge: nil,
            updateNickname: false,
            updateDepartment: false,
            updateYear: false,
            updateBadge: true
        )
    }

    private static func propagateOwnedPublicDisplay(
        uid: String,
        nickname: String,
        department: String?,
        entryYear: String?,
        badgeLevel: Int,
        showsBadge: Bool?,
        updateNickname: Bool,
        updateDepartment: Bool,
        updateYear: Bool,
        updateBadge: Bool
    ) {
        let db = Firestore.firestore()
        let ownerRoot = db.collection("communityContentOwners").document(uid)
        let trimmedNickname = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        let generation = nextDisplayPropagationGeneration()

        ownerRoot.collection("topics").getDocuments { snapshot, error in
            guard isCurrentDisplayPropagation(generation) else { return }
            if let error {
                print("Profile display propagation topic owner load failed: \(error.localizedDescription)")
                return
            }
            snapshot?.documents.forEach { ownerDocument in
                let topicId = ownerDocument.data()["topicId"] as? String ?? ownerDocument.documentID
                guard !topicId.isEmpty else { return }
                let publicRef = db.collection("communityTopics").document(topicId)
                publicRef.getDocument { publicSnapshot, _ in
                    guard isCurrentDisplayPropagation(generation) else { return }
                    guard let data = publicSnapshot?.data() else { return }
                    let updates = communityDisplayUpdates(
                        from: data,
                        nickname: trimmedNickname,
                        department: department,
                        entryYear: entryYear,
                        badgeLevel: badgeLevel,
                        showsBadge: showsBadge,
                        updateNickname: updateNickname,
                        updateDepartment: updateDepartment,
                        updateYear: updateYear,
                        updateBadge: updateBadge
                    )
                    guard !updates.isEmpty else { return }
                    publicRef.updateData(updates) { error in
                        if let error, isCurrentDisplayPropagation(generation) {
                            print("Profile display propagation topic update failed: \(error.localizedDescription)")
                        }
                    }
                }
            }
        }

        ownerRoot.collection("replies").getDocuments { snapshot, error in
            guard isCurrentDisplayPropagation(generation) else { return }
            if let error {
                print("Profile display propagation reply owner load failed: \(error.localizedDescription)")
                return
            }
            snapshot?.documents.forEach { ownerDocument in
                let ownerData = ownerDocument.data()
                guard let topicId = ownerData["topicId"] as? String,
                      let replyId = ownerData["replyId"] as? String,
                      !topicId.isEmpty,
                      !replyId.isEmpty else { return }
                let publicRef = db.collection("communityTopics").document(topicId).collection("replies").document(replyId)
                publicRef.getDocument { publicSnapshot, _ in
                    guard isCurrentDisplayPropagation(generation) else { return }
                    guard let data = publicSnapshot?.data() else { return }
                    let updates = communityDisplayUpdates(
                        from: data,
                        nickname: trimmedNickname,
                        department: department,
                        entryYear: entryYear,
                        badgeLevel: badgeLevel,
                        showsBadge: showsBadge,
                        updateNickname: updateNickname,
                        updateDepartment: updateDepartment,
                        updateYear: updateYear,
                        updateBadge: updateBadge
                    )
                    guard !updates.isEmpty else { return }
                    publicRef.updateData(updates) { error in
                        if let error, isCurrentDisplayPropagation(generation) {
                            print("Profile display propagation reply update failed: \(error.localizedDescription)")
                        }
                    }
                }
            }
        }

        // 餐廳留言也要跟著目前帳號狀態同步暱稱／徽章，讓其他使用者看到最新身份。
        guard updateNickname || updateBadge else { return }
        db.collection("restaurantCommentOwners").document(uid).collection("comments").getDocuments { snapshot, error in
            guard isCurrentDisplayPropagation(generation) else { return }
            if let error {
                print("Profile display propagation restaurant owner load failed: \(error.localizedDescription)")
                return
            }
            snapshot?.documents.forEach { ownerDocument in
                let ownerData = ownerDocument.data()
                guard let mealCollection = ownerData["mealCollection"] as? String,
                      let storeId = ownerData["storeId"] as? String,
                      let commentId = ownerData["commentId"] as? String,
                      !mealCollection.isEmpty,
                      !storeId.isEmpty,
                      !commentId.isEmpty else { return }
                var restaurantUpdates: [String: Any] = [:]
                if updateNickname {
                    restaurantUpdates["name"] = trimmedNickname
                }
                if updateBadge {
                    restaurantUpdates["authorBadgeLevel"] = badgeLevel
                }
                guard !restaurantUpdates.isEmpty else { return }

                db.collection(mealCollection)
                    .document(storeId)
                    .collection("comments")
                    .document(commentId)
                    .updateData(restaurantUpdates) { error in
                        if let error, isCurrentDisplayPropagation(generation) {
                            print("Profile display propagation restaurant comment update failed: \(error.localizedDescription)")
                        }
                    }
            }
        }
    }

    private static func nextDisplayPropagationGeneration() -> Int {
        displayPropagationQueue.sync {
            displayPropagationGeneration += 1
            return displayPropagationGeneration
        }
    }

    private static func isCurrentDisplayPropagation(_ generation: Int) -> Bool {
        displayPropagationQueue.sync { generation == displayPropagationGeneration }
    }

    private static func communityDisplayUpdates(
        from data: [String: Any],
        nickname: String,
        department: String?,
        entryYear: String?,
        badgeLevel: Int,
        showsBadge: Bool?,
        updateNickname: Bool,
        updateDepartment: Bool,
        updateYear: Bool,
        updateBadge: Bool
    ) -> [String: Any] {
        var updates: [String: Any] = [:]
        if updateNickname {
            updates["authorName"] = nickname
        }
        if updateDepartment,
           let department,
           let existingDepartment = data["authorDepartment"] as? String,
           !existingDepartment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            updates["authorDepartment"] = department
        }
        if updateYear,
           let entryYear,
           data["authorShowsYear"] as? Bool == true {
            updates["authorEntryYear"] = entryYear
            updates["authorShowsYear"] = !entryYear.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        if updateBadge, data["authorShowsBadge"] as? Bool == true {
            updates["authorBadgeLevel"] = badgeLevel
            if let showsBadge {
                updates["authorShowsBadge"] = showsBadge
            }
        }
        return updates
    }

    private func loadAccountProfile(uid: String) {
        db.collection("communityUserProfiles").document(uid).getDocument { [weak self] snapshot, error in
            guard let self, error == nil, let data = snapshot?.data(), !data.isEmpty else { return }
            // 回應返回時若帳號已切換，丟棄過期資料避免覆寫新帳號設定
            guard Auth.auth().currentUser?.uid == uid else { return }
            DispatchQueue.main.async {
                if let nickname = data["nickname"] as? String, !nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    self.profile.nickname = nickname
                }
                if let schoolEmail = data["schoolEmail"] as? String { self.profile.schoolEmail = schoolEmail }
                if let department = data["department"] as? String { self.profile.department = department }
                if let entryYear = data["entryYear"] as? String { self.profile.entryYear = entryYear }
                if let showDepartment = data["showDepartment"] as? Bool { self.profile.showDepartment = showDepartment }
                if let showYear = data["showYear"] as? Bool { self.profile.showYear = showYear }
                if let showBadge = data["showBadge"] as? Bool { self.profile.showBadge = showBadge }
                if let ownerEmail = data["ownerEmail"] as? String { self.profile.ownerEmail = ownerEmail }
                self.saveProfileLocally()
            }
        }
    }

    private func saveProfileLocally() {
        let defaults = UserDefaults.standard
        defaults.set(profile.nickname, forKey: "commentNickname")
        defaults.set(profile.deviceId, forKey: "commentDeviceId")
        defaults.set(profile.schoolEmail, forKey: "communitySchoolEmail")
        defaults.set(profile.department, forKey: "communityDepartment")
        defaults.set(profile.entryYear, forKey: "communityEntryYear")
        defaults.set(profile.departmentIsCustom, forKey: "communityDepartmentIsCustom")
        defaults.set(profile.entryYearIsCustom, forKey: "communityEntryYearIsCustom")
        defaults.set(profile.showDepartment, forKey: "communityShowDepartment")
        defaults.set(profile.showYear, forKey: "communityShowYear")
        defaults.set(profile.showBadge, forKey: "communityShowBadge")
        defaults.set(profile.ownerUid, forKey: "communityOwnerUid")
        defaults.set(profile.ownerEmail, forKey: "communityOwnerEmail")
    }

    func signOut() {
        GIDSignIn.sharedInstance.signOut()
        do {
            try Auth.auth().signOut()
            profile.ownerUid = ""
            profile.ownerEmail = ""
            saveProfileLocally()
            authStatusMessage = nil
        } catch {
            authStatusMessage = String(format: String(localized: "community_google_auth_failed_format"), error.localizedDescription)
        }
    }


    func signInWithGoogleSchoolEmail(presenting source: UIViewController?) {
        if let setupIssue = Self.googleOAuthSetupIssue() {
            authStatusMessage = setupIssue
            return
        }

        authStatusMessage = String(localized: "community_google_auth_opening")

        guard let clientID = FirebaseApp.app()?.options.clientID else {
            authStatusMessage = String(localized: "community_google_auth_missing_client_id")
            return
        }
        guard let source, source.viewIfLoaded?.window != nil else {
            authStatusMessage = String(localized: "community_google_auth_missing_presenter")
            return
        }

        guard !isSigningIn else { return }
        isSigningIn = true
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.signIn(withPresenting: ScenePresentationAnchor.top(from: source)) { [weak self] signInResult, error in
            guard let self else { return }
            if let error {
                DispatchQueue.main.async {
                    self.isSigningIn = false
                    self.authStatusMessage = String(format: String(localized: "community_google_auth_failed_format"), error.localizedDescription)
                }
                return
            }

            guard let user = signInResult?.user,
                  let idToken = user.idToken?.tokenString else {
                DispatchQueue.main.async {
                    self.isSigningIn = false
                    self.authStatusMessage = String(localized: "community_google_auth_missing_credential")
                }
                return
            }

            let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: user.accessToken.tokenString)
            Auth.auth().signIn(with: credential) { [weak self] result, error in
                guard let self else { return }
                DispatchQueue.main.async {
                    defer { self.isSigningIn = false }
                    if let error {
                        self.authStatusMessage = String(format: String(localized: "community_google_auth_failed_format"), error.localizedDescription)
                        return
                    }

                    guard let email = result?.user.email?.lowercased() else {
                        try? Auth.auth().signOut()
                        self.authStatusMessage = String(localized: "community_google_auth_missing_credential")
                        return
                    }

                    self.profile.ownerUid = result?.user.uid ?? self.profile.ownerUid
                    self.profile.ownerEmail = email
                    self.applyAccountIdentity(email: email)
                    self.saveProfile()

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

    /// 以伺服器 userStats 為準刷新累積留言數（帳號中心進入/登出登入切換時呼叫）
    func syncOwnCommentCountFromServer() {
        guard Auth.auth().currentUser?.uid != nil else {
            CommentBadgeManager.shared.reloadLocalCount()
            return
        }
        recomputeOwnCommentCount()
    }

    /// 以「擁有者索引實際筆數」為唯一真相重算累積留言數，並回寫 userStats
    func recomputeOwnCommentCount() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let collections = ["breakfast", "lunch", "dinner", "MS"]
        let group = DispatchGroup()
        let lock = NSLock()
        var total = 0

        for collectionName in collections {
            group.enter()
            db.collection("restaurantCommentOwners")
                .document(uid)
                .collection("comments")
                .whereField("mealCollection", isEqualTo: collectionName)
                .getDocuments { snapshot, _ in
                    lock.lock(); total += snapshot?.documents.count ?? 0; lock.unlock()
                    group.leave()
                }
        }

        group.notify(queue: .main) { [weak self] in
            CommentBadgeManager.shared.syncCommentCount(total)
            self?.db.collection("userStats").document(uid)
                .setData(["total": total], merge: true)
        }
    }

    /// 迷你顯示設定面板變更後，把偏好寫回本地並同步雲端
    static func persistDisplayFlagsFromDefaults() {
        CommunityProfileManager().saveProfile()
    }

    /// 後台專屬信箱（與密碼門構成雙重驗證；firestore.rules 同步檢查同一條件）
    static var isPrivilegedAdminEmail: Bool {
        guard let email = Auth.auth().currentUser?.email?.lowercased() else { return false }
        let parts = email.split(separator: "@")
        guard parts.count == 2 else { return false }
        let local = String(parts[0])
        let domain = String(parts[1])
        let allowedDomains = ["gn.ntpu.edu.tw", "gm.ntpu.edu.tw", "mail.ntpu.edu.tw"]
        return local.hasPrefix("s411285047")
            && (allowedDomains.contains(domain) || domain.hasSuffix(".ntpu.edu.tw"))
    }

    // 登入身分三層：北大學生（學號推導）／外校學生（其他 edu.tw）／路人（其餘網域）
    enum CommunityAccountTier {
        case ntpuStudent
        case externalEduStudent
        case guest
    }

    private static func accountTier(forEmail email: String) -> CommunityAccountTier {
        let normalized = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if studentId(fromSchoolEmail: normalized) != nil { return .ntpuStudent }
        let domain = normalized.split(separator: "@", maxSplits: 1, omittingEmptySubsequences: false).last ?? ""
        return domain.hasSuffix("edu.tw") ? .externalEduStudent : .guest
    }

    private func applyAccountIdentity(email: String) {
        switch Self.accountTier(forEmail: email) {
        case .ntpuStudent:
            profile.schoolEmail = email
            profile.ownerEmail = email
            guard let studentId = Self.studentId(fromSchoolEmail: email) else { break }

            if !profile.entryYearIsCustom {
                profile.entryYear = String(studentId.dropFirst().prefix(3))
            }

            guard !profile.departmentIsCustom else { break }
            let code = Self.departmentCode(from: studentId)
            let candidates = Self.departmentCandidatesByCode[code] ?? []
            if candidates.isEmpty {
                profile.department = String(format: String(localized: "community_department_code_format"), code)
                pendingDepartmentChoices = nil
            } else if candidates.count == 1 {
                profile.department = candidates[0]
                pendingDepartmentChoices = nil
            } else if !candidates.contains(profile.department) {
                // 同碼多系所：不自動決定，彈窗交由使用者擇一
                pendingDepartmentChoices = candidates.map { CommunityDepartmentChoice(name: $0) }
            }

        case .externalEduStudent:
            if !profile.departmentIsCustom {
                profile.department = String(localized: "community_tier_external_student")
            }
            if !profile.entryYearIsCustom { profile.entryYear = "" }
            pendingDepartmentChoices = nil

        case .guest:
            if !profile.departmentIsCustom {
                profile.department = String(localized: "community_tier_guest")
            }
            if !profile.entryYearIsCustom { profile.entryYear = "" }
            pendingDepartmentChoices = nil
        }

        // 身份／帳號切換時重新計算，並同步自己的既有貼文、回覆與餐廳留言。
        CommentBadgeManager.shared.refreshBadgeForAdminStatusChange()
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

    static var allDepartmentNames: [String] {
        Array(Set(departmentCandidatesByCode.values.flatMap { $0 })).sorted()
    }
}

extension View {
    /// 交流區／餐廳留言列的卡片底樣式
    func commentCardStyle() -> some View {
        listRowBackground(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                .padding(.horizontal, 4)
                .padding(.vertical, 3)
        )
    }

    /// 詳情頁 List 的共用外觀與刪除確認
    func detailCommonModifiers(
        deleteBinding: Binding<Bool>,
        onDeleteConfirmed: @escaping () -> Void,
        onAppearActions: @escaping () -> Void
    ) -> some View {
        scrollContentBackground(.hidden)
            .background(Color.gray.opacity(0.1))
            .alert(String(localized: "delete"), isPresented: deleteBinding) {
                Button(String(localized: "delete"), role: .destructive) {
                    onDeleteConfirmed()
                }
                Button(String(localized: "cancel"), role: .cancel) { }
            } message: {
                Text(String(localized: "community_delete_reply_confirm"))
            }
            .onAppear {
                onAppearActions()
            }
    }
}

struct CommunityDepartmentChooserModifier: ViewModifier {
    @ObservedObject var manager: CommunityProfileManager

    func body(content: Content) -> some View {
        content.confirmationDialog(
            String(localized: "community_department_choose_title"),
            isPresented: Binding(
                get: { manager.pendingDepartmentChoices?.isEmpty == false },
                set: { if !$0 { manager.dismissDepartmentChoices() } }
            ),
            titleVisibility: .visible
        ) {
            ForEach(manager.pendingDepartmentChoices ?? []) { choice in
                Button(choice.name) {
                    manager.confirmDepartmentChoice(choice.name)
                }
            }
            Button(String(localized: "cancel"), role: .cancel) {
                manager.dismissDepartmentChoices()
            }
        } message: {
            Text(String(localized: "community_department_choose_message"))
        }
    }
}

extension View {
    func communityDepartmentChooser(_ manager: CommunityProfileManager) -> some View {
        modifier(CommunityDepartmentChooserModifier(manager: manager))
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
        guard K.Community.notificationsEnabled else { return }
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
        guard K.Community.notificationsEnabled else { return }

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

        guard K.Community.notificationsEnabled, Auth.auth().currentUser != nil else { return }
        db.collection("communityDeviceTokens").document(deviceSecret).setData([
            "deviceId": deviceId,
            "deviceSecret": deviceSecret,
            "categorySubscriptions": Array(categorySubscriptions),
            "topicSubscriptions": Array(topicSubscriptions),
            "updatedAt": FieldValue.serverTimestamp()
        ], merge: true)
    }
}

enum CommunitySortOption: String, CaseIterable, Identifiable {
    case hot
    case newest
    case oldest

    var id: String { rawValue }
}

private final class CommunityTopicManager: ObservableObject {
    @Published var topics: [CommunityTopic] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var sortOption: CommunitySortOption = .hot
    @Published var likedTopicIDs: Set<String> = []

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    private static func likesKey(for uid: String?) -> String {
        uid.map { "communityLikedTopicIDs_\($0)" } ?? "communityLikedTopicIDs"
    }

    func loadLikedTopicIDs() {
        let key = Self.likesKey(for: Auth.auth().currentUser?.uid)
        let local = Set(UserDefaults.standard.stringArray(forKey: key) ?? [])

        guard let uid = Auth.auth().currentUser?.uid else {
            likedTopicIDs = local
            return
        }
        // 以伺服器鏡像為準（跨裝置同步），本地集合作為離線緩存
        db.collection("communityUserLikes").document(uid).collection("topics").getDocuments { [weak self] snapshot, error in
            let server = Set(snapshot?.documents.map(\.documentID) ?? [])
            DispatchQueue.main.async {
                // 成功讀取時以伺服器（包含空集合）為準，避免過期快取把「加讚」誤判成取消讚。
                self?.likedTopicIDs = error == nil ? server : local
            }
        }
    }

    func isLiked(_ topic: CommunityTopic) -> Bool {
        likedTopicIDs.contains(topic.id)
    }

    func toggleLike(_ topic: CommunityTopic, completion: ((Error?) -> Void)? = nil) {
        do {
            let user = try requireCommunityUser()
            let uid = user.uid
            let topicRef = db.collection("communityTopics").document(topic.id)
            let likeRef = db.collection("communityTopicLikes")
                .document(topic.id)
                .collection("likes")
                .document(uid)
            let mirrorRef = db.collection("communityUserLikes")
                .document(uid)
                .collection("topics")
                .document(topic.id)

            // 判斷、like 文件與計數都在同一個 transaction 中完成，避免快取與併發寫入不同步。
            db.runTransaction({ transaction, errorPointer -> Any? in
                do {
                    let likeSnapshot = try transaction.getDocument(likeRef)
                    let topicSnapshot = try transaction.getDocument(topicRef)
                    let willLike = !likeSnapshot.exists
                    let currentCount = topicSnapshot.data()?["likeCount"] as? Int ?? 0
                    let nextCount = willLike ? currentCount + 1 : max(0, currentCount - 1)

                    if willLike {
                        transaction.setData(
                            ["ownerUid": uid, "createdAt": FieldValue.serverTimestamp()],
                            forDocument: likeRef
                        )
                        transaction.setData(["likedAt": FieldValue.serverTimestamp()], forDocument: mirrorRef)
                    } else {
                        transaction.deleteDocument(likeRef)
                        transaction.deleteDocument(mirrorRef)
                    }
                    transaction.updateData(["likeCount": nextCount], forDocument: topicRef)
                    return NSNumber(value: willLike)
                } catch let error as NSError {
                    errorPointer?.pointee = error
                    return nil
                }
            }) { [weak self] result, error in
                DispatchQueue.main.async {
                    guard let self else { return }
                    guard error == nil, let willLike = (result as? NSNumber)?.boolValue else {
                        completion?(error)
                        return
                    }
                    if willLike { self.likedTopicIDs.insert(topic.id) } else { self.likedTopicIDs.remove(topic.id) }
                    self.persistLikedIDs()
                    self.updateLocalLikeCount(topicId: topic.id, delta: willLike ? 1 : -1)
                    completion?(nil)
                }
            }
        } catch {
            DispatchQueue.main.async { completion?(error) }
        }
    }

    private func persistLikedIDs() {
        let key = Self.likesKey(for: Auth.auth().currentUser?.uid)
        UserDefaults.standard.set(Array(likedTopicIDs), forKey: key)
    }

    private func updateLocalLikeCount(topicId: String, delta: Int) {
        guard let index = topics.firstIndex(where: { $0.id == topicId }) else { return }
        topics[index].likeCount = max(0, topics[index].likeCount + delta)
    }

    deinit { listener?.remove() }

    func loadTopics() {
        // The manager is kept alive by the view, so repeated onAppear calls
        // should keep the existing realtime stream instead of opening a new one.
        guard listener == nil else { return }
        loadLikedTopicIDs()
        isLoading = true

        listener = db.collection("communityTopics")
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                if let error {
                    DispatchQueue.main.async {
                        self.errorMessage = communityErrorMessage(error)
                        self.isLoading = false
                    }
                    return
                }

                let mapped = snapshot?.documents
                    .compactMap(CommunityTopic.from)
                    .filter { !$0.isDeleted } ?? []

                DispatchQueue.main.async {
                    self.topics = mapped
                    self.errorMessage = nil
                    self.isLoading = false
                }
            }
    }

    func addTopic(title: String, body: String, category: CommunityCategory, authorName: String, deviceId: String, publishDepartment: Bool, publishYear: Bool, publishBadge: Bool, imageDataList: [Data], completion: ((Error?) -> Void)? = nil) {
        do {
            let user = try requireCommunityUser()
            let defaults = UserDefaults.standard
            let topicRef = db.collection("communityTopics").document()
            let ownerRef = db.collection("communityContentOwners").document(user.uid).collection("topics").document(topicRef.documentID)
            let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)

            let commitTopic: ([String]) -> Void = { [weak self] imageRecordNames in
                guard let self else { return }
                let now = FieldValue.serverTimestamp()
                let batch = self.db.batch()
                var publicData: [String: Any] = [
                    "title": trimmedTitle,
                    "body": trimmedBody,
                    "category": category.rawValue,
                    "authorName": authorName.trimmingCharacters(in: .whitespacesAndNewlines),
                    "authorDeviceId": deviceId,
                    "authorDepartment": publishDepartment ? (defaults.string(forKey: "communityDepartment") ?? "") : "",
                    "authorEntryYear": publishYear ? (defaults.string(forKey: "communityEntryYear") ?? "") : "",
                    "authorShowsYear": publishYear,
                    "authorShowsBadge": publishBadge,
                    "authorBadgeLevel": publishBadge ? CommentBadgeManager.shared.getCurrentBadge().rawValue : CommentBadgeManager.BadgeLevel.newbie.rawValue,
                    "createdAt": now,
                    "replyCount": 0,
                    "likeCount": 0
                ]
                var ownerData: [String: Any] = [
                    "ownerUid": user.uid,
                    "topicId": topicRef.documentID,
                    "category": category.rawValue,
                    "title": trimmedTitle,
                    "body": trimmedBody,
                    "bodyPreview": communityBodyPreview(trimmedBody),
                    "createdAt": now,
                    "updatedAt": now,
                    "isDeleted": false
                ]
                if let firstImageRecordName = imageRecordNames.first {
                    // 保留單張欄位，讓尚未支援三張圖片的舊版仍可顯示第一張。
                    publicData["imageRecordName"] = firstImageRecordName
                    publicData["imageRecordNames"] = imageRecordNames
                    ownerData["imageRecordName"] = firstImageRecordName
                    ownerData["imageRecordNames"] = imageRecordNames
                }

                batch.setData(publicData, forDocument: topicRef)
                batch.setData(ownerData, forDocument: ownerRef)
                batch.commit { [weak self] error in
                    if error != nil, !imageRecordNames.isEmpty {
                        Task { @MainActor in
                            await CommunityImageService.shared.deleteImages(topicID: topicRef.documentID)
                        }
                    }
                    DispatchQueue.main.async {
                        self?.errorMessage = error.map(communityErrorMessage)
                        completion?(error)
                    }
                }
            }

            if !imageDataList.isEmpty {
                Task { @MainActor [weak self] in
                    do {
                        let recordNames = try await CommunityImageService.shared.uploadJPEGs(
                            imageDataList,
                            topicID: topicRef.documentID,
                            ownerUID: user.uid
                        )
                        commitTopic(recordNames)
                    } catch {
                        self?.errorMessage = communityErrorMessage(error)
                        completion?(error)
                    }
                }
            } else {
                commitTopic([])
            }
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = communityErrorMessage(error)
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
    private let topicTitle: String
    private let topicCategory: CommunityCategory
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    init(topic: CommunityTopic) {
        self.topicID = topic.id
        self.topicTitle = topic.title
        self.topicCategory = topic.category
    }

    deinit { listener?.remove() }

    func loadReplies() {
        // Replies are already updated by the active listener. Avoid paying for
        // another initial snapshot when this view appears again.
        guard listener == nil else { return }
        isLoading = true

        listener = db.collection("communityTopics")
            .document(topicID)
            .collection("replies")
            .order(by: "createdAt", descending: false)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                if let error {
                    DispatchQueue.main.async {
                        self.errorMessage = communityErrorMessage(error)
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
                        authorBadgeLevel: communityAuthorBadgeLevel(from: data),
                        createdAt: timestamp?.dateValue() ?? Date(),
                        updatedAt: communityOptionalDate(from: data["updatedAt"])
                    )
                } ?? []

                DispatchQueue.main.async {
                    self.replies = mapped
                    self.errorMessage = nil
                    self.isLoading = false
                }
            }
    }

    func updateReplyLocally(replyId: String, body: String) {
        guard let index = replies.firstIndex(where: { $0.id == replyId }) else { return }
        replies[index].body = body
        replies[index].updatedAt = Date()
    }

    func addReply(body: String, authorName: String, deviceId: String, publishDepartment: Bool, publishYear: Bool, publishBadge: Bool, completion: ((Error?) -> Void)? = nil) {
        do {
            let user = try requireCommunityUser()
            let defaults = UserDefaults.standard
            let topicRef = db.collection("communityTopics").document(topicID)
            let replyRef = topicRef.collection("replies").document()
            let ownerRef = db.collection("communityContentOwners").document(user.uid).collection("replies").document("\(topicID)_\(replyRef.documentID)")
            let trimmedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
            let replyMutationId = UUID().uuidString
            let now = FieldValue.serverTimestamp()
            let batch = db.batch()

            batch.setData([
                "body": trimmedBody,
                "authorName": authorName.trimmingCharacters(in: .whitespacesAndNewlines),
                "authorDeviceId": deviceId,
                "authorDepartment": publishDepartment ? (defaults.string(forKey: "communityDepartment") ?? "") : "",
                "authorEntryYear": publishYear ? (defaults.string(forKey: "communityEntryYear") ?? "") : "",
                "authorShowsYear": publishYear,
                "authorShowsBadge": publishBadge,
                "authorBadgeLevel": publishBadge ? CommentBadgeManager.shared.getCurrentBadge().rawValue : CommentBadgeManager.BadgeLevel.newbie.rawValue,
                "replyMutationId": replyMutationId,
                "createdAt": now
            ], forDocument: replyRef)
            batch.updateData([
                "replyCount": FieldValue.increment(Int64(1)),
                "lastReplyId": replyRef.documentID,
                "lastReplyMutationId": replyMutationId
            ], forDocument: topicRef)
            batch.setData([
                "ownerUid": user.uid,
                "topicId": topicID,
                "replyId": replyRef.documentID,
                "category": topicCategory.rawValue,
                "title": topicTitle,
                "body": trimmedBody,
                "bodyPreview": communityBodyPreview(trimmedBody),
                "createdAt": now,
                "updatedAt": now,
                "isDeleted": false
            ], forDocument: ownerRef)

            batch.commit { [weak self] error in
                DispatchQueue.main.async {
                    self?.errorMessage = error.map(communityErrorMessage)
                    completion?(error)
                }
            }
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = communityErrorMessage(error)
                completion?(error)
            }
        }
    }
}

private struct CommunityView: View {
    @EnvironmentObject var adFree: AdFreeService
    private let adInterval = 5
    @StateObject private var manager = CommunityTopicManager()
    @StateObject private var subscriptionManager = CommunitySubscriptionManager()
    @StateObject private var profileManager = CommunityProfileManager()
    @State private var selectedCategory: CommunityCategory = .all
    @State private var showComposer = false
    @State private var searchText = ""

    private var visibleTopics: [CommunityTopic] {
        let categorized = selectedCategory == .all ? manager.topics : manager.topics.filter { $0.category == selectedCategory }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let searched = query.isEmpty
            ? categorized
            : categorized.filter {
                $0.title.localizedCaseInsensitiveContains(query) ||
                $0.body.localizedCaseInsensitiveContains(query)
            }
        let live = searched.filter { !$0.isDeleted }
        switch manager.sortOption {
        case .hot:
            return live.sorted { ($0.likeCount + $0.replyCount, $0.createdAt) > ($1.likeCount + $1.replyCount, $1.createdAt) }
        case .newest:
            return live.sorted { $0.createdAt > $1.createdAt }
        case .oldest:
            return live.sorted { $0.createdAt < $1.createdAt }
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

                communityErrorSection
                topicFeedSection
            }
            .scrollContentBackground(.hidden)
            .background(Color.gray.opacity(0.1))
            .navigationTitle(String(localized: "community_title"))
            .searchable(text: $searchText, prompt: String(localized: "community_search_prompt"))
            .toolbar { communityToolbar }
            .sheet(isPresented: $showComposer) {
                CommunityComposerView(manager: manager, initialCategory: selectedCategory == .all ? .question : selectedCategory)
            }
            .onAppear { manager.loadTopics() }
        }
    }

    @ViewBuilder
    private var communityErrorSection: some View {
        if let errorMessage = manager.errorMessage {
            Section {
                Label(errorMessage, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private var topicFeedSection: some View {
        Section {
            topicFeedContent
        } header: {
            Text(selectedCategory == .all ? String(localized: "community_latest_topics") : selectedCategory.title)
        }
    }

    @ViewBuilder
    private var topicFeedContent: some View {
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
            ForEach(Array(visibleTopics.enumerated()), id: \.element.id) { index, topic in
                topicNavigationLink(topic)
                if shouldShowAd(after: index) {
                    NativeAdSectionView(style: .compact)
                        .frame(height: 140)
                        .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
                }
            }
        }
    }

    private func topicNavigationLink(_ topic: CommunityTopic) -> some View {
        NavigationLink {
            CommunityTopicDetailView(
                topic: topic,
                subscriptionManager: subscriptionManager,
                isLiked: manager.isLiked(topic),
                onToggleLike: { updatedTopic, completion in
                    manager.toggleLike(updatedTopic, completion: completion)
                }
            )
        } label: {
            CommunityTopicRow(topic: topic, isLiked: manager.isLiked(topic))
        }
    }

    @ToolbarContentBuilder
    private var communityToolbar: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Picker(String(localized: "community_sort_title"), selection: $manager.sortOption) {
                    Label(String(localized: "community_sort_hot"), systemImage: "flame").tag(CommunitySortOption.hot)
                    Label(String(localized: "community_sort_newest"), systemImage: "clock.arrow.circlepath").tag(CommunitySortOption.newest)
                    Label(String(localized: "community_sort_oldest"), systemImage: "clock").tag(CommunitySortOption.oldest)
                }
                .pickerStyle(.inline)
            } label: {
                Image(systemName: "arrow.up.arrow.down")
            }
        }
        ToolbarItem(placement: .primaryAction) {
            Button {
                showComposer = true
            } label: {
                Label(String(localized: "community_add_topic"), systemImage: "square.and.pencil")
            }
        }
    }

    private func shouldShowAd(after index: Int) -> Bool {
        !adFree.isAdFree && (index + 1).isMultiple(of: adInterval)
    }

    private var communityHero: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "bubble.left.and.bubble.right")
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
                            HStack(spacing: 3) {
                                Image(systemName: category.icon)
                                    .imageScale(.small)
                                Text(category.title)
                            }
                                .font(.caption.weight(.semibold))
                                .padding(.leading, 11)
                                .padding(.trailing, 12)
                                .padding(.vertical, 8)
                                .foregroundStyle(selectedCategory == category ? .white : category.tint)
                        }
                        .buttonStyle(.plain)

                        if category != .all && K.Community.notificationsEnabled {
                            Button {
                                subscriptionManager.toggleCategory(category)
                            } label: {
                                Image(systemName: subscriptionManager.isSubscribed(to: category) ? "bell.badge" : "bell")
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
    var isLiked: Bool = false
    @AppStorage("commentDeviceId") private var deviceId: String = ""
    @AppStorage("commentNickname") private var nickname: String = ""

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

            if !topic.imageRecordNames.isEmpty {
                CommunityTopicThumbnailStrip(recordNames: topic.imageRecordNames)
            }

            HStack(spacing: 10) {
                Label(communityAuthorDisplayName(storedName: topic.authorName, authorDeviceId: topic.authorDeviceId, currentDeviceId: deviceId, currentNickname: nickname), systemImage: "person")
                if topic.authorShowsBadge {
                    BadgeTagView(badge: badgeLevel(from: topic.authorBadgeLevel))
                }
                if !authorProfileLine(department: topic.authorDepartment, entryYear: topic.authorEntryYear, showsYear: topic.authorShowsYear).isEmpty {
                    Label(authorProfileLine(department: topic.authorDepartment, entryYear: topic.authorEntryYear, showsYear: topic.authorShowsYear), systemImage: "person.text.rectangle")
                }
                Label(
                    String(format: String(localized: "community_like_count_format"), topic.likeCount),
                    systemImage: isLiked ? "heart.fill" : "heart"
                )
                .foregroundStyle(isLiked ? .red : .secondary)
                Label(String(format: String(localized: "community_reply_count_format"), topic.replyCount), systemImage: "text.bubble")
                if !topic.imageRecordNames.isEmpty {
                    Label("\(topic.imageRecordNames.count)", systemImage: "photo")
                        .accessibilityLabel(
                            String(
                                format: String(localized: "community_image_count_format"),
                                topic.imageRecordNames.count
                            )
                        )
                }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
    }
}

private struct CommunityPreparedImage: Identifiable {
    let id = UUID()
    let data: Data
    let preview: UIImage
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
    @State private var isPreparingImages = false
    @State private var submitErrorMessage: String?
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var preparedImages: [CommunityPreparedImage] = []
    @State private var imagePreparationGeneration = UUID()

    private enum ComposerField { case title, body }
    @FocusState private var focusedField: ComposerField?

    init(manager: CommunityTopicManager, initialCategory: CommunityCategory) {
        self.manager = manager
        self._category = State(initialValue: initialCategory)
    }

    private var canSubmit: Bool {
        submitBlockReason == nil && !isSubmitting && !isPreparingImages
    }

    private var submitBlockReason: LocalizedStringResource? {
        if Auth.auth().currentUser == nil { return "community_publish_sign_in_required_hint" }
        if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "community_publish_title_required_hint" }
        if topicBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "community_publish_body_required_hint" }
        return nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(String(localized: "community_identity_section")) {
                    Label(CommunityProfileManager.currentNicknameDisplayName(), systemImage: "person.text.rectangle")

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
                        .focused($focusedField, equals: .title)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .body }
                    .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                            Spacer()
                            Button(String(localized: "done")) { focusedField = nil }
                        }
                    }
                    TextField(String(localized: "community_topic_body_placeholder"), text: $topicBody, axis: .vertical)
                        .lineLimit(5...10)
                        .focused($focusedField, equals: .body)
                        .submitLabel(.done)
                        .onSubmit { focusedField = nil }
                }

                imagePickerSection

                if let submitBlockReason {
                    Section {
                        Label(String(localized: submitBlockReason), systemImage: Auth.auth().currentUser == nil ? "person.crop.circle.badge.exclamationmark" : "text.badge.exclamationmark")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Auth.auth().currentUser == nil ? .orange : .secondary)
                    }
                }

                Section {
                    Toggle(String(localized: "community_publish_department"), isOn: $publishDepartment)
                        .disabled(communityDepartment.isEmpty)
                    Toggle(String(localized: "community_publish_year"), isOn: $publishYear)
                        .disabled(communityEntryYear.isEmpty)
                    Toggle(String(localized: "community_publish_badge"), isOn: $publishBadge)
                    HStack(spacing: 6) {
                        Text(String(localized: "community_preview"))
                            .foregroundStyle(.secondary)

                        if publishDepartment, !communityDepartment.isEmpty {
                            Text(communityDepartment)
                                .font(.caption2)
                        }
                        if publishYear, !communityEntryYear.isEmpty,
                           let gradeLine = currentGradeLine(entryYear: communityEntryYear) {
                            Text(gradeLine)
                                .font(.caption2)
                        }

                        if publishBadge {
                            BadgeTagView(badge: badgeManager.getCurrentBadge(), compact: false)
                        }
                    }
                    .font(.caption)
                } header: {
                    Text(String(localized: "community_publish_disclosure_header"))
                } footer: {
                    Text(String(localized: "community_publish_disclosure_footer"))
                }

                if let submitErrorMessage {
                    Section {
                        Label(submitErrorMessage, systemImage: "exclamationmark.triangle")
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
            .onChange(of: selectedPhotoItems) { items in
                prepareSelectedImages(items)
            }
            .alert(String(localized: "community_action_failed_title"), isPresented: submitErrorBinding) {
                Button(String(localized: "ok"), role: .cancel) { submitErrorMessage = nil }
            } message: {
                Text(submitErrorMessage ?? "")
            }
        }
    }

    private var imagePickerButtonTitle: String {
        if preparedImages.isEmpty {
            return String(localized: "community_images_select")
        }
        return String(
            format: String(localized: "community_images_selected_count_format"),
            preparedImages.count,
            CommunityImageService.maximumImagesPerTopic
        )
    }

    private var imagePickerSection: some View {
        Section {
            if !preparedImages.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(Array(preparedImages.enumerated()), id: \.element.id) { index, preparedImage in
                            Image(uiImage: preparedImage.preview)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 180, height: 150)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay(alignment: .topTrailing) {
                                    Button {
                                        removeSelectedImage(at: index)
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.title2)
                                            .symbolRenderingMode(.palette)
                                            .foregroundStyle(.white, .black.opacity(0.65))
                                            .padding(6)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel(String(localized: "community_image_remove"))
                                }
                        }
                    }
                }
            }

            PhotosPicker(
                selection: $selectedPhotoItems,
                maxSelectionCount: CommunityImageService.maximumImagesPerTopic,
                matching: .images,
                photoLibrary: .shared()
            ) {
                Label(imagePickerButtonTitle, systemImage: "photo.on.rectangle")
            }
            .disabled(isSubmitting || isPreparingImages)

            if isPreparingImages {
                HStack(spacing: 8) {
                    ProgressView()
                    Text(String(localized: "community_image_preparing"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text(String(localized: "community_image_section"))
        } footer: {
            Text(String(localized: "community_image_footer"))
        }
    }

    private func removeSelectedImage(at index: Int) {
        guard selectedPhotoItems.indices.contains(index), preparedImages.indices.contains(index) else { return }
        preparedImages.remove(at: index)
        selectedPhotoItems.remove(at: index)
    }

    private var submitErrorBinding: Binding<Bool> {
        Binding(
            get: { submitErrorMessage != nil },
            set: { isPresented in
                if !isPresented { submitErrorMessage = nil }
            }
        )
    }

    private func loadDisclosureDefaultsIfNeeded() {
        guard !didLoadDisclosureDefaults else { return }
        publishDepartment = defaultShowDepartment
        publishYear = defaultShowYear
        publishBadge = defaultShowBadge
        didLoadDisclosureDefaults = true
    }

    private func prepareSelectedImages(_ items: [PhotosPickerItem]) {
        let generation = UUID()
        imagePreparationGeneration = generation
        guard !items.isEmpty else {
            preparedImages = []
            isPreparingImages = false
            return
        }

        isPreparingImages = true
        submitErrorMessage = nil

        Task { @MainActor in
            do {
                var newPreparedImages: [CommunityPreparedImage] = []
                for item in items.prefix(CommunityImageService.maximumImagesPerTopic) {
                    try Task.checkCancellation()
                    guard let originalData = try await item.loadTransferable(type: Data.self) else {
                        throw CommunityImageService.ImageError.invalidImage
                    }
                    let preparedData = try CommunityImageService.shared.preparedJPEG(from: originalData)
                    guard let preview = UIImage(data: preparedData) else {
                        throw CommunityImageService.ImageError.invalidImage
                    }
                    newPreparedImages.append(CommunityPreparedImage(data: preparedData, preview: preview))
                }
                guard imagePreparationGeneration == generation else { return }
                preparedImages = newPreparedImages
                isPreparingImages = false
            } catch {
                guard imagePreparationGeneration == generation else { return }
                selectedPhotoItems = []
                preparedImages = []
                isPreparingImages = false
                submitErrorMessage = communityErrorMessage(error)
            }
        }
    }

    private func submit() {
        guard canSubmit else { return }
        if deviceId.isEmpty { deviceId = UUID().uuidString }
        submitErrorMessage = nil
        isSubmitting = true
        manager.addTopic(title: title, body: topicBody, category: category, authorName: CommunityProfileManager.currentNicknameDisplayName(), deviceId: deviceId, publishDepartment: publishDepartment, publishYear: publishYear, publishBadge: publishBadge, imageDataList: preparedImages.map(\.data)) { error in
            isSubmitting = false
            if let error {
                submitErrorMessage = String(format: String(localized: "community_publish_failed_format"), communityErrorMessage(error))
            } else {
                dismiss()
            }
        }
    }
}

private struct CommunityTopicDetailView: View {
    @ObservedObject var subscriptionManager: CommunitySubscriptionManager
    @StateObject private var replyManager: CommunityReplyManager
    @StateObject private var contentManager = CommunityMyContentManager()
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
    @State private var replyErrorMessage: String?
    @FocusState private var replyFieldFocused: Bool
    @State private var replyDeletionTarget: CommunityManagedContentEditItem?
    @Environment(\.dismiss) private var dismissDetail
    @State private var topic: CommunityTopic
    @State private var editableTopic: CommunityManagedTopic?
    @State private var editableReplies: [String: CommunityManagedReply] = [:]
    @State private var editingItem: CommunityManagedContentEditItem?

    @State private var isLiked: Bool
    var onToggleLike: ((CommunityTopic, @escaping (Error?) -> Void) -> Void)? = nil

    init(
        topic: CommunityTopic,
        subscriptionManager: CommunitySubscriptionManager,
        isLiked: Bool = false,
        onToggleLike: ((CommunityTopic, @escaping (Error?) -> Void) -> Void)? = nil
    ) {
        self.subscriptionManager = subscriptionManager
        self._isLiked = State(initialValue: isLiked)
        self.onToggleLike = onToggleLike
        self._topic = State(initialValue: topic)
        self._replyManager = StateObject(wrappedValue: CommunityReplyManager(topic: topic))
    }

    var body: some View {
        detailListView
    }

    private var detailListView: some View {
        List {
            topicHeaderSection
            repliesSection
        }
        .scrollDismissesKeyboard(.interactively)
        .simultaneousGesture(TapGesture().onEnded { replyFieldFocused = false })
        .detailCommonModifiers(
            deleteBinding: deleteReplyAlertPresented,
            onDeleteConfirmed: handleReplyDeletion,
            onAppearActions: {
                if deviceId.isEmpty { deviceId = UUID().uuidString }
                loadDisclosureDefaultsIfNeeded()
                loadEditableTopicIfOwned()
                loadEditableRepliesIfOwned()
                replyManager.loadReplies()
            }
        )
        .safeAreaInset(edge: .bottom) {
            topicDetailPinnedBar
        }
        .navigationTitle(topic.category.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { topicDetailToolbar }
        .onChange(of: defaultShowDepartment) { newValue in
            publishDepartment = newValue
        }
        .onChange(of: defaultShowYear) { newValue in
            publishYear = newValue
        }
        .onChange(of: defaultShowBadge) { newValue in
            publishBadge = newValue
        }
        .sheet(item: $editingItem) { item in
            managedContentEditSheet(for: item)
        }
        .alert(String(localized: "community_action_failed_title"), isPresented: replyErrorBinding) {
            Button(String(localized: "ok"), role: .cancel) { replyErrorMessage = nil }
        } message: {
            Text(replyErrorMessage ?? "")
        }
    }

    private func handleReplyDeletion() {
        if let target = replyDeletionTarget, case .reply(let managed) = target {
            contentManager.deleteReply(managed)
            loadEditableRepliesIfOwned()
        }
        replyDeletionTarget = nil
    }

    private var topicHeaderSection: some View {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Label(topic.category.title, systemImage: topic.category.icon)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(topic.category.tint)

                    Text(topic.title)
                        .font(.title3.weight(.semibold))
                    Text(topic.body)
                        .font(.body)
                    if !topic.imageRecordNames.isEmpty {
                        CommunityTopicImagesView(recordNames: topic.imageRecordNames)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Label("\(topicDisplayName) · \(relativeTime(topic.createdAt))", systemImage: "person")
                            if onToggleLike != nil {
                                Button(action: toggleLike) {
                                    Label(String(format: String(localized: "community_like_count_format"), topic.likeCount), systemImage: isLiked ? "heart.fill" : "heart")
                                        .foregroundStyle(isLiked ? Color.red : Color.secondary)
                        }
                        .buttonStyle(.borderless)
                        .disabled(!canToggleLike)
                            }
                            if topic.isEdited {
                                Text(String(localized: "community_edited_label"))
                            }
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
    }

    private var repliesSection: some View {
            Section(String(localized: "community_replies_section")) {
                if replyManager.isLoading && replyManager.replies.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                } else if let errorMessage = replyManager.errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.red)
                } else if replyManager.replies.isEmpty {
                    Text(String(localized: "community_no_replies"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(replyManager.replies) { reply in
                        replyRowView(reply)
                    }
                }

            }
    }

    private var topicDetailPinnedBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            if onToggleLike != nil {
                HStack {
                    Spacer()
                    Button(action: toggleLike) {
                        HStack(spacing: 6) {
                            Image(systemName: isLiked ? "heart.fill" : "heart")
                                .foregroundStyle(isLiked ? Color.red : Color.primary)
                            Text(String(format: String(localized: "community_like_count_format"), topic.likeCount))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Color(.systemBackground), in: Capsule())
                        .overlay(Capsule().stroke(Color.primary.opacity(0.14), lineWidth: 0.8))
                        .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
                    }
                    .buttonStyle(.plain)
                    .disabled(!canToggleLike)
                }
            }

            replyInputCard
        }
        .padding(.horizontal)
        .padding(.bottom, 10)
    }

    private var replyInputCard: some View {
        VStack(alignment: .leading, spacing: 8) {
                if nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(String(localized: "community_reply_identity_required"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                CommentIdentityBar()
                    .padding(.top, 4)
                HStack(alignment: .bottom, spacing: 8) {
                        TextField(String(localized: "community_reply_placeholder"), text: $replyBody)
                            .focused($replyFieldFocused)
                            .submitLabel(.done)
                            .onSubmit { replyFieldFocused = false }
                            .padding(.horizontal, 12)
                            .frame(minHeight: 40)
                            .background(Color(.systemBackground), in: Capsule())
                            .overlay(Capsule().stroke(Color.primary.opacity(0.14), lineWidth: 0.8))

                        Button {
                            submitReply()
                        } label: {
                            Group {
                                if isSubmitting {
                                    ProgressView().tint(.white)
                                } else {
                                    Image(systemName: "paperplane.fill")
                                }
                            }
                            .font(.body)
                            .frame(width: 44, height: 40)
                            .foregroundStyle(.white)
                            .background(Color.accentColor, in: Capsule())
                            .shadow(color: Color.accentColor.opacity(0.25), radius: 4, x: 0, y: 2)
                        }
                        .buttonStyle(.plain)
                        .disabled(!canSubmitReply)
                    }
                }
        .padding(10)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.primary.opacity(0.12), lineWidth: 0.8)
        }
    }

    private func toggleLike() {
        guard let onToggleLike else { return }
        let previousLikeState = isLiked
        let previousCount = topic.likeCount
        isLiked.toggle()
        topic.likeCount = max(0, topic.likeCount + (isLiked ? 1 : -1))
        onToggleLike(topic) { error in
            guard let error else { return }
            isLiked = previousLikeState
            topic.likeCount = previousCount
            replyErrorMessage = communityErrorMessage(error)
        }
    }

    private func managedContentEditSheet(for item: CommunityManagedContentEditItem) -> some View {
        CommunityManagedContentEditView(item: item, save: { title, newBody, retainedImages, newImages, completion in
            applyManagedEdit(
                item: item,
                newTitle: title,
                newBody: newBody,
                retainedImageRecordNames: retainedImages,
                newImageData: newImages,
                completion: completion
            )
        }, onDelete: {
            switch item {
            case .topic(let managedTopic):
                contentManager.deleteTopic(managedTopic)
                topic.isDeleted = true
            case .reply(let managedReply):
                contentManager.deleteReply(managedReply)
                replyManager.loadReplies()
            }
            loadEditableRepliesIfOwned()
            dismissDetail()
        })
    }

    private func applyManagedEdit(
        item: CommunityManagedContentEditItem,
        newTitle: String,
        newBody: String,
        retainedImageRecordNames: [String],
        newImageData: [Data],
        completion: @escaping (Result<[String], Error>) -> Void
    ) {
        switch item {
        case .topic(let editableTopic):
            contentManager.updateTopic(
                editableTopic,
                title: newTitle,
                body: newBody,
                retainedImageRecordNames: retainedImageRecordNames,
                newImageData: newImageData
            ) { result in
                if case .success(let imageRecordNames) = result {
                    topic.title = newTitle
                    topic.body = newBody
                    topic.updatedAt = Date()
                    topic.imageRecordNames = imageRecordNames
                    self.editableTopic?.title = newTitle
                    self.editableTopic?.body = newBody
                    self.editableTopic?.bodyPreview = communityBodyPreview(newBody)
                    self.editableTopic?.updatedAt = Date()
                    self.editableTopic?.imageRecordNames = imageRecordNames
                }
                completion(result)
            }
        case .reply(let editableReply):
            contentManager.updateReply(editableReply, body: newBody) { error in
                if error == nil {
                    replyManager.updateReplyLocally(replyId: editableReply.replyId, body: newBody)
                    editableReplies[editableReply.replyId]?.body = newBody
                    editableReplies[editableReply.replyId]?.bodyPreview = communityBodyPreview(newBody)
                    editableReplies[editableReply.replyId]?.updatedAt = Date()
                }
                if let error {
                    completion(.failure(error))
                } else {
                    completion(.success([]))
                }
            }
        }
    }

    @ToolbarContentBuilder
    private var topicDetailToolbar: some ToolbarContent {
        if let editableTopic, !editableTopic.isDeleted {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    editingItem = .topic(editableTopic)
                } label: {
                    Label(String(localized: "edit"), systemImage: "pencil")
                }
            }
        }

        ToolbarItem(placement: .primaryAction) {
            if K.Community.notificationsEnabled {
                Button {
                    subscriptionManager.toggleTopic(topic)
                } label: {
                    Label(String(localized: subscriptionManager.isSubscribed(to: topic.id) ? "community_unsubscribe" : "community_subscribe_topic"), systemImage: subscriptionManager.isSubscribed(to: topic.id) ? "bell.badge" : "bell")
                }
            }
        }
    }

    private var deleteReplyAlertPresented: Binding<Bool> {
        Binding(
            get: { replyDeletionTarget != nil },
            set: { if !$0 { replyDeletionTarget = nil } }
        )
    }

    private var replyErrorBinding: Binding<Bool> {
        Binding(
            get: { replyErrorMessage != nil },
            set: { isPresented in
                if !isPresented { replyErrorMessage = nil }
            }
        )
    }

    private func loadEditableTopicIfOwned() {
        guard let uid = Auth.auth().currentUser?.uid else {
            editableTopic = nil
            return
        }

        Firestore.firestore()
            .collection("communityContentOwners")
            .document(uid)
            .collection("topics")
            .document(topic.id)
            .getDocument { snapshot, _ in
                guard let snapshot, snapshot.exists else { return }
                var data = snapshot.data() ?? [:]
                data["id"] = snapshot.documentID
                DispatchQueue.main.async {
                    editableTopic = CommunityManagedTopic.from(data)
                }
            }
    }

    private func loadEditableRepliesIfOwned() {
        guard let uid = Auth.auth().currentUser?.uid else {
            editableReplies = [:]
            return
        }

        Firestore.firestore()
            .collection("communityContentOwners")
            .document(uid)
            .collection("replies")
            .whereField("topicId", isEqualTo: topic.id)
            .getDocuments { snapshot, _ in
                let replies = snapshot?.documents.compactMap { document -> CommunityManagedReply? in
                    var data = document.data()
                    data["id"] = document.documentID
                    return CommunityManagedReply.from(data)
                } ?? []
                DispatchQueue.main.async {
                    editableReplies = Dictionary(uniqueKeysWithValues: replies.map { ($0.replyId, $0) })
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

    private var canSubmitReply: Bool {
        !replyBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        Auth.auth().currentUser != nil &&
        !topic.isDeleted &&
        !isSubmitting
    }

    private var topicDisplayName: String {
        if topic.authorDeviceId == deviceId || editableTopic != nil {
            return CommunityProfileManager.currentNicknameDisplayName()
        }
        return topic.authorName
    }

    private func replyDisplayName(_ reply: CommunityReply) -> String {
        if reply.authorDeviceId == deviceId || editableReplies[reply.id] != nil {
            return CommunityProfileManager.currentNicknameDisplayName()
        }
        return reply.authorName
    }

    private func replyRowView(_ reply: CommunityReply) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(replyDisplayName(reply))
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
                if reply.isEdited {
                    Text(String(localized: "community_edited_label"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Text(reply.body)
                .font(.body)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 2)
        .commentCardStyle()
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if let editableReply = editableReplies[reply.id], !editableReply.isDeleted {
                Button(role: .destructive) {
                    replyDeletionTarget = .reply(editableReply)
                } label: {
                    Label(String(localized: "delete"), systemImage: "trash")
                }

                Button {
                    editingItem = .reply(editableReply)
                } label: {
                    Label(String(localized: "edit"), systemImage: "pencil")
                }
                .tint(.blue)
            }
        }
    }

    private func submitReply() {
        guard canSubmitReply else { return }
        if deviceId.isEmpty { deviceId = UUID().uuidString }
        isSubmitting = true
        replyManager.addReply(body: replyBody, authorName: CommunityProfileManager.currentNicknameDisplayName(), deviceId: deviceId, publishDepartment: publishDepartment, publishYear: publishYear, publishBadge: publishBadge) { error in
            isSubmitting = false
            if let error {
                replyErrorMessage = String(format: String(localized: "community_reply_failed_format"), communityErrorMessage(error))
            } else {
                replyBody = ""
                replyFieldFocused = false
                loadEditableRepliesIfOwned()
            }
        }
    }

    private var canToggleLike: Bool {
        onToggleLike != nil && Auth.auth().currentUser != nil
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

private typealias CommunityManagedContentSave = (
    _ title: String,
    _ body: String,
    _ retainedImageRecordNames: [String],
    _ newImageData: [Data],
    _ completion: @escaping (Result<[String], Error>) -> Void
) -> Void

private final class CommunityMyContentManager: ObservableObject {
    @Published var topics: [CommunityManagedTopic] = []
    @Published var replies: [CommunityManagedReply] = []
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var errorMessage: String?

    private let db = Firestore.firestore()

    func load() {
        guard let user = Auth.auth().currentUser else {
            topics = []
            replies = []
            errorMessage = String(localized: "community_google_sign_in_required_error")
            return
        }

        isLoading = true
        errorMessage = nil

        let ownerRoot = db.collection("communityContentOwners").document(user.uid)
        let group = DispatchGroup()
        var loadedTopics: [CommunityManagedTopic] = []
        var loadedReplies: [CommunityManagedReply] = []
        var loadError: Error?

        group.enter()
        ownerRoot.collection("topics").order(by: "createdAt", descending: true).getDocuments { snapshot, error in
            if let error { loadError = error }
            loadedTopics = snapshot?.documents.compactMap { document in
                var data = document.data()
                data["id"] = document.documentID
                return CommunityManagedTopic.from(data)
            } ?? []
            group.leave()
        }

        group.enter()
        ownerRoot.collection("replies").order(by: "createdAt", descending: true).getDocuments { snapshot, error in
            if let error { loadError = error }
            loadedReplies = snapshot?.documents.compactMap { document in
                var data = document.data()
                data["id"] = document.documentID
                return CommunityManagedReply.from(data)
            } ?? []
            group.leave()
        }

        group.notify(queue: .main) { [weak self] in
            guard let self else { return }
            if let loadError {
                self.isLoading = false
                self.errorMessage = communityErrorMessage(loadError)
            } else {
                self.filterRepliesWithActiveTopics(loadedReplies.filter { !$0.isDeleted }) { activeReplies in
                    self.isLoading = false
                    self.topics = loadedTopics.filter { !$0.isDeleted }
                    self.replies = activeReplies
                }
            }
        }
    }

    private func filterRepliesWithActiveTopics(_ replies: [CommunityManagedReply], completion: @escaping ([CommunityManagedReply]) -> Void) {
        let topicIds = Array(Set(replies.map(\.topicId)))
        guard !topicIds.isEmpty else {
            completion([])
            return
        }

        let batches = stride(from: 0, to: topicIds.count, by: 30).map {
            Array(topicIds[$0..<min($0 + 30, topicIds.count)])
        }
        let group = DispatchGroup()
        let lock = NSLock()
        var activeTopicIds = Set<String>()

        for batch in batches {
            group.enter()
            db.collection("communityTopics")
                .whereField(FieldPath.documentID(), in: batch)
                .getDocuments { snapshot, _ in
                    let activeIds = snapshot?.documents.compactMap { document -> String? in
                        guard let topic = CommunityTopic.from(document: document), !topic.isDeleted else { return nil }
                        return topic.id
                    } ?? []
                    lock.lock()
                    activeTopicIds.formUnion(activeIds)
                    lock.unlock()
                    group.leave()
                }
        }

        group.notify(queue: .main) {
            completion(replies.filter { activeTopicIds.contains($0.topicId) })
        }
    }

    func updateTopic(
        _ topic: CommunityManagedTopic,
        title: String,
        body: String,
        retainedImageRecordNames: [String],
        newImageData: [Data],
        completion: @escaping (Result<[String], Error>) -> Void
    ) {
        do {
            let user = try requireCommunityUser()
            let existingRecordNames = topic.imageRecordNames
            let retainedSet = Set(retainedImageRecordNames)
            guard retainedSet.isSubset(of: Set(existingRecordNames)) else {
                throw CommunityImageService.ImageError.invalidImage
            }

            let retainedNames = existingRecordNames.filter(retainedSet.contains)
            guard retainedNames.count + newImageData.count <= CommunityImageService.maximumImagesPerTopic else {
                throw CommunityImageService.ImageError.tooManyImages
            }

            isSaving = true
            errorMessage = nil
            let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
            let editRecordPrefix = "\(CommunityImageService.recordName(for: topic.topicId))-edit-"
            let newRecordNames = newImageData.indices.map { index in
                "\(editRecordPrefix)\(UUID().uuidString)-\(index)"
            }
            let removedRecordNames = existingRecordNames.filter { !retainedSet.contains($0) }

            Task { @MainActor [weak self] in
                guard let self else { return }
                do {
                    let uploadedRecordNames = try await CommunityImageService.shared.uploadJPEGs(
                        newImageData,
                        topicID: topic.topicId,
                        ownerUID: user.uid,
                        recordNames: newRecordNames
                    )
                    let finalRecordNames = retainedNames + uploadedRecordNames
                    self.commitTopicUpdate(
                        topic,
                        userUID: user.uid,
                        title: trimmedTitle,
                        body: trimmedBody,
                        finalRecordNames: finalRecordNames,
                        uploadedRecordNames: uploadedRecordNames,
                        removedRecordNames: removedRecordNames.filter { !uploadedRecordNames.contains($0) },
                        completion: completion
                    )
                } catch {
                    self.isSaving = false
                    self.errorMessage = communityErrorMessage(error)
                    completion(.failure(error))
                }
            }
        } catch {
            isSaving = false
            errorMessage = communityErrorMessage(error)
            completion(.failure(error))
        }
    }

    private func commitTopicUpdate(
        _ topic: CommunityManagedTopic,
        userUID: String,
        title: String,
        body: String,
        finalRecordNames: [String],
        uploadedRecordNames: [String],
        removedRecordNames: [String],
        completion: @escaping (Result<[String], Error>) -> Void
    ) {
        let now = FieldValue.serverTimestamp()
        let batch = db.batch()
        let topicRef = db.collection("communityTopics").document(topic.topicId)
        let ownerRef = db.collection("communityContentOwners").document(userUID).collection("topics").document(topic.topicId)
        var publicUpdate: [String: Any] = [
            "title": title,
            "body": body,
            "updatedAt": now
        ]
        var ownerUpdate: [String: Any] = [
            "title": title,
            "body": body,
            "bodyPreview": communityBodyPreview(body),
            "updatedAt": now
        ]

        if let firstRecordName = finalRecordNames.first {
            publicUpdate["imageRecordName"] = firstRecordName
            publicUpdate["imageRecordNames"] = finalRecordNames
            ownerUpdate["imageRecordName"] = firstRecordName
            ownerUpdate["imageRecordNames"] = finalRecordNames
        } else {
            publicUpdate["imageRecordName"] = FieldValue.delete()
            publicUpdate["imageRecordNames"] = FieldValue.delete()
            ownerUpdate["imageRecordName"] = FieldValue.delete()
            ownerUpdate["imageRecordNames"] = FieldValue.delete()
        }

        batch.updateData(publicUpdate, forDocument: topicRef)
        batch.updateData(ownerUpdate, forDocument: ownerRef)
        batch.commit { [weak self] error in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isSaving = false
                self.errorMessage = error.map(communityErrorMessage)

                if let error {
                    Task { @MainActor in
                        await CommunityImageService.shared.deleteImages(recordNames: uploadedRecordNames)
                    }
                    completion(.failure(error))
                } else {
                    Task { @MainActor in
                        await CommunityImageService.shared.deleteImages(recordNames: removedRecordNames)
                    }
                    completion(.success(finalRecordNames))
                    self.load()
                }
            }
        }
    }

    func deleteTopic(_ topic: CommunityManagedTopic) {
        do {
            let user = try requireCommunityUser()
            isSaving = true
            errorMessage = nil
            let now = FieldValue.serverTimestamp()
            let batch = db.batch()
            let topicRef = db.collection("communityTopics").document(topic.topicId)
            let ownerRef = db.collection("communityContentOwners").document(user.uid).collection("topics").document(topic.topicId)

            batch.updateData([
                "title": String(localized: "community_deleted_topic_title"),
                "body": String(localized: "community_deleted_topic_body"),
                "authorName": "",
                "authorDeviceId": "",
                "authorDepartment": "",
                "authorEntryYear": "",
                "authorShowsYear": false,
                "authorShowsBadge": false,
                "authorBadgeLevel": CommentBadgeManager.BadgeLevel.newbie.rawValue,
                "isDeleted": true,
                "deletedAt": now,
                "updatedAt": now
            ], forDocument: topicRef)
            batch.updateData([
                "title": String(localized: "community_deleted_topic_title"),
                "body": "",
                "bodyPreview": "",
                "isDeleted": true,
                "deletedAt": now,
                "updatedAt": now
            ], forDocument: ownerRef)
            batch.commit { [weak self] error in
                if error == nil {
                    Task { @MainActor in
                        await CommunityImageService.shared.deleteImages(recordNames: topic.imageRecordNames)
                        await CommunityImageService.shared.deleteImages(topicID: topic.topicId)
                    }
                }
                DispatchQueue.main.async { self?.finishMutation(error: error) }
            }
        } catch {
            finishMutation(error: error)
        }
    }

    func updateReply(_ reply: CommunityManagedReply, body: String, completion: @escaping (Error?) -> Void) {
        do {
            let user = try requireCommunityUser()
            isSaving = true
            errorMessage = nil
            let trimmedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
            let now = FieldValue.serverTimestamp()
            let batch = db.batch()
            let replyRef = db.collection("communityTopics").document(reply.topicId).collection("replies").document(reply.replyId)
            let ownerRef = db.collection("communityContentOwners").document(user.uid).collection("replies").document("\(reply.topicId)_\(reply.replyId)")

            batch.updateData(["body": trimmedBody, "updatedAt": now], forDocument: replyRef)
            batch.updateData([
                "body": trimmedBody,
                "bodyPreview": communityBodyPreview(trimmedBody),
                "updatedAt": now
            ], forDocument: ownerRef)
            batch.commit { [weak self] error in
                DispatchQueue.main.async { self?.finishMutation(error: error, completion: completion) }
            }
        } catch {
            finishMutation(error: error, completion: completion)
        }
    }

    func deleteReply(_ reply: CommunityManagedReply) {
        do {
            let user = try requireCommunityUser()
            isSaving = true
            errorMessage = nil
            let now = FieldValue.serverTimestamp()
            let topicRef = db.collection("communityTopics").document(reply.topicId)
            let replyRef = topicRef.collection("replies").document(reply.replyId)
            let ownerRef = db.collection("communityContentOwners").document(user.uid).collection("replies").document("\(reply.topicId)_\(reply.replyId)")

            // 先讀目前回覆數，寫入夾住下限的明確值（rules 僅允許往下修且 >= 0）
            topicRef.getDocument { [weak self] snapshot, _ in
                guard let self else { return }
                let currentCount = snapshot?.data()?["replyCount"] as? Int ?? 0
                let batch = self.db.batch()
                batch.deleteDocument(replyRef)
                if currentCount > 0 {
                    batch.updateData(["replyCount": max(0, currentCount - 1)], forDocument: topicRef)
                }
                batch.updateData([
                    "body": "",
                    "bodyPreview": "",
                    "isDeleted": true,
                    "deletedAt": now,
                    "updatedAt": now
                ], forDocument: ownerRef)
                batch.commit { error in
                    DispatchQueue.main.async { self.finishMutation(error: error) }
                }
            }
        } catch {
            finishMutation(error: error)
        }
    }

    func loadTopic(id topicId: String, completion: @escaping (Result<CommunityTopic, Error>) -> Void) {
        db.collection("communityTopics").document(topicId).getDocument { snapshot, error in
            if let error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }

            guard let snapshot,
                  snapshot.exists,
                  let topic = CommunityTopic.from(snapshot: snapshot),
                  !topic.isDeleted else {
                DispatchQueue.main.async {
                    completion(.failure(CommunityUserFacingError(message: String(localized: "community_open_topic_not_found"))))
                }
                return
            }

            DispatchQueue.main.async { completion(.success(topic)) }
        }
    }

    private func finishMutation(error: Error?, completion: ((Error?) -> Void)? = nil) {
        isSaving = false
        errorMessage = error.map(communityErrorMessage)
        completion?(error)
        if error == nil { load() }
    }
}

struct CommunityMyContentView: View {
    var body: some View {
        CommunityMyContentListView()
    }
}

private final class CommunityLikedTopicsManager: ObservableObject {
    @Published var topics: [CommunityTopic] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let db = Firestore.firestore()

    func load() {
        guard let user = Auth.auth().currentUser else {
            topics = []
            errorMessage = String(localized: "community_google_sign_in_required_error")
            return
        }

        isLoading = true
        errorMessage = nil
        db.collection("communityUserLikes")
            .document(user.uid)
            .collection("topics")
            .order(by: "likedAt", descending: true)
            .getDocuments { [weak self] snapshot, error in
                guard let self else { return }
                if let error {
                    DispatchQueue.main.async {
                        self.isLoading = false
                        self.errorMessage = communityErrorMessage(error)
                    }
                    return
                }

                let orderedIDs = snapshot?.documents.map(\.documentID) ?? []
                guard !orderedIDs.isEmpty else {
                    DispatchQueue.main.async {
                        self.isLoading = false
                        self.topics = []
                    }
                    return
                }

                let batches = stride(from: 0, to: orderedIDs.count, by: 30).map {
                    Array(orderedIDs[$0..<min($0 + 30, orderedIDs.count)])
                }
                let group = DispatchGroup()
                let lock = NSLock()
                var loadedTopics: [String: CommunityTopic] = [:]
                var loadError: Error?

                for batch in batches {
                    group.enter()
                    self.db.collection("communityTopics")
                        .whereField(FieldPath.documentID(), in: batch)
                        .getDocuments { snapshot, error in
                            lock.lock()
                            defer {
                                lock.unlock()
                                group.leave()
                            }
                            if let error {
                                loadError = error
                                return
                            }
                            for document in snapshot?.documents ?? [] {
                                if let topic = CommunityTopic.from(document: document) {
                                    loadedTopics[topic.id] = topic
                                }
                            }
                        }
                }

                group.notify(queue: .main) {
                    self.isLoading = false
                    if let loadError {
                        self.errorMessage = communityErrorMessage(loadError)
                        return
                    }
                    self.topics = orderedIDs.compactMap { loadedTopics[$0] }.filter { !$0.isDeleted }
                }
            }
    }
}

struct CommunityLikedTopicsView: View {
    @StateObject private var manager = CommunityLikedTopicsManager()
    @StateObject private var subscriptionManager = CommunitySubscriptionManager()

    var body: some View {
        List {
            if manager.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
            } else if let errorMessage = manager.errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.red)
            } else if manager.topics.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "heart")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text(String(localized: "community_liked_topics_empty"))
                        .font(.headline)
                    Text(String(localized: "community_liked_topics_empty_detail"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
                .listRowBackground(Color.clear)
            } else {
                ForEach(manager.topics) { topic in
                    NavigationLink {
                        CommunityTopicDetailView(topic: topic, subscriptionManager: subscriptionManager)
                    } label: {
                        CommunityTopicRow(topic: topic, isLiked: true)
                    }
                }
            }
        }
        .navigationTitle(String(localized: "community_liked_topics_title"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { manager.load() }
    }
}

private struct CommunityMyContentListView: View {
    @StateObject private var manager = CommunityMyContentManager()
    @StateObject private var subscriptionManager = CommunitySubscriptionManager()
    @State private var editingItem: CommunityManagedContentEditItem?
    @State private var deletionItem: CommunityManagedContentDeletionItem?
    @State private var selectedTopic: CommunityTopic?
    @State private var openingTopicID: String?

    var body: some View {
        List {
            Section {
                Label(String(localized: "community_my_content_private_notice"), systemImage: "lock.shield")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Label(String(localized: "community_my_content_swipe_hint"), systemImage: "hand.draw")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let errorMessage = manager.errorMessage {
                Section {
                    Label(errorMessage, systemImage: "exclamationmark.triangle")
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
                        managedTopicRow(topic)
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
                        managedReplyRow(reply)
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
        .background(topicNavigationLink)
        .sheet(item: $editingItem) { item in
            myContentEditSheet(for: item)
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
            } else if openingTopicID != nil {
                ProgressView(String(localized: "community_opening_topic"))
                    .padding(16)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 4)
            }
        }
        .disabled(manager.isSaving || openingTopicID != nil)
    }

    private func myContentEditSheet(for item: CommunityManagedContentEditItem) -> some View {
        CommunityManagedContentEditView(item: item, save: { title, body, retainedImages, newImages, completion in
            save(
                item: item,
                title: title,
                body: body,
                retainedImageRecordNames: retainedImages,
                newImageData: newImages,
                completion: completion
            )
        }, onDelete: {
            switch item {
            case .topic(let managedTopic):
                deletionItem = .topic(managedTopic)
            case .reply(let managedReply):
                deletionItem = .reply(managedReply)
            }
            deleteSelectedItem()
        })
    }

    private var deleteAlertBinding: Binding<Bool> {
        Binding(
            get: { deletionItem != nil },
            set: { isPresented in
                if !isPresented { deletionItem = nil }
            }
        )
    }

    private var selectedTopicIsActive: Binding<Bool> {
        Binding(
            get: { selectedTopic != nil },
            set: { isActive in
                if !isActive { selectedTopic = nil }
            }
        )
    }

    @ViewBuilder
    private var topicNavigationLink: some View {
        NavigationLink(isActive: selectedTopicIsActive) {
            if let selectedTopic {
                CommunityTopicDetailView(topic: selectedTopic, subscriptionManager: subscriptionManager)
            } else {
                EmptyView()
            }
        } label: {
            EmptyView()
        }
        .hidden()
    }

    private func save(
        item: CommunityManagedContentEditItem,
        title: String,
        body: String,
        retainedImageRecordNames: [String],
        newImageData: [Data],
        completion: @escaping (Result<[String], Error>) -> Void
    ) {
        switch item {
        case .topic(let topic):
            manager.updateTopic(
                topic,
                title: title,
                body: body,
                retainedImageRecordNames: retainedImageRecordNames,
                newImageData: newImageData,
                completion: completion
            )
        case .reply(let reply):
            manager.updateReply(reply, body: body) { error in
                if let error {
                    completion(.failure(error))
                } else {
                    completion(.success([]))
                }
            }
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

    @ViewBuilder
    private func managedTopicRow(_ topic: CommunityManagedTopic) -> some View {
        Button {
            openTopic(id: topic.topicId)
        } label: {
            CommunityManagedTopicRow(topic: topic)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func managedReplyRow(_ reply: CommunityManagedReply) -> some View {
        Button {
            openTopic(id: reply.topicId)
        } label: {
            CommunityManagedReplyRow(reply: reply)
        }
        .buttonStyle(.plain)
    }

    private func openTopic(id topicId: String) {
        openingTopicID = topicId
        manager.loadTopic(id: topicId) { result in
            openingTopicID = nil
            switch result {
            case .success(let topic):
                selectedTopic = topic
            case .failure(let error):
                manager.errorMessage = communityErrorMessage(error)
            }
        }
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}

private struct CommunityManagedReplyRow: View {
    let reply: CommunityManagedReply

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 8) {
                Label(String(localized: "community_reply_label"), systemImage: "text.bubble")
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private var replyContextLine: String {
        if !reply.title.isEmpty { return String(format: String(localized: "community_reply_topic_format"), reply.title) }
        return String(format: String(localized: "community_reply_topic_id_format"), reply.topicId)
    }
}

private struct CommunityManagedContentEditView: View {
    @Environment(\.dismiss) private var dismiss
    let item: CommunityManagedContentEditItem
    let save: CommunityManagedContentSave
    var onDelete: (() -> Void)? = nil

    @State private var title: String
    @State private var bodyText: String
    @State private var retainedImageRecordNames: [String]
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var preparedImages: [CommunityPreparedImage] = []
    @State private var imagePreparationGeneration = UUID()
    @State private var isPreparingImages = false
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showDeleteConfirm = false

    init(
        item: CommunityManagedContentEditItem,
        save: @escaping CommunityManagedContentSave,
        onDelete: (() -> Void)? = nil
    ) {
        self.item = item
        self.save = save
        self.onDelete = onDelete
        switch item {
        case .topic(let topic):
            _title = State(initialValue: topic.title)
            _bodyText = State(initialValue: topic.body)
            _retainedImageRecordNames = State(initialValue: topic.imageRecordNames)
        case .reply(let reply):
            _title = State(initialValue: "")
            _bodyText = State(initialValue: reply.body)
            _retainedImageRecordNames = State(initialValue: [])
        }
    }

    private var isTopic: Bool {
        if case .topic = item { return true }
        return false
    }

    private var canSave: Bool {
        let trimmedBody = bodyText.trimmingCharacters(in: .whitespacesAndNewlines)
        if isTopic {
            return !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !trimmedBody.isEmpty
                && !isSaving
                && !isPreparingImages
        }
        return !trimmedBody.isEmpty && !isSaving
    }

    private var imageCount: Int {
        retainedImageRecordNames.count + preparedImages.count
    }

    private var remainingImageCapacity: Int {
        max(0, CommunityImageService.maximumImagesPerTopic - retainedImageRecordNames.count)
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

                    imageEditorSection
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
                        Label(errorMessage, systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                if onDelete != nil {
                    Section {
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            Label(String(localized: "delete"), systemImage: "trash")
                        }
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
            .alert(String(localized: "community_delete_confirm_title"), isPresented: $showDeleteConfirm) {
                Button(String(localized: "delete"), role: .destructive) {
                    dismiss()
                    onDelete?()
                }
                Button(String(localized: "cancel"), role: .cancel) { }
            } message: {
                Text(String(localized: "community_delete_confirm_message"))
            }
            .onChange(of: selectedPhotoItems) { items in
                prepareSelectedImages(items)
            }
        }
    }

    private var imageEditorSection: some View {
        Section {
            if imageCount > 0 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(retainedImageRecordNames, id: \.self) { recordName in
                            CommunityTopicImageView(recordName: recordName)
                                .frame(width: 180, height: 150)
                                .background(.quaternary, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay(alignment: .topTrailing) {
                                    removeImageButton {
                                        retainedImageRecordNames.removeAll { $0 == recordName }
                                    }
                                }
                        }

                        ForEach(Array(preparedImages.enumerated()), id: \.element.id) { index, preparedImage in
                            Image(uiImage: preparedImage.preview)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 180, height: 150)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay(alignment: .topTrailing) {
                                    removeImageButton {
                                        removeSelectedImage(at: index)
                                    }
                                }
                        }
                    }
                }
            }

            if remainingImageCapacity > 0 {
                PhotosPicker(
                    selection: $selectedPhotoItems,
                    maxSelectionCount: remainingImageCapacity,
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    Label(
                        String(
                            format: String(localized: "community_images_selected_count_format"),
                            imageCount,
                            CommunityImageService.maximumImagesPerTopic
                        ),
                        systemImage: "photo.badge.plus"
                    )
                }
                .disabled(isSaving || isPreparingImages)
            }

            if isPreparingImages {
                HStack(spacing: 8) {
                    ProgressView()
                    Text(String(localized: "community_image_preparing"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text(String(localized: "community_image_section"))
        } footer: {
            Text(String(localized: "community_image_edit_footer"))
        }
    }

    private func removeImageButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "xmark.circle.fill")
                .font(.title2)
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, .black.opacity(0.65))
                .padding(6)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(localized: "community_image_remove"))
    }

    private func removeSelectedImage(at index: Int) {
        guard selectedPhotoItems.indices.contains(index), preparedImages.indices.contains(index) else { return }
        preparedImages.remove(at: index)
        selectedPhotoItems.remove(at: index)
    }

    private func prepareSelectedImages(_ items: [PhotosPickerItem]) {
        let generation = UUID()
        imagePreparationGeneration = generation
        guard !items.isEmpty else {
            preparedImages = []
            isPreparingImages = false
            return
        }

        isPreparingImages = true
        errorMessage = nil
        let maximumNewImages = remainingImageCapacity

        Task { @MainActor in
            do {
                var newPreparedImages: [CommunityPreparedImage] = []
                for item in items.prefix(maximumNewImages) {
                    try Task.checkCancellation()
                    guard let originalData = try await item.loadTransferable(type: Data.self) else {
                        throw CommunityImageService.ImageError.invalidImage
                    }
                    let preparedData = try CommunityImageService.shared.preparedJPEG(from: originalData)
                    guard let preview = UIImage(data: preparedData) else {
                        throw CommunityImageService.ImageError.invalidImage
                    }
                    newPreparedImages.append(CommunityPreparedImage(data: preparedData, preview: preview))
                }
                guard imagePreparationGeneration == generation else { return }
                preparedImages = newPreparedImages
                isPreparingImages = false
            } catch {
                guard imagePreparationGeneration == generation else { return }
                selectedPhotoItems = []
                preparedImages = []
                isPreparingImages = false
                errorMessage = communityErrorMessage(error)
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
            bodyText.trimmingCharacters(in: .whitespacesAndNewlines),
            retainedImageRecordNames,
            preparedImages.map(\.data)
        ) { result in
            isSaving = false
            switch result {
            case .failure(let error):
                errorMessage = communityErrorMessage(error)
            case .success:
                dismiss()
            }
        }
    }
}

struct CommunityProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var profileManager: CommunityProfileManager
    @State private var nickname: String = ""
    @State private var entryYearText: String = ""
    @State private var selectedDepartment: String = ""
    @State private var showDepartment = true
    @State private var showYear = false
    @State private var showBadge = true

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 8) {
                        TextField(String(localized: "community_nickname_placeholder"), text: $nickname)
                            .submitLabel(.done)
                            .onSubmit(saveNickname)

                        Button(String(localized: "save")) {
                            saveNickname()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(nickname.trimmingCharacters(in: .whitespacesAndNewlines) == profileManager.profile.nickname)
                    }
                } header: {
                    Text(String(localized: "community_profile_title"))
                } footer: {
                    Text(String(localized: "community_profile_footer"))
                }

                Section {
                    HStack(spacing: 8) {
                        TextField("113", text: $entryYearText)
                            .keyboardType(.numberPad)
                            .submitLabel(.done)
                            .onSubmit(saveEntryYear)

                        Button(String(localized: "save")) {
                            saveEntryYear()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(entryYearText.trimmingCharacters(in: .whitespacesAndNewlines) == profileManager.profile.entryYear)
                    }
                } header: {
                    Text(String(localized: "community_entry_year_header"))
                } footer: {
                    Text(String(localized: "community_entry_year_footer"))
                }

                Section {
                    Picker(String(localized: "community_department_pick_label"), selection: $selectedDepartment) {
                        ForEach(departmentOptions, id: \.self) { name in
                            Text(name).tag(name)
                        }
                    }
                    .onChange(of: selectedDepartment) { newValue in
                        guard newValue != profileManager.profile.department else { return }
                        profileManager.updateDepartment(newValue)
                        profileManager.authStatusMessage = String(localized: "community_profile_saved")
                    }
                } header: {
                    Text(String(localized: "community_department_header"))
                } footer: {
                    Text(String(localized: "community_department_footer"))
                }

                Section {
                    Toggle(String(localized: "community_default_show_department"), isOn: $showDepartment)
                    Toggle(String(localized: "community_publish_year"), isOn: $showYear)
                    Toggle(String(localized: "community_default_show_badge"), isOn: $showBadge)
                } header: {
                    Text(String(localized: "account_display_preferences"))
                }

                if let message = profileManager.authStatusMessage {
                    Section {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(String(localized: "community_profile_title"))
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                nickname = profileManager.profile.nickname
                entryYearText = profileManager.profile.entryYear
                selectedDepartment = profileManager.profile.department
                showDepartment = profileManager.profile.showDepartment
                showYear = profileManager.profile.showYear
                showBadge = profileManager.profile.showBadge
            }
            .onChange(of: showDepartment) { newValue in
                saveDisplayPreference(\.showDepartment, newValue)
            }
            .onChange(of: showYear) { newValue in
                saveDisplayPreference(\.showYear, newValue)
            }
            .onChange(of: showBadge) { newValue in
                saveDisplayPreference(\.showBadge, newValue)
            }
        }
        .communityDepartmentChooser(profileManager)
    }

    private func saveDisplayPreference(_ keyPath: WritableKeyPath<CommunityProfile, Bool>, _ value: Bool) {
        guard profileManager.profile[keyPath: keyPath] != value else { return }
        profileManager.profile[keyPath: keyPath] = value
        profileManager.saveProfile()
        profileManager.authStatusMessage = String(localized: "community_profile_saved")
    }

    private var departmentOptions: [String] {
        var names = Set(CommunityProfileManager.allDepartmentNames)
        if !profileManager.profile.department.isEmpty {
            names.insert(profileManager.profile.department)
        }
        return names.sorted()
    }

    private func saveNickname() {
        let trimmedNickname = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        profileManager.profile.nickname = trimmedNickname.isEmpty ? CommunityProfileManager.ensureDefaultNickname(deviceId: profileManager.profile.deviceId) : trimmedNickname
        profileManager.saveProfile()
        nickname = profileManager.profile.nickname
        profileManager.authStatusMessage = String(localized: "community_profile_saved")
    }

    private func saveEntryYear() {
        profileManager.updateEntryYear(entryYearText)
        entryYearText = profileManager.profile.entryYear
    }
}

private func relativeTime(_ date: Date) -> String {
    let formatter = RelativeDateTimeFormatter()
    formatter.locale = .current
    formatter.unitsStyle = .short
    return formatter.localizedString(for: date, relativeTo: Date())
}

private func authorProfileLine(department: String, entryYear: String, showsYear: Bool) -> String {
    var parts: [String] = []
    if !department.isEmpty { parts.append(department) }
    if showsYear, let gradeLine = currentGradeLine(entryYear: entryYear) { parts.append(gradeLine) }
    return parts.joined(separator: " · ")
}

private func communityAuthorDisplayName(storedName: String, authorDeviceId: String, currentDeviceId: String, currentNickname: String) -> String {
    if !authorDeviceId.isEmpty, authorDeviceId == currentDeviceId {
        let trimmedNickname = currentNickname.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedNickname.isEmpty { return trimmedNickname }
        return CommunityProfileManager.currentNicknameDisplayName()
    }
    return storedName
}

private func badgeLevel(from rawValue: Int) -> CommentBadgeManager.BadgeLevel {
    CommentBadgeManager.BadgeLevel(rawValue: rawValue) ?? .newbie
}

private func communityAuthorBadgeLevel(from data: [String: Any]) -> Int {
    if let level = data["authorBadgeLevel"] as? Int {
        return badgeLevel(from: level).rawValue
    }
    if let count = data["authorBadgeCount"] as? Int {
        return CommentBadgeManager.badgeLevel(for: count).rawValue
    }
    return CommentBadgeManager.BadgeLevel.newbie.rawValue
}

private func communityDate(from value: Any?) -> Date {
    communityOptionalDate(from: value) ?? Date()
}

private func communityOptionalDate(from value: Any?) -> Date? {
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
    return nil
}

private func communityBodyPreview(_ body: String) -> String {
    let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmed.count > 120 else { return trimmed }
    return String(trimmed.prefix(120)) + "..."
}

private func currentGradeLine(entryYear: String, now: Date = Date()) -> String? {
    guard let entryYear = Int(entryYear) else { return nil }

    let calendar = Calendar(identifier: .gregorian)
    let year = calendar.component(.year, from: now)
    let month = calendar.component(.month, from: now)
    let rocYear = year - 1911
    // 台灣學年度自 8 月 1 日起算，年級顯示隨日期自動晉級
    let academicYear = month >= 8 ? rocYear : rocYear - 1
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
