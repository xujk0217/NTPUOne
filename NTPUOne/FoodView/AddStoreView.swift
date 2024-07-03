//
//  AddStoreView.swift
//  NTPUOne
//
//  Created by 許君愷 on 2024/7/3.
//

import SwiftUI
import FirebaseCore
import FirebaseFirestore
import FirebaseAuth
import AppTrackingTransparency

struct AddStoreView: View {
    let currCollectName: String?
    @State private var store:String = ""
    @State private var time:String = ""
    @State private var url:String = ""
    @State private var address:String = ""
    @State private var starNum:Double = 1
    @State private var lat:String = ""
    @State private var lng:String = ""
    
    @State var isSuccessSend = false
    
    @State private var firebaseFail = false
    
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>
    
    let db = Firestore.firestore()
    
    var body: some View {
        VStack {
            VStack {
                NavigationStack{
                    ScrollView {
                        VStack {
                            HStack {
                                Text("商家名稱＊：")
                                TextField("商家名稱", text: $store)
                                    .textFieldStyle(.roundedBorder)
                            }.padding()
                            HStack {
                                Text("相關網址＊：")
                                TextField("沒有也可以", text: $url)
                                    .textFieldStyle(.roundedBorder)
                            }.padding()
                            HStack {
                                Text("營業時間＊：")
                                TextField("ex: 11:00~12:30", text: $time)
                                    .textFieldStyle(.roundedBorder)
                            }.padding()
                            HStack {
                                Text("地址＊：")
                                TextField("商家地址）", text: $address)
                                    .textFieldStyle(.roundedBorder)
                            }.padding()
                            HStack {
                                Text("經度：")
                                TextField("沒有沒關係", text: $lat)
                                    .textFieldStyle(.roundedBorder)
                            }.padding()
                            HStack {
                                Text("緯度：")
                                TextField("沒有沒關係", text: $lng)
                                    .textFieldStyle(.roundedBorder)
                            }.padding()
                            Divider()
                            Button {
                                sendPressed()
                            } label: {
                                Text("送出")
                                    .font(.title3.bold())
                                    .padding()
                            }.foregroundColor(.white)
                                .background(Color.blue)
                                .cornerRadius(10)
                                .alert("上傳成功", isPresented: $isSuccessSend) {
                                            Button("OK") {
                                                isSuccessSend = false
                                            }
                                        }
                            if firebaseFail{
                                Text("送出失敗，請填好必要內容，或者網路有問題，稍後再試～")
                                    .foregroundStyle(Color.red)
                                    .padding()
                            }
                        }.padding()
                    }
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }.edgesIgnoringSafeArea(.bottom)
    }
    
    
    func sendPressed() {
        if store != "", url != "", time != "", address != ""{
            var latDou:Double = 0.0
            var lngDou:Double = 0.0
            if let latD = Double(lat), let lngD = Double(lng){
                latDou = latD
                lngDou = lngD
            }else{
                latDou = 24.942406
                lngDou = 121.368198
            }
            db.collection(currCollectName!).addDocument(data: [
                K.FStoreF.storeField: store,
                K.FStoreF.urlField: url,
                K.FStoreF.openTimeField: time,
                K.FStoreF.addressField: address,
                K.FStoreF.starField: starNum,
                K.FStoreF.latField: latDou,
                K.FStoreF.lngField: lngDou
                
            ]) { error in
                if let e = error{
                    print("There was an issue saving data to firestore, \(e)")
                    firebaseFail = true
                }else{
                    print("success save data!")
                    DispatchQueue.main.async{
                        self.store = ""
                        self.url = ""
                        self.time = ""
                        self.address = ""
                        self.lat = ""
                        self.lng = ""
                    }
                    self.isSuccessSend = true
                    self.presentationMode.wrappedValue.dismiss()
                }
            }
        }else{
            firebaseFail = true
        }
    }
}

#Preview {
    AddStoreView(currCollectName: K.FStoreF.collectionNameB)
}
