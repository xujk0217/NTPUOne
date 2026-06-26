const { FieldValue, Timestamp, getFirestore } = require("firebase-admin/firestore");
const { onCall, HttpsError } = require("firebase-functions/v2/https");

const db = getFirestore();

const COMMUNITY_CATEGORIES = new Set(["food", "course", "campus", "question", "trade", "meetup"]);

const PUBLIC_TOPIC_FIELDS = [
  "title",
  "body",
  "category",
  "authorName",
  "authorDeviceId",
  "authorDepartment",
  "authorEntryYear",
  "authorShowsYear",
  "authorShowsBadge",
  "authorBadgeLevel",
  "createdAt",
  "replyCount",
];

const PUBLIC_REPLY_FIELDS = [
  "body",
  "authorName",
  "authorDeviceId",
  "authorDepartment",
  "authorEntryYear",
  "authorShowsYear",
  "authorShowsBadge",
  "authorBadgeLevel",
  "createdAt",
];

const TOPIC_DELETED_TITLE = "[已刪除]";
const TOPIC_DELETED_BODY = "此主題已由作者刪除。";

exports.createCommunityTopic = onCall(async (request) => {
  const data = requireObject(request.data);
  const deviceSecret = requireString(data.deviceSecret, "deviceSecret");
  const topicRef = data.topicId
    ? db.collection("communityTopics").doc(requireString(data.topicId, "topicId"))
    : db.collection("communityTopics").doc();

  const topic = buildTopicPayload(data);
  const ownerRef = topicOwnerRef(deviceSecret, topicRef.id);
  const now = FieldValue.serverTimestamp();

  const batch = db.batch();
  batch.create(topicRef, topic);
  batch.create(ownerRef, {
    topicId: topicRef.id,
    category: topic.category,
    title: topic.title,
    body: topic.body,
    bodyPreview: preview(topic.body),
    authorDeviceId: topic.authorDeviceId,
    createdAt: now,
    updatedAt: now,
    isDeleted: false,
  });
  await commitCreateOnly(batch.commit(), "Community topic already exists.");

  return { topicId: topicRef.id };
});

exports.createCommunityReply = onCall(async (request) => {
  const data = requireObject(request.data);
  const deviceSecret = requireString(data.deviceSecret, "deviceSecret");
  const topicId = requireString(data.topicId, "topicId");
  const topicRef = db.collection("communityTopics").doc(topicId);
  const replyRef = data.replyId
    ? topicRef.collection("replies").doc(requireString(data.replyId, "replyId"))
    : topicRef.collection("replies").doc();
  const reply = buildReplyPayload(data);
  const ownerRef = replyOwnerRef(deviceSecret, topicId, replyRef.id);
  const now = FieldValue.serverTimestamp();

  await commitCreateOnly(db.runTransaction(async (transaction) => {
    const topicSnap = await transaction.get(topicRef);
    if (!topicSnap.exists) {
      throw new HttpsError("not-found", "Community topic not found.");
    }
    if (topicSnap.get("isDeleted") === true) {
      throw new HttpsError("failed-precondition", "Cannot reply to a deleted topic.");
    }
    const topicData = topicSnap.data() || {};

    transaction.create(replyRef, reply);
    transaction.update(topicRef, { replyCount: FieldValue.increment(1) });
    transaction.create(ownerRef, {
      topicId,
      replyId: replyRef.id,
      category: typeof topicData.category === "string" ? topicData.category : "",
      title: typeof topicData.title === "string" ? topicData.title : "",
      body: reply.body,
      bodyPreview: preview(reply.body),
      authorDeviceId: reply.authorDeviceId,
      createdAt: now,
      updatedAt: now,
      isDeleted: false,
    });
  }), "Community reply already exists.");

  return { topicId, replyId: replyRef.id };
});

exports.listMyCommunityContent = onCall(async (request) => {
  const data = requireObject(request.data);
  const deviceSecret = requireString(data.deviceSecret, "deviceSecret");
  const ownerRef = ownerRootRef(deviceSecret);
  const [topicsSnap, repliesSnap] = await Promise.all([
    ownerRef.collection("topics").orderBy("createdAt", "desc").get(),
    ownerRef.collection("replies").orderBy("createdAt", "desc").get(),
  ]);

  return {
    topics: topicsSnap.docs.map((doc) => serializeOwnerDoc(doc)),
    replies: repliesSnap.docs.map((doc) => serializeOwnerDoc(doc)),
  };
});

exports.deleteCommunityDeviceData = onCall(async (request) => {
  const data = requireObject(request.data);
  const deviceSecret = requireString(data.deviceSecret, "deviceSecret");
  const tokenRef = db.collection("communityDeviceTokens").doc(deviceSecret);
  const profileRef = db.collection("communityProfiles").doc(deviceSecret);
  const tokenSnap = await tokenRef.get();
  const tokenData = tokenSnap.exists ? tokenSnap.data() || {} : {};
  const categorySubscriptions = stringArray(tokenData.categorySubscriptions);
  const topicSubscriptions = stringArray(tokenData.topicSubscriptions);
  const ownerCleanup = await ownerCleanupOperations(deviceSecret);
  const operations = [
    (batch) => batch.delete(tokenRef),
    (batch) => batch.delete(profileRef),
    ...categorySubscriptions.map((category) => (batch) => batch.delete(categorySubscriptionRef(category, deviceSecret))),
    ...topicSubscriptions.map((topicId) => (batch) => batch.delete(topicSubscriptionRef(topicId, deviceSecret))),
    ...ownerCleanup.operations,
  ];

  await commitBatchedOperations(operations);

  return {
    deletedDeviceToken: true,
    deletedProfile: true,
    deletedCategorySubscriptions: categorySubscriptions.length,
    deletedTopicSubscriptions: topicSubscriptions.length,
    deletedOwnerTopics: ownerCleanup.topicCount,
    deletedOwnerReplies: ownerCleanup.replyCount,
  };
});

exports.updateCommunityTopic = onCall(async (request) => {
  const data = requireObject(request.data);
  const deviceSecret = requireString(data.deviceSecret, "deviceSecret");
  const topicId = requireString(data.topicId, "topicId");
  const title = requireString(data.title, "title").trim();
  const body = requireString(data.body, "body").trim();
  requireNonEmpty(title, "title");
  requireNonEmpty(body, "body");

  const topicRef = db.collection("communityTopics").doc(topicId);
  const ownerRef = topicOwnerRef(deviceSecret, topicId);
  const now = FieldValue.serverTimestamp();

  await db.runTransaction(async (transaction) => {
    const ownerSnap = await transaction.get(ownerRef);
    requireActiveOwner(ownerSnap, "topic");
    requireOwnerTopic(ownerSnap, topicId);
    const topicSnap = await transaction.get(topicRef);
    requireExistingPublicDoc(topicSnap, "topic");

    transaction.update(topicRef, { title, body });
    transaction.update(ownerRef, {
      title,
      body,
      bodyPreview: preview(body),
      updatedAt: now,
    });
  });

  return { topicId };
});

exports.deleteCommunityTopic = onCall(async (request) => {
  const data = requireObject(request.data);
  const deviceSecret = requireString(data.deviceSecret, "deviceSecret");
  const topicId = requireString(data.topicId, "topicId");
  const topicRef = db.collection("communityTopics").doc(topicId);
  const ownerRef = topicOwnerRef(deviceSecret, topicId);
  const now = FieldValue.serverTimestamp();

  await db.runTransaction(async (transaction) => {
    const ownerSnap = await transaction.get(ownerRef);
    requireActiveOwner(ownerSnap, "topic");
    requireOwnerTopic(ownerSnap, topicId);
    const topicSnap = await transaction.get(topicRef);
    requireExistingPublicDoc(topicSnap, "topic");

    transaction.update(topicRef, {
      title: TOPIC_DELETED_TITLE,
      body: TOPIC_DELETED_BODY,
      authorName: "",
      authorDeviceId: "",
      authorDepartment: "",
      authorEntryYear: "",
      authorShowsYear: false,
      authorShowsBadge: false,
      authorBadgeLevel: 0,
      isDeleted: true,
      deletedAt: now,
      updatedAt: now,
    });
    transaction.update(ownerRef, {
      title: TOPIC_DELETED_TITLE,
      body: "",
      bodyPreview: "",
      isDeleted: true,
      deletedAt: now,
      updatedAt: now,
    });
  });

  return { topicId };
});

exports.updateCommunityReply = onCall(async (request) => {
  const data = requireObject(request.data);
  const deviceSecret = requireString(data.deviceSecret, "deviceSecret");
  const topicId = requireString(data.topicId, "topicId");
  const replyId = requireString(data.replyId, "replyId");
  const body = requireString(data.body, "body").trim();
  requireNonEmpty(body, "body");

  const replyRef = db.collection("communityTopics").doc(topicId).collection("replies").doc(replyId);
  const ownerRef = replyOwnerRef(deviceSecret, topicId, replyId);
  const now = FieldValue.serverTimestamp();

  await db.runTransaction(async (transaction) => {
    const ownerSnap = await transaction.get(ownerRef);
    requireActiveOwner(ownerSnap, "reply");
    requireOwnerReply(ownerSnap, topicId, replyId);
    const replySnap = await transaction.get(replyRef);
    requireExistingPublicDoc(replySnap, "reply");

    transaction.update(replyRef, { body });
    transaction.update(ownerRef, {
      body,
      bodyPreview: preview(body),
      updatedAt: now,
    });
  });

  return { topicId, replyId };
});

exports.deleteCommunityReply = onCall(async (request) => {
  const data = requireObject(request.data);
  const deviceSecret = requireString(data.deviceSecret, "deviceSecret");
  const topicId = requireString(data.topicId, "topicId");
  const replyId = requireString(data.replyId, "replyId");
  const topicRef = db.collection("communityTopics").doc(topicId);
  const replyRef = topicRef.collection("replies").doc(replyId);
  const ownerRef = replyOwnerRef(deviceSecret, topicId, replyId);
  const now = FieldValue.serverTimestamp();

  await db.runTransaction(async (transaction) => {
    const ownerSnap = await transaction.get(ownerRef);
    requireActiveOwner(ownerSnap, "reply");
    requireOwnerReply(ownerSnap, topicId, replyId);
    const [topicSnap, replySnap] = await Promise.all([
      transaction.get(topicRef),
      transaction.get(replyRef),
    ]);
    requireExistingPublicDoc(replySnap, "reply");

    transaction.delete(replyRef);
    if (topicSnap.exists) {
      const currentReplyCount = Number.isInteger(topicSnap.get("replyCount")) ? topicSnap.get("replyCount") : 0;
      transaction.update(topicRef, {
        replyCount: Math.max(0, currentReplyCount - 1),
      });
    }
    transaction.update(ownerRef, {
      body: "",
      bodyPreview: "",
      isDeleted: true,
      deletedAt: now,
      updatedAt: now,
    });
  });

  return { topicId, replyId };
});

function buildTopicPayload(data) {
  const title = requireString(data.title, "title").trim();
  const body = requireString(data.body, "body").trim();
  const category = requireString(data.category, "category").trim();
  requireNonEmpty(title, "title");
  requireNonEmpty(body, "body");
  requireCategory(category);

  return pickDefined({
    title,
    body,
    category,
    authorName: requireString(data.authorName, "authorName").trim(),
    authorDeviceId: requireString(data.authorDeviceId, "authorDeviceId").trim(),
    authorDepartment: optionalString(data.authorDepartment),
    authorEntryYear: optionalString(data.authorEntryYear),
    authorShowsYear: requireBoolean(data.authorShowsYear, "authorShowsYear"),
    authorShowsBadge: requireBoolean(data.authorShowsBadge, "authorShowsBadge"),
    authorBadgeLevel: requireBadgeLevel(data.authorBadgeLevel),
    createdAt: FieldValue.serverTimestamp(),
    replyCount: 0,
  }, PUBLIC_TOPIC_FIELDS);
}

function buildReplyPayload(data) {
  const body = requireString(data.body, "body").trim();
  requireNonEmpty(body, "body");

  return pickDefined({
    body,
    authorName: requireString(data.authorName, "authorName").trim(),
    authorDeviceId: requireString(data.authorDeviceId, "authorDeviceId").trim(),
    authorDepartment: optionalString(data.authorDepartment),
    authorEntryYear: optionalString(data.authorEntryYear),
    authorShowsYear: requireBoolean(data.authorShowsYear, "authorShowsYear"),
    authorShowsBadge: requireBoolean(data.authorShowsBadge, "authorShowsBadge"),
    authorBadgeLevel: requireBadgeLevel(data.authorBadgeLevel),
    createdAt: FieldValue.serverTimestamp(),
  }, PUBLIC_REPLY_FIELDS);
}

function ownerRootRef(deviceSecret) {
  return db.collection("communityContentOwners").doc(deviceSecret);
}

function topicOwnerRef(deviceSecret, topicId) {
  return ownerRootRef(deviceSecret).collection("topics").doc(topicId);
}

function replyOwnerRef(deviceSecret, topicId, replyId) {
  return ownerRootRef(deviceSecret).collection("replies").doc(`${topicId}_${replyId}`);
}

function categorySubscriptionRef(category, deviceSecret) {
  return db.collection("communityCategorySubscriptions").doc(category).collection("devices").doc(deviceSecret);
}

function topicSubscriptionRef(topicId, deviceSecret) {
  return db.collection("communityTopicSubscriptions").doc(topicId).collection("devices").doc(deviceSecret);
}

async function ownerCleanupOperations(deviceSecret) {
  const ownerRef = ownerRootRef(deviceSecret);
  const [topicsSnap, repliesSnap] = await Promise.all([
    ownerRef.collection("topics").get(),
    ownerRef.collection("replies").get(),
  ]);

  return {
    topicCount: topicsSnap.size,
    replyCount: repliesSnap.size,
    operations: [
      ...topicsSnap.docs.map((doc) => (batch) => batch.delete(doc.ref)),
      ...repliesSnap.docs.map((doc) => (batch) => batch.delete(doc.ref)),
      (batch) => batch.delete(ownerRef),
    ],
  };
}

async function commitBatchedOperations(operations) {
  const maxOperationsPerBatch = 450;
  for (let index = 0; index < operations.length; index += maxOperationsPerBatch) {
    const batch = db.batch();
    operations.slice(index, index + maxOperationsPerBatch).forEach((applyOperation) => applyOperation(batch));
    await batch.commit();
  }
}

function stringArray(value) {
  if (!Array.isArray(value)) return [];
  return [...new Set(value.filter((entry) => typeof entry === "string" && entry.trim().length > 0).map((entry) => entry.trim()))];
}

function requireObject(value) {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new HttpsError("invalid-argument", "Request data must be an object.");
  }
  return value;
}

function requireString(value, field) {
  if (typeof value !== "string") {
    throw new HttpsError("invalid-argument", `${field} must be a string.`);
  }
  requireNonEmpty(value.trim(), field);
  return value;
}

function requireNonEmpty(value, field) {
  if (value.length === 0) {
    throw new HttpsError("invalid-argument", `${field} must not be empty.`);
  }
}

function optionalString(value) {
  if (value === undefined || value === null) return "";
  if (typeof value !== "string") {
    throw new HttpsError("invalid-argument", "Optional profile fields must be strings.");
  }
  return value.trim();
}

function requireBoolean(value, field) {
  if (typeof value !== "boolean") {
    throw new HttpsError("invalid-argument", `${field} must be a boolean.`);
  }
  return value;
}

function requireBadgeLevel(value) {
  const allowed = [0, 1, 2, 3, 4, 99];
  if (!Number.isInteger(value) || !allowed.includes(value)) {
    throw new HttpsError("invalid-argument", "authorBadgeLevel is invalid.");
  }
  return value;
}

function requireCategory(value) {
  if (!COMMUNITY_CATEGORIES.has(value)) {
    throw new HttpsError("invalid-argument", "category is invalid.");
  }
}

function requireActiveOwner(ownerSnap, contentType) {
  if (!ownerSnap.exists) {
    throw new HttpsError("permission-denied", `No private ${contentType} ownership record for this device.`);
  }
  if (ownerSnap.get("isDeleted") === true) {
    throw new HttpsError("failed-precondition", `This ${contentType} has already been deleted.`);
  }
}

function requireOwnerTopic(ownerSnap, topicId) {
  if (ownerSnap.get("topicId") !== topicId) {
    throw new HttpsError("permission-denied", "Private topic ownership record does not match this topic.");
  }
}

function requireOwnerReply(ownerSnap, topicId, replyId) {
  if (ownerSnap.get("topicId") !== topicId || ownerSnap.get("replyId") !== replyId) {
    throw new HttpsError("permission-denied", "Private reply ownership record does not match this reply.");
  }
}

function requireExistingPublicDoc(docSnap, contentType) {
  if (!docSnap.exists) {
    throw new HttpsError("not-found", `Community ${contentType} not found.`);
  }
  if (docSnap.get("isDeleted") === true) {
    throw new HttpsError("failed-precondition", `Community ${contentType} is deleted.`);
  }
}

async function commitCreateOnly(promise, duplicateMessage) {
  try {
    return await promise;
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    if (isAlreadyExistsError(error)) {
      throw new HttpsError("already-exists", duplicateMessage);
    }
    throw error;
  }
}

function isAlreadyExistsError(error) {
  return error && (error.code === 6 || error.code === "already-exists");
}

function pickDefined(payload, allowedFields) {
  return allowedFields.reduce((result, field) => {
    if (payload[field] !== undefined) result[field] = payload[field];
    return result;
  }, {});
}

function preview(value) {
  return value.length > 160 ? `${value.slice(0, 157)}...` : value;
}

function serializeOwnerDoc(doc) {
  return serializeTimestamps({ id: doc.id, ...doc.data() });
}

function serializeTimestamps(value) {
  if (value instanceof Timestamp) {
    return value.toDate().toISOString();
  }
  if (Array.isArray(value)) {
    return value.map(serializeTimestamps);
  }
  if (value && typeof value === "object") {
    return Object.entries(value).reduce((result, [key, nestedValue]) => {
      result[key] = serializeTimestamps(nestedValue);
      return result;
    }, {});
  }
  return value;
}
