# 校務整合驗證紀錄

日期：2026-11-02（Asia/Taipei）。不保存原始個人頁面、成績、學號、Cookie 或 token。

| 檢查 | 結果與範圍 |
| --- | --- |
| Release 建置 | generic iOS、無簽章建置成功 |
| 簽章 Archive | 1.4.0 build 12；App 與 Widget 版本一致，Archive 成功 |
| TestFlight 上傳 | 1.4.0（12）；Uploaded NTPUOne／EXPORT SUCCEEDED，exit 0；尚未確認 Apple 處理與群組分配 |
| Python 探測工具 | 37 項測試通過 |
| App 同份 Swift 服務與政策 | 離線 parser、身分、時段、保留 UUID／私人修改、完成條件等檢查通過 |
| 真實 Moodle（Swift） | 60 門 timeline 課程；目前學期樣本 12 份作業／12 份提交回應；7 內容區段、4 公告、2 本人評分項目 |
| 真實 SIS 選課（Swift） | 本人正式學期 6 門已核准課程；公開 CourseGet 配對 6／6，解析 14 個每週節次 |
| 真實 SIS 報表（Swift） | 成績、學期排名、畢業學分進度三種原始頁通過身分／格式檢查及安全清理 |
| Core Data 回歸 | 載入失敗保留資料、重試、儲存失敗與 App Group 缺失檢查通過 |
| YouBike 回歸 | 分頁、ID 去重、校區半徑、非法座標、HTTP 失敗、重複頁與空資料檢查通過 |

真實查證使用本人先前於本機登入的 Keychain 資料，透過記憶體管線呼叫同份 Swift 服務；個人資料不進測試 fixture。CLI 舊校務 session 最後一次觀察已過期，不能據此保證 iOS 登入仍有效。

## 尚未代表通過的驗收

完整 iOS 帳密登入、Google 帳號切換、CloudKit 多裝置同時匯入、通知實際送達與取消、Widget／Live Activity 時序、第三方 Moodle 外部工具及所有團體作業狀態，仍須實機驗收。

簽章 Archive 成功不代表 Apple 已接收上傳、完成處理或已分配至測試群組。TestFlight 流程與最終發布狀態見 [TESTFLIGHT.md](TESTFLIGHT.md)。
