import SwiftUI
import MapKit
import UIKit

struct CampusMapView: View {
    @StateObject private var breakfastManager = FManager()
    @StateObject private var lunchManager = FManager()
    @StateObject private var dinnerManager = FManager()
    @StateObject private var snackManager = FManager()
    @StateObject private var ubikeManager = UbikeManager()

    @State private var selectedLayer: CampusMapLayer = .all
    @State private var campusImageScale: CGFloat = 1
    @State private var transientImageScale: CGFloat = 1
    @State private var campusImageOffset: CGSize = .zero
    @State private var transientImageOffset: CGSize = .zero
    @State private var landmarkPins: [CampusMapPin] = []
    @State private var isLoadingLandmarks = false

    private let center = CLLocationCoordinate2D(latitude: 24.9424, longitude: 121.3682)

    private var restaurantPins: [CampusLivePin] {
        allFoods
            .filter { $0.lat != 0 && $0.lng != 0 }
            .map {
                CampusLivePin(
                    id: "restaurant-\($0.id ?? $0.store)-\($0.lat)-\($0.lng)",
                    title: $0.store,
                    subtitle: $0.time,
                    coordinate: CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lng),
                    kind: .restaurants
                )
            }
    }

    private var ubikePins: [CampusLivePin] {
        (ubikeManager.bikeDatas ?? []).compactMap { stop in
            guard let latitude = Double(stop.lat), let longitude = Double(stop.lng) else { return nil }
            return CampusLivePin(
                id: "ubike-\(stop.sno)",
                title: stop.sna.replacingOccurrences(of: "YouBike2.0_", with: ""),
                subtitle: "可借 \(stop.sbi_quantity) / 可還 \(stop.bemp)",
                coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
                kind: .ubike
            )
        }
    }

    private var allFoods: [FDetail] {
        (breakfastManager.Food ?? []) + (lunchManager.Food ?? []) + (dinnerManager.Food ?? []) + (snackManager.Food ?? [])
    }

    private var visibleCampusResources: [CampusResource] {
        guard selectedLayer != .all else { return CampusResource.defaults }
        return CampusResource.defaults.filter { $0.layer == selectedLayer }
    }

    private var allMapPins: [CampusMapPin] {
        landmarkPins + restaurantPins.map(CampusMapPin.init) + ubikePins.map(CampusMapPin.init)
    }

    private var visibleMapPins: [CampusMapPin] {
        guard selectedLayer != .all else { return allMapPins }
        return allMapPins.filter { $0.kind == selectedLayer }
    }

    private var availableLayers: [CampusMapLayer] {
        [.all] + CampusMapLayer.allCases.dropFirst().filter { layer in
            allMapPins.contains { $0.kind == layer }
        }
    }

    var body: some View {
        List {
            headerSection
            mapSection
            campusImageSection
            campusResourcesSection
            liveResourcesSection
        }
        .navigationTitle(String(localized: "campus_map_title"))
        .onAppear(perform: loadLiveData)
    }

    private var headerSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(String(localized: "campus_map_header"))
                            .font(.headline)
                        Text(String(localized: "campus_map_header_subtitle"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "map")
                        .font(.title3)
                        .foregroundStyle(.blue)
                        .padding(10)
                        .background(Color.blue.opacity(0.12), in: Circle())
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(availableLayers) { layer in
                            Button {
                                selectedLayer = layer
                            } label: {
                                Label(layer.title, systemImage: layer.icon)
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 7)
                                    .foregroundStyle(selectedLayer == layer ? .white : layer.tint)
                                    .background(selectedLayer == layer ? layer.tint : layer.tint.opacity(0.12), in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private var mapSection: some View {
        Section {
            if #available(iOS 17.0, *) {
                Map(initialPosition: .camera(MapCamera(centerCoordinate: center, distance: 1800))) {
                    ForEach(visibleMapPins) { pin in
                        Marker(pin.title, systemImage: pin.kind.icon, coordinate: pin.coordinate)
                            .tint(pin.kind.tint)
                    }
                }
                .frame(height: 260)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            } else {
                Label(String(localized: "campus_map_ios17_hint"), systemImage: "map")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text(String(localized: "campus_live_map_title"))
        } footer: {
            Text(String(localized: "campus_live_map_footer"))
        }
    }

    private var campusImageSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                if let image = UIImage(named: "NTPUmap") {
                    GeometryReader { proxy in
                        let zoomScale = campusImageScale * transientImageScale
                        ZStack {
                            Color(.secondarySystemBackground)
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: proxy.size.width, height: proxy.size.height)
                                .scaleEffect(zoomScale)
                                .offset(CGSize(width: campusImageOffset.width + transientImageOffset.width, height: campusImageOffset.height + transientImageOffset.height))
                        }
                        .contentShape(Rectangle())
                        .clipped()
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in transientImageScale = value }
                                .onEnded { value in
                                    campusImageScale = min(max(campusImageScale * value, 1), 4)
                                    transientImageScale = 1
                                    if campusImageScale == 1 { campusImageOffset = .zero }
                                }
                        )
                        .simultaneousGesture(
                            DragGesture()
                                .onChanged { value in
                                    guard campusImageScale > 1 else { return }
                                    transientImageOffset = value.translation
                                }
                                .onEnded { value in
                                    guard campusImageScale > 1 else {
                                        transientImageOffset = .zero
                                        campusImageOffset = .zero
                                        return
                                    }
                                    campusImageOffset.width += value.translation.width
                                    campusImageOffset.height += value.translation.height
                                    transientImageOffset = .zero
                                }
                        )
                    }
                    .frame(height: 320)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Label(String(localized: "campus_image_missing_title"), systemImage: "photo.on.rectangle.angled")
                            .font(.subheadline.weight(.semibold))
                        Text(String(localized: "campus_image_missing_detail"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
        } header: {
            Text(String(localized: "campus_image_title"))
        }
    }

    private var campusResourcesSection: some View {
        Section {
            ForEach(visibleCampusResources) { resource in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: resource.layer.icon)
                        .foregroundStyle(resource.layer.tint)
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(resource.title)
                            .font(.subheadline.weight(.semibold))
                        Text(resource.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
        } header: {
            Text(String(localized: "campus_resources_title"))
        } footer: {
            Text(String(localized: "campus_resources_footer"))
        }
    }

    private var liveResourcesSection: some View {
        Section {
            if selectedLayer == .all || selectedLayer == .restaurants {
                liveSummaryRow(icon: "fork.knife", tint: .orange, title: String(localized: "restaurant"), detail: restaurantPins.isEmpty ? String(localized: "campus_restaurants_loading") : String(format: String(localized: "campus_restaurants_count_format"), restaurantPins.count))
            }

            if selectedLayer == .all || selectedLayer == .ubike {
                liveSummaryRow(icon: "bicycle", tint: .green, title: "Ubike", detail: ubikePins.isEmpty ? (ubikeManager.errorMessage ?? String(localized: "today_hub_ubike_loading")) : String(format: String(localized: "campus_ubike_count_format"), ubikePins.count))
            }
        } header: {
            Text(String(localized: "campus_live_status_title"))
        }
    }

    private func liveSummaryRow(icon: String, tint: Color, title: String, detail: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(tint)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func loadLiveData() {
        if breakfastManager.Food == nil { breakfastManager.loadF(whichDiet: "B") }
        if lunchManager.Food == nil { lunchManager.loadF(whichDiet: "L") }
        if dinnerManager.Food == nil { dinnerManager.loadF(whichDiet: "D") }
        if snackManager.Food == nil { snackManager.loadF(whichDiet: "M") }
        if ubikeManager.bikeDatas == nil { ubikeManager.fetchData() }
        loadCampusLandmarks()
    }

    private func loadCampusLandmarks() {
        guard landmarkPins.isEmpty, !isLoadingLandmarks else { return }
        isLoadingLandmarks = true

        let searchRegion = MKCoordinateRegion(
            center: center,
            latitudinalMeters: 2_400,
            longitudinalMeters: 2_400
        )
        let campusCenter = CLLocation(latitude: center.latitude, longitude: center.longitude)

        Task {
            var foundPins: [CampusMapPin] = []
            for landmark in CampusMapLandmark.defaults {
                let request = MKLocalSearch.Request()
                request.naturalLanguageQuery = landmark.query
                request.region = searchRegion

                do {
                    let response = try await MKLocalSearch(request: request).start()
                    guard let mapItem = response.mapItems.first(where: {
                        campusCenter.distance(from: $0.placemark.location ?? campusCenter) < 1_600
                    }) else {
                        continue
                    }
                    let coordinate = mapItem.placemark.coordinate
                    guard CLLocationCoordinate2DIsValid(coordinate) else { continue }
                    foundPins.append(
                        CampusMapPin(
                            id: "landmark-\(landmark.id)",
                            title: landmark.title,
                            subtitle: landmark.detail,
                            coordinate: coordinate,
                            kind: landmark.layer
                        )
                    )
                } catch {
                    continue
                }
            }

            landmarkPins = foundPins
            isLoadingLandmarks = false
            if !availableLayers.contains(selectedLayer) {
                selectedLayer = .all
            }
        }
    }

}

private enum CampusMapLayer: String, CaseIterable, Identifiable {
    case all
    case restaurants
    case ubike
    case libraryAdmin
    case teaching
    case dormActivity

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return String(localized: "campus_layer_all")
        case .restaurants: return String(localized: "restaurant")
        case .ubike: return "Ubike"
        case .libraryAdmin: return String(localized: "campus_layer_library_admin")
        case .teaching: return String(localized: "campus_layer_teaching")
        case .dormActivity: return String(localized: "campus_layer_dorm_activity")
        }
    }

    var icon: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .restaurants: return "fork.knife"
        case .ubike: return "bicycle"
        case .libraryAdmin: return "building.columns"
        case .teaching: return "graduationcap"
        case .dormActivity: return "figure.socialdance"
        }
    }

    var tint: Color {
        switch self {
        case .all: return .blue
        case .restaurants: return .orange
        case .ubike: return .green
        case .libraryAdmin: return .indigo
        case .teaching: return .purple
        case .dormActivity: return .teal
        }
    }
}

private struct CampusLivePin: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let coordinate: CLLocationCoordinate2D
    let kind: CampusMapLayer
}

private struct CampusMapPin: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let coordinate: CLLocationCoordinate2D
    let kind: CampusMapLayer

    init(id: String, title: String, subtitle: String, coordinate: CLLocationCoordinate2D, kind: CampusMapLayer) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.coordinate = coordinate
        self.kind = kind
    }

    init(_ livePin: CampusLivePin) {
        self.init(
            id: livePin.id,
            title: livePin.title,
            subtitle: livePin.subtitle,
            coordinate: livePin.coordinate,
            kind: livePin.kind
        )
    }
}

private struct CampusMapLandmark {
    let id: String
    let title: String
    let detail: String
    let query: String
    let layer: CampusMapLayer

    static let defaults: [CampusMapLandmark] = [
        CampusMapLandmark(id: "admin", title: "行政大樓", detail: "教務、行政與學生服務窗口。", query: "國立臺北大學 行政大樓", layer: .libraryAdmin),
        CampusMapLandmark(id: "library", title: "圖書資訊大樓", detail: "圖書館、借閱與自習資源。", query: "國立臺北大學 圖書資訊大樓", layer: .libraryAdmin),
        CampusMapLandmark(id: "business", title: "商學大樓", detail: "商學院教學與系所空間。", query: "國立臺北大學 商學大樓", layer: .teaching),
        CampusMapLandmark(id: "humanities", title: "人文大樓", detail: "人文學院與通識課程空間。", query: "國立臺北大學 人文大樓", layer: .teaching),
        CampusMapLandmark(id: "law", title: "法學大樓", detail: "法律學院與法政相關課程空間。", query: "國立臺北大學 法學大樓", layer: .teaching),
        CampusMapLandmark(id: "social-science", title: "社會科學大樓", detail: "社會科學院教學與系所空間。", query: "國立臺北大學 社會科學大樓", layer: .teaching),
        CampusMapLandmark(id: "public-affairs", title: "公共事務大樓", detail: "公共事務學院與相關課程空間。", query: "國立臺北大學 公共事務大樓", layer: .teaching),
        CampusMapLandmark(id: "eecs", title: "電機資訊大樓", detail: "電機資訊相關系所與實作空間。", query: "國立臺北大學 電機資訊大樓", layer: .teaching),
        CampusMapLandmark(id: "dorm", title: "學生宿舍", detail: "住宿生活與校內生活圈。", query: "國立臺北大學 學生宿舍", layer: .dormActivity),
        CampusMapLandmark(id: "activity-center", title: "綜合體育館暨活動中心", detail: "體育課、活動與大型集會場域。", query: "國立臺北大學 綜合體育館", layer: .dormActivity)
    ]
}

private struct CampusResource: Identifiable {
    let id: String
    let title: String
    let detail: String
    let layer: CampusMapLayer

    static let defaults: [CampusResource] = [
        CampusResource(id: "business", title: "商學大樓", detail: "商學院相關教學與系所空間。", layer: .teaching),
        CampusResource(id: "humanities", title: "人文大樓", detail: "人文學院與通識課程常用教學空間。", layer: .teaching),
        CampusResource(id: "law", title: "法學大樓", detail: "法律學院與法政相關教學空間。", layer: .teaching),
        CampusResource(id: "admin", title: "行政大樓", detail: "教務、行政與學生常用服務窗口。", layer: .libraryAdmin),
        CampusResource(id: "public-affairs", title: "公共事務大樓", detail: "公共事務學院與相關課程空間。", layer: .teaching),
        CampusResource(id: "eecs", title: "電資大樓", detail: "電機資訊相關系所與實作空間。", layer: .teaching),
        CampusResource(id: "library", title: "圖書資訊大樓", detail: "圖書館、借閱與自習資源。", layer: .libraryAdmin),
        CampusResource(id: "social-science", title: "社會科學大樓", detail: "社會科學院相關教學與系所空間。", layer: .teaching),
        CampusResource(id: "dorm", title: "學生宿舍", detail: "住宿生活與校內生活圈主要區域。", layer: .dormActivity),
        CampusResource(id: "second-dorm", title: "第二期學生宿舍", detail: "宿舍生活與學生住宿服務區域。", layer: .dormActivity),
        CampusResource(id: "huaide", title: "懷德/木師基地", detail: "校園圖標示之基地與活動延伸空間。", layer: .dormActivity),
        CampusResource(id: "chongyue", title: "崇越館", detail: "校園活動、課程或服務可能使用的場館。", layer: .dormActivity),
        CampusResource(id: "sports-center", title: "綜合體育館暨活動中心", detail: "體育課、活動與大型集會場域。", layer: .dormActivity),
        CampusResource(id: "sports", title: "運動休閒設施", detail: "操場、球場與戶外活動設施群。", layer: .dormActivity)
    ]
}
