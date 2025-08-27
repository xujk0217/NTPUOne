//
//  FeaturesView.swift
//  NTPUOne
//
//  Created by 許君愷 on 2024/6/27.
//

import SwiftUI
import FirebaseCore
import FirebaseFirestore
import FirebaseAuth
import AppTrackingTransparency

struct FeaturesView: View {
    @State private var email: String = ""
    @State private var issue: String = ""
    @State private var detail: String = ""
    @State private var containHeight: CGFloat = 0

    @EnvironmentObject var adFree: AdFreeService
    @State private var isSuccessSend = false
    @State private var firebaseFail = false
    @State private var isSubmitting = false

    @Environment(\.dismiss) private var dismiss
    private let db = Firestore.firestore()

    // 驗證：名稱＋詳情必填
    private var isFormValid: Bool {
        !issue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !detail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Form {
                    Section("功能名稱＊") {
                        TextField("例如：課表分享、課程提醒…", text: $issue)
                            .textInputAutocapitalization(.sentences)
                            .autocorrectionDisabled(false)
                    }

                    Section("功能詳情＊") {
                        // 你的 AutoSizingTF；高度限制 160，輸入多時可捲動
                        AutoSizingTF(
                            hint: "具體如何表現（情境、按鈕位置、流程…）",
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
                            Text("「功能名稱」與「功能詳情」為必填。")
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
            .navigationTitle("功能回報")
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
            K.FStoreR.emailField: email.trimmingCharacters(in: .whitespacesAndNewlines)
        ]

        db.collection(K.FStoreR.collectionNameFt).addDocument(data: data) { error in
            isSubmitting = false
            if let e = error {
                print("Firestore error: \(e)")
                firebaseFail = true
                return
            }
            // 成功
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
    FeaturesView()
        .environmentObject(AdFreeService())
}
