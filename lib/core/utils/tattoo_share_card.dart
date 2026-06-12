import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Renders a branded share card:
/// tattoo image on top, artist / price / TattsBid footer below.
class TattooShareCardData {
  const TattooShareCardData({
    required this.imageUrl,
    required this.artist,
    required this.price,
  });

  final String imageUrl;
  final String artist;
  final double price;
}

String formatTattooSharePrice(double price) {
  return price == price.roundToDouble()
      ? '\$${price.toStringAsFixed(0)}'
      : '\$${price.toStringAsFixed(2)}';
}

Future<XFile?> buildTattooShareCardFile(
  TattooShareCardData data, {
  String basename = 'tattoo_share',
}) async {
  final bytes = await _renderShareCardPng(data);
  if (bytes == null) return null;

  final tempDir = await getTemporaryDirectory();
  final file = File('${tempDir.path}/$basename.png');
  await file.writeAsBytes(bytes);
  return XFile(file.path, mimeType: 'image/png', name: '$basename.png');
}

Future<Uint8List?> _renderShareCardPng(TattooShareCardData data) async {
  final imageUrl = data.imageUrl.trim();
  if (imageUrl.isEmpty || !imageUrl.startsWith('http')) return null;

  ui.Image? tattooImage;
  try {
    final response = await http
        .get(Uri.parse(imageUrl))
        .timeout(const Duration(seconds: 20));
    if (response.statusCode < 200 || response.statusCode >= 300) return null;

    final codec = await ui.instantiateImageCodec(response.bodyBytes);
    final frame = await codec.getNextFrame();
    tattooImage = frame.image;

    const cardWidth = 1080.0;
    const imageHeight = cardWidth;
    const footerPadding = 48.0;
    const lineGap = 12.0;
    const bodySize = 42.0;
    const brandSize = 48.0;

    final artistLabel =
        data.artist.trim().isNotEmpty ? data.artist.trim() : 'Tattoo artist';
    final priceLabel = formatTattooSharePrice(data.price);

    const brandUrl = 'www.tattsbid.com';
    final lines = <_ShareCardLine>[
      _ShareCardLine('Artist: $artistLabel', bodySize, FontWeight.w600),
      _ShareCardLine('Price: $priceLabel', bodySize, FontWeight.w600),
      _ShareCardLine('Available on', bodySize, FontWeight.w500),
    ];

    final textMaxWidth = cardWidth - footerPadding * 2;
    final brandLineHeight = _measureBrandLineHeight(textMaxWidth, brandSize);

    double footerHeight = footerPadding * 2;
    for (final line in lines) {
      footerHeight += line.height + lineGap;
    }
    footerHeight += brandLineHeight;

    final cardHeight = imageHeight + footerHeight;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, cardWidth, cardHeight),
    );

    final borderPaint = Paint()..color = const Color(0xFFE0E0E0);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, cardWidth, cardHeight),
      Paint()..color = Colors.white,
    );

    paintImage(
      canvas: canvas,
      rect: const Rect.fromLTWH(0, 0, cardWidth, imageHeight),
      image: tattooImage,
      fit: BoxFit.cover,
    );

    canvas.drawLine(
      const Offset(0, imageHeight),
      Offset(cardWidth, imageHeight),
      borderPaint..strokeWidth = 2,
    );

    var y = imageHeight + footerPadding;
    for (final line in lines) {
      _paintShareLine(canvas, line, footerPadding, y, textMaxWidth);
      y += line.height + lineGap;
    }
    _paintBrandLine(
        canvas, footerPadding, y, textMaxWidth, brandSize, brandUrl);

    canvas.drawRect(
      Rect.fromLTWH(0, 0, cardWidth, cardHeight),
      Paint()
        ..color = const Color(0xFFE0E0E0)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );

    final picture = recorder.endRecording();
    final cardImage = await picture.toImage(
      cardWidth.toInt(),
      cardHeight.toInt(),
    );
    final byteData = await cardImage.toByteData(format: ui.ImageByteFormat.png);
    cardImage.dispose();
    return byteData?.buffer.asUint8List();
  } finally {
    tattooImage?.dispose();
  }
}

class _ShareCardLine {
  const _ShareCardLine(this.text, this.fontSize, this.weight);

  final String text;
  final double fontSize;
  final FontWeight weight;

  double get height => fontSize * 1.25;
}

void _paintShareLine(
  Canvas canvas,
  _ShareCardLine line,
  double left,
  double top,
  double maxWidth,
) {
  final painter = TextPainter(
    text: TextSpan(
      text: line.text,
      style: TextStyle(
        color: Colors.black87,
        fontSize: line.fontSize,
        fontWeight: line.weight,
        height: 1.25,
      ),
    ),
    textDirection: TextDirection.ltr,
    maxLines: 2,
    ellipsis: '…',
  )..layout(maxWidth: maxWidth);

  painter.paint(canvas, Offset(left, top));
}

TextPainter _brandLinePainter(double maxWidth, double fontSize, String url) {
  return TextPainter(
    text: TextSpan(
      children: [
        TextSpan(
          text: 'TattsBid 🔥  ',
          style: TextStyle(
            color: Colors.black87,
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            height: 1.25,
          ),
        ),
        TextSpan(
          text: url,
          style: TextStyle(
            color: const Color(0xFF1565C0),
            fontSize: fontSize * 0.92,
            fontWeight: FontWeight.w600,
            decoration: TextDecoration.underline,
            height: 1.25,
          ),
        ),
      ],
    ),
    textDirection: TextDirection.ltr,
    maxLines: 2,
  )..layout(maxWidth: maxWidth);
}

double _measureBrandLineHeight(double maxWidth, double fontSize) {
  const brandUrl = 'www.tattsbid.com';
  final painter = _brandLinePainter(maxWidth, fontSize, brandUrl);
  return painter.height;
}

void _paintBrandLine(
  Canvas canvas,
  double left,
  double top,
  double maxWidth,
  double fontSize,
  String url,
) {
  final painter = _brandLinePainter(maxWidth, fontSize, url);
  painter.paint(canvas, Offset(left, top));
}
