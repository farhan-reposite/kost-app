import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/format.dart';
import '../../core/utils/launch.dart';
import '../../core/widgets/common.dart';
import '../../data/models.dart';
import '../../data/repository.dart';
import '../../providers.dart';
import '../payments/payments_screen.dart';
import 'checkout_screen.dart';
import 'deposit_screen.dart';
import 'tenant_form_screen.dart';

class TenantDetailScreen extends ConsumerWidget {
  const TenantDetailScreen({super.key, required this.tenantId});
  final int tenantId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(tenantOverviewProvider(tenantId));
    final overview = async.valueOrNull;

    if (overview == null) {
      return Scaffold(
        appBar: AppBar(),
        body: async.isLoading
            ? const Center(child: CircularProgressIndicator())
            : const SizedBox.shrink(),
      );
    }

    final t = overview.tenant;
    final scheme = Theme.of(context).colorScheme;
    final held = ref.watch(depositHeldProvider(tenantId)).valueOrNull;
    final charges = ref.watch(chargesProvider(tenantId)).valueOrNull ?? [];
    final due = overview.nextDue;

    return Scaffold(
      appBar: AppBar(
        title: Text(t.name),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) async {
              switch (v) {
                case 'edit':
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => TenantFormScreen(tenant: t)));
                case 'checkout':
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => CheckoutScreen(tenantId: tenantId)));
                case 'delete':
                  await _delete(context, ref, t);
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: Text('Edit details')),
              if (t.isActive)
                const PopupMenuItem(value: 'checkout', child: Text('Check out')),
              if (!t.isActive)
                const PopupMenuItem(
                    value: 'delete', child: Text('Delete record')),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          SectionCard(
            title: t.name,
            trailing: Pill(
              label: t.isActive ? 'Active' : 'Moved out',
              colors: t.isActive
                  ? const StatusColors(Color(0xFFDDF3E4), Color(0xFF17703A))
                  : const StatusColors(Color(0xFFE6E6E6), Color(0xFF444444)),
            ),
            children: [
              InfoRow('Room', t.roomName),
              Row(
                children: [
                  Expanded(child: InfoRow('Phone', t.phone)),
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
            ],
          ),
          SectionCard(
            title: 'Personal details',
            children: [
              InfoRow('ID number', t.idNumber),
              InfoRow('School / work', t.institution),
              InfoRow('School / work address', t.institutionAddress),
              InfoRow('Home address', t.homeAddress),
              if (t.idPhoto != null) ...[
                const SizedBox(height: 8),
                Text('ID photo',
                    style: TextStyle(color: scheme.onSurfaceVariant)),
                const SizedBox(height: 6),
                PhotoThumb(
                  name: t.idPhoto,
                  size: 120,
                  onTap: () => openPhoto(context, t.idPhoto!),
                ),
              ],
              if (t.notes.isNotEmpty) InfoRow('Notes', t.notes),
            ],
          ),
          SectionCard(
            title: 'Emergency contact',
            trailing: t.emergencyPhone.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.call_outlined),
                    tooltip: 'Call emergency contact',
                    onPressed: () => callNumber(context, t.emergencyPhone),
                  ),
            children: [
              InfoRow('Name', t.emergencyName),
              InfoRow('Relationship', t.emergencyRelation),
              InfoRow('Phone', t.emergencyPhone),
              InfoRow('Address', t.emergencyAddress),
            ],
          ),
          SectionCard(
            title: 'Stay',
            children: [
              InfoRow('Move-in', fmtDate(t.moveInDate)),
              InfoRow('End date', t.endDate == null ? 'Not set' : fmtDate(t.endDate)),
              if (!t.isActive) InfoRow('Moved out', fmtDate(t.moveOutDate)),
              InfoRow('Rent', '${rp(t.rentAmount)} / month'),
              if (t.isActive)
                InfoRow(
                  'Next due',
                  due == null ? 'None scheduled' : dueLabel(due),
                  valueColor:
                      (due != null && isOverdue(due)) ? scheme.error : null,
                ),
              if (overview.outstanding > 0)
                InfoRow('Outstanding', rp(overview.outstanding),
                    valueColor: scheme.error),
            ],
          ),
          SectionCard(
            title: 'Deposit',
            trailing: TextButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => DepositScreen(tenantId: tenantId))),
              child: const Text('History'),
            ),
            children: [
              InfoRow('Held', held == null ? '...' : rp(held)),
            ],
          ),
          SectionCard(
            title: 'Rent payments',
            children: [
              if (charges.isEmpty)
                const Text('No invoices yet.')
              else
                for (final v in charges)
                  ChargeTile(view: v, showTenant: false),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Tenant t) async {
    final ok = await confirmDialog(
      context,
      title: 'Delete ${t.name}?',
      message:
          'This permanently removes the tenant together with all their invoices, payments and deposit records. This cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok) return;
    try {
      await ref.read(repoProvider).deleteTenant(t.id!);
      notifyChanged(ref);
      if (context.mounted) Navigator.of(context).pop();
    } on KostException catch (e) {
      if (context.mounted) snack(context, e.message);
    }
  }
}
