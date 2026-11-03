# iPhone Duo 開發與驗收紀錄

## 官方資料與環境

- [Apple：三步準備 iPhone Duo](https://developer.apple.com/iphone-duo/prepare/)：iOS 27.1 以上 SDK 的 App 可使用完整顯示範圍；尺寸隨外螢幕、內螢幕與多工而變動。應以目前視窗及 safe area 排版，避免使用主螢幕尺寸或以方向、裝置型號猜測版面。
- [Apple：準備 App](https://developer.apple.com/videos/play/tech-talks/111461/)：系統導覽列與分頁列會適應水平或垂直擺放；safe area 可能不對稱。應測試系統分割多工的左右兩側。
- [Apple：適應摺疊配置](https://developer.apple.com/videos/play/tech-talks/111463/)：系統容器已處理許多摺痕；自訂內容可使用 ReservedRegion 避開摺痕及相機，並在適當層級選擇 split／overlay arrangement。ArrangementView 不提供導覽，不建議將導覽容器放入其中。
- [Apple：多視窗及多螢幕](https://developer.apple.com/videos/play/tech-talks/111464/)：系統分割多工可同時顯示兩個 App；多 Scene 的呈現必須使用來源視窗。Hinge 角度適合互動效果，版面優先用區域及配置 API。
- [Apple：人機介面指南](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo)：保持開合期間的操作與狀態連續，避免隱藏功能；測試外屏、內屏及不同半折姿態。

本機檢查為 Xcode 27.2、iOS 27.2 SDK；部署目標維持 iOS 16。iOS 27.1 以下使用不依賴新 API 的浮動面板。裝置型號與物理尺寸不作為版面判斷依據。

## 專案修改

AI 工作區使用本地 GeometryProxy 的 division／occlusion 區域決定版面：有足夠空間時左右並排；橫向摺痕形成上下可用區時上下排列；空間不足或使用者關閉並排時使用浮層。主頁與聊天面板不因幾何變化切換 View 身分。AI 的頁面按鈕可在主區開啟目的頁，並排時保留聊天；系統工具列承載入口與提醒，隨系統自動調整位置。

Google、Safari 與廣告的呈現來源改由當前視圖取得，避免全域搜尋第一個視窗。首次登入及學校連結提示可捲動；鍵盤工具列不再以 UIScreen.main 決定寬度。支援外螢幕橫向。模擬器建置不執行 Crashlytics 裝置符號上傳，裝置封存仍執行原腳本。

## 驗證矩陣

應使用 Device Hub 實測：外螢幕直向／橫向、內螢幕直向／橫向、書本半折、桌面半折、帳篷、系統 Split View 左右、鍵盤、較大文字、深淺色、AI 並排與浮層切換、頁面跳轉、登入、Safari 與廣告。幾何單元檢查和編譯不能取代真正姿態與登入資料測試；未經驗證的情況不得標示完成。

## 本次模擬器實測

Xcode Device Hub 使用帶 App Group 權限的簽章模擬器 build 25：外螢幕直向／橫向、內螢幕直向／橫向、書本半折、桌面半折均可開啟 AI；外螢幕及內屏直向使用浮層，內屏橫向及書本姿態左右並排，桌面姿態上下並排。並排時從首頁切換到課表，AI 保留。未觀察到可見文字重疊或共用資料空間錯誤。

先前未簽章模擬器套件沒有 App Group 權限，曾顯示「無法存取共用資料空間」；簽章套件未再重現。不能據此判定真機相同訊息的原因。系統 Split View、帳篷姿態、真實帳號聊天與鍵盤，以及實機 CloudKit 仍待驗收。
