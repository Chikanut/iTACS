import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../../globals.dart';
import '../../../../../models/trip_tracking/trip_tracking_models.dart';
import '../../../../../services/trip_tracking_service.dart';

class NewTripTab extends StatefulWidget {
  const NewTripTab({
    super.key,
    required this.groupId,
    required this.userEmail,
    required this.cars,
    required this.people,
    required this.service,
    required this.onTripAdded,
  });

  final String groupId;
  final String userEmail;
  final List<TripCar> cars;
  final List<TripPerson> people;
  final TripTrackingService service;
  final VoidCallback onTripAdded;

  @override
  State<NewTripTab> createState() => _NewTripTabState();
}

class _NewTripTabState extends State<NewTripTab> {
  DateTime _date = DateTime.now();
  TripCar? _selectedCar;
  TripPerson? _selectedDriver;
  TripRoute? _selectedRoute;
  bool _useCustomPrice = false;
  final _customPriceCtrl = TextEditingController();
  final Set<String> _passengerIds = {};
  bool _saving = false;

  List<TripCar> get _myCars {
    final role = Globals.profileManager.currentRole;
    if (role == 'admin' || role == 'editor') return widget.cars;
    return widget.cars
        .where((c) => c.ownerEmail == widget.userEmail)
        .toList();
  }

  List<TripRoute> get _carRoutes => _selectedCar?.routes ?? [];

  @override
  void dispose() {
    _customPriceCtrl.dispose();
    super.dispose();
  }

  void _onCarChanged(TripCar? car) {
    setState(() {
      _selectedCar = car;
      _selectedRoute = car?.routes.isNotEmpty == true ? car!.routes.first : null;
      _useCustomPrice = car?.routes.isEmpty == true;
    });
  }

  void _onDriverChanged(TripPerson? driver) {
    setState(() {
      _selectedDriver = driver;
      if (driver != null) {
        _passengerIds.add(driver.id);
      }
    });
  }

  void _togglePassenger(String personId, bool selected) {
    setState(() {
      if (selected) {
        _passengerIds.add(personId);
      } else {
        if (personId != _selectedDriver?.id) {
          _passengerIds.remove(personId);
        }
      }
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  double get _effectivePrice {
    if (_useCustomPrice || _selectedRoute == null) {
      return double.tryParse(_customPriceCtrl.text) ?? 0;
    }
    return _selectedRoute!.price;
  }

  Future<void> _submit() async {
    if (_selectedCar == null) {
      Globals.errorNotificationManager.showError('Оберіть машину');
      return;
    }
    if (_selectedDriver == null) {
      Globals.errorNotificationManager.showError('Оберіть водія');
      return;
    }
    if (_passengerIds.isEmpty) {
      Globals.errorNotificationManager.showError('Додайте хоча б одного пасажира');
      return;
    }
    if (_effectivePrice <= 0) {
      Globals.errorNotificationManager.showError('Вкажіть ціну поїздки');
      return;
    }

    final passengers = widget.people
        .where((p) => _passengerIds.contains(p.id))
        .toList();

    setState(() => _saving = true);
    try {
      final trip = widget.service.newTrip(
        date: _date,
        car: _selectedCar!,
        driver: _selectedDriver!,
        passengers: passengers,
        route: _useCustomPrice ? null : _selectedRoute,
        customPrice: _useCustomPrice ? _effectivePrice : null,
        createdByEmail: widget.userEmail,
      );
      await widget.service.addTrip(widget.groupId, trip);

      if (mounted) {
        Globals.errorNotificationManager.showSuccess('Поїздку додано');
        widget.onTripAdded();
        setState(() {
          _date = DateTime.now();
          _selectedDriver = null;
          _passengerIds.clear();
          _customPriceCtrl.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        Globals.errorNotificationManager.showError('Помилка: $e');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd MMM yyyy', 'uk');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date
          Card(
            child: ListTile(
              leading: const Icon(Icons.calendar_today),
              title: Text(fmt.format(_date)),
              subtitle: const Text('Дата поїздки'),
              onTap: _pickDate,
            ),
          ),
          const SizedBox(height: 12),

          // Car picker
          _SectionLabel(label: 'Машина'),
          if (_myCars.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'У вас немає машин. Додайте машину на вкладці "Машини".',
                style: TextStyle(color: Colors.orange),
              ),
            )
          else
            DropdownButtonFormField<TripCar>(
              value: _selectedCar,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.directions_car),
              ),
              hint: const Text('Оберіть машину'),
              items: _myCars
                  .map(
                    (c) => DropdownMenuItem(
                      value: c,
                      child: Text(c.name),
                    ),
                  )
                  .toList(),
              onChanged: _onCarChanged,
            ),
          const SizedBox(height: 12),

          // Route picker
          if (_selectedCar != null) ...[
            _SectionLabel(label: 'Маршрут / Ціна'),
            if (_carRoutes.isNotEmpty) ...[
              ...(_carRoutes.map(
                (r) => RadioListTile<TripRoute>(
                  value: r,
                  groupValue: _useCustomPrice ? null : _selectedRoute,
                  onChanged: (v) =>
                      setState(() {
                        _selectedRoute = v;
                        _useCustomPrice = false;
                      }),
                  title: Text(r.name),
                  subtitle: Text('${r.price.toStringAsFixed(0)} ₴'),
                  contentPadding: EdgeInsets.zero,
                ),
              )),
              RadioListTile<bool>(
                value: true,
                groupValue: _useCustomPrice,
                onChanged: (_) => setState(() => _useCustomPrice = true),
                title: const Text('Свій маршрут'),
                contentPadding: EdgeInsets.zero,
              ),
            ],
            if (_useCustomPrice || _carRoutes.isEmpty)
              TextField(
                controller: _customPriceCtrl,
                decoration: const InputDecoration(
                  labelText: 'Ціна поїздки ₴ *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.attach_money),
                ),
                keyboardType: TextInputType.number,
              ),
            const SizedBox(height: 12),
          ],

          // Driver
          _SectionLabel(label: 'Водій'),
          DropdownButtonFormField<TripPerson>(
            value: _selectedDriver,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.person),
            ),
            hint: const Text('Оберіть водія'),
            items: widget.people
                .map(
                  (p) => DropdownMenuItem(
                    value: p,
                    child: Text(p.name),
                  ),
                )
                .toList(),
            onChanged: _onDriverChanged,
          ),
          const SizedBox(height: 12),

          // Passengers
          _SectionLabel(label: 'Пасажири'),
          if (widget.people.isEmpty)
            const Text('Додайте учасників на вкладці "Люди"')
          else
            Card(
              child: Column(
                children: widget.people.map((p) {
                  final isDriver = p.id == _selectedDriver?.id;
                  return CheckboxListTile(
                    value: _passengerIds.contains(p.id),
                    onChanged: isDriver
                        ? null
                        : (v) => _togglePassenger(p.id, v ?? false),
                    title: Row(
                      children: [
                        Text(p.name),
                        if (isDriver) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              '🚗 водій',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.green,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),

          const SizedBox(height: 24),

          // Price preview
          if (_selectedCar != null && _passengerIds.isNotEmpty && _effectivePrice > 0)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Частка на людину:'),
                  Text(
                    '${(_effectivePrice / _passengerIds.length).toStringAsFixed(2)} ₴',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _saving ? null : _submit,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_road),
              label: const Text('Додати поїздку'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
      ),
    );
  }
}
