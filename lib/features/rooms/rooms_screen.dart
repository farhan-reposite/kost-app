import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/format.dart';
import '../../core/widgets/common.dart';
import '../../data/models.dart';
import '../../providers.dart';
import 'room_detail_screen.dart';
import 'room_form_screen.dart';

class RoomsScreen extends ConsumerStatefulWidget {
  const RoomsScreen({super.key});

  @override
  ConsumerState<RoomsScreen> createState() => _RoomsScreenState();
}

class _RoomsScreenState extends ConsumerState<RoomsScreen> {
  RoomStatus? _filter;

  @override
  Widget build(BuildContext context) {
    final rooms = ref.watch(roomOverviewsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Rooms')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const RoomFormScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Add room'),
      ),
      body: rooms.ui(data: (list) {
        if (list.isEmpty) {
          return const EmptyState(
            icon: Icons.meeting_room_outlined,
            message: 'No rooms yet.\nTap "Add room" to create your first one.',
          );
        }
        int count(RoomStatus s) => list.where((o) => o.room.status == s).length;
        final shown = _filter == null
            ? list
            : list.where((o) => o.room.status == _filter).toList();

        return Column(
          children: [
            SizedBox(
              height: 56,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text('All (${list.length})'),
                      selected: _filter == null,
                      onSelected: (_) => setState(() => _filter = null),
                    ),
                  ),
                  for (final s in RoomStatus.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text('${s.label} (${count(s)})'),
                        selected: _filter == s,
                        onSelected: (_) => setState(() => _filter = s),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: shown.isEmpty
                  ? const EmptyState(
                      icon: Icons.filter_alt_off_outlined,
                      message: 'No rooms with this status.',
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 96),
                      itemCount: shown.length,
                      itemBuilder: (_, i) => _RoomCard(overview: shown[i]),
                    ),
            ),
          ],
        );
      }),
    );
  }
}

class _RoomCard extends StatelessWidget {
  const _RoomCard({required this.overview});
  final RoomOverview overview;

  @override
  Widget build(BuildContext context) {
    final room = overview.room;
    final tenant = overview.tenant;
    final due = overview.nextDue;
    final scheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => RoomDetailScreen(roomId: room.id!)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              PhotoThumb(
                name: overview.coverPhoto,
                size: 76,
                placeholderIcon: Icons.bed_outlined,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            room.name,
                            style: Theme.of(context).textTheme.titleMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        RoomStatusPill(room.status),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('${rp(room.price)} / month'),
                    if (tenant != null)
                      Text(
                        tenant.name,
                        style: TextStyle(color: scheme.onSurfaceVariant),
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (tenant != null && due != null)
                      Text(
                        dueLabel(due),
                        style: TextStyle(
                          fontSize: 12,
                          color: isOverdue(due)
                              ? scheme.error
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
