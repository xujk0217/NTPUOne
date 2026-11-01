# 校務系統與 Moodle 整合進度

更新日期：2026-11-02（Asia/Taipei）。基準 commit：`6976954`。

本文件記錄實際查證結果。歷史 Postman 回應不是本次登入成功的證據；離線工具測試不代表校方 API 整合完成。尚未驗證真實資料格式前，不改寫既有 UI、課表、備忘錄或 Core Data schema。

## 階段狀態

| Phase | 目標 | 狀態 |
| --- | --- | --- |
| 0 | 架構、資料流與建置基準 | 完成 |
| 1 | Moodle 登入、本人課程／作業／提交狀態 | 準備唯讀驗證，尚未通過驗收 |
| 2 | 校務登入、本人實際選課代碼與相容性 | 未完成；可獨立研究公開登入入口 |
| 3 | 重用課程查詢、一鍵匯入且不破壞原課表 | 未開始；依賴 Phase 2 |
| 4 | Moodle 作業整合既有 Memo | 未開始；依賴 Phase 1 真實資料 |
| 5 | 遠端提交狀態與本機完成確認／通知 | 未開始；依賴 Phase 4 |
| 6 | Moodle 公告、教材與可讀取成績 | 未開始 |
| 7 | 校務成績、GPA 與經查證的畢業進度 | 未開始；依賴 Phase 2 |
| 8 | Widget／Live Activity 與跨頁面整合 | 未開始 |

## Phase 0：架構分析

### 導覽與共用資料

- `NTPUOneApp.swift` 的 `LoadedAppContent` 在共享資料庫成功載入後建立 `CourseData`，以 environment object 傳入 App。
- `ContentView.swift` 建立 `MemoManager`，使用同一個 `CoreDataManager.shared.persistentContainer.viewContext`。
- 既有五個 Tab 為首頁、待辦、課表、交流區與關於；不新增 Moodle 或成績主 Tab。
- `WebViews/LinkView.swift`（首頁）、`MemoView/TodayView.swift` 與 `CourseList/CourseGridView.swift` 已讀取這兩個 manager。首頁卡片、課程詳情及來源標籤應在後續階段沿用既有畫面。

### 公開課程搜尋 → 本機課表

1. `CourseGet.swift` 的 `CourseGViewModel.fetchCourses()` 以 POST 呼叫 `https://sea.cc.ntpu.edu.tw/pls/dev_stud/course_query_all.queryByKeyword`。
2. 傳入 `qYear`、`qTerm`、`courseno`、`cour`、`teach`、`week`、`seq1`、`seq2`，回應依 BIG5 解碼，再由 SwiftSoup 解析 `table#example tbody tr`。
3. 目前依欄位位置取代碼（第 4 欄）、名稱（第 8 欄）、教師（第 9 欄）、時間與地點（第 14 欄），回傳 `CourseG`。這是公開課程目錄，不能證明本人已選修。
4. 現有 `parseHTML` 是 ViewModel 的 private 方法，帶有錯誤狀態副作用與完整 HTML debug 輸出；時間文字轉星期／節次則在 `CourseGetView` 內。可以不建立畫面而呼叫 ViewModel，但尚無純搜尋／解析 Service；Phase 3 應抽取共用核心，不能新增第二套解析器。
5. `CourseGFormView.saveCoursesInTimeRange()` 將節次區間展開成數筆 `Course`，每節使用新的 UUID。衝突處理目前可刪除舊節次後重建，不能直接套用到自動匯入。
6. `CourseData.addCourse()` 寫入 `CourseEntity`、設定起始時間並保存，再更新記憶體陣列、通知及 Live Activity／Widget。

### 課程模型與相容性限制

- `Course`／`CourseEntity` 以一筆表示一個星期與節次，包含 `id`、名稱、教師、教室及提醒設定。
- 目前沒有正式的學年、學期、校務課號、遠端課程 ID、來源或帳號範圍欄位。
- `CourseG.id` 是課號，不能直接取代現有每節課 UUID；自動匯入應另做來源映射，保留已存在的 `Course.id`。
- 目前時間解析取主要字串並可能以星期一／第一節預設回退。多個星期、非連續節次、合班與空教室都需要真實案例驗證；自動匯入不得默默接受這些回退。

### 備忘錄、完成狀態與關聯

- `MemoData.swift` 的 `Memo` 包含標題、私人內容、分類、優先級、截止／計畫／完成時間與提醒規則。
- `Memo.courseLink`／`MemoEntity.courseLink` 存 `Course.id`；部分課程詳情會聚合同名課程的多個節次，但這不能作為跨課程的可靠遠端映射。
- `MemoManager.addMemo`、`updateMemo`、`deleteMemo` 處理保存、篩選排序、通知與 Live Activity。`markAsCompleted()` 設 `.done` 及完成時間，再走 `updateMemo`；`markAsIncomplete()` 為明確的使用者狀態操作。
- `MemoStatus` 有未完成、進行中、已完成、已延後；不能直接當 Moodle 的 draft／submitted／graded 狀態使用。
- 現有資料沒有 Moodle 來源 ID、來源版本、帳號隔離或「已拒絕完成建議」metadata。Phase 4–5 需另外確認儲存設計，不能把私人備註與遠端說明放進同一個可覆寫欄位。

### 儲存、CloudKit 與跨裝置風險

- `CoreDataManager` 使用 App Group `group.NTPUOne.NextCourseWidget/shared.sqlite`，App container 為 `NSPersistentCloudKitContainer`，雲端 container 為 `iCloud.com.xujk.NTPUOne`。
- `CourseModel.xcdatamodeld` 現有實體為 `CourseEntity` 與 `MemoEntity`，屬性多為 optional，未有遠端學校帳號的擁有者範圍。
- CloudKit 對應的是 Apple/iCloud 使用者，不等於目前學校登入帳號。學校帳號切換不能共用同一筆 Moodle 映射；token 不得進 SQLite、UserDefaults、CloudKit 或 Firebase。
- Phase 0 不改 schema、不遷移、不清空資料；後續若新增持久化來源 metadata，須先驗證輕量遷移、CloudKit 相容性與帳號隔離，再決定實作。

### Widget、Live Activity 與通知

- `NextCourseWidgetBundle.swift` 中的 `WidgetPersistence` 唯讀開啟既有共享 SQLite；各 provider 直接讀取課程／備忘錄，並以既有深連結回到 Tab。
- `NextCourseLiveActivityManager.sync(courses:memos:)` 沿用現有 ActivityKit 管理，受功能開關、App active 狀態及系統可用性限制；不能假設背景能任意同步。
- 課程通知依課程 ID 管理。備忘錄由 `scheduleNotification(for:)` 及 `cancelNotification(for:)` 管理，以 Memo ID 派生識別碼。
- Memo 現有自動截止提醒為一天前及三十分鐘前，另有計畫時間與自訂規則；需求中的三天前等提醒尚未新增。
- 多節課匯入、日期改動與標記完成必須沿用原有通知入口，不能另外建立不受管理的通知。

## Phase 0：Postman 分析（只讀結構）

原檔保留在使用者 Downloads，未複製至儲存庫，也未重放其帳密、Cookie 或動態參數。

| Request | Method／Endpoint | 非敏感結構與限制 |
| --- | --- | --- |
| 公開課表 | POST `sea.cc.ntpu.edu.tw/pls/dev_stud/course_query_all.queryByKeyword` | 與既有 App 相同參數，非個人選課清單 |
| 全校公告 | POST `api-carrier.ntpu.edu.tw/strapi` | GraphQL JSON body，非 Moodle 課程公告 |
| 舊校務登入 | POST `ohs01.ntpu.edu.tw/pls/pm/stud_system.login` | 表單鍵 `stud_num`、`passwd`；有一份歷史 HTTP 200 回應、6 個 Set-Cookie header，body 含 `query_all_course.login2` 與動態 `date1` |
| 成績 | GET `ohs01.ntpu.edu.tw/pls/univer/query_all_course.judge` | query 鍵為 `func`、`date1`；沒有保存可用的真實成績回應結構 |

此 collection 沒有 Moodle Request，沒有新版 `my.ntpu.edu.tw` 的登入或個人選課 Request。歷史登入 HTTP 200 與二次導覽線索都不能證明現在可用；沒有使用保存的密碼或歷史 Session 進行測試。

## Phase 0：本次基準驗證

- Xcode 26.0.1，Release、generic iOS、`CODE_SIGNING_ALLOWED=NO`：`BUILD SUCCEEDED`，exit code 0。
- Core Data 回歸檢查：PASS，exit code 0；包含失敗時資料保留與重試。
- YouBike 回歸檢查：PASS，exit code 0。
- 仍有既有 concurrency／未使用變數等警告；不將無簽章建置視為真機或全功能驗收。
- 本次未執行真機 UI、CloudKit production 同步、遠端資料寫入或 schema 修改。
- 暫存建置紀錄：`/private/tmp/ntpuone-academic-baseline-build.log`。測試重跑步驟見 [tests/README.md](../tests/README.md)。

## 下一步與停止條件

Phase 1 先做無憑證的站台／Mobile service 探測與安全本機工具。需要開發者輸入憑證時，不要求將密碼貼到聊天；提供本機隱藏輸入流程。未取得本人真實課程、作業及可靠提交狀態前，不標記 Phase 1 完成、不開始 Moodle 待辦整合。

Phase 2 可獨立研究舊／新版系統的公開登入流程，但在登入及本人選課資料未確認前，不建立課表匯入按鈕、不改寫原課表。
