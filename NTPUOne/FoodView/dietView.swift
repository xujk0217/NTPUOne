//
//  dietView.swift
//  NTPUOne
//
//  Created by 許君愷 on 2024/7/1.
//
import SwiftUI
import MapKit
import SafariServices
import FirebaseFirestore
import FirebaseFirestoreSwift

@available(iOS 17.0, *)
struct dietView: View {
    let store: FDetail?
    let currCollectName: String?
    
    @State private var isStar = false
    @State private var position: MapCameraPosition
    @State private var selectionResult: MKMapItem?

    init(store: FDetail?, currCollectName: String?) {
        self.store = store
        self.currCollectName = currCollectName
        _position = State(initialValue: .camera(
            MapCamera(centerCoordinate: CLLocationCoordinate2D(latitude: store!.lat, longitude: store!.lng), distance: 780)
        ))
    }
    
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
                        .foregroundStyle(Color.black)
                }
                if !store!.check {
                    Section {
                        Text("未確認資料完整性")
                            .font(.title3)
                            .foregroundStyle(Color.red)
                    }
                }
                Section {
                    Button {
                        if !isStar {
                            addStar()
                        }
                    } label: {
                        HStack {
                            Text("\(Int(store!.starNum))")
                                .font(.title.bold())
                            if isStar {
                                Image(systemName: "star.fill")
                            } else {
                                Image(systemName: "star")
                            }
                            Divider()
                            Text("覺得不錯的話，可點擊星星推薦給其他人")
                        }
                    }
                }
                Section {
                    HStack {
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
                            HStack(alignment: .top) {
                                Image(systemName: "phone")
                                Text(": \(store!.phone)")
                                Spacer()
                            }
                        }
                    }
                    .onTapGesture {
                        openURL(store!.url)
                    }
                } footer: {
                    Text("點擊進入地圖")
                        .foregroundStyle(Color.black)
                }
            }.scrollContentBackground(.hidden)
//                .background(.linearGradient(colors: [.white, .cyan], startPoint: .bottomLeading, endPoint: .topTrailing))
                .background(Color.gray.opacity(0.1))
            .navigationTitle(store!.store)
            .onDisappear {
                isStar = false
            }
        }
    }
}

#Preview {
    if #available(iOS 17.0, *) {
        dietView(store: FDetail(store: "abc", time: "abc", url: "abc", address: "abc", phone: "0987654321", starNum: 1, lat: 24.947582922315316, lng: 1.1, check: false), currCollectName: K.FStoreF.collectionNamed)
    } else {
        // Fallback on earlier versions
        noMapDietView(store: FDetail(store: "abc", time: "abc", url: "abc", address: "abc", phone: "0987654321", starNum: 1, lat: 24.947582922315316, lng: 1.1, check: false), currCollectName: K.FStoreF.collectionNamed)
    }
}

@available(iOS 17.0, *)
extension dietView {
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
    
    func addStar() {
        isStar = true
        let db = Firestore.firestore()
        let documentReference = db.collection(currCollectName!).document(store!.id!)
        documentReference.getDocument { document, error in
            guard let document,
                  document.exists,
                  var store = try? document.data(as: FDetail.self)
            else {
                return
            }
            store.starNum += 1
            do {
                try documentReference.setData(from: store)
            } catch {
                print(error)
            }
        }
    }
    
    var mapView: some View {
        VStack {
            Map(position: $position, selection: $selectionResult) {
                Marker("\(store!.store)", systemImage: "house", coordinate: CLLocationCoordinate2D(latitude: store!.lat, longitude: store!.lng))
            }.mapStyle(.standard(elevation: .realistic))
        }.frame(height: 300)
    }
}


struct noMapDietView: View {
    let store: FDetail?
    let currCollectName: String?
    
    @State private var isStar = false
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("升級至 IOS 17.0 以開啟地圖功能")
                } header: {
                    Text("餐廳位置")
                }
                if !store!.check {
                    Section{
                        Text("未確認資料完整性")
                            .font(.title3)
                            .foregroundStyle(Color.red)
                    }
                }
                Section{
                    Button {
                        if isStar == false{
                            addStar()
                        }
                    } label: {
                        HStack{
                            HStack {
                                Text("\(Int(store!.starNum))")
                                    .font(.title.bold())
                                if isStar == true{
                                    Image(systemName: "star.fill")
                                }else{
                                    Image(systemName: "star")
                                }
                                Divider()
                                Text("覺得不錯的話，可點擊星星推薦給其他人")
                            }
                        }
                    }
                }
                Section {
                    HStack {
                        HStack {
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
                                HStack(alignment: .top) {
                                    Image(systemName: "phone")
                                    Text(": \(store!.phone)")
                                    Spacer()
                                }
                            }
                        }
                    }
                    .onTapGesture {
                        openURL(store!.url)
                    }
                } footer: {
                    Text("點擊進入地圖")
                }
            }.scrollContentBackground(.hidden)
//                .background(.linearGradient(colors: [.white, .cyan], startPoint: .bottomLeading, endPoint: .topTrailing))
                .background(Color.gray.opacity(0.1))
            .navigationTitle(store!.store)
            .onDisappear {
                isStar = false
            }
        }
    }
}

extension noMapDietView{
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
    
    func addStar(){
        isStar = true
        let db = Firestore.firestore()
            let documentReference =
        db.collection(currCollectName!).document(store!.id!)
            documentReference.getDocument { document, error in
                guard let document,
                      document.exists,
                      var store = try? document.data(as: FDetail.self)
                else {
                    return
                }
                store.starNum += 1
                do {
                    try documentReference.setData(from: store)
                } catch {
                    print(error)
                }
                
            }
    }
}

