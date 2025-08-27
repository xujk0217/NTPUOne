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
    @State var store: FDetail
    let currCollectName: String?
    @EnvironmentObject var adFree: AdFreeService

    @State private var isStar = false
    @State private var position: MapCameraPosition
    @State private var selectionResult: MKMapItem?
    
    // adview
    @State private var adHeight: CGFloat = 100
    @State private var rowWidth: CGFloat = 0

    init(store: FDetail, currCollectName: String?) {
        self._store = State(initialValue: store)
        self.currCollectName = currCollectName
        self._position = State(initialValue: .camera(
            MapCamera(centerCoordinate: CLLocationCoordinate2D(latitude: store.lat, longitude: store.lng), distance: 780)
        ))
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    mapView
                } header: {
                    Text("餐廳位置")
                        .foregroundStyle(.black)
                }

                if !store.check {
                    Section {
                        Text("未確認資料完整性")
                            .font(.title3)
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    Button {
                        if !isStar {
                            addStar()
                        }
                    } label: {
                        HStack {
                            Text("\(Int(store.starNum))")
                                .font(.title.bold())
                            Image(systemName: isStar ? "star.fill" : "star")
                            Divider()
                            Text("覺得不錯的話，可點擊星星推薦給其他人")
                        }
                    }
                }

                Section {
                    VStack(alignment: .leading) {
                        Text(store.store)
                            .font(.title2.bold())
                        HStack {
                            Image(systemName: "house")
                            Text(": \(store.address)")
                        }
                        HStack {
                            Image(systemName: "clock")
                            Text(": \(store.time)")
                        }
                        HStack {
                            Image(systemName: "phone")
                            Text(": \(store.phone)")
                        }
                    }
                    .onTapGesture {
                        openURL(store.url)
                    }
                } footer: {
                    Text("點擊進入地圖")
                        .foregroundStyle(.black)
                }

//                // 廣告標記
//                Section {
//                    NativeAdBoxView(
//                        style: .compact(media: 120),
//                        height: $adHeight
//                    )
//                    .frame(height: adHeight)
//                    .listRowInsets(.init(top: 12, leading: 0, bottom: 12, trailing: 0))
//                    .listRowSeparator(.hidden)
//                    .listRowBackground(Color.white)
//                    .padding(.horizontal, 8)
//                } header: {
//                    Text("廣告")
//                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.gray.opacity(0.1))
            .navigationTitle(store.store)
            .onDisappear {
                isStar = false
            }
            if !adFree.isAdFree{
                // 廣告標記
                Section {
                    BannerAdView()
                        .frame(height: 50)
                }
            }
        }
    }

    var mapView: some View {
        Map(position: $position, selection: $selectionResult) {
            Marker(store.store, systemImage: "house", coordinate: CLLocationCoordinate2D(latitude: store.lat, longitude: store.lng))
        }
        .mapStyle(.standard(elevation: .realistic))
        .frame(height: 300)
    }

    func openURL(_ urlString: String) {
        if let url = URL(string: urlString), UIApplication.shared.canOpenURL(url),
           let topViewController = UIApplication.shared.windows.first?.rootViewController {
            let safariVC = SFSafariViewController(url: url)
            topViewController.present(safariVC, animated: true, completion: nil)
        }
    }

    func addStar() {
        isStar = true
        let db = Firestore.firestore()
        let docRef = db.collection(currCollectName!).document(store.id!)

        docRef.getDocument { document, error in
            guard let document, document.exists,
                  var storeData = try? document.data(as: FDetail.self)
            else { return }

            storeData.starNum += 1

            do {
                try docRef.setData(from: storeData) { error in
                    if let error = error {
                        print("❌ 更新失敗: \(error)")
                        return
                    }

                    // ✅ 再次抓回更新後的資料
                    docRef.getDocument { newDoc, error in
                        guard let newDoc,
                              newDoc.exists,
                              let updatedStore = try? newDoc.data(as: FDetail.self)
                        else { return }

                        DispatchQueue.main.async {
                            store.starNum = updatedStore.starNum
                        }
                    }
                }
            } catch {
                print("❌ setData 錯誤: \(error)")
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


struct noMapDietView: View {
    @EnvironmentObject var adFree: AdFreeService
    let store: FDetail?
    let currCollectName: String?
    
    @State private var isStar = false
    
    // adview
    @State private var adHeight: CGFloat = 100
    @State private var rowWidth: CGFloat = 0
    
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
//                // 廣告標記
//                Section {
//                    NativeAdBoxView(
//                        style: .compact(media: 120),
//                        height: $adHeight
//                    )
//                    .frame(height: adHeight)
//                    .listRowInsets(.init(top: 12, leading: 0, bottom: 12, trailing: 0))
//                    .listRowSeparator(.hidden)
//                    .listRowBackground(Color.white)
//                    .padding(.horizontal, 8)
//                } header: {
//                    Text("廣告")
//                }
            }.scrollContentBackground(.hidden)
//                .background(.linearGradient(colors: [.white, .cyan], startPoint: .bottomLeading, endPoint: .topTrailing))
                .background(Color.gray.opacity(0.1))
            .navigationTitle(store!.store)
            .onDisappear {
                isStar = false
            }
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

