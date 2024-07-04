//
//  PrivacyPolicyView.swift
//  NTPUOne
//
//  Created by 許君愷 on 2024/6/26.
//

import SwiftUI

struct PrivacyPolicyView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    Group {
                        Text("This privacy policy applies to the NTPU one app (hereby referred to as \"Application\") for mobile devices that was created by xujk (hereby referred to as \"Service Provider\") as a Free service. This service is intended for use \"AS IS\".")
                            .padding(.bottom, 10)
                    }
                    
                    Group {
                        Text("Information Collection and Use")
                            .font(.headline)
                            .bold()
                        Text("The Application collects information when you download and use it. This information may include information such as:")
                        Text("• Your device's Internet Protocol address (e.g. IP address)")
                        Text("• The pages of the Application that you visit, the time and date of your visit, the time spent on those pages")
                        Text("• The time spent on the Application")
                        Text("• The operating system you use on your mobile device")
                        Text("The Application does not gather precise information about the location of your mobile device.")
                        Text("The Service Provider may use the information you provided to contact you from time to time to provide you with important information, required notices, and marketing promotions.")
                        Text("For a better experience, while using the Application, the Service Provider may require you to provide us with certain personally identifiable information [add whatever else you collect here, e.g. users name, address, location, pictures]. The information that the Service Provider requests will be retained by them and used as described in this privacy policy.")
                    }
                     
                    Group {
                        Text("Third Party Access")
                            .font(.headline)
                            .bold()
                        Text("Only aggregated, anonymized data is periodically transmitted to external services to aid the Service Provider in improving the Application and their service. The Service Provider may share your information with third parties in the ways that are described in this privacy statement.")
                        Text("Please note that the Application utilizes third-party services that have their own Privacy Policy about handling data. Below are the links to the Privacy Policy of the third-party service providers used by the Application:")
                        Link("AdMob", destination: URL(string: "https://policies.google.com/privacy")!)
                        Link("Google Analytics for Firebase", destination: URL(string: "https://firebase.google.com/policies/analytics")!)
                        Link("Firebase Crashlytics", destination: URL(string: "https://firebase.google.com/support/privacy/")!)
                        Text("The Service Provider may disclose User Provided and Automatically Collected Information:")
                        Text("• as required by law, such as to comply with a subpoena, or similar legal process;")
                        Text("• when they believe in good faith that disclosure is necessary to protect their rights, protect your safety or the safety of others, investigate fraud, or respond to a government request;")
                        Text("• with their trusted service providers who work on their behalf, do not have an independent use of the information we disclose to them, and have agreed to adhere to the rules set forth in this privacy statement.")
                    }
                    
                    Group {
                        Text("External Links")
                            .font(.headline)
                            .bold()
                        Text("The Application may contain links to other websites. If you click on a third-party link, you will be directed to that site. Note that these external sites are not operated by the Service Provider. Therefore, it is strongly advised to review the Privacy Policy of these websites. The Service Provider has no control over, and assumes no responsibility for the content, privacy policies, or practices of any third-party sites or services.")
                        Text("The Service Provider does not collect any personal information or data from these external links. By using these links, you are subject to the terms and conditions of the respective websites.")
                    }
                    
                    Group {
                        Text("Opt-Out Rights")
                            .font(.headline)
                            .bold()
                        Text("You can stop all collection of information by the Application easily by uninstalling it. You may use the standard uninstall processes as may be available as part of your mobile device or via the mobile application marketplace or network.")
                    }
                    
                    Group {
                        Text("Data Retention Policy")
                            .font(.headline)
                            .bold()
                        Text("The Service Provider will retain User Provided data for as long as you use the Application and for a reasonable time thereafter. If you'd like them to delete User Provided Data that you have provided via the Application, please contact them at kevin16021777@gmail.com and they will respond in a reasonable time.")
                    }
                    
                    Group {
                        Text("Security")
                            .font(.headline)
                            .bold()
                        Text("The Service Provider is concerned about safeguarding the confidentiality of your information. The Service Provider provides physical, electronic, and procedural safeguards to protect information the Service Provider processes and maintains.")
                    }
                    
                    Group {
                        Text("Changes")
                            .font(.headline)
                            .bold()
                        Text("This Privacy Policy may be updated from time to time for any reason. The Service Provider will notify you of any changes to the Privacy Policy by updating this page with the new Privacy Policy. You are advised to consult this Privacy Policy regularly for any changes, as continued use is deemed approval of all changes.")
                        Text("This privacy policy is effective as of 2024-07-11.")
                    }
                    
                    Group {
                        Text("Your Consent")
                            .font(.headline)
                            .bold()
                        Text("By using the Application, you are consenting to the processing of your information as set forth in this Privacy Policy now and as amended by us.")
                    }
                    
                    Group {
                        Text("Contact Us")
                            .font(.headline)
                            .bold()
                        Text("If you have any questions regarding privacy while using the Application, or have questions about the practices, please contact the Service Provider via email at kevin16021777@gmail.com.")
                    }
                    
                    Group {
                        Text("This privacy policy page was generated by App Privacy Policy Generator.")
                            .italic()
                    }
                    
                    NavigationLink {
                        ContactMeView()
                    } label: {
                        Text("Contact me")
                            .foregroundColor(.blue)
                            .underline()
                    }
                }
                .padding()
                .navigationTitle("Privacy Policy")
            }
        }
    }
}

#Preview {
    PrivacyPolicyView()
}

