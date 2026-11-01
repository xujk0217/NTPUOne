# 校務系統與 Moodle 整合進度

更新日期：2026-11-02（Asia/Taipei）。基準 commit：`6976954`。

本文件記錄實際查證結果。歷史 Postman 回應不是本次登入成功的證據；離線工具測試不代表校方 API 整合完成。尚未驗證真實資料格式前，不改寫既有 UI、課表、備忘錄或 Core Data schema。

## 階段狀態

| Phase | 目標 | 狀態 |
| --- | --- | --- |
| 0 | 架構、資料流與建置基準 | 完成 |
| 1 | Moodle 登入、本人課程／作業／提交狀態 | 核心真實 API 已打通；完整狀態及學期對應驗收尚未完成 |
| 2 | 校務登入、本人實際選課代碼與相容性 | 新版 session 與正式查詢入口已確認；已讀到 6 筆選課列，學期／課號相容性仍待驗證 |
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

## Phase 1：真實 Moodle 驗證結果

### 已完成的實際驗證

1. 無憑證 GET 首頁與 `/login/index.php`：HTTP 200，登入表單包含當次 `logintoken`、`username`、`password`；本次沒有發現 CAPTCHA 字樣，但這不保證帳號、網段或後續狀態永遠沒有互動驗證。
2. POST `/lib/ajax/service.php?info=tool_mobile_get_public_config`，body 為 `[{index:0, methodname:tool_mobile_get_public_config, args:{}}]`：HTTP 200、`error=false`。實際 `enablewebservices=1`、`enablemobilewebservice=1`、`typeoflogin=1`。Moodle 官方常數中 1 代表 App 內登入，不是強制 browser 模式。
3. 無帳密 POST `/login/token.php`：HTTP 200，但 JSON `errorcode=missingparam`，未登入。
4. 無 token POST `/webservice/rest/server.php`，指定 `core_webservice_get_site_info`：HTTP 200，但 `errorcode=invalidtoken`，未登入。
5. 開發者親自在自己的 Terminal 以隱藏輸入執行 `scripts/academic_probe.py login`，回報 `identity_verified_token_saved_to_keychain`；後續本機工具確實從 Keychain 讀取 token 並核對本人 userid 成功。AI 沒有接收或保存開發者輸入的帳號密碼。
6. `core_webservice_get_site_info` 實際回傳本人身分與 375 個可用函式的目錄；下表列出的查詢函式皆有列入。只記錄 schema、布林結果與數量，不記錄個人欄位值。
7. 課程 timeline 以 `classification=inprogress`、`limit=50`、`offset` 分頁，實際收到 50、10、0 筆，共 60 門已註冊的 Moodle 課程。60 門全部 `enddate=0`，因此不能以該分類等同本學期正式選課。
8. 60 門課都有名稱及同站課程連結；其中 6 門在 `fullname`、`shortname`、`idnumber` 各有 115-1 線索。工具以至少兩欄吻合篩出候選，但仍標記 `semester_mapping_verified=false`，尚未與校務正式選課核對。
9. 對這 6 門候選課讀取作業，實際回傳 11 筆 assignment；本次依限量設定讀取其中 10 筆本人提交狀態，均觀測到 `lastattempt.submission.status=submitted`。沒有提交作業、修改成績或更新任何 App 待辦。
10. macOS Keychain 實際寫入／讀取／刪除臨時隨機值測試通過；此測試值不是學校 token，不作為登入成功證據。

### 已實測 API 與結構

| Endpoint／function | Authentication／參數 | 實際觀測／限制 |
| --- | --- | --- |
| POST `/login/token.php` | 本機隱藏輸入 `username`、`password`；`service=moodle_mobile_app` | 開發者當次登入取得可用 token；僅 token 與本人 userid 存 Keychain，不保存密碼、privatetoken 或 Cookie |
| POST `/webservice/rest/server.php` → `core_webservice_get_site_info` | POST body `wstoken`、`wsfunction`、`moodlewsrestformat=json` | 本人 userid、functions、站台欄位；每次重查本人身分，不能只憑 token 非空就通過 |
| 同上 → `core_course_get_enrolled_courses_by_timeline_classification` | 本人 token；`classification=inprogress`、`limit`、`offset` | `{courses:[{id,fullname,shortname,idnumber,startdate,enddate,viewurl,...}],nextoffset}`；沒有校務正式選課狀態 |
| 同上 → `mod_assign_get_assignments` | 本人 token；`courseids[0]` 由剛回傳的本人課程 id 取得 | `{courses:[{id,assignments:[{id,cmid,name,intro,duedate,submissiondrafts,teamsubmission,requireallteammemberssubmit,...}]}],warnings}`；deadline 0／延期及團體設定須分別處理 |
| 同上 → `mod_assign_get_submission_status` | 本人 token；`assignid` 由該課實際回傳取得，不傳他人 userid | `lastattempt.submission.status`、`lastattempt.graded`、`gradingstatus`、`feedback` 等；只記錄型別與受限狀態，成績值不輸出 |
| 同上 → `core_calendar_get_action_events_by_timesort` | 伺服器目錄宣告可用 | 尚未實際讀取，不宣稱已驗證；Quiz／Forum 也尚未驗證 |

所有帶 token 的請求都使用 HTTPS POST body，不把 token 加到 URL；只允許選定的唯讀函式。工具遇到 redirect、未知身分、未知 schema、警告或分頁重複即停止。個人 API 原始回應未納入 Git。

### 提交狀態的驗收界線

- `submitted` 與 `graded` 分開觀察；分數存在、逾期或 draft 都不會觸發本機完成。
- `new`、`draft`、`submitted`、`reopened` 只作來源狀態；未知值顯示 unknown，不回退為完成。
- 個人與團體 submission 分開，尚未驗證的團體規則／全員確認不可推論已完成。
- 本人這次樣本只觀測到 submitted；草稿、重開、未提交、延期、Quiz／Forum 及團體提交情境尚未有本人的 live 樣本。
- 逾期是 deadline／延期與目前時間的另一個面向；不能把過期直接當未提交或把有評分當已提交。
- 所以目前是「核心真實 API 已打通」，不是 Phase 1 完整驗收完成；尚未建立 App 端 Moodle Service／同步資料模型，也沒有修改待辦 UI。

### 工具與安全檢查

- `scripts/academic_probe.py`：公開設定、登入、Keychain token、本人課程與有限作業探測、學期 metadata 調查。
- `scripts/AcademicProbeKeychain.swift`：不啟用雲端同步的本機 Keychain helper，敏感值僅經內部管線傳遞。
- `tests/test_academic_probe.py`／`tests/test_sis_probe.py`：新增動態選單與橋接目的地保護檢查；合成回應不是 live 串接證據。
- `.gitignore` 排除 Postman 原檔名稱、Python 快取與 `.academic-local/`；沒有複製原始 collection 或敏感 response。
- 操作與錯誤處理見 [ACADEMIC_API_TESTING.md](ACADEMIC_API_TESTING.md)。

## Phase 2：獨立校務登入與選課入口調查

- 舊版 `https://ohs01.ntpu.edu.tw/student_new.htm`：HTTP 200，公開頁面有指向歷史登入 handler 的導覽，另含查學號表單；頁面有動態 JavaScript，不能把靜態 form 當作全部登入流程。
- GET 舊版 `/pls/pm/stud_system.login`：HTTP 200，只有 32 bytes，沒有可驗證的個人資料；此結果不能視為登入成功。
- 新版 `https://my.ntpu.edu.tw/login`：HTTP 200，實際 POST form 指向同站 `/login`，欄位為當次 `_token`、`username`、`password`，另有舊版系統導覽。公開頁面與 JS 未觀測到明確 JSON 選課 API；不能因此推論登入後沒有 SSO 或沒有 API。
- 已建立 `scripts/sis_probe.py`：只使用新版當次表單與記憶體 Cookie jar；確認 session 後才存 Keychain。跨站導向、互動驗證、未知表單會停止；不讀 Postman、不查成績、不自動點選未知導覽。
- 開發者已完成本機當次登入，回報 `school_session_observation`（HTTP 200、`session_evidence=true`）及 `fresh_school_session_saved_to_keychain`；後續本機工具重新載入 session，確認非登入頁且有登出入口。這仍不是姓名／學號的本人身分核對。
- 登入頁面的 `var arr` JSON 與 `.service-menu` 使用 `data-url`／`data-index`；選課入口不是一般 `href`，先前 `redacted_academic_routes=[]` 不代表沒有選課功能。只解析 JSON，不執行頁面 JavaScript。
- 實際選單「選課清單」的 project 為 10，目的地 `/pls/univer/u0001.query_all_course.judge?func=3_m`；「選課系統」及其他 `func` 不執行。
- 校方 JS 先 GET 新版 `/get-projects/10?url=...`，取得 `{form_url,base_url,formData:{id,pw},...}`，再 POST 至校方 `/pls/pm/stud_system.signin`，最後 GET 選課清單。`formData` 含登入資料，不能輸出或寫檔；也不存入 Keychain、App 資料庫或 Firebase。
- 自動安全審查最初拒絕跨主機憑證轉送，原因為未有對該目的地的明確授權。開發者隨後明確授權 cof 的指定 signin 與唯讀清單；實際 bridge HTTP 200、6 個暫存 Cookie，清單 HTTP 200、12,744 bytes，表格 1 列標題加 6 列資料。正式學期、本人識別及公開課號的對應尚未完成。
- 後續校方描述先切換為 `ohs01.ntpu.edu.tw`（開發者另行明確授權），再切換為 `ohs02.ntpu.edu.tw`；工具因不符合當時的目的地白名單停止，沒有傳送登入資料至未授權主機。不能將這種格式變動當成空課表。
- `sis_probe.py navigation` 只驗證同站選單及橋接描述，輸出固定安全欄位；不會將登入資料轉送到 bridge。橋接原始回應、選課 HTML 與 Cookie 都未寫檔。

## 下一步與停止條件

Phase 1 補齊來源狀態與學期對應的可靠性驗收。不能把 60 門 Moodle timeline 課程直接匯入，也不能把限量 API 探測誤認為完整同步；在階段 gate 通過前不開始 Moodle 待辦整合。

Phase 2 繼續核對校方動態橋接目的地、本人選課清單的學期／課號，以及公開 CourseGet 的相容性。若目的地未授權、session 失效或 schema 改變即停止。在本人選課資料未確認前，不建立課表匯入按鈕、不改寫原課表。

Phase 3–8 未開始。原有 Course／Memo ID、資料模型、UI、通知、Widget 與 Live Activity 程式均未修改。
