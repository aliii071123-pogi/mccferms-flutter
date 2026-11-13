import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:mcc_ferms_flutter/api_client.dart';
import 'package:mcc_ferms_flutter/ferms_animations.dart';
import 'package:mcc_ferms_flutter/ferms_models.dart';
import 'package:mcc_ferms_flutter/ferms_repository.dart';
import 'package:mcc_ferms_flutter/reservations_page.dart';

void main() {
  testWidgets('reduced motion presents appearing content immediately', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: const Scaffold(
            body: FermsAppear(index: 8, child: Text('Appearing content')),
          ),
        ),
      ),
    );

    final opacity = tester.widget<Opacity>(find.byType(Opacity));
    expect(opacity.opacity, 1);
    expect(find.bySemanticsLabel('Appearing content'), findsOneWidget);
  });

  testWidgets('staff can recommend but cannot approve or reject', (
    tester,
  ) async {
    await _pumpReservations(tester, 'staff');

    expect(find.text('Recommend approval'), findsOneWidget);
    expect(find.text('Approve'), findsNothing);
    expect(find.text('Reject'), findsNothing);
  });

  testWidgets('admins can decide but do not see staff recommendation action', (
    tester,
  ) async {
    await _pumpReservations(tester, 'admin');

    expect(find.text('Approve'), findsOneWidget);
    expect(find.text('Reject'), findsOneWidget);
    expect(find.text('Recommend approval'), findsNothing);
  });

  testWidgets('admins can make the final decision on recommended requests', (
    tester,
  ) async {
    await _pumpReservations(tester, 'admin', status: 'recommended');

    expect(find.text('Approve'), findsOneWidget);
    expect(find.text('Reject'), findsOneWidget);
    expect(find.text('Recommend approval'), findsNothing);
  });

  testWidgets('Student A does not see or open Student B request details', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReservationsPage(
            repository: _repository(),
            user: FermsUser.fromJson({'id': 7, 'role': 'student'}),
            reservations: [
              Reservation.fromJson({
                'id': 1,
                'user_id': 7,
                'status': 'pending',
                'purpose': 'Student A event',
              }),
              Reservation.fromJson({
                'id': 2,
                'user_id': 8,
                'status': 'pending',
                'purpose': 'Student B private event',
              }),
            ],
            facilities: const [],
            equipment: const [],
            loading: false,
            error: null,
            onRefresh: (_) async {},
          ),
        ),
      ),
    );

    expect(find.text('Student A event'), findsOneWidget);
    expect(find.text('Student B private event'), findsNothing);
    await tester.tap(find.text('Student A event'));
    await tester.pumpAndSettle();
    expect(find.text('Student B private event'), findsNothing);
  });

  testWidgets('decision timestamp is rendered for returned reservation data', (
    tester,
  ) async {
    final reservation = Reservation.fromJson({
      'id': 42,
      'user_id': 7,
      'status': 'approved',
      'purpose': 'Council event',
      'reviewed_at': DateTime(2026, 11, 20, 14, 30).toIso8601String(),
      'reviewer': {'name': 'Admin Reviewer'},
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReservationsPage(
            repository: _repository(),
            user: FermsUser.fromJson({'id': 7, 'role': 'student'}),
            reservations: [reservation],
            facilities: const [],
            equipment: const [],
            loading: false,
            error: null,
            onRefresh: (_) async {},
          ),
        ),
      ),
    );

    expect(find.textContaining('Decision approved'), findsOneWidget);
    expect(find.textContaining('Admin Reviewer'), findsOneWidget);
  });
}

FermsRepository _repository() => FermsRepository(
  FermsApiClient(
    baseUrl: 'https://ferms.example.test',
    client: MockClient((_) async => throw StateError('Unexpected API request')),
  ),
);

Future<void> _pumpReservations(
  WidgetTester tester,
  String role, {
  String status = 'pending',
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ReservationsPage(
          repository: _repository(),
          user: FermsUser.fromJson({'id': 7, 'role': role}),
          reservations: [
            Reservation.fromJson({
              'id': 12,
              'date': '2026-11-20',
              'start_time': '08:00',
              'end_time': '10:00',
              'status': status,
              'purpose': 'Council event',
            }),
          ],
          facilities: const [],
          equipment: const [],
          loading: false,
          error: null,
          onRefresh: (_) async {},
        ),
      ),
    ),
  );
}
