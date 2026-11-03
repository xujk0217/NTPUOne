# 遠端修改後的 TestFlight 流程

App 與 Widget 維持行銷版本 1.4.0，目前 build 設為 17；前一個已上傳 build 為 16。後續每次上傳只遞增 CURRENT_PROJECT_VERSION；不要為每次內部測試改行銷版本。Export 允許 Xcode 調整尚未使用的 build number，以 App Store Connect 實際接收的版本為準。

## 建置與發布

需要此 Mac 的完整 Xcode、有效 Apple Developer 帳號、簽章及 App Store Connect 權限。使用 Xcode 已登入帳號，不把密鑰或密碼放進腳本。

```sh
scripts/testflight.sh archive
# 確認是本次要測試的 archive 後，以下指令會真的上傳
scripts/testflight.sh upload
```

輸出在 Git 忽略的 `.academic-local/TestFlight`。封存不會覆蓋既有同名 archive，請先另存舊版。上傳設定限 internal testing，沒有送 App Store 正式審查或外部測試，也不新增測試人員。App Store Connect 接收後仍需要 Apple 處理，不能把 Archive 成功當作 TestFlight 已可下載。

[Apple TestFlight 說明](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/)：內部測試供 App Store Connect 團隊測試人員使用；外部測試可能需要 Beta App Review。同一版本加 build 不保證外部測試完全免審。

## 本次測試重點

1. Google 登入後連結本人校務與 Moodle；略過、解除、重連及切換 Google 帳號。
2. 先備份既有私人課表，再確認預覽與匯入。驗證原課程 UUID、手動修改、衝突及重複匯入；兩台裝置同時匯入須另驗收。
3. 作業更新、私人標題／截止日／筆記覆寫、刪除後不復活、使用者確認已繳交後取消通知。
4. 成績、學期排名、畢業學分門檻是否和當次官方頁一致；斷網時保留更新日期。
5. 課程公告、教材、Moodle 內嵌登入與文件預覽；第三方教材工具尚未整合。
6. Widget、Live Activity、背景返回、通知權限關閉與重新啟用。

校方若改用尚未授權的 ohs 主機，連結會停止。不要以反覆輸入密碼重試處理未知主機。

## 本次發布結果（2026-11-02）

- 1.4.0（build 12）簽章封存成功，App 與 Widget build 一致。
- Xcode 上傳套件先查到已存在 build 11，自動調整為 12；已核對實際 IPA 的兩個 bundle 皆為 12，專案設定亦已同步。
- xcodebuild 最終回報 `Uploaded NTPUOne`、`EXPORT SUCCEEDED`，程序 exit code 0。這表示 Apple 已接收上傳，尚未透過 App Store Connect 驗證處理完成、內部群組分配或實際可下載。
- [App Store Connect TestFlight](https://appstoreconnect.apple.com/apps/6550918004/testflight/ios) 可查看後續處理及測試群組。依 [Apple 說明](https://developer.apple.com/help/app-store-connect/manage-builds/view-builds-and-metadata/)，處理成功才會進入可測試狀態。
- 本機可重用封存：`.academic-local/TestFlight/NTPUOne-build12.xcarchive`，為 build 12；早期 build 2 封存另行保留。封存與上傳日誌不納入 Git。
- 上傳有第三方 framework 缺少對應 dSYM 的警告，包含部分 Google 廣告、Firebase 與 gRPC 相依框架。Apple 仍接受本次套件；這些框架的崩潰堆疊符號解析可能不完整，後續應由相依套件供應的相符符號處理，不能用自行偽造的 dSYM 取代。

本輪介面修正使用 build 13 接續，不需每次調整行銷版本。外部測試仍依 Apple TestFlight App Review 規則處理。

## build 13 發布結果（2026-11-02）

- 本輪 [介面修正](ACADEMIC_UX_BUILD13.md) 已封存並上傳 1.4.0（13）；實際 IPA 的 App 與 Widget 皆已核對為 13。
- xcodebuild 回報 `Uploaded NTPUOne`、`EXPORT SUCCEEDED`，程序 exit code 0；尚未查證 Apple 後續處理、群組分配或實際可下載。
- build 13 封存為 `.academic-local/TestFlight/NTPUOne-build13.xcarchive`（13）；舊 build 12 與原自動調整為 12 的 build 2 封存均保留。若解析 build 12 的 crash，須按 UUID 選用正確 dSYM，而非只看封存檔名稱。
- 主 App 執行檔與自身 dSYM 的 UUID 相符；第三方套件仍有缺少 dSYM 的上傳警告。
- 三種真實校務頁皆通過原生 parser、舊快取與備註保留回歸檢查通過、37 項 Python 工具測試通過、Release 編譯與簽章 Archive 成功。
- 本機三台已配對裝置皆無可用連線，沒有取得當次閃退紀錄。移除 WebView 與改善首次載入不等於已證實閃退根因，仍需 build 13 的實機冷啟動測試。

本輪後續修改使用 build 14，見下方紀錄。

## build 14 發布結果（2026-11-02）

- [本輪三項修正](ACADEMIC_UX_BUILD14.md) 的完整封存已上傳為 1.4.0（14），實際 IPA 的主 App 與 Widget 皆已核對為 14。
- xcodebuild 最終回報 `Uploaded NTPUOne`／`EXPORT SUCCEEDED`，程序 exit code 0。Apple 後續處理、內部測試群組與實際可下載狀態尚未查證。
- build 14 完整封存已保留為 `.academic-local/TestFlight/NTPUOne-build14.xcarchive`。本輪兩份中間封存未上傳，檔名已標記 `not-uploaded`；未將中間版本用於發布。
- 已完成狀態與提醒遷移離線回歸、37 項探測工具測試、真實 Moodle API 型別驗證、最終簽章 Archive。首頁互斥導覽、通知實際送達與課程配對仍須手機驗收。
- 第三方 framework 的部分 dSYM 警告仍存在，未阻擋這次上傳。

後續有程式修改的測試版從 build 18 接續。

## build 15 發布結果（2026-11-02）

- [校務與備忘錄介面整理](ACADEMIC_UI_REFINEMENT.md) 已封存並上傳為 1.4.0（15）；實際上傳套件的主 App 與 Widget 均核對為 15。
- Xcode 回報 `Uploaded NTPUOne`、`EXPORT SUCCEEDED`，程序結束碼 0；Apple 後續處理、內部測試群組與實際可下載狀態尚未查證。
- build 15 完整封存已保留為 `.academic-local/TestFlight/NTPUOne-build15.xcarchive`，build 14 亦已另行保存；上傳設定僅供內部測試。
- 三位數學分的根因仍待有效校務 session 核對，不能視為已解決。已分開原本串接的欄位並保留來源數值；未猜測小數點或縮放。
- Release 簽章封存成功，離線解析及舊快取回歸通過；iPhone 16e 模擬器以合成資料檢查介面，仍需正式 App 與真實資料的實機驗收。

## build 16 發布結果（2026-11-02）

- [畢業門檻與學期分頁修正](ACADEMIC_UI_REFINEMENT.md) 已簽章封存並上傳 1.4.0（16）；實際上傳套件的 App 與 Widget 均核對為 16。
- Xcode 回報 `Uploaded NTPUOne`、`EXPORT SUCCEEDED`，程序結束碼 0；Apple 後續處理、內部群組與實際可下載狀態尚未查證。
- 新版依校方結構讀取「已累計總學分」、加總說明和分類學分，並顯示校方提供的其他門檻狀態；修正將校訂必修誤標成累計總學分的問題。
- 成績與排名按學年、學期由舊至新排序，最新學期預設選取並自動捲至可見。
- 解析、快取遷移、學期排序與其他學業整合離線測試通過；iPhone 16e 模擬器以合成資料檢查畫面。真實校務資料的新解析結果尚待 TestFlight 實機對照。
- build 16 封存保留為 `.academic-local/TestFlight/NTPUOne-build16.xcarchive`，前版封存亦保留。

## build 17 發布結果（2026-11-02）

- 管理員本機密碼改為由使用者在裝置設定並保存於 Keychain，移除源碼硬編碼，舊版管理模式需重新解鎖。
- 實際上傳套件的 App 與 Widget 均為 1.4.0（17），主執行檔不含舊版密碼；簽章 Archive 成功。
- Xcode 回報 `Uploaded NTPUOne`、`EXPORT SUCCEEDED`、程序結束碼 0；Apple 處理及可下載狀態尚未確認。
- Xcode 編譯成功，iOS 模擬器以獨立 App 和合成密碼完成 Keychain 保存、驗證、拒絕覆寫、舊狀態遷移與帳號切換檢查；尚需實機 Google 帳號與密碼設定流程驗收。
- 依使用者要求，本次修改未推送 GitHub。GitHub 目前版本及歷史仍含舊硬編碼密碼；舊密碼應視為洩露，停止使用。
- 最新完整封存為 `.academic-local/TestFlight/NTPUOne.xcarchive`（17）。

### 1.4.0 build 18（2026-11-02）

已上傳 App Store Connect 的內部測試版，Xcode 回報 `Uploaded NTPUOne` 與 `EXPORT SUCCEEDED`；上傳封包及封存均核對為 build 18。TestFlight 處理及測試群組可下載狀態尚未確認。包含懸浮 AI 聊天測試版與統一校務／Moodle 帳號入口；NTPU AI 校方 SSO、WebKit 串流與實機畫面仍需使用者實測。iOS 16 使用暫存網站登入狀態，iOS 17 以上依 App 帳號隔離網站資料。NTPU AI 首次登入仍透過官方頁面完成。

### 1.4.0 build 19（2026-11-02）

含公告輪播免廣告索引修正、AI 玻璃樣式、四類需啟用的 App 資料判斷與 Moodle 附件原生預覽。Xcode 回報 `Uploaded NTPUOne` 和 `EXPORT SUCCEEDED`；封存與實際上傳 IPA 核對 App／Widget 為 build 19。第三方 absl、grpc、grpcpp、openssl_grpc 缺少 dSYM 的警告不影響上傳，但相關崩潰可能無法完整符號化。TestFlight 處理及群組可下載狀態未確認。校方 AI SSO、模型分類、資料分享取消、Moodle 附件下載及 UI 需實機驗證；完整資料來源與尚未接入項目見 `docs/AI_DATA_INVENTORY.md`。

### 1.4.0 build 20（2026-11-02）

已完成 18 類唯讀 AI 資料來源、獨立成績授權與安全登入結構診斷，詳見 `docs/AI_DATA_INVENTORY.md`、`docs/AI_LOGIN_TEST.md`。撤回資料分享會中止請求並於下次開始新網站對話；不會刪除校方既有紀錄。同步更新 App 隱私說明。

完整封存為 `.academic-local/TestFlight/NTPUOne-build20-final.xcarchive`；實際上傳 IPA 的主 App 與 Widget 均核對為 1.4.0（20）。Xcode 回報 `Uploaded NTPUOne`、`EXPORT SUCCEEDED`，程序結束碼 0。Apple 已接收上傳，處理完成、內部群組分配與實際可下載尚未查證。第三方 absl、grpc、grpcpp、openssl_grpc 的 dSYM 警告仍存在，未阻擋上傳。

簽章 Release Archive、AI 串流合成測試、資料分類／敏感範圍與登入診斷遮蔽測試、41 項 Python 工具測試均通過。三個公開來源（校方課程搜尋、官方新聞、氣象觀測）已實際查詢成功；私人 Firebase／Moodle／校務資料、模型來源判斷、真實 SSO 與手機介面仍需實機驗證。診斷尚未代填或傳送 App 保存的帳密。依使用者要求，本輪未 commit 或推送 GitHub。

### 1.4.0 build 21（2026-11-02）

包含餐廳公開評論、本機通知設定與依公告名稱選取的圖片附件、首次開啟 AI 的 App 資料授權提示、明亮模糊背景、收起鍵盤、固定頁面導覽按鈕與 App 使用方式提示。Markdown 解析器沿用本機 ntpu-ai-vscode 的 markdown-it、KaTeX、highlight.js；原始 HTML 不執行，第三方授權隨 App 打包。頁面清單見 `docs/AI_PAGE_GUIDE.md`。

完整封存 `.academic-local/TestFlight/NTPUOne-build21.xcarchive` 已簽章成功；封存與實際 IPA 的 App／Widget 皆核對為 1.4.0（21），Markdown 解析資源已包含。第一次上傳因 Xcode 憑證讀取失敗；被中斷後仍在背景執行的 retry 隨後完成，上傳日誌 `/private/tmp/ntpu-ai21-upload-retry.log` 明確回報 `Uploaded NTPUOne`、`EXPORT SUCCEEDED`。原始指令被中斷，未取得其程序結束碼。後續 retry2 因 Apple 已有 build 21 回報 Redundant Binary Upload，未另增版本。Apple 後續處理、內部群組分配與手機可下載狀態仍未確認。

Debug 建置與 Release Archive 通過；AI 串流及圖片控制項合成測試、資料路由／成績授權與登入遮蔽測試、Markdown 表格／公式／程式碼及 HTML 安全測試、41 項 Python 測試均通過。真實模型分類、校方附件上傳／理解、Firebase 權限、頁面跳轉及手機介面仍待 TestFlight 實機驗證。本輪集中改善 AI 介面及主要入口，尚未完成全 App 每一頁的視覺重設與實機驗收。使用 App 保存帳密直接登入 AI 仍待登入診斷核對。未 commit 或推送 GitHub。

### 1.4.0 build 22（2026-11-02）

已上傳完整修正版：進入 App 的 AI 小提醒（預設開啟、公開／私人來源分流、30 分鐘節流、關閉氣泡與同一份聊天紀錄）、可沿用後續聊天的 App 資料／成績／提醒 Toggle、較透明背景、等待動畫與登入恢復等待狀態。另修正 AI 成績／畢業門檻跳轉視窗的環境注入、校方 GPA 頁尾解析及成績快取更新、Markdown 高度變動與原生按鈕／資料來源提示重疊。細節見 `docs/FLOATING_AI.md`。

最終完整封存為 `.academic-local/TestFlight/NTPUOne-build22-release.xcarchive`；前兩次 build 22 中間封存因納入使用者後續修改而中止，未上傳。最終 App／Widget 的封存與實際上傳 IPA 均核對為 1.4.0（22）。上傳日誌 `/private/tmp/ntpu-ai22-upload.log` 回報 `Uploaded NTPUOne`、`EXPORT SUCCEEDED`，程序結束碼 0。Apple 已接收上傳，處理完成、群組分配與 iPhone 可下載尚未查證。第三方 framework 的 dSYM 警告未阻擋上傳。

驗證包含 Debug 編譯、最終簽章 Release Archive、真實 Swift 校務解析器離線回歸（GPA 頁尾、學期分離、舊快取版本）、提醒來源／日期／節流政策、AI 串流／圖片控制項、Markdown 安全、登入診斷與 41 項 Python 測試。隔離無頭 Chrome 使用 App 相同 Markdown HTML／腳本測試長文、表格、公式、寬度縮小與動態新增內容的高度及末行留白，通過；此測試不等於 iOS WKWebView 與 SwiftUI 實機驗收。

使用者提供的去值 GPA 結構已確認並據以修正解析，未讀取或輸出實際 GPA。原閃退裝置堆疊未取得，已修正缺少校務環境注入的具體問題，仍需重測 AI 跳轉。首次登入與校方 AI 真實回覆、提醒、權限保存及手機版面同樣待 TestFlight 驗證。本輪未 commit 或推送 GitHub。

### 1.4.0 build 23（2026-11-02）

包含課程詳情統一區塊、Moodle 公告／教材／作業／成績四頁整理，以及檔案列多按鈕同時觸發與遲到下載回呼的修正。AI 新增使用手機 Keychain 已保存學校帳號登入官方 SAML 表單；帳密不加入聊天資料，遇驗證碼、OTP、表單變更、失敗或逾時改用手動頁面。首次實際登入仍待 iPhone 驗證。

新對話按鈕移至頂列，順序為新對話、資料設定、關閉；回覆泡泡、資料提示與進入 App 提醒加強深淺色底色與邊框，面板保留透明感。依使用者要求移除登入診斷按鈕與報告介面。

Debug 編譯、校務 Swift 解析回歸、AI 資料權限檢查、串流、Markdown 安全與高度留白、登入表單目的地／驗證碼／OTP 拒絕代填，以及 41 項 Python 測試通過。建置命令關閉 Xcode 使用者腳本沙箱，以處理既有 Crashlytics 腳本存取套件路徑限制，未改動專案的沙箱設定。實機配色、教材預覽及校方 SSO 仍需 TestFlight 驗收。未 commit 或推送 GitHub。

完整簽章封存為 `.academic-local/TestFlight/NTPUOne-build23-release.xcarchive`；中途 build 23 封存因納入後續調整而取消，未上傳。最終封存與實際待上傳 IPA 的主 App／Widget 均核對為 1.4.0（23）。`/private/tmp/ntpu23-upload.log` 回報 `Uploaded NTPUOne`、`EXPORT SUCCEEDED`，程序結束碼 0。Apple 已接收；後續處理、內部群組分配與實機可下載尚未確認。第三方 absl／grpc／grpcpp／openssl_grpc 的 dSYM 警告仍存在，未阻擋上傳。

### 1.4.0 build 24（2026-11-03）

修正首次從 Google 官方登入頁返回後仍停在 App 登入提示：等待登入回呼完成，以有效 Firebase 身分自動完成提示，亦處理初次呈現時已還原的工作階段；科系選擇不再阻擋進入 App。學校連結初次提示採與 Google 相同的卡片與主按鈕風格。

重新安裝仍有 Keychain 憑證、卻沒有本機身分／學期／Moodle 使用者快取時，可由經驗證的校方回應重建；既有身分或另一服務不符仍拒絕。保存帳密與實際同步狀態分開呈現，校務與 Moodle 分別嘗試。公開課程查詢失敗不再擋住正式課號與 Moodle 核對；未知名稱／時段明確標示待更新，不猜時段。不可讀快取保留 recovery 檔後重建，手動連結可重新嘗試安全保存。

AI 每輪提供台北時區日期、星期、時間；明確說明 NTPU One 助理能力、可查來源與目前授權，不把本輪沒附資料說成沒有查詢能力。進入提醒取代 30 分鐘節流，改為每次開啟／從背景回到前景最多一次，必須已登入、開啟提醒且面板關閉；短暫系統 inactive 與切分頁不重複觸發，下一次進入可再提醒。AI 跳轉先收鍵盤與面板再切頁；課表改用固定列距的 eager 欄組，移除首頁標題下問候小字。

Debug 編譯、Swift 校務解析與身分恢復政策、日期跨日／跨年／星期、提醒資格、資料權限／能力提示、AI 串流、登入表單與 Markdown 安全檢查，以及 41 項 Python 測試通過。真實 Google 返回、重新安裝後同步、模型回覆、提醒及鍵盤跳轉間距仍須在 iPhone 驗收；未取得原問題的裝置日誌。未 commit 或推送 GitHub。

最終簽章封存為 `.academic-local/TestFlight/NTPUOne-build24-final.xcarchive`。先前 build 24 中間封存因納入後續要求而取消，未上傳。最終封存與實際上傳 IPA 的 App／Widget 均核對為 1.4.0（24）。`/private/tmp/ntpu24-upload.log` 回報 `Uploaded NTPUOne`、`EXPORT SUCCEEDED`、程序結束碼 0，並顯示上傳套件已進入處理。Apple 已接收；內部群組分配與 iPhone 可下載尚未確認。第三方 framework 的 dSYM 警告未阻擋上傳。

## build 25（2026-11-03）

版本 1.4.0 build 25 已完成 archive 與上傳，Xcode 回報 `Uploaded NTPUOne`、`EXPORT SUCCEEDED`；App Store Connect 後續處理及測試者可下載狀態需另行確認。上傳時第三方 absl、grpc、grpcpp、openssl_grpc 缺少 dSYM 警告，可能影響那些第三方函式庫的閃退符號化。真實帳號、Duo 實機與 AI 寫入流程仍需驗收。

## build 26（2026-11-03）

版本 1.4.0 build 26 已完成 archive 與上傳，Xcode 回報 `Uploaded NTPUOne`、`EXPORT SUCCEEDED`；App Store Connect 的處理與測試者可下載狀態仍待確認。第三方套件有 dSYM 缺漏警告，可能影響相關閃退符號化。搜尋、校方對話刪除與實際帳號操作尚需在手機驗收。

### 第三方符號檔追查

build 26 的主程式 dSYM 存在；封存及目前下載的套件中，11 個動態 framework UUID 找不到相符的 dSYM（包括 gRPC、absl、Google Mobile Ads 與 Firebase）。`python3 scripts/check_archive_symbols.py <archive>` 可重跑檢查，缺漏時回傳非零。第三方二進位必須取得 UUID 完全相符的供應商 dSYM，不能用主程式 dSYM 代替；尚未找到這些檔案。參考 Apple 的 Locating a missing debug symbol file 和 Firebase Crashlytics 的符號上傳說明。

## build 27（2026-11-03）

版本 1.4.0 build 27 已封存並上傳，Xcode 回報 `Uploaded NTPUOne` 與 `EXPORT SUCCEEDED`；App Store Connect 處理及測試者可下載狀態待確認。新增管理員功能開關、舊使用者學校連結提示與批次變更預覽。管理員規則模擬測試通過；批次操作、iCloud 與手機介面仍待實機驗收。本版封存仍缺 11 個第三方 framework 的匹配 dSYM。

## build 28（2026-11-03）

版本 1.4.0 build 28 已封存並上傳，Xcode 回報 `Uploaded NTPUOne` 與 `EXPORT SUCCEEDED`；App Store Connect 後續處理及下載狀態待確認。AI 拖曳關閉和本機歡迎訊息已通過政策測試及模擬器編譯，觸控手感仍需裝置驗收。既有第三方 dSYM 缺漏警告仍存在。

## build 29（2026-11-03）

版本 1.4.0 build 29 已封存並上傳，Xcode 回報 `Uploaded NTPUOne` 與 `EXPORT SUCCEEDED`；Apple 後續處理及 TestFlight 下載狀態待確認。Duo 模擬器已確認內螢幕入口與開關、外螢幕直向／橫向入口、分頁操作及外螢幕下拉關閉。原有第三方 dSYM 缺漏警告仍存在。

## build 31（2026-11-03）

版本 1.4.0 build 31 已封存並上傳，Xcode 回報 `Uploaded NTPUOne` 與 `EXPORT SUCCEEDED`；Apple 處理及下載狀態待確認。AI 面板與提醒動畫已改以右下方懸浮按鈕為中心；Duo 模擬器已檢查面板進出，登入後提醒仍需手機驗收。先前 build 30 因動畫方向更正而中止上傳。既有第三方 dSYM 缺漏警告仍存在。

## build 32（2026-11-03）

版本 1.4.0 build 32 已封存並上傳，`/private/tmp/ntpu32-upload.log` 回報 `Uploaded NTPUOne`、`EXPORT SUCCEEDED`，程序結束碼 0；Apple 後續處理及 TestFlight 下載狀態待確認。

移除 AI 頂部多餘留白，拖曳改為直接跟手並在取消時彈回，避免拖曳狀態歸零與關閉動畫同時發生；開關動畫仍以右下懸浮按鈕為中心。Duo 模擬器已確認標題區拖曳關閉。一般手機隱藏並排選項；Duo 視窗偵測到摺疊區後才提供並排，不依裝置名稱猜測。

移除獨立搜尋介面，新增「需要時自動搜尋網路」設定。預設關閉以保留第三方資料傳送選擇，啟用後由 AI 判斷公開搜尋需求，經格式篩選的查詢送至 Exa；App 私人資料不直接當作搜尋內容。篩選無法保證辨識所有個資，使用時仍應避免輸入敏感資料。政策測試、橋接測試、Debug 編譯及 Release 封存通過；真實校方帳號的自動搜尋與手機動畫仍待驗收。既有第三方 dSYM 缺漏警告仍存在。

## build 33（2026-11-03）

版本 1.4.0 build 33 已封存並上傳，`/private/tmp/ntpu33-upload-retry.log` 回報 `Uploaded NTPUOne`、`EXPORT SUCCEEDED`，程序結束碼 0；App Store Connect 後續處理與測試者可下載狀態待確認。修正 AI 面板拖曳：手指按住時不更新面板位移，放開後才依手勢距離決定收起或以彈簧動畫回原位。封存仍有第三方 `openssl_grpc.framework` dSYM 缺漏警告。

## build 34（2026-11-03）

版本 1.4.0 build 34 已完成簽章封存並上傳，Xcode 回報 `Uploaded NTPUOne` 與 `EXPORT SUCCEEDED`；App Store Connect 後續處理及 TestFlight 可下載狀態待確認。本版讓 AI 面板在手指拖曳期間即時跟隨垂直移動，放手後依門檻收起或彈回。第三方 Firebase／Google framework 仍有缺少匹配 dSYM 的警告，未阻擋上傳。
