//
//  LifeView.swift
//  NTPUOne
//
//  Created by 許君愷 on 2024/8/10.
//

import SwiftUI
import SwiftData
import SafariServices
import FirebaseCore
import FirebaseFirestore
import GoogleMobileAds
import AppTrackingTransparency
import MapKit
import Firebase

struct LifeView: View {
    @ObservedObject var weatherManager = WeatherManager()
    var body: some View {
        NavigationStack {
            VStack{
                if let weatherData = weatherManager.weatherDatas {
                    let station = weatherData.records.Station.first!
                    ScrollView {
                        VStack(alignment: .leading) {
                            Section {
                                weatherView(
                                    weathers: station.WeatherElement.Weather,
                                    currentTemperature: station.WeatherElement.AirTemperature,
                                    maxTemperature: station.WeatherElement.DailyExtreme.DailyHigh.TemperatureInfo.AirTemperature,
                                    minTemperature: station.WeatherElement.DailyExtreme.DailyLow.TemperatureInfo.AirTemperature,
                                    windSpeed: station.WeatherElement.WindSpeed,
                                    getTime: station.ObsTime.DateTime,
                                    humidity: station.WeatherElement.RelativeHumidity
                                )
                            } header: {
                                Text("現在天氣")
                                    .foregroundStyle(Color.black)
                                    .padding(.horizontal)
                            }
                            Divider()
                            VStack(alignment: .leading) {
                                Section {
                                    VStack(alignment: .leading, spacing: 10) {
                                        NavigationLink{
                                            BreakfastView()
                                        } label: {
                                            HStack {
                                                Image(systemName: "cup.and.saucer")
                                                    .resizable()
                                                    .aspectRatio(contentMode: .fit)
                                                    .frame(width: 50, height: 50)
                                                    .foregroundStyle(Color.black)
                                                    .padding()
                                                    .padding(.leading)
                                                Text("早餐")
                                                    .padding()
                                                    .frame(alignment: .leading)
                                                    .foregroundStyle(Color.black)
                                                
                                                Spacer()
                                            }
                                            .frame(height: 100)
                                            .background(Color.white)
                                            .cornerRadius(10)
                                            .padding(.horizontal)
                                        }
                                        NavigationLink(destination: LunchView()) {
                                            HStack {
                                                Image(systemName: "carrot")
                                                    .resizable()
                                                    .aspectRatio(contentMode: .fit)
                                                    .frame(width: 50, height: 50)
                                                    .foregroundStyle(Color.black)
                                                    .padding()
                                                    .padding(.leading)
                                                Text("午餐")
                                                    .padding()
                                                    .frame(alignment: .leading)
                                                    .foregroundStyle(Color.black)
                                                
                                                Spacer()
                                            }
                                            .frame(height: 100)
                                            .background(Color.white)
                                            .cornerRadius(10)
                                            .padding(.horizontal)
                                        }
                                        NavigationLink(destination: dinnerView()) {
                                            HStack {
                                                Image(systemName: "wineglass")
                                                    .resizable()
                                                    .aspectRatio(contentMode: .fit)
                                                    .frame(width: 50, height: 50)
                                                    .foregroundStyle(Color.black)
                                                    .padding()
                                                    .padding(.leading)
                                                Text("晚餐")
                                                    .padding()
                                                    .frame(alignment: .leading)
                                                    .foregroundStyle(Color.black)
                                                
                                                Spacer()
                                            }
                                            .frame(height: 100)
                                            .background(Color.white)
                                            .cornerRadius(10)
                                            .padding(.horizontal)
                                        }
                                        NavigationLink(destination: MSView()) {
                                            HStack {
                                                Image(systemName: "cross")
                                                    .resizable()
                                                    .aspectRatio(contentMode: .fit)
                                                    .frame(width: 50, height: 50)
                                                    .foregroundStyle(Color.black)
                                                    .padding()
                                                    .padding(.leading)
                                                Text("宵夜")
                                                    .padding()
                                                    .frame(alignment: .leading)
                                                    .foregroundStyle(Color.black)
                                                
                                                Spacer()
                                            }
                                            .frame(height: 100)
                                            .background(Color.white)
                                            .cornerRadius(10)
                                            .padding(.horizontal)
                                        }
                                        Spacer()
                                    }
                                } header: {
                                    Text("NTPU-今天吃什麼？")
                                        .foregroundStyle(Color.black)
                                        .padding(.horizontal)
                                }
                            }
                        }
                    }
                    .navigationTitle("PU Life")
                    .background(Color.gray.opacity(0.1))
                }else{
                    Text("Loading...")
                        .onAppear {
                            weatherManager.fetchData()
                        }
                    ProgressView()
                }
            }
        }.onAppear {
            weatherManager.fetchData()
        }
    }
}

#Preview {
    LifeView()
}

extension LifeView{
    struct weatherView: View{
        let weathers: String
        let currentTemperature: Double
        let maxTemperature: Double
        let minTemperature: Double
        let windSpeed: Double
        let getTime: String
        let humidity: Double
        var body: some View{
            VStack {
                HStack {
                    Spacer()
                    VStack {
                        Image(systemName: weatherIcon(weather: weathers))
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 50, height: 50)
                            .padding()
                        Text(weathers)
                    }
                    Spacer()
                    HStack {
                        VStack(alignment: .leading) {
                            HStack {
                                Image(systemName: "thermometer.medium")
                                Text(" \(currentTemperature, specifier: "%.1f")°C")
                                    .font(.title3.bold())
                            }
                            HStack {
                                Image(systemName: "thermometer.sun")
                                Text(" \(maxTemperature, specifier: "%.1f")°C")
                                    .font(.title3)
                            }
                            HStack {
                                Image(systemName: "thermometer.snowflake")
                                Text(" \(minTemperature, specifier: "%.1f")°C")
                                    .font(.title3)
                            }
                            HStack {
                                Image(systemName: "wind")
                                Text(" \(windSpeed, specifier: "%.1f") m/s")
                                    .font(.title3)
                            }
                        }
                        VStack(alignment: .leading) {
                            HStack {
                                Image(systemName: "clock.badge")
                                Text(getTime.substring(from: 11, length: 5))
                                    .font(.title3)
                            }
                            HStack {
                                if currentTemperature > 27{
                                    Image(systemName: "face.dashed")
                                }else if currentTemperature > 16{
                                    Image(systemName: "face.smiling")
                                }else{
                                    Image(systemName: "face.dashed.fill")
                                }
                                if currentTemperature > 30{
                                    Text("快蒸發了")
                                        .font(.title3)
                                }else if currentTemperature >= 28 {
                                    Text("好叻啊")
                                        .font(.title3)
                                }else if currentTemperature >= 23{
                                    Text("小熱")
                                        .font(.title3)
                                }else if currentTemperature > 15{
                                    Text("舒服")
                                        .font(.title3)
                                }else if currentTemperature > 11{
                                    Text("小冷")
                                        .font(.title3)
                                }else{
                                    Text("凍凍腦")
                                        .font(.title3)
                                }
                            }
                            HStack {
                                Text(" ")
                                    .font(.title3)
                            }
                            HStack {
                                Text(" ")
                                    .font(.title3)
                            }
                        }
                    }
                    Spacer()
                }
                .frame(height: 150)
                .background(Color.white)
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.bottom)
            }
        }
        func weatherIcon(weather: String) -> String {
            switch weather {
            case "晴": return "sun.max"
            case "晴有霾": return "sun.haze"
            case "晴有靄": return "sun.haze"
            case "晴有閃電": return "sun.bolt"
            case "晴有雷聲": return "sun.bolt"
            case "晴有霧": return "sun.haze"
            case "晴有雨": return "cloud.sun.rain"
            case "晴有雨雪": return "cloud.sun.snow"
            case "晴有大雪": return "cloud.sun.snow"
            case "晴有雪珠": return "cloud.sun.snow"
            case "晴有冰珠": return "cloud.sun.snow"
            case "晴有陣雨": return "cloud.sun.rain"
            case "晴陣雨雪": return "cloud.sun.snow"
            case "晴有雹": return "cloud.sun.hail"
            case "晴有雷雨": return "cloud.sun.bolt.rain"
            case "晴有雷雪": return "cloud.sun.snow"
            case "晴有雷雹": return "cloud.sun.bolt.hail"
            case "晴大雷雨": return "cloud.sun.bolt.rain"
            case "晴大雷雹": return "cloud.sun.bolt.hail"
            case "晴有雷": return "sun.bolt"
                
            case "多雲": return "cloud.sun"
            case "多雲有霾": return "cloud.sun.haze"
            case "多雲有靄": return "cloud.sun.haze"
            case "多雲有閃電": return "cloud.bolt"
            case "多雲有雷聲": return "cloud.bolt"
            case "多雲有霧": return "cloud.sun.haze"
            case "多雲有雨": return "cloud.rain"
            case "多雲有雨雪": return "cloud.sleet"
            case "多雲有大雪": return "cloud.snow"
            case "多雲有雪珠": return "cloud.snow"
            case "多雲有冰珠": return "cloud.snow"
            case "多雲有陣雨": return "cloud.rain"
            case "多雲陣雨雪": return "cloud.sleet"
            case "多雲有雹": return "cloud.hail"
            case "多雲有雷雨": return "cloud.bolt.rain"
            case "多雲有雷雪": return "cloud.snow"
            case "多雲有雷雹": return "cloud.bolt.hail"
            case "多雲大雷雨": return "cloud.bolt.rain"
            case "多雲大雷雹": return "cloud.bolt.hail"
            case "多雲有雷": return "cloud.bolt"
                
            case "陰": return "cloud"
            case "陰有霾": return "cloud.haze"
            case "陰有靄": return "cloud.haze"
            case "陰有閃電": return "cloud.bolt"
            case "陰有雷聲": return "cloud.bolt"
            case "陰有霧": return "cloud.haze"
            case "陰有雨": return "cloud.rain"
            case "陰有雨雪": return "cloud.sleet"
            case "陰有大雪": return "cloud.snow"
            case "陰有雪珠": return "cloud.snow"
            case "陰有冰珠": return "cloud.snow"
            case "陰有陣雨": return "cloud.rain"
            case "陰陣雨雪": return "cloud.sleet"
            case "陰有雹": return "cloud.hail"
            case "陰有雷雨": return "cloud.bolt.rain"
            case "陰有雷雪": return "cloud.snow"
            case "陰有雷雹": return "cloud.bolt.hail"
            case "陰大雷雨": return "cloud.bolt.rain"
            case "陰大雷雹": return "cloud.bolt.hail"
            case "陰有雷": return "cloud.bolt"
                
            case "有霾": return "cloud.haze"
            case "有靄": return "cloud.haze"
            case "有閃電": return "cloud.bolt"
            case "有雷聲": return "cloud.bolt"
            case "有霧": return "cloud.haze"
            case "有雨": return "cloud.rain"
            case "有雨雪": return "cloud.sleet"
            case "有大雪": return "cloud.snow"
            case "有雪珠": return "cloud.snow"
            case "有冰珠": return "cloud.snow"
            case "有陣雨": return "cloud.rain"
            case "陣雨雪": return "cloud.sleet"
            case "有雹": return "cloud.hail"
            case "有雷雨": return "cloud.bolt.rain"
            case "有雷雪": return "cloud.snow"
            case "有雷雹": return "cloud.bolt.hail"
            case "大雷雨": return "cloud.bolt.rain"
            case "大雷雹": return "cloud.bolt.hail"
            case "有雷": return "cloud.bolt"
                
            default: return "questionmark.circle"
            }
        }
    }
}
