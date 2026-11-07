//
//  ReportBugView.swift
//  NTPUOne
//
//  Created by 許君愷 on 2024/6/27.
//

import SwiftUI
import FirebaseFirestore

struct ReportBugView: View {
    @State private var email: String = ""
    @State private var issue: String = ""
    @State private var detail: String = ""
    private enum Category: String {
        case problem = "問題回報"
        case suggestion = "功能建議"
    }
    private let category: Category

    init(suggestFeature: Bool = false) {
        category = suggestFeature ? .suggestion : .problem
    }

    @State private var isSuccessSend = false
    @State private var firebaseFail = false
    @State private var isSubmitting = false

    @EnvironmentObject private var adFree: AdFreeService
    @Environment(\.dismiss) private var dismiss

    private let db = Firestore.firestore()

    // 必填驗證：標題＋詳情
    private var isFormValid: Bool {
        !issue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !detail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        Form {
            Section {
                TextField("標題", text: $issue)
                TextField(category == .problem ? "在哪個畫面發生？如何重現？" : "你想完成什麼？希望怎麼操作？",
                          text: $detail, axis: .vertical)
                    .lineLimit(5...10)
            } header: {
                Text("內容")
            } footer: {
                Text("標題與內容為必填。請避免填入密碼或學號。")
            }

            Section {
                TextField("電子郵件（選填）", text: $email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            } header: {
                Text("聯絡方式")
            }

            if !adFree.isAdFree {
                BannerAdView().frame(height: 50)
                    .listRowBackground(Color.clear)
            }

            if firebaseFail {
                Section {
                    Label("送出失敗，內容已保留。請再試一次。", systemImage: "exclamationmark.circle")
                        .foregroundStyle(.red)
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(category.rawValue)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                if isSubmitting {
                    ProgressView().accessibilityLabel("正在送出")
                } else {
                    Button("送出", action: sendPressed)
                        .disabled(!isFormValid)
                }
            }
        }
        .alert("已送出回饋", isPresented: $isSuccessSend) {
            Button("完成") { dismiss() }
        }
    }

    // MARK: - Actions

    private func sendPressed() {
        guard isFormValid else {
            firebaseFail = true
            return
        }
        isSubmitting = true
        firebaseFail = false

        let data: [String: Any] = [
            K.FStoreR.issueField: issue.trimmingCharacters(in: .whitespacesAndNewlines),
            K.FStoreR.detailField: detail.trimmingCharacters(in: .whitespacesAndNewlines),
            K.FStoreR.emailField: email.trimmingCharacters(in: .whitespacesAndNewlines),
        ]

        let collection = category == .suggestion ? K.FStoreR.collectionNameFt : K.FStoreR.collectionNameBug
        db.collection(collection).addDocument(data: data) { error in
            isSubmitting = false
            if error != nil {
                firebaseFail = true
                return
            }
            issue = ""; detail = ""; email = ""
            isSuccessSend = true
        }
    }

}

#Preview {
    NavigationStack { ReportBugView() }
        .environmentObject(AdFreeService())

}
