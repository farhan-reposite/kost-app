import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/format.dart';
import '../../core/widgets/common.dart';
import '../../data/models.dart';
import '../../data/repository.dart';
import '../../providers.dart';

class RoomFormScreen extends ConsumerStatefulWidget {
  const RoomFormScreen({super.key, this.room, this.hasTenant = false});

  /// null = add a new room.
  final Room? room;

  /// An occupied room's status is controlled by check-in / check-out.
  final bool hasTenant;

  @override
  ConsumerState<RoomFormScreen> createState() => _RoomFormScreenState();
}

class _RoomFormScreenState extends ConsumerState<RoomFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _price = TextEditingController();
  final _notes = TextEditingController();
  final _custom = TextEditingController();
  final List<String> _facilities = [];
  RoomStatus _status = RoomStatus.available;
  bool _saving = false;

  bool get _editing => widget.room != null;

  @override
  void initState() {
    super.initState();
    final r = widget.room;
    if (r != null) {
      _name.text = r.name;
      _price.text = r.price.toString();
      _notes.text = r.notes;
      _facilities.addAll(r.facilities);
      _status = r.status;
      if (!widget.hasTenant && _status == RoomStatus.occupied) {
        _status = RoomStatus.available;
      }
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _notes.dispose();
    _custom.dispose();
    super.dispose();
  }

  void _addCustom() {
    final text = _custom.text.trim();
    if (text.isEmpty) return;
    setState(() {
      if (!_facilities.contains(text)) _facilities.add(text);
      _custom.clear();
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final repo = ref.read(repoProvider);
    final room = Room(
      id: widget.room?.id,
      name: _name.text.trim(),
      price: parseMoney(_price.text) ?? 0,
      status: widget.hasTenant ? RoomStatus.occupied : _status,
      facilities: List<String>.from(_facilities),
      notes: _notes.text.trim(),
    );
    try {
      if (_editing) {
        await repo.updateRoom(room);
      } else {
        await repo.insertRoom(room);
      }
      notifyChanged(ref);
      if (mounted) Navigator.of(context).pop();
    } on KostException catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        snack(context, e.message);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final options = <String>[
      ...kFacilityPresets,
      ..._facilities.where((f) => !kFacilityPresets.contains(f)),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(_editing ? 'Edit room' : 'Add room')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            appTextField(
              controller: _name,
              label: 'Room name / number',
              capitalization: TextCapitalization.characters,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter a room name' : null,
            ),
            moneyField(
              controller: _price,
              label: 'Price per month',
              validator: (v) {
                final n = parseMoney(v ?? '');
                return (n == null || n <= 0) ? 'Enter the monthly price' : null;
              },
            ),
            Text('Status', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            if (widget.hasTenant)
              const Text(
                'Occupied - this room has a tenant. The status changes automatically when the tenant checks out.',
              )
            else
              Wrap(
                spacing: 8,
                children: [
                  for (final s in [
                    RoomStatus.available,
                    RoomStatus.reserved,
                    RoomStatus.maintenance,
                  ])
                    ChoiceChip(
                      label: Text(s.label),
                      selected: _status == s,
                      onSelected: (_) => setState(() => _status = s),
                    ),
                ],
              ),
            const SizedBox(height: 20),
            Text('Facilities', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final f in options)
                  FilterChip(
                    label: Text(f),
                    selected: _facilities.contains(f),
                    onSelected: (selected) => setState(() {
                      if (selected) {
                        _facilities.add(f);
                      } else {
                        _facilities.remove(f);
                      }
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _custom,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Other facility',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _addCustom(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  onPressed: _addCustom,
                  icon: const Icon(Icons.add),
                  tooltip: 'Add facility',
                ),
              ],
            ),
            const SizedBox(height: 20),
            appTextField(
              controller: _notes,
              label: 'Notes (optional)',
              maxLines: 3,
            ),
            if (!_editing)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'You can add photos after saving, from the room details page.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_editing ? 'Save changes' : 'Add room'),
            ),
          ],
        ),
      ),
    );
  }
}
