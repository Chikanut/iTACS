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
  calendarGrid: "calendar_grid",
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

    if (config.rowMode === TEMPLATE_ROW_MODE.calendarGrid) {
      const {groups, days, warnings} = await buildCalendarGridDataset({
        db, admin, groupId: request.groupId, config,
        startDate: request.startDate, endDate: request.endDate,
      });
      const UA_WEEKDAYS = ["НД", "ПН", "ВТ", "СР", "ЧТ", "ПТ", "СБ"];
      const columns = [
        {key: "instructor", label: "Інструктор"},
        ...days.slice(0, 10).map((d) => ({
          key: `day_${d.dayNum}`,
          label: `${d.dayNum} ${UA_WEEKDAYS[d.weekdayIdx]}`,
        })),
        {key: "total", label: "Всього"},
      ];
      const mark = asString(config.calendarCellMark) || "З";
      const sampleRows = groups.slice(0, MAX_PREVIEW_ROWS).map((g) => {
        const row = {instructor: g.name, total: String(g.totalLessons)};
        for (const d of days.slice(0, 10)) {
          const count = (g.dayMap.get(d.dayKey) || []).length;
          row[`day_${d.dayNum}`] = count > 0 ? (count === 1 ? mark : `${mark}(${count})`) : "";
        }
        return row;
      });
      return {
        templateId: request.templateId,
        templateName: normalizedTemplate.name,
        columns,
        sampleRows,
        totalRows: groups.length,
        warnings,
      };
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

    if (config.rowMode === TEMPLATE_ROW_MODE.calendarGrid) {
      const {groups, days, warnings} = await buildCalendarGridDataset({
        db, admin, groupId: request.groupId, config,
        startDate: request.startDate, endDate: request.endDate,
      });
      const workbookBuffer = await buildCalendarGridWorkbookBuffer({
        groupName: membership.groupName,
        templateName: normalizedTemplate.name,
        startDate: request.startDate,
        endDate: request.endDate,
        groups, days, config,
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
        warnings,
        totalRows: groups.reduce((s, g) => s + g.totalLessons, 0),
      };
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
  if (rowMode !== TEMPLATE_ROW_MODE.calendarGrid && columns.length === 0) {
    throw new Error("Шаблон має містити хоча б одну колонку.");
  }

  for (const key of groupBy) {
    validateFieldKey(key);
  }

  const calendarNoteFields = ensureArray(rawConfig.calendarNoteFields)
      .map((item) => asString(item).trim())
      .filter(Boolean);
  for (const key of calendarNoteFields) {
    validateFieldKey(key);
  }
  const calendarCellMark = asString(rawConfig.calendarCellMark) || "З";

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
    calendarNoteFields,
    calendarCellMark,
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

// ─────────────────────────────────────────────────────────────────────────────
// CALENDAR GRID  (rowMode: "calendar_grid")
// ─────────────────────────────────────────────────────────────────────────────

async function buildCalendarGridDataset({
  db, admin, groupId, config, startDate, endDate,
}) {
  const lessons = await fetchLessonsForPeriod({
    db, admin, groupId, config, startDate, endDate,
  });

  // Build day list (UTC day boundaries)
  const days = [];
  const cur = new Date(Date.UTC(
      startDate.getUTCFullYear(), startDate.getUTCMonth(), startDate.getUTCDate(),
  ));
  const last = new Date(Date.UTC(
      endDate.getUTCFullYear(), endDate.getUTCMonth(), endDate.getUTCDate(),
  ));
  while (cur <= last) {
    const y = cur.getUTCFullYear();
    const m = String(cur.getUTCMonth() + 1).padStart(2, "0");
    const d = String(cur.getUTCDate()).padStart(2, "0");
    days.push({
      date: new Date(cur),
      dayNum: cur.getUTCDate(),
      weekdayIdx: cur.getUTCDay(),
      isWeekend: cur.getUTCDay() === 0 || cur.getUTCDay() === 6,
      dayKey: `${y}-${m}-${d}`,
    });
    cur.setUTCDate(cur.getUTCDate() + 1);
  }

  // Group lessons by the first groupBy key
  const groupByKey = (config.groupBy && config.groupBy[0]) || "instructor.name";
  const groupMap = new Map();

  function addToGroup(name, lesson, dayKey) {
    if (!groupMap.has(name)) {
      groupMap.set(name, {name, dayMap: new Map(), totalLessons: 0});
    }
    const g = groupMap.get(name);
    if (!g.dayMap.has(dayKey)) g.dayMap.set(dayKey, []);
    g.dayMap.get(dayKey).push(lesson);
    g.totalLessons++;
  }

  for (const lesson of lessons) {
    const lessonDate = toDate(lesson[config.periodField || "startTime"]);
    if (!lessonDate) continue;
    const y = lessonDate.getUTCFullYear();
    const m = String(lessonDate.getUTCMonth() + 1).padStart(2, "0");
    const d = String(lessonDate.getUTCDate()).padStart(2, "0");
    const dayKey = `${y}-${m}-${d}`;

    if (groupByKey === "instructor.name") {
      const names = Array.isArray(lesson.instructorNames) && lesson.instructorNames.length > 0
        ? lesson.instructorNames
        : [asString(lesson.instructorName) || "Без інструктора"];
      for (const name of names) {
        if (name) addToGroup(name, lesson, dayKey);
      }
    } else {
      const descriptor = FIELD_CATALOG[groupByKey];
      const row = {lesson, instructor: {name: ""}, member: {}};
      const rawVal = descriptor ? descriptor.getRawValue(row) : null;
      const groupName = formatFieldValue(groupByKey, rawVal) || "(без значення)";
      addToGroup(groupName, lesson, dayKey);
    }
  }

  const groups = [...groupMap.values()].sort((a, b) =>
    a.name.localeCompare(b.name, "uk"),
  );
  const warnings = groups.length === 0 ? ["Не знайдено занять для вказаного періоду."] : [];
  return {groups, days, warnings};
}

async function buildCalendarGridWorkbookBuffer({
  groupName, templateName, startDate, endDate, groups, days, config,
}) {
  const workbook = new ExcelJS.Workbook();
  const sheetName = (templateName || "Відомість").substring(0, 31);
  const ws = workbook.addWorksheet(sheetName);

  const UA_WEEKDAYS = ["НД", "ПН", "ВТ", "СР", "ЧТ", "ПТ", "СБ"];
  const noteFields = Array.isArray(config.calendarNoteFields) ? config.calendarNoteFields : [];
  const cellMark = asString(config.calendarCellMark) || "З";
  const totalCols = days.length + 2; // col1=name, col2..N+1=days, last=total

  const BLUE_HEADER = "FFD9E1F2";
  const WEEKEND_HEADER = "FFFFCCCC";
  const WEEKEND_EMPTY = "FFFFF5F5";
  const THIN = {style: "thin", color: {argb: "FFB0B0B0"}};
  const cellBorder = {top: THIN, left: THIN, bottom: THIN, right: THIN};

  // ── Meta rows ──
  ws.mergeCells(1, 1, 1, totalCols);
  const r1 = ws.getCell(1, 1);
  r1.value = (templateName || "").toUpperCase();
  r1.font = {bold: true, size: 13};
  r1.alignment = {horizontal: "center"};

  ws.mergeCells(2, 1, 2, totalCols);
  const r2 = ws.getCell(2, 1);
  r2.value = `за період з ${formatDate(startDate)} по ${formatDate(endDate)} • Група: ${groupName || ""}`;
  r2.alignment = {horizontal: "center"};

  ws.mergeCells(3, 1, 3, totalCols);
  const r3 = ws.getCell(3, 1);
  r3.value = `Згенеровано: ${formatDateTime(new Date())}`;
  r3.font = {size: 9, color: {argb: "FF888888"}};
  r3.alignment = {horizontal: "center"};

  // ── Header row ──
  const HDR = 4;
  ws.getRow(HDR).height = 28;

  function styleHeader(cell, bg, isWeekend) {
    cell.font = {bold: true, ...(isWeekend ? {color: {argb: "FFCC0000"}} : {})};
    cell.alignment = {horizontal: "center", vertical: "middle", wrapText: true};
    cell.fill = {type: "pattern", pattern: "solid", fgColor: {argb: bg}};
    cell.border = cellBorder;
  }

  const nameHdr = ws.getCell(HDR, 1);
  nameHdr.value = "Інструктор";
  styleHeader(nameHdr, BLUE_HEADER, false);
  nameHdr.alignment = {horizontal: "left", vertical: "middle"};

  for (let i = 0; i < days.length; i++) {
    const {dayNum, weekdayIdx, isWeekend} = days[i];
    const hdr = ws.getCell(HDR, i + 2);
    hdr.value = `${dayNum}\n${UA_WEEKDAYS[weekdayIdx]}`;
    styleHeader(hdr, isWeekend ? WEEKEND_HEADER : BLUE_HEADER, isWeekend);
  }

  const totalHdr = ws.getCell(HDR, totalCols);
  totalHdr.value = "Всього";
  styleHeader(totalHdr, BLUE_HEADER, false);

  // ── Data rows ──
  for (let r = 0; r < groups.length; r++) {
    const group = groups[r];
    const rowIdx = HDR + 1 + r;
    const rowBg = r % 2 === 0 ? "FFFAFAFA" : "FFFFFFFF";
    ws.getRow(rowIdx).height = 16;

    const nameCell = ws.getCell(rowIdx, 1);
    nameCell.value = group.name;
    nameCell.alignment = {vertical: "middle"};
    nameCell.border = cellBorder;
    nameCell.fill = {type: "pattern", pattern: "solid", fgColor: {argb: rowBg}};

    let total = 0;
    for (let i = 0; i < days.length; i++) {
      const {dayKey, isWeekend} = days[i];
      const cell = ws.getCell(rowIdx, i + 2);
      cell.border = cellBorder;
      const lessonsOnDay = group.dayMap.get(dayKey) || [];

      if (lessonsOnDay.length === 0) {
        cell.fill = {
          type: "pattern", pattern: "solid",
          fgColor: {argb: isWeekend ? WEEKEND_EMPTY : rowBg},
        };
      } else {
        total += lessonsOnDay.length;
        cell.value = lessonsOnDay.length === 1
          ? cellMark
          : `${cellMark}(${lessonsOnDay.length})`;
        cell.alignment = {horizontal: "center", vertical: "middle"};
        cell.font = {bold: true, color: {argb: "FF1F4E79"}};
        cell.fill = {type: "pattern", pattern: "solid", fgColor: {argb: rowBg}};

        if (noteFields.length > 0) {
          const noteText = buildCalendarCellNote({lessonsOnDay, noteFields});
          if (noteText) cell.note = noteText;
        }
      }
    }

    const totCell = ws.getCell(rowIdx, totalCols);
    totCell.value = total || "";
    totCell.alignment = {horizontal: "center", vertical: "middle"};
    totCell.border = cellBorder;
    totCell.fill = {type: "pattern", pattern: "solid", fgColor: {argb: BLUE_HEADER}};
    if (total > 0) totCell.font = {bold: true};
  }

  // ── Column widths ──
  ws.getColumn(1).width = 26;
  for (let i = 0; i < days.length; i++) ws.getColumn(i + 2).width = 4.5;
  ws.getColumn(totalCols).width = 8;

  // ── Freeze: first col + header rows ──
  ws.views = [{state: "frozen", xSplit: 1, ySplit: HDR}];

  return workbook.xlsx.writeBuffer();
}

function buildCalendarCellNote({lessonsOnDay, noteFields}) {
  const parts = [];
  for (let li = 0; li < lessonsOnDay.length; li++) {
    if (li > 0) parts.push("");
    if (lessonsOnDay.length > 1) parts.push(`── Заняття ${li + 1} ──`);
    const lesson = lessonsOnDay[li];
    const row = {lesson, instructor: {name: ""}, member: {}};
    for (const fieldKey of noteFields) {
      const descriptor = FIELD_CATALOG[fieldKey];
      if (descriptor) {
        const rawValue = descriptor.getRawValue(row);
        const formatted = formatFieldValue(fieldKey, rawValue);
        if (formatted) parts.push(`${descriptor.label}: ${formatted}`);
      } else if (isCustomFieldKey(fieldKey)) {
        const code = fieldKey.slice("custom.".length);
        const val = resolveCustomFieldValue(lesson, code);
        if (val) parts.push(val);
      }
    }
  }
  return parts.join("\n");
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

  const day = String(currentDate.getUTCDate()).padStart(2, "0");
  const month = String(currentDate.getUTCMonth() + 1).padStart(2, "0");
  const year = currentDate.getUTCFullYear();
  return `${day}.${month}.${year}`;
}

function formatDateTime(date) {
  const currentDate = toDate(date);
  if (!currentDate) {
    return "";
  }

  const hours = String(currentDate.getUTCHours()).padStart(2, "0");
  const minutes = String(currentDate.getUTCMinutes()).padStart(2, "0");
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
