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
                            Section(String(localized: "nearby_restaurant_map")) {
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
                        ForEach(Array(fManager.Food!.enumerated()), id: \.element.id) { index, store in
                            if #available(iOS 17.0, *) {
                                StoreNavigationLink(store: store, collectionName: K.FStoreF.collectionNamem)
                            } else {
                                StoreNavigationLinkLegacy(store: store, collectionName: K.FStoreF.collectionNamem)
                            }
                            
                            // 每 5 個餐廳後插入 Native 廣告
                            if !adFree.isAdFree && (index + 1) % 5 == 0 && index < fManager.Food!.count - 1 {
                                NativeAdSectionView(style: .compact)
                                    .frame(height: 140)
                                    .listRowInsets(.init(top: 8, leading: 0, bottom: 8, trailing: 0))
                            }
                        }
                    } header: {
                        Text("\(Image(systemName: "star.fill")) 是人氣數")
                    }
                    // 底部 Native 廣告 Section
                    if !adFree.isAdFree {
                        Section {
                            NativeAdSectionView(style: .compact)
                                .frame(height: 140)
                        }
                        .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
                    }
                }
                .scrollContentBackground(.hidden)
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
