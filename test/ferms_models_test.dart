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

  test('reservation details retain each returned schedule block', () {
    final reservation = Reservation.fromJson({
      'id': 12,
      'status': 'pending',
      'schedules': [
        {'date': '2026-11-20', 'start_time': '08:00', 'end_time': '10:00'},
        {'date': '2026-11-22', 'start_time': '13:00', 'end_time': '17:00'},
      ],
    });

    expect(reservation.schedules, hasLength(2));
    expect(reservation.date, '2026-11-20');
    expect(reservation.schedules.last.date, '2026-11-22');
    expect(reservation.schedules.last.startTime, '13:00');
  });

  test('calendar entries expose only availability fields and map statuses', () {
    final entry = CalendarEntry.fromJson({
      'facility': 'Auditorium',
      'starts_at': '2026-11-20T08:00:00+08:00',
      'ends_at': '2026-11-20T10:00:00+08:00',
      'status': 'approved',
    });

    expect(entry.facility, 'Auditorium');
    expect(entry.displayStatus, 'Booked');
    expect(entry.startsAt.hour, 8);
  });

  test('equipment parses optional category, staff, and notes', () {
    final equipment = Equipment.fromJson({
      'id': 3,
      'name': 'Projector',
      'category': null,
      'staff_in_charge': 'Facilities Desk',
      'notes': 'HDMI available',
    });

    expect(equipment.category, isNull);
    expect(equipment.staffInCharge, 'Facilities Desk');
    expect(equipment.notes, 'HDMI available');
  });

  test('facility parses form fields and availability', () {
    final facility = Facility.fromJson({
      'id': 5,
      'name': 'Auditorium',
      'location': 'Main Building',
      'staff_in_charge': 'Facilities Desk',
      'capacity': 300,
      'active': false,
      'notes': 'Use the east entrance',
    });

    expect(facility.location, 'Main Building');
    expect(facility.staffInCharge, 'Facilities Desk');
    expect(facility.active, isFalse);
    expect(facility.notes, 'Use the east entrance');
  });
}
