import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:http/http.dart' as http;

class BgRemover {
  /// API key for remove.bg service
  /// Get your free API key from: https://www.remove.bg/api
  /// Free tier: 50 API calls per month
  static const String removeBgApiKey = 'YOUR_REMOVE_BG_API_KEY'; // Replace with your API key

  /// Removes the background from an image at [inputPath] and saves as a PNG
  /// with a transparent background. Returns the new PNG file path, or null on failure.
  /// First tries remove.bg API, falls back to local processing if API fails
  static Future<String?> process(String inputPath) async {
    try {
      final bytes = await File(inputPath).readAsBytes();

      // Try using remove.bg API first if API key is provided
      if (removeBgApiKey != 'YOUR_REMOVE_BG_API_KEY') {
        final resultBytes = await _processWithRemoveBgAPI(bytes);
        if (resultBytes != null) {
          final dir = await getApplicationDocumentsDirectory();
          final fileName = 'item_${DateTime.now().millisecondsSinceEpoch}.png';
          final outPath = p.join(dir.path, fileName);
          await File(outPath).writeAsBytes(resultBytes);
          return outPath;
        }
      }

      // Fall back to local processing
      final resultBytes = await processBytes(bytes);
      if (resultBytes == null) return null;

      final dir = await getApplicationDocumentsDirectory();
      final fileName = 'item_${DateTime.now().millisecondsSinceEpoch}.png';
      final outPath = p.join(dir.path, fileName);
      await File(outPath).writeAsBytes(resultBytes);
      return outPath;
    } catch (_) {
      return null;
    }
  }

  /// Uses remove.bg API to remove background - more accurate than local processing
  static Future<Uint8List?> _processWithRemoveBgAPI(Uint8List imageBytes) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('https://api.remove.bg/v1.0/removebg'),
      );

      request.headers['X-API-Key'] = removeBgApiKey;
      request.files.add(http.MultipartFile.fromBytes(
        'image_file',
        imageBytes,
        filename: 'image.png',
      ));
      request.fields['format'] = 'PNG';
      request.fields['type'] = 'auto';
      request.fields['type_level'] = '2'; // more accurate
      request.fields['quality'] = 'preview'; // faster processing

      final response = await request.send().timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw TimeoutException('API request timeout'),
      );

      if (response.statusCode == 200) {
        final responseBytes = await response.stream.toBytes();
        return responseBytes;
      } else {
        debugPrint('Remove.bg API error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('Remove.bg API error: $e');
      return null;
    }
  }

  /// Removes the background from raw image bytes and returns PNG bytes.
  /// Returns null on failure.
  /// This is a fallback local method - not as accurate as remove.bg
  static Future<Uint8List?> processBytes(Uint8List bytes) async {
    try {
      img.Image? image = img.decodeImage(bytes);
      if (image == null) return null;

      // Ensure the image has an alpha channel
      if (image.numChannels < 4) {
        image = image.convert(numChannels: 4);
      }

      final w = image.width;
      final h = image.height;

      // Sample background color from corners and edge midpoints
      final bgSamples = <List<int>>[
        [0, 0],
        [w - 1, 0],
        [0, h - 1],
        [w - 1, h - 1],
        [w ~/ 2, 0],
        [w ~/ 2, h - 1],
        [0, h ~/ 2],
        [w - 1, h ~/ 2],
      ];

      int sumR = 0, sumG = 0, sumB = 0;
      for (final coord in bgSamples) {
        final px = image.getPixel(coord[0], coord[1]);
        sumR += px.r.toInt();
        sumG += px.g.toInt();
        sumB += px.b.toInt();
      }
      final avgR = sumR ~/ bgSamples.length;
      final avgG = sumG ~/ bgSamples.length;
      final avgB = sumB ~/ bgSamples.length;

      // Flood fill transparent from all four corners
      const tolerance = 35;
      _floodFill(image, 0, 0, avgR, avgG, avgB, tolerance);
      _floodFill(image, w - 1, 0, avgR, avgG, avgB, tolerance);
      _floodFill(image, 0, h - 1, avgR, avgG, avgB, tolerance);
      _floodFill(image, w - 1, h - 1, avgR, avgG, avgB, tolerance);

      return Uint8List.fromList(img.encodePng(image));
    } catch (_) {
      return null;
    }
  }

  static void _floodFill(
    img.Image image,
    int startX,
    int startY,
    int bgR,
    int bgG,
    int bgB,
    int tolerance,
  ) {
    final w = image.width;
    final h = image.height;
    // Use a flat Uint8List as visited map for performance
    final visited = Uint8List(w * h);
    final stack = <int>[startY * w + startX];

    while (stack.isNotEmpty) {
      final idx = stack.removeLast();
      if (visited[idx] == 1) continue;
      visited[idx] = 1;

      final x = idx % w;
      final y = idx ~/ w;

      final px = image.getPixel(x, y);
      final r = px.r.toInt();
      final g = px.g.toInt();
      final b = px.b.toInt();

      if ((r - bgR).abs() <= tolerance &&
          (g - bgG).abs() <= tolerance &&
          (b - bgB).abs() <= tolerance) {
        image.setPixelRgba(x, y, 0, 0, 0, 0); // Fully transparent

        // Add neighbors
        if (x > 0) stack.add(idx - 1);
        if (x < w - 1) stack.add(idx + 1);
        if (y > 0) stack.add(idx - w);
        if (y < h - 1) stack.add(idx + w);
      }
    }
  }
}