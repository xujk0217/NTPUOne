//
//  MSVIew.swift
//  NTPUOne
//
//  Created by 許君愷 on 2024/6/27.
//

import SwiftUI
import MapKit

struct MSView: View {
    @StateObject var fManager = FManager()
    @EnvironmentObject var adFree: AdFreeService
    // adview
    @State private var adHeight: CGFloat = 100
    @State private var rowWidth: CGFloat = 0
    
    var body: some View {
        if let Food = fManager.Food {
            NavigationStack {
                List {
                    // 地圖 Section
                    if #available(iOS 17.0, *) {
                        let pins = Food.filter { $0.lat != 0 && $0.lng != 0 }
                        if !pins.isEmpty {
                            Section("附近餐廣地圖") {
                                Map(initialPosition: .camera(
                                    MapCamera(
                                        centerCoordinate: CLLocationCoordinate2D(latitude: 24.9424, longitude: 121.3682),
                                        distance: 2500
                                    )
                                )) {
                                    ForEach(pins) { item in
                                        Marker(item.store, coordinate: CLLocationCoordinate2D(latitude: item.lat, longitude: item.lng))
                                    }
                                }
                                .frame(height: 200)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            }
                        }
                    }
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
                    fManager.loadF(whichDiet: "M")
                }
            ProgressView()
        }
    }
}


#Preview {
    MSView()
}
