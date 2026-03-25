import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_profile.dart';
import '../utils/user_type_utils.dart';
import 'profile_service.dart';
import 'user_agreement_service.dart';

class OnboardingService {
  OnboardingService._();

  static SupabaseClient get _client => Supabase.instance.client;

  static bool _isProfileComplete(UserProfile? profile) {
    if (profile == null) return false;
    final name = (profile.displayName ?? '').trim();
    final location = (profile.location ?? '').trim();
    final email = (profile.contactEmail ?? profile.email).trim();
    final mobile = (profile.mobile ?? '').trim();
    final type = canonicalUserType(profile.userType);

    return name.isNotEmpty &&
        location.isNotEmpty &&
        email.isNotEmpty &&
        email.contains('@') &&
        mobile.isNotEmpty &&
        (type == 'customer' || type == 'tattoo_artist');
  }

  static Future<bool> needsAgreement() async {
    final user = _client.auth.currentUser;
    if (user == null) return false;
    final accepted = await UserAgreementService.hasAcceptedTerms();
    return !accepted;
  }

  static Future<bool> needsProfileSetup() async {
    final user = _client.auth.currentUser;
    if (user == null) return false;
    final profile = await ProfileService.getCurrentProfile();
    return !_isProfileComplete(profile);
  }
}
