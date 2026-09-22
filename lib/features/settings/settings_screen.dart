import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/backup_service.dart';
import '../../core/widgets/common.dart';
import '../../data/models.dart';
import '../../data/repository.dart';
import '../../providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _name = TextEditingController();
  final _paymentInfo = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final profile = await ref.read(repoProvider).getProfile();
    if (!mounted) return;
    _name.text = profile.name;
    _paymentInfo.text = profile.paymentInfo;
  }

  @override
  void dispose() {
    _name.dispose();
    _paymentInfo.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    await ref.read(repoProvider).saveProfile(KostProfile(
          name: _name.text.trim(),
          paymentInfo: _paymentInfo.text.trim(),
        ));
    if (mounted) snack(context, 'Saved.');
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } on KostException catch (e) {
      if (mounted) snack(context, e.message);
    } catch (e) {
      if (mounted) snack(context, 'Something went wrong: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );
    final path = result?.files.single.path;
    if (path == null) return;
    if (!mounted) return;

    final ok = await confirmDialog(
      context,
      title: 'Restore this backup?',
      message:
          'ALL current data (rooms, tenants, payments, photos) will be replaced by the contents of the backup. This cannot be undone.',
      confirmLabel: 'Replace everything',
      destructive: true,
    );
    if (!ok) return;

    await _run(() async {
      await BackupService.restoreBackup(File(path));
      notifyChanged(ref);
      await _loadProfile();
      if (mounted) snack(context, 'Backup restored.');
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        bottom: _busy
            ? const PreferredSize(
                preferredSize: Size.fromHeight(4),
                child: LinearProgressIndicator(),
              )
            : null,
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          SectionCard(
            title: 'Kost profile',
            children: [
              const SizedBox(height: 4),
              appTextField(
                controller: _name,
                label: 'Kost name',
                capitalization: TextCapitalization.words,
                helper: 'Shown on invoices',
              ),
              appTextField(
                controller: _paymentInfo,
                label: 'Payment instructions',
                maxLines: 3,
                helper: 'e.g. BCA 1234567890 a/n Your Name. Shown on invoices and WhatsApp messages.',
              ),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: _saveProfile,
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
          SectionCard(
            title: 'Backup & export',
            children: [
              Text(
                'All data is stored only on this phone. Make a backup regularly and keep it in Google Drive or send it to yourself.',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.backup_outlined),
                title: const Text('Create backup'),
                subtitle: const Text('Database + all photos, as one .zip file'),
                enabled: !_busy,
                onTap: () => _run(BackupService.shareBackup),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.restore_outlined),
                title: const Text('Restore from backup'),
                subtitle: const Text('Replaces all current data'),
                enabled: !_busy,
                onTap: _restore,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.table_view_outlined),
                title: const Text('Export payments (CSV)'),
                subtitle: const Text('Open in Excel or Google Sheets'),
                enabled: !_busy,
                onTap: () =>
                    _run(() => BackupService.shareCsv(ref.read(repoProvider))),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
