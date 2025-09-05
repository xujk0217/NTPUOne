//
//  FeaturesAdminView.swift
//  NTPUOne
//
//  Created by 許君愷 on 2025/9/6.
//


import SwiftUI

struct FeaturesAdminView: View {
    @StateObject private var mgr = FeatureManager()
    @AppStorage("isAdmin") private var isAdmin: Bool = false

    @State private var query = ""
    @State private var confirmDelete: FeatureRequest?

    var filtered: [FeatureRequest] {
        guard !query.isEmpty else { return mgr.items }
        let q = query.lowercased()
        return mgr.items.filter { x in
            x.issue.lowercased().contains(q) ||
            x.detail.lowercased().contains(q) ||
            x.email.lowercased().contains(q) ||
            (x.id ?? "").lowercased().contains(q)
        }
    }

    var body: some View {
        List {
            ForEach(filtered) { item in
                FeatureRow(item: item, isAdmin: isAdmin) {
                    confirmDelete = item
                }
                .contextMenu {           // ⬅️ 長按彈出
                    if isAdmin {
                        Button("刪除", role: .destructive) {
                            confirmDelete = item
                        }
                    }
                }
            }
        }
        .navigationTitle("功能回報管理")
        .searchable(text: $query, prompt: "搜尋名稱 / 內容 / email / id")
        .onAppear { mgr.load() }
        .alert("確定要刪除嗎？", isPresented: .init(
            get: { confirmDelete != nil },
            set: { if !$0 { confirmDelete = nil } }
        )) {
            Button("取消", role: .cancel) { confirmDelete = nil }
            Button("刪除", role: .destructive) {
                if let id = confirmDelete?.id { mgr.delete(id: id) }
                confirmDelete = nil
            }
        } message: {
            Text(confirmDelete?.issue ?? "")
        }
    }

    private struct FeatureRow: View {
        let item: FeatureRequest
        let isAdmin: Bool
        let onDelete: () -> Void

        var dateText: String {
            guard let t = item.date else { return "" }
            let d = Date(timeIntervalSince1970: t)
            let fmt = DateFormatter()
            fmt.dateFormat = "yyyy/MM/dd HH:mm"
            return fmt.string(from: d)
        }

        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                Text(item.issue).font(.headline)

                Text(item.detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)

                HStack(spacing: 8) {
                    if !item.email.isEmpty, let mail = URL(string: "mailto:\(item.email)") {
                        Link(item.email, destination: mail)
                    }
                    Spacer()
                    if !dateText.isEmpty {
                        Text(dateText).font(.caption).foregroundStyle(.secondary)
                    }
                }

                if let id = item.id {
                    Text("id: \(id)")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
    }
}
