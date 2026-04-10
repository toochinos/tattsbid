/// One item in the Tattsagram feed (mock, user upload from live chat, or future API).
class TattsagramPost {
  const TattsagramPost({
    required this.imageUrl,
    required this.artistName,
    required this.location,
    required this.caption,
    required this.timestamp,
  });

  final String imageUrl;
  final String artistName;
  final String location;
  final String caption;
  final DateTime timestamp;
}
