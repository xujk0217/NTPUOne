//
//  ContentView.swift
//  NTPUOne
//
//  Created by 許君愷 on 2024/6/24.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    
    @ObservedObject var webManager = WebManager()
    
    var body: some View {
        NavigationView{
            List(webManager.webDatas, rowContent: { web in
                NavigationLink(destination: WebDetailView(url: web.url)) {
                    HStack {
                        //Text(String(wel.))
                        Text(web.title)
                    }
                }
            })
            .navigationTitle("NTPU links")
        }
        .onAppear(perform: {
            webManager.createData()
        })
    }
}

#Preview {
    ContentView()
}
