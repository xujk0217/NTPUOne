# 學校帳號連結與同步設計

2026-11-02。這是實作決策，完成狀態另見 ACADEMIC_INTEGRATION_PROGRESS.md。

## 登入

Google 維持現有 App 身分；成功後引導連結學校帳號，也可略過並在「我的」補做。
校務與 Moodle 分別驗證，不假設兩邊密碼相同。不把 Google OAuth token 當校務 token。
輸入頁說明目的地、保存方式、同步範圍及如何解除連結。
密碼／token 只存裝置 Keychain，禁止 Firebase、CloudKit、UserDefaults、日誌及 Widget 讀取。
學校登入資料按 Google uid 分開；每次回應還要比對學校身分，帳號切換後忽略舊請求。
解除連結刪本機登入資料，停止同步，保留使用者已匯入的課表及私人待辦。
Google 登出時不刪個人的既有課表，但不讓下一個 Google 身分沿用上一個連結。

## 更新時機

| 資料 | 自動檢查 | 使用者控制 |
| --- | --- | --- |
| 作業及提交狀態 | App active；5 分鐘內成功同步不重複；同時只跑一組請求 | 手動重新整理可略過成功快取；失敗退避，認證失效要求重連 |
| 課表來源 | 首次連結、學期切換或距上次成功 30 天 | 立即重新整理、先看預覽再套用 |
| 公告、教材 | 開啟該課內容時查詢，不與每次 App active 綁死 | 手動更新 |
| 成績、排名、畢業進度 | 連結後每日檢查／手動更新；限已驗證的本人來源 | 個人敏感內容不進共用 Widget／Firebase |

先顯示上次成功資料，再做非阻塞更新；錯誤保留舊資料與最後成功時間。
App active 是前景內的背景工作，不保證 App 被關閉後能固定時間執行。
不使用定時器反覆嘗試密碼；沒有連結的來源不發送個人 API 請求。

## 資料保護與匯入

不改寫既有 Course／Memo UUID。來源 key 必須包含站台、學校身分、學期及遠端 ID。
新增或更新後沿用既有 Core Data、通知、Widget 及 Live Activity 管理。
課表衝突、未知時段、非核准狀態、空清單及不同學期先停止，不預設星期一第一節，也不刪課。
更新只處理已匯入且未被手動修改的資料；手動課表保留。來源消失不自動刪除。
Moodle 說明與私人筆記分開，標題／截止時間的使用者修改保留。已刪除的匯入待辦不在下一次同步復活。
本機來源 metadata 使用裝置受保護、排除備份的檔案；不新增 CloudKit schema。
已匯入的課程與待辦仍遵循 App 原有的私人 iCloud 同步，連結畫面必須說明。

## 完成狀態

只有已驗證的個人 submitted 可提出完成建議；草稿、未提交、未知、分數、逾期及未驗證團體狀態不能推論完成。
使用者確認才走 MemoManager 的既有完成操作，並取消既有待辦提醒。
拒絕同一來源版本後不反覆詢問；遠端 reopened 不自動撤銷本機完成。

## 尚需實機驗證

iOS Keychain、Google 後續導覽、網路中斷與重連、CloudKit 多裝置去重、通知及 Widget 時序，不能用本機合成測試代替。

參考：[Apple 背景工作](https://developer.apple.com/documentation/backgroundtasks/choosing-background-strategies-for-your-app)、[Keychain 可存取性](https://developer.apple.com/documentation/security/ksecattraccessiblewhenunlockedthisdeviceonly)。
