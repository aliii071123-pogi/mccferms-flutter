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

  Future<List<Reservation>> reservations({
    required FermsUser user,
    bool history = false,
  }) async {
    final reservations = asJsonList(
      await api.get(
        '/api/v1/reservations',
        queryParameters: history ? {'view': 'history'} : null,
      ),
    ).map(Reservation.fromJson).toList();
    if (user.normalizedRole != 'student') return reservations;
    return reservations
        .where((reservation) => reservation.requesterId == user.id)
        .toList();
  }

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

  Future<void> recommendReservation(String id) async =>
      api.post('/api/v1/reservations/$id/recommend');

  Future<void> submitFeedback({
    required FermsUser user,
    required int rating,
    required String comment,
    required bool anonymous,
  }) async {
    if (rating < 1 || rating > 5 || comment.trim().isEmpty) {
      throw ArgumentError('A 1–5 star rating and comment are required.');
    }
    if (anonymous && user.normalizedRole != 'student') {
      throw ArgumentError('Only students may submit anonymous feedback.');
    }
    await api.post(
      '/api/v1/feedback',
      body: {
        'rating': rating,
        'comment': comment.trim(),
        'anonymous': anonymous,
      },
    );
  }

  Future<FermsFeedbackPage> feedback({
    required FermsUser user,
    int page = 1,
  }) async {
    if (!user.canViewFeedback) {
      throw const ApiException(
        statusCode: 403,
        message: 'Only Admins and IT Administrators can view feedback.',
      );
    }
    final response = await api.get(
      '/api/v1/feedback',
      queryParameters: {'page': '$page'},
    );
    final json = asJsonMap(response);
    return FermsFeedbackPage(
      items: asJsonList(response).map(FermsFeedback.fromJson).toList(),
      currentPage: intValue(json['current_page'], page),
      lastPage: intValue(json['last_page'], 1),
      total: intValue(json['total']),
    );
  }

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
