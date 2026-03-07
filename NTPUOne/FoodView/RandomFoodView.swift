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
    var dietOptions: [String: String] {
        ["B": String(localized: "breakfast"),
         "L": String(localized: "lunch"),
         "D": String(localized: "dinner"),
         "M": String(localized: "late_night_snack")]
    }

    var body: some View {
        NavigationStack {
            List {
                
                // MARK: - 餐別選擇區
                Section {
                    Picker(String(localized: "picker_select_meal"), selection: $whichDiet) {
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
                    Text(String(localized: "meal_selection"))
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
                                    Text(String(localized: "winner_restaurant"))
                                        .font(.title3.bold())
                                        .padding(3)
                                    Divider()
                                    StoreRowView(store: restaurant)
                                }
                            }
                        )
                    } else {
                        VStack{
                            Text(String(localized: "tap_wheel_to_spin"))
                                .font(.headline)
                        }
                        .padding()
                        .cornerRadius(12)
                    }
                } header: {
                    Text(String(localized: "recommendation_result"))
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
                        Text(String(localized: "spinner"))
                    }
                }

                // MARK: - 顯示清單
                Section(header: Text(String(localized: "restaurant_list")),
                        footer: Text(String(localized: "restaurant_list_footer"))) {
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
                                            print("at least keep one restaurant")
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
                        Text(String(localized: "no_restaurant_hint"))
                    }
                }
                
                // Native 廣告 Section
                if !adFree.isAdFree {
                    Section {
                        NativeAdSectionView(style: .compact)
                            .frame(height: 140)
                    }
                    .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
                }
            }
            .navigationTitle(String(localized: "navigation_food_wheel"))
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
            .alert(String(localized: "alert_keep_one_restaurant"), isPresented: $showAlert) {
                Button(String(localized: "ok"), role: .cancel) {}
            }
        }
    }
}
