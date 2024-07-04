//
//  SwiftUIView.swift
//  NTPUOne
//
//  Created by 許君愷 on 2024/6/27.
//

import SwiftUI
import FirebaseFirestore

struct BreakfastView: View {
    @ObservedObject var fManager = FManager()
    var body: some View {
        if let Food = fManager.Food {
            NavigationStack {
                List {
                    Section{
                        ForEach(fManager.Food!) { store in
                            if #available(iOS 17.0, *) {
                                NavigationLink(destination: dietView(store: store, currCollectName: K.FStoreF.collectionNameB)){
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
                                            if !store.check{
                                                Text("未確認資料完整性")
                                                    .foregroundStyle(Color.red)
                                            }
                                        }
                                    }
                                }
                            } else {
                                // Fallback on earlier versions
                                NavigationLink(destination: noMapDietView(store: store, currCollectName: K.FStoreF.collectionNameB)){
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
                                            if !store.check{
                                                Text("未確認資料完整性")
                                                    .foregroundStyle(Color.red)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    } header: {
                        Text("\(Image(systemName: "star.fill")) 是人氣數")
                            .foregroundStyle(Color.black)
                    }
                }.scrollContentBackground(.hidden)
                .background(.linearGradient(colors: [.white, .cyan], startPoint: .bottomLeading, endPoint: .topTrailing))
                .navigationTitle("Breakfast")
                .toolbar{
                    ToolbarItem(placement: .primaryAction, content: {
                        NavigationLink {
                            AddStoreView(currCollectName: K.FStoreF.collectionNameB)
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(Color.white)
                        }
                    })
                }
                }.onAppear {
                fManager.loadF(whichDiet: "B")
            }
        }else{
            Text("Loading...")
                .onAppear {
                    fManager.loadF(whichDiet: "B")
                }
            ProgressView()
        }
    }
}

#Preview {
    BreakfastView()
}

