//
//  AdvancedNativeAdView.swift
//  NTPUOne
//
//  Created by 許君愷 on 2025/8/4.
//

import SwiftUI
import GoogleMobileAds

// 兩種版型：compact（左右排；左邊固定方形媒體），topMedia16x9（上媒體16:9，下文字）
enum NativeAdStyle: Equatable {
    case compact(media: CGFloat = 140)          // 建議 120~150
    case topMedia16x9(minHeight: CGFloat = 160) // 高 = 寬*9/16，且 >= minHeight
}

struct NativeAdBoxView: UIViewRepresentable {
//     let adUnitID = "ca-app-pub-3940256099942544/3986624511" // 測試用
    let adUnitID = "ca-app-pub-4105005748617921/9068538634"
    let style: NativeAdStyle
    @Binding var height: CGFloat

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIView(context: Context) -> NativeAdContainerView {
        let container = NativeAdContainerView(style: style)
        context.coordinator.container = container
        context.coordinator.loadAd()
        return container
    }

    func updateUIView(_ uiView: NativeAdContainerView, context: Context) {
        if uiView.style != style { uiView.rebuild(with: style) }
    }

    // iOS 16+：用 SwiftUI 提供的目標寬度計高
    func sizeThatFits(_ proposal: ProposedViewSize,
                      uiView: NativeAdContainerView,
                      context: Context) -> CGSize {
        let targetWidth = proposal.width ?? UIScreen.main.bounds.width
        let size = uiView.systemLayoutSizeFitting(
            CGSize(width: targetWidth, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        DispatchQueue.main.async { self.height = size.height }
        return size
    }

    final class Coordinator: NSObject, GADNativeAdLoaderDelegate, GADNativeAdDelegate {
        var parent: NativeAdBoxView
        var adLoader: GADAdLoader!
        weak var container: NativeAdContainerView?

        init(parent: NativeAdBoxView) { self.parent = parent }

        func loadAd() {
            guard
                let rootVC = UIApplication.shared.connectedScenes
                    .compactMap({ $0 as? UIWindowScene })
                    .first?.windows.first?.rootViewController
            else { return }

            adLoader = GADAdLoader(
                adUnitID: parent.adUnitID,
                rootViewController: rootVC,
                adTypes: [.native],
                options: nil
            )
            adLoader.delegate = self
            adLoader.load(GADRequest())
        }

        func adLoader(_ adLoader: GADAdLoader, didReceive nativeAd: GADNativeAd) {
            DispatchQueue.main.async {
                guard let container = self.container else { return }
                nativeAd.delegate = self
                container.apply(ad: nativeAd)

                // iOS 15 相容：在這裡也計一次高，避免沒走 sizeThatFits
                let targetWidth = container.superview?.bounds.width
                    ?? UIScreen.main.bounds.width - 32
                let size = container.systemLayoutSizeFitting(
                    CGSize(width: targetWidth,
                           height: UIView.layoutFittingCompressedSize.height),
                    withHorizontalFittingPriority: .required,
                    verticalFittingPriority: .fittingSizeLevel
                )
                self.parent.height = size.height
            }
        }

        func adLoader(_ adLoader: GADAdLoader, didFailToReceiveAdWithError error: Error) {
            print("❌ Native ad failed: \(error.localizedDescription)")
            DispatchQueue.main.async { self.parent.height = 0 }
        }
    }
}

// MARK: - 容器：負責 UI 建構 + 資產綁定
final class NativeAdContainerView: UIView {
    private(set) var adView = GADNativeAdView()
    private var mediaView = GADMediaView()
    private var headlineLabel = UILabel()
    private var bodyLabel = UILabel()
    private var ctaButton = UIButton(type: .system)
    private var adChoicesView = GADAdChoicesView()

    private var contentStack: UIStackView?
    private var mediaSizeConstraints: [NSLayoutConstraint] = []
    private var mediaAspectConstraint: NSLayoutConstraint?

    private(set) var style: NativeAdStyle

    init(style: NativeAdStyle) {
        self.style = style
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        buildSkeleton()
        buildLayout(for: style)
    }
    required init?(coder: NSCoder) { fatalError() }

    // 重新套用樣式（若需要動態切換）
    func rebuild(with newStyle: NativeAdStyle) {
        guard style != newStyle else { return }
        style = newStyle
        contentStack?.removeFromSuperview()
        contentStack = nil
        NSLayoutConstraint.deactivate(mediaSizeConstraints)
        mediaSizeConstraints.removeAll()
        mediaAspectConstraint?.isActive = false
        mediaAspectConstraint = nil
        buildLayout(for: newStyle)
        setNeedsLayout()
        layoutIfNeeded()
    }

    private func buildSkeleton() {
        // adView 填滿容器
        adView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(adView)
        NSLayoutConstraint.activate([
            adView.topAnchor.constraint(equalTo: topAnchor),
            adView.leadingAnchor.constraint(equalTo: leadingAnchor),
            adView.trailingAnchor.constraint(equalTo: trailingAnchor),
            adView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        // 邊界裁切，避免極端狀況外溢
        adView.clipsToBounds = true
        clipsToBounds = true

        // 媒體
        mediaView.translatesAutoresizingMaskIntoConstraints = false
        mediaView.isUserInteractionEnabled = true // 媒體需互動
        adView.mediaView = mediaView
        mediaView.setContentCompressionResistancePriority(.required, for: .horizontal)
        mediaView.setContentHuggingPriority(.required, for: .horizontal)

        // 標題
        headlineLabel.font = .boldSystemFont(ofSize: 13)
        headlineLabel.numberOfLines = 2
        headlineLabel.lineBreakMode = .byWordWrapping
        headlineLabel.allowsDefaultTighteningForTruncation = true
        headlineLabel.isUserInteractionEnabled = false
        adView.headlineView = headlineLabel
        // 水平可被壓縮，垂直撐開
        headlineLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        headlineLabel.setContentHuggingPriority(.required, for: .vertical)

        // 內文
        bodyLabel.font = .systemFont(ofSize: 10)
        bodyLabel.numberOfLines = 3
        bodyLabel.lineBreakMode = .byCharWrapping // 長字/無空白也能斷行
        bodyLabel.isUserInteractionEnabled = false
        adView.bodyView = bodyLabel
        bodyLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        bodyLabel.setContentHuggingPriority(.required, for: .vertical)

        // CTA
        ctaButton.backgroundColor = .systemBlue
        ctaButton.setTitleColor(.white, for: .normal)
        ctaButton.titleLabel?.font = .boldSystemFont(ofSize: 12)
        ctaButton.titleLabel?.numberOfLines = 1
        ctaButton.titleLabel?.lineBreakMode = .byTruncatingTail
        ctaButton.titleLabel?.adjustsFontSizeToFitWidth = true
        ctaButton.titleLabel?.minimumScaleFactor = 0.6
        ctaButton.layer.cornerRadius = 8
        ctaButton.isUserInteractionEnabled = false // CTA 交給 SDK
        adView.callToActionView = ctaButton
        // ⚠️ 不要在這裡對 CTA 下寬度約束（此時 CTA 尚未在層級樹內）

        // AdChoices（一定要 addSubview 再下 constraint）
        adChoicesView.translatesAutoresizingMaskIntoConstraints = false
        adChoicesView.isUserInteractionEnabled = false
        adView.adChoicesView = adChoicesView
        adView.addSubview(adChoicesView)
        NSLayoutConstraint.activate([
            adChoicesView.topAnchor.constraint(equalTo: adView.topAnchor, constant: 4),
            adChoicesView.trailingAnchor.constraint(equalTo: adView.trailingAnchor, constant: -4),
        ])
    }

    private func buildLayout(for style: NativeAdStyle) {
        switch style {
        case .compact(let media):
            let hStack = UIStackView()
            hStack.axis = .horizontal
            hStack.spacing = 10
            hStack.alignment = .top
            hStack.translatesAutoresizingMaskIntoConstraints = false
            adView.addSubview(hStack)
            contentStack = hStack

            // 左：固定方形 Media
            hStack.addArrangedSubview(mediaView)
            mediaSizeConstraints = [
                mediaView.widthAnchor.constraint(equalToConstant: media),
                mediaView.heightAnchor.constraint(equalToConstant: media)
            ]
            NSLayoutConstraint.activate(mediaSizeConstraints)

            // 右：文字+CTA
            let vStack = UIStackView()
            vStack.axis = .vertical
            vStack.spacing = 6
            vStack.translatesAutoresizingMaskIntoConstraints = false
            hStack.addArrangedSubview(vStack)

            vStack.addArrangedSubview(headlineLabel)
            vStack.addArrangedSubview(bodyLabel)
            vStack.addArrangedSubview(ctaButton)

            // CTA 尺寸與約束（此時 CTA 已在層級樹內，可以安全加）
            ctaButton.heightAnchor.constraint(equalToConstant: 36).isActive = true
            ctaButton.setContentCompressionResistancePriority(.required, for: .horizontal)
            ctaButton.widthAnchor.constraint(lessThanOrEqualTo: vStack.widthAnchor).isActive = true

            // 讓右側願意被壓縮（換行），左側保持固定寬
            vStack.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            vStack.setContentHuggingPriority(.defaultLow, for: .horizontal)

            NSLayoutConstraint.activate([
                hStack.topAnchor.constraint(equalTo: adView.topAnchor, constant: 12),
                hStack.leadingAnchor.constraint(equalTo: adView.leadingAnchor, constant: 12),
                hStack.trailingAnchor.constraint(equalTo: adView.trailingAnchor, constant: -12),
                hStack.bottomAnchor.constraint(equalTo: adView.bottomAnchor, constant: -12),
            ])

        case .topMedia16x9(let minHeight):
            let vStack = UIStackView()
            vStack.axis = .vertical
            vStack.spacing = 10
            vStack.translatesAutoresizingMaskIntoConstraints = false
            adView.addSubview(vStack)
            contentStack = vStack

            // 上：媒體 16:9 + 最小高度
            vStack.addArrangedSubview(mediaView)
            mediaAspectConstraint = mediaView.heightAnchor.constraint(
                equalTo: mediaView.widthAnchor, multiplier: 9.0/16.0
            )
            mediaAspectConstraint?.isActive = true
            mediaView.heightAnchor.constraint(greaterThanOrEqualToConstant: minHeight).isActive = true

            // 下：文字+CTA
            let textStack = UIStackView()
            textStack.axis = .vertical
            textStack.spacing = 6
            textStack.translatesAutoresizingMaskIntoConstraints = false
            vStack.addArrangedSubview(textStack)

            textStack.addArrangedSubview(headlineLabel)
            textStack.addArrangedSubview(bodyLabel)
            textStack.addArrangedSubview(ctaButton)

            // CTA 尺寸與約束（安全：CTA 已在 textStack 裡）
            ctaButton.heightAnchor.constraint(equalToConstant: 36).isActive = true
            ctaButton.setContentCompressionResistancePriority(.required, for: .horizontal)
            ctaButton.widthAnchor.constraint(lessThanOrEqualTo: textStack.widthAnchor).isActive = true

            // 保險：文字區允許水平壓縮
            textStack.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            textStack.setContentHuggingPriority(.defaultLow, for: .horizontal)

            NSLayoutConstraint.activate([
                vStack.topAnchor.constraint(equalTo: adView.topAnchor, constant: 12),
                vStack.leadingAnchor.constraint(equalTo: adView.leadingAnchor, constant: 12),
                vStack.trailingAnchor.constraint(equalTo: adView.trailingAnchor, constant: -12),
                vStack.bottomAnchor.constraint(equalTo: adView.bottomAnchor, constant: -12),
            ])
        }
    }

    // 綁定廣告資產
    func apply(ad: GADNativeAd) {
        headlineLabel.text = ad.headline

        if let body = ad.body, !body.isEmpty {
            bodyLabel.text = body
            bodyLabel.isHidden = false
        } else {
            bodyLabel.text = nil
            bodyLabel.isHidden = true
        }

        if let cta = ad.callToAction, !cta.isEmpty {
            ctaButton.setTitle(cta, for: .normal)
            ctaButton.isHidden = false
        } else {
            ctaButton.setTitle(nil, for: .normal)
            ctaButton.isHidden = true
        }

        adView.nativeAd = ad
        ad.delegate = self
    }
}

extension NativeAdContainerView: GADNativeAdDelegate {}
