import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase project URL (Dashboard → Settings → API).
const String kSupabaseUrl = 'https://ikkfdwjmqujgkokpqhez.supabase.co';

/// Supabase anon key (JWT). Keep in sync with Dashboard → Settings → API.
const String kSupabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imlra2Zkd2ptcXVqZ2tva3BxaGV6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzIzNDczMTEsImV4cCI6MjA4NzkyMzMxMX0.R55-7QT3xUC5lhhtOYwz5g1u23gpusJsSNjbvbXIzDY';

/// Idempotent: no-op if already initialized (e.g. tests call [Supabase.initialize] first).
Future<void> ensureSupabaseInitialized() async {
  try {
    Supabase.instance.client.auth;
    return;
  } catch (_) {
    // Not initialized yet.
  }
  try {
    await Supabase.initialize(
      url: kSupabaseUrl,
      anonKey: kSupabaseAnonKey,
    );
  } on AssertionError {
    // Already initialized in another zone / race.
  }
}

/// True when [Supabase.instance] is safe to use.
bool isSupabaseReady() {
  try {
    Supabase.instance.client.auth;
    return true;
  } catch (_) {
    return false;
  }
}

/// [Supabase.instance] throws if not initialized — use this from UI before init finishes.
Session? readSupabaseSessionIfReady() {
  if (!isSupabaseReady()) return null;
  try {
    return Supabase.instance.client.auth.currentSession;
  } catch (_) {
    return null;
  }
}
