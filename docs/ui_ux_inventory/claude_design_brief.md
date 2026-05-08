# Claude Design Brief: iTACS Global Redesign

## Product

iTACS is an internal operational Flutter app for GSPP training groups. It is used by instructors, group members, editors and admins to manage lessons, schedules, group notifications, absence requests, tools, reports and training support workflows.

The redesign must preserve all current functionality while making the UI more coherent, dense, responsive and easy to scan.

## Design Direction

Design this as a serious internal operations product, not a marketing website.

Prioritize:

- fast scanning;
- clear hierarchy;
- stable navigation;
- dense but readable layouts;
- role-aware actions;
- strong loading/empty/error states;
- consistent dialogs and snackbars;
- mobile usability for field use;
- desktop efficiency for admin work.

Avoid:

- landing-page composition;
- oversized decorative hero sections;
- purely aesthetic cards without workflow value;
- one-note color palettes;
- hiding operational actions too deeply.

## Users and Roles

- Admin: manages group members, absences, notifications, lesson templates and report templates.
- Editor: creates and edits lessons and group tools when online.
- Viewer: reads information and uses allowed tools.
- Offline read-only user: can see cached data, but cannot perform write actions.

## Main Surfaces to Redesign

### 1. App Shell

Needs:

- responsive desktop/mobile navigation;
- group switcher;
- profile entry;
- admin access when available;
- push/web push banners;
- clear offline/read-only indicator.

### 2. Auth Flow

Screens:

- session checking/loading;
- Google login;
- access denied.

### 3. Dashboard

Purpose: daily operational feed.

Content:

- greeting and user context;
- group notifications;
- user's absence requests;
- upcoming lessons;
- lessons requiring acknowledgement;
- lessons without instructor;
- personal stats;
- quick reports;
- last updated state.

Actions:

- refresh;
- request absence;
- open lesson details;
- acknowledge lessons;
- generate report;
- contact support.

### 4. Calendar Workspace

Purpose: view and manage lessons.

Views:

- day;
- week;
- month;
- year.

Controls:

- previous/next/today;
- view switcher;
- refresh;
- filters with active count;
- create lesson FAB for allowed roles.

Important dialogs:

- filter bottom sheet;
- lesson details;
- lesson create/edit form;
- instructor picker;
- delete confirmation.

### 5. Lesson Detail Template

Must support:

- status;
- time;
- instructors;
- location;
- unit;
- expected students;
- description;
- custom fields;
- instructor coverage;
- instructor acknowledgements;
- tags;
- role-aware action footer.

Actions:

- take/release lesson;
- assign instructor;
- register/unregister;
- edit;
- duplicate;
- delete;
- fill custom fields;
- acknowledge.

### 6. Lesson Form Template

Must support:

- basic info;
- template application;
- date/time;
- progress reminders;
- details;
- instructors;
- recurrence;
- tags;
- custom field definitions;
- validation and saving state.

### 7. Profile

Tabs:

- general info;
- full info;
- settings.

Content:

- avatar/initials;
- full name/email/current group;
- editable fields;
- group roles;
- notification preference switches;
- save/logout actions.

### 8. Admin Panel

Tabs:

- Status;
- Members;
- Notifications;
- Lesson Templates;
- Report Templates.

Needs:

- desktop-first dense data views;
- mobile fallback;
- consistent CRUD dialogs;
- clear destructive action confirmations;
- stats/summary cards where useful.

### 9. Tools Hub

Purpose: searchable catalog of embedded group tools.

Embedded tools:

- Checklist Builder;
- Contacts;
- Schedule Calculator;
- Material Journals;
- Trip Tracking.

Needs:

- search;
- grid/list responsive layout;
- tool cards;
- admin/editor management actions;
- empty/search empty states.

### 10. Embedded Tools

Provide reusable templates for:

- tabbed tool workspace;
- searchable directory;
- CRUD entity list;
- calculator form/result;
- import/export JSON workflow;
- inventory/material journal list;
- history/timeline;
- debt/payment overview.

## Dialog and Notification System

Create a unified system for:

- success snackbar;
- info snackbar;
- warning snackbar;
- error snackbar;
- critical error modal;
- destructive confirmation;
- form dialog;
- large full-screen mobile editor;
- bottom sheet filters/actions.

Large dialogs that may need full-screen mobile treatment:

- LessonFormDialog;
- LessonDetailsDialog;
- ReportTemplateEditorDialog;
- ChecklistConfigEditorPage flows;
- Material journal item/template dialogs.

## Template Families Needed

1. App Shell Template.
2. Auth State Template.
3. Operational Dashboard Template.
4. Calendar Workspace Template.
5. Detail Dialog Template.
6. Entity Editor Dialog Template.
7. Admin Data Tab Template.
8. Tool Catalog Template.
9. Embedded Tool Workspace Template.
10. Notification and Feedback Template.

## Output Requested from Claude Design

Generate design templates, not just individual screens.

For each template, provide:

- desktop layout;
- mobile layout;
- component hierarchy;
- primary/secondary/destructive actions;
- loading/empty/error states;
- notes for role-based visibility;
- suggested component variants.

The final design should feel like a cohesive internal command center for training group operations.
