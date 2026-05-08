import 'package:flutter/material.dart';

import '../../../../globals.dart';
import '../../../../models/trip_tracking/trip_tracking_models.dart';
import '../../../../services/trip_tracking_service.dart';
import 'tabs/trip_new_trip_tab.dart';
import 'tabs/trip_debts_tab.dart';
import 'tabs/trip_history_tab.dart';
import 'tabs/trip_cars_tab.dart';
import 'tabs/trip_people_tab.dart';

class TripTrackingPage extends StatefulWidget {
  const TripTrackingPage({super.key});

  @override
  State<TripTrackingPage> createState() => _TripTrackingPageState();
}

class _TripTrackingPageState extends State<TripTrackingPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _service = TripTrackingService();

  // Shared state streams — all tabs read these
  List<TripCar> _cars = [];
  List<TripPerson> _people = [];
  List<TripEntry> _trips = [];
  List<TripPayment> _payments = [];

  bool _loading = true;

  String? get _groupId => Globals.profileManager.currentGroupId;
  String get _userEmail => Globals.firebaseAuth.currentUser?.email ?? '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    final gid = _groupId;
    if (gid == null) return;
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _service.getCars(gid),
        _service.getPeople(gid),
      ]);
      if (mounted) {
        setState(() {
          _cars = results[0] as List<TripCar>;
          _people = results[1] as List<TripPerson>;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        Globals.errorNotificationManager.showError('Помилка завантаження: $e');
      }
    }
  }

  void _onCarsChanged(List<TripCar> cars) => setState(() => _cars = cars);
  void _onPeopleChanged(List<TripPerson> people) =>
      setState(() => _people = people);
  void _onTripsChanged(List<TripEntry> trips) => setState(() => _trips = trips);
  void _onPaymentsChanged(List<TripPayment> payments) =>
      setState(() => _payments = payments);

  @override
  Widget build(BuildContext context) {
    final gid = _groupId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Облік поїздок'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.add_road), text: 'Поїздка'),
            Tab(icon: Icon(Icons.account_balance_wallet), text: 'Борги'),
            Tab(icon: Icon(Icons.history), text: 'Історія'),
            Tab(icon: Icon(Icons.directions_car), text: 'Машини'),
            Tab(icon: Icon(Icons.people), text: 'Люди'),
          ],
        ),
      ),
      body: gid == null || _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                NewTripTab(
                  groupId: gid,
                  userEmail: _userEmail,
                  cars: _cars,
                  people: _people,
                  service: _service,
                  onTripAdded: () =>
                      _service.watchTrips(gid).first.then(_onTripsChanged),
                ),
                DebtsTab(
                  groupId: gid,
                  userEmail: _userEmail,
                  service: _service,
                  people: _people,
                  cars: _cars,
                ),
                HistoryTab(
                  groupId: gid,
                  userEmail: _userEmail,
                  service: _service,
                ),
                CarsTab(
                  groupId: gid,
                  userEmail: _userEmail,
                  service: _service,
                  onChanged: _onCarsChanged,
                ),
                PeopleTab(
                  groupId: gid,
                  service: _service,
                  onChanged: _onPeopleChanged,
                ),
              ],
            ),
    );
  }
}
