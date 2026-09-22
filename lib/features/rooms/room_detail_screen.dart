import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/format.dart';
import '../../core/utils/launch.dart';
import '../../core/widgets/common.dart';
import '../../data/models.dart';
import '../../data/repository.dart';
import '../../providers.dart';
import '../tenants/checkout_screen.dart';
import '../tenants/deposit_screen.dart';
import '../tenants/tenant_detail_screen.dart';
import '../tenants/tenant_form_screen.dart';
import 'room_form_screen.dart';

class RoomDetailScreen extends ConsumerWidget {
  const RoomDetailScreen({super.key, required this.roomId});
  final int roomId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomAsync = ref.watch(roomProvider(roomId));
    final tenantAsync = ref.watch(roomTenantProvider(roomId));
    final room = roomAsync.valueOrNull;

    if (room == null) {
      return Scaffold(
        appBar: AppBar(),
        body: roomAsync.isLoading
            ? const Center(child: CircularProgressIndicator())
            : const SizedBox.shrink(),
      );
    }
    final overview = tenantAsync.valueOrNull;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(room.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit room',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => RoomFormScreen(
                  room: room,
                  hasTenant: overview != null,
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete room',
            onPressed: () => _delete(context, ref, room),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          _PhotoStrip(roomId: roomId),
          SectionCard(
            title: 'Room',
            trailing: RoomStatusPill(room.status),
            children: [
              InfoRow('Price', '${rp(room.price)} / month'),
              if (room.notes.isNotEmpty) InfoRow('Notes', room.notes),
              const SizedBox(height: 8),
              Text('Facilities',
                  style: TextStyle(color: scheme.onSurfaceVariant)),
              const SizedBox(height: 6),
              if (room.facilities.isEmpty)
                const Text('None listed')
              else
                Wrap(
                  spacing: 6,
                  runSpacing: 0,
                  children: [
                    for (final f in room.facilities)
                      Chip(
                        label: Text(f),
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
            ],
          ),
          if (!tenantAsync.hasValue)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (overview != null)
            _CurrentTenantCard(overview: overview)
          else
            SectionCard(
              title: 'Tenant',
              children: [
                const Text('No tenant in this room.'),
                const SizedBox(height: 12),
                if (room.status == RoomStatus.maintenance)
                  Text(
                    'This room is under maintenance. Set it to Available or Reserved (Edit room) before adding a tenant.',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  )
                else
                  FilledButton.icon(
                    icon: const Icon(Icons.person_add_alt_1),
                    label: const Text('Add tenant'),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => TenantFormScreen(roomId: room.id),
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Room room) async {
    final ok = await confirmDialog(
      context,
      title: 'Delete ${room.name}?',
      message:
          'The room and its photos will be removed. Records of past tenants and their payments are kept.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok) return;
    try {
      await ref.read(repoProvider).deleteRoom(room.id!);
      notifyChanged(ref);
      if (context.mounted) Navigator.of(context).pop();
    } on KostException catch (e) {
      if (context.mounted) snack(context, e.message);
    }
  }
}

// ------------------------------------------------------------------ photos

class _PhotoStrip extends ConsumerWidget {
  const _PhotoStrip({required this.roomId});
  final int roomId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photos = ref.watch(roomPhotosProvider(roomId)).valueOrNull ?? [];
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 110,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                InkWell(
                  onTap: () async {
                    final name = await pickPhotoSheet(context);
                    if (name == null) return;
                    await ref.read(repoProvider).addRoomPhoto(roomId, name);
                    notifyChanged(ref);
                  },
                  child: Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      border: Border.all(color: scheme.outline),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_a_photo_outlined),
                        SizedBox(height: 4),
                        Text('Add photo'),
                      ],
                    ),
                  ),
                ),
                for (final photo in photos)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: GestureDetector(
                      onLongPress: () async {
                        final ok = await confirmDialog(
                          context,
                          title: 'Delete photo?',
                          message: 'This photo will be removed from the room.',
                          confirmLabel: 'Delete',
                          destructive: true,
                        );
                        if (!ok) return;
                        await ref.read(repoProvider).deleteRoomPhoto(photo);
                        notifyChanged(ref);
                      },
                      child: PhotoThumb(
                        name: photo.path,
                        size: 110,
                        onTap: () => openPhoto(context, photo.path),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (photos.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Text(
                'Tap to view, long-press to delete',
                style: TextStyle(fontSize: 12, color: scheme.outline),
              ),
            ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------- current tenant

class _CurrentTenantCard extends ConsumerWidget {
  const _CurrentTenantCard({required this.overview});
  final TenantOverview overview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = overview.tenant;
    final scheme = Theme.of(context).colorScheme;
    final held = ref.watch(depositHeldProvider(t.id!)).valueOrNull;
    final due = overview.nextDue;

    return SectionCard(
      title: 'Current tenant',
      children: [
        Row(
          children: [
            Expanded(
              child: Text(t.name,
                  style: Theme.of(context).textTheme.titleLarge),
            ),
            IconButton(
              icon: const Icon(Icons.call_outlined),
              tooltip: 'Call',
              onPressed: () => callNumber(context, t.phone),
            ),
            IconButton(
              icon: const Icon(Icons.chat_outlined),
              tooltip: 'WhatsApp',
              onPressed: () => openWhatsApp(context, t.phone),
            ),
          ],
        ),
        InfoRow('Phone', t.phone),
        InfoRow('School / work', t.institution),
        InfoRow('Home address', t.homeAddress),
        const Divider(height: 24),
        InfoRow('Stay',
            '${fmtDate(t.moveInDate)} - ${t.endDate == null ? 'no end date' : fmtDate(t.endDate)}'),
        InfoRow('Rent', '${rp(t.rentAmount)} / month'),
        InfoRow(
          'Next due',
          due == null ? 'None scheduled' : dueLabel(due),
          valueColor: (due != null && isOverdue(due)) ? scheme.error : null,
        ),
        if (overview.outstanding > 0)
          InfoRow('Outstanding', rp(overview.outstanding),
              valueColor: scheme.error),
        InfoRow('Deposit held', held == null ? '...' : rp(held)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.person_outline),
              label: const Text('Full details'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => TenantDetailScreen(tenantId: t.id!),
                ),
              ),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.savings_outlined),
              label: const Text('Deposit history'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => DepositScreen(tenantId: t.id!),
                ),
              ),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.logout),
              label: const Text('Check out'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => CheckoutScreen(tenantId: t.id!),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
