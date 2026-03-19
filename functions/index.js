"use strict";
/* eslint-disable require-jsdoc, max-len */

const admin = require("firebase-admin");
const cors = require("cors")({origin: true});
const functionsV1 = require("firebase-functions/v1");
const logger = require("firebase-functions/logger");

admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();

const EVENT_COLLECTION = "function_events";
const MAX_MULTICAST_SIZE = 500;
const ANDROID_CHANNEL_ID = "itacs_high_importance_notifications";
const LESSON_RESET_FIELDS = [
  "startTime",
  "endTime",
  "location",
  "unit",
  "trainingPeriod",
  "description",
  "tags",
  "instructorId",
  "instructorName",
  "instructorIds",
  "instructorNames",
];

exports.proxyDownload = functionsV1.https.onRequest((req, res) => {
  cors(req, res, async () => {
    const fileId = req.query.fileId;
    if (!fileId) {
      return res.status(400).send("Missing fileId");
    }

    const driveUrl =
      `https://drive.google.com/uc?id=${fileId}&export=download`;

    try {
      const response = await fetch(driveUrl);
      if (!response.ok) {
        throw new Error(`Failed with status ${response.status}`);
      }

      const buffer = await response.arrayBuffer();
      const contentType =
        response.headers.get("content-type") || "application/octet-stream";

      res.setHeader("Content-Type", contentType);
      res.send(Buffer.from(buffer));
    } catch (error) {
      logger.error("Download error", error);
      res.status(500).send("Failed to download file");
    }
  });
});

exports.sendPushForGroupNotification = functionsV1.firestore
    .document("groups/{groupId}/notifications/{notificationId}")
    .onCreate(async (snapshot, context) => {
      const eventKey = buildEventKey(
          "group_notification",
          context.eventId,
      );
      const eventStarted = await startEvent(eventKey, {
        functionName: "sendPushForGroupNotification",
        groupId: context.params.groupId,
        notificationId: context.params.notificationId,
      });

      if (!eventStarted) {
        return null;
      }

      try {
        const notification = snapshot.data() || {};
        const groupId = context.params.groupId;
        const title = asString(notification.title) || "Нове сповіщення";
        const body = asString(notification.message) ||
          "У застосунку з'явилось нове сповіщення";

        let recipientUserIds = [];
        const targetUserId = asString(notification.targetUserId);
        if (targetUserId) {
          const resolvedUserId = await resolveUserId(targetUserId);
          if (resolvedUserId) {
            recipientUserIds = [resolvedUserId];
          }
        } else {
          recipientUserIds = await resolveGroupMemberUserIds(groupId);
        }

        const summary = await sendPushToUsers({
          userIds: recipientUserIds,
          title,
          body,
          data: {
            kind: "group_notification",
            title,
            body,
            groupId,
            notificationId: context.params.notificationId,
          },
        });

        await finishEvent(eventKey, {
          status: "completed",
          ...summary,
        });
      } catch (error) {
        await failEvent(eventKey, error);
      }

      return null;
    });

exports.sendPushForLessonCreate = functionsV1.firestore
    .document("lessons/{groupId}/items/{lessonId}")
    .onCreate(async (snapshot, context) => {
      const eventKey = buildEventKey(
          "lesson_create",
          context.eventId,
      );
      const eventStarted = await startEvent(eventKey, {
        functionName: "sendPushForLessonCreate",
        groupId: context.params.groupId,
        lessonId: context.params.lessonId,
      });

      if (!eventStarted) {
        return null;
      }

      try {
        const lesson = snapshot.data() || {};
        if (!shouldSendLessonCreatePush(lesson)) {
          await finishEvent(eventKey, {status: "skipped"});
          return null;
        }

        const recipientUserIds = await resolveLessonRecipientUserIds(lesson);
        const request = buildLessonPushRequest({
          lesson,
          groupId: context.params.groupId,
          lessonId: context.params.lessonId,
          reason: "new_assignment",
        });

        const summary = await sendPushToUsers({
          userIds: recipientUserIds,
          title: request.title,
          body: request.body,
          data: request.data,
        });

        await finishEvent(eventKey, {
          status: "completed",
          ...summary,
        });
      } catch (error) {
        await failEvent(eventKey, error);
      }

      return null;
    });

exports.sendPushForLessonUpdate = functionsV1.firestore
    .document("lessons/{groupId}/items/{lessonId}")
    .onUpdate(async (change, context) => {
      const eventKey = buildEventKey(
          "lesson_update",
          context.eventId,
      );
      const eventStarted = await startEvent(eventKey, {
        functionName: "sendPushForLessonUpdate",
        groupId: context.params.groupId,
        lessonId: context.params.lessonId,
      });

      if (!eventStarted) {
        return null;
      }

      try {
        const before = change.before.data() || {};
        const after = change.after.data() || {};

        if (!shouldSendLessonUpdatePush(before, after)) {
          await finishEvent(eventKey, {status: "skipped"});
          return null;
        }

        const recipientUserIds = await resolveLessonRecipientUserIds(after);
        const request = buildLessonPushRequest({
          lesson: after,
          groupId: context.params.groupId,
          lessonId: context.params.lessonId,
          reason: "acknowledgement_reset",
        });

        const summary = await sendPushToUsers({
          userIds: recipientUserIds,
          title: request.title,
          body: request.body,
          data: request.data,
        });

        await finishEvent(eventKey, {
          status: "completed",
          ...summary,
        });
      } catch (error) {
        await failEvent(eventKey, error);
      }

      return null;
    });

function buildEventKey(prefix, eventId) {
  return `${prefix}_${eventId}`;
}

async function startEvent(eventKey, payload) {
  const docRef = db.collection(EVENT_COLLECTION).doc(eventKey);

  try {
    await docRef.create({
      ...payload,
      status: "processing",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    return true;
  } catch (error) {
    if (isAlreadyExistsError(error)) {
      logger.info("Duplicate function event skipped", {eventKey});
      return false;
    }
    throw error;
  }
}

async function finishEvent(eventKey, payload) {
  await db.collection(EVENT_COLLECTION).doc(eventKey).set({
    ...payload,
    finishedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, {merge: true});
}

async function failEvent(eventKey, error) {
  logger.error("Push function failed", {eventKey, error});
  await finishEvent(eventKey, {
    status: "failed",
    errorMessage: error && error.message ? error.message : String(error),
  });
}

function isAlreadyExistsError(error) {
  if (!error) {
    return false;
  }

  return error.code === 6 ||
    error.code === "already-exists" ||
    error.code === "ALREADY_EXISTS";
}

function asString(value) {
  return value == null ? "" : String(value).trim();
}

function isFutureLesson(lesson) {
  const startTime = toDate(lesson.startTime);
  if (!startTime) {
    return false;
  }

  return startTime.getTime() > Date.now();
}

function toDate(value) {
  if (!value) {
    return null;
  }

  if (typeof value.toDate === "function") {
    return value.toDate();
  }

  if (value instanceof Date) {
    return value;
  }

  const parsedDate = new Date(value);
  return Number.isNaN(parsedDate.getTime()) ? null : parsedDate;
}

function lessonHasInstructors(lesson) {
  const instructorIds = Array.isArray(lesson.instructorIds) ?
    lesson.instructorIds.map(asString).filter(Boolean) :
    [];

  if (instructorIds.length > 0) {
    return true;
  }

  return Boolean(asString(lesson.instructorId));
}

function shouldSendLessonCreatePush(lesson) {
  return isFutureLesson(lesson) && lessonHasInstructors(lesson);
}

function shouldSendLessonUpdatePush(before, after) {
  if (!isFutureLesson(after) || !lessonHasInstructors(after)) {
    return false;
  }

  const beforeResetAt = toDate(before.acknowledgementResetAt);
  const afterResetAt = toDate(after.acknowledgementResetAt);

  if (!afterResetAt) {
    return false;
  }

  if (beforeResetAt &&
      beforeResetAt.getTime() === afterResetAt.getTime() &&
      !hasRelevantLessonFieldChange(before, after)) {
    return false;
  }

  if (!beforeResetAt && afterResetAt) {
    return hasRelevantLessonFieldChange(before, after);
  }

  return !beforeResetAt ||
    beforeResetAt.getTime() !== afterResetAt.getTime() ||
    hasRelevantLessonFieldChange(before, after);
}

function hasRelevantLessonFieldChange(before, after) {
  return LESSON_RESET_FIELDS.some((fieldName) =>
    !deepEqual(before[fieldName], after[fieldName]));
}

function deepEqual(left, right) {
  return JSON.stringify(left || null) === JSON.stringify(right || null);
}

async function resolveLessonRecipientUserIds(lesson) {
  const assignmentIds = [];
  const rawInstructorIds = Array.isArray(lesson.instructorIds) ?
    lesson.instructorIds :
    [];

  for (const instructorId of rawInstructorIds) {
    const normalizedInstructorId = asString(instructorId);
    if (normalizedInstructorId &&
        !assignmentIds.includes(normalizedInstructorId)) {
      assignmentIds.push(normalizedInstructorId);
    }
  }

  const primaryInstructorId = asString(lesson.instructorId);
  if (primaryInstructorId && !assignmentIds.includes(primaryInstructorId)) {
    assignmentIds.push(primaryInstructorId);
  }

  const resolvedUserIds = await Promise.all(
      assignmentIds.map((assignmentId) => resolveUserId(assignmentId)),
  );

  return resolvedUserIds.filter(Boolean);
}

async function resolveUserId(value) {
  const normalizedValue = asString(value).toLowerCase();
  if (!normalizedValue) {
    return null;
  }

  if (!normalizedValue.includes("@")) {
    return normalizedValue;
  }

  const snapshot = await db.collection("users")
      .where("email", "==", normalizedValue)
      .limit(1)
      .get();

  if (snapshot.empty) {
    return null;
  }

  return snapshot.docs[0].id;
}

async function resolveGroupMemberUserIds(groupId) {
  const groupDoc = await db.collection("allowed_users").doc(groupId).get();
  if (!groupDoc.exists) {
    return [];
  }

  const members = groupDoc.get("members") || {};
  const candidateIds = [];

  for (const [email, rawValue] of Object.entries(members)) {
    const normalizedEmail = asString(email).toLowerCase();
    if (rawValue && typeof rawValue === "object") {
      const memberUid = asString(rawValue.uid);
      if (memberUid && !candidateIds.includes(memberUid)) {
        candidateIds.push(memberUid);
        continue;
      }
    }

    if (normalizedEmail && !candidateIds.includes(normalizedEmail)) {
      candidateIds.push(normalizedEmail);
    }
  }

  const resolvedUserIds = await Promise.all(
      candidateIds.map((candidateId) => resolveUserId(candidateId)),
  );

  return resolvedUserIds.filter(Boolean);
}

async function sendPushToUsers({userIds, title, body, data}) {
  if (!Array.isArray(userIds) || userIds.length === 0) {
    return {
      userCount: 0,
      tokenCount: 0,
      successCount: 0,
      failureCount: 0,
    };
  }

  const tokenEntries = await collectTokenEntries(userIds);
  if (tokenEntries.length === 0) {
    return {
      userCount: userIds.length,
      tokenCount: 0,
      successCount: 0,
      failureCount: 0,
    };
  }

  let successCount = 0;
  let failureCount = 0;

  const androidEntries = tokenEntries.filter((entry) => entry.platform !== "web");
  const webEntries = tokenEntries.filter((entry) => entry.platform === "web");

  const androidSummary = await sendPlatformBatches({
    tokenEntries: androidEntries,
    messageFactory: (tokens) => ({
      tokens,
      notification: {
        title,
        body,
      },
      data: stringifyMessageData(data),
      android: {
        priority: "high",
        notification: {
          channelId: ANDROID_CHANNEL_ID,
          priority: "high",
        },
      },
    }),
  });

  const webSummary = await sendPlatformBatches({
    tokenEntries: webEntries,
    messageFactory: (tokens) => ({
      tokens,
      data: stringifyMessageData(data),
      webpush: {
        headers: {
          Urgency: "high",
        },
      },
    }),
  });

  successCount += androidSummary.successCount + webSummary.successCount;
  failureCount += androidSummary.failureCount + webSummary.failureCount;

  return {
    userCount: userIds.length,
    tokenCount: tokenEntries.length,
    successCount,
    failureCount,
  };
}

async function collectTokenEntries(userIds) {
  const uniqueUserIds = [...new Set(userIds.map((userId) => asString(userId)))];

  const snapshots = await Promise.all(
      uniqueUserIds.map((userId) =>
        db.collection("users")
            .doc(userId)
            .collection("devices")
            .where("notificationsEnabled", "==", true)
            .get()),
  );

  const tokenEntries = [];
  const seenTokens = new Set();

  snapshots.forEach((snapshot) => {
    snapshot.docs.forEach((doc) => {
      const token = asString(doc.get("token")) || doc.id;
      if (!token || seenTokens.has(token)) {
        return;
      }

      seenTokens.add(token);
      tokenEntries.push({
        token,
        ref: doc.ref,
        platform: asString(doc.get("platform")).toLowerCase(),
      });
    });
  });

  return tokenEntries;
}

async function sendPlatformBatches({tokenEntries, messageFactory}) {
  let successCount = 0;
  let failureCount = 0;

  for (let index = 0; index < tokenEntries.length; index += MAX_MULTICAST_SIZE) {
    const batch = tokenEntries.slice(index, index + MAX_MULTICAST_SIZE);
    const batchResult = await messaging.sendEachForMulticast(
        messageFactory(batch.map((entry) => entry.token)),
    );

    successCount += batchResult.successCount;
    failureCount += batchResult.failureCount;

    const invalidDocRefs = [];
    batchResult.responses.forEach((response, responseIndex) => {
      if (response.success) {
        return;
      }

      const errorCode = response.error && response.error.code ?
        response.error.code :
        "";

      if (isInvalidTokenError(errorCode)) {
        invalidDocRefs.push(batch[responseIndex].ref);
      }
    });

    await Promise.all(
        invalidDocRefs.map((docRef) =>
          docRef.delete().catch(() => {
            logger.warn("Failed to delete invalid token doc", {
              path: docRef.path,
            });
          })),
    );
  }

  return {successCount, failureCount};
}

function isInvalidTokenError(errorCode) {
  return errorCode === "messaging/registration-token-not-registered" ||
    errorCode === "messaging/invalid-registration-token" ||
    errorCode === "messaging/invalid-argument";
}

function stringifyMessageData(data) {
  const serialized = {};

  Object.entries(data || {}).forEach(([key, value]) => {
    if (value == null) {
      return;
    }
    serialized[key] = String(value);
  });

  return serialized;
}

function buildLessonPushRequest({
  lesson,
  groupId,
  lessonId,
  reason,
}) {
  const lessonTitle = asString(lesson.title) || "Нове заняття";
  const lessonStart = toDate(lesson.startTime);
  const title = reason === "new_assignment" ?
    "Вам призначено нове заняття" :
    "Заняття оновлено, потрібно ознайомитись";
  const body = lessonStart ?
    `${lessonTitle} • ${formatLessonDateTime(lessonStart)}` :
    lessonTitle;

  return {
    title,
    body,
    data: {
      kind: "lesson_acknowledgement",
      title,
      body,
      groupId,
      lessonId,
    },
  };
}

function formatLessonDateTime(date) {
  const day = String(date.getDate()).padStart(2, "0");
  const month = String(date.getMonth() + 1).padStart(2, "0");
  const year = date.getFullYear();
  const hours = String(date.getHours()).padStart(2, "0");
  const minutes = String(date.getMinutes()).padStart(2, "0");

  return `${day}.${month}.${year} ${hours}:${minutes}`;
}
