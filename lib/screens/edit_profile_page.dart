import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/routes/app_routes.dart';
import '../core/services/profile_service.dart';

/// Edit profile form: display name, location.
class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key, this.fromSignUp = false});

  /// When true (e.g. after sign-up), save navigates to dashboard instead of pop.
  final bool fromSignUp;

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();

  bool _loading = false;
  bool _initialized = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final profile = await ProfileService.getCurrentProfile();
    if (!mounted) return;
    if (profile != null) {
      _nameController.text = profile.displayName ?? '';
      _locationController.text = profile.location ?? '';
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

    final name = _nameController.text.trim();
    final location = _locationController.text.trim();

    setState(() => _loading = true);
    try {
      await ProfileService.updateProfile(
        displayName: name.isEmpty ? null : name,
        location: location.isEmpty ? null : location,
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
    return Scaffold(
      appBar: AppBar(title: const Text('Edit profile')),
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
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        hintText: 'Your display name',
                        border: OutlineInputBorder(),
                      ),
                      textCapitalization: TextCapitalization.words,
                      validator: (v) {
                        final s = v?.trim() ?? '';
                        if (s.length > 100) {
                          return 'Name must be 100 characters or less';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _locationController,
                      decoration: const InputDecoration(
                        labelText: 'Location',
                        hintText: 'Where are you from?',
                        border: OutlineInputBorder(),
                      ),
                      textCapitalization: TextCapitalization.words,
                      validator: (v) {
                        final s = v?.trim() ?? '';
                        if (s.length > 100) {
                          return 'Location must be 100 characters or less';
                        }
                        return null;
                      },
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error),
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
                          : const Text('Save'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
