//
//  dinnerView.swift
//  NTPUOne
//
//  Created by 許君愷 on 2024/6/27.
//
import SwiftUI
import MapKit

struct dinnerView: View {
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
                    Section{
                        ForEach(Array(fManager.Food!.enumerated()), id: \.element.id) { index, store in
                            if #available(iOS 17.0, *) {
                                StoreNavigationLinkL(store: store)
                            } else {
                                // Fallback on earlier versions
                                StoreNavigationLinkLegacyL(store: store)
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
                .navigationTitle("Dinner")
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        NavigationLink {
                            AddStoreView(currCollectName: K.FStoreF.collectionNamed)
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(Color.blue)
                        }
                    }
                }
                .onAppear {
                    fManager.loadF(whichDiet: "D")
                }
            }
        } else {
            Text("Loading...")
                .onAppear {
                    fManager.loadF(whichDiet: "D")
                }
            ProgressView()
        }
    }
}

@available(iOS 17.0, *)
struct StoreNavigationLinkL: View {
    var store: FDetail?

    var body: some View {
        NavigationLink(destination: dietView(store: store!, currCollectName: K.FStoreF.collectionNamed)) {
            StoreRowViewL(store: store)
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

struct StoreNavigationLinkLegacyL: View {
    var store: FDetail?

    var body: some View {
        NavigationLink(destination: noMapDietView(store: store, currCollectName: K.FStoreF.collectionNamed)) {
            StoreRowViewL(store: store)
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

struct StoreRowViewL: View {
    var store: FDetail?

    var body: some View {
        HStack(spacing: 12) {
            VStack(spacing: 2) {
                Text("\(Int(store!.starNum))")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                Image(systemName: "star.fill")
                    .font(.caption)
                    .foregroundStyle(.white)
            }
            .frame(width: 52)
            .padding(.vertical, 10)
            .background(.orange.gradient, in: RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 4) {
                Text(store!.store)
                    .font(.headline)
                    .foregroundStyle(.primary)
                HStack(spacing: 4) {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                    Text(store!.address)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                if !store!.check {
                    Label("未確認資料完整性", systemImage: "exclamationmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    dinnerView()
}
