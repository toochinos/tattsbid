import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/routes/app_routes.dart';
import '../core/services/profile_service.dart';
import '../l10n/app_localizations.dart';

/// Contact details: email and mobile (no separate “profile” name/location here).
class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key, this.fromSignUp = false});

  /// When true (e.g. after sign-up), save navigates to dashboard instead of pop.
  final bool fromSignUp;

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _mobileController = TextEditingController();

  bool _loading = false;
  bool _initialized = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _mobileController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final profile = await ProfileService.getCurrentProfile();
    if (!mounted) return;
    if (profile != null) {
      _emailController.text = (profile.contactEmail?.trim().isNotEmpty == true)
          ? profile.contactEmail!.trim()
          : profile.email;
      _mobileController.text = profile.mobile?.trim() ?? '';
    }
    setState(() => _initialized = true);
  }

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _submit() async {
    _errorMessage = null;
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    final mobile = _mobileController.text.trim();

    setState(() => _loading = true);
    try {
      await ProfileService.updateProfile(
        contactEmail: email.isEmpty ? null : email,
        mobile: mobile.isEmpty ? null : mobile,
      );
      if (!mounted) return;
      if (widget.fromSignUp) {
        Navigator.of(context).pushReplacementNamed(AppRoutes.dashboard);
      } else {
        Navigator.of(context).pop();
      }
    } on PostgrestException catch (e) {
      setState(() {
        _loading = false;
        _errorMessage = e.message;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.profileContactDetailsTitle)),
      body: !_initialized
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        labelText: l10n.authEmailLabel,
                        hintText: l10n.editContactEmailHint,
                        border: const OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      validator: (v) {
                        final s = v?.trim() ?? '';
                        if (s.isEmpty) {
                          return l10n.profileEnterEmail;
                        }
                        if (!s.contains('@') || s.length > 254) {
                          return l10n.profileEnterValidEmail;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _mobileController,
                      decoration: InputDecoration(
                        labelText: l10n.profileMobileLabel,
                        hintText: l10n.editContactPhoneHint,
                        border: const OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.phone,
                      validator: (v) {
                        final s = v?.trim() ?? '';
                        if (s.length > 40) {
                          return l10n.profileMobileMaxLength;
                        }
                        return null;
                      },
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _loading ? null : _submit,
                      child: _loading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(l10n.profileSave),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
