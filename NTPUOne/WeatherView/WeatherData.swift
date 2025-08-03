//
//  WeatherData.swift
//  NTPUOne
//
//  Created by 許君愷 on 2024/6/25.
//

import Foundation

struct WeatherResults: Decodable {
    let records: Records
}

struct Records: Decodable {
    let Station: [Station]
}

struct Station: Decodable {
    let StationName: String
    let StationId: String
    let ObsTime: ObsTime
    let WeatherElement: WeatherElement
}

struct ObsTime: Decodable {
    let DateTime: String
}

struct WeatherElement: Decodable {
    let Weather: String
    let WindSpeed: String
    let AirTemperature: String
    let RelativeHumidity: String
    let DailyExtreme: DailyExtreme
}

struct DailyExtreme: Decodable {
    let DailyHigh: DailyHigh
    let DailyLow: DailyLow
}

struct DailyHigh: Decodable {
    let TemperatureInfo: TemperatureInfo
}

struct DailyLow: Decodable {
    let TemperatureInfo: TemperatureInfo
}

struct TemperatureInfo: Decodable {
    let AirTemperature: String
    let Occurred_at: OccurredAt
}

struct OccurredAt: Decodable {
    let DateTime: String
}

//晴 多雲 陰
//有霾 有靄 有閃電 有雷聲 有霧 有雨 有雨雪 有大雪 有雪珠 有冰珠 有陣雨 陣雨雪 有雹 有雷雨 有雷雪 有雷雨 有雷雹 大雷雨 有雷雨 大雷雹  有雷
