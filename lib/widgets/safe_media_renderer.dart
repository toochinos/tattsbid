import 'package:flutter/material.dart';

Widget buildMedia(String url) {
  return SafeMediaRenderer(url: url);
}

class SafeMediaRenderer extends StatelessWidget {
  const SafeMediaRenderer({super.key, required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final safeUrl = url.trim();
    if (safeUrl.isEmpty ||
        !safeUrl.startsWith('http') ||
        !safeUrl.contains('.')) {
      return Container(color: Colors.black);
    }
    final isVideo = safeUrl.toLowerCase().endsWith('.mp4');
    return isVideo
        ? Container(color: Colors.black)
        : Image.network(
            safeUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) {
              return Container(
                color: Colors.black,
                child: const Icon(Icons.broken_image, color: Colors.white),
              );
            },
          );
  }
}
