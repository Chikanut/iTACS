import 'package:cloud_firestore/cloud_firestore.dart';

enum MaterialAction {
  writeOff,
  replenish,
  transfer,
  transferReceive,
  conditionChange,
  correction,
  create,
}

extension MaterialActionX on MaterialAction {
  String get label => switch (this) {
    MaterialAction.writeOff => 'Списання',
    MaterialAction.replenish => 'Поповнення',
    MaterialAction.transfer => 'Передача',
    MaterialAction.transferReceive => 'Отримання',
    MaterialAction.conditionChange => 'Зміна стану',
    MaterialAction.correction => 'Корекція',
    MaterialAction.create => 'Створення',
  };

  String get value => switch (this) {
    MaterialAction.writeOff => 'write_off',
    MaterialAction.replenish => 'replenish',
    MaterialAction.transfer => 'transfer',
    MaterialAction.transferReceive => 'transfer_receive',
    MaterialAction.conditionChange => 'condition_change',
    MaterialAction.correction => 'correction',
    MaterialAction.create => 'create',
  };

  static MaterialAction fromString(String v) => switch (v) {
    'replenish' => MaterialAction.replenish,
    'transfer' => MaterialAction.transfer,
    'transfer_receive' => MaterialAction.transferReceive,
    'condition_change' => MaterialAction.conditionChange,
    'correction' => MaterialAction.correction,
    'create' => MaterialAction.create,
    _ => MaterialAction.writeOff,
  };
}

class MaterialHistoryRecord {
  final String id;
  final DateTime timestamp;
  final String userId;
  final String userName;
  final String journalId;
  final String journalName;
  final String itemId;
  final String itemName;
  final MaterialAction action;
  final String before;
  final String change;
  final String after;
  final String? comment;
  final String? targetJournalId;
  final String? targetJournalName;

  const MaterialHistoryRecord({
    required this.id,
    required this.timestamp,
    required this.userId,
    required this.userName,
    required this.journalId,
    required this.journalName,
    required this.itemId,
    required this.itemName,
    required this.action,
    required this.before,
    required this.change,
    required this.after,
    this.comment,
    this.targetJournalId,
    this.targetJournalName,
  });

  factory MaterialHistoryRecord.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MaterialHistoryRecord(
      id: doc.id,
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      userId: data['userId'] as String? ?? '',
      userName: data['userName'] as String? ?? '',
      journalId: data['journalId'] as String? ?? '',
      journalName: data['journalName'] as String? ?? '',
      itemId: data['itemId'] as String? ?? '',
      itemName: data['itemName'] as String? ?? '',
      action: MaterialActionX.fromString(data['action'] as String? ?? ''),
      before: data['before'] as String? ?? '',
      change: data['change'] as String? ?? '',
      after: data['after'] as String? ?? '',
      comment: data['comment'] as String?,
      targetJournalId: data['targetJournalId'] as String?,
      targetJournalName: data['targetJournalName'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
    'timestamp': FieldValue.serverTimestamp(),
    'userId': userId,
    'userName': userName,
    'journalId': journalId,
    'journalName': journalName,
    'itemId': itemId,
    'itemName': itemName,
    'action': action.value,
    'before': before,
    'change': change,
    'after': after,
    if (comment != null && comment!.isNotEmpty) 'comment': comment,
    if (targetJournalId != null) 'targetJournalId': targetJournalId,
    if (targetJournalName != null) 'targetJournalName': targetJournalName,
  };
}
