//
//  WeatherManager.swift
//  NTPUOne
//
//  Created by 許君愷 on 2024/6/25.
//

import Foundation

class WeatherManager: ObservableObject{
    
    @Published var weatherDatas: WeatherResults?
    
    func fetchData() {
            if let url = URL(string: "https://opendata.cwa.gov.tw/api/v1/rest/datastore/O-A0003-001?Authorization=CWA-0DC17557-999D-4A6F-949A-0F8418E1C095&StationId=72AI40") {
                let session = URLSession(configuration: .default)
                let task = session.dataTask(with: url) { data, response, error in
                    if error == nil {
                        let decoder = JSONDecoder()
                        if let safeData = data {
                            do {
                                let results = try decoder.decode(WeatherResults.self, from: safeData)
                                DispatchQueue.main.async {
                                    self.weatherDatas = results
                                }
                                print("success get weather data")
                            } catch {
                                print(error)
                            }
                        }
                    }
                }
                task.resume()
            }
        }
    }
