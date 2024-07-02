//
//  dietView.swift
//  NTPUOne
//
//  Created by 許君愷 on 2024/7/1.
//

import SwiftUI
import MapKit
import SafariServices

struct dietView: View {
    let store: FDetail?
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    if #available(iOS 17.0, *) {
                        mapView
                    } else {
                        // Fallback on earlier versions
                        Text("升級至 IOS 17.0 以開啟地圖功能")
                    }
                } header: {
                    Text("餐廳位置")
                }
                Section {
                    HStack {
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
                                        .font(.title2.bold())
                                    Spacer()
                                }
                                HStack(alignment: .top) {
                                    Image(systemName: "house")
                                    Text(": \(store!.address)")
                                    Spacer()
                                }
                                HStack(alignment: .top) {
                                    Image(systemName: "clock")
                                    Text(": \(store!.time)")
                                    Spacer()
                                }
                            }
                        }
                    }
                    .onTapGesture {
                        openURL(store!.url)
                    }
                }
            }
            .navigationTitle("餐廳詳情")
        }
    }
}

#Preview {
    dietView(store: FDetail(store: "abc", time: "abc", url: "abc", address: "abc", starNum: 1, lat: 24.947582922315316, lng: 1.1))
}

extension dietView{
    func openURL(_ urlString: String) {
        if let url = URL(string: urlString) {
            if UIApplication.shared.canOpenURL(url) {
                // 打开 SafariViewController
                if let topViewController = UIApplication.shared.windows.first?.rootViewController {
                    let safariVC = SFSafariViewController(url: url)
                    topViewController.present(safariVC, animated: true, completion: nil)
                }
            } else {
                print("Cannot open URL: \(urlString)")
            }
        }
    }
    @available(iOS 17.0, *)
    var mapView: some View {
        @State var position: MapCameraPosition = .camera(
            MapCamera(centerCoordinate: CLLocationCoordinate2D(latitude: store!.lat, longitude: store!.lng), distance: 780)
        )
        @State var selectionResult: MKMapItem?
        return VStack{
            Map(position: $position, selection: $selectionResult){
                Marker("\(store!.store)", systemImage: "house", coordinate: CLLocationCoordinate2D(latitude: store!.lat, longitude: store!.lng))
            }.mapStyle(.standard(elevation: .realistic))
        }.frame(height: 300)
    }
}
