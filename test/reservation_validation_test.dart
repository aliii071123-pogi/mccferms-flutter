import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mcc_ferms_flutter/reservation_form.dart';

void main() {
  test('allows requests within the school schedule', () {
    expect(
      validateReservationWindow(
        start: const TimeOfDay(hour: 8, minute: 0),
        end: const TimeOfDay(hour: 20, minute: 0),
      ),
      isNull,
    );
  });

  test('rejects times outside school hours and reversed intervals', () {
    expect(
      validateReservationWindow(
        start: const TimeOfDay(hour: 7, minute: 59),
        end: const TimeOfDay(hour: 9, minute: 0),
      ),
      contains('8:00 AM'),
    );
    expect(
      validateReservationWindow(
        start: const TimeOfDay(hour: 18, minute: 0),
        end: const TimeOfDay(hour: 20, minute: 1),
      ),
      contains('8:00 AM'),
    );
    expect(
      validateReservationWindow(
        start: const TimeOfDay(hour: 12, minute: 0),
        end: const TimeOfDay(hour: 8, minute: 0),
      ),
      contains('later'),
    );
  });

  test('validates multi-day count, future dates, and strict ordering', () {
    final today = DateTime(2026, 11, 12);
    expect(
      validateReservationDates(
        dates: [DateTime(2026, 11, 12), DateTime(2026, 11, 14)],
        durationDays: 2,
        today: today,
      ),
      isNull,
    );
    expect(
      validateReservationDates(
        dates: [DateTime(2026, 11, 12), DateTime(2026, 11, 12)],
        durationDays: 2,
        today: today,
      ),
      contains('strictly increasing'),
    );
    expect(
      validateReservationDates(
        dates: [DateTime(2026, 11, 11)],
        durationDays: 1,
        today: today,
      ),
      contains('today or a future'),
    );
    expect(
      validateReservationDates(
        dates: List.generate(8, (index) => today.add(Duration(days: index))),
        durationDays: 8,
        today: today,
      ),
      contains('1 and 7'),
    );
  });
}
