"use strict";
/* eslint-disable require-jsdoc, max-len */

const admin = require("firebase-admin");
const cors = require("cors")({origin: true});
const functionsV1 = require("firebase-functions/v1");
const logger = require("firebase-functions/logger");
const reportTemplates = require("./report_templates");

admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();

const EVENT_COLLECTION = "function_events";
const LESSON_REMINDER_JOBS_COLLECTION = "lesson_reminder_jobs";
const MAX_MULTICAST_SIZE = 500;
const ANDROID_CHANNEL_ID = "itacs_high_importance_notifications";
const NOTIFICATION_PREFERENCE_KEYS = {
  groupAnnouncements: "groupAnnouncements",
  lessonAssigned: "lessonAssigned",
  lessonRemoved: "lessonRemoved",
  lessonCriticalChanged: "lessonCriticalChanged",
  absenceRequestResult: "absenceRequestResult",
  lessonProgressReminder: "lessonProgressReminder",
  adminAbsenceAssignment: "adminAbsenceAssignment",
  adminLessonAcknowledged: "adminLessonAcknowledged",
};
const LESSON_RESET_FIELDS = [
  "startTime",
  "endTime",
  "unit",
];
const REMINDER_JOB_STATUS = {
  pending: "pending",
  processing: "processing",
  sent: "sent",
  skipped: "skipped",
  failed: "failed",
  cancelled: "cancelled",
};

exports.previewReportTemplate = functionsV1.https.onCall(
    reportTemplates.createPreviewHandler({db, admin, functionsV1}),
);

exports.publishReportTemplate = functionsV1.https.onCall(
    reportTemplates.createPublishHandler({db, functionsV1}),
);

exports.generateReportTemplate = functionsV1.https.onCall(
    reportTemplates.createGenerateHandler({db, admin, functionsV1}),
);

// ── Feedback / Bug reports ─────────────────────────────────────────────────

exports.submitFeedback = functionsV1.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functionsV1.https.HttpsError(
        "unauthenticated",
        "Користувач не авторизований",
    );
  }

  const {category, priority, description, appVersion, platform} = data;

  if (!description || description.trim().length < 10) {
    throw new functionsV1.https.HttpsError(
        "invalid-argument",
        "Опис занадто короткий",
    );
  }

  await db.collection("app_feedback").add({
    category: category ?? "other",
    priority: priority ?? null,
    description: description.trim(),
    userEmail: context.auth.token.email ?? "",
    userName: context.auth.token.name ?? context.auth.token.email ?? "",
    userId: context.auth.uid,
    appVersion: appVersion ?? "unknown",
    platform: platform ?? "unknown",
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    status: "new",
  });

  logger.info("Feedback submitted", {userId: context.auth.uid, category});
  return {success: true};
});

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
          preferenceKey: resolveGroupNotificationPreferenceKey(notification),
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
          preferenceKey: NOTIFICATION_PREFERENCE_KEYS.lessonAssigned,
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
        const operations = await buildLessonUpdatePushOperations({
          before,
          after,
          groupId: context.params.groupId,
          lessonId: context.params.lessonId,
        });

        if (operations.length === 0) {
          await finishEvent(eventKey, {status: "skipped"});
          return null;
        }

        const summary = createEmptySummary();
        for (const operation of operations) {
          const operationSummary = await sendPushToUsers(operation);
          mergeSummaries(summary, operationSummary);
        }

        await finishEvent(eventKey, {
          status: "completed",
          ...summary,
        });
      } catch (error) {
        await failEvent(eventKey, error);
      }

      return null;
    });

exports.sendPushForLessonAcknowledgement = functionsV1.firestore
    .document("lessons/{groupId}/items/{lessonId}")
    .onUpdate(async (change, context) => {
      const eventKey = buildEventKey(
          "lesson_acknowledgement",
          context.eventId,
      );
      const eventStarted = await startEvent(eventKey, {
        functionName: "sendPushForLessonAcknowledgement",
        groupId: context.params.groupId,
        lessonId: context.params.lessonId,
      });

      if (!eventStarted) {
        return null;
      }

      try {
        const before = change.before.data() || {};
        const after = change.after.data() || {};
        const acknowledgementEvent = detectNewAcknowledgement(before, after);

        if (!acknowledgementEvent) {
          await finishEvent(eventKey, {status: "skipped"});
          return null;
        }

        const adminUserIds = await resolveGroupAdminUserIds(
            context.params.groupId,
        );
        const recipientUserIds = adminUserIds.filter((userId) =>
          userId !== acknowledgementEvent.acknowledgedByUid);

        if (recipientUserIds.length === 0) {
          await finishEvent(eventKey, {
            status: "skipped",
            reason: "no_admin_recipients",
          });
          return null;
        }

        const request = buildLessonAcknowledgementPushRequest({
          lesson: after,
          groupId: context.params.groupId,
          lessonId: context.params.lessonId,
          acknowledgementEvent,
        });

        const summary = await sendPushToUsers({
          userIds: recipientUserIds,
          title: request.title,
          body: request.body,
          data: request.data,
          preferenceKey: NOTIFICATION_PREFERENCE_KEYS.adminLessonAcknowledged,
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

exports.syncLessonReminderJobs = functionsV1.firestore
    .document("lessons/{groupId}/items/{lessonId}")
    .onWrite(async (change, context) => {
      const groupId = context.params.groupId;
      const lessonId = context.params.lessonId;

      if (!change.after.exists) {
        await cancelReminderJobsForLesson({
          lessonKey: buildLessonKey(groupId, lessonId),
          reason: "lesson_deleted",
        });
        return null;
      }

      await syncReminderJobsForLesson({
        lesson: change.after.data() || {},
        groupId,
        lessonId,
      });
      return null;
    });

exports.sendLessonProgressReminderPush = functionsV1.pubsub
    .schedule("* * * * *")
    .onRun(async () => {
      const now = new Date();
      const snapshot = await db.collection(LESSON_REMINDER_JOBS_COLLECTION)
          .where("dueAt", "<=", admin.firestore.Timestamp.fromDate(now))
          .orderBy("dueAt")
          .limit(50)
          .get();

      for (const doc of snapshot.docs) {
        await processReminderJob(doc, now);
      }

      return null;
    });

exports.cleanupLessonReminderJobs = functionsV1.pubsub
    .schedule("every 24 hours")
    .onRun(async () => {
      const threshold = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);
      const snapshot = await db.collection(LESSON_REMINDER_JOBS_COLLECTION)
          .where("updatedAt", "<=", admin.firestore.Timestamp.fromDate(threshold))
          .limit(200)
          .get();

      const deleteBatch = db.batch();
      let deleteCount = 0;

      snapshot.docs.forEach((doc) => {
        const status = asString(doc.get("status"));
        if (status !== REMINDER_JOB_STATUS.sent &&
            status !== REMINDER_JOB_STATUS.cancelled &&
            status !== REMINDER_JOB_STATUS.skipped) {
          return;
        }

        deleteBatch.delete(doc.ref);
        deleteCount += 1;
      });

      if (deleteCount > 0) {
        await deleteBatch.commit();
      }

      logger.info("Reminder jobs cleanup completed", {deleteCount});
      return null;
    });

// ─── Telegram-сповіщення при новому feedback ─────────────────────────────────

const https = require("https");
const {defineSecret} = require("firebase-functions/params");

const telegramBotToken = defineSecret("TELEGRAM_BOT_TOKEN");
const telegramChatId = defineSecret("TELEGRAM_CHAT_ID");

function sendTelegramMessage(token, chatId, text) {
  return new Promise((resolve, reject) => {
    const body = JSON.stringify({chat_id: chatId, text, parse_mode: "HTML"});
    const req = https.request(
        {
          hostname: "api.telegram.org",
          path: `/bot${token}/sendMessage`,
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "Content-Length": Buffer.byteLength(body),
          },
        },
        (res) => {
          let data = "";
          res.on("data", (chunk) => (data += chunk));
          res.on("end", () => resolve(JSON.parse(data)));
        },
    );
    req.on("error", reject);
    req.write(body);
    req.end();
  });
}

exports.notifyOnNewFeedback = functionsV1
    .runWith({secrets: ["TELEGRAM_BOT_TOKEN", "TELEGRAM_CHAT_ID"]})
    .firestore.document("app_feedback/{docId}")
    .onCreate(async (snap) => {
      const token = telegramBotToken.value();
      const chatId = telegramChatId.value();

      if (!token || !chatId) {
        logger.warn("Telegram secrets missing — set TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID");
        return null;
      }

      const d = snap.data() || {};

      const categoryEmoji = {bug: "🐛", feature: "💡", other: "💬"}[d.category] || "💬";
      const categoryLabel = {bug: "Баг", feature: "Пропозиція", other: "Інше"}[d.category] || d.category;

      const priorityLine = d.priority
        ? `\n⚡️ Критичність: ${{low: "🟢 Низька", medium: "🟡 Середня", high: "🔴 Критична"}[d.priority] || d.priority}`
        : "";

      const createdAt = d.createdAt
        ? new Date(d.createdAt.toMillis()).toLocaleString("uk-UA", {timeZone: "Europe/Kyiv"})
        : "—";

      const text = [
        `${categoryEmoji} <b>Новий відгук — ${categoryLabel}</b>${priorityLine}`,
        ``,
        `👤 ${d.userName || "—"} (<code>${d.userEmail || "—"}</code>)`,
        `📱 ${d.platform || "—"} · v${d.appVersion || "—"}`,
        `🕐 ${createdAt}`,
        ``,
        `💬 <b>Опис:</b>`,
        d.description || "—",
      ].join("\n");

      try {
        await sendTelegramMessage(token, chatId, text);
        logger.info("Telegram feedback notification sent", {docId: snap.id});
      } catch (err) {
        logger.error("Failed to send Telegram notification", err);
      }

      return null;
    });

// ─────────────────────────────────────────────────────────────────────────────

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

async function syncReminderJobsForLesson({lesson, groupId, lessonId}) {
  const lessonKey = buildLessonKey(groupId, lessonId);
  const existingSnapshot = await db.collection(LESSON_REMINDER_JOBS_COLLECTION)
      .where("lessonKey", "==", lessonKey)
      .get();
  const existingJobsByReminderId = new Map(
      existingSnapshot.docs.map((doc) => [asString(doc.get("reminderId")), doc]),
  );
  const reminders = normalizeLessonProgressReminders(lesson.progressReminders);
  const currentReminderIds = new Set(reminders.map((reminder) => reminder.id));
  const now = Date.now();
  const batch = db.batch();

  for (const reminder of reminders) {
    const payload = buildReminderJobPayload({
      lesson,
      groupId,
      lessonId,
      reminder,
    });
    const jobDocId = buildReminderJobId(groupId, lessonId, reminder.id);
    const jobRef = db.collection(LESSON_REMINDER_JOBS_COLLECTION).doc(jobDocId);
    const existingDoc = existingJobsByReminderId.get(reminder.id);
    const dueAtMillis = payload.dueAt.toMillis();

    if (dueAtMillis <= now) {
      if (existingDoc &&
          shouldCancelReminderJobStatus(asString(existingDoc.get("status")))) {
        batch.set(jobRef, {
          ...payload,
          status: REMINDER_JOB_STATUS.skipped,
          skipReason: "past_due_on_sync",
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, {merge: true});
      }
      continue;
    }

    const existingData = existingDoc ? existingDoc.data() : null;
    const nextStatus = shouldRequeueReminderJob(existingData, payload) ?
      REMINDER_JOB_STATUS.pending :
      asString(existingDoc.get("status")) || REMINDER_JOB_STATUS.pending;

    batch.set(jobRef, {
      ...payload,
      status: nextStatus,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, {merge: true});
  }

  existingSnapshot.docs.forEach((doc) => {
    const reminderId = asString(doc.get("reminderId"));
    if (currentReminderIds.has(reminderId)) {
      return;
    }

    if (!shouldCancelReminderJobStatus(asString(doc.get("status")))) {
      return;
    }

    batch.set(doc.ref, {
      status: REMINDER_JOB_STATUS.cancelled,
      cancelReason: "reminder_removed",
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, {merge: true});
  });

  await batch.commit();
}

async function cancelReminderJobsForLesson({lessonKey, reason}) {
  const snapshot = await db.collection(LESSON_REMINDER_JOBS_COLLECTION)
      .where("lessonKey", "==", lessonKey)
      .get();

  if (snapshot.empty) {
    return;
  }

  const batch = db.batch();
  snapshot.docs.forEach((doc) => {
    if (!shouldCancelReminderJobStatus(asString(doc.get("status")))) {
      return;
    }

    batch.set(doc.ref, {
      status: REMINDER_JOB_STATUS.cancelled,
      cancelReason: reason,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, {merge: true});
  });

  await batch.commit();
}

async function processReminderJob(doc, now) {
  const claimedJob = await claimReminderJob(doc.ref, now);
  if (!claimedJob) {
    return;
  }

  try {
    const lessonSnapshot = await db.collection("lessons")
        .doc(claimedJob.groupId)
        .collection("items")
        .doc(claimedJob.lessonId)
        .get();

    if (!lessonSnapshot.exists) {
      await markReminderJob(doc.ref, REMINDER_JOB_STATUS.cancelled, {
        cancelReason: "lesson_missing",
      });
      return;
    }

    const lesson = lessonSnapshot.data() || {};
    const activeReminder = normalizeLessonProgressReminders(
        lesson.progressReminders,
    ).find((reminder) => reminder.id === claimedJob.reminderId);

    if (!activeReminder) {
      await markReminderJob(doc.ref, REMINDER_JOB_STATUS.cancelled, {
        cancelReason: "reminder_missing",
      });
      return;
    }

    const freshPayload = buildReminderJobPayload({
      lesson,
      groupId: claimedJob.groupId,
      lessonId: claimedJob.lessonId,
      reminder: activeReminder,
    });

    if (freshPayload.dueAt.toMillis() > now.getTime()) {
      await markReminderJob(doc.ref, REMINDER_JOB_STATUS.pending, {
        ...freshPayload,
        processingStartedAt: null,
      });
      return;
    }

    const recipientUserIds = await resolveLessonRecipientUserIds(lesson);
    if (recipientUserIds.length === 0) {
      await markReminderJob(doc.ref, REMINDER_JOB_STATUS.skipped, {
        skipReason: "no_instructors",
      });
      return;
    }

    const request = buildLessonProgressReminderPushRequest({
      lesson,
      groupId: claimedJob.groupId,
      lessonId: claimedJob.lessonId,
      reminder: activeReminder,
    });

    const summary = await sendPushToUsers({
      userIds: recipientUserIds,
      title: request.title,
      body: request.body,
      data: request.data,
      preferenceKey: NOTIFICATION_PREFERENCE_KEYS.lessonProgressReminder,
    });

    await markReminderJob(doc.ref, REMINDER_JOB_STATUS.sent, {
      ...freshPayload,
      sentAt: admin.firestore.FieldValue.serverTimestamp(),
      pushSummary: summary,
    });
  } catch (error) {
    logger.error("Lesson reminder push failed", {
      jobId: doc.id,
      error,
    });
    await markReminderJob(doc.ref, REMINDER_JOB_STATUS.failed, {
      errorMessage: error && error.message ? error.message : String(error),
    });
  }
}

async function claimReminderJob(docRef, now) {
  return db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(docRef);
    if (!snapshot.exists) {
      return null;
    }

    const status = asString(snapshot.get("status"));
    const dueAt = toDate(snapshot.get("dueAt"));
    if (status !== REMINDER_JOB_STATUS.pending ||
        !dueAt ||
        dueAt.getTime() > now.getTime()) {
      return null;
    }

    transaction.set(docRef, {
      status: REMINDER_JOB_STATUS.processing,
      processingStartedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, {merge: true});

    return {
      ...snapshot.data(),
      groupId: asString(snapshot.get("groupId")),
      lessonId: asString(snapshot.get("lessonId")),
      reminderId: asString(snapshot.get("reminderId")),
    };
  });
}

async function markReminderJob(docRef, status, payload = {}) {
  await docRef.set({
    ...payload,
    status,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, {merge: true});
}

function shouldCancelReminderJobStatus(status) {
  return status === REMINDER_JOB_STATUS.pending ||
    status === REMINDER_JOB_STATUS.processing ||
    status === REMINDER_JOB_STATUS.failed ||
    status === REMINDER_JOB_STATUS.skipped ||
    status === "";
}

function shouldRequeueReminderJob(existingJob, payload) {
  if (!existingJob) {
    return true;
  }

  const currentStatus = asString(existingJob.status);
  if (currentStatus === REMINDER_JOB_STATUS.cancelled ||
      currentStatus === REMINDER_JOB_STATUS.failed ||
      currentStatus === REMINDER_JOB_STATUS.skipped) {
    return true;
  }

  const existingDueAt = toDate(existingJob.dueAt);
  const payloadDueAt = payload.dueAt.toDate();
  if (!existingDueAt || existingDueAt.getTime() !== payloadDueAt.getTime()) {
    return true;
  }

  return asString(existingJob.title) !== payload.title ||
    asString(existingJob.message) !== payload.message ||
    Number(existingJob.progressPercent || 0) !== payload.progressPercent;
}

function buildLessonKey(groupId, lessonId) {
  return `${asString(groupId)}_${asString(lessonId)}`;
}

function buildReminderJobId(groupId, lessonId, reminderId) {
  return `${buildLessonKey(groupId, lessonId)}_${asString(reminderId)}`;
}

function buildReminderJobPayload({lesson, groupId, lessonId, reminder}) {
  const startTime = toDate(lesson.startTime);
  const endTime = toDate(lesson.endTime);
  const dueAt = calculateReminderDueAt({
    startTime,
    endTime,
    progressPercent: reminder.progressPercent,
  });

  return {
    lessonKey: buildLessonKey(groupId, lessonId),
    groupId,
    lessonId,
    reminderId: reminder.id,
    title: reminder.title,
    message: reminder.message,
    progressPercent: reminder.progressPercent,
    dueAt: admin.firestore.Timestamp.fromDate(dueAt),
    lessonTitle: asString(lesson.title),
    startTime: startTime ?
      admin.firestore.Timestamp.fromDate(startTime) :
      null,
    endTime: endTime ?
      admin.firestore.Timestamp.fromDate(endTime) :
      null,
  };
}

function buildLessonProgressReminderPushRequest({
  lesson,
  groupId,
  lessonId,
  reminder,
}) {
  const lessonTitle = asString(lesson.title) || "Заняття";
  const lessonStart = toDate(lesson.startTime);
  const title = reminder.title || "Нагадування під час заняття";
  const body = lessonStart ?
    `${lessonTitle} • ${reminder.message}` :
    reminder.message;

  return {
    title,
    body,
    data: {
      kind: "lesson_progress_reminder",
      title,
      body,
      groupId,
      lessonId,
      reminderId: reminder.id,
    },
  };
}

function normalizeLessonProgressReminders(raw) {
  if (!Array.isArray(raw)) {
    return [];
  }

  const reminders = [];
  const seenIds = new Set();

  raw.forEach((item, index) => {
    if (!item || typeof item !== "object") {
      return;
    }

    const reminderId = asString(item.id) || `reminder_${index}`;
    if (seenIds.has(reminderId)) {
      return;
    }

    const title = asString(item.title);
    const message = asString(item.message);
    const progressPercent = normalizeProgressPercent(item.progressPercent);
    if (!title || !message) {
      return;
    }

    seenIds.add(reminderId);
    reminders.push({
      id: reminderId,
      title,
      message,
      progressPercent,
    });
  });

  reminders.sort((left, right) =>
    left.progressPercent - right.progressPercent);
  return reminders;
}

function normalizeProgressPercent(value) {
  const numericValue = Number(value);
  if (Number.isNaN(numericValue)) {
    return 0;
  }

  if (numericValue < 0) {
    return 0;
  }

  if (numericValue > 100) {
    return 100;
  }

  return numericValue;
}

function calculateReminderDueAt({startTime, endTime, progressPercent}) {
  if (!(startTime instanceof Date) || Number.isNaN(startTime.getTime())) {
    return new Date();
  }

  if (!(endTime instanceof Date) || Number.isNaN(endTime.getTime())) {
    return new Date(startTime.getTime());
  }

  const durationMs = Math.max(endTime.getTime() - startTime.getTime(), 0);
  const offsetMs = durationMs * (normalizeProgressPercent(progressPercent) / 100);
  return new Date(startTime.getTime() + Math.round(offsetMs));
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
  return extractLessonAssignmentIds(lesson).length > 0;
}

function shouldSendLessonCreatePush(lesson) {
  return isFutureLesson(lesson) && lessonHasInstructors(lesson);
}

function hasRelevantLessonFieldChange(before, after) {
  return LESSON_RESET_FIELDS.some((fieldName) =>
    !deepEqual(before[fieldName], after[fieldName]));
}

function deepEqual(left, right) {
  return JSON.stringify(left || null) === JSON.stringify(right || null);
}

async function resolveLessonRecipientUserIds(lesson) {
  return resolveAssignmentIdsToUserIds(extractLessonAssignmentIds(lesson));
}

function extractLessonAssignmentIds(lesson) {
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

  return assignmentIds;
}

async function resolveAssignmentIdsToUserIds(assignmentIds) {
  const resolvedUserIds = await Promise.all(
      assignmentIds.map((assignmentId) => resolveUserId(assignmentId)),
  );

  return resolvedUserIds.filter(Boolean);
}

async function resolveUserId(value) {
  const rawValue = asString(value);
  if (!rawValue) {
    return null;
  }

  if (!rawValue.includes("@")) {
    return rawValue;
  }

  const normalizedEmail = rawValue.toLowerCase();

  const snapshot = await db.collection("users")
      .where("email", "==", normalizedEmail)
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

async function resolveGroupAdminUserIds(groupId) {
  const groupDoc = await db.collection("allowed_users").doc(groupId).get();
  if (!groupDoc.exists) {
    return [];
  }

  const members = groupDoc.get("members") || {};
  const candidateIds = [];

  for (const [email, rawValue] of Object.entries(members)) {
    const role = extractMemberRole(rawValue);
    if (role !== "admin") {
      continue;
    }

    if (rawValue && typeof rawValue === "object") {
      const memberUid = asString(rawValue.uid);
      if (memberUid && !candidateIds.includes(memberUid)) {
        candidateIds.push(memberUid);
        continue;
      }
    }

    const normalizedEmail = asString(email).toLowerCase();
    if (normalizedEmail && !candidateIds.includes(normalizedEmail)) {
      candidateIds.push(normalizedEmail);
    }
  }

  const resolvedUserIds = await Promise.all(
      candidateIds.map((candidateId) => resolveUserId(candidateId)),
  );

  return resolvedUserIds.filter(Boolean);
}

function extractMemberRole(rawValue) {
  if (!rawValue) {
    return "";
  }

  if (typeof rawValue === "string") {
    return asString(rawValue).toLowerCase();
  }

  if (typeof rawValue === "object") {
    return asString(rawValue.role).toLowerCase();
  }

  return "";
}

async function sendPushToUsers({userIds, title, body, data, preferenceKey}) {
  const filteredUserIds = await filterUserIdsByPreference(
      userIds,
      preferenceKey,
  );

  if (!Array.isArray(filteredUserIds) || filteredUserIds.length === 0) {
    return {
      userCount: 0,
      tokenCount: 0,
      successCount: 0,
      failureCount: 0,
    };
  }

  const tokenEntries = await collectTokenEntries(filteredUserIds);
  if (tokenEntries.length === 0) {
    logger.info("Push skipped: no device tokens", {
      preferenceKey,
      userIds: filteredUserIds,
      title,
    });
    return {
      userCount: filteredUserIds.length,
      tokenCount: 0,
      successCount: 0,
      failureCount: 0,
    };
  }

  let successCount = 0;
  let failureCount = 0;

  const androidEntries = tokenEntries.filter((entry) =>
    !isWebPushPlatform(entry.platform));
  const webEntries = tokenEntries.filter((entry) =>
    isWebPushPlatform(entry.platform));

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

  logger.info("Push send summary", {
    preferenceKey,
    userCount: filteredUserIds.length,
    tokenCount: tokenEntries.length,
    successCount,
    failureCount,
    title,
  });

  return {
    userCount: filteredUserIds.length,
    tokenCount: tokenEntries.length,
    successCount,
    failureCount,
  };
}

async function filterUserIdsByPreference(userIds, preferenceKey) {
  const uniqueUserIds = [...new Set((userIds || []).map((userId) => asString(userId))
      .filter(Boolean))];

  if (!preferenceKey || uniqueUserIds.length === 0) {
    return uniqueUserIds;
  }

  const snapshots = await Promise.all(
      uniqueUserIds.map((userId) => db.collection("users").doc(userId).get()),
  );

  return uniqueUserIds.filter((userId, index) =>
    isPreferenceEnabled(snapshots[index].data(), preferenceKey));
}

function isPreferenceEnabled(userData, preferenceKey) {
  if (!preferenceKey) {
    return true;
  }

  const preferences = userData &&
    typeof userData.notificationPreferences === "object" ?
      userData.notificationPreferences :
      {};
  const value = preferences[preferenceKey];

  return typeof value === "boolean" ? value : true;
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

function isWebPushPlatform(platform) {
  return asString(platform).toLowerCase().startsWith("web");
}

function buildLessonPushRequest({
  lesson,
  groupId,
  lessonId,
  reason,
}) {
  const lessonTitle = asString(lesson.title) || "Нове заняття";
  const lessonStart = toDate(lesson.startTime);
  let title = "Заняття оновлено";
  switch (reason) {
    case "new_assignment":
      title = "Вам призначено нове заняття";
      break;
    case "lesson_removed":
      title = "Вас зняли із заняття";
      break;
    case "critical_change":
      title = "Заняття оновлено, потрібно ознайомитись";
      break;
  }
  const body = lessonStart ?
    `${lessonTitle} • ${formatLessonDateTime(lessonStart)}` :
    lessonTitle;

  return {
    title,
    body,
    data: {
      kind: reason,
      title,
      body,
      groupId,
      lessonId,
    },
  };
}

function buildLessonAcknowledgementPushRequest({
  lesson,
  groupId,
  lessonId,
  acknowledgementEvent,
}) {
  const lessonTitle = asString(lesson.title) || "Заняття";
  const lessonStart = toDate(lesson.startTime);
  const acknowledgedByName = asString(acknowledgementEvent.acknowledgedByName) ||
    "Викладач";
  const title = "Викладач ознайомився із заняттям";
  const body = lessonStart ?
    `${acknowledgedByName} • ${lessonTitle} • ${formatLessonDateTime(lessonStart)}` :
    `${acknowledgedByName} • ${lessonTitle}`;

  return {
    title,
    body,
    data: {
      kind: "lesson_acknowledged",
      title,
      body,
      groupId,
      lessonId,
      acknowledgedByUid: acknowledgementEvent.acknowledgedByUid,
      acknowledgedByName,
      assignmentId: acknowledgementEvent.assignmentId,
    },
  };
}

function resolveGroupNotificationPreferenceKey(notification) {
  const type = asString(notification.type);
  const creationType = asString(notification.relatedAbsenceCreationType);

  switch (type) {
    case "announcement":
      return NOTIFICATION_PREFERENCE_KEYS.groupAnnouncements;
    case "absence_assigned":
    case "absence_updated":
      return NOTIFICATION_PREFERENCE_KEYS.adminAbsenceAssignment;
    case "absence_approved":
    case "absence_rejected":
      return creationType === "admin_assignment" ?
        NOTIFICATION_PREFERENCE_KEYS.adminAbsenceAssignment :
        NOTIFICATION_PREFERENCE_KEYS.absenceRequestResult;
    case "absence_cancelled":
      return creationType === "admin_assignment" ?
        NOTIFICATION_PREFERENCE_KEYS.adminAbsenceAssignment :
        NOTIFICATION_PREFERENCE_KEYS.absenceRequestResult;
    default:
      return NOTIFICATION_PREFERENCE_KEYS.groupAnnouncements;
  }
}

async function buildLessonUpdatePushOperations({
  before,
  after,
  groupId,
  lessonId,
}) {
  if (!isFutureLesson(after)) {
    return [];
  }

  const beforeAssignmentIds = extractLessonAssignmentIds(before);
  const afterAssignmentIds = extractLessonAssignmentIds(after);
  const addedAssignmentIds = afterAssignmentIds.filter((assignmentId) =>
    !beforeAssignmentIds.includes(assignmentId));
  const removedAssignmentIds = beforeAssignmentIds.filter((assignmentId) =>
    !afterAssignmentIds.includes(assignmentId));
  const retainedAssignmentIds = afterAssignmentIds.filter((assignmentId) =>
    beforeAssignmentIds.includes(assignmentId));
  const operations = [];

  if (addedAssignmentIds.length > 0) {
    const request = buildLessonPushRequest({
      lesson: after,
      groupId,
      lessonId,
      reason: "new_assignment",
    });
    const userIds = await resolveAssignmentIdsToUserIds(addedAssignmentIds);
    operations.push({
      userIds,
      title: request.title,
      body: request.body,
      data: request.data,
      preferenceKey: NOTIFICATION_PREFERENCE_KEYS.lessonAssigned,
    });
  }

  if (removedAssignmentIds.length > 0) {
    const request = buildLessonPushRequest({
      lesson: after,
      groupId,
      lessonId,
      reason: "lesson_removed",
    });
    const userIds = await resolveAssignmentIdsToUserIds(removedAssignmentIds);
    operations.push({
      userIds,
      title: request.title,
      body: request.body,
      data: request.data,
      preferenceKey: NOTIFICATION_PREFERENCE_KEYS.lessonRemoved,
    });
  }

  if (retainedAssignmentIds.length > 0 &&
      hasRelevantLessonFieldChange(before, after)) {
    const request = buildLessonPushRequest({
      lesson: after,
      groupId,
      lessonId,
      reason: "critical_change",
    });
    const userIds = await resolveAssignmentIdsToUserIds(retainedAssignmentIds);
    operations.push({
      userIds,
      title: request.title,
      body: request.body,
      data: request.data,
      preferenceKey: NOTIFICATION_PREFERENCE_KEYS.lessonCriticalChanged,
    });
  }

  return operations.filter((operation) =>
    Array.isArray(operation.userIds) && operation.userIds.length > 0);
}

function createEmptySummary() {
  return {
    userCount: 0,
    tokenCount: 0,
    successCount: 0,
    failureCount: 0,
  };
}

function mergeSummaries(target, source) {
  target.userCount += source.userCount || 0;
  target.tokenCount += source.tokenCount || 0;
  target.successCount += source.successCount || 0;
  target.failureCount += source.failureCount || 0;

  return target;
}

function detectNewAcknowledgement(before, after) {
  const beforeAcknowledgements = normalizeAcknowledgementsMap(
      before.instructorAcknowledgements,
  );
  const afterAcknowledgements = normalizeAcknowledgementsMap(
      after.instructorAcknowledgements,
  );

  for (const [assignmentId, currentRecord] of Object.entries(afterAcknowledgements)) {
    const previousRecord = beforeAcknowledgements[assignmentId];
    if (isNewAcknowledgementRecord(previousRecord, currentRecord)) {
      return {
        assignmentId,
        acknowledgedAt: asString(currentRecord.acknowledgedAt),
        acknowledgedByUid: asString(currentRecord.acknowledgedByUid),
        acknowledgedByName: asString(currentRecord.acknowledgedByName),
      };
    }
  }

  return null;
}

function normalizeAcknowledgementsMap(raw) {
  if (!raw || typeof raw !== "object") {
    return {};
  }

  return raw;
}

function isNewAcknowledgementRecord(previousRecord, currentRecord) {
  if (!currentRecord || typeof currentRecord !== "object") {
    return false;
  }

  const currentAcknowledgedAt = asString(currentRecord.acknowledgedAt);
  const currentAcknowledgedByUid = asString(currentRecord.acknowledgedByUid);
  if (!currentAcknowledgedAt || !currentAcknowledgedByUid) {
    return false;
  }

  if (!previousRecord || typeof previousRecord !== "object") {
    return true;
  }

  return asString(previousRecord.acknowledgedAt) !== currentAcknowledgedAt ||
    asString(previousRecord.acknowledgedByUid) !== currentAcknowledgedByUid;
}

function formatLessonDateTime(date) {
  const day = String(date.getDate()).padStart(2, "0");
  const month = String(date.getMonth() + 1).padStart(2, "0");
  const year = date.getFullYear();
  const hours = String(date.getHours()).padStart(2, "0");
  const minutes = String(date.getMinutes()).padStart(2, "0");

  return `${day}.${month}.${year} ${hours}:${minutes}`;
}

exports.__test = {
  REMINDER_JOB_STATUS,
  buildLessonKey,
  buildReminderJobId,
  buildReminderJobPayload,
  buildLessonProgressReminderPushRequest,
  calculateReminderDueAt,
  isWebPushPlatform,
  normalizeLessonProgressReminders,
  normalizeProgressPercent,
  shouldRequeueReminderJob,
};
