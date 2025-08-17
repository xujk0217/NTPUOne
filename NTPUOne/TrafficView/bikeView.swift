//
//  bikeView.swift
//  NTPUOne
//
//  Created by 許君愷 on 2024/6/24.
//
import SwiftUI
import MapKit

@available(iOS 17.0, *)
struct bikeView: View {
    let Bike: UBResults
    
    @State private var position: MapCameraPosition
    @State private var selectionResult: MKMapItem?
    
    // adview
    @State private var adHeight: CGFloat = 100
    @State private var rowWidth: CGFloat = 0

    init(Bike: UBResults) {
        self.Bike = Bike
        _position = State(initialValue: .camera(
            MapCamera(centerCoordinate: CLLocationCoordinate2D(latitude: Double(Bike.lat)!, longitude: Double(Bike.lng)!), distance: 780)
        ))
    }
    
    var body: some View {
        NavigationStack {
            List{
                Section {
                    if #available(iOS 17.0, *) {
                        mapView
                    } else {
                        // Fallback on earlier versions
                        Text("升級至 IOS 17.0 以開啟地圖功能")
                    }
                } header: {
                    Text("腳踏車地圖")
                } footer: {
                    Text("名稱：站名-(腳踏車數/總數)")
                }.listRowBackground(Color.white.opacity(0.7))
                Section {
                    HStack {
                        Text(Bike.tot)
                            .font(.title.bold())
                        VStack {
                            HStack {
                                Text(Bike.sna.substring(from: 11))
                                Spacer()
                            }
                            HStack {
                                Image(systemName: "bicycle")
                                Text(Bike.sbi)
                                Spacer()
                                Image(systemName: "baseball.diamond.bases")
                                Text(Bike.bemp)
                                Spacer()
                            }
                        }
                    }
                }.listRowBackground(Color.white.opacity(0.7))
                // 廣告標記
                Section {
                    NativeAdBoxView(
                        style: .compact(media: 120),
                        height: $adHeight
                    )
                    .frame(height: adHeight)
                    .listRowInsets(.init(top: 12, leading: 0, bottom: 12, trailing: 0))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.white)
                    .padding(.horizontal, 8)
                } header: {
                    Text("廣告")
                }
            }
            .scrollContentBackground(.hidden)
//            .background(.linearGradient(colors: [.white, .green], startPoint: .bottomLeading, endPoint: .topTrailing))
            .background(Color.gray.opacity(0.1))
            .navigationTitle(Bike.sna.substring(from: 11))
        }
    }
}

#Preview {
    if #available(iOS 17.0, *) {
        bikeView(Bike: UBResults(sno: "0", sna: "0", snaen: "0", lat: "0", lng: "0", tot: "0", sbi: "0", bemp: "0"))
    } else {
        // Fallback on earlier versions
        noMapBikeView(Bike: UBResults(sno: "0", sna: "0", snaen: "0", lat: "0", lng: "0", tot: "0", sbi: "0", bemp: "0"))
    }
}

@available(iOS 17.0, *)
extension bikeView {
    @available(iOS 17.0, *)
    var mapView: some View {
        VStack {
            Map(position: $position, selection: $selectionResult) {
                Marker("\(Bike.sna.substring(from: 11))-(\(Bike.sbi)/\(Bike.tot))", systemImage: "bicycle", coordinate: CLLocationCoordinate2D(latitude: Double(Bike.lat)!, longitude: Double(Bike.lng)!))
            }
            .mapStyle(.standard(elevation: .realistic))
        }
        .frame(height: 200)
    }
}


struct noMapBikeView: View {
    
    let Bike: UBResults?
    
    // adview
    @State private var adHeight: CGFloat = 100
    @State private var rowWidth: CGFloat = 0
    
    var body: some View {
        NavigationStack {
            List{
                Section{
                    Text("升級至 IOS 17.0 以開啟地圖功能")
                } header: {
                    Text("腳踏車地圖")
                        .foregroundStyle(Color.black)
                } footer: {
                    Text("名稱：站名-(腳踏車數/總數)")
                        .foregroundStyle(Color.black)
                }
                Section{
                    HStack{
                        Text(Bike!.tot)
                            .font(.title.bold())
                        VStack{
                            HStack {
                                Text(Bike!.sna.substring(from: 11))
                                Spacer()
                            }
                            HStack{
                                Image(systemName: "bicycle")
                                Text(Bike!.sbi)
                                Spacer()
                                Image(systemName: "baseball.diamond.bases")
                                Text(Bike!.bemp)
                                Spacer()
                            }
                        }
                    }
                }.listRowBackground(Color.white.opacity(0.7))
                .scrollContentBackground(.hidden)
//                .background(.linearGradient(colors: [.white, .green], startPoint: .bottomLeading, endPoint: .topTrailing))
                .background(Color.gray.opacity(0.1))
                // 廣告標記
                Section {
                    NativeAdBoxView(
                        style: .compact(media: 120),
                        height: $adHeight
                    )
                    .frame(height: adHeight)
                    .listRowInsets(.init(top: 12, leading: 0, bottom: 12, trailing: 0))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.white)
                    .padding(.horizontal, 8)
                } header: {
                    Text("廣告")
                }
            }.navigationTitle(Bike!.sna.substring(from: 11))
        }
    }
}

