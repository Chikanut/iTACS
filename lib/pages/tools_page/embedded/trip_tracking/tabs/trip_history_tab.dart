import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../../globals.dart';
import '../../../../../models/trip_tracking/trip_tracking_models.dart';
import '../../../../../services/trip_tracking_service.dart';

class HistoryTab extends StatelessWidget {
  const HistoryTab({
    super.key,
    required this.groupId,
    required this.userEmail,
    required this.service,
  });

  final String groupId;
  final String userEmail;
  final TripTrackingService service;

  bool get _isAdmin {
    final role = Globals.profileManager.currentRole;
    return role == 'admin' || role == 'editor';
  }

  Future<void> _deleteTrip(BuildContext context, TripEntry trip) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Видалити поїздку?'),
        content: Text(
          'Поїздка ${DateFormat('dd.MM.yyyy').format(trip.date)} '
          'на ${trip.carName} буде видалена.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Скасувати'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Видалити'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await service.deleteTrip(groupId, trip.id);
      if (context.mounted) {
        Globals.errorNotificationManager.showSuccess('Поїздку видалено');
      }
    } catch (e) {
      if (context.mounted) {
        Globals.errorNotificationManager.showError('Помилка: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('dd MMM yyyy', 'uk');

    return StreamBuilder<List<TripEntry>>(
      stream: service.watchTrips(groupId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final trips = snap.data ?? [];
        if (trips.isEmpty) {
          return const Center(child: Text('Поїздок ще немає'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: trips.length,
          itemBuilder: (ctx, i) {
            final trip = trips[i];
            final share = trip.sharePerPerson;
            final canDelete =
                _isAdmin || trip.createdByEmail == userEmail;

            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          dateFmt.format(trip.date),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        Text(
                          '${trip.price.toStringAsFixed(0)} ₴',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        if (canDelete)
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              size: 18,
                              color: Colors.red,
                            ),
                            onPressed: () => _deleteTrip(context, trip),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.directions_car,
                            size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          trip.carName,
                          style: const TextStyle(fontSize: 13),
                        ),
                        const SizedBox(width: 12),
                        const Icon(Icons.route, size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            trip.routeName,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: trip.passengerIds.map((pid) {
                        final name = trip.passengerNames[pid] ?? pid;
                        final isDriver = pid == trip.driverId;
                        return Chip(
                          label: Text(
                            isDriver ? '🚗 $name' : name,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDriver ? Colors.green[800] : null,
                            ),
                          ),
                          backgroundColor: isDriver
                              ? Colors.green.withOpacity(0.1)
                              : null,
                          padding: EdgeInsets.zero,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Частка: ${share.toStringAsFixed(2)} ₴ / особу',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
