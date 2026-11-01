# NTPUOne

給國立臺北大學學生使用的 iPhone 校園生活 App，整合課表、待辦、校園資訊與交流功能。

[App Store](https://apps.apple.com/tw/app/ntpuone/id6550918004) · [問題回報](https://github.com/xujk0217/NTPUOne/issues) · [聯絡開發者](mailto:kevin16021777@gmail.com)

> 本專案為個人開發，非國立臺北大學官方產品。原創內容採 **All rights reserved／保留所有權利**，公開原始碼不代表開放商用、改作或重新發行。使用範圍見 [LICENSE](LICENSE) 與[權益說明](docs/RIGHTS.md)。

## 功能

| 功能 | 說明 |
| --- | --- |
| 校園首頁 | 學校公告、活動資訊、常用連結與行事曆 |
| 課表 | 課程搜尋、新增與編輯、課前本地提醒 |
| 待辦與備忘錄 | 截止日期、計畫時間、課程關聯與提醒 |
| Widget／Live Activity | 課表、下一堂課及待辦資訊；依系統與功能條件提供 |
| 校園生活 | 餐廳資料與留言、校園地圖、天氣與周邊 YouBike |
| 交流區 | 學校 Google 帳號登入、主題、回覆、圖片與本人內容管理 |

這是原始碼實作範圍，實際可用性受 App 發布版本、系統版本、遠端功能開關及外部服務影響。交流區雲端推播目前停用，課表與備忘錄本地提醒另外處理。

## 技術與目錄

SwiftUI／UIKit、Core Data／CloudKit、WidgetKit／ActivityKit、MapKit，以及由 Swift Package Manager 管理的 Firebase、Google Sign-In、Google Mobile Ads、SwiftSoup 等依賴。

```text
NTPUOne/                    App 主程式與功能畫面
NTPUOne.xcodeproj/          Xcode 專案與共享 scheme
NextCourseWidget/          Widget 與 Live Activity
CourseModel.xcdatamodeld/   課程與備忘錄資料模型
firebase/                  Firestore 規則、索引與後端說明
tests/                     可獨立執行的回歸檢查
docs/                      維護紀錄、系統說明與權益文件
```

## 開發與建置

以下供維護者與已取得授權的協作者使用，不另外授予程式使用或散布權利。

### 環境

- macOS、Xcode 與相容的 iOS SDK。最近一次建置使用 Xcode 26.0.1；這是驗證環境，不是最低 Xcode 版本承諾。
- 專案最低部署版本為 iOS 16，部分功能需要更新系統。
- Apple Developer 簽章及 App Groups／iCloud 能力；真機與發布需要相符的 provisioning 設定。
- 自行建立的 Firebase、Google 登入與其他服務設定，或維護者明確授權使用的測試環境。

### 設定步驟

1. 開啟 `NTPUOne.xcodeproj`，等待 Swift Package Manager 解析依賴。
2. 在 App 與 Widget target 設定正確的 Team、Bundle Identifier、App Group 與 iCloud container；兩個 target 的共享資料設定必須一致。
3. 將自己 Firebase App 的 `GoogleService-Info.plist` 放在 `NTPUOne/`。此檔未納入 Git；沒有設定檔時不能直接視為可執行的完整環境。
4. 若使用自己的 Firebase 專案，同步調整 Google OAuth URL scheme，並依功能設定 Authentication、Firestore、App Check、Remote Config 等服務。模擬器使用的 App Check debug token 應只登錄在測試專案。
5. 使用自己的廣告測試設定及外部 API 授權；請勿將來源碼中的既有服務識別或 API 授權視為可共用的開發資源。
6. 選擇 `NTPUOne` scheme 與模擬器／真機執行。正式雲端服務、資料寫入與發布操作需另外確認目標環境。

Firebase 細節見 [firebase/functions/README.md](firebase/functions/README.md)。CloudKit schema、Console 參數、簽章與服務帳號並非全部由此儲存庫重建。

### Release 編譯

完成服務與套件設定後，從專案根目錄執行：

```sh
xcodebuild -project NTPUOne.xcodeproj -scheme NTPUOne \
  -configuration Release -destination 'generic/platform=iOS' \
  -derivedDataPath /private/tmp/ntpuone-build \
  CODE_SIGNING_ALLOWED=NO build
```

這只驗證無簽章建置，不代表已完成 Archive、真機、CloudKit 同步、TestFlight 或 App Store 審查。App 與 Widget 的版本、build number 必須一致，並依實際上傳紀錄遞增。

### 回歸檢查

見 [tests/README.md](tests/README.md)。目前包含 Core Data 失敗與重試、YouBike 分頁與錯誤處理等獨立檢查，不是全功能端對端測試。

## 維護資訊

- [最近修正與驗證紀錄](docs/fixes-2026-11-02.md)
- [上線檢查快照](docs/release-readiness-2026-11-02.md)
- [YouBike 站點快照](docs/youbike-stations-2026-11-02.md)：App 會動態抓取，快照數量不代表即時營運狀態。
- [Android 系統規格](docs/android-system-spec/NTPUOne-Android-System-Spec.md)：規格文件，不代表已有可發布的 Android App。

## 回報與貢獻

一般問題與功能建議可使用 [Issues](https://github.com/xujk0217/NTPUOne/issues)。請附版本、系統、重現步驟，並先遮蔽個資。安全漏洞請依 [SECURITY.md](SECURITY.md) 私下回報，勿公開攻擊步驟或憑證。

程式與文件貢獻請先閱讀 [CONTRIBUTING.md](CONTRIBUTING.md)。提交前需確認來源與授權，維護者保留是否合併的決定權。

## 著作權與第三方內容

Copyright © 2024–2026 許君愷（JUN-KAI XU／xujk0217），僅及於依法享有權利的原創內容。其他作者、套件、資料來源、學校標誌與使用者內容的權利仍歸各權利人。

[LICENSE](LICENSE) · [權益與使用限制](docs/RIGHTS.md) · [第三方套件與資料來源](docs/THIRD_PARTY_NOTICES.md)
