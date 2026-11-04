# TestFlight 1.4.0（42）

發布日期：2026-11-05（Asia/Taipei）。App 與 Widget 的 build 號均為 42。

## 修改內容

- AI 單筆與批次提案共用已套用狀態，批次日期使用原生選擇器，並顯示提醒資訊。
- 整理 AI 帳號狀態、資料授權及來源說明；失敗時可帶回原問題重新編輯。
- 修正新手導覽結束時機，學校連結頁補上 Google 登入、分服務重試及更新時間。
- 首頁優先呈現待辦，餐廳推薦可展開；備忘錄刪除提供復原，清空課表可保留備忘錄。
- Moodle 教材／檔名搜尋、重試與更新狀態；成績空白頁補上可操作入口。

詳細實作及驗證範圍見 `UIUX_IMPLEMENTATION_2026-11-05.md`。

## 發布證據

- 功能及版本提交已推送 `origin/main`，發布準備提交為 `f399578`。
- Release archive：成功，封存內 App 與 Widget 版本一致。
- App 與 Widget 的 dSYM UUID 均與執行檔相符。
- `xcodebuild -exportArchive` exit code：0。
- Apple 上傳結果：`Uploaded NTPUOne`、`EXPORT SUCCEEDED`。
- 使用既有自動簽章與 TestFlight internal-testing-only 設定；不在 Git 儲存帳密、憑證或封存檔。

本機封存：`.academic-local/TestFlight/NTPUOne-build42.xcarchive`。
本機日誌：`/private/tmp/ntpu42-archive.log`、`/private/tmp/ntpu42-upload.log`（不提交原始日誌）。

## 限制

Apple 接受上傳；尚未核實 App Store Connect 的後續處理與可下載狀態。

上傳另回報 11 個第三方 framework 的 dSYM 警告，未阻擋本次上傳。已檢查本機套件，未找到可匹配的 SDK 符號檔；這些 SDK 內部的崩潰堆疊可能無法完整還原。本身 App 與 Widget 的符號檔完整。
