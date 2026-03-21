"use strict";
/* eslint-disable require-jsdoc, max-len */

const ExcelJS = require("exceljs");

const TEMPLATE_STATUS = {
  draft: "draft",
  active: "active",
};

const TEMPLATE_SOURCE = {
  lessons: "lessons",
};

const TEMPLATE_PERIOD_FIELD = {
  startTime: "startTime",
  endTime: "endTime",
};

const TEMPLATE_ROW_MODE = {
  lesson: "lesson",
  lessonInstructor: "lesson_instructor",
};

const FILTER_OPERATOR = {
  eq: "eq",
  neq: "neq",
  in: "in",
  contains: "contains",
  exists: "exists",
  dateBetween: "date_between",
  lteNow: "lte_now",
};

const SORT_DIRECTION = {
  asc: "asc",
  desc: "desc",
};

const TOTAL_TYPE = {
  count: "count",
  countDistinct: "countDistinct",
  sum: "sum",
};

const ROLE_HIERARCHY = {
  viewer: 1,
  editor: 2,
  admin: 3,
};

const XLSX_MIME_TYPE =
  "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet";
const MAX_PREVIEW_ROWS = 25;
const MAX_REPORT_ROWS = 5000;
const MAX_REPORT_RANGE_DAYS = 365;
const DEFAULT_ALLOWED_ROLES = ["viewer"];

const FIELD_CATALOG = {
  "lesson.title": {
    label: "Назва заняття",
    valueType: "string",
    getRawValue: (row) => asString(row.lesson.title),
  },
  "lesson.description": {
    label: "Опис",
    valueType: "string",
    getRawValue: (row) => asString(row.lesson.description),
  },
  "lesson.startTime": {
    label: "Початок",
    valueType: "datetime",
    getRawValue: (row) => toDate(row.lesson.startTime),
  },
  "lesson.endTime": {
    label: "Кінець",
    valueType: "datetime",
    getRawValue: (row) => toDate(row.lesson.endTime),
  },
  "lesson.startDate": {
    label: "Дата",
    valueType: "date",
    getRawValue: (row) => toDate(row.lesson.startTime),
  },
  "lesson.endDate": {
    label: "Дата завершення",
    valueType: "date",
    getRawValue: (row) => toDate(row.lesson.endTime),
  },
  "lesson.unit": {
    label: "Підрозділ",
    valueType: "string",
    getRawValue: (row) => asString(row.lesson.unit),
  },
  "lesson.location": {
    label: "Локація",
    valueType: "string",
    getRawValue: (row) => asString(row.lesson.location),
  },
  "lesson.status": {
    label: "Статус",
    valueType: "string",
    getRawValue: (row) => asString(row.lesson.status),
  },
  "lesson.tags": {
    label: "Теги",
    valueType: "array",
    getRawValue: (row) => toStringArray(row.lesson.tags),
  },
  "lesson.groupName": {
    label: "Група",
    valueType: "string",
    getRawValue: (row) => asString(row.lesson.groupName),
  },
  "lesson.maxParticipants": {
    label: "Максимум учасників",
    valueType: "number",
    getRawValue: (row) => toNumber(row.lesson.maxParticipants),
  },
  "lesson.currentParticipants": {
    label: "Поточна кількість",
    valueType: "number",
    getRawValue: (row) => toNumber(row.lesson.currentParticipants),
  },
  "lesson.typeId": {
    label: "Тип заняття",
    valueType: "string",
    getRawValue: (row) => asString(row.lesson.type),
  },
  "lesson.templateId": {
    label: "ID шаблону заняття",
    valueType: "string",
    getRawValue: (row) => asString(row.lesson.templateId),
  },
  "instructor.assignmentId": {
    label: "ID інструктора",
    valueType: "string",
    getRawValue: (row) => asString(row.instructor.assignmentId),
  },
  "instructor.name": {
    label: "Інструктор",
    valueType: "string",
    getRawValue: (row) => asString(row.instructor.name),
  },
  "member.uid": {
    label: "UID користувача",
    valueType: "string",
    getRawValue: (row) => asString(row.member.uid),
  },
  "member.email": {
    label: "Email",
    valueType: "string",
    getRawValue: (row) => asString(row.member.email),
  },
  "member.fullName": {
    label: "ПІБ",
    valueType: "string",
    getRawValue: (row) => asString(row.member.fullName),
  },
  "member.role": {
    label: "Роль",
    valueType: "string",
    getRawValue: (row) => asString(row.member.role),
  },
  "member.rank": {
    label: "Звання",
    valueType: "string",
    getRawValue: (row) => asString(row.member.rank),
  },
  "member.position": {
    label: "Посада",
    valueType: "string",
    getRawValue: (row) => asString(row.member.position),
  },
  "member.phone": {
    label: "Телефон",
    valueType: "string",
    getRawValue: (row) => asString(row.member.phone),
  },
};

function createPreviewHandler({db, admin, functionsV1}) {
  return async (data, context) => {
    const request = normalizeCallableRequest(data, functionsV1);
    const auth = requireAuth(context, functionsV1);
    const membership = await getGroupMembership({
      db,
      groupId: request.groupId,
      auth,
      functionsV1,
    });

    ensureAdmin(membership.role, functionsV1);

    const template = await getReportTemplateDoc({
      db,
      groupId: request.groupId,
      templateId: request.templateId,
      functionsV1,
    });

    const config = selectTemplateConfig({
      template,
      useDraft: request.useDraft,
      role: membership.role,
      functionsV1,
    });

    const normalizedTemplate = normalizeTemplateDocument(template);
    const dataset = await buildReportDataset({
      db,
      admin,
      groupId: request.groupId,
      config,
      startDate: request.startDate,
      endDate: request.endDate,
      warnings: [],
    });

    return {
      templateId: request.templateId,
      templateName: normalizedTemplate.name,
      columns: dataset.columns,
      sampleRows: dataset.sampleRows,
      totalRows: dataset.totalRows,
      warnings: dataset.warnings,
    };
  };
}

function createPublishHandler({db, functionsV1}) {
  return async (data, context) => {
    const auth = requireAuth(context, functionsV1);
    const groupId = asString(data && data.groupId);
    const templateId = asString(data && data.templateId);

    if (!groupId || !templateId) {
      throw new functionsV1.https.HttpsError(
          "invalid-argument",
          "Потрібно передати groupId і templateId.",
      );
    }

    const membership = await getGroupMembership({
      db,
      groupId,
      auth,
      functionsV1,
    });
    ensureAdmin(membership.role, functionsV1);

    const templateRef = db.collection("groups")
        .doc(groupId)
        .collection("report_templates")
        .doc(templateId);
    const snapshot = await templateRef.get();

    if (!snapshot.exists) {
      throw new functionsV1.https.HttpsError(
          "not-found",
          "Шаблон звіту не знайдено.",
      );
    }

    const template = normalizeTemplateDocument({
      id: snapshot.id,
      ...snapshot.data(),
    });
    const draftConfig = normalizeTemplateConfig(template.draftConfig);
    const nextActiveVersion = Math.max(1, template.activeVersion + 1);
    const now = new Date();

    await templateRef.update({
      status: TEMPLATE_STATUS.active,
      activeConfig: draftConfig,
      activeVersion: nextActiveVersion,
      publishedAt: now,
      publishedBy: auth.uid,
      updatedAt: now,
      updatedBy: auth.uid,
    });

    return {
      templateId,
      status: TEMPLATE_STATUS.active,
      activeVersion: nextActiveVersion,
    };
  };
}

function createGenerateHandler({db, admin, functionsV1}) {
  return async (data, context) => {
    const request = normalizeCallableRequest(data, functionsV1);
    const auth = requireAuth(context, functionsV1);
    const membership = await getGroupMembership({
      db,
      groupId: request.groupId,
      auth,
      functionsV1,
    });

    const template = await getReportTemplateDoc({
      db,
      groupId: request.groupId,
      templateId: request.templateId,
      functionsV1,
    });

    const normalizedTemplate = normalizeTemplateDocument(template);
    const config = selectTemplateConfig({
      template: normalizedTemplate,
      useDraft: request.useDraft,
      role: membership.role,
      functionsV1,
    });

    if (!request.useDraft &&
        !canRoleAccessTemplate(membership.role, normalizedTemplate.allowedRoles)) {
      throw new functionsV1.https.HttpsError(
          "permission-denied",
          "Недостатньо прав для генерації цього звіту.",
      );
    }

    const dataset = await buildReportDataset({
      db,
      admin,
      groupId: request.groupId,
      config,
      startDate: request.startDate,
      endDate: request.endDate,
      warnings: [],
    });

    if (dataset.totalRows > MAX_REPORT_ROWS) {
      throw new functionsV1.https.HttpsError(
          "failed-precondition",
          "Звіт занадто великий. Звузьте період або зменште вибірку.",
      );
    }

    const workbookBuffer = await buildWorkbookBuffer({
      groupName: membership.groupName,
      templateName: normalizedTemplate.name,
      startDate: request.startDate,
      endDate: request.endDate,
      generatedAt: new Date(),
      dataset,
    });

    return {
      templateId: request.templateId,
      templateName: normalizedTemplate.name,
      fileName: buildReportFileName({
        templateName: normalizedTemplate.name,
        startDate: request.startDate,
        endDate: request.endDate,
      }),
      mimeType: XLSX_MIME_TYPE,
      bytesBase64: Buffer.from(workbookBuffer).toString("base64"),
      warnings: dataset.warnings,
      totalRows: dataset.totalRows,
    };
  };
}

async function buildReportDataset({
  db,
  admin,
  groupId,
  config,
  startDate,
  endDate,
  warnings,
}) {
  const lessons = await fetchLessonsForPeriod({
    db,
    admin,
    groupId,
    config,
    startDate,
    endDate,
  });
  const memberLookup = await buildGroupMemberLookup({db, groupId});
  const rows = buildReportRows({
    lessons,
    rowMode: config.rowMode,
    memberLookup,
  });
  const filteredRows = applyFilters(rows, config.filters);
  const sortedRows = applySort(filteredRows, config.sort);
  const columns = config.columns.map((column) => ({
    key: column.key,
    label: column.label,
  }));
  const groupedRows = buildGroupedRows(sortedRows, config.groupBy);
  const totals = computeReportTotals(sortedRows, config.totals);

  if (sortedRows.length > MAX_REPORT_ROWS) {
    warnings.push(
        "Кількість рядків перевищує рекомендований ліміт для v1.",
    );
  }

  return {
    columns,
    rows: sortedRows,
    sampleRows: sortedRows
        .slice(0, MAX_PREVIEW_ROWS)
        .map((row) => formatRowForOutput(row, config.columns)),
    totalRows: sortedRows.length,
    groupedRows,
    totals,
    sheet: config.sheet,
    warnings,
  };
}

async function fetchLessonsForPeriod({
  db,
  admin,
  groupId,
  config,
  startDate,
  endDate,
}) {
  const snapshot = await db.collection("lessons")
      .doc(groupId)
      .collection("items")
      .where(
          config.periodField,
          ">=",
          admin.firestore.Timestamp.fromDate(startDate),
      )
      .where(
          config.periodField,
          "<=",
          admin.firestore.Timestamp.fromDate(endDate),
      )
      .orderBy(config.periodField)
      .get();

  return snapshot.docs.map((doc) => ({
    id: doc.id,
    ...normalizeFirestoreValue(doc.data(), admin),
  }));
}

function buildReportRows({lessons, rowMode, memberLookup}) {
  const rows = [];

  for (const lesson of lessons) {
    const assignments = extractLessonAssignments(lesson);
    if (rowMode === TEMPLATE_ROW_MODE.lessonInstructor) {
      if (assignments.length === 0) {
        rows.push(createRow({
          lesson,
          assignment: {assignmentId: "", name: ""},
          memberLookup,
        }));
        continue;
      }

      for (const assignment of assignments) {
        rows.push(createRow({lesson, assignment, memberLookup}));
      }
      continue;
    }

    const primaryAssignment = assignments[0] || {
      assignmentId: asString(lesson.instructorId),
      name: asString(lesson.instructorName),
    };
    rows.push(createRow({
      lesson,
      assignment: primaryAssignment,
      memberLookup,
    }));
  }

  return rows;
}

function createRow({lesson, assignment, memberLookup}) {
  const member = resolveMemberForAssignment({
    assignmentId: assignment.assignmentId,
    fallbackName: assignment.name,
    memberLookup,
  });

  return {
    lesson,
    instructor: {
      assignmentId: asString(assignment.assignmentId),
      name: asString(assignment.name),
    },
    member,
  };
}

function buildGroupedRows(rows, groupByKeys) {
  if (!Array.isArray(groupByKeys) || groupByKeys.length === 0) {
    return [{label: null, rows}];
  }

  return buildGroupLevel(rows, groupByKeys, 0);
}

function buildGroupLevel(rows, groupByKeys, depth) {
  if (depth >= groupByKeys.length) {
    return [{label: null, rows}];
  }

  const key = groupByKeys[depth];
  const groups = new Map();

  for (const row of rows) {
    const value = formatFieldValue(key, resolveFieldRawValue(row, key));
    const groupLabel = value || "Не вказано";
    if (!groups.has(groupLabel)) {
      groups.set(groupLabel, []);
    }
    groups.get(groupLabel).push(row);
  }

  return Array.from(groups.entries())
      .sort((a, b) => a[0].localeCompare(b[0], "uk"))
      .map(([groupValue, groupRows]) => ({
        key,
        label: `${getFieldLabel(key).toUpperCase()}: ${groupValue}`,
        value: groupValue,
        rows: groupRows,
        children: buildGroupLevel(groupRows, groupByKeys, depth + 1),
      }));
}

function computeReportTotals(rows, totalsConfig) {
  const effectiveTotals = Array.isArray(totalsConfig) && totalsConfig.length > 0 ?
    totalsConfig :
    [{type: TOTAL_TYPE.count, label: "Всього записів"}];

  return effectiveTotals.map((item) => {
    const label = asString(item.label) || defaultTotalLabel(item);
    const totalValue = computeSingleTotal(rows, item);
    return {
      type: item.type,
      key: asString(item.key),
      label,
      value: totalValue,
    };
  });
}

function computeSingleTotal(rows, totalConfig) {
  switch (totalConfig.type) {
    case TOTAL_TYPE.count:
      return rows.length;
    case TOTAL_TYPE.countDistinct: {
      const values = new Set();
      for (const row of rows) {
        const rawValue = resolveFieldRawValue(row, totalConfig.key);
        const normalizedValue = serializeForComparison(rawValue);
        if (normalizedValue) {
          values.add(normalizedValue);
        }
      }
      return values.size;
    }
    case TOTAL_TYPE.sum:
      return rows.reduce((sum, row) => {
        const value = toNumber(resolveFieldRawValue(row, totalConfig.key));
        return sum + (value || 0);
      }, 0);
    default:
      return rows.length;
  }
}

function formatRowForOutput(row, columns) {
  const result = {};
  for (const column of columns) {
    result[column.key] = formatFieldValue(
        column.key,
        resolveFieldRawValue(row, column.key),
    );
  }
  return result;
}

function applyFilters(rows, filters) {
  if (!Array.isArray(filters) || filters.length === 0) {
    return rows;
  }

  return rows.filter((row) =>
    filters.every((filter) => rowMatchesFilter(row, filter)));
}

function rowMatchesFilter(row, filter) {
  const rawValue = resolveFieldRawValue(row, filter.key);

  switch (filter.operator) {
    case FILTER_OPERATOR.eq:
      return areEquivalent(rawValue, filter.value);
    case FILTER_OPERATOR.neq:
      return !areEquivalent(rawValue, filter.value);
    case FILTER_OPERATOR.in:
      return ensureArray(filter.values)
          .some((item) => areEquivalent(rawValue, item));
    case FILTER_OPERATOR.contains:
      return containsValue(rawValue, filter.value);
    case FILTER_OPERATOR.exists: {
      const shouldExist = filter.value !== false;
      return shouldExist ? !isValueEmpty(rawValue) : isValueEmpty(rawValue);
    }
    case FILTER_OPERATOR.dateBetween: {
      const currentDate = toDate(rawValue);
      const start = toDate(filter.start);
      const end = toDate(filter.end);
      if (!currentDate || !start || !end) {
        return false;
      }
      return currentDate >= start && currentDate <= end;
    }
    case FILTER_OPERATOR.lteNow: {
      const currentDate = toDate(rawValue);
      return currentDate instanceof Date && currentDate.getTime() <= Date.now();
    }
    default:
      return true;
  }
}

function applySort(rows, sortConfig) {
  if (!Array.isArray(sortConfig) || sortConfig.length === 0) {
    return [...rows];
  }

  return [...rows].sort((left, right) => {
    for (const sortItem of sortConfig) {
      const leftValue = normalizeSortableValue(
          resolveFieldRawValue(left, sortItem.key),
      );
      const rightValue = normalizeSortableValue(
          resolveFieldRawValue(right, sortItem.key),
      );

      if (leftValue < rightValue) {
        return sortItem.dir === SORT_DIRECTION.desc ? 1 : -1;
      }
      if (leftValue > rightValue) {
        return sortItem.dir === SORT_DIRECTION.desc ? -1 : 1;
      }
    }

    return 0;
  });
}

function resolveFieldRawValue(row, key) {
  if (FIELD_CATALOG[key]) {
    return FIELD_CATALOG[key].getRawValue(row);
  }

  if (isCustomFieldKey(key)) {
    const customCode = key.slice("custom.".length);
    return resolveCustomFieldValue(row.lesson, customCode);
  }

  return null;
}

function resolveCustomFieldValue(lesson, customCode) {
  const values = lesson && typeof lesson === "object" ?
    lesson.customFieldValues :
    null;
  if (!values || typeof values !== "object") {
    return null;
  }

  const rawValue = values[customCode];
  if (!rawValue || typeof rawValue !== "object") {
    return null;
  }

  const normalizedType = asString(rawValue.type) || "string";
  if (normalizedType === "date") {
    return toDate(rawValue.value);
  }
  if (normalizedType === "dateRange") {
    return formatDateRange({
      start: toDate(rawValue.start),
      end: toDate(rawValue.end),
    });
  }

  return asString(rawValue.value);
}

function formatFieldValue(key, rawValue) {
  if (rawValue == null) {
    return "";
  }

  if (Array.isArray(rawValue)) {
    return rawValue.map((item) => asString(item)).filter(Boolean).join(", ");
  }

  if (rawValue instanceof Date) {
    const descriptor = FIELD_CATALOG[key];
    if (descriptor && descriptor.valueType === "datetime") {
      return formatDateTime(rawValue);
    }
    return formatDate(rawValue);
  }

  if (typeof rawValue === "number") {
    return String(rawValue);
  }

  return asString(rawValue);
}

async function buildGroupMemberLookup({db, groupId}) {
  const groupDoc = await db.collection("allowed_users").doc(groupId).get();
  if (!groupDoc.exists) {
    return {byAssignmentId: new Map(), byEmail: new Map()};
  }

  const members = groupDoc.get("members") || {};
  return buildGroupMemberLookupFromData({
    members,
    loadUserByUid: async (uid) => {
      const snapshot = await db.collection("users").doc(uid).get();
      return snapshot.exists ? {id: snapshot.id, ...snapshot.data()} : null;
    },
    loadUserByEmail: async (email) => {
      const snapshot = await db.collection("users")
          .where("email", "==", email)
          .limit(1)
          .get();
      if (snapshot.empty) {
        return null;
      }
      const doc = snapshot.docs[0];
      return {id: doc.id, ...doc.data()};
    },
  });
}

async function buildGroupMemberLookupFromData({
  members,
  loadUserByUid,
  loadUserByEmail,
}) {
  const byAssignmentId = new Map();
  const byEmail = new Map();

  for (const [email, rawValue] of Object.entries(members || {})) {
    const normalizedEmail = asString(email).toLowerCase();
    if (!normalizedEmail) {
      continue;
    }

    const baseMember = buildFallbackMember({
      email: normalizedEmail,
      rawValue,
    });

    let resolvedUser = null;
    const memberUid = rawValue && typeof rawValue === "object" ?
      asString(rawValue.uid) :
      "";
    if (memberUid) {
      resolvedUser = await loadUserByUid(memberUid);
    }
    if (!resolvedUser) {
      resolvedUser = await loadUserByEmail(normalizedEmail);
    }

    const mergedMember = mergeMemberData(baseMember, resolvedUser);
    byEmail.set(normalizedEmail, mergedMember);
    if (mergedMember.uid) {
      byAssignmentId.set(mergedMember.uid, mergedMember);
    }
    byAssignmentId.set(normalizedEmail, mergedMember);
  }

  return {byAssignmentId, byEmail};
}

function resolveMemberForAssignment({assignmentId, fallbackName, memberLookup}) {
  const normalizedAssignmentId = asString(assignmentId);
  const normalizedEmail = normalizedAssignmentId.includes("@") ?
    normalizedAssignmentId.toLowerCase() :
    "";

  let member = null;
  if (normalizedAssignmentId) {
    member = memberLookup.byAssignmentId.get(normalizedAssignmentId) || null;
  }
  if (!member && normalizedEmail) {
    member = memberLookup.byEmail.get(normalizedEmail) || null;
  }

  if (member) {
    return member;
  }

  return {
    uid: normalizedAssignmentId && !normalizedAssignmentId.includes("@") ?
      normalizedAssignmentId :
      "",
    email: normalizedEmail,
    fullName: asString(fallbackName),
    role: "",
    rank: "",
    position: "",
    phone: "",
  };
}

function buildFallbackMember({email, rawValue}) {
  const rawObject = rawValue && typeof rawValue === "object" ? rawValue : {};
  const firstName = asString(rawObject.firstName);
  const lastName = asString(rawObject.lastName);
  const fallbackFullName = `${firstName} ${lastName}`.trim() ||
    email.split("@")[0];

  return {
    uid: asString(rawObject.uid),
    email,
    fullName: fallbackFullName,
    role: extractMemberRole(rawValue),
    rank: asString(rawObject.rank),
    position: asString(rawObject.position),
    phone: asString(rawObject.phone),
  };
}

function mergeMemberData(baseMember, resolvedUser) {
  if (!resolvedUser || typeof resolvedUser !== "object") {
    return baseMember;
  }

  const firstName = asString(resolvedUser.firstName);
  const lastName = asString(resolvedUser.lastName);
  const fullName = asString(resolvedUser.fullName) ||
    `${firstName} ${lastName}`.trim() ||
    baseMember.fullName;

  return {
    uid: asString(resolvedUser.id) || baseMember.uid,
    email: asString(resolvedUser.email).toLowerCase() || baseMember.email,
    fullName,
    role: baseMember.role,
    rank: asString(resolvedUser.rank) || baseMember.rank,
    position: asString(resolvedUser.position) || baseMember.position,
    phone: asString(resolvedUser.phone) || baseMember.phone,
  };
}

async function getGroupMembership({db, groupId, auth, functionsV1}) {
  const groupDoc = await db.collection("allowed_users").doc(groupId).get();
  if (!groupDoc.exists) {
    throw new functionsV1.https.HttpsError(
        "permission-denied",
        "Група не знайдена або доступ заборонено.",
    );
  }

  const members = groupDoc.get("members") || {};
  const email = asString(auth.token && auth.token.email).toLowerCase();
  const memberValue = email ? members[email] : null;
  if (!memberValue) {
    throw new functionsV1.https.HttpsError(
        "permission-denied",
        "Користувач не входить до цієї групи.",
    );
  }

  return {
    role: extractMemberRole(memberValue) || "viewer",
    groupName: asString(groupDoc.get("name")) || groupId,
  };
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

async function getReportTemplateDoc({db, groupId, templateId, functionsV1}) {
  const snapshot = await db.collection("groups")
      .doc(groupId)
      .collection("report_templates")
      .doc(templateId)
      .get();

  if (!snapshot.exists) {
    throw new functionsV1.https.HttpsError(
        "not-found",
        "Шаблон звіту не знайдено.",
    );
  }

  return {id: snapshot.id, ...snapshot.data()};
}

function normalizeCallableRequest(raw, functionsV1) {
  const groupId = asString(raw && raw.groupId);
  const templateId = asString(raw && raw.templateId);
  const useDraft = raw && raw.useDraft === true;
  const startDate = toDate(raw && raw.startDate);
  const endDate = toDate(raw && raw.endDate);

  if (!groupId || !templateId || !startDate || !endDate) {
    throw new functionsV1.https.HttpsError(
        "invalid-argument",
        "Потрібно передати groupId, templateId, startDate та endDate.",
    );
  }
  if (startDate > endDate) {
    throw new functionsV1.https.HttpsError(
        "invalid-argument",
        "Початкова дата не може бути пізнішою за кінцеву.",
    );
  }
  if ((endDate.getTime() - startDate.getTime()) >
      MAX_REPORT_RANGE_DAYS * 24 * 60 * 60 * 1000) {
    throw new functionsV1.https.HttpsError(
        "invalid-argument",
        "Максимальний період звіту для v1 становить 365 днів.",
    );
  }

  return {
    groupId,
    templateId,
    useDraft,
    startDate,
    endDate,
  };
}

function requireAuth(context, functionsV1) {
  if (!context || !context.auth || !context.auth.uid) {
    throw new functionsV1.https.HttpsError(
        "unauthenticated",
        "Потрібна авторизація.",
    );
  }
  return context.auth;
}

function ensureAdmin(role, functionsV1) {
  if (role !== "admin") {
    throw new functionsV1.https.HttpsError(
        "permission-denied",
        "Дія доступна лише адміністраторам групи.",
    );
  }
}

function selectTemplateConfig({template, useDraft, role, functionsV1}) {
  const normalizedTemplate = normalizeTemplateDocument(template);

  if (useDraft) {
    if (role !== "admin") {
      throw new functionsV1.https.HttpsError(
          "permission-denied",
          "Чернетка доступна лише адміністраторам.",
      );
    }
    return normalizeTemplateConfig(normalizedTemplate.draftConfig);
  }

  if (!normalizedTemplate.activeConfig) {
    throw new functionsV1.https.HttpsError(
        "failed-precondition",
        "Активна конфігурація звіту ще не опублікована.",
    );
  }

  return normalizeTemplateConfig(normalizedTemplate.activeConfig);
}

function normalizeTemplateDocument(raw) {
  const allowedRoles = normalizeAllowedRoles(raw.allowedRoles);

  return {
    id: asString(raw.id),
    name: asString(raw.name),
    description: asString(raw.description),
    status: asString(raw.status) === TEMPLATE_STATUS.active ?
      TEMPLATE_STATUS.active :
      TEMPLATE_STATUS.draft,
    allowedRoles,
    draftConfig: raw.draftConfig || null,
    activeConfig: raw.activeConfig || null,
    draftVersion: Math.max(1, toInteger(raw.draftVersion) || 1),
    activeVersion: Math.max(0, toInteger(raw.activeVersion) || 0),
  };
}

function normalizeAllowedRoles(rawRoles) {
  const normalizedRoles = ensureArray(rawRoles)
      .map((role) => asString(role).toLowerCase())
      .filter((role) => Object.prototype.hasOwnProperty.call(ROLE_HIERARCHY, role));

  return normalizedRoles.length > 0 ? normalizedRoles : DEFAULT_ALLOWED_ROLES;
}

function canRoleAccessTemplate(role, allowedRoles) {
  const normalizedRole = asString(role).toLowerCase();
  const userLevel = ROLE_HIERARCHY[normalizedRole] || 0;
  const minRequiredLevel = normalizeAllowedRoles(allowedRoles)
      .map((item) => ROLE_HIERARCHY[item] || 0)
      .reduce((min, current) => Math.min(min, current), Infinity);

  return userLevel >= minRequiredLevel;
}

function normalizeTemplateConfig(rawConfig) {
  if (!rawConfig || typeof rawConfig !== "object") {
    throw new Error("Конфігурація шаблону відсутня.");
  }

  const source = asString(rawConfig.source) || TEMPLATE_SOURCE.lessons;
  const periodField = asString(rawConfig.periodField) ||
    TEMPLATE_PERIOD_FIELD.startTime;
  const rowMode = asString(rawConfig.rowMode) || TEMPLATE_ROW_MODE.lesson;
  const filters = ensureArray(rawConfig.filters).map(normalizeFilterConfig);
  const columns = ensureArray(rawConfig.columns).map(normalizeColumnConfig);
  const groupBy = ensureArray(rawConfig.groupBy)
      .map((item) => asString(item))
      .filter(Boolean);
  const sort = ensureArray(rawConfig.sort).map(normalizeSortConfig);
  const totals = ensureArray(rawConfig.totals).map(normalizeTotalConfig);
  const sheet = normalizeSheetConfig(rawConfig.sheet);

  if (source !== TEMPLATE_SOURCE.lessons) {
    throw new Error("v1 підтримує тільки lessons як джерело.");
  }
  if (!Object.values(TEMPLATE_PERIOD_FIELD).includes(periodField)) {
    throw new Error("Непідтримуване поле періоду.");
  }
  if (!Object.values(TEMPLATE_ROW_MODE).includes(rowMode)) {
    throw new Error("Непідтримуваний режим рядків.");
  }
  if (columns.length === 0) {
    throw new Error("Шаблон має містити хоча б одну колонку.");
  }

  for (const key of groupBy) {
    validateFieldKey(key);
  }

  return {
    source,
    periodField,
    rowMode,
    filters,
    columns,
    groupBy,
    sort,
    totals,
    sheet,
  };
}

function normalizeColumnConfig(raw) {
  const key = asString(raw && raw.key);
  const label = asString(raw && raw.label) || getFieldLabel(key);

  validateFieldKey(key);
  if (!label) {
    throw new Error(`Не вдалося визначити label для колонки "${key}".`);
  }

  return {key, label};
}

function normalizeFilterConfig(raw) {
  const key = asString(raw && raw.key);
  const operator = asString(raw && raw.operator);

  validateFieldKey(key);
  if (!Object.values(FILTER_OPERATOR).includes(operator)) {
    throw new Error(`Оператор "${operator}" не підтримується.`);
  }

  const normalized = {key, operator};
  if (Object.prototype.hasOwnProperty.call(raw || {}, "value")) {
    normalized.value = raw.value;
  }
  if (Object.prototype.hasOwnProperty.call(raw || {}, "values")) {
    normalized.values = ensureArray(raw.values);
  }
  if (Object.prototype.hasOwnProperty.call(raw || {}, "start")) {
    normalized.start = raw.start;
  }
  if (Object.prototype.hasOwnProperty.call(raw || {}, "end")) {
    normalized.end = raw.end;
  }

  return normalized;
}

function normalizeSortConfig(raw) {
  const key = asString(raw && raw.key);
  const dir = asString(raw && raw.dir) || SORT_DIRECTION.asc;

  validateFieldKey(key);
  if (!Object.values(SORT_DIRECTION).includes(dir)) {
    throw new Error(`Напрям сортування "${dir}" не підтримується.`);
  }

  return {key, dir};
}

function normalizeTotalConfig(raw) {
  const type = asString(raw && raw.type);
  const key = asString(raw && raw.key);
  const label = asString(raw && raw.label);

  if (!Object.values(TOTAL_TYPE).includes(type)) {
    throw new Error(`Агрегат "${type}" не підтримується.`);
  }

  if ([TOTAL_TYPE.countDistinct, TOTAL_TYPE.sum].includes(type)) {
    validateFieldKey(key);
  }

  return {type, key, label};
}

function normalizeSheetConfig(raw) {
  const sheet = raw && typeof raw === "object" ? raw : {};
  const name = asString(sheet.name) || "Звіт";

  return {
    name,
    freezeHeader: sheet.freezeHeader !== false,
    autoWidth: sheet.autoWidth !== false,
  };
}

function validateFieldKey(key) {
  if (!key) {
    throw new Error("Поле шаблону не може бути порожнім.");
  }
  if (FIELD_CATALOG[key]) {
    return;
  }
  if (isCustomFieldKey(key)) {
    const customCode = key.slice("custom.".length);
    if (!customCode) {
      throw new Error("custom.<code> має містити код поля.");
    }
    return;
  }
  throw new Error(`Поле "${key}" не входить до whitelist v1.`);
}

function isCustomFieldKey(key) {
  return asString(key).startsWith("custom.");
}

function getFieldLabel(key) {
  if (FIELD_CATALOG[key]) {
    return FIELD_CATALOG[key].label;
  }
  if (isCustomFieldKey(key)) {
    return key.slice("custom.".length);
  }
  return key;
}

async function buildWorkbookBuffer({
  groupName,
  templateName,
  startDate,
  endDate,
  generatedAt,
  dataset,
}) {
  const workbook = new ExcelJS.Workbook();
  const worksheet = workbook.addWorksheet(
      dataset.sheet.name || templateName || "Звіт",
  );

  const columnCount = dataset.columns.length;
  const mergeEndColumn = Math.max(1, columnCount);
  let currentRow = 1;

  mergeRow(worksheet, currentRow, mergeEndColumn, templateName.toUpperCase());
  styleTitleRow(worksheet.getRow(currentRow));
  currentRow++;

  mergeRow(
      worksheet,
      currentRow,
      mergeEndColumn,
      `за період з ${formatDate(startDate)} по ${formatDate(endDate)}`,
  );
  currentRow++;

  mergeRow(
      worksheet,
      currentRow,
      mergeEndColumn,
      `Група: ${groupName || "Не вибрано"}`,
  );
  currentRow++;

  mergeRow(
      worksheet,
      currentRow,
      mergeEndColumn,
      `Згенеровано: ${formatDateTime(generatedAt)}`,
  );
  worksheet.getRow(currentRow).font = {size: 10, color: {argb: "FF666666"}};
  currentRow += 2;

  writeColumnHeaders({
    worksheet,
    rowNumber: currentRow,
    columns: dataset.columns,
  });
  currentRow++;

  currentRow = writeGroupedData({
    worksheet,
    startRow: currentRow,
    columns: dataset.columns,
    groupedRows: dataset.groupedRows,
  });

  currentRow += 1;
  mergeRow(worksheet, currentRow, mergeEndColumn, "ЗАГАЛЬНА СТАТИСТИКА");
  const totalsHeaderRow = worksheet.getRow(currentRow);
  totalsHeaderRow.font = {bold: true, color: {argb: "FFFFFFFF"}};
  totalsHeaderRow.fill = {
    type: "pattern",
    pattern: "solid",
    fgColor: {argb: "FF4472C4"},
  };
  currentRow++;

  for (const total of dataset.totals) {
    worksheet.getCell(currentRow, 1).value = total.label;
    worksheet.getCell(currentRow, 2).value = total.value;
    currentRow++;
  }

  if (dataset.sheet.freezeHeader) {
    worksheet.views = [{state: "frozen", ySplit: 6}];
  }
  if (dataset.sheet.autoWidth) {
    autoFitColumns(worksheet, dataset.columns.length);
  }

  return workbook.xlsx.writeBuffer();
}

function writeGroupedData({worksheet, startRow, columns, groupedRows}) {
  let currentRow = startRow;

  for (const group of groupedRows) {
    if (group.label) {
      mergeRow(worksheet, currentRow, columns.length, group.label);
      const row = worksheet.getRow(currentRow);
      row.font = {bold: true};
      row.fill = {
        type: "pattern",
        pattern: "solid",
        fgColor: {argb: "FFD3D3D3"},
      };
      currentRow++;
    }

    if (Array.isArray(group.children) && group.children.length > 0 &&
        group.children[0].label) {
      currentRow = writeGroupedData({
        worksheet,
        startRow: currentRow,
        columns,
        groupedRows: group.children,
      });
    } else {
      for (const row of group.rows || []) {
        writeDataRow({
          worksheet,
          rowNumber: currentRow,
          columns,
          row,
        });
        currentRow++;
      }
    }

    if (group.label) {
      mergeRow(
          worksheet,
          currentRow,
          columns.length,
          `Всього записів: ${(group.rows || []).length}`,
      );
      const summaryRow = worksheet.getRow(currentRow);
      summaryRow.font = {bold: true};
      summaryRow.fill = {
        type: "pattern",
        pattern: "solid",
        fgColor: {argb: "FFF0F0F0"},
      };
      currentRow += 2;
    }
  }

  return currentRow;
}

function writeColumnHeaders({worksheet, rowNumber, columns}) {
  for (let index = 0; index < columns.length; index++) {
    const cell = worksheet.getCell(rowNumber, index + 1);
    cell.value = columns[index].label;
    cell.font = {bold: true};
    cell.alignment = {horizontal: "center", vertical: "middle"};
    cell.fill = {
      type: "pattern",
      pattern: "solid",
      fgColor: {argb: "FFE6E6FA"},
    };
  }
}

function writeDataRow({worksheet, rowNumber, columns, row}) {
  for (let index = 0; index < columns.length; index++) {
    const column = columns[index];
    const cell = worksheet.getCell(rowNumber, index + 1);
    cell.value = formatFieldValue(
        column.key,
        resolveFieldRawValue(row, column.key),
    );
  }
}

function mergeRow(worksheet, rowNumber, mergeEndColumn, value) {
  worksheet.getCell(rowNumber, 1).value = value;
  if (mergeEndColumn > 1) {
    worksheet.mergeCells(rowNumber, 1, rowNumber, mergeEndColumn);
  }
}

function styleTitleRow(row) {
  row.font = {size: 16, bold: true};
  row.alignment = {horizontal: "center"};
}

function autoFitColumns(worksheet, columnCount) {
  for (let index = 1; index <= columnCount; index++) {
    let maxLength = 12;
    worksheet.getColumn(index).eachCell({includeEmpty: true}, (cell) => {
      const value = cell.value == null ? "" : String(cell.value);
      maxLength = Math.max(maxLength, value.length + 2);
    });
    worksheet.getColumn(index).width = Math.min(maxLength, 40);
  }
}

function buildReportFileName({templateName, startDate, endDate}) {
  const normalizedName = sanitizeFileName(templateName || "Звіт");
  return `${normalizedName}_${formatDate(startDate)}-${formatDate(endDate)}.xlsx`;
}

function sanitizeFileName(value) {
  return asString(value)
      .replace(/[\\/:*?"<>|]+/g, "")
      .replace(/\s+/g, "_");
}

function defaultTotalLabel(totalConfig) {
  switch (totalConfig.type) {
    case TOTAL_TYPE.countDistinct:
      return `Унікальних: ${getFieldLabel(totalConfig.key)}`;
    case TOTAL_TYPE.sum:
      return `Сума: ${getFieldLabel(totalConfig.key)}`;
    case TOTAL_TYPE.count:
    default:
      return "Всього записів";
  }
}

function extractLessonAssignments(lesson) {
  const instructorIds = toStringArray(lesson.instructorIds);
  const instructorNames = toStringArray(lesson.instructorNames);
  const assignments = [];
  const seen = new Set();

  for (let index = 0; index < instructorIds.length; index++) {
    const assignmentId = instructorIds[index];
    const name = instructorNames[index] || asString(lesson.instructorName);
    const signature = `${assignmentId}::${name}`;
    if (seen.has(signature)) {
      continue;
    }

    assignments.push({assignmentId, name});
    seen.add(signature);
  }

  const primaryId = asString(lesson.instructorId);
  const primaryName = asString(lesson.instructorName);
  if (primaryId || primaryName) {
    const signature = `${primaryId}::${primaryName}`;
    if (!seen.has(signature)) {
      assignments.push({assignmentId: primaryId, name: primaryName});
    }
  }

  return assignments;
}

function containsValue(rawValue, expectedValue) {
  const normalizedExpected = asString(expectedValue).toLowerCase();
  if (!normalizedExpected) {
    return false;
  }

  if (Array.isArray(rawValue)) {
    return rawValue.some((item) =>
      asString(item).toLowerCase().includes(normalizedExpected));
  }

  return asString(rawValue).toLowerCase().includes(normalizedExpected);
}

function areEquivalent(left, right) {
  return serializeForComparison(left) === serializeForComparison(right);
}

function serializeForComparison(value) {
  if (value == null) {
    return "";
  }
  if (value instanceof Date) {
    return value.toISOString();
  }
  if (Array.isArray(value)) {
    return value.map((item) => serializeForComparison(item)).join("|");
  }
  if (typeof value === "object") {
    return JSON.stringify(value);
  }
  return String(value).trim().toLowerCase();
}

function normalizeSortableValue(value) {
  if (value instanceof Date) {
    return value.getTime();
  }
  if (typeof value === "number") {
    return value;
  }
  if (Array.isArray(value)) {
    return value.map((item) => asString(item)).join("|");
  }
  return asString(value).toLowerCase();
}

function isValueEmpty(value) {
  if (value == null) {
    return true;
  }
  if (Array.isArray(value)) {
    return value.length === 0;
  }
  return asString(value) === "";
}

function formatDateRange({start, end}) {
  if (!start && !end) {
    return "";
  }
  const startText = start ? formatDate(start) : "?";
  const endText = end ? formatDate(end) : "?";
  return `${startText} - ${endText}`;
}

function formatDate(date) {
  const currentDate = toDate(date);
  if (!currentDate) {
    return "";
  }

  const day = String(currentDate.getDate()).padStart(2, "0");
  const month = String(currentDate.getMonth() + 1).padStart(2, "0");
  const year = currentDate.getFullYear();
  return `${day}.${month}.${year}`;
}

function formatDateTime(date) {
  const currentDate = toDate(date);
  if (!currentDate) {
    return "";
  }

  const hours = String(currentDate.getHours()).padStart(2, "0");
  const minutes = String(currentDate.getMinutes()).padStart(2, "0");
  return `${formatDate(currentDate)} ${hours}:${minutes}`;
}

function normalizeFirestoreValue(value, admin) {
  if (value == null) {
    return value;
  }
  if (value instanceof admin.firestore.Timestamp) {
    return value.toDate();
  }
  if (Array.isArray(value)) {
    return value.map((item) => normalizeFirestoreValue(item, admin));
  }
  if (typeof value === "object") {
    return Object.fromEntries(
        Object.entries(value)
            .map(([key, entryValue]) => [
              key,
              normalizeFirestoreValue(entryValue, admin),
            ]),
    );
  }
  return value;
}

function ensureArray(value) {
  return Array.isArray(value) ? value : [];
}

function toStringArray(value) {
  return ensureArray(value).map((item) => asString(item)).filter(Boolean);
}

function toInteger(value) {
  const parsed = Number.parseInt(value, 10);
  return Number.isNaN(parsed) ? null : parsed;
}

function toNumber(value) {
  if (typeof value === "number") {
    return value;
  }
  const parsed = Number(value);
  return Number.isNaN(parsed) ? null : parsed;
}

function toDate(value) {
  if (value instanceof Date) {
    return value;
  }
  if (!value) {
    return null;
  }
  if (typeof value.toDate === "function") {
    return value.toDate();
  }
  if (typeof value === "string" || typeof value === "number") {
    const parsed = new Date(value);
    return Number.isNaN(parsed.getTime()) ? null : parsed;
  }
  return null;
}

function asString(value) {
  return value == null ? "" : String(value).trim();
}

module.exports = {
  TEMPLATE_STATUS,
  TEMPLATE_SOURCE,
  TEMPLATE_PERIOD_FIELD,
  TEMPLATE_ROW_MODE,
  FILTER_OPERATOR,
  SORT_DIRECTION,
  TOTAL_TYPE,
  DEFAULT_ALLOWED_ROLES,
  FIELD_CATALOG,
  MAX_REPORT_ROWS,
  XLSX_MIME_TYPE,
  createPreviewHandler,
  createPublishHandler,
  createGenerateHandler,
  __test: {
    normalizeTemplateConfig,
    resolveCustomFieldValue,
    buildReportRows,
    buildGroupMemberLookupFromData,
    buildGroupedRows,
    computeReportTotals,
    canRoleAccessTemplate,
    formatFieldValue,
    applyFilters,
    applySort,
    resolveMemberForAssignment,
    buildReportFileName,
  },
};
