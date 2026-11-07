# 本次回歸檢查

在 macOS 與 Xcode Command Line Tools 環境，從專案根目錄執行。測試僅使用暫存資料庫及模擬網路回應，不修改正式資料或登入狀態。

```sh
swiftc -swift-version 5 -module-cache-path /private/tmp/ntpuone-test-module-cache \
  NTPUOne/CourseList/CoreDataManager.swift tests/CoreDataRecoveryChecks.swift \
  -o /private/tmp/ntpuone-coredata-checks
/private/tmp/ntpuone-coredata-checks

swiftc -swift-version 5 -module-cache-path /private/tmp/ntpuone-bike-test-module-cache \
  NTPUOne/TrafficView/UbikeData.swift NTPUOne/TrafficView/UbikeManager.swift \
  tests/YouBikeRegressionChecks.swift -o /private/tmp/ntpuone-bike-checks
/private/tmp/ntpuone-bike-checks

swiftc -swift-version 5 -module-cache-path /private/tmp/ntpuone-test-module-cache \
  CourseEntity+CoreDataClass.swift CourseEntity+CoreDataProperties.swift \
  tests/CourseScheduleStorageChecks.swift -o /private/tmp/ntpuone-schedule-checks
/private/tmp/ntpuone-schedule-checks
```

課表檢查包含同步衝突、同名同時段分組與刪除後重新計算；YouBike 檢查包含跨午夜時段、規則優先順序及偏好設定讀取失敗的回復。

Core Data 測試會刻意製造錯誤路徑與資料驗證失敗，因此會出現預期中的 Core Data error log；以程序 exit code 及最後的 `PASS` 判斷結果。這些檢查不代表真機 CloudKit 同步或 Widget 系統排程已驗收。

## 校務與 Moodle

```sh
python3 -m unittest discover -s tests -p 'test_*probe.py' -q
python3 scripts/run_academic_checks.py --swiftsoup-path /path/to/trusted/SwiftSoup
```

Swift 檢查直接編譯 App 的 API、政策與共用課程 parser，使用合成資料驗證本人／學期／核准狀態、原生報表 selector／雙語／學期隔離／累計排名、舊快取遷移、私人備註保留、時段範圍與歧義拒絕、匯入保留原 UUID／手動修改、完成建議與快取時鐘等契約。SwiftSoup 請使用 Xcode 已解析的可信套件目錄。測試不寫正式資料庫，也不代表 iOS 端到端登入／CloudKit／通知已驗收。

## AI 與登入表單

```sh
node tests/test_ai_bridge.cjs
node tests/test_ai_login_diagnostic.cjs
node tests/test_ai_stored_login.cjs
node tests/test_ai_markdown.cjs
```

已儲存帳號登入測試使用合成表單與假帳密，驗證唯一官方 POST 表單、禁止讀取隱藏值、驗證碼／OTP 拒絕代填，以及欄位事件變更目的地時清除填入值並停止提交。並非真實校方 SSO 驗收。

## AI 資料權限與 Duo 幾何

```sh
swiftc -module-cache-path /private/tmp/ntpuone-test-module-cache \
  NTPUOne/AIAssistant/AIDataPolicy.swift NTPUOne/AIAssistant/AILoginDiagnostics.swift \
  tests/AIDataPolicyChecks.swift -o /private/tmp/ntpuone-ai-policy-checks
/private/tmp/ntpuone-ai-policy-checks

swiftc -module-cache-path /private/tmp/ntpuone-test-module-cache \
  NTPUOne/AdaptiveLayout/DuoWorkspacePolicy.swift tests/DuoWorkspaceChecks.swift \
  -o /private/tmp/ntpuone-duo-checks
/private/tmp/ntpuone-duo-checks
```

以上為合成資料與幾何測試，不代表實際模型產生變更建議、寫入流程或每個裝置姿態都已驗收。

## UI/UX 提案執行狀態

```sh
swiftc -module-cache-path /private/tmp/ntpuone-test-module-cache \
  NTPUOne/AIAssistant/AIDataPolicy.swift tests/AIChangeExecutionChecks.swift \
  -o /private/tmp/ntpuone-ai-execution-checks
/private/tmp/ntpuone-ai-execution-checks
```

檢查同一則訊息中單筆與整批的待確認篩選、帳號隔離、不同訊息同名提案，以及拒絕採用模型傳來的執行 ID。執行狀態與目前聊天同為 App session 生命週期，不是跨裝置的操作紀錄。
