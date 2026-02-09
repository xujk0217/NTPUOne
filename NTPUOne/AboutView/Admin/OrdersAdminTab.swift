//
//  OrdersAdminTab.swift
//  NTPUOne
//
//  Created by 許君愷 on 2025/9/6.
//

import SwiftUI

/// 用於預覽輪播的統一項目
struct PreviewOrderItem: Identifiable {
    let id = UUID()
    let message: String
    let name: String
    let tag: String
    let url: String
    let email: String
    let time: String
    let isPending: Bool
}

struct OrdersAdminTab: View {
    @StateObject private var manager = OrderManager()
    @StateObject private var crawlerService = NTPUCrawlerService()
    @AppStorage("isAdmin") private var isAdmin: Bool = false

    @State private var searchText = ""
    @State private var selectedTag: TagFilter = .all
    @State private var editing: Order?                 // 用於 .sheet(item:)
    @State private var confirmDelete: Order? = nil     // 二次確認
    @State private var showCrawlerSheet = false        // 爬蟲頁面
    
    // 輪播預覽
    @State private var previewIndex = 0
    @State private var isDragging = false
    private let timer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()

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

    /// 合併已上傳 Order 和備取 Order 用於預覽
    var allOrdersForPreview: [PreviewOrderItem] {
        var items: [PreviewOrderItem] = []
        
        // 已上傳的 Order
        if let orders = manager.order {
            for order in orders {
                items.append(PreviewOrderItem(
                    message: order.message,
                    name: order.name,
                    tag: order.tag,
                    url: order.url,
                    email: order.email,
                    time: order.time,
                    isPending: false
                ))
            }
        }
        
        // 備取 Order
        for pending in crawlerService.pendingOrders {
            items.append(PreviewOrderItem(
                message: pending.message,
                name: pending.name,
                tag: pending.tag,
                url: pending.url,
                email: pending.email,
                time: pending.time,
                isPending: true
            ))
        }
        
        return items
    }

    var body: some View {
        VStack(spacing: 0) {
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
            .padding(.top, 8)

            // 列表
            List {
                // 預覽輪播區（放在 List 的 Section 裡面，和主頁面結構一樣）
                if !allOrdersForPreview.isEmpty {
                    Section {
                        TabView(selection: $previewIndex) {
                            ForEach(Array(allOrdersForPreview.enumerated()), id: \.offset) { index, item in
                                ZStack(alignment: .topTrailing) {
                                    AnnouncementCard(
                                        message: item.message,
                                        author: "— \(item.name)",
                                        tag: item.tag,
                                        urlString: item.url,
                                        email: item.email,
                                        time: item.time
                                    ) {
                                        // Admin 頁面不做跳轉
                                    }
                                    .frame(maxWidth: .infinity, minHeight: 140)
                                    .padding(.horizontal, 8)
                                    
                                    // 備取標記
                                    if item.isPending {
                                        Text("備取")
                                            .font(.caption2.weight(.bold))
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(.orange, in: Capsule())
                                            .foregroundStyle(.white)
                                            .padding(16)
                                    }
                                }
                                .tag(index)
                            }
                        }
                        .tabViewStyle(.page(indexDisplayMode: .automatic))
                        .frame(height: 160)
                        .simultaneousGesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { _ in isDragging = true }
                                .onEnded { _ in isDragging = false }
                        )
                        .onReceive(timer) { _ in
                            guard !isDragging else { return }
                            let count = allOrdersForPreview.count
                            if count > 1 {
                                withAnimation {
                                    previewIndex = (previewIndex + 1) % count
                                }
                            }
                        }
                    } header: {
                        HStack {
                            Text("預覽播放")
                            Spacer()
                            Text("\(allOrdersForPreview.count) 則公告")
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                
                // Order 列表
                Section("投稿列表") {
                    ForEach(filtered) { o in
                        OrderRow(
                            o: o,
                            isAdmin: isAdmin,
                            onEdit: { editing = o },
                            onDelete: { confirmDelete = o }
                        )
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
        .navigationTitle("投稿管理")
        .searchable(text: $searchText, placement: .navigationBarDrawer, prompt: "搜尋訊息/名稱/URL")
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    showCrawlerSheet = true
                } label: {
                    Label("爬蟲", systemImage: "arrow.triangle.2.circlepath")
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Text("活動\(manager.eventN) 貼文\(manager.postN) 其他\(manager.otherN)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear { manager.loadOrder() }
        
        // 爬蟲頁面
        .sheet(isPresented: $showCrawlerSheet) {
            CrawlerSheet(crawlerService: crawlerService, orderManager: manager)
        }

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

// MARK: - 爬蟲管理頁面
struct CrawlerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var crawlerService: NTPUCrawlerService
    @ObservedObject var orderManager: OrderManager
    
    @State private var uploadingId: UUID?
    @State private var showUploadSuccess = false
    @State private var showUploadAll = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 狀態欄
                if let lastDate = crawlerService.lastCrawledDate {
                    HStack {
                        Image(systemName: "clock")
                        Text("上次爬取：\(formatDate(lastDate))")
                        Spacer()
                        Text("\(crawlerService.pendingOrders.count) 筆待審核")
                            .foregroundStyle(.orange)
                    }
                    .font(.caption)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color(.secondarySystemBackground))
                }
                
                if crawlerService.isLoading {
                    Spacer()
                    ProgressView("正在爬取 NTPU 網站...")
                    Spacer()
                } else if let error = crawlerService.errorMessage {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundStyle(.orange)
                        Text(error)
                            .foregroundStyle(.secondary)
                        Button("重試") {
                            Task { await crawlerService.crawlBanners() }
                        }
                        .buttonStyle(.bordered)
                    }
                    Spacer()
                } else if crawlerService.pendingOrders.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "tray")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("沒有待審核的項目")
                            .foregroundStyle(.secondary)
                        Text("點擊「刷新」從北大網站抓取輪播圖")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                } else {
                    List {
                        ForEach(crawlerService.pendingOrders) { pending in
                            PendingOrderRow(
                                pending: pending,
                                isUploading: uploadingId == pending.id,
                                onApprove: {
                                    uploadPendingOrder(pending)
                                },
                                onReject: {
                                    crawlerService.removePendingOrder(pending)
                                }
                            )
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("輪播圖爬蟲")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("關閉") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    HStack(spacing: 12) {
                        if !crawlerService.pendingOrders.isEmpty {
                            Button {
                                showUploadAll = true
                            } label: {
                                Label("全部上傳", systemImage: "arrow.up.circle.fill")
                            }
                        }
                        Button {
                            Task { await crawlerService.crawlBanners() }
                        } label: {
                            Label("刷新", systemImage: "arrow.triangle.2.circlepath")
                        }
                        .disabled(crawlerService.isLoading)
                    }
                }
            }
            .alert("上傳成功", isPresented: $showUploadSuccess) {
                Button("確定", role: .cancel) {}
            }
            .alert("確定要全部上傳嗎？", isPresented: $showUploadAll) {
                Button("取消", role: .cancel) {}
                Button("全部上傳") {
                    uploadAllPendingOrders()
                }
            } message: {
                Text("將上傳 \(crawlerService.pendingOrders.count) 筆資料到 Firebase")
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm"
        return formatter.string(from: date)
    }
    
    private func uploadPendingOrder(_ pending: PendingOrder) {
        uploadingId = pending.id
        orderManager.uploadOrder(
            message: pending.message,
            name: pending.name,
            url: pending.url,
            tag: pending.tag,
            time: pending.time,
            email: pending.email
        ) { success in
            uploadingId = nil
            if success {
                crawlerService.removePendingOrder(pending)
                showUploadSuccess = true
            }
        }
    }
    
    private func uploadAllPendingOrders() {
        let orders = crawlerService.pendingOrders
        for pending in orders {
            orderManager.uploadOrder(
                message: pending.message,
                name: pending.name,
                url: pending.url,
                tag: pending.tag,
                time: pending.time,
                email: pending.email
            ) { success in
                if success {
                    crawlerService.removePendingOrder(pending)
                }
            }
        }
    }
}

// MARK: - 備取 Order 列表項
private struct PendingOrderRow: View {
    let pending: PendingOrder
    let isUploading: Bool
    let onApprove: () -> Void
    let onReject: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 圖片預覽
            if pending.isImageOrder {
                AsyncImage(url: URL(string: pending.message)) { phase in
                    switch phase {
                    case .empty:
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.systemGray5))
                            .frame(height: 120)
                            .overlay(ProgressView())
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 120)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    case .failure:
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.systemGray5))
                            .frame(height: 120)
                            .overlay {
                                Image(systemName: "photo")
                                    .foregroundStyle(.secondary)
                            }
                    @unknown default:
                        EmptyView()
                    }
                }
            }
            
            // 標題
            Text(pending.altText.isEmpty ? "（無標題）" : pending.altText)
                .font(.headline)
                .lineLimit(2)
            
            // 連結
            if let url = URL(string: pending.url), let host = url.host {
                Label(host, systemImage: "link")
                    .font(.caption)
                    .foregroundStyle(.blue)
            }
            
            // 操作按鈕
            HStack(spacing: 12) {
                Spacer()
                
                Button(role: .destructive) {
                    onReject()
                } label: {
                    Label("忽略", systemImage: "xmark")
                }
                .buttonStyle(.bordered)
                .disabled(isUploading)
                
                Button {
                    onApprove()
                } label: {
                    if isUploading {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label("上傳", systemImage: "arrow.up.circle")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isUploading)
            }
        }
        .padding(.vertical, 8)
    }
}
