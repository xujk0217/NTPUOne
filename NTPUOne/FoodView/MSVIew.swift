//
//  MSVIew.swift
//  NTPUOne
//
//  Created by 許君愷 on 2024/6/27.
//

import SwiftUI

struct MSView: View {
    @ObservedObject var fManager = FManager()
    
    var body: some View {
        if let Food = fManager.Food {
            NavigationStack {
                List {
                    Section {
                        ForEach(fManager.Food!) { store in
                            if #available(iOS 17.0, *) {
                                StoreNavigationLink(store: store, collectionName: K.FStoreF.collectionNamem)
                            } else {
                                StoreNavigationLinkLegacy(store: store, collectionName: K.FStoreF.collectionNamem)
                            }
                        }
                    } header: {
                        Text("\(Image(systemName: "star.fill")) 是人氣數")
                            .foregroundStyle(Color.black)
                    }
                    // 廣告標記
                    Section {
                        BannerAdView()
                                .frame(height: 50) // 橫幅廣告的高度通常是 50
                    } header: {
                        Text("廣告")
                    }
                }
                .scrollContentBackground(.hidden)
//                .background(.linearGradient(colors: [.white, .cyan], startPoint: .bottomLeading, endPoint: .topTrailing))
                .background(Color.gray.opacity(0.1))
                .navigationTitle("Midnight Snack")
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        NavigationLink {
                            AddStoreView(currCollectName: K.FStoreF.collectionNamem)
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(Color.blue)
                        }
                    }
                }
                .onAppear {
                    fManager.loadF(whichDiet: "M")
                }
            }
        } else {
            Text("Loading...")
                .onAppear {
                    fManager.loadF(whichDiet: "M")
                }
            ProgressView()
        }
    }
}


#Preview {
    MSView()
}
