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
                    Section(String(localized: "feature_name_required")) {
                        TextField(String(localized: "feature_name_placeholder"), text: $issue)
                            .textInputAutocapitalization(.sentences)
                            .autocorrectionDisabled(false)
                    }

                    Section(String(localized: "feature_detail_required")) {
                        // 你的 AutoSizingTF；高度限制 160，輸入多時可捲動
                        AutoSizingTF(
                            hint: String(localized: "feature_detail_placeholder"),
                            text: $detail,
                            containerHeight: $containHeight,
                            onEnd: { hideKeyboard() }
                        )
                        .frame(minHeight: 80, maxHeight: 160)
                    }

                    Section {
                        TextField(String(localized: "email_optional_placeholder"), text: $email)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    } header: {
                      Text(String(localized: "contact_method_optional"))
                    } footer: {
                        if !isFormValid {
                            Text(String(localized: "feature_form_required_hint"))
                        }
                        if firebaseFail {
                            Text(String(localized: "submit_failed_hint"))
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
                                Text(String(localized: "submit"))
                                    .font(.headline)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!isFormValid || isSubmitting)
                    }
                    .listRowBackground(Color.clear)
                }
            }
            .navigationTitle(String(localized: "feature_request_title"))
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(String(localized: "done")) { hideKeyboard() }
                }
            }
            .alert(String(localized: "upload_success"), isPresented: $isSuccessSend) {
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
