import 'package:flutter/material.dart';

import '../core/routes/app_routes.dart';
import '../core/services/user_agreement_service.dart';

class UserAgreementPage extends StatefulWidget {
  const UserAgreementPage({super.key});

  @override
  State<UserAgreementPage> createState() => _UserAgreementPageState();
}

class _UserAgreementPageState extends State<UserAgreementPage> {
  bool _agreed = false;
  bool _saving = false;
  String? _error;
  String _nextRoute = AppRoutes.profile;
  Object? _nextArgs = const {
    'fromSignUp': true,
    'allowAccountTypeChoice': true,
  };
  bool _didReadArgs = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didReadArgs) return;
    _didReadArgs = true;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      final route = args['nextRoute'];
      if (route is String && route.trim().isNotEmpty) {
        _nextRoute = route;
      }
      _nextArgs = args['nextArgs'];
    }
  }

  Future<void> _continue() async {
    if (!_agreed || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await UserAgreementService.acceptTerms();
      if (!mounted) return;
      Navigator.of(
        context,
      ).pushReplacementNamed(_nextRoute, arguments: _nextArgs);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not save agreement: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('TattsBid User Agreement'),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: scheme.outline.withValues(alpha: 0.35),
                ),
              ),
              child: const SingleChildScrollView(
                child: SelectableText(_agreementText),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                border: Border(
                  top: BorderSide(
                    color: scheme.outline.withValues(alpha: 0.2),
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CheckboxListTile(
                    value: _agreed,
                    contentPadding: EdgeInsets.zero,
                    onChanged: _saving
                        ? null
                        : (v) => setState(() => _agreed = v ?? false),
                    title: const Text('I agree to the TattsBid terms'),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      style: TextStyle(color: scheme.error),
                    ),
                  ],
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: (_agreed && !_saving) ? _continue : null,
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Continue'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

const String _agreementText = '''
TATTSBID USER AGREEMENT

Effective Date: March 26, 2026

Welcome to TattsBid. By using TattsBid, you agree to the terms in this User Agreement. If you do not agree, do not use the app.

1. Platform Role
TattsBid is a marketplace that connects customers with tattoo artists. TattsBid does not provide tattoo services and is not a party to agreements between users.

2. Eligibility and Accounts
You must provide accurate information, keep your account secure, and use the app only for lawful purposes. You are responsible for activity under your account.

3. Bids, Payments, and Deposits
Artists may submit bids to customer requests. Customers may select a winning bid and pay required platform or deposit fees. Payment processing may be handled by third-party providers.

4. User Responsibilities
You agree not to:
- post unlawful, abusive, or infringing content;
- impersonate others or submit misleading information;
- misuse messaging, payment, or profile features.

5. Artist and Customer Conduct
All users must communicate respectfully and comply with applicable local laws, health standards, and licensing requirements. Customers are responsible for evaluating artists before booking.

6. No Medical Advice
Information in TattsBid is not medical advice. Users should seek professional medical guidance where appropriate.

7. Privacy
Your use of TattsBid is also subject to the Privacy Policy. Contact details may be shown only after payment-related unlock conditions are met.

8. Limitation of Liability
To the maximum extent permitted by law, TattsBid is provided "as is" without warranties, and TattsBid is not liable for indirect, incidental, or consequential damages.

9. Suspension and Termination
TattsBid may suspend or terminate accounts that violate this agreement or applicable law.

10. Changes to Terms
We may update these terms. Continued use after changes become effective means you accept the updated terms.

11. Contact
For support or legal questions, contact TattsBid support through the channels provided in-app.

By tapping Continue, you confirm that you have read and agree to this User Agreement.
''';
