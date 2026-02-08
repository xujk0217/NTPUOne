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
    @StateObject var weatherManager = WeatherManager()
    @EnvironmentObject var adFree: AdFreeService
    
    // adview
    @State private var adHeight: CGFloat = 100
    @State private var rowWidth: CGFloat = 0
    
    var body: some View {
        NavigationStack {
            VStack{
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {

                        // 天氣卡
                        Group {
                            if let weatherData = weatherManager.weatherDatas,
                               let station = weatherData.records.Station.first {
                                WeatherSectionView(station: station)
//                                    .padding(.horizontal)
                            } else {
                                HStack {
                                    Spacer()
                                    VStack(spacing: 8) {
                                        Text("Loading…")
                                            .font(.headline)
                                            .foregroundStyle(.secondary)
                                            .onAppear { weatherManager.fetchData() }
                                        ProgressView()
                                    }
                                    Spacer()
                                }
                                .frame(height: 160)
                                .background {
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(Color(.tertiarySystemBackground))
                                        .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 5)
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .padding(.horizontal)
                            }
                        }

                        // 交通
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Traffic")
                                .font(.title3.weight(.semibold))
                                .padding(.horizontal)

                            CardRow(icon: "bicycle", title: "Ubike", iconTint: .green) {
                                if #available(iOS 17.0, *) { TrafficView() } else { BackTrafficView() }
                            }
                            .padding(.horizontal)
                        }

                        // 今天吃什麼
                        VStack(alignment: .leading, spacing: 10) {
                            Text("NTPU - 今天吃什麼？")
                                .font(.title3.weight(.semibold))
                                .padding(.horizontal)

                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                GridCard(icon: "cup.and.saucer.fill", title: "早餐", iconTint: .orange) { BreakfastView() }
                                GridCard(icon: "carrot.fill",        title: "午餐",  iconTint: .green)  { LunchView() }
                                GridCard(icon: "wineglass.fill",     title: "晚餐",  iconTint: .purple) { dinnerView() }
                                GridCard(icon: "moon.stars.fill",    title: "宵夜",  iconTint: .indigo) { MSView() }
                            }
                            .padding(.horizontal)
                        }

                        Spacer(minLength: 8)
                    }

                    }
                    .navigationTitle("PU Life")
                    .background(Color(.systemGroupedBackground))
            }
            if !adFree.isAdFree{
                // 廣告標記
                Section {
                    BannerAdView()
                        .frame(height: 50)
                }
            }
        }.onAppear {
            weatherManager.fetchData()
        }
    }
}

struct CardRow<Destination: View>: View {
    let icon: String
    let title: String
    var iconTint: Color = .accentColor
    @ViewBuilder var destination: () -> Destination

    var body: some View {
        NavigationLink {
            destination()
        } label: {
            HStack(spacing: 12) {
                IconBadge(systemName: icon, tint: iconTint)
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            .background(CardBackground())
        }
        .buttonStyle(.plain)
    }
}

struct GridCard<Destination: View>: View {
    let icon: String
    let title: String
    var iconTint: Color = .accentColor
    @ViewBuilder var destination: () -> Destination

    var body: some View {
        NavigationLink {
            destination()
        } label: {
            VStack(spacing: 8) {
                IconBadge(systemName: icon, tint: iconTint)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity, minHeight: 100)
            .background(CardBackground())
        }
        .buttonStyle(.plain)
    }
}

// 小元件：icon 徽章
private struct IconBadge: View {
    let systemName: String
    var tint: Color

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 24))
            .foregroundStyle(tint)
            .frame(width: 44, height: 44)
//            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
    }
}

// 小元件：卡片背景（適配 iOS 26 Liquid Glass 風格）
private struct CardBackground: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color(.tertiarySystemBackground))
            .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 5)
    }
}


struct WeatherSectionView: View {
    let station: Station

    var body: some View {
        let weather = station.WeatherElement.Weather
        let currentTemp = station.WeatherElement.AirTemperature
        let maxTemp = station.WeatherElement.DailyExtreme.DailyHigh.TemperatureInfo.AirTemperature
        let minTemp = station.WeatherElement.DailyExtreme.DailyLow.TemperatureInfo.AirTemperature
        let windSpeed = station.WeatherElement.WindSpeed
        let time = station.ObsTime.DateTime
        let humidity = station.WeatherElement.RelativeHumidity

        return Section {
            LifeView.weatherView(
                weathers: weather,
                currentTemperature: currentTemp,
                maxTemperature: maxTemp,
                minTemperature: minTemp,
                windSpeed: windSpeed,
                getTime: time,
                humidity: humidity
            )
        }
    }
}


#Preview {
    LifeView()
}

extension LifeView{
    struct weatherView: View {
        let weathers: String
        let currentTemperature: String
        let maxTemperature: String
        let minTemperature: String
        let windSpeed: String
        let getTime: String
        let humidity: String
        
        let cardShape = RoundedRectangle(cornerRadius: 14, style: .continuous)

        var body: some View {
            VStack(spacing: 12) {
                HStack(alignment: .center, spacing: 14) {

                    // 左側圖示徽章
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(tint.opacity(0.15))
                            .frame(width: 60, height: 60)
                        Image(systemName: weatherIcon(weather: weathers))
                            .font(.system(size: 26))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(tint)
                    }

                    // 中段：天氣描述 + 現在溫度
                    VStack(alignment: .leading, spacing: 2) {
                        Text(weathers)
                            .font(.headline)
                            .lineLimit(1)

                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(safeTemp(currentTemperature))
                                .font(.system(size: 34, weight: .bold, design: .rounded))
                            Text("現在")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()
                }

                // 指標膠囊列
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        StatChip(icon: "thermometer.sun.fill", text: "高 \(safeTemp(maxTemperature))", chipColor: .orange)
                        StatChip(icon: "thermometer.snowflake", text: "低 \(safeTemp(minTemperature))", chipColor: .blue)
                        Spacer()
                    }
                    HStack(spacing: 8) {
                        StatChip(icon: "wind", text: safeWind(windSpeed), chipColor: .teal)
                        StatChip(icon: "humidity", text: safeHumidity(humidity), chipColor: .indigo)
                        Spacer()
                        if let time = shortTimeString(getTime) {
                            Label("更新 \(time)", systemImage: "clock")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding(14)
            .background {
                cardShape.fill(Color(.tertiarySystemBackground))
                    .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 5)
            }
            .overlay(alignment: .leading) {
                Capsule()
                    .fill(tint)
                    .frame(width: 4)
                    .padding(.vertical, 8)
                    .padding(.leading, 6)
            }
            .clipShape(cardShape)
            .padding(.horizontal)
            .padding(.bottom, 6)
        }

        // MARK: - 小元件

        private struct StatChip: View {
            let icon: String
            let text: String
            var chipColor: Color

            var body: some View {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .imageScale(.small)
                    Text(text)
                        .font(.caption.weight(.semibold))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .foregroundStyle(chipColor)
                .background(chipColor.opacity(0.12), in: Capsule())
            }
        }

        // MARK: - Helpers

        private var tint: Color { tintForWeather(weathers) }

        private func safeTemp(_ s: String) -> String {
            (s == "-99" || s.isEmpty) ? "—" : "\(s)°C"
        }
        private func safeWind(_ s: String) -> String {
            (s == "-99" || s.isEmpty) ? "—" : "\(s) m/s"
        }
        private func safeHumidity(_ s: String) -> String {
            (s == "-99" || s.isEmpty) ? "—" : "\(s)%"
        }
        private func shortTimeString(_ s: String) -> String? {
            // 取 "YYYY-MM-DD HH:mm..." 的 HH:mm
            guard s.count >= 16 else { return nil }
            let start = s.index(s.startIndex, offsetBy: 11)
            let end = s.index(start, offsetBy: 5, limitedBy: s.endIndex) ?? s.endIndex
            return String(s[start..<end])
        }

        // 簡單的色彩對應（可自行調整）
        private func tintForWeather(_ text: String) -> Color {
            if text.contains("雷") { return .purple }
            if text.contains("雪") { return .indigo }
            if text.contains("雨") { return .teal }
            if text.contains("陰") { return .gray }
            if text.contains("多雲") { return .blue }
            return .orange // 晴
        }

        func weatherIcon(weather: String) -> String {
            switch weather {
            case "晴": return "sun.max"
            case "晴有霾", "晴有靄", "晴有霧": return "sun.haze"
            case "晴有閃電", "晴有雷聲", "晴有雷": return "sun.bolt"
            case "晴有雨", "晴有陣雨": return "cloud.sun.rain"
            case "晴有雨雪", "晴有大雪", "晴有雪珠", "晴有冰珠", "晴陣雨雪": return "cloud.sun.snow"
            case "晴有雹": return "cloud.sun.hail"
            case "晴有雷雨", "晴大雷雨": return "cloud.sun.bolt.rain"
            case "晴有雷雪": return "cloud.sun.snow"
            case "晴有雷雹", "晴大雷雹": return "cloud.sun.bolt.hail"

            case "多雲": return "cloud.sun"
            case "多雲有霾", "多雲有靄", "多雲有霧": return "cloud.sun.haze"
            case "多雲有閃電", "多雲有雷聲", "多雲有雷": return "cloud.bolt"
            case "多雲有雨", "多雲有陣雨": return "cloud.rain"
            case "多雲有雨雪", "多雲陣雨雪": return "cloud.sleet"
            case "多雲有大雪": return "cloud.snow"
            case "多雲有雪珠", "多雲有冰珠": return "cloud.snow"
            case "多雲有雹": return "cloud.hail"
            case "多雲有雷雨", "多雲大雷雨": return "cloud.bolt.rain"
            case "多雲有雷雪": return "cloud.snow"
            case "多雲有雷雹", "多雲大雷雹": return "cloud.bolt.hail"

            case "陰": return "cloud"
            case "陰有霾", "陰有靄", "陰有霧": return "cloud.haze"
            case "陰有閃電", "陰有雷聲", "陰有雷": return "cloud.bolt"
            case "陰有雨", "陰有陣雨": return "cloud.rain"
            case "陰有雨雪", "陰陣雨雪": return "cloud.sleet"
            case "陰有大雪": return "cloud.snow"
            case "陰有雪珠", "陰有冰珠": return "cloud.snow"
            case "陰有雹": return "cloud.hail"
            case "陰有雷雨", "陰大雷雨": return "cloud.bolt.rain"
            case "陰有雷雪": return "cloud.snow"
            case "陰有雷雹", "陰大雷雹": return "cloud.bolt.hail"

            case "有霾", "有靄", "有霧": return "cloud.haze"
            case "有閃電", "有雷聲", "有雷": return "cloud.bolt"
            case "有雨", "有陣雨": return "cloud.rain"
            case "有雨雪", "陣雨雪": return "cloud.sleet"
            case "有大雪", "有雪珠", "有冰珠": return "cloud.snow"
            case "有雹": return "cloud.hail"
            case "有雷雨", "大雷雨": return "cloud.bolt.rain"
            case "有雷雪": return "cloud.snow"
            case "有雷雹", "大雷雹": return "cloud.bolt.hail"

            default: return "questionmark.circle"
            }
        }
    }
}
