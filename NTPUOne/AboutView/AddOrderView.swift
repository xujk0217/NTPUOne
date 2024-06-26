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

struct AddOrderView: View {
    @State private var name:String = ""
    @State private var message:String = ""
    @State private var email:String = ""
    @State private var time:String = ""
    @State private var url:String = ""
    
    @State private var firebaseFail = false
    
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>
    
    let db = Firestore.firestore()
    
    var body: some View {
        NavigationView{
            ScrollView {
                VStack {
                    HStack {
                        Text("活動內容：")
                        TextField("輸入活動或公告事項", text: $message)
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
                    Section{
                        NavigationLink {
                            ContactMeView()
                        } label: {
                            Text("聯絡我～")
                                .bold()
                                .padding()
                        }
                    } header: {
                        Text("若是有想討論或是有問題，都可以聯絡我～")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    Button {
                        sendPressed()
                    } label: {
                        Text("送出～")
                            .font(.title2.bold())
                            .foregroundStyle(Color.white)
                            .padding()
                            .background(Color.red)
                            .border(Color.red, width: 5)
                            .cornerRadius(10)
                    }
                    if firebaseFail{
                        Text("送出失敗，請填好內容以及名稱，或者網路有問題，稍後再試～")
                            .foregroundStyle(Color.red)
                            .padding()
                    }
                }.padding()
            }
        }
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
