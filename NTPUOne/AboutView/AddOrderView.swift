//
//  AddOrderView.swift
//  NTPUOne
//
//  Created by 許君愷 on 2024/6/26.
//

import SwiftUI
import FirebaseCore
import FirebaseFirestore
import FirebaseAuth
import AppTrackingTransparency

struct AddOrderView: View {
    @State private var name:String = ""
    @State private var message:String = ""
    @State private var email:String = ""
    @State private var time:String = ""
    @State private var url:String = ""
    
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
                                Text("活動內容：")
                                TextField("輸入公告事項（注意長度）", text: $message)
                                    .textFieldStyle(.roundedBorder)
                            }.padding()
                            HStack {
                                Text("相關網址：")
                                TextField("沒有也可以", text: $url)
                                    .textFieldStyle(.roundedBorder)
                            }.padding()
                            Divider()
                            HStack {
                                Text("你的名字：")
                                TextField("名字或暱稱", text: $name)
                                    .textFieldStyle(.roundedBorder)
                            }.padding()
                            HStack {
                                Text("你的信箱：")
                                TextField("讓我找得到你（沒有也可以）", text: $email)
                                    .textFieldStyle(.roundedBorder)
                            }.padding()
                            HStack {
                                Text("你想展示多久：")
                                TextField("日期或是時間", text: $time)
                                    .textFieldStyle(.roundedBorder)
                            }.padding()
                            Divider()
                            Text("若是有想討論或是有問題，都可以聯絡我～")
                                .font(.caption)
                                .foregroundColor(.gray)
                            NavigationLink {
                                ContactMeView()
                            } label: {
                                Text("聯絡我～")
                                    .bold()
                                    .padding()
                            }
                            Button {
                                sendPressed()
                            } label: {
                                Text("送出")
                                    .font(.title2.bold())
                                    .padding()
                            }.foregroundColor(.white)
                                .background(Color.red)
                                .cornerRadius(10)
                                .alert("上傳成功", isPresented: $isSuccessSend) {
                                            Button("OK") {
                                                isSuccessSend = false
                                            }
                                        }
                            if firebaseFail{
                                Text("送出失敗，請填好內容以及名字，或者網路有問題，稍後再試～")
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
        if message != "", name != ""{
            db.collection(K.FStoreOr.collectionName).addDocument(data: [
                K.FStoreOr.messageField: message,
                K.FStoreOr.nameField: name,
                K.FStoreOr.timeField: time,
                K.FStoreOr.emailField: email,
                K.FStoreOr.urlField: url,
                K.FStoreOr.dateField: Date().timeIntervalSince1970
            ]) { error in
                if let e = error{
                    print("There was an issue saving data to firestore, \(e)")
                    firebaseFail = true
                }else{
                    print("success save data!")
                    DispatchQueue.main.async{
                        self.message = ""
                        self.name = ""
                        self.url = ""
                        self.email = ""
                        self.time = ""
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
    AddOrderView()
}
