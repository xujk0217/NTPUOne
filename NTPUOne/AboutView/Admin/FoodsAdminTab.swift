//
//  FoodsAdminTab.swift
//  NTPUOne
//
//  Created by 許君愷 on 2025/9/6.
//
import FirebaseFirestore
import SwiftUI

struct FoodsAdminTab: View {
    // 先宣告 enum，再使用
    enum Diet: String, CaseIterable, Identifiable {
        case B, L, D, M
        var id: String { rawValue }
        var title: String {
            switch self {
            case .B: return "早餐"
            case .L: return "午餐"
            case .D: return "晚餐"
            case .M: return "宵夜"
            }
        }
    }

    @StateObject private var f = FManager()
    @AppStorage("isAdmin") private var isAdmin: Bool = false

    @State private var diet: Diet = .B // Breakfast 預設
    @State private var search = ""
    @State private var editing: FDetail?
    @State private var showEdit = false
    @State private var confirmDelete: FDetail? = nil   // 刪除二次確認

    // 搜尋過濾
    var filtered: [FDetail] {
        let src = f.Food ?? []
        guard !search.isEmpty else { return src }
        return src.filter { x in
            x.store.localizedCaseInsensitiveContains(search) ||
            x.address.localizedCaseInsensitiveContains(search) ||
            x.time.localizedCaseInsensitiveContains(search)
        }
    }

    var body: some View {
        VStack {
            Picker("餐別", selection: $diet) {
                ForEach(Diet.allCases) { d in
                    Text(d.title).tag(d)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .onChange(of: diet) { newVal in
                f.loadF(whichDiet: newVal.rawValue)
            }

            List {
                ForEach(filtered) { item in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(item.store).font(.headline)
                            ApproveBadge(approved: item.check)
                            Spacer()
                            Text(String(format: "⭐️ %.1f", item.starNum))
                                .font(.subheadline)
                                .monospacedDigit()
                        }
                        Text(item.address)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        HStack{
                            Text("時間：")
                            Text(item.time)
                        }
                            .font(.footnote)
                        if !item.url.isEmpty {
                            Text(item.url).foregroundStyle(.blue)
                                .font(.footnote)
                        }

                        if isAdmin {
                            HStack(spacing: 10) {

                                Spacer()

                                Button("編輯") {
                                    editing = item
                                }
                                .buttonStyle(.bordered)

                            }
                            .font(.caption)
                        }
                    }
                    .contentShape(Rectangle())
                }
            }
            .listStyle(.insetGrouped)
        }
        .navigationTitle("餐廳管理")
        .searchable(text: $search, prompt: "搜尋店名 / 地址 / 營業時間")
        .onAppear { f.loadF(whichDiet: diet.rawValue) }
        .sheet(item: $editing) { detail in
            EditFoodSheet(fManager: f, diet: diet.rawValue, detail: detail)
                .presentationDetents([.medium, .large])
        }
    }
}

struct EditFoodSheet: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var fManager: FManager
    let diet: String

    @State var store: String
    @State var time: String
    @State var url: String
    @State var address: String
    @State var phone: String
    @State var starText: String   // 無上限，字串綁定
    @State var lat: String
    @State var lng: String
    @State var check: Bool
    let id: String

    @State private var showDeleteConfirm = false

    init(fManager: FManager, diet: String, detail: FDetail) {
        self.fManager = fManager
        self.diet = diet
        _store = State(initialValue: detail.store)
        _time = State(initialValue: detail.time)
        _url = State(initialValue: detail.url)
        _address = State(initialValue: detail.address)
        _phone = State(initialValue: detail.phone)
        _starText = State(initialValue: String(format: "%.1f", detail.starNum))
        _lat = State(initialValue: String(detail.lat))
        _lng = State(initialValue: String(detail.lng))
        _check = State(initialValue: detail.check)
        self.id = detail.id ?? ""
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("基本") {
                    TextField("店名", text: $store)
                    TextField("營業時間", text: $time)
                    TextField("網址", text: $url)
                    TextField("地址", text: $address)
                    TextField("電話", text: $phone)
                }
                Section("座標 / 星數") {
                    TextField("緯度", text: $lat).keyboardType(.decimalPad)
                    TextField("經度", text: $lng).keyboardType(.decimalPad)

                    HStack {
                        TextField("星數（可輸入任意數值）", text: $starText)
                            .keyboardType(.decimalPad)
                        Button {
                            let current = Double(starText) ?? 0
                            starText = String(format: "%.1f", current + 1)
                        } label: { Image(systemName: "plus.circle") }
                        Button {
                            let current = Double(starText) ?? 0
                            let next = max(0, current - 1)
                            starText = String(format: "%.1f", next)
                        } label: { Image(systemName: "minus.circle") }
                    }

                    Toggle("已審核", isOn: $check)
                }

                // 也可把刪除放在表單底部一區（可選）
                Section {
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Text("刪除這間餐廳")
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
            }
            .navigationTitle("編輯餐廳")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("儲存") {
                        guard let latD = Double(lat),
                              let lngD = Double(lng) else { return }

                        let star = max(0, Double(starText) ?? 0)

                        let fields: [String: Any] = [
                            "store": store,
                            "time": time,
                            "url": url,
                            "address": address,
                            "phone": phone,
                            "starNum": star,
                            "lat": latD,
                            "lng": lngD,
                            "check": check
                        ]
                        fManager.updateFoodFields(diet: diet, id: id, fields: fields)
                        dismiss()
                    }
                }
            }
            // 刪除二次確認
            .alert("確定要刪除嗎？", isPresented: $showDeleteConfirm) {
                Button("取消", role: .cancel) { }
                Button("刪除", role: .destructive) {
                    fManager.deleteFood(diet: diet, id: id)
                    dismiss()
                }
            } message: {
                Text("刪除後無法復原。")
            }
        }
    }
}

private struct ApproveBadge: View {
    let approved: Bool
    var body: some View {
        Label(approved ? "已審核" : "未審核",
              systemImage: approved ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(approved ? Color.green.opacity(0.15) : Color.orange.opacity(0.15))
            .foregroundStyle(approved ? Color.green : Color.orange)
            .clipShape(Capsule())
    }
}
