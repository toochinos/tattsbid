import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Renders a branded share card:
/// tattoo image on top, artist / price / TattsBid footer below.
class TattooShareCardData {
  const TattooShareCardData({
    required this.imageUrl,
    required this.posterName,
    required this.price,
    this.isArtistPost = false,
  });

  final String imageUrl;
  final String posterName;
  final double price;

  /// Artist promo / bid card — original share footer. Customer job post otherwise.
  final bool isArtistPost;
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
    final bodySize = data.isArtistPost ? 42.0 : 38.0;
    final brandSize = data.isArtistPost ? 48.0 : 40.0;

    final posterLabel = data.posterName.trim().isNotEmpty
        ? data.posterName.trim()
        : (data.isArtistPost ? 'Tattoo artist' : 'A customer');
    final priceLabel = formatTattooSharePrice(data.price);

    const brandUrl = 'www.tattsbid.com';
    final lines = data.isArtistPost
        ? <_ShareCardLine>[
            _ShareCardLine('Artist: $posterLabel', bodySize, FontWeight.w600),
            _ShareCardLine('Price: $priceLabel', bodySize, FontWeight.w600),
            _ShareCardLine('Available on', bodySize, FontWeight.w500),
          ]
        : <_ShareCardLine>[
            _ShareCardLine(posterLabel, bodySize, FontWeight.w700),
            _ShareCardLine(
              'has a budget of $priceLabel for this tattoo.',
              bodySize,
              FontWeight.w600,
            ),
            _ShareCardLine(
              'Looking for a tattoo Artist to do the job.',
              bodySize,
              FontWeight.w600,
            ),
            _ShareCardLine('Available on', bodySize, FontWeight.w500),
          ];

    const logoHeight = 420.0;
    const logoPadding = 24.0;
    const logoVerticalAnchor = 0.68;
    final logo = await _loadShareLogoImage();
    final logoWidth = logo != null
        ? logoHeight * (logo.width / logo.height)
        : 0.0;

    final fullTextWidth = cardWidth - footerPadding * 2;
    final textMaxWidth = logo != null
        ? (fullTextWidth - logoWidth - logoPadding).clamp(280.0, fullTextWidth)
        : fullTextWidth;

    double lineBlockHeight = 0;
    for (final line in lines) {
      lineBlockHeight += _measureLineHeight(line, textMaxWidth) + lineGap;
    }
    if (lines.isNotEmpty) lineBlockHeight -= lineGap;

    final brandLineHeight = _measureBrandLineHeight(textMaxWidth, brandSize);
    var footerHeight = footerPadding * 2 + lineBlockHeight + brandLineHeight;

    if (logo != null) {
      final logoBottom =
          imageHeight - logoHeight * logoVerticalAnchor + logoHeight;
      final minFooterForLogo = logoBottom - imageHeight + footerPadding;
      if (minFooterForLogo > footerHeight) {
        footerHeight = minFooterForLogo;
      }
    }

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
      final lineHeight = _measureLineHeight(line, textMaxWidth);
      _paintShareLine(canvas, line, footerPadding, y, textMaxWidth);
      y += lineHeight + lineGap;
    }
    _paintBrandLine(
      canvas,
      footerPadding,
      y,
      textMaxWidth,
      brandSize,
      brandUrl,
    );

    if (logo != null) {
      try {
        paintImage(
          canvas: canvas,
          rect: Rect.fromLTWH(
            cardWidth - logoWidth - logoPadding,
            imageHeight - logoHeight * logoVerticalAnchor,
            logoWidth,
            logoHeight,
          ),
          image: logo,
          fit: BoxFit.contain,
        );
      } finally {
        logo.dispose();
      }
    }

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
}

TextPainter _linePainter(_ShareCardLine line, double maxWidth) {
  return TextPainter(
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
    maxLines: 4,
    ellipsis: '…',
  )..layout(maxWidth: maxWidth);
}

double _measureLineHeight(_ShareCardLine line, double maxWidth) {
  return _linePainter(line, maxWidth).height;
}

void _paintShareLine(
  Canvas canvas,
  _ShareCardLine line,
  double left,
  double top,
  double maxWidth,
) {
  _linePainter(line, maxWidth).paint(canvas, Offset(left, top));
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

Future<ui.Image?> _loadShareLogoImage() async {
  try {
    final data = await rootBundle.load('assets/tattsbid_share_logo.png');
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    return frame.image;
  } catch (_) {
    return null;
  }
}
