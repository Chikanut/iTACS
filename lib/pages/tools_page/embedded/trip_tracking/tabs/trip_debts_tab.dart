import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../../globals.dart';
import '../../../../../models/trip_tracking/trip_tracking_models.dart';
import '../../../../../services/trip_tracking_service.dart';

class DebtsTab extends StatelessWidget {
  const DebtsTab({
    super.key,
    required this.groupId,
    required this.userEmail,
    required this.service,
    required this.people,
    required this.cars,
  });

  final String groupId;
  final String userEmail;
  final TripTrackingService service;
  final List<TripPerson> people;
  final List<TripCar> cars;

  Map<String, String> get _personNames =>
      {for (final p in people) p.id: p.name};

  // Current user's person record (matched by email)
  TripPerson? get _myPerson {
    try {
      return people.firstWhere((p) => p.email == userEmail);
    } catch (_) {
      return null;
    }
  }

  // Cars owned by current user (driver can close debts on their car)
  Set<String> get _myCarIds {
    return cars.where((c) => c.ownerEmail == userEmail).map((c) => c.id).toSet();
  }

  bool get _isAdmin {
    final role = Globals.profileManager.currentRole;
    return role == 'admin' || role == 'editor';
  }

  Future<void> _markAsPaid(
    BuildContext context,
    List<TripEntry> trips,
    List<TripPayment> payments,
    DebtTransaction debt,
  ) async {
    // Find trips where the debtor owes the creditor
    final relevantTrips = trips.where((t) {
      if (t.driverId != debt.toPersonId) return false;
      return t.passengerIds.contains(debt.fromPersonId);
    }).toList();

    // Check if current user is the creditor (driver)
    final myPerson = _myPerson;
    final isCreditor = myPerson?.id == debt.toPersonId;
    final canClose = _isAdmin || isCreditor;

    if (!canClose) {
      Globals.errorNotificationManager.showError(
        'Тільки водій може закрити цей борг',
      );
      return;
    }

    final amountCtrl = TextEditingController(
      text: debt.amount.toStringAsFixed(2),
    );
    final noteCtrl = TextEditingController();
    final selectedTripIds = <String>{};

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Закрити борг'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${debt.fromPersonName} → ${debt.toPersonName}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Сума ₴',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Примітка (необов\'язково)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (relevantTrips.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'Пов\'язані поїздки (необов\'язково):',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    ...relevantTrips.map((t) {
                      final fmt = DateFormat('dd.MM.yy');
                      return CheckboxListTile(
                        dense: true,
                        value: selectedTripIds.contains(t.id),
                        onChanged: (v) {
                          setS(() {
                            if (v == true) {
                              selectedTripIds.add(t.id);
                            } else {
                              selectedTripIds.remove(t.id);
                            }
                          });
                        },
                        title: Text(
                          '${fmt.format(t.date)} — ${t.routeName} '
                          '(${(t.price / t.passengerIds.length).toStringAsFixed(0)} ₴)',
                          style: const TextStyle(fontSize: 13),
                        ),
                        contentPadding: EdgeInsets.zero,
                      );
                    }),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Скасувати'),
            ),
            ElevatedButton(
              onPressed: () async {
                final amount =
                    double.tryParse(amountCtrl.text.trim()) ?? 0;
                if (amount <= 0) return;

                final fromPerson = people.firstWhere(
                  (p) => p.id == debt.fromPersonId,
                  orElse: () => TripPerson(
                    id: debt.fromPersonId,
                    name: debt.fromPersonName,
                    createdAt: DateTime.now(),
                  ),
                );
                final toPerson = people.firstWhere(
                  (p) => p.id == debt.toPersonId,
                  orElse: () => TripPerson(
                    id: debt.toPersonId,
                    name: debt.toPersonName,
                    createdAt: DateTime.now(),
                  ),
                );

                final payment = service.newPayment(
                  from: fromPerson,
                  to: toPerson,
                  amount: amount,
                  tripIds: selectedTripIds.toList(),
                  note: noteCtrl.text.trim(),
                  createdByEmail: userEmail,
                );

                try {
                  await service.addPayment(groupId, payment);
                  if (ctx.mounted) Navigator.pop(ctx);
                  Globals.errorNotificationManager.showSuccess('Борг закрито');
                } catch (e) {
                  Globals.errorNotificationManager.showError('Помилка: $e');
                }
              },
              child: const Text('Підтвердити оплату'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<TripEntry>>(
      stream: service.watchTrips(groupId),
      builder: (context, tripSnap) {
        return StreamBuilder<List<TripPayment>>(
          stream: service.watchPayments(groupId),
          builder: (context, paySnap) {
            if (tripSnap.connectionState == ConnectionState.waiting ||
                paySnap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final trips = tripSnap.data ?? [];
            final payments = paySnap.data ?? [];
            final names = _personNames;

            final minTransactions = calculateMinTransactions(
              trips,
              payments,
              names,
            );
            final balances = calculateBalances(trips, payments);

            final hasAnyDebt = minTransactions.isNotEmpty;

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── Min transactions ──────────────────────────────────────
                const Text(
                  'Мінімум переказів',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                if (!hasAnyDebt)
                  Card(
                    color: Colors.green.withOpacity(0.1),
                    child: const ListTile(
                      leading: Icon(Icons.check_circle, color: Colors.green),
                      title: Text('Усі борги закриті 🎉'),
                    ),
                  )
                else
                  ...minTransactions.map((debt) {
                    final myPerson = _myPerson;
                    final isCreditor = myPerson?.id == debt.toPersonId;
                    final isDebtor = myPerson?.id == debt.fromPersonId;
                    final canClose = _isAdmin || isCreditor;

                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.orange.withOpacity(0.2),
                          child: const Icon(
                            Icons.arrow_forward,
                            color: Colors.orange,
                          ),
                        ),
                        title: Text(
                          '${debt.fromPersonName} → ${debt.toPersonName}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: isDebtor
                            ? const Text(
                                'Ви маєте сплатити',
                                style: TextStyle(color: Colors.red),
                              )
                            : isCreditor
                                ? const Text(
                                    'Вам мають сплатити',
                                    style: TextStyle(color: Colors.green),
                                  )
                                : null,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${debt.amount.toStringAsFixed(2)} ₴',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            if (canClose)
                              IconButton(
                                icon: const Icon(
                                  Icons.check_circle_outline,
                                  color: Colors.green,
                                ),
                                tooltip: 'Закрити борг',
                                onPressed: () => _markAsPaid(
                                  context,
                                  trips,
                                  payments,
                                  debt,
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  }),

                const SizedBox(height: 24),

                // ── Balances ──────────────────────────────────────────────
                ExpansionTile(
                  title: const Text(
                    'Баланс по учасниках',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  children: balances.entries
                      .where((e) => e.value.abs() > 0.01)
                      .map((e) {
                        final name = names[e.key] ?? e.key;
                        final isPositive = e.value > 0;
                        return ListTile(
                          dense: true,
                          title: Text(name),
                          trailing: Text(
                            '${isPositive ? '+' : ''}${e.value.toStringAsFixed(2)} ₴',
                            style: TextStyle(
                              color: isPositive ? Colors.green : Colors.red,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            isPositive ? 'кредитор' : 'боржник',
                            style: const TextStyle(fontSize: 11),
                          ),
                        );
                      })
                      .toList(),
                ),

                const SizedBox(height: 8),

                // ── Payment history ───────────────────────────────────────
                ExpansionTile(
                  title: const Text(
                    'Історія закриттів боргів',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  children: payments.isEmpty
                      ? [
                          const ListTile(
                            dense: true,
                            title: Text('Закриттів ще немає'),
                          ),
                        ]
                      : payments.map((p) {
                          final fmt = DateFormat('dd.MM.yy');
                          return ListTile(
                            dense: true,
                            leading: const Icon(
                              Icons.payment,
                              color: Colors.green,
                            ),
                            title: Text(
                              '${p.fromPersonName} → ${p.toPersonName}: '
                              '${p.amount.toStringAsFixed(2)} ₴',
                            ),
                            subtitle: Text(
                              '${fmt.format(p.createdAt)}'
                              '${p.note.isNotEmpty ? ' · ${p.note}' : ''}',
                              style: const TextStyle(fontSize: 11),
                            ),
                            trailing: _isAdmin
                                ? IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      size: 18,
                                      color: Colors.red,
                                    ),
                                    onPressed: () async {
                                      try {
                                        await service.deletePayment(
                                          groupId,
                                          p.id,
                                        );
                                      } catch (e) {
                                        Globals.errorNotificationManager
                                            .showError('Помилка: $e');
                                      }
                                    },
                                  )
                                : null,
                          );
                        }).toList(),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
