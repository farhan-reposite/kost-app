import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/date_helpers.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/common.dart';
import '../../data/models.dart';
import '../../providers.dart';
import 'charge_detail_screen.dart';

enum _Filter {
  unpaid('Unpaid'),
  overdue('Overdue'),
  paid('Paid'),
  all('All');

  const _Filter(this.label);
  final String label;
}

class PaymentsScreen extends ConsumerStatefulWidget {
  const PaymentsScreen({super.key});

  @override
  ConsumerState<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends ConsumerState<PaymentsScreen> {
  _Filter _filter = _Filter.unpaid;

  @override
  Widget build(BuildContext context) {
    final charges = ref.watch(chargesProvider(null));
    final collected = ref.watch(collectedThisMonthProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Payments')),
      body: charges.ui(data: (all) {
        final today = todayDate();
        var outstanding = 0;
        var overdueAmount = 0;
        for (final v in all) {
          final r = v.charge.remaining;
          if (r > 0) {
            outstanding += r;
            if (v.charge.dueDate.isBefore(today)) overdueAmount += r;
          }
        }

        final shown = all.where((v) {
          final c = v.charge;
          switch (_filter) {
            case _Filter.unpaid:
              return c.remaining > 0;
            case _Filter.overdue:
              return c.remaining > 0 && c.dueDate.isBefore(today);
            case _Filter.paid:
              return c.remaining == 0;
            case _Filter.all:
              return true;
          }
        }).toList();
        if (_filter == _Filter.unpaid || _filter == _Filter.overdue) {
          shown.sort((a, b) => a.charge.dueDate.compareTo(b.charge.dueDate));
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Row(
                children: [
                  _Stat(label: 'Outstanding', value: rp(outstanding)),
                  _Stat(
                    label: 'Overdue',
                    value: rp(overdueAmount),
                    danger: overdueAmount > 0,
                  ),
                  _Stat(
                    label: 'Collected this month',
                    value: collected == null ? '...' : rp(collected),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 56,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                children: [
                  for (final f in _Filter.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(f.label),
                        selected: _filter == f,
                        onSelected: (_) => setState(() => _filter = f),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: shown.isEmpty
                  ? EmptyState(
                      icon: Icons.receipt_long_outlined,
                      message: all.isEmpty
                          ? 'No invoices yet.\nThey are created automatically when you add a tenant.'
                          : 'Nothing here.',
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 24),
                      itemCount: shown.length,
                      itemBuilder: (_, i) => ChargeTile(view: shown[i]),
                    ),
            ),
          ],
        );
      }),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.danger = false});
  final String label;
  final String value;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: danger ? scheme.error : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One invoice row, used here and on the tenant detail page.
class ChargeTile extends StatelessWidget {
  const ChargeTile({super.key, required this.view, this.showTenant = true});
  final ChargeView view;
  final bool showTenant;

  @override
  Widget build(BuildContext context) {
    final c = view.charge;
    final status = c.statusOn(todayDate());
    final period = '${fmtDate(c.dueDate)} – ${fmtDate(c.periodEnd)}';
    final amountLine = (c.paidAmount > 0 && c.remaining > 0)
        ? 'Paid ${rp(c.paidAmount)} of ${rp(c.amount)}'
        : rp(c.amount);

    return ListTile(
      contentPadding: showTenant ? null : EdgeInsets.zero,
      title: Text(showTenant ? '${view.tenantName} · ${view.roomName}' : period),
      subtitle: Text(showTenant ? '$period\n$amountLine' : amountLine),
      isThreeLine: showTenant,
      trailing: PaymentStatusPill(status),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ChargeDetailScreen(chargeId: c.id)),
      ),
    );
  }
}
