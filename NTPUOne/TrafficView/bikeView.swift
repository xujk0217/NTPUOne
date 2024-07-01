//
//  bikeView.swift
//  NTPUOne
//
//  Created by 許君愷 on 2024/6/24.
//

import SwiftUI
import MapKit

struct bikeView: View {
    
    let Bike: UBResults?
    
    var body: some View {
        NavigationStack {
            List{
                Section{
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
                }
            }.navigationTitle(Bike!.sna.substring(from: 11))
        }
    }
}

#Preview {
    bikeView(Bike: UBResults(sno: "0", sna: "0", snaen: "0", lat: "0", lng: "0", tot: "0", sbi: "0", bemp: "0"))
}

extension bikeView{
    @available(iOS 17.0, *)
    var mapView: some View {
        @State var position: MapCameraPosition = .camera(
            MapCamera(centerCoordinate: CLLocationCoordinate2D(latitude: Double(Bike!.lat)!, longitude: Double(Bike!.lng)!), distance: 780)
        )
        @State var selectionResult: MKMapItem?
        return VStack{
            Map(position: $position, selection: $selectionResult){
                Marker("\(Bike!.sna.substring(from: 11))-(\(Bike!.sbi)/\(Bike!.tot))", systemImage: "bicycle", coordinate: CLLocationCoordinate2D(latitude: Double(Bike!.lat)!, longitude: Double(Bike!.lng)!))
            }.mapStyle(.standard(elevation: .realistic))
        }.frame(height: 200)
    }
}
