import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../models/trip_tracking/trip_tracking_models.dart';

class TripTrackingService {
  FirebaseFirestore get _db => FirebaseFirestore.instance;
  static const _uuid = Uuid();

  // ─── Collection refs ────────────────────────────────────────────────────────

  CollectionReference _cars(String groupId) =>
      _db.collection('trips_by_group').doc(groupId).collection('cars');

  CollectionReference _people(String groupId) =>
      _db.collection('trips_by_group').doc(groupId).collection('people');

  CollectionReference _trips(String groupId) =>
      _db.collection('trips_by_group').doc(groupId).collection('trips');

  CollectionReference _payments(String groupId) =>
      _db.collection('trips_by_group').doc(groupId).collection('payments');

  // ─── Cars ────────────────────────────────────────────────────────────────────

  Stream<List<TripCar>> watchCars(String groupId) {
    return _cars(groupId)
        .orderBy('name')
        .snapshots()
        .map((s) => s.docs.map(TripCar.fromDoc).toList());
  }

  Future<List<TripCar>> getCars(String groupId) async {
    final snap = await _cars(groupId).orderBy('name').get();
    return snap.docs.map(TripCar.fromDoc).toList();
  }

  Future<void> addCar(String groupId, TripCar car) async {
    await _cars(groupId).doc(car.id).set(car.toMap());
  }

  Future<void> updateCar(String groupId, TripCar car) async {
    await _cars(groupId).doc(car.id).update(car.toMap());
  }

  Future<void> deleteCar(String groupId, String carId) async {
    await _cars(groupId).doc(carId).delete();
  }

  TripCar newCar({
    required String name,
    required String ownerEmail,
    required List<TripRoute> routes,
  }) => TripCar(
    id: _uuid.v4(),
    name: name,
    ownerEmail: ownerEmail,
    routes: routes,
    createdAt: DateTime.now(),
  );

  // ─── People ──────────────────────────────────────────────────────────────────

  Stream<List<TripPerson>> watchPeople(String groupId) {
    return _people(groupId)
        .orderBy('name')
        .snapshots()
        .map((s) => s.docs.map(TripPerson.fromDoc).toList());
  }

  Future<List<TripPerson>> getPeople(String groupId) async {
    final snap = await _people(groupId).orderBy('name').get();
    return snap.docs.map(TripPerson.fromDoc).toList();
  }

  Future<void> addPerson(String groupId, TripPerson person) async {
    await _people(groupId).doc(person.id).set(person.toMap());
  }

  Future<void> updatePerson(String groupId, TripPerson person) async {
    await _people(groupId).doc(person.id).update(person.toMap());
  }

  Future<void> deletePerson(String groupId, String personId) async {
    await _people(groupId).doc(personId).delete();
  }

  TripPerson newPerson({required String name, String email = ''}) => TripPerson(
    id: _uuid.v4(),
    name: name,
    email: email,
    createdAt: DateTime.now(),
  );

  // ─── Trips ───────────────────────────────────────────────────────────────────

  Stream<List<TripEntry>> watchTrips(String groupId) {
    return _trips(groupId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((s) => s.docs.map(TripEntry.fromDoc).toList());
  }

  Future<void> addTrip(String groupId, TripEntry trip) async {
    await _trips(groupId).doc(trip.id).set(trip.toMap());
  }

  Future<void> deleteTrip(String groupId, String tripId) async {
    await _trips(groupId).doc(tripId).delete();
  }

  TripEntry newTrip({
    required DateTime date,
    required TripCar car,
    required TripPerson driver,
    required List<TripPerson> passengers,
    TripRoute? route,
    double? customPrice,
    required String createdByEmail,
  }) {
    final price = route?.price ?? customPrice ?? 0;
    final routeName = route?.name ?? 'Власний маршрут';
    final passengerIds = passengers.map((p) => p.id).toList();
    final passengerNames = {for (final p in passengers) p.id: p.name};

    return TripEntry(
      id: _uuid.v4(),
      date: date,
      carId: car.id,
      carName: car.name,
      driverId: driver.id,
      driverName: driver.name,
      passengerIds: passengerIds,
      passengerNames: passengerNames,
      routeId: route?.id,
      routeName: routeName,
      price: price,
      createdAt: DateTime.now(),
      createdByEmail: createdByEmail,
    );
  }

  // ─── Payments ────────────────────────────────────────────────────────────────

  Stream<List<TripPayment>> watchPayments(String groupId) {
    return _payments(groupId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(TripPayment.fromDoc).toList());
  }

  Future<void> addPayment(String groupId, TripPayment payment) async {
    await _payments(groupId).doc(payment.id).set(payment.toMap());
  }

  Future<void> deletePayment(String groupId, String paymentId) async {
    await _payments(groupId).doc(paymentId).delete();
  }

  TripPayment newPayment({
    required TripPerson from,
    required TripPerson to,
    required double amount,
    List<String> tripIds = const [],
    String note = '',
    required String createdByEmail,
  }) => TripPayment(
    id: _uuid.v4(),
    fromPersonId: from.id,
    fromPersonName: from.name,
    toPersonId: to.id,
    toPersonName: to.name,
    amount: amount,
    tripIds: tripIds,
    note: note,
    createdAt: DateTime.now(),
    createdByEmail: createdByEmail,
  );

  // ─── Check if person/car is used in trips ────────────────────────────────────

  Future<bool> isCarUsedInTrips(String groupId, String carId) async {
    final snap = await _trips(
      groupId,
    ).where('carId', isEqualTo: carId).limit(1).get();
    return snap.docs.isNotEmpty;
  }

  Future<bool> isPersonUsedInTrips(String groupId, String personId) async {
    final snap = await _trips(
      groupId,
    ).where('passengerIds', arrayContains: personId).limit(1).get();
    return snap.docs.isNotEmpty;
  }
}
