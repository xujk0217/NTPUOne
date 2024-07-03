//
//  AboutMeView.swift
//  NTPUOne
//
//  Created by 許君愷 on 2024/6/26.
//

import SwiftUI

struct AboutMeView: View {
    var body: some View {
        NavigationStack {
            VStack {
                Text(/*@START_MENU_TOKEN@*/"Hello, World!"/*@END_MENU_TOKEN@*/)
                NavigationLink {
                    ContactMeView()
                } label: {
                    Text("hahaha")
                }

            }
        }
    }
}

#Preview {
    AboutMeView()
}
