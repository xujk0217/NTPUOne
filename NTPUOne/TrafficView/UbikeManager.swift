//
//  UbikeManager.swift
//  NTPUOne
//
//  Created by 許君愷 on 2024/6/24.
//

import Foundation

class UbikeManager: ObservableObject{
    
    @Published var bikeDatas: [UBResults]?
    @Published var errorMessage: String?
    
    func fetchData(){
        if let url = URL(string: "https://data.ntpc.gov.tw/api/datasets/010E5B15-3823-4B20-B401-B1CF000550C5/json?page=0&size=230"){
            let session = URLSession(configuration: .default)
            let task = session.dataTask(with: url) { data, response, error in
                if let error = error {
                    print("❌ Ubike fetch error: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        self.errorMessage = "網路錯誤: \(error.localizedDescription)"
                    }
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    print("📡 Ubike API status code: \(httpResponse.statusCode)")
                }
                
                let decoder = JSONDecoder()
                if let safeData = data{
                    do{
                        let results = try decoder.decode([UBResults].self, from: safeData)
                        print("✅ Ubike data decoded, total: \(results.count)")
                        
                        // 检查数组范围
                        if results.count >= 222 {
                            let subset = Array(results[169..<222])
                            DispatchQueue.main.async{
                                self.bikeDatas = subset
                                print("✅ Ubike data set successfully, count: \(subset.count)")
                            }
                        } else {
                            print("⚠️ Not enough data, got \(results.count), need at least 222")
                            // 如果数据不够，就使用全部数据
                            DispatchQueue.main.async{
                                self.bikeDatas = results
                                print("✅ Using all available data: \(results.count)")
                            }
                        }
                    }catch{
                        print("❌ Ubike decode error: \(error)")
                        DispatchQueue.main.async {
                            self.errorMessage = "資料格式錯誤: \(error.localizedDescription)"
                        }
                    }
                }
            }
            task.resume()
        }
    }
}
