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
