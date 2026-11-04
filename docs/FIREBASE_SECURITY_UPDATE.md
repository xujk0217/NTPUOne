# Firestore 憑證安全更新（2026-11-04）

## 原因與適用範圍

Firebase 官方公告指出，Apple 原生 App 使用 Cloud Firestore 時，內嵌的 TLS 信任憑證需要更新，以排除與受影響 eMudhra 中繼 CA 有關的根憑證。官方列出的修補版為 12.19.3 或 13.1.1 以上。原專案使用 10.28.1，屬於受影響範圍。這份公告本身不是本專案發生資料外洩的證據。

官方來源：
- https://firebase.google.com/support/guides/compromised-emudhra-intermediate-ca
- https://github.com/firebase/firebase-ios-sdk/releases/tag/12.19.3

## 本次處理

- 升級 Firebase 至 12.19.3；保留 iOS 16 部署下限。
- Firestore Swift API 已整合進 FirebaseFirestore，移除 FirebaseFirestoreSwift 匯入。
- 移除新版已不存在的舊 Swift 包裝產品，以及未使用的 Dynamic Links／Vertex AI 預覽產品參照。
- Google Sign-In 更新為相容版本；實際鎖定 9.2.0。
- 保存 SPM Package.resolved，以鎖定 Firebase 12.19.3 與傳遞相依版本。
- 未修改 Firestore 規則、資料、專案 ID 或帳戶金鑰。

## 驗證與發布界線

首次下載遇 Xcode 二進位壓縮檔錯誤，重試成功。從官方下載的 FirebaseFirestoreInternal.zip 通過解壓縮檢查，SHA-256 與官方 Package.swift 一致：
`dd147b4429719e7ddb04cbfa2f24b9f3eade0b03cc4ed294ffa409158ea6ee1d`。

完整 Release 簽章封存成功（1.4.0 build 36）。尚需手機驗收 Google 登入、Firestore 資料讀寫與通知。TestFlight 發布情況記於 TESTFLIGHT.md。

舊 App 內的信任憑證不會因伺服器或 OS 更新而自動被替換。正式 App Store 使用者需要取得包含此 SDK 的正式版本並更新；TestFlight 更新僅涵蓋安裝該測試版本的人，不能視為所有既有使用者已修補。
