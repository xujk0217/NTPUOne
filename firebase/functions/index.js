const admin = require("firebase-admin");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { FieldValue } = require("firebase-admin/firestore");

admin.initializeApp();

const db = admin.firestore();
Object.assign(exports, require("./communityContent"));

exports.notifyCommunityCategorySubscribers = onDocumentCreated(
  "communityTopics/{topicId}",
  async (event) => {
    const topic = event.data && event.data.data();
    if (!topic || !topic.category) return;

    const subscriptions = await db
      .collection("communityCategorySubscriptions")
      .doc(topic.category)
      .collection("devices")
      .get();

    const tokenRecords = await tokenRecordsForSubscriptions(subscriptions, topic.authorDeviceId, {
      category: topic.category,
    });
    if (tokenRecords.length === 0) return;

    await sendMulticastInBatches(tokenRecords, {
      notification: {
        title: `交流區有新主題：${topic.title || "新主題"}`,
        body: topic.body || "有人開了一個新話題。",
      },
      data: {
        type: "communityTopic",
        topicId: event.params.topicId,
        category: topic.category,
      },
      apns: {
        payload: { aps: { sound: "default" } },
      },
    });
  }
);

exports.notifyCommunityTopicSubscribers = onDocumentCreated(
  "communityTopics/{topicId}/replies/{replyId}",
  async (event) => {
    const reply = event.data && event.data.data();
    if (!reply) return;

    const topicSnap = await db.collection("communityTopics").doc(event.params.topicId).get();
    const topic = topicSnap.exists ? topicSnap.data() : {};

    const subscriptions = await db
      .collection("communityTopicSubscriptions")
      .doc(event.params.topicId)
      .collection("devices")
      .get();

    const tokenRecords = await tokenRecordsForSubscriptions(subscriptions, reply.authorDeviceId, {
      topicId: event.params.topicId,
    });
    if (tokenRecords.length === 0) return;

    await sendMulticastInBatches(tokenRecords, {
      notification: {
        title: `「${topic.title || "主題"}」有新回覆`,
        body: reply.body || "有人回覆了你訂閱的主題。",
      },
      data: {
        type: "communityReply",
        topicId: event.params.topicId,
        replyId: event.params.replyId,
      },
      apns: {
        payload: { aps: { sound: "default" } },
      },
    });
  }
);

async function tokenRecordsForSubscriptions(snapshot, authorDeviceId, sourceSubscription) {
  const subscribers = snapshot.docs
    .filter((doc) => doc.data().active !== false)
    .map((doc) => ({ deviceSecret: doc.id, deviceId: doc.data().deviceId }))
    .filter((subscriber) => subscriber.deviceSecret && subscriber.deviceId !== authorDeviceId);

  if (subscribers.length === 0) return [];

  const tokenDocs = await Promise.all(
    subscribers.map((subscriber) => db.collection("communityDeviceTokens").doc(subscriber.deviceSecret).get())
  );

  await cleanupMissingTokenRecords(tokenDocs
    .map((doc, index) => missingTokenRecordFromDoc(doc, subscribers[index], sourceSubscription))
    .filter(Boolean));

  return tokenDocs
    .map((doc) => tokenRecordFromDoc(doc, sourceSubscription))
    .filter(Boolean);
}

async function sendMulticastInBatches(tokenRecords, message) {
  const batchSize = 500;
  for (let index = 0; index < tokenRecords.length; index += batchSize) {
    const batchRecords = tokenRecords.slice(index, index + batchSize);
    const response = await admin.messaging().sendEachForMulticast({
      ...message,
      tokens: batchRecords.map((record) => record.fcmToken),
    });
    await cleanupInvalidTokenRecords(batchRecords, response.responses);
  }
}

function tokenRecordFromDoc(doc, sourceSubscription) {
  if (!doc.exists) return null;
  const data = doc.data() || {};
  if (typeof data.fcmToken !== "string" || data.fcmToken.trim().length === 0) return null;

  return {
    deviceSecret: doc.id,
    fcmToken: data.fcmToken.trim(),
    categorySubscriptions: withSourceSubscription(stringArray(data.categorySubscriptions), sourceSubscription.category),
    topicSubscriptions: withSourceSubscription(stringArray(data.topicSubscriptions), sourceSubscription.topicId),
  };
}

function missingTokenRecordFromDoc(doc, subscriber, sourceSubscription) {
  if (doc.exists && typeof (doc.data() || {}).fcmToken === "string" && doc.data().fcmToken.trim().length > 0) {
    return null;
  }

  return {
    deviceSecret: subscriber.deviceSecret,
    categorySubscriptions: withSourceSubscription([], sourceSubscription.category),
    topicSubscriptions: withSourceSubscription([], sourceSubscription.topicId),
  };
}

function withSourceSubscription(subscriptions, sourceId) {
  if (typeof sourceId !== "string" || sourceId.trim().length === 0) return subscriptions;
  return [...new Set([...subscriptions, sourceId.trim()])];
}

function stringArray(value) {
  if (!Array.isArray(value)) return [];
  return [...new Set(value.filter((entry) => typeof entry === "string" && entry.trim().length > 0).map((entry) => entry.trim()))];
}

async function cleanupInvalidTokenRecords(tokenRecords, responses) {
  const invalidRecords = tokenRecords.filter((record, index) => isInvalidFcmTokenError(responses[index] && responses[index].error));
  if (invalidRecords.length === 0) return;

  await commitBatchedOperations(invalidRecords.flatMap((record) => cleanupOperationsForTokenRecord(record, "invalid-fcm-token")));
}

async function cleanupMissingTokenRecords(records) {
  if (records.length === 0) return;

  await commitBatchedOperations(records.flatMap((record) => cleanupOperationsForTokenRecord(record, "missing-device-token")));
}

function isInvalidFcmTokenError(error) {
  if (!error) return false;
  if (["messaging/invalid-registration-token", "messaging/registration-token-not-registered"].includes(error.code)) {
    return true;
  }
  return error.code === "messaging/invalid-argument" && /token/i.test(error.message || "");
}

function cleanupOperationsForTokenRecord(record, reason) {
  const now = FieldValue.serverTimestamp();
  const subscriptionUpdate = {
    active: false,
    deactivatedAt: now,
    deactivationReason: reason,
    deviceSecret: record.deviceSecret,
  };

  return [
    (batch) => batch.delete(db.collection("communityDeviceTokens").doc(record.deviceSecret)),
    ...record.categorySubscriptions.map((category) => (batch) => batch.set(
      db.collection("communityCategorySubscriptions").doc(category).collection("devices").doc(record.deviceSecret),
      subscriptionUpdate,
      { merge: true }
    )),
    ...record.topicSubscriptions.map((topicId) => (batch) => batch.set(
      db.collection("communityTopicSubscriptions").doc(topicId).collection("devices").doc(record.deviceSecret),
      subscriptionUpdate,
      { merge: true }
    )),
  ];
}

async function commitBatchedOperations(operations) {
  const maxOperationsPerBatch = 450;
  for (let index = 0; index < operations.length; index += maxOperationsPerBatch) {
    const batch = db.batch();
    operations.slice(index, index + maxOperationsPerBatch).forEach((applyOperation) => applyOperation(batch));
    await batch.commit();
  }
}
