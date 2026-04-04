/// Safe parsing of PostgREST / JSON [List] responses into
/// [List<Map<String, dynamic>>] (avoids `List<dynamic>` subtype errors).
List<Map<String, dynamic>> mapListFrom(dynamic response) {
  if (response == null) return [];
  if (response is! List) return [];
  final out = <Map<String, dynamic>>[];
  for (final e in response) {
    if (e is Map<String, dynamic>) {
      out.add(e);
    } else if (e is Map) {
      out.add(Map<String, dynamic>.from(e));
    }
  }
  return out;
}
