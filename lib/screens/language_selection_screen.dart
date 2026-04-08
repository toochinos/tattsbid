import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

/// First-launch language picker (before onboarding / sign-in).
class LanguageSelectionScreen extends StatefulWidget {
  const LanguageSelectionScreen({
    super.key,
    required this.onLanguageSelected,
  });

  final Future<void> Function(String languageCode) onLanguageSelected;

  @override
  State<LanguageSelectionScreen> createState() =>
      _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends State<LanguageSelectionScreen> {
  bool _busy = false;

  Future<void> _tap(String code) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.onLanguageSelected(code);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Text(
                l10n.languagePickerTitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.languagePickerSubtitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
              const SizedBox(height: 40),
              FilledButton(
                onPressed: _busy ? null : () => _tap('en'),
                child: Text(l10n.languageEnglish),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _busy ? null : () => _tap('km'),
                child: Text(l10n.languageKhmer),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _busy ? null : () => _tap('id'),
                child: Text(l10n.languageIndonesian),
              ),
              if (_busy) ...[
                const SizedBox(height: 24),
                const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ],
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }
}
