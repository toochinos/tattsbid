import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/constants/app_constants.dart';
import '../core/routes/app_routes.dart';

class PaywallPage extends StatefulWidget {
  const PaywallPage({super.key});

  @override
  State<PaywallPage> createState() => _PaywallPageState();
}

class _PaywallPageState extends State<PaywallPage> {
  bool _loading = false;
  String? _error;

  Future<void> _openProCheckout() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await launchUrl(
        Uri.parse(AppConstants.stripeProCheckoutUrl),
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _openProMaxCheckout() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await launchUrl(
        Uri.parse(AppConstants.stripeProMaxCheckoutUrl),
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscribe'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pushReplacementNamed(
            AppRoutes.dashboard,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _error!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 16),
            ],
            const _PlanCard(
              title: 'Free Version',
              subtitle: null,
              isSelected: false,
              onTap: null,
            ),
            const SizedBox(height: 16),
            _PlanCard(
              title: 'Pro Version',
              subtitle: '99¢ AUD Monthly',
              isSelected: false,
              onTap: _loading ? null : _openProCheckout,
              isLoading: _loading,
            ),
            const SizedBox(height: 16),
            _PlanCard(
              title: 'Pro Max',
              subtitle: '\$1.00 AUD Monthly',
              isSelected: false,
              onTap: _loading ? null : _openProMaxCheckout,
              isLoading: _loading,
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.title,
    this.subtitle,
    required this.isSelected,
    this.onTap,
    this.isLoading = false,
  });

  final String title;
  final String? subtitle;
  final bool isSelected;
  final VoidCallback? onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context)
                      .colorScheme
                      .outline
                      .withValues(alpha: 0.5),
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
              if (onTap != null)
                isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : ElevatedButton(
                        onPressed: onTap,
                        child: const Text('Subscribe Monthly'),
                      ),
            ],
          ),
        ),
      ),
    );
  }
}
