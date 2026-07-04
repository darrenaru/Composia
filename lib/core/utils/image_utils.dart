import 'dart:convert';
import 'dart:io';

class ImageUtils {
  ImageUtils._();

  static Future<String> fileToBase64(File file) async {
    final bytes = await file.readAsBytes();
    return base64Encode(bytes);
  }

  static String getMimeType(String path) {
    final ext = path.toLowerCase().split('.').last;
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      default:
        return 'image/jpeg';
    }
  }

  static Future<File?> compressIfNeeded(File file) async {
    final stat = await file.stat();
    // Return as-is if under 5MB; Claude API handles compression internally
    if (stat.size < 5 * 1024 * 1024) return file;
    return file;
  }
}
