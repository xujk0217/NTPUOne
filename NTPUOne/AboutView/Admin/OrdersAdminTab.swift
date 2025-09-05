//
//  OrdersAdminTab.swift
//  NTPUOne
//
//  Created by 許君愷 on 2025/9/6.
//

import SwiftUI

import SwiftUI

struct OrdersAdminTab: View {
    @StateObject private var manager = OrderManager()
    @AppStorage("isAdmin") private var isAdmin: Bool = false

    @State private var searchText = ""
    @State private var selectedTag: TagFilter = .all
    @State private var editing: Order?                 // 用於 .sheet(item:)
    @State private var confirmDelete: Order? = nil     // 二次確認

    enum TagFilter: String, CaseIterable, Identifiable {
        case all = "全部"
        case event = "活動(1)"
        case post  = "貼文(2)"
        case other = "其他(3)"
        var id: String { rawValue }
        var tagValue: String? {
            switch self {
            case .all:   return nil
            case .event: return "1"
            case .post:  return "2"
            case .other: return "3"
            }
        }
    }

    // 篩選 + 搜尋
    var filtered: [Order] {
        var result = manager.order ?? []

        if let wantedTag = selectedTag.tagValue {
            result = result.filter { $0.tag == wantedTag }
        }

        if !searchText.isEmpty {
            let q = searchText.lowercased()
            result = result.filter {
                $0.message.lowercased().contains(q) ||
                $0.name.lowercased().contains(q) ||
                $0.url.lowercased().contains(q) ||
                $0.email.lowercased().contains(q) ||
                $0.time.lowercased().contains(q)
            }
        }
        return result
    }

    var body: some View {
        VStack {
            // 篩選列
            HStack {
                Picker("標籤", selection: $selectedTag) {
                    ForEach(TagFilter.allCases) { t in
                        Text(t.rawValue).tag(t)
                    }
                }
                .pickerStyle(.segmented)
            }
            .padding(.horizontal)

            // 列表（❗️改成用按鈕觸發）
            List {
                ForEach(filtered) { o in
                    OrderRow(
                        o: o,
                        isAdmin: isAdmin,
                        onEdit: { editing = o },
                        onDelete: { confirmDelete = o }
                    )
                }
            }
            .listStyle(.insetGrouped)
        }
        .navigationTitle("投稿管理")
        .searchable(text: $searchText, placement: .navigationBarDrawer, prompt: "搜尋訊息/名稱/URL")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Text("活動\(manager.eventN) 貼文\(manager.postN) 其他\(manager.otherN)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear { manager.loadOrder() }

        // 編輯（.sheet(item:) 不會第一次空白）
        .sheet(item: $editing) { o in
            EditOrderSheet(orderManager: manager, order: o)
                .presentationDetents([.medium, .large])
        }

        // 刪除二次確認
        .alert("確定要刪除嗎？", isPresented: .init(
            get: { confirmDelete != nil },
            set: { if !$0 { confirmDelete = nil } }
        )) {
            Button("取消", role: .cancel) { confirmDelete = nil }
            Button("刪除", role: .destructive) {
                if let id = confirmDelete?.id {
                    manager.deleteOrder(docID: id)
                }
                confirmDelete = nil
            }
        } message: {
            Text(confirmDelete?.message ?? "")
        }
    }
}

// 顯示完整欄位 + 行內「編輯 / 刪除」按鈕
private struct OrderRow: View {
    let o: Order
    let isAdmin: Bool
    let onEdit: () -> Void
    let onDelete: () -> Void

    private var dateText: String {
        let d = Date(timeIntervalSince1970: o.date)
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy/MM/dd HH:mm"
        return fmt.string(from: d)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // message
            HStack{
                Text(o.message)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
                Text("tag \(o.tag)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.thinMaterial, in: Capsule())
            }

            HStack{
                Text("作者：")
                Text(o.name)
            }
            .font(.subheadline)
            
            if !o.email.isEmpty{
                Text(o.email)
                    .foregroundStyle(Color.blue)
                    .font(.subheadline)
            }

            // url + time + date
            VStack(alignment: .leading, spacing: 8) {
                if !o.url.isEmpty, let link = URL(string: o.url) {
                    Text(o.url).foregroundStyle(.blue)
                } else if !o.url.isEmpty {
                    Text(o.url).foregroundStyle(.orange)
                }
                if !o.time.isEmpty {
                    HStack{
                        Text("建議結束時間：").font(.caption).foregroundStyle(.secondary)
                        Text(o.time).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Text(dateText).font(.caption).foregroundStyle(.secondary)
            }

            // ✅ 行內操作按鈕（和餐廳列表一致）
            if isAdmin {
                HStack(spacing: 12) {
                    Spacer()
                    Button("編輯", action: onEdit)
                        .buttonStyle(.bordered)
                }
                .font(.caption)
                .padding(.top, 2)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}



struct EditOrderSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var orderManager: OrderManager

    @State private var message: String
    @State private var name: String
    @State private var url: String
    @State private var tag: String
    @State private var time: String
    @State private var email: String
    private let orderID: String
    private let createdAt: Double

    @State private var showDeleteConfirm = false

    init(orderManager: OrderManager, order: Order) {
        self.orderManager = orderManager
        _message = State(initialValue: order.message)
        _name    = State(initialValue: order.name)
        _url     = State(initialValue: order.url)
        _tag     = State(initialValue: order.tag)
        _time    = State(initialValue: order.time)
        _email   = State(initialValue: order.email)
        self.orderID  = order.id ?? ""
        self.createdAt = order.date
    }

    var createdText: String {
        let d = Date(timeIntervalSince1970: createdAt)
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy/MM/dd HH:mm:ss"
        return fmt.string(from: d)
    }

    var body: some View {
        NavigationStack {
            Form {
                if !orderID.isEmpty {
                    Section("文件 ID / 建立時間") {
                        Text(orderID)
                            .font(.footnote.monospaced())
                            .lineLimit(1)
                            .truncationMode(.middle)
                        HStack {
                            Text("建立於")
                            Spacer()
                            Text(createdText).foregroundStyle(.secondary)
                        }
                    }
                }

                Section("內容") {
                    TextField("訊息", text: $message, axis: .vertical)
                        .lineLimit(3...6)
                    TextField("名稱", text: $name)
                }

                Section("聯絡與連結") {
                    TextField("Email", text: $email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                    TextField("URL", text: $url)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                    TextField("時間（自訂顯示字串）", text: $time)
                }

                Section("標籤") {
                    Picker("Tag", selection: $tag) {
                        Text("活動 (1)").tag("1")
                        Text("貼文 (2)").tag("2")
                        Text("其他 (3)").tag("3")
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Text("刪除這筆投稿")
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
            }
            .navigationTitle("編輯投稿")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("儲存") {
                        guard !orderID.isEmpty else { return }
                        orderManager.updateOrder(
                            docID: orderID,
                            message: message,
                            name: name,
                            url: url,
                            tag: tag,
                            time: time,
                            email: email
                        )
                        dismiss()
                    }
                }
            }
            .alert("確定要刪除嗎？", isPresented: $showDeleteConfirm) {
                Button("取消", role: .cancel) {}
                Button("刪除", role: .destructive) {
                    orderManager.deleteOrder(docID: orderID)
                    dismiss()
                }
            } message: {
                Text("刪除後無法復原。")
            }
        }
    }
}
