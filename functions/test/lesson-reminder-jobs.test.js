"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");

const {__test} = require("../index.js");

test("normalizes reminder definitions and ignores invalid entries", () => {
  const reminders = __test.normalizeLessonProgressReminders([
    {
      id: "r-1",
      title: "Фініш",
      message: "Уточнити дані",
      progressPercent: 90,
    },
    {
      id: "r-1",
      title: "Дубль",
      message: "Не має пройти",
      progressPercent: 50,
    },
    {
      id: "r-2",
      title: "",
      message: "Порожній заголовок",
      progressPercent: 30,
    },
  ]);

  assert.equal(reminders.length, 1);
  assert.equal(reminders[0].id, "r-1");
  assert.equal(reminders[0].progressPercent, 90);
});

test("calculates reminder due time for 0, 90 and 100 percent", () => {
  const startTime = new Date("2026-03-20T08:15:00.000Z");
  const endTime = new Date("2026-03-20T13:35:00.000Z");

  assert.equal(
      __test.calculateReminderDueAt({
        startTime,
        endTime,
        progressPercent: 0,
      }).toISOString(),
      startTime.toISOString(),
  );

  assert.equal(
      __test.calculateReminderDueAt({
        startTime,
        endTime,
        progressPercent: 90,
      }).toISOString(),
      "2026-03-20T13:03:00.000Z",
  );

  assert.equal(
      __test.calculateReminderDueAt({
        startTime,
        endTime,
        progressPercent: 100,
      }).toISOString(),
      endTime.toISOString(),
  );
});

test("builds reminder job payload with deterministic ids", () => {
  const payload = __test.buildReminderJobPayload({
    lesson: {
      title: "Тактика",
      startTime: new Date("2026-03-20T08:15:00.000Z"),
      endTime: new Date("2026-03-20T13:35:00.000Z"),
    },
    groupId: "group-1",
    lessonId: "lesson-1",
    reminder: {
      id: "r-1",
      title: "Фініш",
      message: "Уточнити дані",
      progressPercent: 90,
    },
  });

  assert.equal(
      __test.buildLessonKey("group-1", "lesson-1"),
      "group-1_lesson-1",
  );
  assert.equal(
      __test.buildReminderJobId("group-1", "lesson-1", "r-1"),
      "group-1_lesson-1_r-1",
  );
  assert.equal(payload.reminderId, "r-1");
  assert.equal(payload.progressPercent, 90);
  assert.equal(payload.title, "Фініш");
  assert.equal(payload.message, "Уточнити дані");
  assert.equal(
      payload.dueAt.toDate().toISOString(),
      "2026-03-20T13:03:00.000Z",
  );
});

test("requeues reminder jobs when schedule or payload changed", () => {
  const payload = __test.buildReminderJobPayload({
    lesson: {
      title: "Тактика",
      startTime: new Date("2026-03-20T08:15:00.000Z"),
      endTime: new Date("2026-03-20T13:35:00.000Z"),
    },
    groupId: "group-1",
    lessonId: "lesson-1",
    reminder: {
      id: "r-1",
      title: "Фініш",
      message: "Уточнити дані",
      progressPercent: 90,
    },
  });

  assert.equal(__test.shouldRequeueReminderJob(null, payload), true);
  assert.equal(
      __test.shouldRequeueReminderJob({
        status: __test.REMINDER_JOB_STATUS.sent,
        dueAt: payload.dueAt,
        title: payload.title,
        message: payload.message,
        progressPercent: payload.progressPercent,
      }, payload),
      false,
  );
  assert.equal(
      __test.shouldRequeueReminderJob({
        status: __test.REMINDER_JOB_STATUS.sent,
        dueAt: payload.dueAt,
        title: payload.title,
        message: "Інший текст",
        progressPercent: payload.progressPercent,
      }, payload),
      true,
  );
});

test("treats all web platform variants as web push targets", () => {
  assert.equal(__test.isWebPushPlatform("web"), true);
  assert.equal(__test.isWebPushPlatform("web_ios_standalone"), true);
  assert.equal(__test.isWebPushPlatform("web_ios_browser"), true);
  assert.equal(__test.isWebPushPlatform("android"), false);
  assert.equal(__test.isWebPushPlatform(""), false);
});
