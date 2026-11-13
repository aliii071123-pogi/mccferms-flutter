import 'package:flutter/material.dart';

import 'api_client.dart';
import 'ferms_animations.dart';
import 'ferms_models.dart';
import 'ferms_repository.dart';

class ReservationForm extends StatefulWidget {
  const ReservationForm({
    super.key,
    required this.repository,
    required this.facilities,
    required this.equipment,
    this.reservation,
  });

  final FermsRepository repository;
  final List<Facility> facilities;
  final List<Equipment> equipment;
  final Reservation? reservation;

  @override
  State<ReservationForm> createState() => _ReservationFormState();
}

class _ReservationFormState extends State<ReservationForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _paxController;
  late final TextEditingController _purposeController;
  late final TextEditingController _descriptionController;
  final List<_ReservationDay> _days = [];
  String _facilityId = '';
  final Map<String, int> _quantities = {};
  bool _saving = false;
  String? _error;

  bool get _editing => widget.reservation != null;

  @override
  void initState() {
    super.initState();
    final reservation = widget.reservation;
    final facilityId = reservation?.facilityId;
    _facilityId =
        facilityId != null &&
            widget.facilities.any((facility) => facility.id == facilityId)
        ? facilityId
        : '';
    final schedules = reservation?.schedules.isNotEmpty == true
        ? reservation!.schedules
        : [
            ReservationSchedule(
              date: reservation?.date ?? '',
              startTime: reservation?.startTime ?? '',
              endTime: reservation?.endTime ?? '',
            ),
          ];
    for (final schedule in schedules) {
      _days.add(
        _ReservationDay(
          date: DateTime.tryParse(schedule.date) ?? _today,
          start:
              _parseTime(schedule.startTime) ??
              const TimeOfDay(hour: 8, minute: 0),
          end:
              _parseTime(schedule.endTime) ??
              const TimeOfDay(hour: 9, minute: 0),
        ),
      );
    }
    _paxController = TextEditingController(
      text: reservation == null ? '' : '${reservation.pax}',
    );
    _purposeController = TextEditingController(
      text: reservation?.purpose ?? '',
    );
    _descriptionController = TextEditingController(
      text: reservation?.description ?? '',
    );
    for (final entry
        in reservation?.equipment.entries ?? <MapEntry<String, dynamic>>[]) {
      _quantities[entry.key] = intValue(entry.value);
    }
  }

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  @override
  void dispose() {
    _paxController.dispose();
    _purposeController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  TimeOfDay? _parseTime(String? value) {
    if (value == null) return null;
    final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(value);
    if (match == null) return null;
    return TimeOfDay(
      hour: int.parse(match.group(1)!),
      minute: int.parse(match.group(2)!),
    );
  }

  String _timeValue(TimeOfDay value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

  String _dateValue(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  Future<void> _selectDate(int index) async {
    final today = DateTime.now();
    final minimum = index == 0
        ? DateTime(today.year, today.month, today.day)
        : _days[index - 1].date.add(const Duration(days: 1));
    final selected = await showDatePicker(
      context: context,
      initialDate: _days[index].date.isBefore(minimum)
          ? minimum
          : _days[index].date,
      firstDate: minimum,
      lastDate: today.add(const Duration(days: 365)),
    );
    if (selected != null) setState(() => _days[index].date = selected);
  }

  Future<void> _selectTime(int index, {required bool start}) async {
    final value = start ? _days[index].start : _days[index].end;
    final selected = await showTimePicker(
      context: context,
      initialTime: value,
      initialEntryMode: TimePickerEntryMode.input,
    );
    if (selected != null) {
      setState(() {
        if (start) {
          _days[index].start = selected;
        } else {
          _days[index].end = selected;
        }
      });
    }
  }

  String? _validateSchedule(int index) => validateReservationWindow(
    start: _days[index].start,
    end: _days[index].end,
  );

  Future<void> _submit() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    final dateError = validateReservationDates(
      dates: _days.map((day) => day.date).toList(),
      durationDays: _days.length,
    );
    if (dateError != null) {
      setState(() => _error = dateError);
      return;
    }
    final scheduleError = _days.indexWhere(
      (day) =>
          validateReservationWindow(start: day.start, end: day.end) != null,
    );
    if (scheduleError != -1) {
      setState(() => _error = _validateSchedule(scheduleError));
      return;
    }
    final quantities = <String, int>{
      for (final entry in _quantities.entries)
        if (entry.value > 0) entry.key: entry.value,
    };
    if (_facilityId.isEmpty && quantities.isEmpty) {
      setState(
        () => _error = 'Choose a facility or at least one equipment item.',
      );
      return;
    }
    final canAddEquipment = widget.equipment.any((item) => item.active);
    final canAddFacility = widget.facilities.any((item) => item.active);
    final missingComplement =
        (_facilityId.isNotEmpty && quantities.isEmpty && canAddEquipment) ||
        (_facilityId.isEmpty && quantities.isNotEmpty && canAddFacility);
    if (!_editing && missingComplement) {
      final addResource = await showDialog<bool>(
        context: context,
        builder: (context) {
          final wantsEquipment = _facilityId.isNotEmpty;
          return AlertDialog(
            title: Text(
              wantsEquipment
                  ? 'Also borrow equipment?'
                  : 'Also reserve a facility?',
            ),
            content: Text(
              wantsEquipment
                  ? 'You can include available equipment with this facility request.'
                  : 'You can include a facility with this equipment request.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Continue without'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(wantsEquipment ? 'Add equipment' : 'Add facility'),
              ),
            ],
          );
        },
      );
      if (addResource != true) return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final payload = <String, dynamic>{
        'facility_id': _facilityId.isEmpty ? null : _facilityId,
        'duration_days': _days.length,
        'days': _days
            .map(
              (day) => {
                'date': _dateValue(day.date),
                'start_time': _timeValue(day.start),
                'end_time': _timeValue(day.end),
              },
            )
            .toList(),
        'pax': int.parse(_paxController.text),
        'purpose': _purposeController.text.trim(),
        'description': _descriptionController.text.trim(),
        'equipment': quantities,
      };
      if (_editing) {
        await widget.repository.updateReservation(
          widget.reservation!.id,
          payload,
        );
      } else {
        await widget.repository.createReservation(payload);
      }
      if (!mounted) return;
      if (!_editing) {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            icon: const Icon(Icons.assignment_turned_in_outlined),
            title: const Text('Request submitted'),
            content: Text(
              'Printed request letters still need to be signed and submitted to the appropriate office.'
              '${quantities.isEmpty ? '' : '\n\nBorrowed equipment must be returned within 2 days.'}',
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Understood'),
              ),
            ],
          ),
        );
      }
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (exception) {
      if (mounted) {
        final facilityConflict =
            exception.statusCode == 422 &&
            exception.errors.containsKey('facility_conflict');
        if (facilityConflict) {
          await showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              icon: const Icon(Icons.event_busy_outlined),
              title: const Text('Facility time unavailable'),
              content: const Text(
                'This facility and time slot conflict with another request. '
                'Please communicate with facility staff to find out which '
                'student organization or institute requested the slot and '
                'coordinate with them.',
              ),
              actions: [
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Understood'),
                ),
              ],
            ),
          );
        }
        final fieldErrors = exception.errors.entries
            .where((entry) => entry.key != 'facility_conflict')
            .expand((entry) => entry.value)
            .join('\n');
        setState(
          () => _error = fieldErrors.isEmpty
              ? (facilityConflict ? null : exception.message)
              : '${facilityConflict ? '' : '${exception.message}\n'}$fieldErrors',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not submit the request. Try again.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: Scaffold(
      appBar: AppBar(title: Text(_editing ? 'Edit request' : 'New request')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                children: [
                  Text(
                    _editing ? 'Update your request' : 'Reservation details',
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'School reservations are scheduled between 8:00 AM and 8:00 PM.',
                  ),
                  const SizedBox(height: 22),
                  DropdownButtonFormField<String>(
                    initialValue: _facilityId,
                    decoration: const InputDecoration(labelText: 'Facility'),
                    items: [
                      const DropdownMenuItem(
                        value: '',
                        child: Text('Equipment only'),
                      ),
                      ...widget.facilities
                          .where((item) => item.active)
                          .map(
                            (facility) => DropdownMenuItem(
                              value: facility.id,
                              child: Text(facility.name),
                            ),
                          ),
                    ],
                    onChanged: _saving
                        ? null
                        : (value) => setState(() => _facilityId = value ?? ''),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    initialValue: _days.length.clamp(1, 7),
                    decoration: const InputDecoration(
                      labelText: 'Number of event days',
                    ),
                    items: List.generate(
                      7,
                      (index) => DropdownMenuItem(
                        value: index + 1,
                        child: Text(
                          '${index + 1} ${index == 0 ? 'day' : 'days'}',
                        ),
                      ),
                    ),
                    onChanged: _saving
                        ? null
                        : (value) {
                            if (value == null) return;
                            setState(() {
                              while (_days.length < value) {
                                final nextDate = _days.last.date.add(
                                  const Duration(days: 1),
                                );
                                _days.add(
                                  _ReservationDay(
                                    date: nextDate,
                                    start: const TimeOfDay(hour: 8, minute: 0),
                                    end: const TimeOfDay(hour: 9, minute: 0),
                                  ),
                                );
                              }
                              if (_days.length > value) {
                                _days.removeRange(value, _days.length);
                              }
                            });
                          },
                  ),
                  const SizedBox(height: 12),
                  ...List.generate(_days.length, _daySection),
                  const SizedBox(height: 18),
                  if (_days.indexWhere(
                        (day) =>
                            validateReservationWindow(
                              start: day.start,
                              end: day.end,
                            ) !=
                            null,
                      ) !=
                      -1)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        _validateSchedule(
                          _days.indexWhere(
                            (day) =>
                                validateReservationWindow(
                                  start: day.start,
                                  end: day.end,
                                ) !=
                                null,
                          ),
                        )!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  TextFormField(
                    controller: _paxController,
                    enabled: !_saving,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Estimated attendees',
                      prefixIcon: Icon(Icons.groups_outlined),
                    ),
                    validator: (value) {
                      final number = int.tryParse(value ?? '');
                      if (number == null || number < 1) {
                        return 'Enter at least 1 attendee.';
                      }
                      final facility = widget.facilities
                          .where((item) => item.id == _facilityId)
                          .firstOrNull;
                      if (facility != null &&
                          facility.capacity > 0 &&
                          number > facility.capacity) {
                        return 'Capacity is ${facility.capacity} people.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: _purposeController,
                    enabled: !_saving,
                    maxLength: 255,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(labelText: 'Purpose'),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Enter the purpose of this request.'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _descriptionController,
                    enabled: !_saving,
                    minLines: 3,
                    maxLines: 5,
                    maxLength: 2000,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Activity brief description',
                      alignLabelWithHint: true,
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Add a short activity description.'
                        : null,
                  ),
                  if (widget.equipment.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Equipment',
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    ...widget.equipment
                        .where((item) => item.active)
                        .map(_equipmentRow),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    _FormError(_error!),
                  ],
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _saving ? null : _submit,
                    icon: _saving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: FermsLoadingIndicator(size: 20),
                          )
                        : const Icon(Icons.send_outlined),
                    label: Text(
                      _saving
                          ? 'Submitting…'
                          : _editing
                          ? 'Save changes'
                          : 'Submit request',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _equipmentRow(Equipment equipment) {
    final quantity = _quantities[equipment.id] ?? 0;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(equipment.name),
      subtitle: Text('${equipment.availableQuantity} available'),
      trailing: SizedBox(
        width: 140,
        child: Row(
          children: [
            IconButton(
              tooltip: 'Remove one ${equipment.name}',
              onPressed: _saving || quantity == 0
                  ? null
                  : () => setState(
                      () => _quantities[equipment.id] = quantity - 1,
                    ),
              icon: const Icon(Icons.remove_circle_outline),
            ),
            Expanded(child: Center(child: Text('$quantity'))),
            IconButton(
              tooltip: 'Add one ${equipment.name}',
              onPressed: _saving || quantity >= equipment.availableQuantity
                  ? null
                  : () => setState(
                      () => _quantities[equipment.id] = quantity + 1,
                    ),
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
        ),
      ),
    );
  }

  Widget _daySection(int index) {
    final day = _days[index];
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                index == 0 ? 'Pick date for the first day' : 'Day ${index + 1}',
                style: Theme.of(context).textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  OutlinedButton.icon(
                    onPressed: _saving ? null : () => _selectDate(index),
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: Text(_dateValue(day.date)),
                  ),
                  OutlinedButton.icon(
                    onPressed: _saving
                        ? null
                        : () => _selectTime(index, start: true),
                    icon: const Icon(Icons.schedule_outlined),
                    label: Text('Start ${day.start.format(context)}'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _saving
                        ? null
                        : () => _selectTime(index, start: false),
                    icon: const Icon(Icons.schedule_outlined),
                    label: Text('End ${day.end.format(context)}'),
                  ),
                ],
              ),
              if (_validateSchedule(index) != null) ...[
                const SizedBox(height: 8),
                Text(
                  _validateSchedule(index)!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ReservationDay {
  _ReservationDay({required this.date, required this.start, required this.end});

  DateTime date;
  TimeOfDay start;
  TimeOfDay end;
}

String? validateReservationDates({
  required List<DateTime> dates,
  required int durationDays,
  DateTime? today,
}) {
  if (durationDays < 1 || durationDays > 7 || dates.length != durationDays) {
    return 'Choose between 1 and 7 event days.';
  }
  final now = today ?? DateTime.now();
  final firstAllowed = DateTime(now.year, now.month, now.day);
  for (var index = 0; index < dates.length; index++) {
    final date = DateTime(
      dates[index].year,
      dates[index].month,
      dates[index].day,
    );
    if (date.isBefore(firstAllowed)) return 'Choose today or a future date.';
    if (index > 0) {
      final previous = DateTime(
        dates[index - 1].year,
        dates[index - 1].month,
        dates[index - 1].day,
      );
      if (!date.isAfter(previous)) {
        return 'Event dates must be in strictly increasing order.';
      }
    }
  }
  return null;
}

String? validateReservationWindow({
  required TimeOfDay start,
  required TimeOfDay end,
}) {
  final startMinutes = start.hour * 60 + start.minute;
  final endMinutes = end.hour * 60 + end.minute;
  if (startMinutes < 8 * 60 || endMinutes > 20 * 60) {
    return 'Reservations are available from 8:00 AM to 8:00 PM.';
  }
  if (startMinutes >= endMinutes) {
    return 'End time must be later than start time.';
  }
  return null;
}

class _FormError extends StatelessWidget {
  const _FormError(this.message);
  final String message;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFFFECEF),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(message, style: const TextStyle(color: Color(0xFF8A1C32))),
  );
}
