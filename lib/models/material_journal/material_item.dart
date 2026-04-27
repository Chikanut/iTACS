import 'package:cloud_firestore/cloud_firestore.dart';

enum MaterialItemType { consumable, nonConsumable, valueBased }

enum MaterialUnit { pcs, liters, kg, meters, m3 }

enum ItemStatus { normal, low, critical }

enum ItemCondition { working, damaged, inRepair, writtenOff }

extension MaterialItemTypeX on MaterialItemType {
  String get label => switch (this) {
    MaterialItemType.consumable => 'Витратна',
    MaterialItemType.nonConsumable => 'Невитратна',
    MaterialItemType.valueBased => 'Зі значенням',
  };

  String get value => switch (this) {
    MaterialItemType.consumable => 'consumable',
    MaterialItemType.nonConsumable => 'non_consumable',
    MaterialItemType.valueBased => 'value_based',
  };

  static MaterialItemType fromString(String v) => switch (v) {
    'non_consumable' => MaterialItemType.nonConsumable,
    'value_based' => MaterialItemType.valueBased,
    _ => MaterialItemType.consumable,
  };
}

extension MaterialUnitX on MaterialUnit {
  String get label => switch (this) {
    MaterialUnit.pcs => 'шт',
    MaterialUnit.liters => 'л',
    MaterialUnit.kg => 'кг',
    MaterialUnit.meters => 'м',
    MaterialUnit.m3 => 'м³',
  };

  String get value => switch (this) {
    MaterialUnit.pcs => 'pcs',
    MaterialUnit.liters => 'liters',
    MaterialUnit.kg => 'kg',
    MaterialUnit.meters => 'meters',
    MaterialUnit.m3 => 'm3',
  };

  static MaterialUnit fromString(String v) => switch (v) {
    'liters' => MaterialUnit.liters,
    'kg' => MaterialUnit.kg,
    'meters' => MaterialUnit.meters,
    'm3' => MaterialUnit.m3,
    _ => MaterialUnit.pcs,
  };
}

extension ItemStatusX on ItemStatus {
  String get label => switch (this) {
    ItemStatus.normal => 'Норма',
    ItemStatus.low => 'Мало',
    ItemStatus.critical => 'Критично',
  };

  String get value => switch (this) {
    ItemStatus.normal => 'normal',
    ItemStatus.low => 'low',
    ItemStatus.critical => 'critical',
  };

  static ItemStatus fromString(String v) => switch (v) {
    'low' => ItemStatus.low,
    'critical' => ItemStatus.critical,
    _ => ItemStatus.normal,
  };

  static ItemStatus compute(double quantity, double minQuantity) {
    if (quantity <= 0) return ItemStatus.critical;
    if (quantity <= minQuantity) return ItemStatus.low;
    return ItemStatus.normal;
  }
}

extension ItemConditionX on ItemCondition {
  String get label => switch (this) {
    ItemCondition.working => 'Справне',
    ItemCondition.damaged => 'Пошкоджене',
    ItemCondition.inRepair => 'В ремонті',
    ItemCondition.writtenOff => 'Списане',
  };

  String get value => switch (this) {
    ItemCondition.working => 'working',
    ItemCondition.damaged => 'damaged',
    ItemCondition.inRepair => 'in_repair',
    ItemCondition.writtenOff => 'written_off',
  };

  static ItemCondition fromString(String v) => switch (v) {
    'damaged' => ItemCondition.damaged,
    'in_repair' => ItemCondition.inRepair,
    'written_off' => ItemCondition.writtenOff,
    _ => ItemCondition.working,
  };
}

class MaterialItem {
  final String id;
  final String name;
  final MaterialItemType type;
  final DateTime modifiedAt;
  final String modifiedBy;

  // Consumable / value_based fields
  final double quantity;
  final MaterialUnit unit;
  final double minQuantity;
  final ItemStatus status;

  // Non-consumable fields
  final int count;
  final ItemCondition condition;
  final String conditionComment;

  const MaterialItem({
    required this.id,
    required this.name,
    required this.type,
    required this.modifiedAt,
    required this.modifiedBy,
    this.quantity = 0,
    this.unit = MaterialUnit.pcs,
    this.minQuantity = 0,
    this.status = ItemStatus.normal,
    this.count = 0,
    this.condition = ItemCondition.working,
    this.conditionComment = '',
  });

  factory MaterialItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final type = MaterialItemTypeX.fromString(data['type'] as String? ?? '');

    final quantity = (data['quantity'] as num?)?.toDouble() ?? 0.0;
    final minQuantity = (data['minQuantity'] as num?)?.toDouble() ?? 0.0;

    return MaterialItem(
      id: doc.id,
      name: data['name'] as String? ?? '',
      type: type,
      modifiedAt: (data['modifiedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      modifiedBy: data['modifiedBy'] as String? ?? '',
      quantity: quantity,
      unit: MaterialUnitX.fromString(data['unit'] as String? ?? ''),
      minQuantity: minQuantity,
      status: ItemStatusX.fromString(data['status'] as String? ?? ''),
      count: (data['count'] as num?)?.toInt() ?? 0,
      condition: ItemConditionX.fromString(data['condition'] as String? ?? ''),
      conditionComment: data['conditionComment'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    final base = <String, dynamic>{
      'name': name,
      'type': type.value,
      'modifiedAt': FieldValue.serverTimestamp(),
      'modifiedBy': modifiedBy,
    };

    if (type == MaterialItemType.nonConsumable) {
      base['count'] = count;
      base['condition'] = condition.value;
      base['conditionComment'] = conditionComment;
    } else {
      final computedStatus = ItemStatusX.compute(quantity, minQuantity);
      base['quantity'] = quantity;
      base['unit'] = unit.value;
      base['minQuantity'] = minQuantity;
      base['status'] = computedStatus.value;
    }

    return base;
  }

  MaterialItem copyWith({
    String? name,
    MaterialItemType? type,
    String? modifiedBy,
    double? quantity,
    MaterialUnit? unit,
    double? minQuantity,
    int? count,
    ItemCondition? condition,
    String? conditionComment,
  }) {
    final newQty = quantity ?? this.quantity;
    final newMin = minQuantity ?? this.minQuantity;
    return MaterialItem(
      id: id,
      name: name ?? this.name,
      type: type ?? this.type,
      modifiedAt: DateTime.now(),
      modifiedBy: modifiedBy ?? this.modifiedBy,
      quantity: newQty,
      unit: unit ?? this.unit,
      minQuantity: newMin,
      status: ItemStatusX.compute(newQty, newMin),
      count: count ?? this.count,
      condition: condition ?? this.condition,
      conditionComment: conditionComment ?? this.conditionComment,
    );
  }

  bool get isCritical =>
      type != MaterialItemType.nonConsumable && status == ItemStatus.critical;
}
