//
//  AdminConsoleView.swift
//  NTPUOne
//
//  Created by 許君愷 on 2025/9/6.
//

import SwiftUI

struct AdminConsoleView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("資料管理") {
                    NavigationLink {
                        OrdersAdminTab()
                    } label: {
                        Label("投稿管理", systemImage: "tray.full")
                    }

                    NavigationLink {
                        FoodsAdminTab()
                    } label: {
                        Label("餐廳管理", systemImage: "fork.knife")
                    }
                    NavigationLink {
                        ReportBugAdminView()
                    } label: {
                        Label("問題回報管理", systemImage: "ladybug.fill")
                    }
                    NavigationLink {
                        FeaturesAdminView()
                    } label: {
                        Label("功能回報管理", systemImage: "sparkles")
                    }
                }
            }
            .navigationTitle("管理後台")
        }
    }
}
