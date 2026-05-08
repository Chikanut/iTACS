import 'package:cloud_firestore/cloud_firestore.dart';

// ─── Route ───────────────────────────────────────────────────────────────────

class TripRoute {
  const TripRoute({required this.id, required this.name, required this.price});

  final String id;
  final String name;
  final double price;

  Map<String, dynamic> toMap() => {'id': id, 'name': name, 'price': price};

  factory TripRoute.fromMap(Map<String, dynamic> m) => TripRoute(
    id: m['id'] as String? ?? '',
    name: m['name'] as String? ?? '',
    price: (m['price'] as num?)?.toDouble() ?? 0.0,
  );

  TripRoute copyWith({String? id, String? name, double? price}) => TripRoute(
    id: id ?? this.id,
    name: name ?? this.name,
    price: price ?? this.price,
  );
}

// ─── Car ─────────────────────────────────────────────────────────────────────

class TripCar {
  const TripCar({
    required this.id,
    required this.name,
    required this.ownerEmail,
    required this.routes,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String ownerEmail;
  final List<TripRoute> routes;
  final DateTime createdAt;

  Map<String, dynamic> toMap() => {
    'name': name,
    'ownerEmail': ownerEmail,
    'routes': routes.map((r) => r.toMap()).toList(),
    'createdAt': Timestamp.fromDate(createdAt),
  };

  factory TripCar.fromDoc(DocumentSnapshot doc) {
    final m = doc.data() as Map<String, dynamic>;
    return TripCar(
      id: doc.id,
      name: m['name'] as String? ?? '',
      ownerEmail: m['ownerEmail'] as String? ?? '',
      routes: (m['routes'] as List<dynamic>? ?? [])
          .map((r) => TripRoute.fromMap(r as Map<String, dynamic>))
          .toList(),
      createdAt: (m['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  TripCar copyWith({
    String? name,
    String? ownerEmail,
    List<TripRoute>? routes,
  }) => TripCar(
    id: id,
    name: name ?? this.name,
    ownerEmail: ownerEmail ?? this.ownerEmail,
    routes: routes ?? this.routes,
    createdAt: createdAt,
  );
}

// ─── Person ───────────────────────────────────────────────────────────────────

class TripPerson {
  const TripPerson({
    required this.id,
    required this.name,
    this.email = '',
    required this.createdAt,
  });

  final String id;
  final String name;
  final String email;
  final DateTime createdAt;

  Map<String, dynamic> toMap() => {
    'name': name,
    'email': email,
    'createdAt': Timestamp.fromDate(createdAt),
  };

  factory TripPerson.fromDoc(DocumentSnapshot doc) {
    final m = doc.data() as Map<String, dynamic>;
    return TripPerson(
      id: doc.id,
      name: m['name'] as String? ?? '',
      email: m['email'] as String? ?? '',
      createdAt: (m['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  TripPerson copyWith({String? name, String? email}) => TripPerson(
    id: id,
    name: name ?? this.name,
    email: email ?? this.email,
    createdAt: createdAt,
  );
}

// ─── Trip ─────────────────────────────────────────────────────────────────────

class TripEntry {
  const TripEntry({
    required this.id,
    required this.date,
    required this.carId,
    required this.carName,
    required this.driverId,
    required this.driverName,
    required this.passengerIds,
    required this.passengerNames,
    this.routeId,
    required this.routeName,
    required this.price,
    required this.createdAt,
    required this.createdByEmail,
  });

  final String id;
  final DateTime date;
  final String carId;
  final String carName;
  final String driverId;
  final String driverName;
  final List<String> passengerIds;
  final Map<String, String> passengerNames;
  final String? routeId;
  final String routeName;
  final double price;
  final DateTime createdAt;
  final String createdByEmail;

  double get sharePerPerson =>
      passengerIds.isEmpty ? 0 : price / passengerIds.length;

  Map<String, dynamic> toMap() => {
    'date': Timestamp.fromDate(date),
    'carId': carId,
    'carName': carName,
    'driverId': driverId,
    'driverName': driverName,
    'passengerIds': passengerIds,
    'passengerNames': passengerNames,
    'routeId': routeId,
    'routeName': routeName,
    'price': price,
    'createdAt': Timestamp.fromDate(createdAt),
    'createdByEmail': createdByEmail,
  };

  factory TripEntry.fromDoc(DocumentSnapshot doc) {
    final m = doc.data() as Map<String, dynamic>;
    return TripEntry(
      id: doc.id,
      date: (m['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      carId: m['carId'] as String? ?? '',
      carName: m['carName'] as String? ?? '',
      driverId: m['driverId'] as String? ?? '',
      driverName: m['driverName'] as String? ?? '',
      passengerIds: List<String>.from(m['passengerIds'] as List? ?? []),
      passengerNames: Map<String, String>.from(
        m['passengerNames'] as Map? ?? {},
      ),
      routeId: m['routeId'] as String?,
      routeName: m['routeName'] as String? ?? '',
      price: (m['price'] as num?)?.toDouble() ?? 0.0,
      createdAt: (m['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdByEmail: m['createdByEmail'] as String? ?? '',
    );
  }
}

// ─── Payment (debt settlement) ────────────────────────────────────────────────

class TripPayment {
  const TripPayment({
    required this.id,
    required this.fromPersonId,
    required this.fromPersonName,
    required this.toPersonId,
    required this.toPersonName,
    required this.amount,
    required this.tripIds,
    this.note = '',
    required this.createdAt,
    required this.createdByEmail,
  });

  final String id;
  final String fromPersonId;
  final String fromPersonName;
  final String toPersonId;
  final String toPersonName;
  final double amount;
  final List<String> tripIds;
  final String note;
  final DateTime createdAt;
  final String createdByEmail;

  Map<String, dynamic> toMap() => {
    'fromPersonId': fromPersonId,
    'fromPersonName': fromPersonName,
    'toPersonId': toPersonId,
    'toPersonName': toPersonName,
    'amount': amount,
    'tripIds': tripIds,
    'note': note,
    'createdAt': Timestamp.fromDate(createdAt),
    'createdByEmail': createdByEmail,
  };

  factory TripPayment.fromDoc(DocumentSnapshot doc) {
    final m = doc.data() as Map<String, dynamic>;
    return TripPayment(
      id: doc.id,
      fromPersonId: m['fromPersonId'] as String? ?? '',
      fromPersonName: m['fromPersonName'] as String? ?? '',
      toPersonId: m['toPersonId'] as String? ?? '',
      toPersonName: m['toPersonName'] as String? ?? '',
      amount: (m['amount'] as num?)?.toDouble() ?? 0.0,
      tripIds: List<String>.from(m['tripIds'] as List? ?? []),
      note: m['note'] as String? ?? '',
      createdAt: (m['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdByEmail: m['createdByEmail'] as String? ?? '',
    );
  }
}

// ─── Debt calculation result ───────────────────────────────────────────────────

class DebtTransaction {
  const DebtTransaction({
    required this.fromPersonId,
    required this.fromPersonName,
    required this.toPersonId,
    required this.toPersonName,
    required this.amount,
  });

  final String fromPersonId;
  final String fromPersonName;
  final String toPersonId;
  final String toPersonName;
  final double amount;
}

// ─── Algorithm ────────────────────────────────────────────────────────────────

List<DebtTransaction> calculateMinTransactions(
  List<TripEntry> trips,
  List<TripPayment> payments,
  Map<String, String> personNames,
) {
  // Step 1: raw balances
  final Map<String, double> balance = {};

  for (final trip in trips) {
    if (trip.passengerIds.isEmpty) continue;
    final share = trip.price / trip.passengerIds.length;
    for (final pid in trip.passengerIds) {
      if (pid == trip.driverId) continue;
      balance[pid] = (balance[pid] ?? 0) - share;
      balance[trip.driverId] = (balance[trip.driverId] ?? 0) + share;
    }
  }

  // Step 2: apply payments
  for (final p in payments) {
    balance[p.fromPersonId] = (balance[p.fromPersonId] ?? 0) + p.amount;
    balance[p.toPersonId] = (balance[p.toPersonId] ?? 0) - p.amount;
  }

  // Step 3: greedy min-cash-flow
  final debtors = balance.entries
      .where((e) => e.value < -0.005)
      .map((e) => MapEntry(e.key, e.value))
      .toList()
    ..sort((a, b) => a.value.compareTo(b.value));

  final creditors = balance.entries
      .where((e) => e.value > 0.005)
      .map((e) => MapEntry(e.key, e.value))
      .toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  final result = <DebtTransaction>[];
  int di = 0;
  int ci = 0;

  while (di < debtors.length && ci < creditors.length) {
    final debtor = debtors[di];
    final creditor = creditors[ci];
    final amount = debtor.value.abs() < creditor.value
        ? debtor.value.abs()
        : creditor.value;

    if (amount > 0.005) {
      result.add(
        DebtTransaction(
          fromPersonId: debtor.key,
          fromPersonName: personNames[debtor.key] ?? debtor.key,
          toPersonId: creditor.key,
          toPersonName: personNames[creditor.key] ?? creditor.key,
          amount: double.parse(amount.toStringAsFixed(2)),
        ),
      );
    }

    debtors[di] = MapEntry(debtor.key, debtor.value + amount);
    creditors[ci] = MapEntry(creditor.key, creditor.value - amount);

    if (debtors[di].value.abs() < 0.005) di++;
    if (creditors[ci].value < 0.005) ci++;
  }

  return result;
}

Map<String, double> calculateBalances(
  List<TripEntry> trips,
  List<TripPayment> payments,
) {
  final Map<String, double> balance = {};

  for (final trip in trips) {
    if (trip.passengerIds.isEmpty) continue;
    final share = trip.price / trip.passengerIds.length;
    for (final pid in trip.passengerIds) {
      if (pid == trip.driverId) continue;
      balance[pid] = (balance[pid] ?? 0) - share;
      balance[trip.driverId] = (balance[trip.driverId] ?? 0) + share;
    }
  }

  for (final p in payments) {
    balance[p.fromPersonId] = (balance[p.fromPersonId] ?? 0) + p.amount;
    balance[p.toPersonId] = (balance[p.toPersonId] ?? 0) - p.amount;
  }

  return balance;
}

// Raw pairwise debts before netting
Map<String, Map<String, double>> calculateRawPairDebts(
  List<TripEntry> trips,
  List<TripPayment> payments,
) {
  // rawDebts[debtor][creditor] = amount owed
  final Map<String, Map<String, double>> raw = {};

  void addDebt(String debtor, String creditor, double amount) {
    raw.putIfAbsent(debtor, () => {});
    raw[debtor]![creditor] = (raw[debtor]![creditor] ?? 0) + amount;
  }

  for (final trip in trips) {
    if (trip.passengerIds.isEmpty) continue;
    final share = trip.price / trip.passengerIds.length;
    for (final pid in trip.passengerIds) {
      if (pid == trip.driverId) continue;
      addDebt(pid, trip.driverId, share);
    }
  }

  // Net payments
  for (final p in payments) {
    addDebt(p.toPersonId, p.fromPersonId, p.amount);
  }

  // Net pairs
  final pairs = <String>{};
  for (final debtor in raw.keys) {
    for (final creditor in raw[debtor]!.keys) {
      final key1 = '$debtor|$creditor';
      final key2 = '$creditor|$debtor';
      if (pairs.contains(key2)) continue;
      pairs.add(key1);

      final ab = raw[debtor]![creditor] ?? 0;
      final ba = raw[creditor]?[debtor] ?? 0;
      if (ab > ba) {
        raw[debtor]![creditor] = ab - ba;
        raw[creditor]?.remove(debtor);
      } else if (ba > ab) {
        raw[creditor]![debtor] = ba - ab;
        raw[debtor]?.remove(creditor);
      } else {
        raw[debtor]?.remove(creditor);
        raw[creditor]?.remove(debtor);
      }
    }
  }

  raw.removeWhere((_, v) => v.isEmpty);
  return raw;
}
