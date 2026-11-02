# 遠端修改後的 TestFlight 流程

App 與 Widget 維持行銷版本 1.4.0，本次 build 設為 2。後續每次上傳只遞增 CURRENT_PROJECT_VERSION；不要為每次內部測試改行銷版本。Export 允許 Xcode 調整尚未使用的 build number，以 App Store Connect 實際接收的版本為準。

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
