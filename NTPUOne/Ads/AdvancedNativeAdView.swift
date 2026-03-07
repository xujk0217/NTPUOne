//
//  AdvancedNativeAdView.swift
//  NTPUOne
//
//  Created by 許君愷 on 2025/8/4.
//

import SwiftUI
import GoogleMobileAds

// MARK: - Native 廣告載入器

/// 原生廣告載入狀態管理（ObservableObject，可多實例使用）
final class NativeAdLoader: NSObject, ObservableObject, GADNativeAdLoaderDelegate, GADNativeAdDelegate {
    @Published var nativeAd: GADNativeAd?
    @Published var isLoading = false
    @Published var loadFailed = false

    // 正式 ID
    private let adUnitID = "ca-app-pub-4105005748617921/9068538634"
    // 測試 ID（開發時可切換）：
    // private let adUnitID = "ca-app-pub-3940256099942544/3986624511"

    private var adLoader: GADAdLoader?
    private var retryCount = 0
    private let maxRetry = 2

    func loadAd() {
        guard !isLoading else { return }
        guard nativeAd == nil else { return }

        isLoading = true
        loadFailed = false

        // 取得 rootViewController
        let rootVC = Self.findRootVC()
        guard let rootVC else {
            print("⚠️ NativeAdLoader: rootVC == nil，延遲 0.5s 重試")
            isLoading = false
            // rootVC 可能尚未就緒（例如 app launch 初期），稍後重試
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.loadAd()
            }
            return
        }

        let loader = GADAdLoader(
            adUnitID: adUnitID,
            rootViewController: rootVC,
            adTypes: [.native],
            options: nil
        )
        loader.delegate = self
        self.adLoader = loader
        loader.load(GADRequest())
    }

    // MARK: GADNativeAdLoaderDelegate
    func adLoader(_ adLoader: GADAdLoader, didReceive nativeAd: GADNativeAd) {
        nativeAd.delegate = self
        DispatchQueue.main.async {
            self.nativeAd = nativeAd
            self.isLoading = false
            self.retryCount = 0
            print("✅ Native ad loaded: \(nativeAd.headline ?? "(no headline)")")
        }
    }

    func adLoader(_ adLoader: GADAdLoader, didFailToReceiveAdWithError error: Error) {
        print("❌ Native ad load failed: \(error.localizedDescription)")
        DispatchQueue.main.async {
            self.isLoading = false
            self.loadFailed = true
            guard self.retryCount < self.maxRetry else { return }
            self.retryCount += 1
            let delay = Double(self.retryCount) * 3.0
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.nativeAd = nil
                self?.loadAd()
            }
        }
    }

    // MARK: GADNativeAdDelegate
    func nativeAdDidRecordImpression(_ nativeAd: GADNativeAd) {
        print("📊 Native ad impression recorded")
    }
    func nativeAdDidRecordClick(_ nativeAd: GADNativeAd) {
        print("👆 Native ad click recorded")
    }

    // MARK: Helper
    private static func findRootVC() -> UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first(where: { $0.isKeyWindow })?
            .rootViewController
    }
}

// MARK: - SwiftUI 入口：NativeAdSectionView

/// 在 List / Section / TabView 中使用的原生廣告視圖
/// - `.compact`：左圖右文，高度約 90pt，適合 List row
/// - `.card`：上媒體下文字，高度約 220pt，適合獨立 Section
/// - `showCardBackground`：是否顯示卡片背景（用於輪播器，與公告卡片一致）
struct NativeAdSectionView: View {
    enum Style {
        case compact
        case card
    }

    let style: Style
    var showCardBackground: Bool = false
    @StateObject private var loader = NativeAdLoader()

    var body: some View {
        let _ = print("🔍 NativeAdSectionView body called - style: \(style), nativeAd: \(loader.nativeAd != nil), isLoading: \(loader.isLoading), loadFailed: \(loader.loadFailed)")
        
        Group {
            if let ad = loader.nativeAd {
                let _ = print("✅ NativeAdSectionView: 顯示廣告 - \(ad.headline ?? "(no headline)")")
                NativeAdUIViewWrapper(ad: ad, style: style)
                    .frame(maxWidth: .infinity, minHeight: style == .compact ? 140 : 240)
            } else {
                // Loading / Failed / Initial 都顯示骨架佔位符
                AdSkeletonView(style: style)
                    .frame(maxWidth: .infinity, minHeight: style == .compact ? 140 : 240)
            }
        }
        .frame(maxWidth: .infinity, minHeight: style == .compact ? 140 : 240)
        .background(
            Group {
                if showCardBackground {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                        .overlay {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color(.separator), lineWidth: 0.5)
                        }
                        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
                } else {
                    Color.clear
                }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: showCardBackground ? 18 : 0, style: .continuous))
        .onAppear {
            print("🔍 NativeAdSectionView onAppear - 開始載入廣告")
            loader.loadAd()
        }
    }
}

// MARK: - UIViewRepresentable：正確的 GADNativeAdView 實現
//
// Google Mobile Ads 要求：
// 1. 所有內容必須放在 GADNativeAdView 內
// 2. headlineView、bodyView、mediaView、callToActionView 等屬性必須設定
// 3. 最後設定 nativeAd 屬性，SDK 才會記錄曝光（impression）

struct NativeAdUIViewWrapper: UIViewRepresentable {
    let ad: GADNativeAd
    let style: NativeAdSectionView.Style

    func makeUIView(context: Context) -> GADNativeAdView {
        let nativeAdView = GADNativeAdView()
        nativeAdView.backgroundColor = .clear

        switch style {
        case .compact:
            configureCompact(nativeAdView)
        case .card:
            configureCard(nativeAdView)
        }

        return nativeAdView
    }

    func updateUIView(_ nativeAdView: GADNativeAdView, context: Context) {
        // 更新文字內容
        (nativeAdView.headlineView as? UILabel)?.text = ad.headline
        (nativeAdView.bodyView as? UILabel)?.text = ad.body
        (nativeAdView.advertiserView as? UILabel)?.text = ad.advertiser

        if let ctaButton = nativeAdView.callToActionView as? UIButton {
            ctaButton.setTitle(ad.callToAction, for: .normal)
            ctaButton.isHidden = (ad.callToAction ?? "").isEmpty
        }

        // 更新 icon
        if let iconView = nativeAdView.iconView as? UIImageView {
            iconView.image = ad.icon?.image
            iconView.isHidden = (ad.icon == nil)
        }

        // 更新媒體
        if let mediaView = nativeAdView.mediaView {
            mediaView.mediaContent = ad.mediaContent
        }

        // 設定 ad badge
        if let badgeLabel = nativeAdView.viewWithTag(999) as? UILabel {
            badgeLabel.isHidden = false
        }

        // ⚠️ 最後設定 nativeAd — 這步讓 SDK 開始追蹤曝光和點擊
        nativeAdView.nativeAd = ad
    }

    // MARK: - Compact 版型（左 icon/media + 右 文字）

    private func configureCompact(_ adView: GADNativeAdView) {
        // --- Ad badge ---
        let badgeLabel = UILabel()
        badgeLabel.tag = 999
        badgeLabel.text = "廣告"
        badgeLabel.font = .systemFont(ofSize: 9, weight: .semibold)
        badgeLabel.textColor = .white
        badgeLabel.backgroundColor = UIColor.systemOrange.withAlphaComponent(0.85)
        badgeLabel.textAlignment = .center
        badgeLabel.layer.cornerRadius = 3
        badgeLabel.clipsToBounds = true
        badgeLabel.translatesAutoresizingMaskIntoConstraints = false

        // --- Icon ---
        let iconView = UIImageView()
        iconView.contentMode = .scaleAspectFill
        iconView.clipsToBounds = true
        iconView.layer.cornerRadius = 8
        iconView.translatesAutoresizingMaskIntoConstraints = false
        adView.iconView = iconView

        // --- Media (fallback if no icon) ---
        let mediaView = GADMediaView()
        mediaView.contentMode = .scaleAspectFill
        mediaView.clipsToBounds = true
        mediaView.layer.cornerRadius = 8
        mediaView.translatesAutoresizingMaskIntoConstraints = false
        adView.mediaView = mediaView

        // --- Headline ---
        let headlineLabel = UILabel()
        headlineLabel.font = .systemFont(ofSize: 14, weight: .bold)
        headlineLabel.numberOfLines = 1
        headlineLabel.translatesAutoresizingMaskIntoConstraints = false
        adView.headlineView = headlineLabel

        // --- Body ---
        let bodyLabel = UILabel()
        bodyLabel.font = .systemFont(ofSize: 12)
        bodyLabel.textColor = .secondaryLabel
        bodyLabel.numberOfLines = 2
        bodyLabel.translatesAutoresizingMaskIntoConstraints = false
        adView.bodyView = bodyLabel

        // --- CTA ---
        let ctaButton = UIButton(type: .system)
        ctaButton.titleLabel?.font = .systemFont(ofSize: 12, weight: .bold)
        ctaButton.setTitleColor(.systemBlue, for: .normal)
        ctaButton.isUserInteractionEnabled = false // 由 GADNativeAdView 處理
        ctaButton.contentHorizontalAlignment = .leading
        ctaButton.translatesAutoresizingMaskIntoConstraints = false
        adView.callToActionView = ctaButton

        // --- Layout ---
        // 左側容器：icon 在上，media 在下（二選一顯示）
        let leftContainer = UIView()
        leftContainer.translatesAutoresizingMaskIntoConstraints = false
        leftContainer.addSubview(mediaView)
        leftContainer.addSubview(iconView)

        // 右側文字堆疊
        let titleRow = UIStackView(arrangedSubviews: [badgeLabel, headlineLabel])
        titleRow.axis = .horizontal
        titleRow.spacing = 4
        titleRow.alignment = .center

        let textStack = UIStackView(arrangedSubviews: [titleRow, bodyLabel, ctaButton])
        textStack.axis = .vertical
        textStack.spacing = 3
        textStack.translatesAutoresizingMaskIntoConstraints = false

        adView.addSubview(leftContainer)
        adView.addSubview(textStack)

        NSLayoutConstraint.activate([
            // 左側 120x120（Google 要求視頻廣告至少 120x120）
            // 注意：增加頂部 padding 給 AdChoices icon 留空間
            leftContainer.leadingAnchor.constraint(equalTo: adView.leadingAnchor, constant: 12),
            leftContainer.centerYAnchor.constraint(equalTo: adView.centerYAnchor, constant: 6),
            leftContainer.widthAnchor.constraint(equalToConstant: 120),
            leftContainer.heightAnchor.constraint(equalToConstant: 120),

            iconView.topAnchor.constraint(equalTo: leftContainer.topAnchor),
            iconView.leadingAnchor.constraint(equalTo: leftContainer.leadingAnchor),
            iconView.trailingAnchor.constraint(equalTo: leftContainer.trailingAnchor),
            iconView.bottomAnchor.constraint(equalTo: leftContainer.bottomAnchor),

            mediaView.topAnchor.constraint(equalTo: leftContainer.topAnchor),
            mediaView.leadingAnchor.constraint(equalTo: leftContainer.leadingAnchor),
            mediaView.trailingAnchor.constraint(equalTo: leftContainer.trailingAnchor),
            mediaView.bottomAnchor.constraint(equalTo: leftContainer.bottomAnchor),

            // Badge 固定寬度
            badgeLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 28),
            badgeLabel.heightAnchor.constraint(equalToConstant: 16),

            // 右側文字 - 增加右側 padding 給 AdChoices icon 留空間
            textStack.leadingAnchor.constraint(equalTo: leftContainer.trailingAnchor, constant: 10),
            textStack.trailingAnchor.constraint(equalTo: adView.trailingAnchor, constant: -28),
            textStack.centerYAnchor.constraint(equalTo: adView.centerYAnchor, constant: 6),
        ])
    }

    // MARK: - Card 版型（上 media + 下 文字 + CTA 按鈕）

    private func configureCard(_ adView: GADNativeAdView) {
        // --- Ad badge ---
        let badgeLabel = UILabel()
        badgeLabel.tag = 999
        badgeLabel.text = "廣告"
        badgeLabel.font = .systemFont(ofSize: 9, weight: .semibold)
        badgeLabel.textColor = .white
        badgeLabel.backgroundColor = UIColor.systemOrange.withAlphaComponent(0.85)
        badgeLabel.textAlignment = .center
        badgeLabel.layer.cornerRadius = 3
        badgeLabel.clipsToBounds = true
        badgeLabel.translatesAutoresizingMaskIntoConstraints = false

        // --- Media ---
        let mediaView = GADMediaView()
        mediaView.contentMode = .scaleAspectFill
        mediaView.clipsToBounds = true
        mediaView.layer.cornerRadius = 10
        mediaView.translatesAutoresizingMaskIntoConstraints = false
        adView.mediaView = mediaView

        // --- Icon ---
        let iconView = UIImageView()
        iconView.contentMode = .scaleAspectFill
        iconView.clipsToBounds = true
        iconView.layer.cornerRadius = 4
        iconView.translatesAutoresizingMaskIntoConstraints = false
        adView.iconView = iconView

        // --- Headline ---
        let headlineLabel = UILabel()
        headlineLabel.font = .systemFont(ofSize: 15, weight: .bold)
        headlineLabel.numberOfLines = 1
        headlineLabel.translatesAutoresizingMaskIntoConstraints = false
        adView.headlineView = headlineLabel

        // --- Body ---
        let bodyLabel = UILabel()
        bodyLabel.font = .systemFont(ofSize: 12)
        bodyLabel.textColor = .secondaryLabel
        bodyLabel.numberOfLines = 2
        bodyLabel.translatesAutoresizingMaskIntoConstraints = false
        adView.bodyView = bodyLabel

        // --- Advertiser ---
        let advLabel = UILabel()
        advLabel.font = .systemFont(ofSize: 11)
        advLabel.textColor = .tertiaryLabel
        advLabel.numberOfLines = 1
        advLabel.translatesAutoresizingMaskIntoConstraints = false
        adView.advertiserView = advLabel

        // --- CTA ---
        let ctaButton = UIButton(type: .system)
        ctaButton.titleLabel?.font = .systemFont(ofSize: 13, weight: .bold)
        ctaButton.setTitleColor(.white, for: .normal)
        ctaButton.backgroundColor = .systemBlue
        ctaButton.layer.cornerRadius = 16
        ctaButton.contentEdgeInsets = UIEdgeInsets(top: 6, left: 16, bottom: 6, right: 16)
        ctaButton.isUserInteractionEnabled = false
        ctaButton.translatesAutoresizingMaskIntoConstraints = false
        adView.callToActionView = ctaButton

        // --- Layout ---
        adView.addSubview(mediaView)
        adView.addSubview(badgeLabel)
        adView.addSubview(iconView)
        adView.addSubview(headlineLabel)
        adView.addSubview(bodyLabel)
        adView.addSubview(advLabel)
        adView.addSubview(ctaButton)

        NSLayoutConstraint.activate([
            // 媒體區上方 - 增加上方和右側 padding 給 AdChoices icon 留空間
            mediaView.topAnchor.constraint(equalTo: adView.topAnchor, constant: 20),
            mediaView.leadingAnchor.constraint(equalTo: adView.leadingAnchor, constant: 12),
            mediaView.trailingAnchor.constraint(equalTo: adView.trailingAnchor, constant: -24),
            mediaView.heightAnchor.constraint(equalToConstant: 110),

            // Badge 在 media 左上角
            badgeLabel.topAnchor.constraint(equalTo: mediaView.topAnchor, constant: 6),
            badgeLabel.leadingAnchor.constraint(equalTo: mediaView.leadingAnchor, constant: 6),
            badgeLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 28),
            badgeLabel.heightAnchor.constraint(equalToConstant: 16),

            // Icon (小圖) 在 media 下方左側
            iconView.topAnchor.constraint(equalTo: mediaView.bottomAnchor, constant: 8),
            iconView.leadingAnchor.constraint(equalTo: adView.leadingAnchor, constant: 12),
            iconView.widthAnchor.constraint(equalToConstant: 24),
            iconView.heightAnchor.constraint(equalToConstant: 24),

            // Headline 在 icon 右邊
            headlineLabel.centerYAnchor.constraint(equalTo: iconView.centerYAnchor),
            headlineLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 6),
            headlineLabel.trailingAnchor.constraint(equalTo: adView.trailingAnchor, constant: -24),

            // Body
            bodyLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 4),
            bodyLabel.leadingAnchor.constraint(equalTo: adView.leadingAnchor, constant: 12),
            bodyLabel.trailingAnchor.constraint(equalTo: adView.trailingAnchor, constant: -24),

            // Advertiser
            advLabel.topAnchor.constraint(equalTo: bodyLabel.bottomAnchor, constant: 2),
            advLabel.leadingAnchor.constraint(equalTo: adView.leadingAnchor, constant: 12),

            // CTA 按鈕右下
            ctaButton.trailingAnchor.constraint(equalTo: adView.trailingAnchor, constant: -12),
            ctaButton.bottomAnchor.constraint(equalTo: adView.bottomAnchor, constant: -8),
            ctaButton.heightAnchor.constraint(equalToConstant: 32),
        ])
    }
}

// MARK: - 廣告骨架佔位符（Loading 狀態）

/// 在廣告載入中或失敗時顯示的骨架視圖
/// 用灰色條紋和 "ad" 文字重複排列，避免旋轉 loading
struct AdSkeletonView: View {
    let style: NativeAdSectionView.Style
    
    var body: some View {
        GeometryReader { geo in
            let rowHeight: CGFloat = style == .compact ? 24 : 28
            let spacing: CGFloat = 8
            let rows = Int((geo.size.height - 16) / (rowHeight + spacing))
            
            VStack(alignment: .leading, spacing: spacing) {
                ForEach(0..<max(rows, 1), id: \.self) { index in
                    skeletonRow(index: index, totalWidth: geo.size.width - 24, rowHeight: rowHeight)
                }
            }
            .padding(12)
        }
        .background(Color.clear)
    }
    
    @ViewBuilder
    private func skeletonRow(index: Int, totalWidth: CGFloat, rowHeight: CGFloat) -> some View {
        HStack(spacing: 6) {
            // 根據行索引變化寬度，模擬不同長度的內容
            let widths: [CGFloat] = [0.7, 0.5, 0.85, 0.6, 0.75]
            let widthRatio = widths[index % widths.count]
            
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(.systemGray4))
                .frame(width: totalWidth * widthRatio, height: rowHeight)
            
            Spacer()
            
            // 每隔幾行顯示 "ad" 標記
            if index % 2 == 0 {
                Text("ad")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color(.systemGray3))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 3)
                            .stroke(Color(.systemGray4), lineWidth: 1)
                    )
            }
        }
    }
}

// MARK: - Banner 廣告骨架佔位符

/// Banner 廣告載入時的骨架視圖
struct BannerSkeletonView: View {
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<4, id: \.self) { index in
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(.systemGray4))
                    .frame(width: index == 0 ? 60 : (index == 3 ? 40 : 80), height: 20)
            }
            Spacer()
            Text("ad")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(Color(.systemGray3))
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )
        }
        .padding(.horizontal, 12)
        .frame(height: BannerAdView.adHeight)
        .background(Color(.secondarySystemGroupedBackground))
    }
}
