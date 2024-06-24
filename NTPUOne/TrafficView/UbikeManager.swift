//
//  UbikeManager.swift
//  NTPUOne
//
//  Created by 許君愷 on 2024/6/24.
//

import Foundation

class UbikeManager: ObservableObject{
    
    @Published var bikeDatas = [UBResults]()
    
    func fetchData(){
        if let url = URL(string: "https://data.ntpc.gov.tw/api/datasets/010E5B15-3823-4B20-B401-B1CF000550C5/json?page=0&size=210"){
            let session = URLSession(configuration: .default)
            let task = session.dataTask(with: url) { data, response, error in
                if error == nil{
                    let decoder = JSONDecoder()
                    if let safeData = data{
                        do{
                            let results = try decoder.decode([UBResults].self, from: safeData)
                            let subset = Array(results[170..<209])
                            DispatchQueue.main.async{
                                self.bikeDatas = subset
                            }
                            print("success get bike data")
                        }catch{
                            print(error)
                        }
                    }
                }
            }
            task.resume()
        }
    }
}
