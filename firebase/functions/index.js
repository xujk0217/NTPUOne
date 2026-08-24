/**
 * NTPUOne Cloud Functions
 *
 * 2026-08 安全整併：
 * - 移除交流區推播函式（notifyCommunityCategorySubscribers / notifyCommunityTopicSubscribers）：
 *   社群通知功能暫停，App 端僅保留課表、備忘錄等本地通知。
 * - 移除 communityContent.js 的 callable 匯出：該組 API 未驗證 request.auth，
 *   且以呼叫者可任意指定的 deviceSecret 作為 ownership root，存在被冒用刪改他人內容的風險。
 *   App 一律透過 Firestore 安全規則直接批次寫入（公開文件 + 私有 owner 文件同批原子建立）。
 *
 * 若未來要重啟推播或提供伺服器端 API，必須：
 * 1. onCall({ enforceAppCheck: true }) 並驗證 request.auth；
 * 2. ownership 一律由 request.auth.uid 推導，絕不接受請求資料中的識別字串；
 * 3. 對寫入與推播 fan-out 加入配額限制。
 */

const admin = require("firebase-admin");

admin.initializeApp();
