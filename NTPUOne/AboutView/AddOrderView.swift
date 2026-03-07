//
//  AddOrderView.swift
//  NTPUOne
//
//  Created by 許君愷 on 2024/6/26.
//

import SwiftUI
import FirebaseCore
import FirebaseFirestore
import FirebaseAuth
import AppTrackingTransparency

struct AddOrderView: View {
    @AppStorage("commentNickname") private var nickname: String = ""
    @State private var message: String = ""
    @State private var email: String = ""
    @State private var time: String = ""
    @State private var url: String = ""

    @ObservedObject var rewardAd: RewardedAd
    @EnvironmentObject var adFree: AdFreeService

    enum Tags: String, CaseIterable, Identifiable {
        case 社團, 活動, 其他
        var id: Self { self }
        
        var displayName: String {
            switch self {
            case .社團: return String(localized: "tag_club")
            case .活動: return String(localized: "tag_event")
            case .其他: return String(localized: "tag_other")
            }
        }
    }
    @State private var tag: Tags = .其他

    @State private var isSuccessSend = false
    @State private var firebaseFail = false
    @State private var isSubmitting = false

    @Environment(\.dismiss) private var dismiss
    private let db = Firestore.firestore()

    // 驗證：訊息與姓名必填
    private var isFormValid: Bool {
        !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // 標籤轉存字串
    private var tagValue: String {
        switch tag {
        case .活動: return "1"
        case .社團: return "2"
        case .其他: return "3"
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Form {
                    Section(String(localized: "announcement_content_required")) {
                        TextEditor(text: $message)
                            .frame(minHeight: 120)
                            .overlay {
                                if message.isEmpty {
                                    VStack{
                                        Text(String(localized: "enter_announcement"))
                                            .foregroundStyle(.secondary)
                                            .padding(.top, 8)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        Spacer()
                                    }
                                }
                            }
                        HStack {
                            Text(String(localized: "note_length_focus"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(String(localized: "char_count \\(message.count)"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Section(String(localized: "related_info")) {
                        TextField(String(localized: "related_url_optional"), text: $url)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }

                    Section(String(localized: "category")) {
                        Picker(String(localized: "select_tag"), selection: $tag) {
                            ForEach(Tags.allCases) { t in
                                Text(t.displayName).tag(t)
                            }
                        }
                        .pickerStyle(.segmented)

                        Text(String(localized: "tag_mismatch_warning"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Section {
                        HStack {
                            Text(String(localized: "nickname"))
                            Spacer()
                            if nickname.isEmpty {
                                Text(String(localized: "set_in_about_page"))
                                    .foregroundStyle(.secondary)
                            } else {
                                Text(nickname)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        TextField(String(localized: "email_optional_placeholder"), text: $email)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()

                        TextField(String(localized: "display_time_placeholder"), text: $time)
                            .textInputAutocapitalization(.never)
                    } header: {
                        Text(String(localized: "contact_info"))
                    } footer: {
                        if !isFormValid {
                            Text(String(localized: "announcement_form_required_hint"))
                        }
                        if firebaseFail {
                            Text(String(localized: "submit_failed_hint"))
                                .foregroundStyle(.red)
                        }
                    }
                    
                    Section {
                        Button(action: {
                            sendPressed()
                        }) {
                            if isSubmitting {
                                ProgressView()
                            } else {
                                Text(String(localized: "submit"))
                                    .font(.headline)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!isFormValid || isSubmitting)

                        NavigationLink {
                            ContactMeView()
                        } label: {
                            Label(String(localized: "contact_me"), systemImage: "message")
                                .bold()
                        }
                    }
                    .listRowBackground(Color.clear)
                }
            }
            .navigationTitle(String(localized: "add_announcement_title"))
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(String(localized: "done")) {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                                        to: nil, from: nil, for: nil)
                    }
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

    // MARK: - Firestore
    private func sendPressed() {
        guard isFormValid else {
            firebaseFail = true
            return
        }
        isSubmitting = true
        firebaseFail = false

        let data: [String: Any] = [
            K.FStoreOr.messageField: message.trimmingCharacters(in: .whitespacesAndNewlines),
            K.FStoreOr.nameField: nickname.trimmingCharacters(in: .whitespacesAndNewlines),
            K.FStoreOr.timeField: time.trimmingCharacters(in: .whitespacesAndNewlines),
            K.FStoreOr.emailField: email.trimmingCharacters(in: .whitespacesAndNewlines),
            K.FStoreOr.urlField: url.trimmingCharacters(in: .whitespacesAndNewlines),
            K.FStoreOr.tagField: tagValue,
            K.FStoreOr.dateField: Date().timeIntervalSince1970
        ]

        db.collection(K.FStoreOr.collectionName).addDocument(data: data) { error in
            isSubmitting = false
            if let e = error {
                print("There was an issue saving data to Firestore, \(e)")
                firebaseFail = true
                return
            }
            // 清空表單並關閉（暱稱保留）
            message = ""; url = ""; email = ""; time = ""
            isSuccessSend = true
            dismiss()
        }
    }
}
