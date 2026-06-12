import 'package:flutter/material.dart';

import '../core/services/account_deletion_service.dart';
import '../l10n/app_localizations.dart';

/// GDPR account deletion with typed confirmation and loading state.
class DeleteAccountPage extends StatefulWidget {
  const DeleteAccountPage({super.key});

  @override
  State<DeleteAccountPage> createState() => _DeleteAccountPageState();
}

class _DeleteAccountPageState extends State<DeleteAccountPage> {
  static const _confirmToken = 'DELETE';

  final _confirmController = TextEditingController();
  bool _isDeleting = false;

  @override
  void dispose() {
    _confirmController.dispose();
    super.dispose();
  }

  bool get _canConfirm =>
      !_isDeleting && _confirmController.text.trim() == _confirmToken;

  Future<void> _submitDeletion() async {
    if (!_canConfirm) return;

    setState(() => _isDeleting = true);

    try {
      await AccountDeletionService.deleteAccount();
    } on AccountDeletionException catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.settingsAccountDeleteFailed(e.message)),
        ),
      );
      setState(() => _isDeleting = false);
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.settingsAccountDeleteFailed(e.toString())),
        ),
      );
      setState(() => _isDeleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final errorColor = theme.colorScheme.error;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.deleteAccountTitle)),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Icon(Icons.warning_amber_rounded, color: errorColor, size: 48),
              const SizedBox(height: 16),
              Text(
                l10n.deleteAccountWarningTitle,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: errorColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.deleteAccountWarningBody,
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 24),
              Text(
                l10n.deleteAccountTypePrompt,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _confirmController,
                enabled: !_isDeleting,
                autocorrect: false,
                textCapitalization: TextCapitalization.characters,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  hintText: l10n.deleteAccountTypeHint,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) {
                  if (!_canConfirm) return;
                  FocusScope.of(context).unfocus();
                  _submitDeletion();
                },
              ),
              const SizedBox(height: 24),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: errorColor,
                  disabledBackgroundColor: errorColor.withValues(alpha: 0.35),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: _canConfirm ? _submitDeletion : null,
                child: Text(
                  l10n.deleteAccountConfirmButton,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
          if (_isDeleting)
            ColoredBox(
              color: Colors.black.withValues(alpha: 0.35),
              child: Center(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(l10n.deleteAccountDeleting),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
