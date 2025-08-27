//
//  AddStoreView.swift
//  NTPUOne
//
//  Created by 許君愷 on 2024/7/3.
//

import SwiftUI
import FirebaseCore
import FirebaseFirestore
import FirebaseAuth
import AppTrackingTransparency
import CoreLocation

struct AddStoreView: View {
    let currCollectName: String?
    @EnvironmentObject var adFree: AdFreeService

    @State private var store = ""
    @State private var time = ""
    @State private var url = ""
    @State private var address = ""
    @State private var phone = ""

    @State private var isSuccessSend = false
    @State private var firebaseFail = false
    @State private var isSubmitting = false

    @Environment(\.dismiss) private var dismiss
    private let db = Firestore.firestore()

    // 預設座標（失敗時 fallback）
    private let fallbackLat: Double = 24.942406
    private let fallbackLng: Double = 121.368198

    // 驗證必填
    private var isFormValid: Bool {
        !store.trimmingCharacters(in: .whitespaces).isEmpty &&
        !url.trimmingCharacters(in: .whitespaces).isEmpty &&
        !time.trimmingCharacters(in: .whitespaces).isEmpty &&
        !address.trimmingCharacters(in: .whitespaces).isEmpty &&
        currCollectName?.isEmpty == false
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("商家名稱＊", text: $store)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()

                    TextField("Google Maps 網址＊", text: $url)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    TextField("營業時間（例：11:00–12:30）＊", text: $time)
                        .textInputAutocapitalization(.never)

                    TextField("電話（選填）", text: $phone)
                        .keyboardType(.phonePad)

                    TextField("地址＊", text: $address)
                } header:{
                    Text("基本資訊")
                }footer: {
                    if !isFormValid {
                        Text("帶有「＊」為必填欄位。")
                    }
                    if firebaseFail {
                        Text("送出失敗，請確認必填內容或稍後再試。")
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    Button(action: {
                        Task { await sendPressed() }
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
                }
                .listRowBackground(Color.clear)
            }
            .navigationTitle("新增店家")
            .alert("上傳成功", isPresented: $isSuccessSend) {
                Button("OK") { isSuccessSend = false }
            }
            // 廣告標記
            if !adFree.isAdFree {
                Section {
                    BannerAdView()
                        .frame(height: 50)
                }
            }
        }
    }

    // MARK: - Submit

    private func sendPressed() async {
        guard isFormValid, let collection = currCollectName else {
            firebaseFail = true
            return
        }
        isSubmitting = true
        firebaseFail = false

        // 1) 嘗試從 URL 取得座標；若失敗 → 預設
        let (latDou, lngDou) = await deriveLatLng(from: url) ?? (fallbackLat, fallbackLng)

        let data: [String: Any] = [
            K.FStoreF.storeField: store.trimmingCharacters(in: .whitespaces),
            K.FStoreF.urlField: url.trimmingCharacters(in: .whitespaces),
            K.FStoreF.openTimeField: time.trimmingCharacters(in: .whitespaces),
            K.FStoreF.addressField: address.trimmingCharacters(in: .whitespaces),
            K.FStoreF.phoneField: phone.trimmingCharacters(in: .whitespaces),
            K.FStoreF.starField: 1,  // ⭐ 固定 1
            K.FStoreF.latField: latDou,
            K.FStoreF.lngField: lngDou,
            K.FStoreF.checkField: false
        ]

        do {
            _ = try await db.collection(collection).addDocument(data: data)
            clearForm()
            isSuccessSend = true
            dismiss()
        } catch {
            print("Firestore error: \(error)")
            firebaseFail = true
        }
        isSubmitting = false
    }

    private func clearForm() {
        store = ""; url = ""; time = ""; address = ""; phone = ""
    }

    // MARK: - URL → Lat/Lng pipeline

    /// 從輸入的 Google Maps 連結推得 (lat, lng)；支援短連結展開與地址地理編碼。
    private func deriveLatLng(from rawURL: String) async -> (Double, Double)? {
        guard !rawURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }

        // (a) 展開短連結（maps.app.goo.gl 等）
        let finalURL = await resolveMapsShortlink(rawURL) ?? URL(string: rawURL)

        // (b) 直接從 URL 解析座標
        if let finalURL, let pair = parseLatLng(from: finalURL) {
            return pair
        }

        // (c) 若 q= 是地址 → 地理編碼
        if let finalURL, let pair = await geocodeIfNeeded(from: finalURL) {
            return pair
        }

        return nil
    }
}

#Preview {
    AddStoreView(currCollectName: K.FStoreF.collectionNameB)
}

// MARK: - Helpers

/// 展開 Google 短連結，取得最終 URL
func resolveMapsShortlink(_ raw: String) async -> URL? {
    guard let u = URL(string: raw) else { return nil }
    do {
        // 會自動跟隨 3xx，最後的 response.url 即為展開後的網址
        let (_, resp) = try await URLSession.shared.data(from: u)
        return resp.url
    } catch {
        return nil
    }
}

/// 解析經緯度（支援 ?q=lat,lng 或 /@lat,lng,zoom）
func parseLatLng(from url: URL) -> (Double, Double)? {
    if let comps = URLComponents(url: url, resolvingAgainstBaseURL: false) {
        if let q = comps.queryItems?.first(where: { $0.name.lowercased() == "q" })?.value {
            let parts = q.split(separator: ",").map { String($0) }
            if parts.count >= 2, let la = Double(parts[0]), let lo = Double(parts[1]) {
                return (la, lo) // q=25.0330,121.5654
            }
        }
        if let path = comps.path.removingPercentEncoding,
           let at = path.range(of: "/@") {
            let tail = path[at.upperBound...].split(separator: ",")
            if tail.count >= 2, let la = Double(tail[0]), let lo = Double(tail[1]) {
                return (la, lo) // /@25.0330,121.5654,17z
            }
        }
    }
    return nil
}

/// 從 ?q=地址 做地理編碼 → 經緯度
func geocodeIfNeeded(from url: URL) async -> (Double, Double)? {
    guard let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
          let q = comps.queryItems?.first(where: { $0.name.lowercased() == "q" })?.value
    else { return nil }

    // 如果 q 是 "lat,lng" 就不用編碼
    let parts = q.split(separator: ",")
    if parts.count >= 2, Double(parts[0]) != nil, Double(parts[1]) != nil {
        return nil
    }

    return await withCheckedContinuation { cont in
        CLGeocoder().geocodeAddressString(q) { placemarks, _ in
            if let c = placemarks?.first?.location?.coordinate {
                cont.resume(returning: (c.latitude, c.longitude))
            } else {
                cont.resume(returning: nil)
            }
        }
    }
}
