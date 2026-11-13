import 'package:flutter/material.dart';

import 'calendar_page.dart';
import 'ferms_animations.dart';
import 'ferms_models.dart';
import 'ferms_repository.dart';

class ResourcesPage extends StatelessWidget {
  const ResourcesPage({
    super.key,
    required this.repository,
    required this.user,
    required this.facilities,
    required this.equipment,
    required this.onRefresh,
  });

  final FermsRepository repository;
  final FermsUser user;
  final List<Facility> facilities;
  final List<Equipment> equipment;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
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
              'Resources',
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push<void>(
                fermsPageRoute(CalendarPage(repository: repository)),
              ),
              icon: const Icon(Icons.calendar_month_outlined),
              label: const Text('Facility calendar'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const TabBar(
          isScrollable: true,
          tabs: [
            Tab(icon: Icon(Icons.apartment_outlined), text: 'Facilities'),
            Tab(icon: Icon(Icons.inventory_2_outlined), text: 'Equipment'),
          ],
        ),
        Expanded(
          child: TabBarView(
            children: [
              _FacilityList(
                repository: repository,
                user: user,
                facilities: facilities,
                onRefresh: onRefresh,
              ),
              _EquipmentList(
                repository: repository,
                user: user,
                equipment: equipment,
                onRefresh: onRefresh,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _FacilityList extends StatelessWidget {
  const _FacilityList({
    required this.repository,
    required this.user,
    required this.facilities,
    required this.onRefresh,
  });

  final FermsRepository repository;
  final FermsUser user;
  final List<Facility> facilities;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      if (user.canManageResources)
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 8),
          child: Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: () => _editFacility(context),
              icon: const Icon(Icons.add),
              label: const Text('Add facility'),
            ),
          ),
        ),
      Expanded(
        child: facilities.isEmpty
            ? const _EmptyResources('No facilities are available.')
            : RefreshIndicator(
                onRefresh: onRefresh,
                child: ListView.separated(
                  padding: const EdgeInsets.only(top: 10, bottom: 24),
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: facilities.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final facility = facilities[index];
                    return _ResourceTile(
                      title: facility.name,
                      subtitle: facility.notes.isNotEmpty
                          ? facility.notes
                          : facility.description,
                      icon: Icons.apartment_outlined,
                      detail: [
                        if (facility.capacity > 0)
                          '${facility.capacity} people',
                        if (facility.location.isNotEmpty) facility.location,
                        if (facility.staffInCharge.isNotEmpty)
                          'Staff: ${facility.staffInCharge}',
                      ].join(' · '),
                      schedule: facility.schedule,
                      managed: user.canManageResources,
                      onEdit: () => _editFacility(context, facility),
                      onDelete: () => _deleteResource(
                        context,
                        title: facility.name,
                        delete: () => repository.deleteFacility(facility.id),
                        onRefresh: onRefresh,
                      ),
                    );
                  },
                ),
              ),
      ),
    ],
  );

  Future<void> _editFacility(BuildContext context, [Facility? facility]) async {
    final changed = await Navigator.of(context).push<bool>(
      fermsPageRoute(
        _ResourceForm(
          repository: repository,
          facility: facility,
          isFacility: true,
        ),
      ),
    );
    if (changed == true) await onRefresh();
  }
}

class _EquipmentList extends StatefulWidget {
  const _EquipmentList({
    required this.repository,
    required this.user,
    required this.equipment,
    required this.onRefresh,
  });

  final FermsRepository repository;
  final FermsUser user;
  final List<Equipment> equipment;
  final Future<void> Function() onRefresh;

  @override
  State<_EquipmentList> createState() => _EquipmentListState();
}

class _EquipmentListState extends State<_EquipmentList> {
  String _query = '';
  String _category = '*';

  List<Equipment> get _filteredEquipment {
    final query = _query.trim().toLowerCase();
    return widget.equipment.where((item) {
      final matchesCategory = switch (_category) {
        '*' => true,
        '' => item.category == null || item.category!.trim().isEmpty,
        _ => item.category == _category,
      };
      final searchable =
          '${item.name} ${item.description} ${item.notes} ${item.staffInCharge}'
              .toLowerCase();
      return matchesCategory && (query.isEmpty || searchable.contains(query));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final categories =
        widget.equipment
            .map((item) => item.category?.trim() ?? '')
            .where((category) => category.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    final filtered = _filteredEquipment;
    return Column(
      children: [
        if (widget.user.canManageResources)
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: () => _editEquipment(context),
                icon: const Icon(Icons.add),
                label: const Text('Add equipment'),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 8),
          child: Column(
            children: [
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Search equipment',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: [
                  const DropdownMenuItem(
                    value: '*',
                    child: Text('All categories'),
                  ),
                  ...categories.map(
                    (category) => DropdownMenuItem(
                      value: category,
                      child: Text(category),
                    ),
                  ),
                  if (widget.equipment.any(
                    (item) =>
                        item.category == null || item.category!.trim().isEmpty,
                  ))
                    const DropdownMenuItem(
                      value: '',
                      child: Text('Uncategorized'),
                    ),
                ],
                onChanged: (value) => setState(() => _category = value ?? '*'),
              ),
            ],
          ),
        ),
        Expanded(
          child: widget.equipment.isEmpty
              ? const _EmptyResources('No equipment is available.')
              : filtered.isEmpty
              ? const _EmptyResources('No equipment matches these filters.')
              : RefreshIndicator(
                  onRefresh: widget.onRefresh,
                  child: ListView.separated(
                    padding: const EdgeInsets.only(top: 10, bottom: 24),
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = filtered[index];
                      return _ResourceTile(
                        title: item.name,
                        subtitle: [
                          if (item.description.isNotEmpty) item.description,
                          if (item.notes.isNotEmpty) item.notes,
                        ].join('\n'),
                        icon: Icons.inventory_2_outlined,
                        detail: [
                          '${item.availableQuantity} available of ${item.quantity}',
                          if (item.category?.isNotEmpty == true) item.category!,
                          if (item.staffInCharge.isNotEmpty)
                            'Staff: ${item.staffInCharge}',
                        ].join(' · '),
                        schedule: item.schedule,
                        managed: widget.user.canManageResources,
                        onEdit: () => _editEquipment(context, item),
                        onDelete: () => _deleteResource(
                          context,
                          title: item.name,
                          delete: () =>
                              widget.repository.deleteEquipment(item.id),
                          onRefresh: widget.onRefresh,
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Future<void> _editEquipment(BuildContext context, [Equipment? item]) async {
    final changed = await Navigator.of(context).push<bool>(
      fermsPageRoute(
        _ResourceForm(
          repository: widget.repository,
          equipment: item,
          isFacility: false,
        ),
      ),
    );
    if (changed == true) await widget.onRefresh();
  }
}

class _ResourceTile extends StatelessWidget {
  const _ResourceTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.detail,
    required this.schedule,
    required this.managed,
    required this.onEdit,
    required this.onDelete,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String detail;
  final List<JsonMap> schedule;
  final bool managed;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface,
    borderRadius: BorderRadius.circular(8),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    if (detail.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        detail,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (managed) ...[
                IconButton(
                  tooltip: 'Edit $title',
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  tooltip: 'Delete $title',
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ],
          ),
          if (schedule.isNotEmpty) ...[
            const Divider(height: 24),
            const Text(
              'UPCOMING SCHEDULE',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 6),
            ...schedule.take(3).map((block) {
              final date = stringValue(block['date']);
              final start = stringValue(block['start_time']);
              final end = stringValue(block['end_time']);
              final status = stringValue(block['status'], 'reserved');
              final quantity = intValue(block['quantity']);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.event_busy_outlined, size: 15),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$date  $start–$end'
                        '${quantity > 0 ? ' · $quantity units' : ''}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                    Text(
                      status,
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    ),
  );
}

class _ResourceForm extends StatefulWidget {
  const _ResourceForm({
    required this.isFacility,
    this.repository,
    this.facility,
    this.equipment,
  });

  final bool isFacility;
  final FermsRepository? repository;
  final Facility? facility;
  final Equipment? equipment;

  @override
  State<_ResourceForm> createState() => _ResourceFormState();
}

class _ResourceFormState extends State<_ResourceForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _location;
  late final TextEditingController _category;
  late final TextEditingController _staffInCharge;
  late final TextEditingController _notes;
  late final TextEditingController _quantity;
  bool _active = true;
  bool _saving = false;
  String? _error;

  bool get _isFacility => widget.isFacility;
  String get _title => _isFacility ? 'facility' : 'equipment';

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(
      text: widget.facility?.name ?? widget.equipment?.name,
    );
    _location = TextEditingController(text: widget.facility?.location);
    _category = TextEditingController(text: widget.equipment?.category);
    _staffInCharge = TextEditingController(
      text: widget.facility?.staffInCharge ?? widget.equipment?.staffInCharge,
    );
    _notes = TextEditingController(
      text:
          widget.facility?.notes ??
          widget.facility?.description ??
          widget.equipment?.notes ??
          widget.equipment?.description,
    );
    _quantity = TextEditingController(
      text: widget.facility != null
          ? '${widget.facility!.capacity}'
          : widget.equipment == null
          ? ''
          : '${widget.equipment!.quantity}',
    );
    _active = widget.facility?.active ?? widget.equipment?.active ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _location.dispose();
    _category.dispose();
    _staffInCharge.dispose();
    _notes.dispose();
    _quantity.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final category = _category.text.trim();
    final payload = <String, dynamic>{
      'name': _name.text.trim(),
      'staff_in_charge': _staffInCharge.text.trim(),
      'notes': _notes.text.trim(),
      'active': _active,
      if (_isFacility) 'capacity': int.parse(_quantity.text),
      if (_isFacility) 'location': _location.text.trim(),
      if (!_isFacility) ...{
        'category': category.isEmpty ? null : category,
        'quantity': int.parse(_quantity.text),
      },
    };
    try {
      if (_isFacility) {
        await widget.repository!.saveFacility(payload, id: widget.facility?.id);
      } else {
        await widget.repository!.saveEquipment(
          payload,
          id: widget.equipment?.id,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        '${widget.facility == null && widget.equipment == null ? 'Add' : 'Edit'} ${_title[0].toUpperCase()}${_title.substring(1)}',
      ),
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              TextFormField(
                controller: _name,
                enabled: !_saving,
                maxLength: 120,
                decoration: InputDecoration(
                  labelText: _isFacility ? 'Facility name' : 'Equipment name',
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter a name.'
                    : null,
              ),
              if (_isFacility) ...[
                const SizedBox(height: 14),
                TextFormField(
                  controller: _location,
                  enabled: !_saving,
                  maxLength: 160,
                  decoration: const InputDecoration(
                    labelText: 'Building / location',
                  ),
                ),
              ],
              if (!_isFacility) ...[
                const SizedBox(height: 14),
                TextFormField(
                  controller: _category,
                  enabled: !_saving,
                  maxLength: 120,
                  decoration: const InputDecoration(
                    labelText: 'Category (optional)',
                  ),
                ),
              ],
              const SizedBox(height: 14),
              TextFormField(
                controller: _staffInCharge,
                enabled: !_saving,
                maxLength: 160,
                decoration: const InputDecoration(labelText: 'Staff in charge'),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _quantity,
                enabled: !_saving,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: _isFacility ? 'Capacity' : 'Quantity in inventory',
                ),
                validator: (value) {
                  final number = int.tryParse(value ?? '');
                  if (number == null || number < 1) {
                    return 'Enter a number greater than zero.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<bool>(
                initialValue: _active,
                decoration: const InputDecoration(labelText: 'Availability'),
                items: const [
                  DropdownMenuItem(value: true, child: Text('Available')),
                  DropdownMenuItem(value: false, child: Text('Unavailable')),
                ],
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _active = value ?? _active),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _notes,
                enabled: !_saving,
                minLines: 2,
                maxLines: 4,
                maxLength: 1000,
                decoration: const InputDecoration(labelText: 'Notes'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!, style: const TextStyle(color: Color(0xFF9B2438))),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Saving…' : 'Save $_title'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Future<void> _deleteResource(
  BuildContext context, {
  required String title,
  required Future<void> Function() delete,
  required Future<void> Function() onRefresh,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Delete $title?'),
      content: const Text('This action cannot be undone.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Keep it'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  if (confirmed != true) return;
  try {
    await delete();
    await onRefresh();
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }
}

class _EmptyResources extends StatelessWidget {
  const _EmptyResources(this.message);
  final String message;

  @override
  Widget build(BuildContext context) => Center(child: Text(message));
}
