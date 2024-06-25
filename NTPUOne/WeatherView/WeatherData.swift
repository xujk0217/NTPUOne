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
    let WindSpeed: Double
    let AirTemperature: Double
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
    let AirTemperature: Double
    let Occurred_at: OccurredAt
}

struct OccurredAt: Decodable {
    let DateTime: String
}
