import SwiftUI

struct MoreBikeView: View {
    @StateObject private var bikeManager = UbikeManager()
    @EnvironmentObject var adFree: AdFreeService

    var body: some View {
        Group {
            if let stations = bikeManager.bikeDatas {
                List {
                    BikeStatusView(manager: bikeManager)
                    Section("北大周邊 YouBike（\(stations.filter { !K.Bike.NTPUBikeNum.contains($0.sno) }.count) 站）") {
                        ForEach(stations.filter { !K.Bike.NTPUBikeNum.contains($0.sno) }) { stop in
                            if #available(iOS 17.0, *) {
                                NavigationLink(destination: bikeView(Bike: stop)) { stationRow(stop) }
                            } else {
                                NavigationLink(destination: noMapBikeView(Bike: stop)) { stationRow(stop) }
                            }
                        }
                    }
                    if !adFree.isAdFree {
                        Section {
                            NativeAdSectionView(style: .compact).frame(height: 140)
                        }.listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
                    }
                }
                .refreshable { await bikeManager.refresh() }
            } else if bikeManager.errorMessage != nil {
                BikeStatusView(manager: bikeManager).padding()
            } else {
                ProgressView(String(localized: "loading"))
            }
        }
        .navigationTitle("北大周邊 YouBike")
        .onAppear { bikeManager.fetchData() }
    }

    private func stationRow(_ stop: UBResults) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(stop.displayName)
            HStack {
                Label(stop.sbi_quantity, systemImage: "bicycle")
                Spacer()
                Label(stop.bemp, systemImage: "baseball.diamond.bases")
                Spacer()
                Text("\(Int(stop.distanceFromNTPU)) 公尺")
            }.font(.caption).foregroundStyle(.secondary)
        }
    }
}
