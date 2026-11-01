//
//  LunchView.swift
//  NTPUOne
//
//  Created by 許君愷 on 2024/6/27.
//

import SwiftUI
import MapKit

struct LunchView: View {
    @StateObject var fManager = FManager()
    @EnvironmentObject var adFree: AdFreeService
    // adview
    @State private var adHeight: CGFloat = 100
    @State private var rowWidth: CGFloat = 0
    @State private var selectedFilter: FoodListFilter = .popular
    
    var body: some View {
        RemoteConfigFeatureGate(feature: .restaurant) {
        Group {
        if let Food = fManager.Food {
            let displayedFoods = FoodFiltering.filteredFoods(Food, filter: selectedFilter, userLocation: nil)
            NavigationStack {
                List {
                    FoodFilterControls(selectedFilter: $selectedFilter)
                    // 地圖 Section
                    if #available(iOS 17.0, *) {
                        // 篩選後為空（如營業中無店）時，地圖改顯示全部店家供參考
                        let pins = (displayedFoods.isEmpty ? Food : displayedFoods).filter { $0.lat != 0 && $0.lng != 0 }
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
                        if displayedFoods.isEmpty {
                            Label(
                                selectedFilter == .openNow
                                    ? String(localized: "food_filter_open_now_empty")
                                    : String(localized: "food_list_empty"),
                                systemImage: selectedFilter == .openNow ? "moon.zzz" : "tray"
                            )
                            .foregroundStyle(.secondary)
                        }
                        ForEach(Array(displayedFoods.enumerated()), id: \.element.id) { index, store in
                            if #available(iOS 17.0, *) {
                                StoreNavigationLink(store: store, collectionName: K.FStoreF.collectionNamel)
                            } else {
                                StoreNavigationLinkLegacy(store: store, collectionName: K.FStoreF.collectionNamel)
                            }
                            
                            // 每 5 個餐廳後插入 Native 廣告
                            if !adFree.isAdFree && (index + 1) % 5 == 0 && index < displayedFoods.count - 1 {
                                NativeAdSectionView(style: .compact)
                                    .frame(height: 140)
                                    .listRowInsets(.init(top: 8, leading: 0, bottom: 8, trailing: 0))
                            }
                        }
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
                .navigationTitle(String(localized: "lunch"))
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        NavigationLink {
                            AddStoreView(currCollectName: K.FStoreF.collectionNamel)
                        } label: {
                            Image(systemName: "plus.circle")
                                .foregroundStyle(Color.blue)
                        }
                    }
                }
            }
        } else {
            Text(String(localized: "loading"))
            ProgressView()
        }
        }
        .task { fManager.loadF(whichDiet: "L") }
        }
    }
}

struct FoodFilterControls: View {
    @Binding var selectedFilter: FoodListFilter

    var body: some View {
        Section {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(FoodListFilter.mealPageFilters) { filter in
                        Button {
                            selectedFilter = filter
                        } label: {
                            Text(filter.title)
                                .font(.subheadline.weight(.semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .foregroundStyle(selectedFilter == filter ? Color.white : Color.orange)
                                .background(
                                    Capsule()
                                        .fill(selectedFilter == filter ? Color.orange : Color.orange.opacity(0.12))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }
}

private extension FoodListFilter {
    static let mealPageFilters: [FoodListFilter] = [.popular, .openNow]
}

@available(iOS 17.0, *)
struct StoreNavigationLink: View {
    var store: FDetail
    var collectionName: String

    var body: some View {
        NavigationLink(destination: dietView(store: store, currCollectName: collectionName)) {
            StoreRowView(store: store)
        }
        .listRowBackground(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
                .padding(.horizontal, 4)
                .padding(.vertical, 3)
        )
    }
}

struct StoreNavigationLinkLegacy: View {
    var store: FDetail
    var collectionName: String

    var body: some View {
        NavigationLink(destination: noMapDietView(store: store, currCollectName: collectionName)) {
            StoreRowView(store: store)
        }
        .listRowBackground(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
                .padding(.horizontal, 4)
                .padding(.vertical, 3)
        )
    }
}

struct StoreRowView: View {
    var store: FDetail

    var body: some View {
        HStack(spacing: 12) {
            // 星數徽章
            VStack(spacing: 2) {
                Text("\(Int(store.starNum))")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                Image(systemName: "star")
                    .font(.caption)
                    .foregroundStyle(.white)
            }
            .frame(width: 52)
            .padding(.vertical, 10)
            .background(.orange.gradient, in: RoundedRectangle(cornerRadius: 12))

            // 資訊區
            VStack(alignment: .leading, spacing: 4) {
                Text(store.store)
                    .font(.headline)
                    .foregroundStyle(.primary)
                HStack(spacing: 4) {
                    Image(systemName: "mappin.circle")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                    Text(store.address)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                if !store.check {
                    Text(String(localized: "data_not_verified"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    LunchView()
}
