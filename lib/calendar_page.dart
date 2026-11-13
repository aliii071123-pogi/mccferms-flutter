import 'package:flutter/material.dart';

import 'ferms_animations.dart';
import 'ferms_models.dart';
import 'ferms_repository.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key, required this.repository});

  final FermsRepository repository;

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _selectedDate = DateTime.now();
  List<CalendarEntry> _entries = const [];
  bool _loading = true;
  String? _error;
  int _loadId = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final loadId = ++_loadId;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final entries = await widget.repository.calendar(_month);
      if (!mounted || loadId != _loadId) return;
      setState(() => _entries = entries);
    } catch (error) {
      if (mounted && loadId == _loadId) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted && loadId == _loadId) setState(() => _loading = false);
    }
  }

  List<CalendarEntry> _entriesFor(DateTime date) =>
      _entries
          .where(
            (entry) =>
                entry.startsAt.year == date.year &&
                entry.startsAt.month == date.month &&
                entry.startsAt.day == date.day,
          )
          .toList()
        ..sort((a, b) => a.startsAt.compareTo(b.startsAt));

  void _changeMonth(int amount) {
    setState(() {
      _month = DateTime(_month.year, _month.month + amount);
      _selectedDate = DateTime(_month.year, _month.month, 1);
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final firstWeekday = DateTime(_month.year, _month.month, 1).weekday % 7;
    final dayCount = DateTime(_month.year, _month.month + 1, 0).day;
    final today = DateTime.now();
    final selectedEntries = _entriesFor(_selectedDate);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Facility calendar',
          style: Theme.of(context).textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        const Text(
          'Select a date to see each facility time slot and whether it is pending or booked.',
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Previous month',
                      onPressed: () => _changeMonth(-1),
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Expanded(
                      child: Text(
                        _monthLabel(_month),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Next month',
                      onPressed: () => _changeMonth(1),
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
                const Row(
                  children: [
                    _WeekdayLabel('S'),
                    _WeekdayLabel('M'),
                    _WeekdayLabel('T'),
                    _WeekdayLabel('W'),
                    _WeekdayLabel('T'),
                    _WeekdayLabel('F'),
                    _WeekdayLabel('S'),
                  ],
                ),
                const SizedBox(height: 6),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: 42,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    mainAxisSpacing: 4,
                    crossAxisSpacing: 4,
                    childAspectRatio: 1.15,
                  ),
                  itemBuilder: (context, index) {
                    final day = index - firstWeekday + 1;
                    if (day < 1 || day > dayCount) {
                      return const SizedBox.shrink();
                    }
                    final date = DateTime(_month.year, _month.month, day);
                    final selected = _sameDate(date, _selectedDate);
                    final isToday = _sameDate(date, today);
                    final dayEntries = _entriesFor(date);
                    final hasPending = dayEntries.any(
                      (entry) => entry.isPendingAvailability,
                    );
                    final hasBooked = dayEntries.any(
                      (entry) => entry.status == 'approved',
                    );
                    final hasEntries = hasPending || hasBooked;
                    return Semantics(
                      button: true,
                      selected: selected,
                      label:
                          '${_dateLabel(date)}'
                          '${hasPending ? ', pending requests' : ''}'
                          '${hasBooked ? ', booked facilities' : ''}',
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => setState(() => _selectedDate = date),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: selected
                                ? Theme.of(context).colorScheme.primaryContainer
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            border: isToday && !selected
                                ? Border.all(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary,
                                  )
                                : null,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '$day',
                                style: TextStyle(
                                  fontWeight: selected || isToday
                                      ? FontWeight.w700
                                      : FontWeight.normal,
                                  color: selected
                                      ? Theme.of(context)
                                            .colorScheme
                                            .onPrimaryContainer
                                      : null,
                                ),
                              ),
                              if (hasEntries)
                                Wrap(
                                  spacing: 2,
                                  children: [
                                    if (hasPending)
                                      _DayMarker(
                                        color: const Color(0xFF9A5A00),
                                      ),
                                    if (hasBooked)
                                      _DayMarker(
                                        color: const Color(0xFF237A52),
                                      ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Wrap(
          spacing: 16,
          runSpacing: 4,
          children: [
            _AvailabilityLegend(color: Color(0xFF9A5A00), label: 'Pending'),
            _AvailabilityLegend(color: Color(0xFF237A52), label: 'Booked'),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          _dateLabel(_selectedDate),
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        if (_loading) const Center(child: FermsLoadingIndicator(size: 28)),
        if (_error != null)
          Card(
            child: ListTile(
              leading: Icon(
                Icons.cloud_off_outlined,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(_error!),
              trailing: IconButton(
                tooltip: 'Retry',
                onPressed: _load,
                icon: const Icon(Icons.refresh),
              ),
            ),
          )
        else if (!_loading && selectedEntries.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('No reservation for this date'),
          )
        else
          Expanded(
            child: ListView.separated(
              itemCount: selectedEntries.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) =>
                  _AvailabilityCard(entry: selectedEntries[index]),
            ),
          ),
      ],
    );
  }
}

class _AvailabilityCard extends StatelessWidget {
  const _AvailabilityCard({required this.entry});

  final CalendarEntry entry;

  @override
  Widget build(BuildContext context) {
    final booked = entry.status == 'approved';
    final time = '${_timeLabel(entry.startsAt)}–${_timeLabel(entry.endsAt)}';
    return Card(
      child: ListTile(
        leading: Icon(
          Icons.apartment_outlined,
          color: Theme.of(context).colorScheme.primary,
        ),
        title: Text(entry.facility),
        subtitle: Text('${_dateLabel(entry.startsAt)} · $time'),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: (booked ? const Color(0xFF237A52) : const Color(0xFF9A5A00))
                .withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            entry.displayStatus,
            style: TextStyle(
              color: booked ? const Color(0xFF237A52) : const Color(0xFF9A5A00),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _WeekdayLabel extends StatelessWidget {
  const _WeekdayLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Center(
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(fontWeight: FontWeight.w700),
      ),
    ),
  );
}

class _DayMarker extends StatelessWidget {
  const _DayMarker({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 5,
    height: 5,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

class _AvailabilityLegend extends StatelessWidget {
  const _AvailabilityLegend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      _DayMarker(color: color),
      const SizedBox(width: 6),
      Text(label, style: Theme.of(context).textTheme.labelSmall),
    ],
  );
}

bool _sameDate(DateTime first, DateTime second) =>
    first.year == second.year &&
    first.month == second.month &&
    first.day == second.day;

String _monthLabel(DateTime date) =>
    '${_monthNames[date.month - 1]} ${date.year}';

String _dateLabel(DateTime date) =>
    '${_monthNames[date.month - 1]} ${date.day}, ${date.year}';

String _timeLabel(DateTime date) =>
    '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

const _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];
