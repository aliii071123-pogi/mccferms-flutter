import 'package:flutter/material.dart';

import 'ferms_models.dart';
import 'ferms_repository.dart';
import 'reservation_form.dart';

class ReservationsPage extends StatefulWidget {
  const ReservationsPage({
    super.key,
    required this.repository,
    required this.user,
    required this.reservations,
    required this.facilities,
    required this.equipment,
    required this.loading,
    required this.error,
    required this.onRefresh,
  });

  final FermsRepository repository;
  final FermsUser user;
  final List<Reservation> reservations;
  final List<Facility> facilities;
  final List<Equipment> equipment;
  final bool loading;
  final String? error;
  final Future<void> Function(bool history) onRefresh;

  @override
  State<ReservationsPage> createState() => _ReservationsPageState();
}

class _ReservationsPageState extends State<ReservationsPage> {
  bool _history = false;
  String? _actionError;

  Future<void> _confirmDecision(Reservation reservation, String status) async {
    final approved = status == 'approved';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          approved ? Icons.check_circle_outline : Icons.cancel_outlined,
        ),
        title: Text('${approved ? 'Approve' : 'Reject'} this request?'),
        content: Text(
          '${reservation.purpose}\n${reservation.date}, ${reservation.startTime}–${reservation.endTime}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Go back'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(approved ? 'Approve request' : 'Reject request'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _runAction(
      () => widget.repository.decideReservation(reservation.id, status),
    );
  }

  Future<void> _confirmCancel(Reservation reservation) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel this request?'),
        content: const Text(
          'This cannot be undone. You can submit a new request later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep request'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel request'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _runAction(
        () => widget.repository.cancelReservation(reservation.id),
      );
    }
  }

  Future<void> _confirmDelete(Reservation reservation) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this request?'),
        content: const Text(
          'This permanently removes the request from the system.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep request'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete request'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _runAction(
        () => widget.repository.deleteReservation(reservation.id),
      );
    }
  }

  Future<void> _runAction(Future<void> Function() action) async {
    setState(() => _actionError = null);
    try {
      await action();
      await widget.onRefresh(_history);
    } catch (error) {
      if (mounted) setState(() => _actionError = error.toString());
    }
  }

  Future<void> _edit(Reservation reservation) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ReservationForm(
          repository: widget.repository,
          facilities: widget.facilities,
          equipment: widget.equipment,
          reservation: reservation,
        ),
      ),
    );
    if (changed == true) await widget.onRefresh(_history);
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              'Requests',
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          SegmentedButton<bool>(
            showSelectedIcon: false,
            style: const ButtonStyle(
              padding: WidgetStatePropertyAll(
                EdgeInsets.symmetric(horizontal: 8),
              ),
              textStyle: WidgetStatePropertyAll(TextStyle(fontSize: 12)),
              visualDensity: VisualDensity(horizontal: -2),
            ),
            segments: const [
              ButtonSegment(value: false, label: Text('Upcoming')),
              ButtonSegment(value: true, label: Text('History')),
            ],
            selected: {_history},
            onSelectionChanged: (selection) {
              setState(() => _history = selection.first);
              widget.onRefresh(_history);
            },
          ),
        ],
      ),
      const SizedBox(height: 8),
      Text(
        widget.user.canReviewRequests
            ? 'Review and track facility and equipment requests.'
            : 'Track your facility and equipment requests.',
        style: Theme.of(context).textTheme.bodyMedium
            ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
      if (_actionError != null) ...[
        const SizedBox(height: 14),
        _InlineError(_actionError!),
      ],
      const SizedBox(height: 18),
      if (widget.loading) const LinearProgressIndicator(),
      if (widget.error != null) ...[
        _InlineError(widget.error!),
        TextButton.icon(
          onPressed: () => widget.onRefresh(_history),
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
        ),
      ] else if (!widget.loading && widget.reservations.isEmpty)
        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _history ? Icons.history : Icons.event_available_outlined,
                  size: 42,
                  color: const Color(0xFF9E1B32),
                ),
                const SizedBox(height: 12),
                Text(
                  _history ? 'No request history yet' : 'No upcoming requests',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                const Text('Your requests will appear here.'),
              ],
            ),
          ),
        )
      else
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => widget.onRefresh(_history),
            child: ListView.separated(
              padding: const EdgeInsets.only(bottom: 24),
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: widget.reservations.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) =>
                  _reservationTile(widget.reservations[index]),
            ),
          ),
        ),
    ],
  );

  Widget _reservationTile(Reservation reservation) {
    final statusColor = _statusColor(reservation.status);
    final canEdit =
        widget.user.role.toLowerCase() == 'student' &&
        reservation.isPending &&
        !_history;
    final canReview = widget.user.canReviewRequests && reservation.isPending;
    final canDelete = widget.user.canReviewRequests;
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _showDetails(reservation),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  Text(
                    reservation.purpose,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  _StatusLabel(reservation.status, statusColor),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  _Meta(Icons.calendar_today_outlined, reservation.date),
                  _Meta(
                    Icons.schedule_outlined,
                    '${reservation.startTime}–${reservation.endTime}',
                  ),
                  if (reservation.facilityName.isNotEmpty)
                    _Meta(Icons.location_on_outlined, reservation.facilityName),
                  if (reservation.pax > 0)
                    _Meta(Icons.groups_outlined, '${reservation.pax} people'),
                ],
              ),
              if (widget.user.canManageResources &&
                  reservation.requesterName.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  '${reservation.requesterName}${reservation.requesterEmail.isEmpty ? '' : ' · ${reservation.requesterEmail}'}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
              if (canEdit || canReview || canDelete) ...[
                const Divider(height: 24),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (canEdit) ...[
                      OutlinedButton.icon(
                        onPressed: () => _edit(reservation),
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Edit'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _confirmCancel(reservation),
                        icon: const Icon(Icons.close),
                        label: const Text('Cancel'),
                      ),
                    ],
                    if (canReview) ...[
                      FilledButton.icon(
                        onPressed: () =>
                            _confirmDecision(reservation, 'approved'),
                        icon: const Icon(Icons.check),
                        label: const Text('Approve'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () =>
                            _confirmDecision(reservation, 'rejected'),
                        icon: const Icon(Icons.close),
                        label: const Text('Reject'),
                      ),
                    ],
                    if (canDelete)
                      IconButton(
                        tooltip: 'Delete request',
                        onPressed: () => _confirmDelete(reservation),
                        icon: const Icon(Icons.delete_outline),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showDetails(Reservation reservation) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(reservation.purpose),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (reservation.schedules.length > 1) ...[
              const Text(
                'Event schedule',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              ...reservation.schedules.asMap().entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    'Day ${entry.key + 1}: ${entry.value.date} · '
                    '${entry.value.startTime}–${entry.value.endTime}',
                  ),
                ),
              ),
            ] else
              Text(
                '${reservation.date} · ${reservation.startTime}–${reservation.endTime}',
              ),
            if (reservation.facilityName.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text('Facility: ${reservation.facilityName}'),
            ],
            if (reservation.pax > 0) ...[
              const SizedBox(height: 8),
              Text('Estimated attendees: ${reservation.pax}'),
            ],
            const SizedBox(height: 14),
            Text(
              reservation.description.isEmpty
                  ? 'No description provided.'
                  : reservation.description,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );

  Color _statusColor(String status) => switch (status.toLowerCase()) {
    'approved' => const Color(0xFF237A52),
    'rejected' || 'cancelled' || 'canceled' => const Color(0xFF9B2438),
    'completed' || 'closed' => const Color(0xFF59636A),
    _ => const Color(0xFF9A5A00),
  };
}

class _StatusLabel extends StatelessWidget {
  const _StatusLabel(this.status, this.color);
  final String status;
  final Color color;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 10,
        ),
      ),
    ),
  );
}

class _Meta extends StatelessWidget {
  const _Meta(this.icon, this.text);
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(
        icon,
        size: 16,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      const SizedBox(width: 5),
      Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    ],
  );
}

class _InlineError extends StatelessWidget {
  const _InlineError(this.message);
  final String message;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFFFECEF),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(message, style: const TextStyle(color: Color(0xFF8A1C32))),
  );
}
