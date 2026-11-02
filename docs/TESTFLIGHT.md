# 遠端修改後的 TestFlight 流程

App 與 Widget 維持行銷版本 1.4.0，本次 build 設為 12（Apple 回報既有最高 build 為 11）。後續每次上傳只遞增 CURRENT_PROJECT_VERSION；不要為每次內部測試改行銷版本。Export 允許 Xcode 調整尚未使用的 build number，以 App Store Connect 實際接收的版本為準。

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
- 本機可重用封存：`.academic-local/TestFlight/NTPUOne.xcarchive`，為 build 12；早期 build 2 封存另行保留。封存與上傳日誌不納入 Git。
- 上傳有第三方 framework 缺少對應 dSYM 的警告，包含部分 Google 廣告、Firebase 與 gRPC 相依框架。Apple 仍接受本次套件；這些框架的崩潰堆疊符號解析可能不完整，後續應由相依套件供應的相符符號處理，不能用自行偽造的 dSYM 取代。

後續內部測試由 build 13 接續，不需每次調整行銷版本。外部測試仍依 Apple TestFlight App Review 規則處理。
