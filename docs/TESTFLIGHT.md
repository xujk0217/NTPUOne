# 遠端修改後的 TestFlight 流程

App 與 Widget 維持行銷版本 1.4.0，目前 build 設為 16；前一個已上傳 build 為 15。後續每次上傳只遞增 CURRENT_PROJECT_VERSION；不要為每次內部測試改行銷版本。Export 允許 Xcode 調整尚未使用的 build number，以 App Store Connect 實際接收的版本為準。

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

後續有程式修改的測試版從 build 17 接續。

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
- 最新完整封存為 `.academic-local/TestFlight/NTPUOne.xcarchive`（16），前版封存分別保留。
