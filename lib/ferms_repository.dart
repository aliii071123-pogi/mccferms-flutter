import 'api_client.dart';
import 'ferms_models.dart';

class FermsRepository {
  const FermsRepository(this.api);

  final FermsApiClient api;

  Future<FermsUser> me() async =>
      FermsUser.fromJson(asJsonMap(unwrapData(await api.get('/api/v1/me'))));

  Future<dynamic> dashboard() => api.get('/api/v1/dashboard');

  Future<List<Facility>> facilities() async =>
      asJsonList(await api.get('/api/v1/facilities'))
          .map(Facility.fromJson)
          .toList();

  Future<List<Equipment>> equipment() async =>
      asJsonList(await api.get('/api/v1/equipment'))
          .map(Equipment.fromJson)
          .toList();

  Future<List<Organization>> organizations() async =>
      asJsonList(await api.get('/api/v1/organizations'))
          .map(Organization.fromJson)
          .toList();

  Future<List<CalendarEntry>> calendar(DateTime month) async => asJsonList(
    await api.get(
      '/api/v1/calendar',
      queryParameters: {
        'month':
            '${month.year.toString().padLeft(4, '0')}-'
            '${month.month.toString().padLeft(2, '0')}',
      },
    ),
  ).map(CalendarEntry.fromJson).toList();

  Future<List<Reservation>> reservations({bool history = false}) async =>
      asJsonList(
        await api.get(
          '/api/v1/reservations',
          queryParameters: history ? {'view': 'history'} : null,
        ),
      ).map(Reservation.fromJson).toList();

  Future<Reservation> createReservation(JsonMap payload) async =>
      Reservation.fromJson(
        asJsonMap(
          unwrapData(await api.post('/api/v1/reservations', body: payload)),
        ),
      );

  Future<Reservation> updateReservation(String id, JsonMap payload) async =>
      Reservation.fromJson(
        asJsonMap(
          unwrapData(await api.put('/api/v1/reservations/$id', body: payload)),
        ),
      );

  Future<void> cancelReservation(String id) async =>
      api.delete('/api/v1/reservations/$id/cancel');

  Future<void> decideReservation(String id, String status) async =>
      api.put('/api/v1/reservations/$id/decision', body: {'status': status});

  Future<void> deleteReservation(String id) async =>
      api.delete('/api/v1/reservations/$id');

  Future<void> saveProfile({
    required String organization,
    required String position,
  }) async => api.put(
    '/api/v1/profile',
    body: {'organization': organization.trim(), 'position': position.trim()},
  );

  Future<void> saveFacility(JsonMap payload, {String? id}) async {
    if (id == null) {
      await api.post('/api/v1/facilities', body: payload);
    } else {
      await api.put('/api/v1/facilities/$id', body: payload);
    }
  }

  Future<void> deleteFacility(String id) async =>
      api.delete('/api/v1/facilities/$id');

  Future<void> saveEquipment(JsonMap payload, {String? id}) async {
    if (id == null) {
      await api.post('/api/v1/equipment', body: payload);
    } else {
      await api.put('/api/v1/equipment/$id', body: payload);
    }
  }

  Future<void> deleteEquipment(String id) async =>
      api.delete('/api/v1/equipment/$id');
}
