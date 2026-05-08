import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../../../globals.dart';
import '../../../../../models/trip_tracking/trip_tracking_models.dart';
import '../../../../../services/trip_tracking_service.dart';

class CarsTab extends StatefulWidget {
  const CarsTab({
    super.key,
    required this.groupId,
    required this.userEmail,
    required this.service,
    required this.onChanged,
  });

  final String groupId;
  final String userEmail;
  final TripTrackingService service;
  final ValueChanged<List<TripCar>> onChanged;

  @override
  State<CarsTab> createState() => _CarsTabState();
}

class _CarsTabState extends State<CarsTab> {
  static const _uuid = Uuid();

  bool get _isAdmin {
    final role = Globals.profileManager.currentRole;
    return role == 'admin' || role == 'editor';
  }

  Future<void> _showCarDialog({TripCar? car}) async {
    final nameCtrl = TextEditingController(text: car?.name ?? '');
    final ownerCtrl = TextEditingController(
      text: car?.ownerEmail ?? widget.userEmail,
    );
    final routes = List<TripRoute>.from(car?.routes ?? []);

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(car == null ? 'Нова машина' : 'Редагувати машину'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Назва машини *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: ownerCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Email власника',
                      border: OutlineInputBorder(),
                      helperText: 'Хто може додавати поїздки на цій машині',
                    ),
                    enabled: _isAdmin,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text(
                        'Маршрути',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () {
                          setS(() {
                            routes.add(
                              TripRoute(
                                id: _uuid.v4(),
                                name: '',
                                price: 0,
                              ),
                            );
                          });
                        },
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Додати'),
                      ),
                    ],
                  ),
                  ...routes.asMap().entries.map((e) {
                    final i = e.key;
                    final r = e.value;
                    final routeNameCtrl = TextEditingController(text: r.name);
                    final routePriceCtrl = TextEditingController(
                      text: r.price > 0 ? r.price.toString() : '',
                    );
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextField(
                              controller: routeNameCtrl,
                              decoration: InputDecoration(
                                labelText: 'Маршрут ${i + 1}',
                                border: const OutlineInputBorder(),
                                isDense: true,
                              ),
                              onChanged: (v) {
                                routes[i] = routes[i].copyWith(name: v);
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: routePriceCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Ціна ₴',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (v) {
                                routes[i] = routes[i].copyWith(
                                  price: double.tryParse(v) ?? 0,
                                );
                              },
                            ),
                          ),
                          IconButton(
                            onPressed: () => setS(() => routes.removeAt(i)),
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.red,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
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
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                final validRoutes =
                    routes.where((r) => r.name.isNotEmpty).toList();
                try {
                  if (car == null) {
                    final newCar = widget.service.newCar(
                      name: name,
                      ownerEmail: ownerCtrl.text.trim(),
                      routes: validRoutes,
                    );
                    await widget.service.addCar(widget.groupId, newCar);
                  } else {
                    await widget.service.updateCar(
                      widget.groupId,
                      car.copyWith(
                        name: name,
                        ownerEmail: ownerCtrl.text.trim(),
                        routes: validRoutes,
                      ),
                    );
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                  await _reload();
                } catch (e) {
                  Globals.errorNotificationManager.showError(
                    'Помилка: $e',
                  );
                }
              },
              child: const Text('Зберегти'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteCar(TripCar car) async {
    final used = await widget.service.isCarUsedInTrips(widget.groupId, car.id);
    if (!mounted) return;

    if (used) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Машина використовується'),
          content: Text(
            '${car.name} вже є в поїздках. '
            'Видалення машини не видалить пов\'язані поїздки.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Скасувати'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: const Text('Все одно видалити'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    try {
      await widget.service.deleteCar(widget.groupId, car.id);
      await _reload();
      if (mounted) {
        Globals.errorNotificationManager.showSuccess(
          '${car.name} видалено',
        );
      }
    } catch (e) {
      if (mounted) {
        Globals.errorNotificationManager.showError('Помилка: $e');
      }
    }
  }

  Future<void> _reload() async {
    final cars = await widget.service.getCars(widget.groupId);
    if (mounted) widget.onChanged(cars);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<TripCar>>(
      stream: widget.service.watchCars(widget.groupId),
      builder: (context, snap) {
        final cars = snap.data ?? [];
        return Scaffold(
          body: cars.isEmpty
              ? const Center(child: Text('Машини ще не додані'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: cars.length,
                  itemBuilder: (ctx, i) {
                    final car = cars[i];
                    final isOwner = car.ownerEmail == widget.userEmail;
                    final canEdit = _isAdmin || isOwner;
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Text(
                            car.name.isNotEmpty
                                ? car.name[0].toUpperCase()
                                : '?',
                          ),
                        ),
                        title: Text(
                          car.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (car.routes.isEmpty)
                              const Text('Маршрути не вказані',
                                  style: TextStyle(fontSize: 12))
                            else
                              ...car.routes.map(
                                (r) => Text(
                                  '${r.name}: ${r.price.toStringAsFixed(0)} ₴',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            Text(
                              car.ownerEmail,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                        isThreeLine: true,
                        trailing: canEdit
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined),
                                    onPressed: () =>
                                        _showCarDialog(car: car),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: Colors.red,
                                    ),
                                    onPressed: () => _deleteCar(car),
                                  ),
                                ],
                              )
                            : null,
                      ),
                    );
                  },
                ),
          floatingActionButton: FloatingActionButton(
            onPressed: _showCarDialog,
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }
}
