# AdMob SDK 13.12.0 更新（2026-11-04）

Google Mobile Ads 從 11.6.0 升級至 13.12.0，SPM 鎖定檔已同步。Firebase 保留官方安全修補版 12.19.3。

依 Google 官方遷移指南，橫幅、原生與獎勵廣告調整為新版 Swift 類別名稱、載入及播放 API。SDK 的 RewardedAd 與專案既有包裝類別同名，使用 GoogleMobileAds.RewardedAd 明確指定 SDK 類別。

在 AppDelegate 的廣告初始化之前設定：

```swift
MobileAds.shared.requestConfiguration.coarseLocationCollectionEnabled = false
```

這會停用 13.12.0 新增的、使用 App 已取得定位權限而自動蒐集概略位置的功能；不代表廣告 SDK 完全不蒐集其他資料，也不取代 ATT 或既有隱私揭露。未新增定位權限、未改動廣告單元 ID。

Release 簽章封存成功（1.4.0 build 37）。實機廣告載入、獎勵取得、每日次數與關閉回呼仍應在 TestFlight 驗收；本機沒有模擬廣告曝光或點擊。

官方來源：
- https://developers.google.com/admob/ios/rel-notes
- https://developers.google.com/admob/ios/migration
- https://developers.google.com/admob/ios/targeting
- https://developers.google.com/admob/ios/privacy/data-disclosure
