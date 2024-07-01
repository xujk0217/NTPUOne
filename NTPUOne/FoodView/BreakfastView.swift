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
        NavigationStack {
            List {
                ForEach(fManager.Food) { store in
                    NavigationLink(destination: dietView(store: store)){
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
            .navigationTitle("Breakfast")
            }.onAppear {
            fManager.loadF(whichDiet: "B")
        }
    }
}

#Preview {
    BreakfastView()
}

