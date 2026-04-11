/// Step 2 & 3 — same formula as:
/// `(map['rating'] as num?)?.toDouble() ?? 0.0`
/// Prefer this over casting map/JSON values directly to [double].
double doubleFromJsonNum(dynamic value) => (value as num?)?.toDouble() ?? 0.0;

/// Optional numeric field: null if absent or not a [num].
double? doubleFromJsonNumNullable(dynamic value) {
  if (value == null) return null;
  if (value is! num) return null;
  return value.toDouble();
}

/// Parses JSON / Supabase values that may be [num], [String], [bool], or null.
double safeDouble(dynamic value) {
  if (value == null) return 0.0;

  if (value is bool) return value ? 1.0 : 0.0;
  if (value is int) return value.toDouble();
  if (value is double) return value;

  return double.tryParse(value.toString()) ?? 0.0;
}
