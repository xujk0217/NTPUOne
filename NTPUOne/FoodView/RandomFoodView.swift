//
//  RandomFoodView.swift
//  NTPUOne
//
//  Created by 許君愷 on 2025/8/6.
//

import SwiftUI

@available(iOS 17.0, *)
struct RandomFoodView: View {
    @StateObject private var fManager = FManager()
    @EnvironmentObject var adFree: AdFreeService
    @State private var whichDiet: String = "B"
    @State private var selectedRestaurant: FDetail?
    @State private var resetTrigger = false
    @State private var selectedIDs: Set<String> = []
    @State private var showAlert = false
    
    // adview
    @State private var adHeight: CGFloat = 100
    @State private var rowWidth: CGFloat = 0
    

    let dietKeys = ["B", "L", "D", "M"]
    let dietOptions = ["B": "早餐", "L": "午餐", "D": "晚餐", "M": "宵夜"]

    var body: some View {
        NavigationStack {
            List {
                
                // MARK: - 餐別選擇區
                Section {
                    Picker("選擇餐別", selection: $whichDiet) {
                        ForEach(dietKeys, id: \.self) { key in
                            Text(dietOptions[key] ?? "").tag(key)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .onChange(of: whichDiet) { newValue in
                        selectedRestaurant = nil // 清除中獎店家
                        resetTrigger = true      // 觸發轉盤歸位
                        fManager.loadF(whichDiet: newValue)
                    }

                } header: {
                    Text("餐別選擇")
                }
                // MARK: - 結果顯示區（中獎）
                Section {
                    if let restaurant = selectedRestaurant {
                        NavigationLink(
                            destination: {
                                if #available(iOS 17.0, *) {
                                    dietView(store: restaurant, currCollectName: fManager.getCollectionName(for: whichDiet))
                                } else {
                                    noMapDietView(store: restaurant, currCollectName: fManager.getCollectionName(for: whichDiet))
                                }
                            },
                            label: {
                                VStack(spacing: 8) {
                                    Text("🎉 中獎餐廳")
                                        .font(.title3.bold())
                                        .padding(3)
                                    Divider()
                                    StoreRowView(store: restaurant)
                                }
                            }
                        )
                    } else {
                        VStack{
                            Text("點擊下方輪盤按鈕即可抽獎")
                                .font(.headline)
                        }
                        .padding()
                        .cornerRadius(12)
                    }
                } header: {
                    Text("推薦結果")
                }
                
                // MARK: - 轉盤轉動區
                if let foodList = fManager.Food {
                    let filteredList = foodList.filter { restaurant in
                        selectedIDs.contains(restaurant.id ?? "")
                    }

                    Section {
                        SpinningWheelView(restaurants: filteredList, resetTrigger: $resetTrigger) { selected in
                            selectedRestaurant = selected
                        }
                    } header: {
                        Text("轉盤")
                    }
                }

                // MARK: - 顯示清單
                Section(header: Text("餐廳列表"),
                        footer: Text("勾選你想要參加抽籤的餐廳\n可到 Life 頁面新增餐廳")) {
                    if let foodList = fManager.Food {
                        ForEach(foodList, id: \.id) { r in
                            Toggle(isOn: Binding<Bool>(
                                get: { selectedIDs.contains(r.id ?? "") },
                                set: { isOn in
                                    let id = r.id ?? ""
                                    if isOn {
                                        selectedIDs.insert(id)
                                    } else {
                                        if selectedIDs.count > 1 {
                                            selectedIDs.remove(id)
                                        } else {
                                            showAlert = true
                                            print("至少要保留一間餐廳")
                                        }
                                    }
                                }
                            )) {
                                Text(r.store)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                    .font(.headline)
                            }
                        }
                    } else {
                        Text("目前沒有餐廳，可到 Life 頁面新增")
                    }
                }
            }
            .navigationTitle("吃飯轉盤")
            .onAppear {
                fManager.loadF(whichDiet: whichDiet)
                if let list = fManager.Food {
                    selectedIDs = Set(list.compactMap { $0.id })
                }
            }
            .onChange(of: fManager.Food) { newList in
                if let list = newList {
                    selectedIDs = Set(list.compactMap { $0.id })
                }
            }
            .alert("至少要保留一間餐廳參加抽籤", isPresented: $showAlert) {
                Button("OK", role: .cancel) {}
            }
            if !adFree.isAdFree{
                // 廣告標記
                Section {
                    BannerAdView()
                        .frame(height: 50)
                }
            }
        }
    }
}
