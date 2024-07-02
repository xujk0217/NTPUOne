//
//  ContactMeView.swift
//  NTPUOne
//
//  Created by 許君愷 on 2024/6/26.
//

import SwiftUI
import SafariServices

struct ContactMeView: View {
    @State private var email: String = "kevin16021777@gmail.com"
    @State private var semail: String = "s411285047@gm.ntpu.edu.tw"
    var body: some View {
        VStack {
            List {
                Section{
                    HStack{
                        Image(systemName: "figure.rolling")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 50, height: 50)
                        Divider()
                        Text("xujk")
                            .font(.title3)
                            .padding()
                    }
                } header: {
                    Text("名字")
                }
                Section {
                    Button {
                        UIPasteboard.general.string = self.email
                    } label: {
                        HStack {
                            Text("email: \(email)")
                                .foregroundStyle(Color.black)
                            Spacer()
                            Image(systemName: "doc.on.doc")
                        }
                    }
                    Button {
                        UIPasteboard.general.string = self.semail
                    } label: {
                        HStack {
                            Text("email: \(semail)")
                                .foregroundStyle(Color.black)
                            Spacer()
                            Image(systemName: "doc.on.doc")
                        }
                    }
                    Text("My Instagram")
                        .onTapGesture {
                            openURL("https://www.instagram.com/xujk_06217?igsh=bms2b3djOGdqNGtv&utm_source=qr")
                        }
                        .foregroundStyle(Color.blue)
                } header: {
                    Text("聯絡方式")
                }
            }
        }.navigationTitle("Contact")
    }
}

#Preview {
    ContactMeView()
}

extension ContactMeView{
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
}
