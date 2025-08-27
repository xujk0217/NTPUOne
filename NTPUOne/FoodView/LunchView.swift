//
//  LunchView.swift
//  NTPUOne
//
//  Created by 許君愷 on 2024/6/27.
//

import SwiftUI

struct LunchView: View {
    @StateObject var fManager = FManager()
    @EnvironmentObject var adFree: AdFreeService
    // adview
    @State private var adHeight: CGFloat = 100
    @State private var rowWidth: CGFloat = 0
    
    var body: some View {
        if let Food = fManager.Food {
            NavigationStack {
                List {
                    Section {
                        ForEach(fManager.Food!) { store in
                            if #available(iOS 17.0, *) {
                                StoreNavigationLink(store: store, collectionName: K.FStoreF.collectionNamel)
                            } else {
                                StoreNavigationLinkLegacy(store: store, collectionName: K.FStoreF.collectionNamel)
                            }
                        }
                    } header: {
                        Text("\(Image(systemName: "star.fill")) 是人氣數")
                            .foregroundStyle(Color.black)
                    }
//                    // 廣告標記
//                    Section {
//                        NativeAdBoxView(
//                            style: .compact(media: 120),
//                            height: $adHeight
//                        )
//                        .frame(height: adHeight)
//                        .listRowInsets(.init(top: 12, leading: 0, bottom: 12, trailing: 0))
//                        .listRowSeparator(.hidden)
//                        .listRowBackground(Color.white)
//                        .padding(.horizontal, 8)
//                    } header: {
//                        Text("廣告")
//                    }
                }
                .scrollContentBackground(.hidden)
//                .background(.linearGradient(colors: [.white, .cyan], startPoint: .bottomLeading, endPoint: .topTrailing))
                .background(Color.gray.opacity(0.1))
                .navigationTitle("Lunch")
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        NavigationLink {
                            AddStoreView(currCollectName: K.FStoreF.collectionNamel)
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(Color.blue)
                        }
                    }
                }
                .onAppear {
                    fManager.loadF(whichDiet: "L")
                }
                if !adFree.isAdFree{
                    // 廣告標記
                    Section {
                        BannerAdView()
                            .frame(height: 50)
                    }
                }
            }
        } else {
            Text("Loading...")
                .onAppear {
                    fManager.loadF(whichDiet: "L")
                }
            ProgressView()
        }
    }
}

@available(iOS 17.0, *)
struct StoreNavigationLink: View {
    var store: FDetail
    var collectionName: String

    var body: some View {
        NavigationLink(destination: dietView(store: store, currCollectName: collectionName)) {
            StoreRowView(store: store)
        }
    }
}

struct StoreNavigationLinkLegacy: View {
    var store: FDetail
    var collectionName: String

    var body: some View {
        NavigationLink(destination: noMapDietView(store: store, currCollectName: collectionName)) {
            StoreRowView(store: store)
        }
    }
}

struct StoreRowView: View {
    var store: FDetail

    var body: some View {
        HStack {
            HStack {
                Text("\(Int(store.starNum))")
                    .font(.title.bold())
                Image(systemName: "star.fill")
            }
            Divider()
            VStack(alignment: .leading) {
                HStack {
                    Text(store.store)
                        .font(.headline)
                    Spacer()
                }
                HStack(alignment: .top) {
                    Image(systemName: "house")
                    Text(": \(store.address)")
                    Spacer()
                }
                if !store.check {
                    Text("未確認資料完整性")
                        .foregroundStyle(Color.red)
                }
            }
        }
    }
}

#Preview {
    LunchView()
}
