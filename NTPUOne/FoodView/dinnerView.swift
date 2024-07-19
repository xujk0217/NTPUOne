//
//  dinnerView.swift
//  NTPUOne
//
//  Created by 許君愷 on 2024/6/27.
//
import SwiftUI

struct dinnerView: View {
    @ObservedObject var fManager = FManager()
    var body: some View {
        if let Food = fManager.Food {
            NavigationStack {
                List {
                    Section{
                        ForEach(fManager.Food!) { store in
                            if #available(iOS 17.0, *) {
                                StoreNavigationLinkL(store: store)
                            } else {
                                // Fallback on earlier versions
                                StoreNavigationLinkLegacyL(store: store)
                            }
                        }
                    } header: {
                        Text("\(Image(systemName: "star.fill")) 是人氣數")
                            .foregroundStyle(Color.black)
                    }
                }
                .scrollContentBackground(.hidden)
//                .background(.linearGradient(colors: [.white, .cyan], startPoint: .bottomLeading, endPoint: .topTrailing))
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
        NavigationLink(destination: dietView(store: store, currCollectName: K.FStoreF.collectionNamed)) {
            StoreRowViewL(store: store)
        }
    }
}

struct StoreNavigationLinkLegacyL: View {
    var store: FDetail?

    var body: some View {
        NavigationLink(destination: noMapDietView(store: store, currCollectName: K.FStoreF.collectionNamed)) {
            StoreRowViewL(store: store)
        }
    }
}

struct StoreRowViewL: View {
    var store: FDetail?

    var body: some View {
        HStack {
            HStack {
                Text("\(Int(store!.starNum))")
                    .font(.title.bold())
                Image(systemName: "star.fill")
            }
            Divider()
            VStack(alignment: .leading) {
                HStack {
                    Text(store!.store)
                        .font(.headline)
                    Spacer()
                }
                HStack(alignment: .top) {
                    Image(systemName: "house")
                    Text(": \(store!.address)")
                    Spacer()
                }
                if !store!.check {
                    Text("未確認資料完整性")
                        .foregroundStyle(Color.red)
                }
            }
        }
    }
}

#Preview {
    dinnerView()
}
