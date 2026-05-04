import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart' as ex;
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../globals.dart';
import '../models/personnel_profile.dart';

class PersonnelProfileService {
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _membersRef(String groupId) {
    return _firestore
        .collection('personnel_profiles')
        .doc(groupId)
        .collection('members');
  }

  Future<PersonnelProfile> loadOwnProfile({
    required String groupId,
    required String uid,
  }) async {
    final profile = await loadMemberProfile(groupId: groupId, uid: uid);
    if (profile != null) return profile;

    final cached = Globals.profileManager.profile;
    return PersonnelProfile.empty(
      uid: uid,
      email: cached.email ?? '',
      firstName: cached.firstName ?? '',
      lastName: cached.lastName ?? '',
      rank: cached.rank ?? '',
      position: cached.position ?? '',
      phone: cached.phone ?? '',
    );
  }

  Future<PersonnelProfile?> loadMemberProfile({
    required String groupId,
    required String uid,
  }) async {
    final doc = await _membersRef(groupId).doc(uid).get();
    if (!doc.exists) return null;

    final data = doc.data() ?? {};
    return PersonnelProfile.fromMap({...data, 'uid': data['uid'] ?? doc.id});
  }

  Future<void> saveOwnProfile({
    required String groupId,
    required PersonnelProfile profile,
  }) async {
    await saveMemberProfile(
      groupId: groupId,
      uid: profile.uid,
      profile: profile,
    );
  }

  Future<void> saveMemberProfile({
    required String groupId,
    required String uid,
    required PersonnelProfile profile,
  }) async {
    final currentUser = Globals.firebaseAuth.currentUser;
    final payload = profile
        .copyWith(
          uid: uid,
          updatedBy: currentUser?.uid ?? '',
          updatedAt: DateTime.now(),
        )
        .toMap();

    payload['updatedAt'] = FieldValue.serverTimestamp();
    payload['updatedBy'] = currentUser?.uid ?? '';

    await _membersRef(groupId).doc(uid).set(payload, SetOptions(merge: true));
  }

  Future<List<PersonnelProfile>> loadGroupProfiles(String groupId) async {
    final snapshot = await _membersRef(groupId).get();
    final profiles = snapshot.docs.map((doc) {
      final data = doc.data();
      return PersonnelProfile.fromMap({...data, 'uid': data['uid'] ?? doc.id});
    }).toList();

    profiles.sort((a, b) => a.fullName.compareTo(b.fullName));
    return profiles;
  }

  Future<Uint8List> generateStandardExcel({
    required List<PersonnelProfile> profiles,
    required String groupName,
    String title =
        'Якісна характеристика офіцерів органів психологічної підтримки персоналу',
  }) async {
    final excel = ex.Excel.createExcel();
    final sheet = excel['Якісна характеристика'];
    excel.delete('Sheet1');

    final headers = [
      '№ п/п',
      ...PersonnelExportColumn.standard.map((column) => column.title),
    ];

    _writeMergedTitle(sheet, title, headers.length);
    _writeHeaders(sheet, headers, 2);

    final groupCell = sheet.cell(
      ex.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 3),
    );
    groupCell.value = ex.TextCellValue(groupName);
    groupCell.cellStyle = ex.CellStyle(
      bold: true,
      horizontalAlign: ex.HorizontalAlign.Left,
      verticalAlign: ex.VerticalAlign.Center,
      textWrapping: ex.TextWrapping.WrapText,
    );
    sheet.merge(
      ex.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 3),
      ex.CellIndex.indexByColumnRow(
        columnIndex: headers.length - 1,
        rowIndex: 3,
      ),
    );

    for (var rowIndex = 0; rowIndex < profiles.length; rowIndex++) {
      final profile = profiles[rowIndex];
      final exportFields = profile.toExportFields();
      final values = [
        '${rowIndex + 1}',
        ...PersonnelExportColumn.standard.map(
          (column) => exportFields[column.key] ?? '',
        ),
      ];
      _writeRow(sheet, rowIndex + 4, values);
    }

    _formatStandardSheet(sheet, headers.length);
    return Uint8List.fromList(excel.encode()!);
  }

  Future<Uint8List> generateCustomExcel({
    required List<PersonnelProfile> profiles,
    required List<PersonnelExportColumn> columns,
    required String title,
  }) async {
    final excel = ex.Excel.createExcel();
    final sheet = excel['Експорт'];
    excel.delete('Sheet1');

    _writeMergedTitle(sheet, title, columns.length + 1);
    _writeHeaders(sheet, [
      '№ п/п',
      ...columns.map((column) => column.title),
    ], 2);

    for (var rowIndex = 0; rowIndex < profiles.length; rowIndex++) {
      final profile = profiles[rowIndex];
      final exportFields = profile.toExportFields();
      final values = [
        '${rowIndex + 1}',
        ...columns.map((column) => exportFields[column.key] ?? ''),
      ];
      _writeRow(sheet, rowIndex + 3, values);
    }

    _formatStandardSheet(sheet, columns.length + 1);
    return Uint8List.fromList(excel.encode()!);
  }

  String buildExportFilename(String prefix) {
    final date = DateFormat('dd.MM.yyyy_HH-mm').format(DateTime.now());
    return '${_sanitizeFilename(prefix)}_$date.xlsx';
  }

  void _writeMergedTitle(ex.Sheet sheet, String title, int columnCount) {
    final titleCell = sheet.cell(
      ex.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
    );
    titleCell.value = ex.TextCellValue(title);
    titleCell.cellStyle = ex.CellStyle(
      bold: true,
      fontSize: 14,
      horizontalAlign: ex.HorizontalAlign.Center,
      verticalAlign: ex.VerticalAlign.Center,
      textWrapping: ex.TextWrapping.WrapText,
    );
    sheet.merge(
      ex.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
      ex.CellIndex.indexByColumnRow(columnIndex: columnCount - 1, rowIndex: 1),
    );
  }

  void _writeHeaders(ex.Sheet sheet, List<String> headers, int rowIndex) {
    for (var columnIndex = 0; columnIndex < headers.length; columnIndex++) {
      final cell = sheet.cell(
        ex.CellIndex.indexByColumnRow(
          columnIndex: columnIndex,
          rowIndex: rowIndex,
        ),
      );
      cell.value = ex.TextCellValue(headers[columnIndex]);
      cell.cellStyle = ex.CellStyle(
        bold: true,
        horizontalAlign: ex.HorizontalAlign.Center,
        verticalAlign: ex.VerticalAlign.Center,
        textWrapping: ex.TextWrapping.WrapText,
        backgroundColorHex: ex.ExcelColor.fromHexString('#D9EAF7'),
      );
    }
  }

  void _writeRow(ex.Sheet sheet, int rowIndex, List<String> values) {
    for (var columnIndex = 0; columnIndex < values.length; columnIndex++) {
      final cell = sheet.cell(
        ex.CellIndex.indexByColumnRow(
          columnIndex: columnIndex,
          rowIndex: rowIndex,
        ),
      );
      cell.value = ex.TextCellValue(values[columnIndex]);
      cell.cellStyle = ex.CellStyle(
        verticalAlign: ex.VerticalAlign.Top,
        textWrapping: ex.TextWrapping.WrapText,
      );
    }
  }

  void _formatStandardSheet(ex.Sheet sheet, int columnCount) {
    const widths = <double>[
      6,
      10,
      28,
      18,
      12,
      28,
      22,
      24,
      14,
      42,
      38,
      24,
      30,
      36,
      36,
      18,
      12,
      36,
      42,
      36,
      32,
    ];

    for (var i = 0; i < columnCount; i++) {
      sheet.setColumnWidth(i, i < widths.length ? widths[i] : 24);
    }
    sheet.setRowHeight(0, 28);
    sheet.setRowHeight(2, 58);
    sheet.setRowHeight(3, 24);
  }

  String _sanitizeFilename(String value) {
    final clean = value.trim().replaceAll(RegExp(r'[\\/:*?"<>|]+'), '_');
    return clean.isEmpty ? 'Експорт' : clean;
  }
}
