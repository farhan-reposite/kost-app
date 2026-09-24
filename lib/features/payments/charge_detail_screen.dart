import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/date_helpers.dart';
import '../../core/utils/format.dart';
import '../../core/utils/launch.dart';
import '../../core/widgets/common.dart';
import '../../data/models.dart';
import '../../data/repository.dart';
import '../../providers.dart';
import 'invoice_service.dart';

class ChargeDetailScreen extends ConsumerWidget {
  const ChargeDetailScreen({super.key, required this.chargeId});
  final int chargeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(chargeProvider(chargeId));
    final view = async.valueOrNull;

    if (view == null) {
      return Scaffold(
        appBar: AppBar(),
        body: async.isLoading
            ? const Center(child: CircularProgressIndicator())
            : const SizedBox.shrink(),
      );
    }

    final c = view.charge;
    final status = c.statusOn(todayDate());
    final payments = ref.watch(paymentsProvider(chargeId)).valueOrNull ?? [];
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(InvoiceService.number(view)),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'amount') _editAmount(context, ref, view);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'amount', child: Text('Edit invoice amount')),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          SectionCard(
            title: 'Invoice',
            trailing: PaymentStatusPill(status),
            children: [
              InfoRow('Tenant', view.tenantName),
              InfoRow('Room', view.roomName),
              InfoRow('Period', '${fmtDate(c.dueDate)} – ${fmtDate(c.periodEnd)}'),
              InfoRow(
                'Due date',
                fmtDate(c.dueDate),
                valueColor:
                    status == PaymentStatus.overdue ? scheme.error : null,
              ),
              const Divider(height: 24),
              InfoRow('Amount', rp(c.amount)),
              InfoRow('Paid', rp(c.paidAmount)),
              InfoRow(
                'Remaining',
                rp(c.remaining),
                valueColor: c.remaining > 0 ? scheme.error : null,
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (c.remaining > 0)
                  FilledButton.icon(
                    icon: const Icon(Icons.payments_outlined),
                    label: const Text('Record payment'),
                    onPressed: () => showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      useSafeArea: true,
                      builder: (_) => RecordPaymentSheet(view: view),
                    ),
                  ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('Share invoice'),
                  onPressed: () => _shareInvoice(context, ref, view),
                ),
                if (view.tenantPhone.isNotEmpty)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.chat_outlined),
                    label: Text(c.remaining > 0
                        ? 'WhatsApp reminder'
                        : 'WhatsApp receipt'),
                    onPressed: () => _whatsApp(context, ref, view),
                  ),
              ],
            ),
          ),
          SectionCard(
            title: 'Payments received',
            children: [
              if (payments.isEmpty)
                const Text('No payments recorded yet.')
              else
                for (final p in payments)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: p.proofPhoto == null
                        ? const Icon(Icons.check_circle_outline)
                        : PhotoThumb(
                            name: p.proofPhoto,
                            size: 44,
                            onTap: () => openPhoto(context, p.proofPhoto!),
                          ),
                    title: Text(rp(p.amount)),
                    subtitle: Text(
                      '${fmtDate(p.paidOn)} · ${p.method}${p.note.isEmpty ? '' : '\n${p.note}'}',
                    ),
                    isThreeLine: p.note.isNotEmpty,
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: 'Delete payment',
                      onPressed: () async {
                        final ok = await confirmDialog(
                          context,
                          title: 'Delete this payment?',
                          message:
                              'Use this to fix a mistake. The invoice balance will go back up by ${rp(p.amount)}.',
                          confirmLabel: 'Delete',
                          destructive: true,
                        );
                        if (!ok) return;
                        await ref.read(repoProvider).deletePayment(p);
                        notifyChanged(ref);
                      },
                    ),
                  ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _shareInvoice(
      BuildContext context, WidgetRef ref, ChargeView view) async {
    try {
      final profile = await ref.read(repoProvider).getProfile();
      await InvoiceService.sharePdf(view, profile);
    } catch (e) {
      if (context.mounted) snack(context, 'Could not create the invoice: $e');
    }
  }

  Future<void> _whatsApp(
      BuildContext context, WidgetRef ref, ChargeView view) async {
    final profile = await ref.read(repoProvider).getProfile();
    if (!context.mounted) return;
    await openWhatsApp(
        context, view.tenantPhone, InvoiceService.message(view, profile));
  }

  Future<void> _editAmount(
      BuildContext context, WidgetRef ref, ChargeView view) async {
    final controller =
        TextEditingController(text: view.charge.amount.toString());
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit invoice amount'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            prefixText: 'Rp ',
            helperText: 'For a discount or an extra charge',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, parseMoney(controller.text)),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result == null) return;
    try {
      await ref.read(repoProvider).updateChargeAmount(view.charge.id, result);
      notifyChanged(ref);
    } on KostException catch (e) {
      if (context.mounted) snack(context, e.message);
    }
  }
}

// -------------------------------------------------------- record payment

class RecordPaymentSheet extends ConsumerStatefulWidget {
  const RecordPaymentSheet({super.key, required this.view});
  final ChargeView view;

  @override
  ConsumerState<RecordPaymentSheet> createState() => _RecordPaymentSheetState();
}

class _RecordPaymentSheetState extends ConsumerState<RecordPaymentSheet> {
  late final TextEditingController _amount;
  final _note = TextEditingController();
  DateTime _date = todayDate();
  String _method = kPaymentMethods.first;
  String? _proof;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _amount =
        TextEditingController(text: widget.view.charge.remaining.toString());
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = parseMoney(_amount.text);
    if (amount == null || amount <= 0) {
      snack(context, 'Enter the amount received.');
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(repoProvider).addPayment(
            chargeId: widget.view.charge.id,
            amount: amount,
            date: _date,
            method: _method,
            proofPhoto: _proof,
            note: _note.text.trim(),
          );
      notifyChanged(ref);
      if (mounted) Navigator.of(context).pop();
    } on KostException catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        snack(context, e.message);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final remaining = widget.view.charge.remaining;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Record payment',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text('Remaining balance: ${rp(remaining)}'),
            const SizedBox(height: 16),
            moneyField(
              controller: _amount,
              label: 'Amount received',
              icon: Icons.payments_outlined,
              helper: 'Enter less than the balance for a partial payment',
            ),
            DateField(
              label: 'Payment date',
              value: _date,
              onChanged: (d) {
                if (d != null) setState(() => _date = d);
              },
            ),
            Wrap(
              spacing: 8,
              children: [
                for (final m in kPaymentMethods)
                  ChoiceChip(
                    label: Text(m),
                    selected: _method == m,
                    onSelected: (_) => setState(() => _method = m),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                PhotoThumb(
                  name: _proof,
                  size: 56,
                  placeholderIcon: Icons.receipt_outlined,
                  onTap: _proof == null ? null : () => openPhoto(context, _proof!),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.add_a_photo_outlined),
                  label: Text(_proof == null
                      ? 'Add proof of transfer'
                      : 'Replace photo'),
                  onPressed: () async {
                    final name = await pickPhotoSheet(context);
                    if (name != null) setState(() => _proof = name);
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            appTextField(
              controller: _note,
              label: 'Note (optional)',
              icon: Icons.note_alt_outlined,
            ),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: const Text('Save payment'),
            ),
          ],
        ),
      ),
    );
  }
}
