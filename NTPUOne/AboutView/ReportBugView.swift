//
//  ReportBugView.swift
//  NTPUOne
//
//  Created by 許君愷 on 2024/6/27.
//

import SwiftUI
import FirebaseCore
import FirebaseFirestore
import FirebaseAuth
import AppTrackingTransparency

struct ReportBugView: View {
    @State private var email:String = ""
    @State private var issue:String = ""
    @State private var detail:String = ""
    @State var containHeight: CGFloat = 0
    
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
                                Text("發現問題：")
                                TextField("問題", text: $issue)
                                    .textFieldStyle(.roundedBorder)
                            }.padding()
                            HStack {
                                Text("問題詳情：")
//                                TextField("具體過程或是如何產生", text: $detail)
//                                    .textFieldStyle(.roundedBorder)
                                VStack{
                                    AutoSizingTF(
                                        hint: "具體過程或是如何產生",
                                        text: $detail,
                                        containerHeight: $containHeight,
                                        onEnd: {
                                        //当键盘被关闭时调用该方法
                                            UIApplication
                                                .shared
                                                .sendAction(
                                                    #selector(
                                                        UIResponder.resignFirstResponder
                                                    ),
                                                    to: nil,
                                                    from: nil,
                                                    for: nil
                                                )
                                        }
                                    )
                                    .frame(height: containHeight < 120 ? containHeight : 120)
                                }
                            }.padding()
                            HStack {
                                Text("你的信箱：")
                                TextField("讓我找得到你（沒有也可以）", text: $email)
                                    .textFieldStyle(.roundedBorder)
                            }.padding()
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
                                        }
                            if firebaseFail{
                                Text("送出失敗，請填好問題以及詳情，或者網路有問題，稍後再試～")
                                    .foregroundStyle(Color.red)
                                    .padding()
                            }
                        }.padding()
                    }
                    // 廣告標記
                    BannerAdView()
                            .frame(height: 50)
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }//.edgesIgnoringSafeArea(.bottom)
    }
    func sendPressed() {
        if issue != "", detail != ""{
            db.collection(K.FStoreR.collectionNameBug).addDocument(data: [
                K.FStoreR.issueField: issue,
                K.FStoreR.detailField: detail,
                K.FStoreR.emailField: email,
            ]) { error in
                if let e = error{
                    print("There was an issue saving data to firestore, \(e)")
                    firebaseFail = true
                }else{
                    print("success save data!")
                    DispatchQueue.main.async{
                        self.detail = ""
                        self.issue = ""
                        self.email = ""
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
    ReportBugView()
}
