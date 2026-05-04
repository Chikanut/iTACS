import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../globals.dart';
import '../models/material_journal/material_history_record.dart';
import '../models/material_journal/material_item.dart';
import '../models/material_journal/material_journal.dart';
import '../models/material_journal/material_template.dart';

class JournalStats {
  final int total;
  final int critical;
  final int low;

  const JournalStats({
    required this.total,
    required this.critical,
    required this.low,
  });

  bool get hasIssues => critical > 0 || low > 0;
}

class MaterialJournalService {
  static const _root = 'material_journals_by_group';
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  // ── Journals ──────────────────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> _journalsRef(String groupId) =>
      _db.collection(_root).doc(groupId).collection('journals');

  CollectionReference<Map<String, dynamic>> _itemsRef(
    String groupId,
    String journalId,
  ) => _journalsRef(groupId).doc(journalId).collection('items');

  CollectionReference<Map<String, dynamic>> _templatesRef(
    String groupId,
    String journalId,
  ) => _journalsRef(groupId).doc(journalId).collection('templates');

  CollectionReference<Map<String, dynamic>> _historyRef(String groupId) =>
      _db.collection(_root).doc(groupId).collection('history');

  Future<List<MaterialJournal>> getJournals(String groupId) async {
    try {
      final snap = await _journalsRef(groupId).orderBy('name').get();
      return snap.docs.map(MaterialJournal.fromFirestore).toList();
    } catch (e) {
      debugPrint('[material_journal] getJournals error: $e');
      return [];
    }
  }

  Future<String?> createJournal(
    String groupId,
    String name,
    String? description,
  ) async {
    final email = Globals.profileManager.currentUserEmail ?? '';
    try {
      final ref = await _journalsRef(groupId).add({
        'name': name,
        'description': description,
        'authorEmail': email,
        'createdAt': FieldValue.serverTimestamp(),
        'modifiedAt': FieldValue.serverTimestamp(),
      });
      return ref.id;
    } catch (e) {
      debugPrint('[material_journal] createJournal error: $e');
      rethrow;
    }
  }

  Future<void> updateJournal(
    String groupId,
    String journalId,
    String name,
    String? description,
  ) async {
    try {
      await _journalsRef(groupId).doc(journalId).update({
        'name': name,
        'description': description,
        'modifiedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('[material_journal] updateJournal error: $e');
      rethrow;
    }
  }

  Future<void> deleteJournal(String groupId, String journalId) async {
    try {
      // Delete subcollections first
      final items = await _itemsRef(groupId, journalId).get();
      for (final doc in items.docs) {
        await doc.reference.delete();
      }
      final templates = await _templatesRef(groupId, journalId).get();
      for (final doc in templates.docs) {
        await doc.reference.delete();
      }
      await _journalsRef(groupId).doc(journalId).delete();
    } catch (e) {
      debugPrint('[material_journal] deleteJournal error: $e');
      rethrow;
    }
  }

  // ── Items ─────────────────────────────────────────────────────────────────

  Future<List<MaterialItem>> getItems(String groupId, String journalId) async {
    try {
      final snap = await _itemsRef(groupId, journalId).orderBy('name').get();
      return snap.docs.map(MaterialItem.fromFirestore).toList();
    } catch (e) {
      debugPrint('[material_journal] getItems error: $e');
      return [];
    }
  }

  Future<JournalStats> getJournalStats(String groupId, String journalId) async {
    final items = await getItems(groupId, journalId);
    final critical = items.where((i) => i.isCritical).length;
    final low = items
        .where(
          (i) =>
              i.type != MaterialItemType.nonConsumable &&
              i.status == ItemStatus.low,
        )
        .length;
    return JournalStats(total: items.length, critical: critical, low: low);
  }

  Future<String?> createItem(
    String groupId,
    String journalId,
    MaterialItem item,
    String userName,
  ) async {
    try {
      final ref = await _itemsRef(groupId, journalId).add(item.toMap());
      await _addHistory(
        groupId: groupId,
        journalId: journalId,
        journalName: await _journalName(groupId, journalId),
        itemId: ref.id,
        itemName: item.name,
        action: MaterialAction.create,
        before: '',
        change: '',
        after: _itemValueString(item),
        userName: userName,
        comment: null,
      );
      return ref.id;
    } catch (e) {
      debugPrint('[material_journal] createItem error: $e');
      rethrow;
    }
  }

  Future<void> updateItemMeta(
    String groupId,
    String journalId,
    MaterialItem item,
  ) async {
    try {
      await _itemsRef(groupId, journalId).doc(item.id).update(item.toMap());
    } catch (e) {
      debugPrint('[material_journal] updateItemMeta error: $e');
      rethrow;
    }
  }

  Future<void> deleteItem(
    String groupId,
    String journalId,
    String itemId,
  ) async {
    try {
      await _itemsRef(groupId, journalId).doc(itemId).delete();
    } catch (e) {
      debugPrint('[material_journal] deleteItem error: $e');
      rethrow;
    }
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> writeOff(
    String groupId,
    String journalId,
    MaterialItem item,
    double amount,
    String? comment,
    String userName,
  ) async {
    final before = item.quantity;
    final after = (before - amount).clamp(0.0, double.infinity);
    final newStatus = ItemStatusX.compute(after, item.minQuantity);

    await _runQuantityUpdate(
      groupId: groupId,
      journalId: journalId,
      itemId: item.id,
      quantity: after,
      status: newStatus,
      userName: userName,
    );

    await _addHistory(
      groupId: groupId,
      journalId: journalId,
      journalName: await _journalName(groupId, journalId),
      itemId: item.id,
      itemName: item.name,
      action: MaterialAction.writeOff,
      before: '${_fmt(before)} ${item.unit.label}',
      change: '-${_fmt(amount)} ${item.unit.label}',
      after: '${_fmt(after)} ${item.unit.label}',
      userName: userName,
      comment: comment,
    );
  }

  Future<void> replenish(
    String groupId,
    String journalId,
    MaterialItem item,
    double amount,
    String? comment,
    String userName,
  ) async {
    final before = item.quantity;
    final after = before + amount;
    final newStatus = ItemStatusX.compute(after, item.minQuantity);

    await _runQuantityUpdate(
      groupId: groupId,
      journalId: journalId,
      itemId: item.id,
      quantity: after,
      status: newStatus,
      userName: userName,
    );

    await _addHistory(
      groupId: groupId,
      journalId: journalId,
      journalName: await _journalName(groupId, journalId),
      itemId: item.id,
      itemName: item.name,
      action: MaterialAction.replenish,
      before: '${_fmt(before)} ${item.unit.label}',
      change: '+${_fmt(amount)} ${item.unit.label}',
      after: '${_fmt(after)} ${item.unit.label}',
      userName: userName,
      comment: comment,
    );
  }

  Future<void> transfer(
    String groupId,
    String fromJournalId,
    MaterialItem fromItem,
    String toJournalId,
    MaterialItem toItem,
    double amount,
    String? comment,
    String userName,
  ) async {
    final fromJournalName = await _journalName(groupId, fromJournalId);
    final toJournalName = await _journalName(groupId, toJournalId);

    // Subtract from source
    final fromBefore = fromItem.quantity;
    final fromAfter = (fromBefore - amount).clamp(0.0, double.infinity);
    await _runQuantityUpdate(
      groupId: groupId,
      journalId: fromJournalId,
      itemId: fromItem.id,
      quantity: fromAfter,
      status: ItemStatusX.compute(fromAfter, fromItem.minQuantity),
      userName: userName,
    );

    // Add to target
    final toBefore = toItem.quantity;
    final toAfter = toBefore + amount;
    await _runQuantityUpdate(
      groupId: groupId,
      journalId: toJournalId,
      itemId: toItem.id,
      quantity: toAfter,
      status: ItemStatusX.compute(toAfter, toItem.minQuantity),
      userName: userName,
    );

    final unit = fromItem.unit.label;

    await _addHistory(
      groupId: groupId,
      journalId: fromJournalId,
      journalName: fromJournalName,
      itemId: fromItem.id,
      itemName: fromItem.name,
      action: MaterialAction.transfer,
      before: '${_fmt(fromBefore)} $unit',
      change: '-${_fmt(amount)} $unit',
      after: '${_fmt(fromAfter)} $unit',
      userName: userName,
      comment: comment,
      targetJournalId: toJournalId,
      targetJournalName: toJournalName,
    );

    await _addHistory(
      groupId: groupId,
      journalId: toJournalId,
      journalName: toJournalName,
      itemId: toItem.id,
      itemName: toItem.name,
      action: MaterialAction.transferReceive,
      before: '${_fmt(toBefore)} $unit',
      change: '+${_fmt(amount)} $unit',
      after: '${_fmt(toAfter)} $unit',
      userName: userName,
      comment: comment,
      targetJournalId: fromJournalId,
      targetJournalName: fromJournalName,
    );
  }

  Future<void> changeCondition(
    String groupId,
    String journalId,
    MaterialItem item,
    ItemCondition newCondition,
    String? comment,
    String userName,
  ) async {
    try {
      await _itemsRef(groupId, journalId).doc(item.id).update({
        'condition': newCondition.value,
        'conditionComment': comment ?? '',
        'modifiedBy': userName,
        'modifiedAt': FieldValue.serverTimestamp(),
      });

      await _addHistory(
        groupId: groupId,
        journalId: journalId,
        journalName: await _journalName(groupId, journalId),
        itemId: item.id,
        itemName: item.name,
        action: MaterialAction.conditionChange,
        before: item.condition.label,
        change: '→',
        after: newCondition.label,
        userName: userName,
        comment: comment,
      );
    } catch (e) {
      debugPrint('[material_journal] changeCondition error: $e');
      rethrow;
    }
  }

  Future<void> correction(
    String groupId,
    String journalId,
    MaterialItem item,
    double newValue,
    String? comment,
    String userName,
  ) async {
    final before = item.quantity;
    final diff = newValue - before;
    final newStatus = ItemStatusX.compute(newValue, item.minQuantity);

    await _runQuantityUpdate(
      groupId: groupId,
      journalId: journalId,
      itemId: item.id,
      quantity: newValue,
      status: newStatus,
      userName: userName,
    );

    await _addHistory(
      groupId: groupId,
      journalId: journalId,
      journalName: await _journalName(groupId, journalId),
      itemId: item.id,
      itemName: item.name,
      action: MaterialAction.correction,
      before: '${_fmt(before)} ${item.unit.label}',
      change: '${diff >= 0 ? '+' : ''}${_fmt(diff)} ${item.unit.label}',
      after: '${_fmt(newValue)} ${item.unit.label}',
      userName: userName,
      comment: comment,
    );
  }

  // ── Templates ─────────────────────────────────────────────────────────────

  Future<List<MaterialTemplate>> getTemplates(
    String groupId,
    String journalId,
  ) async {
    try {
      final snap = await _templatesRef(
        groupId,
        journalId,
      ).orderBy('name').get();
      return snap.docs.map(MaterialTemplate.fromFirestore).toList();
    } catch (e) {
      debugPrint('[material_journal] getTemplates error: $e');
      return [];
    }
  }

  Future<void> createTemplate(
    String groupId,
    String journalId,
    MaterialTemplate template,
  ) async {
    try {
      await _templatesRef(groupId, journalId).add(template.toCreateMap());
    } catch (e) {
      debugPrint('[material_journal] createTemplate error: $e');
      rethrow;
    }
  }

  Future<void> updateTemplate(
    String groupId,
    String journalId,
    MaterialTemplate template,
  ) async {
    try {
      await _templatesRef(
        groupId,
        journalId,
      ).doc(template.id).update(template.toMap());
    } catch (e) {
      debugPrint('[material_journal] updateTemplate error: $e');
      rethrow;
    }
  }

  Future<void> deleteTemplate(
    String groupId,
    String journalId,
    String templateId,
  ) async {
    try {
      await _templatesRef(groupId, journalId).doc(templateId).delete();
    } catch (e) {
      debugPrint('[material_journal] deleteTemplate error: $e');
      rethrow;
    }
  }

  /// Applies a template: writes off each line item.
  /// Returns a map of itemId → error string for items that failed.
  Future<Map<String, String>> applyTemplate(
    String groupId,
    String journalId,
    MaterialTemplate template,
    Map<String, MaterialItem> itemsById,
    String? comment,
    String userName,
  ) async {
    final errors = <String, String>{};
    for (final line in template.items) {
      final item = itemsById[line.itemId];
      if (item == null) {
        errors[line.itemId] = 'Елемент не знайдено';
        continue;
      }
      try {
        await writeOff(
          groupId,
          journalId,
          item,
          line.quantity,
          comment ?? 'Шаблон: ${template.name}',
          userName,
        );
      } catch (e) {
        errors[line.itemId] = e.toString();
      }
    }
    return errors;
  }

  // ── History ───────────────────────────────────────────────────────────────

  Future<List<MaterialHistoryRecord>> getHistory(
    String groupId, {
    String? journalId,
    String? itemId,
    int limit = 100,
  }) async {
    try {
      // Compound queries (where + orderBy on different fields) need composite
      // indexes. To avoid that, we filter with where() only — no orderBy() —
      // then sort and limit client-side. Fine for typical history sizes.
      Query<Map<String, dynamic>> query = _historyRef(groupId);

      if (journalId != null) {
        query = query.where('journalId', isEqualTo: journalId);
      }
      if (itemId != null) {
        query = query.where('itemId', isEqualTo: itemId);
      }

      // No filters → use server-side orderBy + limit (single-field index
      // is auto-created by Firestore, so no composite index needed).
      if (journalId == null && itemId == null) {
        query = query.orderBy('timestamp', descending: true).limit(limit);
      }

      final snap = await query.get();
      final records = snap.docs
          .map(MaterialHistoryRecord.fromFirestore)
          .toList();

      // Client-side sort + limit when filters were applied.
      if (journalId != null || itemId != null) {
        records.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        if (records.length > limit) {
          return records.sublist(0, limit);
        }
      }

      return records;
    } catch (e) {
      debugPrint('[material_journal] getHistory error: $e');
      return [];
    }
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  Future<void> _runQuantityUpdate({
    required String groupId,
    required String journalId,
    required String itemId,
    required double quantity,
    required ItemStatus status,
    required String userName,
  }) async {
    await _itemsRef(groupId, journalId).doc(itemId).update({
      'quantity': quantity,
      'status': status.value,
      'modifiedBy': userName,
      'modifiedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _addHistory({
    required String groupId,
    required String journalId,
    required String journalName,
    required String itemId,
    required String itemName,
    required MaterialAction action,
    required String before,
    required String change,
    required String after,
    required String userName,
    String? comment,
    String? targetJournalId,
    String? targetJournalName,
  }) async {
    final uid = Globals.profileManager.currentUserId ?? '';
    final record = MaterialHistoryRecord(
      id: '',
      timestamp: DateTime.now(),
      userId: uid,
      userName: userName,
      journalId: journalId,
      journalName: journalName,
      itemId: itemId,
      itemName: itemName,
      action: action,
      before: before,
      change: change,
      after: after,
      comment: comment,
      targetJournalId: targetJournalId,
      targetJournalName: targetJournalName,
    );
    await _historyRef(groupId).add(record.toMap());
  }

  Future<String> _journalName(String groupId, String journalId) async {
    try {
      final doc = await _journalsRef(groupId).doc(journalId).get();
      return (doc.data()?['name'] as String?) ?? journalId;
    } catch (_) {
      return journalId;
    }
  }

  String _itemValueString(MaterialItem item) {
    if (item.type == MaterialItemType.nonConsumable) {
      return '${item.count} шт — ${item.condition.label}';
    }
    return '${_fmt(item.quantity)} ${item.unit.label}';
  }

  String _fmt(double v) {
    if (v == v.truncateToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(2);
  }
}
