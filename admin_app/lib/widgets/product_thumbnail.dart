import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/product.dart';
import '../services/github_service.dart';
import '../theme/app_colors.dart';

class ProductThumbnail extends StatelessWidget {
  final Product product;
  final GitHubService? githubService;
  final double size;
  final double borderRadius;
  final VoidCallback? onTap;

  const ProductThumbnail({
    super.key,
    required this.product,
    this.githubService,
    this.size = 44,
    this.borderRadius = 8,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Widget content;

    // 1. Henüz push edilmemiş yerel olarak seçilmiş yeni görsel
    if (product.pendingImageBytes != null) {
      content = Image.memory(
        product.pendingImageBytes!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _buildFallback(),
      );
    }
    // 2. HTTP/HTTPS Web URL
    else if (product.image.startsWith('http://') ||
        product.image.startsWith('https://')) {
      content = Image.network(
        product.image,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _buildFallback(),
      );
    }
    // 3. GitHub veya Yerel Dosya Yolu
    else if (product.image.isNotEmpty && githubService != null) {
      content = FutureBuilder<Uint8List?>(
        future: githubService!.fetchImageBytes(product.image),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Container(
              width: size,
              height: size,
              color: AppColors.stone100,
              child: Center(
                child: SizedBox(
                  width: size * 0.35,
                  height: size * 0.35,
                  child: const CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: AppColors.emerald600,
                  ),
                ),
              ),
            );
          }
          if (snapshot.hasData &&
              snapshot.data != null &&
              snapshot.data!.isNotEmpty) {
            final bytes = snapshot.data!;
            if (isSvgBytes(bytes)) {
              return _buildFallback();
            }
            return Image.memory(
              bytes,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _buildFallback(),
            );
          }
          return _buildFallback();
        },
      );
    } else {
      content = _buildFallback();
    }

    final card = Container(
      width: size,
      height: size,
      constraints: BoxConstraints.tightFor(width: size, height: size),
      decoration: BoxDecoration(
        color: AppColors.stone100,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: product.hasPendingImage
              ? AppColors.emerald500
              : AppColors.stone200,
          width: product.hasPendingImage ? 1.5 : 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius - 1),
        child: Stack(
          fit: StackFit.expand,
          children: [
            content,
            if (product.hasPendingImage)
              Positioned(
                top: 2,
                right: 2,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.emerald600,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(borderRadius),
        child: card,
      );
    }

    return card;
  }

  static bool isSvgBytes(Uint8List bytes) {
    if (bytes.length < 5) return false;
    final snippet = String.fromCharCodes(bytes.take(120)).trim().toLowerCase();
    return snippet.startsWith('<?xml') ||
        snippet.startsWith('<svg') ||
        snippet.contains('<svg');
  }

  Widget _buildFallback() {
    IconData icon;
    final cat = product.category.toLowerCase();
    if (cat.contains('meyve')) {
      icon = Icons.apple;
    } else if (cat.contains('sebze')) {
      icon = Icons.spa;
    } else if (cat.contains('yeşillik')) {
      icon = Icons.eco;
    } else if (cat.contains('narenciye')) {
      icon = Icons.wb_sunny;
    } else {
      icon = Icons.shopping_basket_outlined;
    }

    return Container(
      width: size,
      height: size,
      color: AppColors.stone100,
      child: Center(
        child: Icon(icon, size: size * 0.45, color: AppColors.stone400),
      ),
    );
  }
}
