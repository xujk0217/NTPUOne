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
```

Core Data 測試會刻意製造錯誤路徑與資料驗證失敗，因此會出現預期中的 Core Data error log；以程序 exit code 及最後的 `PASS` 判斷結果。這些檢查不代表真機 CloudKit 同步或 Widget 系統排程已驗收。

## 校務與 Moodle

```sh
python3 -m unittest discover -s tests -p 'test_*probe.py' -q
python3 scripts/run_academic_checks.py --swiftsoup-path /path/to/trusted/SwiftSoup
```

Swift 檢查直接編譯 App 的 API、政策與共用課程 parser，使用合成資料驗證本人／學期／核准狀態、報表清理、時段範圍與歧義拒絕、匯入保留原 UUID／手動修改、完成建議與快取時鐘等契約。SwiftSoup 請使用 Xcode 已解析的可信套件目錄。測試不寫正式資料庫，也不代表 iOS 端到端登入／CloudKit／通知已驗收。
