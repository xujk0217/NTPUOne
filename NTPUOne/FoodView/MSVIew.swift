//
//  MSVIew.swift
//  NTPUOne
//
//  Created by 許君愷 on 2024/6/27.
//

import SwiftUI

struct MSVIew: View {
    @ObservedObject var fManager = FManager()
    var body: some View {
        if let Food = fManager.Food {
            NavigationStack {
                List {
                    ForEach(fManager.Food!) { store in
                        NavigationLink(destination: dietView(store: store, currCollectName: K.FStoreF.collectionNamem)){
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
                .navigationTitle("Midnight snack")
                .toolbar{
                    ToolbarItem(placement: .primaryAction, content: {
                        NavigationLink {
                            AddStoreView(currCollectName: K.FStoreF.collectionNamem)
                        } label: {
                            Image(systemName: "plus")
                                .foregroundStyle(Color.blue)
                        }
                    })
                }
                .onAppear {
                    fManager.loadF(whichDiet: "M")
                }
            }
        }else{
            Text("Loading...")
                .onAppear {
                    fManager.loadF(whichDiet: "M")
                }
            ProgressView()
        }
    }
}

#Preview {
    MSVIew()
}
