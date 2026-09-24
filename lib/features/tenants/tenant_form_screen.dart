import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/date_helpers.dart';
import '../../core/utils/format.dart';
import '../../core/utils/photo_store.dart';
import '../../core/widgets/common.dart';
import '../../data/models.dart';
import '../../data/repository.dart';
import '../../providers.dart';

class TenantFormScreen extends ConsumerStatefulWidget {
  const TenantFormScreen({super.key, this.tenant, this.roomId});

  /// null = add a new tenant (check-in).
  final Tenant? tenant;

  /// Pre-selected room when adding from a room's detail page.
  final int? roomId;

  @override
  ConsumerState<TenantFormScreen> createState() => _TenantFormScreenState();
}

class _TenantFormScreenState extends ConsumerState<TenantFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _idNumber = TextEditingController();
  final _institution = TextEditingController();
  final _institutionAddress = TextEditingController();
  final _homeAddress = TextEditingController();
  final _emName = TextEditingController();
  final _emRelation = TextEditingController();
  final _emPhone = TextEditingController();
  final _emAddress = TextEditingController();
  final _rent = TextEditingController();
  final _deposit = TextEditingController();
  final _notes = TextEditingController();

  String? _idPhoto;
  String? _originalIdPhoto;
  int? _roomId;
  DateTime _moveIn = todayDate();
  DateTime? _endDate;
  bool _billFromCurrent = true;
  bool _rentTouched = false;
  bool _saving = false;
  List<Room> _eligibleRooms = [];
  bool _roomsLoaded = false;

  bool get _editing => widget.tenant != null;

  @override
  void initState() {
    super.initState();
    final t = widget.tenant;
    if (t != null) {
      _name.text = t.name;
      _phone.text = t.phone;
      _idNumber.text = t.idNumber;
      _institution.text = t.institution;
      _institutionAddress.text = t.institutionAddress;
      _homeAddress.text = t.homeAddress;
      _emName.text = t.emergencyName;
      _emRelation.text = t.emergencyRelation;
      _emPhone.text = t.emergencyPhone;
      _emAddress.text = t.emergencyAddress;
      _rent.text = t.rentAmount.toString();
      _notes.text = t.notes;
      _idPhoto = t.idPhoto;
      _originalIdPhoto = t.idPhoto;
      _roomId = t.roomId;
      _moveIn = t.moveInDate;
      _endDate = t.endDate;
      _rentTouched = true;
    } else {
      _roomId = widget.roomId;
      _loadRooms();
    }
  }

  Future<void> _loadRooms() async {
    final rooms = await ref.read(repoProvider).getRooms();
    if (!mounted) return;
    final eligible = rooms
        .where((r) =>
            r.status == RoomStatus.available || r.status == RoomStatus.reserved)
        .toList();
    setState(() {
      _eligibleRooms = eligible;
      _roomsLoaded = true;
    });
    if (_roomId != null) {
      final match = eligible.where((r) => r.id == _roomId).firstOrNull;
      if (match != null) {
        _selectRoom(match);
      } else {
        setState(() => _roomId = null);
      }
    }
  }

  void _selectRoom(Room room) {
    setState(() {
      _roomId = room.id;
      if (!_rentTouched) _rent.text = room.price.toString();
    });
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _phone,
      _idNumber,
      _institution,
      _institutionAddress,
      _homeAddress,
      _emName,
      _emRelation,
      _emPhone,
      _emAddress,
      _rent,
      _deposit,
      _notes,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickIdPhoto() async {
    final name = await pickPhotoSheet(context);
    if (name == null) return;
    // A photo picked in this session but not saved is replaced right away.
    if (_idPhoto != null && _idPhoto != _originalIdPhoto) {
      await PhotoStore.delete(_idPhoto);
    }
    setState(() => _idPhoto = name);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_editing && _roomId == null) {
      snack(context, 'Select a room for this tenant.');
      return;
    }
    if (_endDate != null && !_endDate!.isAfter(_moveIn)) {
      snack(context, 'End date must be after the move-in date.');
      return;
    }

    setState(() => _saving = true);
    final repo = ref.read(repoProvider);
    final old = widget.tenant;
    final rent = parseMoney(_rent.text) ?? 0;

    final latest = latestDueOnOrBefore(_moveIn, todayDate());
    final billingStart =
        (!_editing && _billFromCurrent && latest.isAfter(_moveIn))
            ? latest
            : _moveIn;

    final tenant = Tenant(
      id: old?.id,
      roomId: _roomId,
      roomName: old?.roomName ?? '',
      name: _name.text.trim(),
      phone: _phone.text.trim(),
      idNumber: _idNumber.text.trim(),
      idPhoto: _idPhoto,
      institution: _institution.text.trim(),
      institutionAddress: _institutionAddress.text.trim(),
      homeAddress: _homeAddress.text.trim(),
      emergencyName: _emName.text.trim(),
      emergencyRelation: _emRelation.text.trim(),
      emergencyPhone: _emPhone.text.trim(),
      emergencyAddress: _emAddress.text.trim(),
      rentAmount: rent,
      moveInDate: old?.moveInDate ?? _moveIn,
      billingStart: old?.billingStart ?? billingStart,
      endDate: _endDate,
      moveOutDate: old?.moveOutDate,
      isActive: old?.isActive ?? true,
      notes: _notes.text.trim(),
    );

    try {
      if (_editing) {
        await repo.updateTenant(tenant);
        if (_originalIdPhoto != null && _originalIdPhoto != _idPhoto) {
          await PhotoStore.delete(_originalIdPhoto);
        }
      } else {
        await repo.addTenant(tenant, deposit: parseMoney(_deposit.text) ?? 0);
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

  Widget _heading(String text) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 12),
        child: Text(text, style: Theme.of(context).textTheme.titleMedium),
      );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final latest = latestDueOnOrBefore(_moveIn, todayDate());
    final showBackfill = !_editing && latest.isAfter(_moveIn);

    return Scaffold(
      appBar: AppBar(title: Text(_editing ? 'Edit tenant' : 'Add tenant')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ---- room
            Text('Room', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (_editing)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(widget.tenant!.roomName.isEmpty
                    ? '-'
                    : widget.tenant!.roomName),
              )
            else if (!_roomsLoaded)
              const Padding(
                padding: EdgeInsets.all(8),
                child: LinearProgressIndicator(),
              )
            else if (_eligibleRooms.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'No available or reserved rooms. Add a room, or check out a tenant first.',
                  style: TextStyle(color: scheme.error),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final r in _eligibleRooms)
                      ChoiceChip(
                        label: Text(r.name),
                        selected: _roomId == r.id,
                        onSelected: (_) => _selectRoom(r),
                      ),
                  ],
                ),
              ),

            // ---- personal
            _heading('Personal details'),
            appTextField(
              controller: _name,
              label: 'Full name',
              icon: Icons.person_outline,
              capitalization: TextCapitalization.words,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter the name' : null,
            ),
            appTextField(
              controller: _phone,
              label: 'Phone / WhatsApp',
              icon: Icons.chat_outlined,
              type: TextInputType.phone,
              helper: 'Used for WhatsApp invoices and reminders',
            ),
            appTextField(
              controller: _idNumber,
              label: 'ID number (KTP / NIK)',
              icon: Icons.badge_outlined,
              type: TextInputType.number,
            ),
            Row(
              children: [
                PhotoThumb(
                  name: _idPhoto,
                  size: 72,
                  placeholderIcon: Icons.badge_outlined,
                  onTap: _idPhoto == null
                      ? null
                      : () => openPhoto(context, _idPhoto!),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.add_a_photo_outlined),
                        label: Text(_idPhoto == null ? 'Add ID photo' : 'Replace'),
                        onPressed: _pickIdPhoto,
                      ),
                      if (_idPhoto != null)
                        TextButton(
                          onPressed: () async {
                            if (_idPhoto != _originalIdPhoto) {
                              await PhotoStore.delete(_idPhoto);
                            }
                            setState(() => _idPhoto = null);
                          },
                          child: const Text('Remove'),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            appTextField(
              controller: _institution,
              label: 'School / workplace',
              icon: Icons.work_outline,
              capitalization: TextCapitalization.words,
            ),
            appTextField(
              controller: _institutionAddress,
              label: 'School / workplace address',
              icon: Icons.location_on_outlined,
              maxLines: 2,
            ),
            appTextField(
              controller: _homeAddress,
              label: 'Home address',
              icon: Icons.home_outlined,
              maxLines: 2,
            ),

            // ---- emergency
            _heading('Emergency contact'),
            appTextField(
              controller: _emName,
              label: 'Contact name',
              icon: Icons.contact_phone_outlined,
              capitalization: TextCapitalization.words,
            ),
            appTextField(
              controller: _emRelation,
              label: 'Relationship (e.g. mother, brother)',
              icon: Icons.groups_outlined,
            ),
            appTextField(
              controller: _emPhone,
              label: 'Contact phone',
              icon: Icons.phone_outlined,
              type: TextInputType.phone,
            ),
            appTextField(
              controller: _emAddress,
              label: 'Contact address',
              icon: Icons.place_outlined,
              maxLines: 2,
            ),

            // ---- lease
            _heading('Stay & rent'),
            DateField(
              label: 'Move-in date',
              value: _moveIn,
              enabled: !_editing,
              onChanged: (d) {
                if (d != null) setState(() => _moveIn = d);
              },
            ),
            if (_editing)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'The move-in date can\'t be changed because invoices are already based on it.',
                  style: TextStyle(fontSize: 12, color: scheme.outline),
                ),
              ),
            if (showBackfill)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Existing tenant: bill from current period'),
                subtitle: Text(
                  _billFromCurrent
                      ? 'First invoice is due ${fmtDate(latest)}. Old months are not created.'
                      : 'Invoices will be created for every month since move-in (all unpaid).',
                ),
                value: _billFromCurrent,
                onChanged: (v) => setState(() => _billFromCurrent = v),
              ),
            DateField(
              label: 'End date (optional)',
              value: _endDate,
              clearable: true,
              firstDate: addDays(_moveIn, 1),
              onChanged: (d) => setState(() => _endDate = d),
            ),
            moneyField(
              controller: _rent,
              label: 'Rent per month',
              icon: Icons.payments_outlined,
              onChanged: (_) => _rentTouched = true,
              validator: (v) {
                final n = parseMoney(v ?? '');
                return (n == null || n <= 0) ? 'Enter the monthly rent' : null;
              },
              helper: _editing
                  ? 'Changes apply to invoices created from now on'
                  : 'Prefilled from the room price',
            ),
            if (!_editing)
              moneyField(
                controller: _deposit,
                label: 'Deposit received (optional)',
                icon: Icons.savings_outlined,
              ),
            appTextField(
              controller: _notes,
              label: 'Notes (optional)',
              icon: Icons.note_alt_outlined,
              maxLines: 3,
            ),
            const SizedBox(height: 4),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_editing ? 'Save changes' : 'Add tenant'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
