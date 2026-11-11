import 'package:flutter_test/flutter_test.dart';
import 'package:mcc_ferms_flutter/ferms_models.dart';

void main() {
  test('student profile completion and role permissions are explicit', () {
    final incomplete = FermsUser.fromJson({
      'id': 5,
      'name': 'Taylor Student',
      'email': 'taylor@mcc.edu.ph',
      'role': 'student',
    });
    final staff = FermsUser.fromJson({'id': 6, 'role': 'staff'});
    final admin = FermsUser.fromJson({'id': 7, 'role': 'admin'});

    expect(incomplete.profileIncomplete, isTrue);
    expect(staff.canManageResources, isTrue);
    expect(staff.canReviewRequests, isFalse);
    expect(admin.canReviewRequests, isTrue);
  });

  test('facility parses upcoming schedule blocks', () {
    final facility = Facility.fromJson({
      'id': 3,
      'name': 'Auditorium',
      'capacity': 300,
      'schedule_blocks': [
        {'date': '2026-11-12', 'start_time': '13:00', 'end_time': '15:00'},
      ],
    });

    expect(facility.capacity, 300);
    expect(facility.schedule.single['date'], '2026-11-12');
  });

  test('reservation parses equipment relationship quantities', () {
    final reservation = Reservation.fromJson({
      'id': 9,
      'date': '2026-11-12',
      'start_time': '13:00',
      'end_time': '15:00',
      'status': 'pending',
      'purpose': 'Council meeting',
      'pax': 25,
      'equipment': [
        {
          'id': 4,
          'name': 'Projector',
          'pivot': {'quantity': 2},
        },
      ],
    });

    expect(reservation.isPending, isTrue);
    expect(reservation.equipment['4'], 2);
  });
}
