"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");

const reportTemplates = require("../report_templates.js");

test("rejects unknown DSL fields", () => {
  assert.throws(
      () => reportTemplates.__test.normalizeTemplateConfig({
        source: "lessons",
        periodField: "startTime",
        rowMode: "lesson_instructor",
        columns: [
          {key: "lesson.unknown", label: "Broken"},
        ],
      }),
      /whitelist/,
  );
});

test("formats custom dateRange as dd.MM.yyyy - dd.MM.yyyy", () => {
  const value = reportTemplates.__test.resolveCustomFieldValue({
    customFieldValues: {
      "період_навчання": {
        type: "dateRange",
        start: new Date("2026-02-17T00:00:00.000Z"),
        end: new Date("2026-04-14T00:00:00.000Z"),
      },
    },
  }, "період_навчання");

  assert.equal(value, "17.02.2026 - 14.04.2026");
});

test("expands lessons by instructors for lesson_instructor mode", () => {
  const rows = reportTemplates.__test.buildReportRows({
    lessons: [
      {
        title: "Т2",
        instructorIds: ["uid-1", "uid-2"],
        instructorNames: ["Сергій", "Юрій"],
      },
    ],
    rowMode: "lesson_instructor",
    memberLookup: {byAssignmentId: new Map(), byEmail: new Map()},
  });

  assert.equal(rows.length, 2);
  assert.equal(rows[0].instructor.assignmentId, "uid-1");
  assert.equal(rows[0].instructor.name, "Сергій");
  assert.equal(rows[1].instructor.assignmentId, "uid-2");
  assert.equal(rows[1].instructor.name, "Юрій");
});

test("builds member lookup from allowed_users and users data", async () => {
  const lookup = await reportTemplates.__test.buildGroupMemberLookupFromData({
    members: {
      "serhiy@example.com": {
        role: "admin",
        uid: "uid-1",
        firstName: "Сергій",
        lastName: "Кашуба",
      },
    },
    loadUserByUid: async (uid) => {
      assert.equal(uid, "uid-1");
      return {
        id: "uid-1",
        email: "serhiy@example.com",
        fullName: "Сергій Кашуба",
        rank: "майор",
        position: "інструктор",
        phone: "+380000000000",
      };
    },
    loadUserByEmail: async () => null,
  });

  const member = reportTemplates.__test.resolveMemberForAssignment({
    assignmentId: "uid-1",
    fallbackName: "Сергій",
    memberLookup: lookup,
  });

  assert.equal(member.uid, "uid-1");
  assert.equal(member.email, "serhiy@example.com");
  assert.equal(member.fullName, "Сергій Кашуба");
  assert.equal(member.role, "admin");
  assert.equal(member.rank, "майор");
});

test("groups, sorts and calculates totals", () => {
  const rows = [
    {
      lesson: {
        title: "Т3",
        unit: "Бета",
        customFieldValues: {},
      },
      instructor: {assignmentId: "uid-2", name: "Юрій"},
      member: {uid: "uid-2", fullName: "Юрій", role: "viewer"},
    },
    {
      lesson: {
        title: "Т2",
        unit: "Альфа",
        customFieldValues: {},
      },
      instructor: {assignmentId: "uid-1", name: "Сергій"},
      member: {uid: "uid-1", fullName: "Сергій", role: "admin"},
    },
  ];

  const filtered = reportTemplates.__test.applyFilters(rows, [
    {key: "member.role", operator: "exists", value: true},
  ]);
  const sorted = reportTemplates.__test.applySort(filtered, [
    {key: "lesson.unit", dir: "asc"},
  ]);
  const grouped = reportTemplates.__test.buildGroupedRows(
      sorted,
      ["instructor.name"],
  );
  const totals = reportTemplates.__test.computeReportTotals(sorted, [
    {type: "count", label: "Всього"},
    {
      type: "countDistinct",
      key: "instructor.assignmentId",
      label: "Унікальних інструкторів",
    },
  ]);

  assert.equal(sorted[0].lesson.unit, "Альфа");
  assert.equal(grouped.length, 2);
  assert.equal(grouped[0].label, "ІНСТРУКТОР: Сергій");
  assert.equal(totals[0].value, 2);
  assert.equal(totals[1].value, 2);
});

test("checks role access by hierarchy", () => {
  assert.equal(
      reportTemplates.__test.canRoleAccessTemplate("viewer", ["viewer"]),
      true,
  );
  assert.equal(
      reportTemplates.__test.canRoleAccessTemplate("viewer", ["admin"]),
      false,
  );
  assert.equal(
      reportTemplates.__test.canRoleAccessTemplate("admin", ["editor"]),
      true,
  );
});
