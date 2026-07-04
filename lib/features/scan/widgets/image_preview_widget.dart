import 'dart:io';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class ImagePreviewWidget extends StatelessWidget {
  final File image;
  final VoidCallback? onRetake;

  const ImagePreviewWidget({
    super.key,
    required this.image,
    this.onRetake,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Image.file(
            image,
            width: double.infinity,
            height: 320,
            fit: BoxFit.cover,
          ),
        ),
        Positioned(
          top: 12,
          right: 12,
          child: GestureDetector(
            onTap: onRetake,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.refresh_rounded, color: Colors.white, size: 16),
                  SizedBox(width: 4),
                  Text(
                    'Ganti Foto',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
