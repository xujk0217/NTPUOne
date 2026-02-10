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
    @EnvironmentObject var adFree: AdFreeService
    
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
                }
                Section {
                    HStack {
                        Text(Bike.tot_quantity)
                            .font(.title.bold())
                        VStack {
                            HStack {
                                Text(Bike.sna.substring(from: 11))
                                Spacer()
                            }
                            HStack {
                                Image(systemName: "bicycle")
                                Text(Bike.sbi_quantity)
                                Spacer()
                                Image(systemName: "baseball.diamond.bases")
                                Text(Bike.bemp)
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle(Bike.sna.substring(from: 11))
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

#Preview {
    if #available(iOS 17.0, *) {
        bikeView(Bike: UBResults(sno: "0", sna: "0", snaen: "0", lat: "0", lng: "0", tot_quantity: "0", sbi_quantity: "0", bemp: "0"))
    } else {
        // Fallback on earlier versions
        noMapBikeView(Bike: UBResults(sno: "0", sna: "0", snaen: "0", lat: "0", lng: "0", tot_quantity: "0", sbi_quantity: "0", bemp: "0"))
    }
}

@available(iOS 17.0, *)
extension bikeView {
    @available(iOS 17.0, *)
    var mapView: some View {
        VStack {
            Map(position: $position, selection: $selectionResult) {
                Marker("\(Bike.sna.substring(from: 11))-(\(Bike.sbi_quantity)/\(Bike.tot_quantity))", systemImage: "bicycle", coordinate: CLLocationCoordinate2D(latitude: Double(Bike.lat)!, longitude: Double(Bike.lng)!))
            }
            .mapStyle(.standard(elevation: .realistic))
        }
        .frame(height: 200)
    }
}


struct noMapBikeView: View {
    @EnvironmentObject var adFree: AdFreeService
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
                } footer: {
                    Text("名稱：站名-(腳踏車數/總數)")
                }
                Section{
                    HStack{
                        Text(Bike!.tot_quantity)
                            .font(.title.bold())
                        VStack{
                            HStack {
                                Text(Bike!.sna.substring(from: 11))
                                Spacer()
                            }
                            HStack{
                                Image(systemName: "bicycle")
                                Text(Bike!.sbi_quantity)
                                Spacer()
                                Image(systemName: "baseball.diamond.bases")
                                Text(Bike!.bemp)
                                Spacer()
                            }
                        }
                    }
                }
            }.navigationTitle(Bike!.sna.substring(from: 11))
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

