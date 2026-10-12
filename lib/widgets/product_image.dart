import 'dart:convert';

import 'package:flutter/material.dart';

class ProductImage extends StatelessWidget {
  final String source;
  final double? width;
  final double? height;
  final BorderRadius borderRadius;
  const ProductImage({
    super.key,
    required this.source,
    this.width,
    this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(14)),
  });

  @override
  Widget build(BuildContext context) {
    Widget placeholder() => Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF5E7EC), Color(0xFFE8D7DE)],
        ),
      ),
      child: const Center(
        child: Icon(Icons.spa_outlined, size: 56, color: Color(0xFF805266)),
      ),
    );

    if (source.trim().isEmpty) return placeholder();
    Widget image;
    if (source.startsWith('data:image/')) {
      try {
        image = Image.memory(
          base64Decode(source.substring(source.indexOf(',') + 1)),
          width: width,
          height: height,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => placeholder(),
        );
      } catch (_) {
        return placeholder();
      }
    } else {
      image = Image.network(
        source,
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => placeholder(),
      );
    }
    return ClipRRect(borderRadius: borderRadius, child: image);
  }
}
