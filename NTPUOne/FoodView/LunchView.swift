//
//  LunchView.swift
//  NTPUOne
//
//  Created by 許君愷 on 2024/6/27.
//

import SwiftUI

struct LunchView: View {
    @ObservedObject var fManager = FManager()
    var body: some View {
        if let Food = fManager.Food {
            NavigationStack {
                List {
                    ForEach(fManager.Food!) { store in
                        NavigationLink(destination: dietView(store: store, currCollectName: K.FStoreF.collectionNamel)){
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
                                }
                            }
                        }
                    }
                }
                .navigationTitle("Lunch")
                .onAppear {
                    fManager.loadF(whichDiet: "L")
                }
            }
        }
        else{
            Text("Loading...")
                .onAppear {
                    fManager.loadF(whichDiet: "L")
                }
            ProgressView()
        }
    }
}

#Preview {
    LunchView()
}
