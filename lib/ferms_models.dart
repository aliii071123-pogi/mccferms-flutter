typedef JsonMap = Map<String, dynamic>;

JsonMap asJsonMap(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

dynamic unwrapData(dynamic value) =>
    value is Map && value.containsKey('data') ? value['data'] : value;

List<JsonMap> asJsonList(dynamic value) {
  var unwrapped = unwrapData(value);
  if (unwrapped is Map) {
    unwrapped =
        unwrapped['items'] ??
        unwrapped['results'] ??
        unwrapped['reservations'] ??
        unwrapped['facilities'] ??
        unwrapped['equipment'] ??
        unwrapped['data'];
  }
  if (unwrapped is! List) return const [];
  return unwrapped.map(asJsonMap).toList();
}

List<JsonMap> scheduleBlocks(JsonMap json) => asJsonList(
  json['schedule_blocks'] ??
      json['upcoming_blocks'] ??
      json['upcoming_reservations'] ??
      json['schedule'],
);

String stringValue(dynamic value, [String fallback = '']) =>
    value?.toString() ?? fallback;

int intValue(dynamic value, [int fallback = 0]) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? fallback;

class FermsUser {
  const FermsUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.organization = '',
    this.position = '',
  });

  final String id;
  final String name;
  final String email;
  final String role;
  final String organization;
  final String position;

  String get normalizedRole =>
      role.toLowerCase().replaceAll('-', '_').replaceAll(' ', '_');

  bool get profileIncomplete =>
      normalizedRole == 'student' &&
      (organization.trim().isEmpty || position.trim().isEmpty);

  bool get canManageResources =>
      const {'staff', 'admin', 'super_admin'}.contains(normalizedRole);

  bool get canReviewRequests =>
      const {'admin', 'administrator', 'super_admin'}.contains(normalizedRole);

  bool get isSuperAdmin => normalizedRole == 'super_admin';

  factory FermsUser.fromJson(JsonMap json) {
    final profile = asJsonMap(json['profile']);
    return FermsUser(
      id: stringValue(json['id']),
      name: stringValue(json['name'], 'MCC FERMS user'),
      email: stringValue(json['email']),
      role: stringValue(json['role'] ?? json['role_name'], 'student'),
      organization: stringValue(
        json['organization'] ?? profile['organization'],
      ),
      position: stringValue(json['position'] ?? profile['position']),
    );
  }
}

class Facility {
  const Facility({
    required this.id,
    required this.name,
    this.description = '',
    this.capacity = 0,
    this.location = '',
    this.active = true,
    this.schedule = const [],
  });

  final String id;
  final String name;
  final String description;
  final int capacity;
  final String location;
  final bool active;
  final List<JsonMap> schedule;

  factory Facility.fromJson(JsonMap json) => Facility(
    id: stringValue(json['id']),
    name: stringValue(json['name'], 'Facility'),
    description: stringValue(json['description']),
    capacity: intValue(json['capacity'] ?? json['pax']),
    location: stringValue(json['location']),
    active: json['active'] != false && json['is_active'] != false,
    schedule: scheduleBlocks(json),
  );
}

class Organization {
  const Organization({required this.id, required this.name});

  final String id;
  final String name;

  factory Organization.fromJson(JsonMap json) => Organization(
    id: stringValue(json['id']),
    name: stringValue(json['name']),
  );
}

class CalendarEntry {
  const CalendarEntry({
    required this.facility,
    required this.startsAt,
    required this.endsAt,
    required this.status,
  });

  final String facility;
  final DateTime startsAt;
  final DateTime endsAt;
  final String status;

  String get displayStatus => status == 'approved' ? 'Booked' : 'Pending';

  factory CalendarEntry.fromJson(JsonMap json) => CalendarEntry(
    facility: stringValue(json['facility']),
    startsAt: _calendarDateTime(stringValue(json['starts_at'])),
    endsAt: _calendarDateTime(stringValue(json['ends_at'])),
    status: stringValue(json['status']).toLowerCase(),
  );
}

DateTime _calendarDateTime(String value) {
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})[T ](\d{2}):(\d{2})')
      .firstMatch(value);
  if (match == null) return DateTime.parse(value);
  return DateTime(
    int.parse(match.group(1)!),
    int.parse(match.group(2)!),
    int.parse(match.group(3)!),
    int.parse(match.group(4)!),
    int.parse(match.group(5)!),
  );
}

class Equipment {
  const Equipment({
    required this.id,
    required this.name,
    this.description = '',
    this.quantity = 0,
    this.availableQuantity = 0,
    this.active = true,
    this.schedule = const [],
    this.category,
    this.staffInCharge = '',
    this.notes = '',
  });

  final String id;
  final String name;
  final String description;
  final int quantity;
  final int availableQuantity;
  final bool active;
  final List<JsonMap> schedule;
  final String? category;
  final String staffInCharge;
  final String notes;

  factory Equipment.fromJson(JsonMap json) {
    final quantity = intValue(json['quantity'] ?? json['total_quantity']);
    return Equipment(
      id: stringValue(json['id']),
      name: stringValue(json['name'], 'Equipment'),
      description: stringValue(json['description']),
      quantity: quantity,
      availableQuantity: intValue(
        json['available_quantity'] ?? json['available'],
        quantity,
      ),
      active: json['active'] != false && json['is_active'] != false,
      schedule: scheduleBlocks(json),
      category: json['category'] == null
          ? null
          : stringValue(
              json['category'] is Map
                  ? asJsonMap(json['category'])['name']
                  : json['category'],
            ),
      staffInCharge: stringValue(
        json['staff_in_charge'] is Map
            ? asJsonMap(json['staff_in_charge'])['name']
            : json['staff_in_charge'],
      ),
      notes: stringValue(json['notes']),
    );
  }
}

class ReservationSchedule {
  const ReservationSchedule({
    required this.date,
    required this.startTime,
    required this.endTime,
  });

  final String date;
  final String startTime;
  final String endTime;

  factory ReservationSchedule.fromJson(JsonMap json) {
    final startsAt = stringValue(json['starts_at']);
    final endsAt = stringValue(json['ends_at']);
    return ReservationSchedule(
      date: _scheduleDate(json['date'] ?? startsAt),
      startTime: _scheduleTime(json['start_time'] ?? startsAt),
      endTime: _scheduleTime(json['end_time'] ?? endsAt),
    );
  }
}

String _scheduleDate(dynamic value) {
  final text = stringValue(value);
  return text.length >= 10 ? text.substring(0, 10) : text;
}

String _scheduleTime(dynamic value) {
  final text = stringValue(value);
  final match = RegExp(r'T?(\d{2}:\d{2})').firstMatch(text);
  return match?.group(1) ?? text;
}

class Reservation {
  const Reservation({
    required this.id,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.status,
    required this.purpose,
    required this.description,
    required this.pax,
    this.facilityId,
    this.facilityName = '',
    this.requesterName = '',
    this.requesterEmail = '',
    this.equipment = const {},
    this.schedules = const [],
  });

  final String id;
  final String date;
  final String startTime;
  final String endTime;
  final String status;
  final String purpose;
  final String description;
  final int pax;
  final String? facilityId;
  final String facilityName;
  final String requesterName;
  final String requesterEmail;
  final JsonMap equipment;
  final List<ReservationSchedule> schedules;

  ReservationSchedule get primarySchedule => schedules.isEmpty
      ? ReservationSchedule(date: date, startTime: startTime, endTime: endTime)
      : schedules.first;

  bool get isPending => status.toLowerCase() == 'pending';
  bool get isClosed => const {
    'completed',
    'closed',
    'cancelled',
    'canceled',
    'rejected',
  }.contains(status.toLowerCase());

  factory Reservation.fromJson(JsonMap json) {
    final facility = asJsonMap(json['facility']);
    final user = asJsonMap(json['user'] ?? json['requester']);
    final equipment = <String, dynamic>{};
    final rawEquipment = json['equipment'];
    if (rawEquipment is Map) {
      equipment.addAll(Map<String, dynamic>.from(rawEquipment));
    } else if (rawEquipment is List) {
      for (final item in rawEquipment) {
        final itemMap = asJsonMap(item);
        final pivot = asJsonMap(itemMap['pivot']);
        final itemId = stringValue(itemMap['id']);
        if (itemId.isNotEmpty) {
          equipment[itemId] = intValue(
            pivot['quantity'] ??
                itemMap['requested_quantity'] ??
                itemMap['quantity'],
          );
        }
      }
    }
    final schedules = json['schedules'] is List
        ? (json['schedules'] as List)
              .map((item) => ReservationSchedule.fromJson(asJsonMap(item)))
              .toList()
        : <ReservationSchedule>[];
    final primary = schedules.isEmpty ? null : schedules.first;
    return Reservation(
      id: stringValue(json['id']),
      date: primary?.date ?? stringValue(json['date']),
      startTime: primary?.startTime ?? stringValue(json['start_time']),
      endTime: primary?.endTime ?? stringValue(json['end_time']),
      status: stringValue(json['status'], 'pending'),
      purpose: stringValue(json['purpose']),
      description: stringValue(json['description']),
      pax: intValue(json['pax']),
      facilityId: json['facility_id'] == null && facility['id'] == null
          ? null
          : stringValue(json['facility_id'] ?? facility['id']),
      facilityName: stringValue(json['facility_name'] ?? facility['name']),
      requesterName: stringValue(json['requester_name'] ?? user['name']),
      requesterEmail: stringValue(json['requester_email'] ?? user['email']),
      equipment: equipment,
      schedules: schedules,
    );
  }
}
