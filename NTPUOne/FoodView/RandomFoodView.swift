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
    @State private var showMealPicker = false
    @State private var goBreakfast = false
    @State private var goLunch = false
    @State private var goDinner = false
    @State private var goMidnightSnack = false
    
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
        RemoteConfigFeatureGate(feature: .restaurant) {
        NavigationStack {
            VStack {
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
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showMealPicker = true
                        } label: {
                            Label(String(localized: "restaurant"), systemImage: "list.bullet.rectangle")
                                .labelStyle(.iconOnly)
                        }
                    }
                }
                .onAppear {
                    if let list = fManager.Food {
                        selectedIDs = Set(list.compactMap { $0.id })
                    }
                }
                .task(id: whichDiet) {
                    fManager.loadF(whichDiet: whichDiet)
                }
                .onChange(of: fManager.Food) { newList in
                    if let list = newList {
                        selectedIDs = Set(list.compactMap { $0.id })
                    }
                }
                .sheet(isPresented: $showMealPicker) {
                    mealPickerSheet
                }
                .alert(String(localized: "alert_keep_one_restaurant"), isPresented: $showAlert) {
                    Button(String(localized: "ok"), role: .cancel) {}
                }

                NavigationLink(destination: BreakfastView(), isActive: $goBreakfast) { EmptyView() }.hidden()
                NavigationLink(destination: LunchView(), isActive: $goLunch) { EmptyView() }.hidden()
                NavigationLink(destination: dinnerView(), isActive: $goDinner) { EmptyView() }.hidden()
                NavigationLink(destination: MSView(), isActive: $goMidnightSnack) { EmptyView() }.hidden()
            }
        }
        }
    }

    private var mealPickerSheet: some View {
        NavigationStack {
            List {
                mealPickerRow(icon: "cup.and.saucer", title: String(localized: "breakfast"), tint: .orange) {
                    goBreakfast = true
                    showMealPicker = false
                }

                mealPickerRow(icon: "carrot", title: String(localized: "lunch"), tint: .green) {
                    goLunch = true
                    showMealPicker = false
                }

                mealPickerRow(icon: "wineglass", title: String(localized: "dinner"), tint: .purple) {
                    goDinner = true
                    showMealPicker = false
                }

                mealPickerRow(icon: "moon.stars", title: String(localized: "midnight_snack"), tint: .indigo) {
                    goMidnightSnack = true
                    showMealPicker = false
                }
            }
            .navigationTitle(String(localized: "choose_meal"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "close")) {
                        showMealPicker = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func mealPickerRow(icon: String, title: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(tint)
                    .frame(width: 40)
                Text(title)
                    .font(.headline)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}
