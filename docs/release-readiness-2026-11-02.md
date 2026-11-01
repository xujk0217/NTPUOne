# NTPUOne 上線檢查與 iPhone Duo 適配建議

> 此為修正前的檢查快照。後續版本、YouBike、行事曆與本機資料庫修正及驗證，請見 [修正紀錄](fixes-2026-11-02.md)。

檢查日期：2026-11-02（Asia/Taipei）。本次以目前工作目錄為準，包含 19 個既有未提交修改檔案；沒有修改 App 程式碼、部署 Firebase 或操作 App Store Connect。

## 目前進度

| 範圍 | 查得狀態 | 判斷 |
| --- | --- | --- |
| 公開上架版本 | Apple Lookup API：1.3，2026-02-20 發布，最低 iOS 16 | 已有正式上架版本 |
| 本機主程式 | 1.4.0、build 1、最低 iOS 16、iPhone only | 下一版開發狀態，不能等同已上架 |
| Widget extension | 1.3.1、build 1 | 與主程式版本不同，發版前應統一 |
| 功能實作 | 首頁、課表查詢與管理、待辦、Widget／Live Activity、餐廳／留言、交流區／圖片、校園地圖、管理後台 | 功能範圍已相當完整；尚未逐一完成真機驗收 |
| 營運控制 | 本機新增 Remote Config 全站及分功能維護開關 | 是維運基礎，但只控制 UI，不是後端存取限制；遠端參數是否發布未查證 |
| 交流區推播 | `K.Community.notificationsEnabled = false`，Functions 無推播匯出 | 明確停用；課表／備忘錄本地通知另行處理 |
| 發布證據 | 無 App Store Connect、TestFlight、線上 Firestore 規則／索引、CloudKit production schema 查證 | 尚不能保證本機新功能已部署或具備正式服務條件 |

Apple 公開資料來源：[App Store](https://apps.apple.com/tw/app/ntpuone/id6550918004)、[Lookup API](https://itunes.apple.com/lookup?id=6550918004&country=tw)。版本另以本次直接 HTTP 查詢確認；商店版本無法直接映射到某個 Git commit。

## 優先修改項目

### P1：下一版公開前處理

1. **補齊交流區治理流程。** 目前能發文、回覆、編輯及刪除本人內容，亦有管理後台，但在 Swift 實作中沒有找到內容檢舉、封鎖使用者與不當內容過濾流程。一般「回報問題」表單不能取代貼文／回覆的檢舉與封鎖。建議加入貼文／回覆選單、檢舉佇列、後台處理狀態與封鎖機制；封鎖識別應由可信的後端映射產生，不公開私人 owner UID，也不信任可自行更改的裝置識別。Apple [審查指引 1.2](https://developer.apple.com/app-store/review/guidelines/#user-generated-content)列有相應要求。

2. **提供刪除帳號與關聯資料流程。** `ContentView.swift` 有 Google 登入及 `signOut()`；`AboutView.swift:464` 的資料控制頁目前只有說明與重新顯示 onboarding，未找到 Firebase Auth 帳號刪除實作。需要處理重新驗證、帳號／私有 profile／訂閱與 token／擁有者索引，以及 Firestore 公開內容和 CloudKit 圖片；跨服務刪除要可重試，避免只刪除登入帳號留下孤兒資料。依 Apple [帳號刪除指引](https://developer.apple.com/help/app-review/guideline-reference/5-1-1-account-deletion/)，提供建立帳號的 App 也應提供 App 內刪除入口。

3. **收緊 Firestore 的星數、徽章及公開寫入權限。**
   - `firebase/firestore.rules:215` 的 `isRestaurantStarUpdate()` 只檢查星數不下降；`:697` 直接以此允許 update，沒有登入、單次增量或每人一次的限制。因此從本地規則可推導未登入請求能任意增加星數。
   - `:209`／`:659` 讓本人將 `userStats.total` 寫成任意非負整數；一般徽章級別亦允許客戶端直接選 0–4。因此累計／徽章不是可信的服務端認證結果。
   - `order`、`bug`、`feature` 以及公開餐廳新增存在不需登入的合法寫入路徑，且部分字串沒有上限。需要合理的身分限制、長度限制及防濫用設計。
   - 建議增加 Rules Emulator 測試：未登入、跨帳號修改、超額星數、偽造徽章、過長輸入、合法原子留言寫入。App Check 應確認在 Console 已強制執行；客戶端有初始化不代表伺服器端已啟用。
   - 以上是本地規則的靜態結論，本次未對正式資料進行攻擊或寫入，也未確認線上使用同一份規則。

4. **統一主程式與 Widget 版本並完成 Archive 驗證。** `NTPUOne.xcodeproj/project.pbxproj:969` 與 `:1171` 分別為 extension 1.3.1 與 App 1.4.0，build 都是 1。應統一 extension 與 App 的發版版本、依 App Store Connect 現況設定 build number，再驗證簽章／entitlements／Archive／TestFlight。無簽章編譯不等於可上傳商店。

### P2：穩定性與維運改善

5. **YouBike 改用站號與完整資料集合篩選。** `TrafficView/UbikeManager.swift` 只抓第 0 頁 230 筆，之後再切 `169..<222`；當資料排序、頁數改變時容易漏站或錯站。本次直接查詢現用 URL 回傳 230 筆，專案 `K.Bike.NTPUBikeNum` 的 19 個站號中只有 6 個出現在該頁及切片；將查詢筆數擴大後取得 1,614 筆資料，其中完整包含 19 個指定站點，確認目前漏掉 13 個。應處理分頁，再依 `sno`／地理範圍篩選；失敗時提供錯誤、重試與資料更新時間。來源：[目前使用的公開 API](https://data.ntpc.gov.tw/api/datasets/010E5B15-3823-4B20-B401-B1CF000550C5/json?page=0&size=230)。

6. **將持久化錯誤改為可恢復狀態。** `CourseList/CoreDataManager.swift:34`／`:48` 在載入或儲存失敗時直接 `fatalError`，App 與 Widget 其他位置也有相同模式。建議給可理解的錯誤與重試／資料匯出或復原入口，避免因儲存、遷移或雲端異常反覆閃退；不要為了避開錯誤自動刪除使用者資料。

7. **加入查詢分頁與資料量上限。** 交流區主題／回覆（`ContentView.swift:2556`／`:2693`）、活動（`WebViews/Order.swift:58`）及餐廳留言目前為沒有 `limit` 的 snapshot listener。重複 listener 防護已有改善，但資料成長後仍會增加首次載入、記憶體與讀取成本。建議分頁載入，僅對目前畫面需要的範圍監聽。

8. **整理網路及隱私設定。** `Info.plist` 全域 `NSAllowsArbitraryLoads = true`，建議先盤點校方舊 HTTP 連結，再限縮例外；`WeatherManager.swift` 有內嵌氣象 API 授權值，應評估配額、換發及代理／快取，單純搬到另一個客戶端設定檔無法保密。核對目前廣告、Analytics、Crashlytics、Google 登入及社群資料與 App Store 隱私揭露是否一致。本次未找到 App 自有 `.xcprivacy`，應檢查發佈產物整合 SDK manifests 與本身所用 required-reason APIs，不能只依原始碼有無檔案判定合規。

9. **補可重現建置及核心測試。** 專案未找到測試 target 或現成測試套件，shared scheme 也沒有指定測試清單；`.gitignore` 排除 `Package.resolved`。建議提交 App 的套件鎖定版本，加入課程 HTML 解析、學期切換、提醒時間、跨帳號與 Firestore 規則測試。優先驗證真實風險，不必為純畫面文字另寫鏡像測試。

10. **逐步拆分大檔案。** `ContentView.swift` 約 5,320 行、`WebViews/LinkView.swift` 約 2,662 行、`MemoView/TodayView.swift` 約 2,133 行。將社群資料、登入、圖片服務與頁面拆開，能降低 Duo 適配與後續維護風險，沒有必要先重寫整個 App。

11. **先清理升級編譯器會放大的警告。** 本次 Release 建置出現 `AdminConsoleView.swift` 的 MainActor／Sendable 警告，以及 `CourseData.swift:434` 的非完整 switch（缺 `.ephemeral`）。升級 Xcode／Swift 前應修正跨執行緒 UI 狀態更新、callback 隔離及 enum case；不要直接切換 Swift 6 language mode 後才處理全部錯誤。

## iPhone Duo 的可行開發方式

Apple 已提供 [Prepare your app for iPhone Duo](https://developer.apple.com/videos/play/tech-talks/111461/) 及 [Strike a pose with adaptive layouts on iPhone Duo](https://developer.apple.com/videos/play/tech-talks/111463/) 官方指引。現有 SwiftUI 架構可以延續；不需另開一套 Duo App。

### 工具與目前限制

- 本機確認為 macOS 26.4、Xcode 26.0.1，模擬器僅有 iOS 26.0，沒有 Duo。
- 依 Apple [Xcode 系統需求](https://developer.apple.com/xcode/system-requirements)，Xcode 27.1 需要 macOS 26.6 以上。因此先升級相容 macOS，再安裝 Xcode 27.1 及 iOS 27.1 Duo runtime。本次未安裝或升級系統工具。
- 舊 SDK 建置的 App 仍可在 Duo 相容模式運行，但不能據此宣稱完整適配；採 iOS 27.1 SDK 才能使用完整螢幕體驗。實際版面與狀態連續性仍須測試。
- 可維持最低 iOS 16；新 API 用 `if #available(iOS 27.1, *)` 包覆並保留舊版 layout。升級 SDK 和提高最低支援系統是兩件不同的事。

### 建議實作順序

1. **先做一般尺寸自適應。** 使用 `horizontalSizeClass`、可用容器尺寸及 `ViewThatFits` 決定版型，不以裝置名稱或直橫向判斷。`Other/extention.swift:52` 的 `UIScreen.main.bounds.width` 應改由目前視窗／容器布局決定；檢查固定卡片、地圖與廣告高度在窄窗、鍵盤及大字體時是否裁切。
2. **導入寬版雙欄。** 外螢幕及窄視窗維持既有導覽；寬視窗可用 `NavigationSplitView`。建議課表左側週課表／右側選中課程與待辦，交流區左側列表／右側文章與回覆，餐廳左側列表／右側地圖與詳情。首頁採自適應卡片格線。既有課表 `GridItem(.flexible())` 是可沿用的基礎。
3. **處理展開與收合狀態。** 選中的文章、課程、草稿、搜尋條件、捲動位置應由穩定的 state／model 擁有，不因 layout 切換重新建立而遺失。Duo 內螢幕不依 App 的直向限制鎖定版面，因此目前 portrait-only 設定不能當作尺寸保證。
4. **再加入摺疊專屬體驗。** 依需求採 iOS 27.1 的 `ArrangementView` 及 reserved regions 處理雙面板、鉸鏈及鏡頭避讓；前景按鈕尊重 safe area，左右 inset 個別計算。導覽容器和 arrangement 是不同責任，依官方範例選擇層級，避免直接將 `NavigationSplitView` 塞入 `ArrangementView`。
5. **最後完成 Device Hub 驗收。** 外螢幕、完全展開、半摺疊、旋轉、Split View；各狀態檢查課表、發文草稿、圖片瀏覽、地圖、登入 sheet、廣告及 Widget 深連結。另測大字體、VoiceOver、鍵盤與斷線。iPad 可先驗證寬窄視窗的排版，但不能取代 Duo 模擬器與真機測試。

### 建議驗收標準

- 展開／收合及分割視窗時，選中項目和未送出的內容不遺失。
- 重要操作不被鏡頭、鉸鏈、鍵盤或系統 UI 擋住。
- 窄窗仍能完成課程新增、待辦編輯及交流區閱讀／回覆。
- 寬窗有資訊密度更好的版型，沒有單純把手機畫面等比放大。
- Release Archive、TestFlight、正式 Firebase／CloudKit 環境與兩種螢幕實測均通過，再宣稱 Duo 支援。

## 本次驗證記錄

- `git diff --check`：通過。
- 直接查詢 Apple Lookup 及新北市公開 API：完成，結果如上。
- Release 無簽章編譯：`BUILD SUCCEEDED`，exit code 0。命令如下；完整紀錄在 `/private/tmp/ntpuone-audit-build.log`，屬暫存檔。

```sh
xcodebuild -project NTPUOne.xcodeproj -scheme NTPUOne \
  -configuration Release -destination 'generic/platform=iOS' \
  -derivedDataPath /private/tmp/ntpuone-audit-build \
  CODE_SIGNING_ALLOWED=NO build
```

- 建置確認警告：extension 的 `CFBundleShortVersionString`（1.3.1）必須與主程式（1.4.0）一致，另有上列 concurrency、switch 及未使用變數警告。
- 正式環境寫入、真機 UI、帳號建立／刪除、推播送達、Archive 簽章與商店上傳：未執行。

建議優先順序：公開功能的治理及資料刪除 → Firestore 權限與測試 → 版本一致與 Release／TestFlight → 資料來源穩定性 → Duo 自適應版面及專屬驗證。
