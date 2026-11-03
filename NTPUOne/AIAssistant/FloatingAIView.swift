import SwiftUI
import UIKit
import WebKit

// Keep the glass panel translucent while giving its content a stable contrast surface.
private enum AIChatColors {
    static let reply = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(red: 0.12, green: 0.15, blue: 0.20, alpha: 0.96) : UIColor(white: 1, alpha: 0.93) })
    static let hint = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(red: 0.13, green: 0.20, blue: 0.30, alpha: 0.97) : UIColor(red: 0.92, green: 0.96, blue: 1, alpha: 0.97) })
    static let border = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(white: 1, alpha: 0.22) : UIColor(red: 0.20, green: 0.32, blue: 0.48, alpha: 0.22) })
    static let user = Color(red: 0.16, green: 0.35, blue: 0.73)
}

/// Scale and translate a reminder toward its floating button.
private struct AIButtonEntrance: ViewModifier {
    let hidden: Bool
    let horizontal: CGFloat
    let vertical: CGFloat
    func body(content: Content) -> some View {
        content
            .scaleEffect(hidden ? 0.08 : 1, anchor: UnitPoint(x: 1, y: 1))
            .offset(x: hidden ? horizontal : 0, y: hidden ? vertical : 0)
            .opacity(hidden ? 0 : 1)
    }
}

struct FloatingAIContainer<Content: View>: View {
    let content: Content
    let contextProvider: (AIContextRequest) async -> AIContextPayload
    let openPage: (AIAppPage) -> Void
    let reviewChange: (AIChangeProposal) -> Void
    let reviewBatch: ([AIChangeProposal], @escaping () -> Void) -> Void
    let hasSavedSchoolAccount: Bool
    let credentialProvider: () -> SchoolCredential?
    @ObservedObject private var features = GlobalFeatureSettings.shared
    @StateObject private var bridge: NTPUAIWebBridge
    @State private var open = false
    @State private var preferDocked = true
    @State private var enteredBackground = false
    @State private var pageNavigation: Task<Void, Never>?
    @AppStorage("hasCompletedFirstRunOnboarding") private var onboardingComplete = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.layoutDirection) private var layoutDirection
    init(accountID: String, contextProvider: @escaping (AIContextRequest) async -> AIContextPayload, hasSavedSchoolAccount: Bool, credentialProvider: @escaping () -> SchoolCredential?, openPage: @escaping (AIAppPage) -> Void, reviewChange: @escaping (AIChangeProposal) -> Void, reviewBatch: @escaping ([AIChangeProposal], @escaping () -> Void) -> Void, @ViewBuilder content: () -> Content) {
        self.content = content(); self.contextProvider = contextProvider; self.openPage = openPage
        self.hasSavedSchoolAccount = hasSavedSchoolAccount; self.credentialProvider = credentialProvider; self.reviewChange = reviewChange; self.reviewBatch = reviewBatch
        _bridge = StateObject(wrappedValue: NTPUAIWebBridge(accountID: accountID))
    }
    private var arrivalTrigger: String {
        "\(features.aiEnabled)-\(onboardingComplete)-\(scenePhase == .active)-\(bridge.ready)-\(bridge.replying)-\(bridge.appDataEnabled)-\(bridge.arrivalEnabled)-\(open)"
    }
    private var animation: Animation { reduceMotion ? .easeInOut(duration: 0.15) : .spring(response: 0.38, dampingFraction: 0.86) }
    private func regions(_ proxy: GeometryProxy, division: Bool) -> [CGRect] {
        if #available(iOS 27.1, *) {
            return proxy.reservedRegions(kind: division ? .division : .occlusion).map(\.frame)
        }
        return []
    }
    var body: some View {
        GeometryReader { geo in
            let plan = DuoWorkspacePolicy.plan(size: geo.size, divisions: regions(geo, division: true),
                occlusions: regions(geo, division: false), assistantOpen: open, preferDocked: preferDocked,
                rightToLeft: layoutDirection == .rightToLeft)
            let anchorPoint = DuoWorkspacePolicy.buttonAnchor(size: geo.size,
                divisions: regions(geo, division: true), occlusions: regions(geo, division: false))
            let buttonAnchor = UnitPoint(x: anchorPoint.x, y: anchorPoint.y)
            let blocking = open && plan.mode == .overlay
            ZStack(alignment: .topLeading) {
                // A stable view identity preserves tab navigation and scroll position across folds.
                content
                    .frame(width: plan.page.width, height: plan.page.height)
                    .position(x: plan.page.midX, y: plan.page.midY)
                    .blur(radius: blocking ? 9 : 0).allowsHitTesting(!blocking).accessibilityHidden(blocking)
                if blocking {
                    Color(uiColor: .systemBackground).opacity(0.08).ignoresSafeArea()
                        .onTapGesture { withAnimation(animation) { open = false } }
                }
                if open {
                    AIChatPanel(bridge: bridge, preferDocked: $preferDocked, reviewChange: reviewChange, reviewBatch: reviewBatch, contextProvider: contextProvider,
                        hasSavedSchoolAccount: hasSavedSchoolAccount, credentialProvider: credentialProvider, openPage: { page in
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        if blocking { withAnimation(animation) { open = false } }
                        pageNavigation?.cancel()
                        pageNavigation = Task { @MainActor in
                            do { try await Task.sleep(nanoseconds: blocking ? 300_000_000 : 100_000_000) } catch { return }
                            guard !Task.isCancelled else { return }
                            openPage(page)
                        }
                    }) {
                        bridge.cancelStoredSchoolLogin(); withAnimation(animation) { open = false }
                    }
                    .frame(width: plan.assistant.width, height: plan.assistant.height)
                    .position(x: plan.assistant.midX, y: plan.assistant.midY)
                    .transition(reduceMotion ? .opacity : .scale(scale: 0.08, anchor: buttonAnchor).combined(with: .opacity))
                    .zIndex(1)
                }
                if !open {
                    AIWebsiteView(webView: bridge.webView).frame(width: 1, height: 1).opacity(0.01).allowsHitTesting(false).accessibilityHidden(true)
                    if features.aiEnabled {
                        let area = DuoWorkspacePolicy.floatingArea(size: geo.size, divisions: regions(geo, division: true), occlusions: regions(geo, division: false))
                        let button = DuoWorkspacePolicy.floatingButton(in: area, occlusions: regions(geo, division: false))
                        if !button.isEmpty {
                            let width = min(320, max(button.width, button.maxX - area.minX))
                            VStack(alignment: .trailing, spacing: 10) {
                                if let tip = bridge.arrivalTip, button.minY - area.minY >= 100 {
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack {
                                            Label("給你的小提醒", systemImage: "sparkles").font(.subheadline.weight(.semibold))
                                            Spacer(minLength: 8)
                                            Button { withAnimation(animation) { bridge.dismissArrivalTip() } } label: { Image(systemName: "xmark").frame(width: 44, height: 44) }
                                                .accessibilityLabel("關閉提醒")
                                        }
                                        ScrollView { Text(tip).font(.subheadline).fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, alignment: .leading) }
                                            .frame(maxHeight: max(0, min(180, button.minY - area.minY - 86)))
                                    }
                                    .padding(12).background(AIChatColors.hint, in: RoundedRectangle(cornerRadius: 18))
                                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(AIChatColors.border))
                                    .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
                                    .transition(reduceMotion ? .opacity : .modifier(
                                        active: AIButtonEntrance(hidden: true,
                                            horizontal: -button.width / 2,
                                            vertical: button.height / 2 + 10),
                                        identity: AIButtonEntrance(hidden: false, horizontal: 0, vertical: 0)))
                                }
                                Button {
                                    bridge.start(); bridge.dismissArrivalTip(); withAnimation(animation) { open = true }
                                } label: {
                                    Group {
                                        if bridge.loading || bridge.preparingArrival || bridge.replying { ProgressView().tint(.white) }
                                        else { Image(systemName: "sparkles").font(.system(size: 22, weight: .semibold)).foregroundStyle(.white) }
                                    }.frame(width: button.width, height: button.height)
                                        .background(Color.accentColor, in: Circle())
                                        .overlay(alignment: .topTrailing) {
                                            if bridge.arrivalTip != nil { Circle().fill(Color.red).frame(width: 11, height: 11).overlay(Circle().stroke(.white, lineWidth: 1.5)) }
                                        }
                                        .shadow(color: .black.opacity(0.22), radius: 8, y: 4)
                                }.accessibilityLabel(bridge.arrivalTip == nil ? "開啟 AI 助理" : "開啟 AI 助理，有新提醒")
                            }
                            .padding(.bottom, max(0, area.maxY - button.maxY))
                            .frame(width: width, height: area.height, alignment: .bottomTrailing)
                            .animation(animation, value: bridge.arrivalTip)
                            .position(x: button.maxX - width / 2, y: area.midY)
                            .zIndex(2)
                        }
                    }
                }
            }
            .task(id: "\(onboardingComplete)-\(features.aiEnabled)") { if onboardingComplete && features.aiEnabled { bridge.start() } }
            .task(id: arrivalTrigger) {
                guard features.aiEnabled, onboardingComplete, scenePhase == .active, !open, bridge.ready, bridge.arrivalEnabled else { return }
                do { try await Task.sleep(nanoseconds: 2_000_000_000) } catch { return }
                guard !Task.isCancelled else { return }
                await bridge.requestArrival(contextProvider: contextProvider)
            }
            .onChange(of: features.aiEnabled) { enabled in
                if !enabled { pageNavigation?.cancel(); bridge.cancelArrival(); bridge.stop(); bridge.cancelStoredSchoolLogin(); open = false }
            }
            .onChange(of: open) { visible in
                bridge.setChatVisible(visible)
                if !visible {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    bridge.cancelStoredSchoolLogin()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification).receive(on: RunLoop.main)) { _ in bridge.honorPersistedRevocations() }
            .onDisappear { pageNavigation?.cancel(); bridge.cancelArrival(); bridge.cancelStoredSchoolLogin() }
            .onChange(of: scenePhase) { phase in
                if phase == .active {
                    if enteredBackground { bridge.beginForegroundEntry(); enteredBackground = false }
                    if features.aiEnabled { bridge.checkStatus() }
                } else {
                    if phase == .background { enteredBackground = true }
                    bridge.cancelArrival()
                }
            }
        }
    }
}

private struct AIChatPanel: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @ObservedObject var bridge: NTPUAIWebBridge
    @Binding var preferDocked: Bool
    let reviewChange: (AIChangeProposal) -> Void
    let reviewBatch: ([AIChangeProposal], @escaping () -> Void) -> Void
    let contextProvider: (AIContextRequest) async -> AIContextPayload
    let hasSavedSchoolAccount: Bool
    let credentialProvider: () -> SchoolCredential?
    let openPage: (AIAppPage) -> Void
    let close: () -> Void
    @State private var showDataSettings = false
    @State private var showDeleteSchoolChat = false
    @State private var showWebSearch = false
    @State private var webQuery = ""
    @State private var webSearching = false
    @State private var webError: String?
    @State private var webTask: Task<Void, Never>?
    @State private var draft = ""
    @State private var followLatest = true
    @FocusState private var inputFocused: Bool
    @GestureState private var dismissDrag: CGFloat = 0
    var body: some View {
        VStack(spacing: 0) {
            Capsule().fill(.secondary.opacity(0.45)).frame(width: 42, height: 5)
                .frame(maxWidth: .infinity, minHeight: 28)
                .padding(.top, 24)
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 8)
                    .updating($dismissDrag) { value, state, _ in
                        if value.translation.height > 0 && abs(value.translation.height) > abs(value.translation.width) {
                            state = min(value.translation.height, 220)
                        }
                    }
                    .onEnded { value in
                        guard AIPanelDismissPolicy.shouldDismiss(horizontal: value.translation.width,
                            vertical: value.translation.height, predictedVertical: value.predictedEndTranslation.height) else { return }
                        inputFocused = false; close()
                    })
                .accessibilityLabel("向下滑動關閉 AI 助理")
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { inputFocused = false; close() }
            HStack(spacing: 10) {
                Image(systemName: "sparkles").font(.headline).foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text("NTPU One AI").font(.headline).lineLimit(1).minimumScaleFactor(0.8)
                    Text(bridge.replying ? "正在回覆" : bridge.loading ? "連線中" : bridge.ready ? "已連線" : "請登入 NTPU AI")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if bridge.showingWebsite { Button("完成") { bridge.checkStatus() }.font(.subheadline.weight(.semibold)) }
                Button { inputFocused = false; followLatest = true; bridge.newConversation() } label: {
                    Image(systemName: "square.and.pencil").font(.body.weight(.semibold)).frame(width: 44, height: 44)
                }.accessibilityLabel("新對話").disabled(bridge.showingWebsite || bridge.storedLoginInProgress || bridge.deletingSchoolConversation)
                Group {
                    Menu {
                        Toggle("寬畫面並排", isOn: $preferDocked)
                        Button("網路搜尋") { inputFocused = false; webQuery = draft; webError = nil; showWebSearch = true }.disabled(!bridge.ready || bridge.replying || bridge.deletingSchoolConversation)
                        Button("資料與提醒設定") { inputFocused = false; showDataSettings = true }
                        Button("刪除這次校方對話", role: .destructive) { inputFocused = false; showDeleteSchoolChat = true }.disabled(!bridge.ready || bridge.replying || bridge.deletingSchoolConversation || !bridge.hasSchoolConversation)
                    } label: {
                        Image(systemName: bridge.appDataEnabled ? "sparkles.rectangle.stack.fill" : "sparkles.rectangle.stack")
                            .foregroundStyle(bridge.appDataEnabled ? Color.accentColor : Color.secondary)
                            .frame(width: 44, height: 44)
                    }.accessibilityLabel("AI 資料設定")
                }
                Button(action: close) { Image(systemName: "xmark").font(.subheadline.weight(.bold)).padding(9).background(.quaternary, in: Circle()).frame(width: 44, height: 44) }.accessibilityLabel("關閉 AI 助理")
            }.padding(14)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.23), lineWidth: 0.7))
                .padding(.horizontal, 4).padding(.top, 4)
            ZStack {
                if !bridge.showingWebsite {
                    VStack(spacing: 0) {
                        ScrollViewReader { proxy in
                            ScrollView {
                                LazyVStack(alignment: .leading, spacing: 12) {
                                    if bridge.messages.isEmpty && (bridge.preparingArrival || bridge.replying) {
                                        AITypingIndicator(label: "正在準備提醒").padding(12)
                                    }
                                    ForEach(bridge.messages) { message in
                                        HStack {
                                            if message.isUser { Spacer(minLength: 36) }
                                            Group {
                                                if !message.isUser && message.text.isEmpty && bridge.replying {
                                                    AITypingIndicator(label: bridge.replyStatus)
                                                } else { AIMessageBody(message: message, canReview: !bridge.replying, reviewChange: reviewChange, reviewBatch: reviewBatch, openPage: { page in inputFocused = false; openPage(page) }) }
                                            }.padding(12)
                                                .foregroundStyle(message.isUser ? Color.white : Color.primary)
                                                .background { RoundedRectangle(cornerRadius: 18).fill(message.isUser ? AIChatColors.user : AIChatColors.reply).overlay(RoundedRectangle(cornerRadius: 18).stroke(message.isUser ? Color.clear : AIChatColors.border, lineWidth: 1)) }
                                            if !message.isUser { Spacer(minLength: 36) }
                                        }.id(message.id)
                                    }
                                    if let notice = bridge.contextNotice {
                                        Label(notice, systemImage: "info.circle")
                                            .font(.caption).foregroundStyle(.primary)
                                            .fixedSize(horizontal: false, vertical: true)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding(12).background(AIChatColors.hint, in: RoundedRectangle(cornerRadius: 12))
                                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(AIChatColors.border, lineWidth: 1))
                                            .padding(.top, 4)
                                    }
                                    Color.clear.frame(height: 16).id("bottom")
                                }.padding(16)
                            }
                            .scrollDismissesKeyboard(.interactively)
                            .simultaneousGesture(DragGesture(minimumDistance: 8).onChanged { _ in followLatest = false })
                            .onPreferenceChange(AIMarkdownHeightKey.self) { _ in if followLatest { proxy.scrollTo("bottom", anchor: .bottom) } }
                            .onChange(of: bridge.contextNotice) { _ in if followLatest { proxy.scrollTo("bottom", anchor: .bottom) } }
                            .onChange(of: bridge.messages.count) { _ in if followLatest { proxy.scrollTo("bottom", anchor: .bottom) } }
                            .onChange(of: bridge.messages.last?.text) { _ in if followLatest { proxy.scrollTo("bottom", anchor: .bottom) } }
                            .overlay(alignment: .bottomTrailing) {
                                if !followLatest {
                                    Button { followLatest = true; withAnimation { proxy.scrollTo("bottom", anchor: .bottom) } } label: {
                                        Image(systemName: "arrow.down").padding(9).background(.regularMaterial, in: Circle()).shadow(radius: 2)
                                    }.accessibilityLabel("前往最新訊息").padding(10)
                                }
                            }
                        }
                        if let error = bridge.error {
                            HStack { Text(error).font(.caption).foregroundStyle(.secondary); Spacer(); Button("重新載入") { bridge.reload() }.font(.caption) }.padding(.horizontal, 16).padding(.bottom, 8)
                        }
                        if !bridge.ready && bridge.loading {
                            HStack(spacing: 10) { ProgressView(); Text(bridge.storedLoginInProgress ? "正在使用學校帳號登入…" : "正在恢復登入狀態…").font(.subheadline).foregroundStyle(.secondary) }.padding(.vertical, 8)
                            if bridge.storedLoginInProgress {
                                Button("改用手動登入") { bridge.finishStoredLogin(showWebsite: true) }.font(.caption).padding(.bottom, 8)
                            }
                        }
                        if !bridge.ready && !bridge.loading {
                            if hasSavedSchoolAccount && !bridge.diagnosingLogin {
                                Button("使用已儲存的學校帳號登入") { inputFocused = false; bridge.beginStoredSchoolLogin(provider: credentialProvider) }
                                    .buttonStyle(.borderedProminent).padding(.bottom, 4)
                            }
                            Button(hasSavedSchoolAccount ? "手動登入" : "登入 NTPU AI") { bridge.showingWebsite = true; inputFocused = false }
                                .buttonStyle(.bordered).padding(.bottom, 4)
                            Link("開啟官方網站", destination: URL(string: "https://ai.ntpu.edu.tw/")!).font(.caption).padding(.bottom, 8)
                        }
                        HStack(alignment: .bottom, spacing: 10) {
                            if inputFocused {
                                Button { inputFocused = false } label: { Image(systemName: "keyboard.chevron.compact.down").frame(width: 34, height: 40) }.accessibilityLabel("收起鍵盤")
                            }
                            TextField("輸入訊息", text: $draft, axis: .vertical).lineLimit(1...5).focused($inputFocused)
                                .padding(10).background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
                                .disabled(!bridge.ready || bridge.replying)
                            if bridge.replying {
                                Button { bridge.stop() } label: { Image(systemName: "stop.fill").frame(width: 40, height: 40) }.accessibilityLabel("停止回覆")
                            } else {
                                Button { let text = draft; draft = ""; followLatest = true; bridge.send(text, contextProvider: bridge.appDataEnabled ? contextProvider : nil, includeSensitive: bridge.sensitiveDataEnabled) } label: { Image(systemName: "arrow.up").fontWeight(.bold).foregroundStyle(.white).frame(width: 40, height: 40).background(Color.accentColor, in: Circle()) }
                                    .disabled(!bridge.ready || bridge.deletingSchoolConversation || draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty).accessibilityLabel("送出訊息")
                            }
                        }.padding(10)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22))
                            .overlay(RoundedRectangle(cornerRadius: 22).stroke(.white.opacity(0.25), lineWidth: 0.7))
                            .padding(4)
                    }
                }
                AIWebsiteView(webView: bridge.webView)
                    .opacity(bridge.showingWebsite ? 1 : 0.01)
                    .frame(maxWidth: bridge.showingWebsite ? .infinity : 1, maxHeight: bridge.showingWebsite ? .infinity : 1)
                    .allowsHitTesting(bridge.showingWebsite).accessibilityHidden(!bridge.showingWebsite)
            }
        }
         .background {
            if reduceTransparency { RoundedRectangle(cornerRadius: 24).fill(Color(uiColor: .systemBackground)) }
            else { RoundedRectangle(cornerRadius: 24).fill(.ultraThinMaterial).opacity(0.62).overlay(RoundedRectangle(cornerRadius: 24).fill(Color(uiColor: .systemBackground).opacity(0.04))) }
        }
        .onAppear {
            bridge.showWelcomeIfNeeded()
            if !bridge.hasPromptedForAppData { bridge.hasPromptedForAppData = true; showDataSettings = true }
        }
        .onChange(of: bridge.messages.count) { _ in bridge.showWelcomeIfNeeded() }
        .onChange(of: bridge.preparingArrival) { _ in bridge.showWelcomeIfNeeded() }
        .onChange(of: bridge.replying) { _ in bridge.showWelcomeIfNeeded() }
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .offset(y: dismissDrag)
        .sheet(isPresented: $showWebSearch, onDismiss: { webTask?.cancel(); webSearching = false }) {
            NavigationStack {
                Form {
                    Section("搜尋內容") {
                        TextField("輸入要查詢的問題", text: $webQuery, axis: .vertical).lineLimit(2...5).disabled(webSearching)
                        Text("搜尋文字會傳送至第三方 Exa；結果及你的問題會傳送至 NTPU AI。請勿輸入帳密或不想分享的個人資料。") .font(.caption).foregroundStyle(.secondary)
                    }
                    if let webError { Section { Text(webError).foregroundStyle(.red) } }
                    Section {
                        Button(webSearching ? "搜尋中…" : "搜尋並詢問 AI") {
                            let query = webQuery.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !query.isEmpty, query.count <= 300 else { webError = "請輸入 1 至 300 字的搜尋內容。"; return }
                            webSearching = true; webError = nil
                            webTask = Task { @MainActor in
                                do {
                                    let results = try await AIWebSearch.search(query)
                                    guard !Task.isCancelled, bridge.ready, !bridge.replying else { webSearching = false; return }
                                    // Dismissal cancels webTask; detach only after all search work is complete.
                                    webTask = nil; webSearching = false; showWebSearch = false; draft = ""; followLatest = true
                                    bridge.send(query, contextProvider: bridge.appDataEnabled ? contextProvider : nil, includeSensitive: bridge.sensitiveDataEnabled, webResults: results)
                                } catch {
                                    guard !Task.isCancelled else { return }
                                    webSearching = false; webError = "搜尋暫時無法使用，請稍後再試。問題尚未送出。"
                                }
                            }
                        }.disabled(webSearching)
                    }
                }
                .navigationTitle("網路搜尋")
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { webTask?.cancel(); showWebSearch = false } } }
            }
        }
        .confirmationDialog("刪除這次校方對話？", isPresented: $showDeleteSchoolChat, titleVisibility: .visible) {
            Button("刪除這次對話", role: .destructive) { bridge.deleteCurrentSchoolConversation() }
        } message: { Text("刪除後無法復原；帳號的長期記憶和其他對話不受影響。") }
        .sheet(isPresented: $showDataSettings) {
            NavigationStack {
                Form {
                    Section {
                        Toggle("使用 App 資料", isOn: Binding(get: { bridge.appDataEnabled }, set: { if $0 { bridge.enableAppData() } else { bridge.disableAppData() } }))
                        Toggle("手機與 iCloud 課表", isOn: Binding(get: { bridge.shareCourses }, set: { bridge.setSource("courses", enabled: $0) })).disabled(!bridge.appDataEnabled)
                        Toggle("手機與 iCloud 備忘錄", isOn: Binding(get: { bridge.shareMemos }, set: { bridge.setSource("memos", enabled: $0) })).disabled(!bridge.appDataEnabled)
                        Toggle("Moodle 課程與作業", isOn: Binding(get: { bridge.shareMoodle }, set: { bridge.setSource("moodle", enabled: $0) })).disabled(!bridge.appDataEnabled)
                        Toggle("學生資訊系統", isOn: Binding(get: { bridge.shareSchool }, set: { bridge.setSource("school", enabled: $0) })).disabled(!bridge.appDataEnabled)
                        Toggle("成績與畢業資料", isOn: Binding(get: { bridge.sensitiveDataEnabled }, set: { if $0 { bridge.enableSensitiveData() } else { bridge.disableSensitiveData() } }))
                            .disabled(!bridge.appDataEnabled)
                    } header: { Text("AI 可使用的資訊") } footer: {
                        Text("課表與備忘錄預設開啟；Moodle、學生資訊系統及成績預設關閉。開啟的資料會依問題選取並傳至 NTPU AI，校方可能保存。成績另須開啟所屬來源及成績開關；帳密與 Cookie 不會作為聊天資料。")
                    }
                    Section {
                        Toggle("進入 App 時提醒", isOn: Binding(get: { bridge.arrivalEnabled }, set: { bridge.setArrivalEnabled($0) }))
                    } footer: {
                        Text("每次開啟 App 或從背景回來時提醒一次；AI 必須已登入。未開啟 App 資料時只提供公開資訊。設定會沿用後續聊天，隨時可關閉。")
                    }
                }
                .navigationTitle("AI 資料與提醒")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { showDataSettings = false } } }
            }
            .presentationDetents([.medium, .large])
        }


    }
}


private struct AITypingIndicator: View {
    let label: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        TimelineView(.animation(minimumInterval: 0.35, paused: reduceMotion)) { timeline in
            let phase = Int(timeline.date.timeIntervalSinceReferenceDate / 0.35) % 3
            HStack(spacing: 9) {
                HStack(spacing: 4) {
                    ForEach(0..<3) { index in
                        Circle().fill(Color.accentColor.opacity(reduceMotion || phase == index ? 0.9 : 0.25))
                            .frame(width: 6, height: 6)
                            .offset(y: !reduceMotion && phase == index ? -2 : 0)
                    }
                }
                Text(label).font(.caption).foregroundStyle(.secondary)
            }
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: phase)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
    }
}

/// Render bounded Markdown blocks with native, allowlisted page actions.
private struct AIMessageBody: View {
    @State private var batchApplied = false
    let message: AIChatMessage
    let canReview: Bool
    let reviewChange: (AIChangeProposal) -> Void
    let reviewBatch: ([AIChangeProposal], @escaping () -> Void) -> Void
    let openPage: (AIAppPage) -> Void
    private var pages: [AIAppPage] {
        guard !message.isUser else { return [] }
        return AIAppPage.allCases.filter { message.text.contains("[[page:\($0.rawValue)]]") }
    }
    private var displayText: String {
        guard !message.isUser else { return message.text }
        return AIAppPage.allCases.reduce(AIChangeProposal.displayText(message.text)) { $0.replacingOccurrences(of: "[[page:\($1.rawValue)]]", with: "") }.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if message.isUser {
                Text(displayText.isEmpty ? "…" : displayText).textSelection(.enabled)
            } else {
                AIMarkdownView(text: displayText.isEmpty ? "…" : displayText)
            }
            if !message.isUser, canReview, let proposals = AIChangeProposal.extractAll(from: message.text) {
                if proposals.count > 1 {
                    Text("共 \(proposals.count) 筆建議，可一起預覽確認；若已逐筆儲存，請勿再次整批套用。") .font(.caption).foregroundStyle(.secondary)
                    if batchApplied { Label("這組變更已儲存", systemImage: "checkmark.circle").font(.caption) }
                    else { Button("預覽全部變更") { reviewBatch(proposals) { batchApplied = true } }.buttonStyle(.borderedProminent) }
                }
                ForEach(Array(proposals.enumerated()), id: \.offset) { _, proposal in
                VStack(alignment: .leading, spacing: 8) {
                    let verb = proposal.operation == .create ? "新增" : proposal.operation == .edit ? "修改" : "刪除"
                    Label("AI 建議\(verb)\(proposal.kind == .memo ? "備忘錄" : "課程")", systemImage: "square.and.pencil").font(.subheadline.weight(.semibold))
                    if let target = proposal.target, !target.isEmpty { Text("目標：\(target)").font(.caption) }
                    if let title = proposal.title, !title.isEmpty { Text("名稱：\(title)").font(.caption) }
                    if let deadline = proposal.deadline, !deadline.isEmpty { Text("截止建議：\(deadline)").font(.caption) }
                    if let day = proposal.weekday, let period = proposal.period { Text("建議時段：\(day) · 第 \(period) 節").font(.caption) }
                    Text("每次確認都會執行一次，請避免重複新增。") .font(.caption).foregroundStyle(.secondary)
                    Button("查看並確認") { reviewChange(proposal) }.buttonStyle(.borderedProminent).disabled(batchApplied)
                }.padding(12).frame(maxWidth: .infinity, alignment: .leading)
                    .background(AIChatColors.hint, in: RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(AIChatColors.border))
            }
            }
            if !message.isUser, canReview, message.text.contains("<ntpu-change>"), AIChangeProposal.extractAll(from: message.text) == nil {
                Label("無法解析變更建議，請重新提出要求。", systemImage: "exclamationmark.triangle").font(.caption).foregroundStyle(.secondary)
            }
            ForEach(pages) { page in
                Button { openPage(page) } label: {
                    Label("開啟\(page.title)", systemImage: "arrow.up.right.square")
                        .fixedSize(horizontal: false, vertical: true).padding(.vertical, 4)
                }.buttonStyle(.bordered)
                    .padding(.top, 2)
            }
        }
    }
}

/// Sandboxed local renderer shared with ntpu-ai-vscode. No remote resources or raw HTML.
private struct AIMarkdownHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value += nextValue() }
}

private struct AIMarkdownView: View {
    let text: String
    @State private var height: CGFloat = 40
    var body: some View {
        AIMarkdownSurface(text: text, height: $height)
            .frame(height: height)
            .frame(maxWidth: .infinity, alignment: .leading)
            .preference(key: AIMarkdownHeightKey.self, value: height)
    }
}

private struct AIMarkdownSurface: UIViewRepresentable {
    let text: String
    @Binding var height: CGFloat
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.userContentController.add(context.coordinator, name: "ntpuMarkdownSize")
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.isOpaque = false; view.backgroundColor = .clear; view.scrollView.backgroundColor = .clear
        view.scrollView.isScrollEnabled = false
        view.navigationDelegate = context.coordinator
        guard let url = Bundle.main.url(forResource: "markdown-renderer.bundle", withExtension: "js"),
              let script = try? String(contentsOf: url, encoding: .utf8) else { return view }
        let html = """
        <!doctype html><html><head><meta name="viewport" content="width=device-width, initial-scale=1">
        <meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline'; script-src 'unsafe-inline'">
        <style>
        :root { color-scheme: light dark; background:transparent; } body { margin:0; background:transparent; color:CanvasText; font:-apple-system-body; overflow-wrap:anywhere; line-height:1.55; }
        #content { display:flow-root; padding-bottom:10px; } p { margin:.4em 0 .7em; } h1,h2,h3,h4 { margin:.8em 0 .4em; line-height:1.25; } h1 {font-size:1.35em} h2 {font-size:1.2em} h3 {font-size:1.1em}
        ul,ol { padding-left:1.5em; margin:.4em 0 .7em; } blockquote { border-left:3px solid #888; margin:.5em 0; padding-left:.8em; }
        pre { overflow-x:auto; padding:10px; border-radius:10px; background:rgba(128,128,128,.13); } code { font-family:ui-monospace,monospace; font-size:.9em; }
        table { display:block; overflow:auto; border-collapse:collapse; } td,th { border:1px solid #8888; padding:4px 8px; } math {font-size:1.1em} .math-block {overflow-x:auto}
        a { color:#155caf; } .image-reference { color:#666; }
        @media (prefers-color-scheme: dark) { a { color:#82baff; } .image-reference { color:#b8c3d0; } }
        </style></head><body><div id="content"></div><script>\(script)</script><script>
        window.ntpuReportSize = () => {
            const node=document.getElementById('content');
            const height=Math.ceil(Math.max(node.getBoundingClientRect().height,node.scrollHeight)+12);
            window.webkit.messageHandlers.ntpuMarkdownSize.postMessage({height, width:node.getBoundingClientRect().width});
        };
        new ResizeObserver(window.ntpuReportSize).observe(document.getElementById('content'));
        document.fonts.ready.then(window.ntpuReportSize);
        </script></body></html>
        """
        view.loadHTMLString(html, baseURL: nil)
        return view
    }
    func updateUIView(_ view: WKWebView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.render(view)
    }
    static func dismantleUIView(_ view: WKWebView, coordinator: Coordinator) {
        view.configuration.userContentController.removeScriptMessageHandler(forName: "ntpuMarkdownSize")
        view.stopLoading()
    }
    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: AIMarkdownSurface
        var loaded = false
        var lastText: String?
        init(_ parent: AIMarkdownSurface) { self.parent = parent }
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { loaded = true; render(webView) }
        func render(_ view: WKWebView) {
            guard loaded, lastText != parent.text else { return }
            lastText = parent.text
            view.callAsyncJavaScript("document.getElementById('content').innerHTML = NTPUMarkdown.md.render(text); window.ntpuReportSize();", arguments: ["text": String(parent.text.prefix(100_000))], in: nil, in: .page) { _ in }
        }
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.frameInfo.isMainFrame,
                  let body = message.body as? [String: Any],
                  let value = body["height"] as? NSNumber, let width = body["width"] as? NSNumber,
                  width.doubleValue > 0, value.doubleValue.isFinite else { return }
            let height = min(50_000, max(32, CGFloat(truncating: value)))
            guard abs(parent.height - height) > 0.5 else { return }
            parent.height = height
        }
        func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if action.navigationType == .linkActivated, let url = action.request.url, ["https", "http"].contains(url.scheme?.lowercased() ?? "") {
                UIApplication.shared.open(url); decisionHandler(.cancel); return
            }
            decisionHandler(action.navigationType == .other && action.request.url?.scheme == "about" ? .allow : .cancel)
        }
    }
}

/// Builds bounded, labelled snapshots only for the categories chosen by the model.
enum AIContextSnapshot {
    static func make(_ kinds: Set<String>, courses: [Course], memos: [Memo], orders: [Order], bikes: [UBResults], bikeUpdated: Date?) -> String {
        var sections: [String] = []
        func limited(_ value: String, _ count: Int = 240) -> String { String(value.prefix(count)) }
        if kinds.contains("courses") {
            let rows = courses.prefix(80).map { "\(limited($0.name, 80))｜\($0.day) \($0.startTime.rawValue)｜節次 \($0.timeSlot.rawValue)｜提醒 \($0.isNotification ? "開啟" : "關閉")｜\(limited($0.location, 80))｜\(limited($0.teacher, 60))" }
            sections.append("課表（\(courses.count) 筆；最多 80 筆）:\n" + (rows.isEmpty ? "無可用資料" : rows.joined(separator: "\n")))
        }
        if kinds.contains("memos") {
            let names = Dictionary(courses.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
            let ordered = memos.sorted {
                if ($0.status == .done) != ($1.status == .done) { return $0.status != .done }
                if $0.dueAt != $1.dueAt { return ($0.dueAt ?? .distantFuture) < ($1.dueAt ?? .distantFuture) }
                return $0.updatedAt > $1.updatedAt
            }
            let rows = ordered.prefix(50).map { memo in
                let due = memo.dueAt?.formatted(date: .numeric, time: .shortened) ?? "未設定"
                let plan = memo.planAt?.formatted(date: .numeric, time: .shortened) ?? "未設定"
                let reminders = memo.reminderRules.filter(\.enabled).prefix(5).map {
                    "\($0.kind.rawValue) \($0.triggerAt.formatted(date: .numeric, time: .shortened)) \($0.repeatType.rawValue)"
                }.joined(separator: "；")
                return "\(limited(memo.title, 100))｜\(memo.status.rawValue)｜類型 \(memo.tagType.rawValue)｜優先級 \(memo.priority.rawValue)｜截止 \(due)｜計劃 \(plan)｜提醒 \(reminders)｜課程 \(limited(memo.courseLink == nil ? "未連結" : (memo.courseLink.flatMap { names[$0] } ?? "未提供"), 80))｜\(limited(memo.content, 500))"
            }
            sections.append("備忘錄與作業（\(memos.count) 筆；最多 50 筆）:\n" + (rows.isEmpty ? "無可用資料" : rows.joined(separator: "\n")))
        }
        if kinds.contains("announcements") {
            let rows = orders.sorted { $0.date > $1.date }.prefix(30).map { "\(limited($0.message))｜\(limited($0.time, 50))｜\(limited($0.favoriteSource, 20))" }
            sections.append("校園公告及活動（快取 \(orders.count) 筆；最多 30 筆）:\n" + (rows.isEmpty ? "無可用資料" : rows.joined(separator: "\n")))
        }
        if kinds.contains("bikes") {
            let rows = bikes.prefix(40).map { "\(limited($0.displayName, 80))｜可借 \($0.sbi_quantity)｜可還 \($0.bemp)" }
            let time = bikeUpdated?.formatted(date: .numeric, time: .shortened) ?? "尚未更新"
            sections.append("YouBike（更新：\(time)；最多 40 站）:\n" + (rows.isEmpty ? "無可用資料，請先開啟站點頁更新" : rows.joined(separator: "\n")))
        }
        return sections.joined(separator: "\n\n")
    }
}
