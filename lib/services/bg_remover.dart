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
  /// https://www.remove.bg/api — Free tier: 50 calls/month
  static const String removeBgApiKey = 'jcqUzyeyx4MgUAUdiQJB1uah';

  /// Removes the background from an image at [inputPath] and saves as a PNG
  /// with a transparent background. Returns the new PNG file path, or null on failure.
  /// Always tries remove.bg API first, falls back to local processing if API fails.
  static Future<String?> process(String inputPath) async {
    try {
      final bytes = await File(inputPath).readAsBytes();

      // Always try remove.bg API first
      final resultBytes = await _processWithRemoveBgAPI(bytes);
      if (resultBytes != null) {
        final dir = await getApplicationDocumentsDirectory();
        final fileName = 'item_${DateTime.now().millisecondsSinceEpoch}.png';
        final outPath = p.join(dir.path, fileName);
        await File(outPath).writeAsBytes(resultBytes);
        debugPrint('✅ Background removed via remove.bg API');
        return outPath;
      }

      // Fall back to local processing if API fails
      debugPrint('⚠️ API failed, falling back to local processing');
      final localResultBytes = await processBytes(bytes);
      if (localResultBytes == null) return null;

      final dir = await getApplicationDocumentsDirectory();
      final fileName = 'item_${DateTime.now().millisecondsSinceEpoch}.png';
      final outPath = p.join(dir.path, fileName);
      await File(outPath).writeAsBytes(localResultBytes);
      return outPath;
    } catch (e) {
      debugPrint('BgRemover.process error: $e');
      return null;
    }
  }

  /// Uses remove.bg API to remove background — more accurate than local processing
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
      request.fields['type_level'] = '2'; // more accurate segmentation
      request.fields['quality'] = 'preview'; // faster processing

      final response = await request.send().timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw TimeoutException('Remove.bg API request timed out'),
      );

      if (response.statusCode == 200) {
        final responseBytes = await response.stream.toBytes();
        return responseBytes;
      } else {
        final body = await response.stream.bytesToString();
        debugPrint('Remove.bg API error ${response.statusCode}: $body');
        return null;
      }
    } catch (e) {
      debugPrint('Remove.bg API exception: $e');
      return null;
    }
  }

  /// Processes raw image bytes via remove.bg API.
  /// Used for web platform where file paths are not available.
  /// Falls back to local processing if API fails.
  static Future<Uint8List?> processBytes(Uint8List bytes) async {
    // Try API first even for bytes
    final apiResult = await _processWithRemoveBgAPI(bytes);
    if (apiResult != null) {
      debugPrint('✅ Background removed via remove.bg API (bytes)');
      return apiResult;
    }

    // Fall back to local flood-fill method
    debugPrint('⚠️ API failed, using local fallback for bytes');
    return _localProcessBytes(bytes);
  }

  /// Local fallback: flood-fill based background removal.
  /// Less accurate than remove.bg but works offline.
  static Future<Uint8List?> _localProcessBytes(Uint8List bytes) async {
    try {
      img.Image? image = img.decodeImage(bytes);
      if (image == null) return null;

      // Ensure the image has an alpha channel
      if (image.numChannels < 4) {
        image = image.convert(numChannels: 4);
      }

      final w = image.width;
      final h = image.height;

      // Sample background color from corners, edge midpoints, and quarter points
      final bgSamples = <List<int>>[
        [0, 0],
        [w - 1, 0],
        [0, h - 1],
        [w - 1, h - 1],
        [w ~/ 2, 0],
        [w ~/ 2, h - 1],
        [0, h ~/ 2],
        [w - 1, h ~/ 2],
        [w ~/ 4, 0],
        [w * 3 ~/ 4, 0],
        [w ~/ 4, h - 1],
        [w * 3 ~/ 4, h - 1],
        [0, h ~/ 4],
        [0, h * 3 ~/ 4],
        [w - 1, h ~/ 4],
        [w - 1, h * 3 ~/ 4],
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

      // Flood fill from all edge midpoints and corners
      const tolerance = 60;
      _floodFill(image, 0, 0, avgR, avgG, avgB, tolerance);
      _floodFill(image, w - 1, 0, avgR, avgG, avgB, tolerance);
      _floodFill(image, 0, h - 1, avgR, avgG, avgB, tolerance);
      _floodFill(image, w - 1, h - 1, avgR, avgG, avgB, tolerance);
      _floodFill(image, w ~/ 2, 0, avgR, avgG, avgB, tolerance);
      _floodFill(image, w ~/ 2, h - 1, avgR, avgG, avgB, tolerance);
      _floodFill(image, 0, h ~/ 2, avgR, avgG, avgB, tolerance);
      _floodFill(image, w - 1, h ~/ 2, avgR, avgG, avgB, tolerance);

      return Uint8List.fromList(img.encodePng(image));
    } catch (e) {
      debugPrint('Local BgRemover error: $e');
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

        if (x > 0) stack.add(idx - 1);
        if (x < w - 1) stack.add(idx + 1);
        if (y > 0) stack.add(idx - w);
        if (y < h - 1) stack.add(idx + w);
      }
    }
  }
}