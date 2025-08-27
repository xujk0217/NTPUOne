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
    @State private var name: String = ""
    @State private var message: String = ""
    @State private var email: String = ""
    @State private var time: String = ""
    @State private var url: String = ""

    @ObservedObject var rewardAd: RewardedAd
    @EnvironmentObject var adFree: AdFreeService

    enum Tags: String, CaseIterable, Identifiable {
        case 社團, 活動, 其他
        var id: Self { self }
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
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
                    Section("公告內容＊") {
                        TextEditor(text: $message)
                            .frame(minHeight: 120)
                            .overlay {
                                if message.isEmpty {
                                    VStack{
                                        Text("輸入公告事項")
                                            .foregroundStyle(.secondary)
                                            .padding(.top, 8)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        Spacer()
                                    }
                                }
                            }
                        HStack {
                            Text("注意長度與重點")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(message.count) 字")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Section("相關資訊") {
                        TextField("相關網址（選填）", text: $url)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }

                    Section("分類") {
                        Picker("選擇標籤", selection: $tag) {
                            ForEach(Tags.allCases) { t in
                                Text(t.rawValue).tag(t)
                            }
                        }
                        .pickerStyle(.segmented)

                        Text("若標籤與內容不符，可能會被移除。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Section {
                        TextField("你的名字＊", text: $name)
                            .textInputAutocapitalization(.words)

                        TextField("你的信箱（選填）", text: $email)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()

                        TextField("展示時間（例如：至 10/15 或一週）", text: $time)
                            .textInputAutocapitalization(.never)
                    } header: {
                        Text("聯絡資訊")
                    } footer: {
                        if !isFormValid {
                            Text("「公告內容」與「你的名字」為必填。")
                        }
                        if firebaseFail {
                            Text("送出失敗，請稍後再試或確認網路連線。")
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
                                Text("送出")
                                    .font(.headline)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!isFormValid || isSubmitting)

                        NavigationLink {
                            ContactMeView()
                        } label: {
                            Label("聯絡我～", systemImage: "message")
                                .bold()
                        }
                    }
                    .listRowBackground(Color.clear)
                }
            }
            .navigationTitle("新增公告")
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完成") {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                                        to: nil, from: nil, for: nil)
                    }
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
            K.FStoreOr.nameField: name.trimmingCharacters(in: .whitespacesAndNewlines),
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
            // 清空表單並關閉
            message = ""; name = ""; url = ""; email = ""; time = ""
            isSuccessSend = true
            dismiss()
        }
    }
}
