# 本機校務／Moodle API 驗證操作

目前為獨立驗證工具，沒有整合到 App，也不會讀寫 App 的 SQLite、Firebase、CloudKit 或課表。階段成果見 [ACADEMIC_INTEGRATION_PROGRESS.md](ACADEMIC_INTEGRATION_PROGRESS.md)。

## 安全界線

- 不要將學校帳密、Cookie 或 token 貼到聊天、Issue、PR 或終端命令參數。
- 只使用自己的帳號；不能使用歷史 Postman 中的 Cookie、Session 或他人的憑證。
- 工具在本機終端隱藏輸入帳號／密碼，不寫入密碼檔；Python 的記憶體清理不等於可保證的密碼記憶體覆寫。
- Moodle token 與經確認的新版校務 session 分開存入 macOS Keychain，關閉跨裝置同步。Keychain helper 使用內部管線傳遞敏感值，不把值放在命令參數或直接輸出到互動終端。
- helper 在權限受限的臨時目錄編譯，結束後刪除暫存 binary。macOS 若詢問 Keychain 存取，請確認是自己啟動的 `AcademicProbeKeychain`；不確定時先取消。
- 只輸出欄位型別、數量、受限的錯誤／狀態列舉與去識別化的導覽線索；完整回應只在程序記憶體中，不寫到 Git。
- 無背景重試、不繞過 CAPTCHA／SSO／權限。遇到跨站跳轉、未知驗證方式或未知結構就停止，不把 HTTP 200 當作登入成功。

## Moodle

從專案根目錄執行，需要 macOS、Python 3 與 Xcode Command Line Tools。

```sh
# 無憑證檢查公開 Mobile 設定與標準入口
python3 scripts/academic_probe.py public

# 本機 Keychain 測試，使用臨時隨機值，測完即刪；不是學校登入測試
python3 scripts/academic_probe.py keychain-self-test

# 只在自己的互動 Terminal 執行；依序隱藏輸入帳號、密碼
python3 scripts/academic_probe.py login

# 以 Keychain token 驗證本人資料，預設最多檢查 3 門候選課／5 份提交狀態
python3 scripts/academic_probe.py verify

# 檢查學期線索及欄位完整率，輸出只有總數
python3 scripts/academic_probe.py inventory

# 明確擴大少量驗證的範圍（各上限 20）
python3 scripts/academic_probe.py verify --max-courses 6 --max-submissions 10

# 移除本機 token，不代表已撤銷伺服器上的 token
python3 scripts/academic_probe.py logout
```

`--profile` 可使用自己選擇的本機別名區分帳號，不建議用學號。每次驗證都會重新呼叫 site info，核對 userid 與當初登入保存的身分一致；不同 profile 不共用來源映射。

若站台改成瀏覽器登入模式，工具不提交密碼。只有在校方提供合法、可使用的 token 取得流程時，才可用 `import-token` 於本機隱藏輸入；不要擷取他人的 token，也不要繞過 SSO 取得。

### 如何看結果

- `identity_verified_token_saved_to_keychain`：本人身分已由 API 驗證，token 已存 Keychain；不是整個 Phase 1 完成。
- `own_courses_received`：回傳總數及本學期候選數。候選由目前臺灣時區日期與至少兩個課程 metadata 欄位的學期線索判定，**不是校務正式選課證明**。
- `submission_schema`：只顯示結構和個人／團體提交狀態、是否評分。`submitted`、`draft`、評分及逾期是不同面向；此工具不把結果寫入 Memo，也不直接推論團體作業已完成。
- `readonly_probe_finished`：有限範圍的 API 調查結束，輸出仍保留 `phase_1_complete=false`，避免將探測成功誤認為 UI／全情境已驗收。
- `probe_stopped`：檢查 `diagnostic`；只提供此代碼即可，勿提供原始回應或憑證。`invalidlogin` 時先確認官方網頁可登入，不反覆嘗試密碼。

工具以白名單限制 Web Service 函式，沒有作業提交、評分、選退課或寫入 API。欄位契約參考 Moodle 官方實作，再逐步以北大實際回應驗證；尚未實際觀測的狀態會保留限制。

## 新版學生資訊系統：獨立的當次登入驗證

```sh
# 在自己的 Terminal 隱藏輸入新版校務帳密
python3 scripts/sis_probe.py login

# 僅重新查看同一個 Keychain session 是否仍有登入後頁面證據
python3 scripts/sis_probe.py inspect

# 辨識官方動態選課選單與橋接描述，不執行跨主機登入
python3 scripts/sis_probe.py navigation

# 僅限已明確授權的 cof／ohs01 signin 與同主機選課清單；不寫入 App
python3 scripts/sis_probe.py catalog-verify

# 僅刪除本機保存的 session
python3 scripts/sis_probe.py logout-local
```

CLI 的 `login`、`inspect`、`navigation` 只請求 `https://my.ntpu.edu.tw`。先 GET 當次 `/login`，從目前的 POST form 取得 `_token`，以當次記憶體 Cookie jar 提交 `_token`、`username`、`password`。它不重放 Postman，也不呼叫舊系統的成績網址。

只接受 HTTPS 同站且符合限制的登入導向；跨站 SSO、307／308、互動驗證或未知登入頁面會停止，需要開發者／校方確認正式流程。登入後以「非登入頁、沒有帳密表單、存在登出入口」作為 session 證據，不能單憑此宣稱本人身分或正式選課清單已驗證。

保存的 Cookie 限定新版站台、位於 Keychain；不將 session 上傳至 Firebase。`inspect` 沒有自動點擊導覽連結，也不查成績、課表或畢業規則。未知的個人 API 需在取得正式文件或可靠的授權觀察後，才能逐步加入。

`navigation` 只接受官方 JSON 中名稱為「選課清單」、project 10 且為固定唯讀 URL 的項目，再以官方頁面既有方式讀取 `/get-projects/10` 描述。`formData` 是敏感登入資料，不能貼出原始 JSON。診斷只輸出已通過白名單的橋接路徑及 `bridge_credentials_forwarded=false`；未知主機、登入／清單主機不一致、額外欄位或非預期功能都停止。

內部 `read_course_list` 僅供已明確授權的本機調查呼叫，使用獨立、暫存 Cookie jar；只 POST 驗證過的 signin，接著 GET 對應同主機 `func=3_m`。不跟隨任何 redirect，不將舊校務 Cookie 保存至 Keychain。它不是 App 登入或正式課表匯入功能。

`catalog-verify` 先確認新版 session 與官方選單，再依同一流程讀取個人選課清單。它要求頁面中確認單連結的本人識別與登入橋接一致、只有單一學年學期、代碼唯一且每列都為已實測的「已核准」；不自動追蹤確認單連結。接著以學年／學期／代碼查公開 CourseGet 目錄，只比較現有欄位契約。公開站使用全新的無 Cookie opener，不接收校務登入資料。回報 `school_enrolment_catalog_verified` 表示這份學期清單與欄位檢查成功，**不表示 App 匯入、歷史學期、多時段解析或其他功能已完成**。

目前主機白名單僅有 `cof.ntpu.edu.tw`、`ohs01.ntpu.edu.tw` 的指定路徑及 `func=3_m`。校方可能回傳其他 ohs 主機；此時停止是預期行為，需要該目的地的明確授權及程式白名單更新。不得將描述中的任意 URL 或使用者提供的歷史 `date1` 直接帶入執行。

## 離線工具測試

```sh
python3 -m unittest discover -s tests -p 'test_*probe.py' -v
```

其中的合成回應只用於驗證遮蔽、參數限制、身分切換與失敗處理，**不能作為真實串接成功證據**。App 原有測試另見 [tests/README.md](../tests/README.md)。

## 官方參考

- [Moodle Web Service 函式清單](https://docs.moodle.org/dev/Web_service_API_functions)
- [Mobile 登入模式常數](https://github.com/moodle/moodle/blob/MOODLE_39_STABLE/admin/tool/mobile/classes/api.php)
- [課程 timeline 分頁契約](https://github.com/moodle/moodle/blob/MOODLE_39_STABLE/course/externallib.php)
- [Assignment／submission status 契約](https://github.com/moodle/moodle/blob/MOODLE_39_STABLE/mod/assign/externallib.php)

參考來源用來理解 API 語義，不代表已確認北大站台的精確 Moodle 版本，也不代表校方提供額外的服務或批次存取授權。

## App 同份 Swift 服務驗證（2026-11-02）

新增檢查入口見 [tests/README.md](../tests/README.md)。離線測試與真實查證分開。真實測試模式只接受管線 stdin，禁止 Terminal 手動貼憑證，且只回報數量／階段代碼。不要把 token 放進 argv、檔案、URL 或 Git。

同份 Swift 選課 parser 與公開目錄已驗證 6 門課／14 節；成績、排名、畢業進度三份真實頁通過身分及內容契約。Moodle 公告、教材與成績使用 core_course_get_contents、mod_forum_get_forum_discussions、gradereport_user_get_grade_items；成績必須明確傳入已由 site info 驗證的本人 userid。課程總計 itemname 可以為 null。

App 支援已核對的唯讀 func=3_m／5_m／8_m／9_m，各自使用固定官方路徑，主機仍只有 cof／ohs01。CLI 早期的 inspect／navigation 指令維持較小範圍。CLI 與 App Keychain service 不共用，App 仍需由本人連結一次。
