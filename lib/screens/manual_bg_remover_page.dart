import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// A screen that lets the user tap a colour in the image to flood-fill remove it.
/// Returns a [File] with the processed PNG (transparent background) via [Navigator.pop].
class ManualBgRemoverPage extends StatefulWidget {
  /// The raw, unprocessed image file to edit.
  final File imageFile;

  const ManualBgRemoverPage({super.key, required this.imageFile});

  @override
  State<ManualBgRemoverPage> createState() => _ManualBgRemoverPageState();
}

class _ManualBgRemoverPageState extends State<ManualBgRemoverPage> {
  // ── State ──────────────────────────────────────────────────────────────────
  img.Image? _image;           // working decoded image
  Uint8List? _previewBytes;    // PNG bytes rendered on screen
  bool _isLoading = true;
  bool _isProcessing = false;
  double _tolerance = 40;      // flood-fill colour tolerance (0-100)

  // Undo stack: each entry is the PNG bytes before a fill operation
  final List<Uint8List> _undoStack = [];

  // Size of the on-screen image widget (set by LayoutBuilder)
  Size _widgetSize = Size.zero;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  // ── Image loading ──────────────────────────────────────────────────────────
  Future<void> _loadImage() async {
    final bytes = await widget.imageFile.readAsBytes();
    final decoded = await _decodeInIsolate(bytes);
    if (!mounted) return;
    setState(() {
      _image = decoded;
      _previewBytes = bytes;
      _isLoading = false;
    });
  }

  /// Decode on the current isolate (image pkg is fast enough for preview sizes).
  Future<img.Image> _decodeInIsolate(Uint8List bytes) async {
    img.Image? decoded = img.decodeImage(bytes);
    if (decoded == null) throw Exception('Could not decode image');
    // Ensure alpha channel
    if (decoded.numChannels < 4) {
      decoded = decoded.convert(numChannels: 4);
    }
    return decoded;
  }

  // ── Tap handler ────────────────────────────────────────────────────────────
  Future<void> _onImageTap(TapDownDetails details) async {
    if (_image == null || _isProcessing || _widgetSize == Size.zero) return;

    final localPos = details.localPosition;
    final imgW = _image!.width.toDouble();
    final imgH = _image!.height.toDouble();

    // Map widget coordinates → image pixel coordinates (letterboxed / contain fit)
    final scaleX = imgW / _widgetSize.width;
    final scaleY = imgH / _widgetSize.height;
    final scale = scaleX > scaleY ? scaleX : scaleY;

    final displayW = imgW / scale;
    final displayH = imgH / scale;
    final offsetX = (_widgetSize.width - displayW) / 2;
    final offsetY = (_widgetSize.height - displayH) / 2;

    final imgX = ((localPos.dx - offsetX) * scale).round();
    final imgY = ((localPos.dy - offsetY) * scale).round();

    if (imgX < 0 || imgY < 0 || imgX >= _image!.width || imgY >= _image!.height) {
      return; // tapped outside the actual image area
    }

    setState(() => _isProcessing = true);

    // Save undo snapshot
    final snapshot = Uint8List.fromList(img.encodePng(_image!));
    _undoStack.add(snapshot);

    // Sample colour at tapped pixel
    final px = _image!.getPixel(imgX, imgY);
    final r = px.r.toInt();
    final g = px.g.toInt();
    final b = px.b.toInt();

    // Already transparent — nothing to do
    if (px.a.toInt() == 0) {
      _undoStack.removeLast();
      setState(() => _isProcessing = false);
      _showInfo('That area is already transparent.');
      return;
    }

    // Run flood-fill
    _floodFill(_image!, imgX, imgY, r, g, b, _tolerance.round());

    final newBytes = Uint8List.fromList(img.encodePng(_image!));
    if (!mounted) return;
    setState(() {
      _previewBytes = newBytes;
      _isProcessing = false;
    });
  }

  // ── Flood fill ─────────────────────────────────────────────────────────────
  void _floodFill(
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
      if (px.a.toInt() == 0) continue; // already transparent

      final r = px.r.toInt();
      final g = px.g.toInt();
      final b = px.b.toInt();

      if ((r - bgR).abs() <= tolerance &&
          (g - bgG).abs() <= tolerance &&
          (b - bgB).abs() <= tolerance) {
        image.setPixelRgba(x, y, 0, 0, 0, 0);
        if (x > 0) stack.add(idx - 1);
        if (x < w - 1) stack.add(idx + 1);
        if (y > 0) stack.add(idx - w);
        if (y < h - 1) stack.add(idx + w);
      }
    }
  }

  // ── Undo ───────────────────────────────────────────────────────────────────
  Future<void> _undo() async {
    if (_undoStack.isEmpty) return;
    setState(() => _isProcessing = true);
    final previous = _undoStack.removeLast();
    final decoded = await _decodeInIsolate(previous);
    if (!mounted) return;
    setState(() {
      _image = decoded;
      _previewBytes = previous;
      _isProcessing = false;
    });
  }

  // ── Reset ──────────────────────────────────────────────────────────────────
  Future<void> _reset() async {
    setState(() => _isProcessing = true);
    _undoStack.clear();
    final bytes = await widget.imageFile.readAsBytes();
    final decoded = await _decodeInIsolate(bytes);
    if (!mounted) return;
    setState(() {
      _image = decoded;
      _previewBytes = bytes;
      _isProcessing = false;
    });
  }

  // ── Done — save & return ───────────────────────────────────────────────────
  Future<void> _done() async {
    if (_image == null) return;
    setState(() => _isProcessing = true);
    final dir = await getApplicationDocumentsDirectory();
    final fileName = 'manual_bg_${DateTime.now().millisecondsSinceEpoch}.png';
    final outPath = p.join(dir.path, fileName);
    final pngBytes = Uint8List.fromList(img.encodePng(_image!));
    await File(outPath).writeAsBytes(pngBytes);
    if (!mounted) return;
    Navigator.pop(context, File(outPath));
  }

  void _showInfo(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        backgroundColor: const Color(0xff1c1c1c),
        foregroundColor: Colors.white,
        title: const Text(
          'Manual Background Remover',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        actions: [
          // Undo
          IconButton(
            icon: const Icon(Icons.undo),
            tooltip: 'Undo',
            onPressed: _undoStack.isEmpty || _isProcessing ? null : _undo,
          ),
          // Reset
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reset',
            onPressed: _isProcessing ? null : _reset,
          ),
          // Done
          TextButton(
            onPressed: _isProcessing || _image == null ? null : _done,
            child: const Text(
              'Done',
              style: TextStyle(
                color: Colors.deepOrange,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.deepOrange),
            )
          : Column(
              children: [
                // ── Instruction banner ──────────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.deepOrange.withValues(alpha: 0.15),
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.deepOrange.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.touch_app,
                        color: Colors.deepOrange,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Tap on a colour in the image to remove it. '
                          'Tap multiple times to remove more areas.',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Image canvas ────────────────────────────────────────────
                Expanded(
                  child: Stack(
                    children: [
                      // Checkerboard background (shows transparency)
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _CheckerboardPainter(),
                        ),
                      ),

                      // Image with tap detection
                      Positioned.fill(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            _widgetSize = Size(
                              constraints.maxWidth,
                              constraints.maxHeight,
                            );
                            return GestureDetector(
                              onTapDown: _onImageTap,
                              child: _previewBytes != null
                                  ? Image.memory(
                                      _previewBytes!,
                                      fit: BoxFit.contain,
                                      gaplessPlayback: true,
                                    )
                                  : const SizedBox(),
                            );
                          },
                        ),
                      ),

                      // Processing overlay
                      if (_isProcessing)
                        Positioned.fill(
                          child: Container(
                            color: Colors.black.withValues(alpha: 0.45),
                            child: const Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircularProgressIndicator(
                                    color: Colors.deepOrange,
                                  ),
                                  SizedBox(height: 12),
                                  Text(
                                    'Removing colour…',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // ── Tolerance slider ────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  color: const Color(0xff1c1c1c),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Colour Tolerance',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.deepOrange,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _tolerance.round().toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Text(
                            'Precise',
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 11,
                            ),
                          ),
                          Expanded(
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                activeTrackColor: Colors.deepOrange,
                                inactiveTrackColor:
                                    Colors.white.withValues(alpha: 0.15),
                                thumbColor: Colors.deepOrange,
                                overlayColor:
                                    Colors.deepOrange.withValues(alpha: 0.2),
                                trackHeight: 4,
                              ),
                              child: Slider(
                                value: _tolerance,
                                min: 5,
                                max: 100,
                                onChanged: _isProcessing
                                    ? null
                                    : (v) => setState(() => _tolerance = v),
                              ),
                            ),
                          ),
                          const Text(
                            'Wide',
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Higher tolerance removes more similar shades at once.',
                        style: TextStyle(color: Colors.white38, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

/// Checkerboard painter to visualise transparent areas.
class _CheckerboardPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const tileSize = 12.0;
    final paintLight = Paint()..color = const Color(0xFF3A3A3A);
    final paintDark = Paint()..color = const Color(0xFF2A2A2A);

    for (double y = 0; y < size.height; y += tileSize) {
      for (double x = 0; x < size.width; x += tileSize) {
        final isEven =
            ((x / tileSize).floor() + (y / tileSize).floor()) % 2 == 0;
        canvas.drawRect(
          Rect.fromLTWH(x, y, tileSize, tileSize),
          isEven ? paintLight : paintDark,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}