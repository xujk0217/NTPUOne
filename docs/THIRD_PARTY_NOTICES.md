# 第三方套件、服務與資料來源

更新日期：2026-11-02。本表依 Xcode 專案、Firebase 套件設定與目前原始碼列出主要來源，不是完整的逐檔授權清冊；未出現在表中不代表沒有第三方權利。

## 套件與平台

| 項目 | 專案用途或狀態 | 權利及條款查核來源 |
| --- | --- | --- |
| Firebase Apple SDK | 身分驗證、Firestore、App Check、Remote Config、分析等 | [上游儲存庫](https://github.com/firebase/firebase-ios-sdk)及實際解析版本內的 LICENSE／NOTICE |
| Google Sign-In for iOS | Google 帳號登入 | [上游儲存庫](https://github.com/google/GoogleSignIn-iOS)及該版本條款 |
| Google Mobile Ads | 廣告顯示與獎勵廣告 | [套件入口](https://github.com/googleads/swift-package-manager-google-mobile-ads)及 SDK 隨附條款；套件包裝層授權不等同二進位 SDK 全部授權 |
| SwiftSoup | 校方 HTML 資料解析 | [上游儲存庫](https://github.com/scinfu/SwiftSoup)及實際解析版本的授權 |
| CalendarKit | Xcode 專案列有套件依賴 | [上游儲存庫](https://github.com/richardtop/CalendarKit)；列入依賴不代表每個功能均有使用 |
| Firebase Admin／Functions（Node.js） | `firebase/functions/package.json` 列有依賴；目前沒有部署用的業務函式匯出 | [Admin](https://github.com/firebase/firebase-admin-node)、[Functions](https://github.com/firebase/firebase-functions)及 lockfile 對應版本 |
| Apple frameworks／SF Symbols | 系統 UI、地圖、資料同步、Widget 等 | 適用的 Apple SDK、開發者及素材使用條款 |

發行前應以實際建置解析出的直接及間接依賴為準，保留必要的著作權、LICENSE／NOTICE 與隨附聲明。此表不替代應隨發布產物提供的法律文字，亦未宣稱已完成全部 SDK 的授權稽核。

## 外部內容與即時服務

| 來源 | 使用內容 | 說明 |
| --- | --- | --- |
| 國立臺北大學 | 校園公告、課程、行事曆及官方網站連結 | [學校首頁](https://new.ntpu.edu.tw/)；內容權利與連結有效性依原提供者規範 |
| 新北市政府資料開放平臺 | YouBike 站點與即時資訊 | [資料 API](https://data.ntpc.gov.tw/api/datasets/010E5B15-3823-4B20-B401-B1CF000550C5/json?page=0&size=500)；實際利用需另核對資料集的授權與標示要求 |
| 交通部中央氣象署 | 氣象觀測資料 | [開放資料平臺](https://opendata.cwa.gov.tw/)；依 API 授權、配額及資料利用條款 |
| 使用者、商家及其他提供者 | 發文、圖片、留言、餐廳資訊與網站內容 | 權利歸各提供者或實際權利人，不因由 App 顯示而納入本專案的原創權利聲明 |

資料可能延遲、改版或停止提供。App 的站點距離與資料顯示不代表來源提供者的背書，也不承諾即時正確。

如有來源、標示或授權問題，請聯絡 [kevin16021777@gmail.com](mailto:kevin16021777@gmail.com)，並提供具體檔案或內容位置。
