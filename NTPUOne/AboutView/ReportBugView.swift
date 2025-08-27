//
//  ReportBugView.swift
//  NTPUOne
//
//  Created by 許君愷 on 2024/6/27.
//

import SwiftUI
import FirebaseCore
import FirebaseFirestore
import FirebaseAuth
import AppTrackingTransparency

struct ReportBugView: View {
    @State private var email: String = ""
    @State private var issue: String = ""
    @State private var detail: String = ""
    @State private var containHeight: CGFloat = 0

    @State private var isSuccessSend = false
    @State private var firebaseFail = false
    @State private var isSubmitting = false

    @EnvironmentObject var adFree: AdFreeService
    @Environment(\.dismiss) private var dismiss

    private let db = Firestore.firestore()

    // 必填驗證：標題＋詳情
    private var isFormValid: Bool {
        !issue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !detail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {

                Form {
                    Section("發現問題＊") {
                        TextField("例如：課表載入失敗、廣告高度錯誤…", text: $issue)
                            .textInputAutocapitalization(.sentences)
                            .autocorrectionDisabled(false)
                    }

                    Section("問題詳情＊") {
                        AutoSizingTF(
                            hint: "具體過程或如何重現（路徑、按鈕、錯誤訊息…）",
                            text: $detail,
                            containerHeight: $containHeight,
                            onEnd: { hideKeyboard() }
                        )
                        .frame(minHeight: 80, maxHeight: 160)
                    }

                    Section {
                        TextField("你的信箱（選填）", text: $email)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    } header: {
                      Text("聯絡方式（選填）")
                    } footer: {
                        if !isFormValid {
                            Text("「發現問題」與「問題詳情」為必填。")
                        }
                        if firebaseFail {
                            Text("送出失敗，請稍後再試或確認網路連線。")
                                .foregroundStyle(.red)
                        }
                    }

                    Section {
                        Button {
                            sendPressed()
                        } label: {
                            if isSubmitting {
                                ProgressView()
                            } else {
                                Text("送出")
                                    .font(.headline)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!isFormValid || isSubmitting)
                    }
                    .listRowBackground(Color.clear)
                }
            }
            .navigationTitle("回報問題")
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完成") { hideKeyboard() }
                }
            }
            .alert("上傳成功", isPresented: $isSuccessSend) {
                Button("OK") { isSuccessSend = false }
            }
            // 廣告標記
            if !adFree.isAdFree {
                Section {
                    BannerAdView()
                        .frame(height: 50)
                }
                .listRowBackground(Color.clear)
            }
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

        db.collection(K.FStoreR.collectionNameBug).addDocument(data: data) { error in
            isSubmitting = false
            if let e = error {
                print("Firestore error: \(e)")
                firebaseFail = true
                return
            }
            issue = ""; detail = ""; email = ""
            isSuccessSend = true
            dismiss()
        }
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                        to: nil, from: nil, for: nil)
    }
}

#Preview {
    ReportBugView()
        .environmentObject(AdFreeService())
}
