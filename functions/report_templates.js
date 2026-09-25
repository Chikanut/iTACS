"use strict";
/* eslint-disable require-jsdoc, max-len */

const ExcelJS = require("exceljs");

// Monkey-patch ExcelJS so cell note boxes resize to fit their content.
// VmlShapeXform hardcodes width/height in the VML style string; we replace
// the static factory with one that reads _width/_height from the note model.
try {
  const VmlShapeXform = require("exceljs/lib/xlsx/xform/comment/vml-shape-xform");
  const _origAttrs = VmlShapeXform.V_SHAPE_ATTRIBUTES;
  VmlShapeXform.V_SHAPE_ATTRIBUTES = (model, index) => {
    const attrs = _origAttrs(model, index);
    const note = model && model.note;
    if (note && (note._width || note._height)) {
      attrs.style = attrs.style
          .replace(/width:[^;]+/, `width:${note._width || "97.8pt"}`)
          .replace(/height:[^;]+/, `height:${note._height || "59.1pt"}`);
    }
    return attrs;
  };
} catch (_) { /* ignore if ExcelJS internals change */ }

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
  "lesson.duration": {
    label: "Тривалість (хв.)",
    valueType: "number",
    getRawValue: (row) => {
      const start = toDate(row.lesson.startTime);
      const end = toDate(row.lesson.endTime);
      if (!start || !end) return null;
      return Math.round((end.getTime() - start.getTime()) / 60000);
    },
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
        membersOnly: request.membersOnly,
      });
      const UA_WEEKDAYS = ["НД", "ПН", "ВТ", "СР", "ЧТ", "ПТ", "СБ"];
      const columns = [
        {key: "instructor", label: "ПІБ"},
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
          row[`day_${d.dayNum}`] = count > 0 ? mark : (g.absenceMap.get(d.dayKey) || "");
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
      membersOnly: request.membersOnly,
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
        membersOnly: request.membersOnly,
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
      membersOnly: request.membersOnly,
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
  membersOnly = false,
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
    membersOnly,
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

function buildReportRows({lessons, rowMode, memberLookup, membersOnly = false}) {
  const rows = [];
  const isGroupMember = membersOnly ?
    createGroupMemberMatcher(memberLookup) :
    null;

  for (const lesson of lessons) {
    let assignments = extractLessonAssignments(lesson);
    if (isGroupMember) {
      // Лише учасники групи: запрошених викладачів відкидаємо, а заняття
      // без жодного викладача-учасника не потрапляють у звіт.
      assignments = assignments.filter(isGroupMember);
      if (assignments.length === 0) continue;
    }
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
  const cleanName = splitInstructorName(assignment.name).name;
  const member = resolveMemberForAssignment({
    assignmentId: assignment.assignmentId,
    fallbackName: cleanName,
    memberLookup,
  });

  return {
    lesson,
    instructor: {
      assignmentId: asString(assignment.assignmentId),
      name: cleanName,
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
  const membersOnly = raw && raw.membersOnly === true;
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
    membersOnly,
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
  const calendarOptions = normalizeCalendarOptions(rawConfig.calendarOptions);

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
    calendarOptions,
  };
}

function normalizeCalendarOptions(raw) {
  const source = raw && typeof raw === "object" ? raw : {};
  const noteLabels = {};
  const rawLabels = source.noteLabels && typeof source.noteLabels === "object" ?
    source.noteLabels :
    {};
  for (const [key, label] of Object.entries(rawLabels)) {
    const normalizedKey = asString(key);
    if (normalizedKey) noteLabels[normalizedKey] = asString(label);
  }
  return {
    title: asString(source.title),
    subtitle: asString(source.subtitle),
    noteLabels,
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

const CALENDAR_TIME_ZONE = "Europe/Kyiv";

const UA_MONTHS_NOMINATIVE = [
  "січень", "лютий", "березень", "квітень", "травень", "червень",
  "липень", "серпень", "вересень", "жовтень", "листопад", "грудень",
];

// instructor_absences.type -> код у клітинці відомості
const CALENDAR_ABSENCE_CODES = {
  sick_leave: "Х",
  vacation: "В",
  business_trip: "ВД",
  duty: "Н",
};

const CALENDAR_IGNORED_ABSENCE_STATUSES = new Set(["cancelled", "pending"]);

// Порядок від молодшого до старшого — використовується для сортування рядків.
const CALENDAR_RANK_ORDER = [
  "солдат", "старший солдат", "молодший сержант", "сержант",
  "старший сержант", "головний сержант", "штаб-сержант", "майстер-сержант",
  "перший сержант", "головний майстер-сержант", "молодший лейтенант",
  "лейтенант", "старший лейтенант", "капітан", "майор", "підполковник",
  "полковник", "бригадний генерал", "генерал-майор", "генерал-лейтенант",
  "генерал", "генерал армії україни",
];

const CALENDAR_RANK_ABBREVIATIONS = {
  "солдат": "солдат",
  "старший солдат": "ст. солдат",
  "молодший сержант": "мол. с-нт",
  "сержант": "с-нт",
  "старший сержант": "ст. с-нт",
  "головний сержант": "гол. с-нт",
  "штаб-сержант": "штаб-с-нт",
  "майстер-сержант": "м-с-нт",
  "перший сержант": "перш. с-нт",
  "головний майстер-сержант": "гол. м-с-нт",
  "молодший лейтенант": "мол. л-нт",
  "лейтенант": "л-нт",
  "старший лейтенант": "ст. л-нт",
  "капітан": "капітан",
  "майор": "майор",
  "підполковник": "п/п-к",
  "полковник": "п-к",
};

const CALENDAR_EDUCATION_NOTE = [
  "Офіцери:",
  "25 тис. чи 30 тис. залежно від посади",
  "",
  "Сержанти:",
  "0 грн. - не мають освіту, яка відповідає вимогам на 15 тис.",
  "15 тис. грн. - мають базовий рівень підготовки сержанта (суміщена підготовка)",
  "20 тис. грн. - мають базовий рівень підготовки сержанта та базовий рівень інструктора",
  "30 тис. грн. - мають середній рівень підготовки сержанта та підвищений рівень інструктора",
].join("\n");

const NAME_EMAIL_SUFFIX_RE = /\s*\(\s*([^()\s]+@[^()\s]+)\s*\)\s*$/;

let calendarDayFormatter = null;

function toCalendarDayKey(date) {
  if (!calendarDayFormatter) {
    const options = {year: "numeric", month: "2-digit", day: "2-digit"};
    try {
      calendarDayFormatter = new Intl.DateTimeFormat("en-CA", {
        ...options, timeZone: CALENDAR_TIME_ZONE,
      });
    } catch (_) {
      calendarDayFormatter = new Intl.DateTimeFormat("en-CA", {
        ...options, timeZone: "Europe/Kiev",
      });
    }
  }
  const parts = calendarDayFormatter.formatToParts(date);
  const pick = (type) => (parts.find((p) => p.type === type) || {}).value;
  return `${pick("year")}-${pick("month")}-${pick("day")}`;
}

// "Ім'я Прізвище (mail@x.com)" -> {name: "Ім'я Прізвище", email: "mail@x.com"}
function splitInstructorName(rawName) {
  const value = asString(rawName);
  const match = value.match(NAME_EMAIL_SUFFIX_RE);
  if (!match) return {name: value, email: ""};
  return {
    name: value.slice(0, match.index).trim(),
    email: match[1].toLowerCase(),
  };
}

// Ключ імені, нечутливий до регістру та порядку слів.
function normalizePersonNameKey(name) {
  return asString(name)
      .toLowerCase()
      .replace(/[’`ʼ]/g, "'")
      .split(/\s+/)
      .filter(Boolean)
      .sort()
      .join(" ");
}

function buildCalendarDays(startDate, endDate) {
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
      isSunday: cur.getUTCDay() === 0,
      dayKey: `${y}-${m}-${d}`,
      headerLabel: `${d}.${m}.`,
    });
    cur.setUTCDate(cur.getUTCDate() + 1);
  }
  return days;
}

async function fetchPersonnelProfiles({db, groupId}) {
  const byUid = new Map();
  const byEmail = new Map();
  try {
    const snapshot = await db.collection("personnel_profiles")
        .doc(groupId)
        .collection("members")
        .get();
    for (const doc of snapshot.docs) {
      const data = doc.data() || {};
      const profile = {uid: asString(data.uid) || doc.id, ...data};
      byUid.set(doc.id, profile);
      if (profile.uid) byUid.set(profile.uid, profile);
      const email = asString(data.email).toLowerCase();
      if (email) byEmail.set(email, profile);
    }
  } catch (error) {
    console.warn("calendar_grid: не вдалося завантажити анкети", error);
  }
  return {byUid, byEmail};
}

async function fetchAbsencesForPeriod({db, admin, groupId, startDate, endDate}) {
  try {
    // Запас у добу з обох боків — межі періоду приходять без часового поясу.
    const from = new Date(startDate.getTime() - 24 * 60 * 60 * 1000);
    const to = new Date(endDate.getTime() + 24 * 60 * 60 * 1000);
    const snapshot = await db.collection("instructor_absences")
        .doc(groupId)
        .collection("items")
        .where("endDate", ">=", admin.firestore.Timestamp.fromDate(from))
        .get();
    return snapshot.docs
        .map((doc) => ({id: doc.id, ...normalizeFirestoreValue(doc.data(), admin)}))
        .filter((absence) => {
          const start = toDate(absence.startDate);
          return start && start <= to &&
            !CALENDAR_IGNORED_ABSENCE_STATUSES.has(asString(absence.status));
        });
  } catch (error) {
    console.warn("calendar_grid: не вдалося завантажити відсутності", error);
    return [];
  }
}

// Зводить усі варіанти посилання на людину (uid, email, "Ім'я",
// "Ім'я (email)") до одного ключа, щоб у відомості не було дублів.
function createPersonResolver({memberLookup, profiles}) {
  const membersByName = new Map();
  const seenMembers = new Set();
  for (const member of memberLookup.byEmail.values()) {
    if (seenMembers.has(member)) continue;
    seenMembers.add(member);
    const nameKey = normalizePersonNameKey(member.fullName);
    if (nameKey && !membersByName.has(nameKey)) membersByName.set(nameKey, member);
    const profile = findProfileForMember(member, profiles);
    if (profile) {
      const profileKey = normalizePersonNameKey(
          `${asString(profile.firstName)} ${asString(profile.lastName)}`,
      );
      if (profileKey && !membersByName.has(profileKey)) {
        membersByName.set(profileKey, member);
      }
    }
  }
  const aliasByName = new Map();
  const memberByKey = new Map();

  return function resolvePerson({assignmentId, name, email}) {
    const id = asString(assignmentId);
    const split = splitInstructorName(name);
    const candidateEmail = asString(email).toLowerCase() || split.email ||
      (id.includes("@") ? id.toLowerCase() : "");
    const nameKey = normalizePersonNameKey(split.name);

    let member = null;
    if (id) member = memberLookup.byAssignmentId.get(id) || null;
    if (!member && candidateEmail) {
      member = memberLookup.byEmail.get(candidateEmail) || null;
    }
    if (!member && nameKey) member = membersByName.get(nameKey) || null;

    let key;
    if (member) {
      key = `member:${member.email || member.uid}`;
    } else if (candidateEmail || id) {
      key = `id:${candidateEmail || id.toLowerCase()}`;
    } else if (nameKey) {
      key = aliasByName.get(nameKey) || `name:${nameKey}`;
      member = memberByKey.get(key) || null;
    } else {
      return null;
    }
    if (member) memberByKey.set(key, member);
    if (nameKey && !aliasByName.has(nameKey)) aliasByName.set(nameKey, key);

    return {key, member, fallbackName: split.name || candidateEmail || id};
  };
}

// Повертає предикат: чи є викладач (assignment) учасником групи.
function createGroupMemberMatcher(memberLookup) {
  const resolvePerson = createPersonResolver({
    memberLookup,
    profiles: {byUid: new Map(), byEmail: new Map()},
  });
  return (assignment) => {
    const identity = resolvePerson(assignment);
    return Boolean(identity && identity.member);
  };
}

function findProfileForMember(member, profiles) {
  if (!member) return null;
  return (member.uid && profiles.byUid.get(member.uid)) ||
    (member.email && profiles.byEmail.get(member.email)) ||
    null;
}

function buildPersonRowInfo({member, fallbackName, profiles}) {
  const profile = findProfileForMember(member, profiles);
  const lastName = asString(profile && profile.lastName);
  const firstName = asString(profile && profile.firstName);
  const patronymic = asString(profile && profile.patronymic);

  let fullName = "";
  if (lastName || firstName) {
    fullName = [lastName.toUpperCase(), firstName, patronymic]
        .filter(Boolean)
        .join(" ");
  }
  if (!fullName) fullName = asString(member && member.fullName) || fallbackName;

  const rawRank = asString(profile && profile.rank) || asString(member && member.rank);
  const position = asString(profile && profile.position) ||
    asString(member && member.position);

  return {
    fullName,
    sortName: lastName || fullName,
    position,
    rank: formatRankShort(rawRank),
    rankWeight: CALENDAR_RANK_ORDER.indexOf(rawRank.toLowerCase()),
  };
}

function formatRankShort(rank) {
  const value = asString(rank);
  if (!value) return "";
  return CALENDAR_RANK_ABBREVIATIONS[value.toLowerCase()] || value.toLowerCase();
}

async function buildCalendarGridDataset({
  db, admin, groupId, config, startDate, endDate, membersOnly = false,
}) {
  const groupByKey = (config.groupBy && config.groupBy[0]) || "instructor.name";
  const byPerson = groupByKey === "instructor.name";

  const [lessons, memberLookup, profiles, absences] = await Promise.all([
    fetchLessonsForPeriod({db, admin, groupId, config, startDate, endDate}),
    byPerson || membersOnly ? buildGroupMemberLookup({db, groupId}) :
      {byAssignmentId: new Map(), byEmail: new Map()},
    byPerson ? fetchPersonnelProfiles({db, groupId}) :
      {byUid: new Map(), byEmail: new Map()},
    byPerson ? fetchAbsencesForPeriod({db, admin, groupId, startDate, endDate}) : [],
  ]);

  const days = buildCalendarDays(startDate, endDate);
  const dayKeys = new Set(days.map((d) => d.dayKey));
  const resolvePerson = createPersonResolver({memberLookup, profiles});
  const groupMap = new Map();
  const warnings = [];
  let lessonsWithoutInstructor = 0;
  let lessonsWithoutMembers = 0;
  const isGroupMember = createGroupMemberMatcher(memberLookup);

  function ensureGroup(key, info) {
    if (!groupMap.has(key)) {
      groupMap.set(key, {
        key,
        name: info.fullName,
        ...info,
        dayMap: new Map(),
        absenceMap: new Map(),
        lessonIds: new Set(),
        totalLessons: 0,
      });
    }
    return groupMap.get(key);
  }

  function ensurePersonGroup(identity) {
    return ensureGroup(identity.key, buildPersonRowInfo({
      member: identity.member,
      fallbackName: identity.fallbackName,
      profiles,
    }));
  }

  function addLesson(group, lesson, dayKey) {
    const lessonId = lesson.id || `${dayKey}:${group.lessonIds.size}`;
    if (group.lessonIds.has(lessonId)) return;
    group.lessonIds.add(lessonId);
    if (!group.dayMap.has(dayKey)) group.dayMap.set(dayKey, []);
    group.dayMap.get(dayKey).push(lesson);
    group.totalLessons++;
  }

  if (byPerson) {
    // Спершу реєструємо записи з id/email, щоб "Ім'я" без id потім
    // приєдналося до того ж рядка незалежно від порядку занять.
    for (const lesson of lessons) {
      for (const person of extractLessonAssignments(lesson)) {
        if (person.assignmentId || splitInstructorName(person.name).email) {
          resolvePerson(person);
        }
      }
    }
  }

  for (const lesson of lessons) {
    const lessonDate = toDate(lesson[config.periodField || "startTime"]);
    if (!lessonDate) continue;
    const dayKey = toCalendarDayKey(lessonDate);
    if (!dayKeys.has(dayKey)) continue;

    if (byPerson) {
      const people = [
        ...extractLessonAssignments(lesson),
        ...toStringArray(lesson.externalInstructorNames)
            .map((name) => ({assignmentId: "", name})),
      ];
      let added = false;
      for (const person of people) {
        const identity = resolvePerson(person);
        if (!identity) continue;
        if (membersOnly && !identity.member) continue;
        addLesson(ensurePersonGroup(identity), lesson, dayKey);
        added = true;
      }
      if (!added) {
        if (membersOnly && people.length > 0) {
          lessonsWithoutMembers++;
        } else {
          lessonsWithoutInstructor++;
        }
      }
    } else {
      if (membersOnly &&
          !extractLessonAssignments(lesson).some(isGroupMember)) {
        lessonsWithoutMembers++;
        continue;
      }
      const descriptor = FIELD_CATALOG[groupByKey];
      const row = {lesson, instructor: {name: ""}, member: {}};
      const rawVal = descriptor ? descriptor.getRawValue(row) : null;
      const groupName = formatFieldValue(groupByKey, rawVal) || "(без значення)";
      addLesson(ensureGroup(`value:${groupName}`, {
        fullName: groupName, sortName: groupName, position: "", rank: "",
        rankWeight: -1,
      }), lesson, dayKey);
    }
  }

  for (const absence of absences) {
    const code = CALENDAR_ABSENCE_CODES[asString(absence.type)];
    const absStart = toDate(absence.startDate);
    const absEnd = toDate(absence.endDate) || absStart;
    if (!code || !absStart) continue;
    const identity = resolvePerson({
      assignmentId: absence.instructorId,
      name: absence.instructorName,
      email: absence.instructorEmail,
    });
    if (!identity || (membersOnly && !identity.member)) continue;
    const fromKey = toCalendarDayKey(absStart);
    const toKey = toCalendarDayKey(absEnd);
    const coveredDays = days.filter((d) => d.dayKey >= fromKey && d.dayKey <= toKey);
    if (coveredDays.length === 0) continue;
    const group = ensurePersonGroup(identity);
    for (const day of coveredDays) {
      if (!group.absenceMap.has(day.dayKey)) group.absenceMap.set(day.dayKey, code);
    }
  }

  const groups = [...groupMap.values()].sort((a, b) =>
    (b.rankWeight - a.rankWeight) || a.sortName.localeCompare(b.sortName, "uk"),
  );

  if (lessonsWithoutInstructor > 0) {
    warnings.push(`Занять без викладача (не потрапили у відомість): ${lessonsWithoutInstructor}.`);
  }
  if (lessonsWithoutMembers > 0) {
    warnings.push(`Занять лише із запрошеними викладачами (пропущено): ${lessonsWithoutMembers}.`);
  }
  if (groups.length === 0) {
    warnings.push("Не знайдено занять для вказаного періоду.");
  }
  return {groups, days, warnings};
}

function buildCalendarPeriodLabel(startDate, endDate) {
  const sameMonth = startDate.getUTCFullYear() === endDate.getUTCFullYear() &&
    startDate.getUTCMonth() === endDate.getUTCMonth();
  const lastDayOfMonth = new Date(Date.UTC(
      endDate.getUTCFullYear(), endDate.getUTCMonth() + 1, 0,
  )).getUTCDate();
  if (sameMonth && startDate.getUTCDate() === 1 &&
      endDate.getUTCDate() === lastDayOfMonth) {
    return `за ${UA_MONTHS_NOMINATIVE[startDate.getUTCMonth()]} ` +
      `${startDate.getUTCFullYear()} року`;
  }
  return `за період з ${formatDate(startDate)} по ${formatDate(endDate)}`;
}

function columnLetter(index) {
  let result = "";
  let c = index;
  while (c > 0) {
    const rem = (c - 1) % 26;
    result = String.fromCharCode(65 + rem) + result;
    c = Math.floor((c - 1) / 26);
  }
  return result;
}

// Формує книгу за зразком «Відомість проведення занять» (див. docs):
// №, Посада, Військове звання, ПІБ, Освіта, дні періоду, кількість занять.
async function buildCalendarGridWorkbookBuffer({
  groupName, templateName, startDate, endDate, groups, days, config,
}) {
  const workbook = new ExcelJS.Workbook();
  const sheetName = (asString(config.sheet && config.sheet.name) ||
    templateName || "Відомість").substring(0, 31);
  const ws = workbook.addWorksheet(sheetName);

  const options = config.calendarOptions || {};
  const noteFields = Array.isArray(config.calendarNoteFields) ? config.calendarNoteFields : [];
  const noteLabels = options.noteLabels || {};
  const cellMark = asString(config.calendarCellMark) || "З";

  const FONT = "Times New Roman";
  const LESSON_FILL = "FF92D050";
  const SUNDAY_FILL = "FFFF0000";
  const WHITE_FILL = "FFFFFFFF";
  const THIN = {style: "thin"};
  const allBorders = {top: THIN, left: THIN, bottom: THIN, right: THIN};
  const solid = (argb) => ({type: "pattern", pattern: "solid", fgColor: {argb}});

  const FIRST_DAY_COL = 6;
  const lastDayCol = FIRST_DAY_COL + days.length - 1;
  const countCol = lastDayCol + 1;
  const spareCol = countCol + 1;
  const HDR = 4;
  const DATES_ROW = 5;
  const FIRST_DATA_ROW = 6;

  // ── Заголовок ──
  const titleRows = [
    {text: asString(options.title) || "ВІДОМІСТЬ", bold: true},
    {
      text: asString(options.subtitle) ||
        `проведення занять${groupName ? ` групою ${groupName}` : ""}`,
      bold: false,
    },
    {
      text: buildCalendarPeriodLabel(startDate, endDate),
      bold: true,
      color: "FF333F4F",
    },
  ];
  titleRows.forEach((item, index) => {
    const rowIdx = index + 1;
    ws.mergeCells(rowIdx, 1, rowIdx, countCol);
    const cell = ws.getCell(rowIdx, 1);
    cell.value = item.text;
    cell.font = {
      name: FONT, size: 12, bold: item.bold,
      ...(item.color ? {color: {argb: item.color}} : {}),
    };
    cell.alignment = {horizontal: "center"};
    ws.getRow(rowIdx).height = 15.75;
  });
  for (let col = 1; col <= countCol; col++) {
    ws.getCell(3, col).border = {bottom: THIN};
  }

  // ── Шапка таблиці ──
  ws.getRow(HDR).height = 26.25;
  ws.getRow(DATES_ROW).height = 44.25;
  const headerFont = {name: FONT, size: 12};
  const centered = {horizontal: "center", vertical: "middle"};

  function mergedHeader(col, text, extra = {}) {
    ws.mergeCells(HDR, col, DATES_ROW, col);
    const cell = ws.getCell(HDR, col);
    cell.value = text;
    cell.font = headerFont;
    cell.alignment = {...centered, ...extra};
    cell.border = allBorders;
    ws.getCell(DATES_ROW, col).border = allBorders;
    return cell;
  }

  mergedHeader(1, "№");
  mergedHeader(2, "Посада");

  const rankTop = ws.getCell(HDR, 3);
  rankTop.value = "Військове";
  rankTop.font = headerFont;
  rankTop.alignment = {horizontal: "center"};
  rankTop.border = {top: THIN, left: THIN, right: THIN};
  const rankBottom = ws.getCell(DATES_ROW, 3);
  rankBottom.value = "звання";
  rankBottom.font = headerFont;
  rankBottom.alignment = {horizontal: "center", vertical: "top"};
  rankBottom.border = {bottom: THIN, left: THIN, right: THIN};

  mergedHeader(4, "ПІБ");
  const educationHdr = mergedHeader(5, "Освіта");
  educationHdr.note = {
    texts: [{text: CALENDAR_EDUCATION_NOTE}],
    margins: {insetmode: "auto"},
    _width: "300pt",
    _height: "140pt",
  };

  if (days.length > 0) {
    ws.mergeCells(HDR, FIRST_DAY_COL, HDR, lastDayCol);
  }
  const dateHdr = ws.getCell(HDR, FIRST_DAY_COL);
  dateHdr.value = "Дата";
  dateHdr.font = headerFont;
  dateHdr.alignment = centered;
  for (let col = FIRST_DAY_COL; col <= lastDayCol; col++) {
    ws.getCell(HDR, col).border = allBorders;
  }

  days.forEach((day, i) => {
    const cell = ws.getCell(DATES_ROW, FIRST_DAY_COL + i);
    cell.value = day.headerLabel;
    cell.numFmt = "@";
    cell.font = headerFont;
    cell.alignment = {textRotation: 90};
    cell.fill = solid(day.isSunday ? SUNDAY_FILL : WHITE_FILL);
    cell.border = allBorders;
  });

  mergedHeader(countCol, "Кількість занять за звітний період ", {wrapText: true});
  mergedHeader(spareCol, null);

  // ── Рядки людей ──
  groups.forEach((group, r) => {
    const rowIdx = FIRST_DATA_ROW + r;
    ws.getRow(rowIdx).height = 15.75;

    const numCell = ws.getCell(rowIdx, 1);
    numCell.value = r + 1;
    numCell.font = {name: FONT, size: 12};
    numCell.alignment = centered;

    const positionCell = ws.getCell(rowIdx, 2);
    positionCell.value = group.position || null;
    positionCell.font = {name: FONT, size: 8};
    positionCell.alignment = {horizontal: "left", vertical: "middle", wrapText: true};

    const rankCell = ws.getCell(rowIdx, 3);
    rankCell.value = group.rank || null;
    rankCell.font = {name: FONT, size: 11};

    const nameCell = ws.getCell(rowIdx, 4);
    nameCell.value = group.fullName;
    nameCell.font = {name: FONT, size: 8};
    nameCell.alignment = {vertical: "middle"};
    nameCell.fill = solid(WHITE_FILL);

    const educationCell = ws.getCell(rowIdx, 5);
    educationCell.font = {name: FONT, size: 11};
    educationCell.alignment = centered;
    educationCell.numFmt = "#,##0";

    for (let col = 1; col <= 5; col++) ws.getCell(rowIdx, col).border = allBorders;

    days.forEach((day, i) => {
      const cell = ws.getCell(rowIdx, FIRST_DAY_COL + i);
      cell.border = allBorders;
      cell.alignment = {horizontal: "center"};
      const lessonsOnDay = group.dayMap.get(day.dayKey) || [];
      const absenceCode = group.absenceMap.get(day.dayKey);

      if (lessonsOnDay.length > 0) {
        cell.value = cellMark;
        cell.font = {name: FONT, size: 11};
        cell.fill = solid(LESSON_FILL);
        if (noteFields.length > 0) {
          const noteObj = buildCalendarCellNote({lessonsOnDay, noteFields, noteLabels});
          if (noteObj) cell.note = noteObj;
        }
      } else if (absenceCode) {
        cell.value = absenceCode;
        cell.font = {name: FONT, size: 11, bold: true};
        cell.fill = solid(WHITE_FILL);
      } else {
        cell.font = {name: FONT, size: 11};
        cell.fill = solid(WHITE_FILL);
      }
    });

    const countCell = ws.getCell(rowIdx, countCol);
    countCell.value = group.totalLessons || null;
    countCell.font = {name: FONT, size: 11};
    countCell.alignment = centered;
    countCell.border = allBorders;
  });

  // ── Умовні скорочення ──
  const legendRow = FIRST_DATA_ROW + groups.length;
  ws.mergeCells(legendRow, 1, legendRow, 2);
  const legendTitle = ws.getCell(legendRow, 1);
  legendTitle.value = "Умовні скорочення:";
  legendTitle.font = {name: FONT, size: 9, bold: true};
  legendTitle.alignment = {horizontal: "center"};

  const legendItems = [
    "Х - хворий (шпиталь)",
    "В - відпустка",
    "ВД - відрядження",
    "Н - добовий наряд",
    `${cellMark} - заняття`,
  ];
  legendItems.forEach((text, i) => {
    const rowIdx = legendRow + i;
    ws.mergeCells(rowIdx, 3, rowIdx, 4);
    const cell = ws.getCell(rowIdx, 3);
    cell.value = text;
    cell.font = {name: FONT, size: 9};
    cell.alignment = {horizontal: "left"};
  });
  const lastRow = legendRow + legendItems.length - 1;

  // ── Ширина колонок ──
  [5.71, 18.71, 9.86, 23.71, 18.29].forEach((width, i) => {
    ws.getColumn(i + 1).width = width;
  });
  for (let col = FIRST_DAY_COL; col <= lastDayCol; col++) {
    ws.getColumn(col).width = 3.71;
  }
  ws.getColumn(countCol).width = 11.86;
  ws.getColumn(spareCol).width = 8.86;

  // ── Друк ──
  ws.pageSetup = {
    orientation: "landscape",
    paperSize: 9,
    fitToPage: true,
    fitToWidth: 1,
    fitToHeight: 0,
    horizontalCentered: true,
    margins: {
      left: 0.984251968503937,
      right: 0.1968503937007874,
      top: 0.3937007874015748,
      bottom: 0.3937007874015748,
      header: 0.31496062992125984,
      footer: 0.31496062992125984,
    },
    printArea: `A1:${columnLetter(countCol)}${lastRow}`,
  };
  ws.views = [{style: "pageBreakPreview", zoomScale: 88, zoomScaleNormal: 88}];

  return workbook.xlsx.writeBuffer();
}

// Returns {text, _width, _height} for use as cell.note object, or null.
function buildCalendarCellNote({lessonsOnDay, noteFields, noteLabels = {}}) {
  const parts = [];
  const hasTitle = noteFields.includes("lesson.title");
  const hasDesc = noteFields.includes("lesson.description");

  for (let li = 0; li < lessonsOnDay.length; li++) {
    if (li > 0) parts.push("");
    if (lessonsOnDay.length > 1) {
      parts.push(`--------- Заняття ${li + 1} ---------`);
    }
    const lesson = lessonsOnDay[li];
    const row = {lesson, instructor: {name: ""}, member: {}};
    let customSectionStarted = false;

    for (const fieldKey of noteFields) {
      // description is rendered together with title — skip standalone
      if (fieldKey === "lesson.description" && hasTitle) continue;

      const descriptor = FIELD_CATALOG[fieldKey];
      if (descriptor) {
        if (fieldKey === "lesson.unit") {
          const formatted = formatFieldValue(fieldKey, descriptor.getRawValue(row));
          if (formatted) {
            parts.push(`Підрозділ: ${formatted}`);
            parts.push("");
          }
        } else if (fieldKey === "lesson.title") {
          const title = formatFieldValue(fieldKey, descriptor.getRawValue(row));
          const desc = hasDesc
            ? formatFieldValue("lesson.description",
                FIELD_CATALOG["lesson.description"].getRawValue(row))
            : "";
          if (title && desc) {
            parts.push(`${title}: "${desc}"`);
          } else if (title) {
            parts.push(title);
          }
          // Duration always follows the title block
          const start = lesson.startTime ? new Date(
            lesson.startTime.seconds
              ? lesson.startTime.seconds * 1000
              : lesson.startTime,
          ) : null;
          const end = lesson.endTime ? new Date(
            lesson.endTime.seconds
              ? lesson.endTime.seconds * 1000
              : lesson.endTime,
          ) : null;
          if (start && end && end > start) {
            const mins = Math.round((end - start) / 60000);
            const h = Math.floor(mins / 60);
            const m = mins % 60;
            const hWord = _ukHours(h);
            const durStr = m === 0 ? `${h} ${hWord}` : `${h} ${hWord} ${m} хв`;
            parts.push(`Час: ${durStr}`);
          }
        } else if (fieldKey === "lesson.duration") {
          // Rendered automatically after title; skip to avoid duplication
        } else {
          const rawValue = descriptor.getRawValue(row);
          const formatted = formatFieldValue(fieldKey, rawValue);
          if (formatted) parts.push(`${noteLabels[fieldKey] || descriptor.label}: ${formatted}`);
        }
      } else if (isCustomFieldKey(fieldKey)) {
        const code = fieldKey.slice("custom.".length);
        const val = resolveCustomFieldValue(lesson, code);
        if (val) {
          if (!customSectionStarted) {
            parts.push("");
            customSectionStarted = true;
          }
          const label = noteLabels[fieldKey] || _resolveCustomFieldLabel(lesson, code);
          parts.push(label ? `${label}  №${val}` : val);
        }
      }
    }
  }

  // Trim trailing blank lines
  while (parts.length > 0 && parts[parts.length - 1] === "") parts.pop();

  if (parts.length === 0) return null;
  const text = parts.join("\n");
  const lineCount = lessonsOnDay.length;
  const w = lineCount > 1 ? "260pt" : "200pt";
  const h = lineCount > 1 ? `${150 * lineCount}pt` : "150pt";
  return {
    texts: [{text}],
    margins: {insetmode: "auto"},
    _width: w,
    _height: h,
  };
}

function _ukHours(h) {
  const m10 = h % 10;
  const m100 = h % 100;
  if (m10 === 1 && m100 !== 11) return "година";
  if (m10 >= 2 && m10 <= 4 && (m100 < 10 || m100 >= 20)) return "години";
  return "годин";
}

function _resolveCustomFieldLabel(lesson, code) {
  const defs = lesson && Array.isArray(lesson.customFieldDefinitions)
    ? lesson.customFieldDefinitions
    : [];
  const def = defs.find((d) => asString(d.code) === code);
  return def ? asString(def.label) : null;
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

  // Один і той самий викладач може бути записаний як "Ім'я" та
  // "Ім'я (email)" — порівнюємо за id, а без id — за очищеним імʼям.
  const signatureOf = (assignmentId, name) => assignmentId ?
    `id:${assignmentId.toLowerCase()}` :
    `name:${normalizePersonNameKey(splitInstructorName(name).name)}`;

  for (let index = 0; index < instructorIds.length; index++) {
    const assignmentId = instructorIds[index];
    const name = instructorNames[index] || asString(lesson.instructorName);
    const signature = signatureOf(assignmentId, name);
    if (seen.has(signature)) {
      continue;
    }

    assignments.push({assignmentId, name});
    seen.add(signature);
  }

  const primaryId = asString(lesson.instructorId);
  const primaryName = asString(lesson.instructorName);
  if (primaryId || primaryName) {
    const signature = signatureOf(primaryId, primaryName);
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
    extractLessonAssignments,
    splitInstructorName,
    createPersonResolver,
    buildCalendarGridWorkbookBuffer,
    buildCalendarGridDataset,
    createGroupMemberMatcher,
    buildCalendarPeriodLabel,
  },
};
