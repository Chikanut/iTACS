import 'package:flutter/material.dart';

import '../../../../../globals.dart';
import '../../../../../models/trip_tracking/trip_tracking_models.dart';
import '../../../../../services/trip_tracking_service.dart';

class PeopleTab extends StatefulWidget {
  const PeopleTab({
    super.key,
    required this.groupId,
    required this.service,
    required this.onChanged,
  });

  final String groupId;
  final TripTrackingService service;
  final ValueChanged<List<TripPerson>> onChanged;

  @override
  State<PeopleTab> createState() => _PeopleTabState();
}

class _PeopleTabState extends State<PeopleTab> {
  bool get _canManage {
    final role = Globals.profileManager.currentRole;
    return role == 'admin' || role == 'editor';
  }

  Future<void> _showPersonDialog({TripPerson? person}) async {
    final nameCtrl = TextEditingController(text: person?.name ?? '');
    final emailCtrl = TextEditingController(text: person?.email ?? '');

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(person == null ? 'Новий учасник' : 'Редагувати учасника'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: "Ім'я *",
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emailCtrl,
              decoration: const InputDecoration(
                labelText: 'Email (необов\'язково)',
                border: OutlineInputBorder(),
                helperText: 'Для прив\'язки до акаунту',
              ),
              keyboardType: TextInputType.emailAddress,
            ),
          ],
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
              try {
                if (person == null) {
                  final p = widget.service.newPerson(
                    name: name,
                    email: emailCtrl.text.trim(),
                  );
                  await widget.service.addPerson(widget.groupId, p);
                } else {
                  await widget.service.updatePerson(
                    widget.groupId,
                    person.copyWith(
                      name: name,
                      email: emailCtrl.text.trim(),
                    ),
                  );
                }
                if (ctx.mounted) Navigator.pop(ctx);
                await _reload();
              } catch (e) {
                Globals.errorNotificationManager.showError('Помилка: $e');
              }
            },
            child: const Text('Зберегти'),
          ),
        ],
      ),
    );
  }

  Future<void> _deletePerson(TripPerson person) async {
    final used =
        await widget.service.isPersonUsedInTrips(widget.groupId, person.id);
    if (!mounted) return;

    if (used) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Учасник є в поїздках'),
          content: Text(
            '${person.name} вже фігурує в поїздках. Видалити все одно?',
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
    }

    try {
      await widget.service.deletePerson(widget.groupId, person.id);
      await _reload();
      if (mounted) {
        Globals.errorNotificationManager.showSuccess('${person.name} видалено');
      }
    } catch (e) {
      if (mounted) {
        Globals.errorNotificationManager.showError('Помилка: $e');
      }
    }
  }

  Future<void> _reload() async {
    final people = await widget.service.getPeople(widget.groupId);
    if (mounted) widget.onChanged(people);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<TripPerson>>(
      stream: widget.service.watchPeople(widget.groupId),
      builder: (context, snap) {
        final people = snap.data ?? [];
        return Scaffold(
          body: people.isEmpty
              ? const Center(child: Text('Учасники ще не додані'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: people.length,
                  itemBuilder: (ctx, i) {
                    final p = people[i];
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Text(
                            p.name.isNotEmpty ? p.name[0].toUpperCase() : '?',
                          ),
                        ),
                        title: Text(p.name),
                        subtitle: p.email.isNotEmpty
                            ? Text(
                                p.email,
                                style: const TextStyle(fontSize: 12),
                              )
                            : null,
                        trailing: _canManage
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined),
                                    onPressed: () =>
                                        _showPersonDialog(person: p),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: Colors.red,
                                    ),
                                    onPressed: () => _deletePerson(p),
                                  ),
                                ],
                              )
                            : null,
                      ),
                    );
                  },
                ),
          floatingActionButton: _canManage
              ? FloatingActionButton(
                  onPressed: _showPersonDialog,
                  child: const Icon(Icons.add),
                )
              : null,
        );
      },
    );
  }
}
