import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

enum _EditMode { fill, eraser }

class ManualBgRemoverPage extends StatefulWidget {
  final File imageFile;
  const ManualBgRemoverPage({super.key, required this.imageFile});

  @override
  State<ManualBgRemoverPage> createState() => _ManualBgRemoverPageState();
}

class _ManualBgRemoverPageState extends State<ManualBgRemoverPage> {
  img.Image? _image;
  Uint8List? _previewBytes;
  bool _isLoading = true;
  bool _isProcessing = false;

  double _tolerance = 20;   // lower default = more precise fill
  double _eraserSize = 20;

  _EditMode _mode = _EditMode.fill;

  final List<Uint8List> _undoStack = [];
  Size _widgetSize = Size.zero;
  DateTime? _lastSnackbarTime; // prevents spamming snackbar

  // ── Eraser stroke throttle ─────────────────────────────────────────────────
  // We buffer erased pixels during a stroke and only re-encode at stroke end
  // so the gesture feels instant with no double-tap required.
  bool _strokeActive = false;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  // ── Image loading ──────────────────────────────────────────────────────────
  Future<void> _loadImage() async {
    final bytes = await widget.imageFile.readAsBytes();
    final decoded = await _decode(bytes);
    if (!mounted) return;
    setState(() {
      _image = decoded;
      _previewBytes = bytes;
      _isLoading = false;
    });
  }

  Future<img.Image> _decode(Uint8List bytes) async {
    img.Image? decoded = img.decodeImage(bytes);
    if (decoded == null) throw Exception('Could not decode image');
    if (decoded.numChannels < 4) decoded = decoded.convert(numChannels: 4);
    return decoded;
  }

  // ── Coordinate mapping ─────────────────────────────────────────────────────
  Offset? _toImageCoords(Offset local) {
    if (_image == null || _widgetSize == Size.zero) return null;
    final imgW = _image!.width.toDouble();
    final imgH = _image!.height.toDouble();
    final scaleX = imgW / _widgetSize.width;
    final scaleY = imgH / _widgetSize.height;
    final scale = scaleX > scaleY ? scaleX : scaleY;
    final displayW = imgW / scale;
    final displayH = imgH / scale;
    final offsetX = (_widgetSize.width - displayW) / 2;
    final offsetY = (_widgetSize.height - displayH) / 2;
    final imgX = (local.dx - offsetX) * scale;
    final imgY = (local.dy - offsetY) * scale;
    if (imgX < 0 || imgY < 0 || imgX >= imgW || imgY >= imgH) return null;
    return Offset(imgX, imgY);
  }

  // ── Fill mode ──────────────────────────────────────────────────────────────
  Future<void> _onImageTap(TapDownDetails details) async {
    if (_mode != _EditMode.fill || _image == null || _isProcessing) return;
    final coords = _toImageCoords(details.localPosition);
    if (coords == null) return;

    final imgX = coords.dx.round();
    final imgY = coords.dy.round();

    setState(() => _isProcessing = true);

    final snapshot = Uint8List.fromList(img.encodePng(_image!));
    _undoStack.add(snapshot);

    final px = _image!.getPixel(imgX, imgY);
    if (px.a.toInt() == 0) {
      _undoStack.removeLast();
      setState(() => _isProcessing = false);
      _showInfo('That area is already transparent.');
      return;
    }

    // ── Precise flood fill with perceptual color distance ──────────────────
    _preciseFloodFill(
      _image!,
      imgX,
      imgY,
      px.r.toInt(),
      px.g.toInt(),
      px.b.toInt(),
      _tolerance,
    );

    // ── Edge fringe cleanup pass ───────────────────────────────────────────
    // After the fill, semi-transparent / mixed-colour edge pixels remain.
    // This pass checks every pixel adjacent to a transparent pixel and removes
    // it if it blends strongly toward the removed colour.
    _cleanEdgeFringe(
      _image!,
      px.r.toInt(),
      px.g.toInt(),
      px.b.toInt(),
      _tolerance * 1.6, // slightly wider to catch blended edge pixels
    );

    final newBytes = Uint8List.fromList(img.encodePng(_image!));
    if (!mounted) return;
    setState(() {
      _previewBytes = newBytes;
      _isProcessing = false;
    });
  }

  // ── Precise flood fill using perceptual ΔE colour distance ────────────────
  // Standard abs-per-channel misses pixels where one channel is fine but
  // another is slightly off. ΔE treats the colour as a 3D point and measures
  // true Euclidean distance, which is far more accurate at edges.
  void _preciseFloodFill(
    img.Image image,
    int startX,
    int startY,
    int bgR,
    int bgG,
    int bgB,
    double tolerance,
  ) {
    final w = image.width;
    final h = image.height;
    final visited = Uint8List(w * h);
    final stack = <int>[startY * w + startX];
    // Convert tolerance from 0-100 scale to ΔE scale (max ΔE ≈ 441)
    final deltaETolerance = tolerance * tolerance; // squared distance

    while (stack.isNotEmpty) {
      final idx = stack.removeLast();
      if (visited[idx] == 1) continue;
      visited[idx] = 1;

      final x = idx % w;
      final y = idx ~/ w;

      final px = image.getPixel(x, y);
      if (px.a.toInt() == 0) continue;

      final r = px.r.toInt();
      final g = px.g.toInt();
      final b = px.b.toInt();

      final dr = (r - bgR).toDouble();
      final dg = (g - bgG).toDouble();
      final db = (b - bgB).toDouble();
      final distSq = dr * dr + dg * dg + db * db;

      if (distSq <= deltaETolerance) {
        image.setPixelRgba(x, y, 0, 0, 0, 0);
        if (x > 0) stack.add(idx - 1);
        if (x < w - 1) stack.add(idx + 1);
        if (y > 0) stack.add(idx - w);
        if (y < h - 1) stack.add(idx + w);
      }
    }
  }

  // ── Edge fringe cleanup ────────────────────────────────────────────────────
  // Scans every pixel that neighbours a transparent pixel. If it is a mix of
  // the background colour and anything else (i.e. an anti-aliased edge pixel),
  // make it fully transparent too. This removes the coloured halo/fringe.
  void _cleanEdgeFringe(
    img.Image image,
    int bgR,
    int bgG,
    int bgB,
    double tolerance,
  ) {
    final w = image.width;
    final h = image.height;
    final toRemove = <int>[];
    final deltaETolerance = tolerance * tolerance;

    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final px = image.getPixel(x, y);
        if (px.a.toInt() == 0) continue; // already transparent

        // Check if any 4-connected neighbour is transparent
        bool hasTransparentNeighbour = false;
        if (x > 0 && image.getPixel(x - 1, y).a.toInt() == 0) hasTransparentNeighbour = true;
        if (!hasTransparentNeighbour && x < w - 1 && image.getPixel(x + 1, y).a.toInt() == 0) hasTransparentNeighbour = true;
        if (!hasTransparentNeighbour && y > 0 && image.getPixel(x, y - 1).a.toInt() == 0) hasTransparentNeighbour = true;
        if (!hasTransparentNeighbour && y < h - 1 && image.getPixel(x, y + 1).a.toInt() == 0) hasTransparentNeighbour = true;
        // Also check diagonals for corner pixels
        if (!hasTransparentNeighbour && x > 0 && y > 0 && image.getPixel(x - 1, y - 1).a.toInt() == 0) hasTransparentNeighbour = true;
        if (!hasTransparentNeighbour && x < w - 1 && y > 0 && image.getPixel(x + 1, y - 1).a.toInt() == 0) hasTransparentNeighbour = true;
        if (!hasTransparentNeighbour && x > 0 && y < h - 1 && image.getPixel(x - 1, y + 1).a.toInt() == 0) hasTransparentNeighbour = true;
        if (!hasTransparentNeighbour && x < w - 1 && y < h - 1 && image.getPixel(x + 1, y + 1).a.toInt() == 0) hasTransparentNeighbour = true;

        if (!hasTransparentNeighbour) continue;

        final r = px.r.toInt();
        final g = px.g.toInt();
        final b = px.b.toInt();
        final dr = (r - bgR).toDouble();
        final dg = (g - bgG).toDouble();
        final db = (b - bgB).toDouble();
        final distSq = dr * dr + dg * dg + db * db;

        if (distSq <= deltaETolerance) {
          toRemove.add(y * w + x);
        }
      }
    }

    for (final idx in toRemove) {
      final x = idx % w;
      final y = idx ~/ w;
      image.setPixelRgba(x, y, 0, 0, 0, 0);
    }
  }

  // ── Eraser mode: pure swipe, no re-encode mid-stroke ──────────────────────
  void _onEraserStart(DragStartDetails details) {
    if (_mode != _EditMode.eraser || _image == null) return;
    if (!_strokeActive) {
      // Save undo snapshot once at the start of each new stroke
      final snapshot = Uint8List.fromList(img.encodePng(_image!));
      _undoStack.add(snapshot);
      _strokeActive = true;
    }
    _applyEraserAt(details.localPosition);
  }

  void _onEraserUpdate(DragUpdateDetails details) {
    if (_mode != _EditMode.eraser || _image == null) return;
    _applyEraserAt(details.localPosition);
    // Lightweight live preview: encode only a small region or throttle.
    // For smoothness we do encode here but without setState flutter won't repaint;
    // We call setState but skip heavy PNG encode — just mark dirty via a counter.
    _schedulePreviewUpdate();
  }

  int _pendingUpdates = 0;
  void _schedulePreviewUpdate() {
    _pendingUpdates++;
    if (_pendingUpdates > 3) return; // throttle: encode at most every 3 drag events
    Future.microtask(() {
      if (!mounted || _image == null) return;
      final bytes = Uint8List.fromList(img.encodePng(_image!));
      if (mounted) setState(() => _previewBytes = bytes);
      _pendingUpdates = 0;
    });
  }

  void _onEraserEnd(DragEndDetails details) {
    if (!mounted || _image == null) return;
    _strokeActive = false;
    _pendingUpdates = 0;
    // Final encode at stroke end for full quality preview
    final newBytes = Uint8List.fromList(img.encodePng(_image!));
    setState(() => _previewBytes = newBytes);
  }

  /// Erases a circle of pixels directly in [_image] (no setState here).
  void _applyEraserAt(Offset localPos) {
    final coords = _toImageCoords(localPos);
    if (coords == null || _image == null) return;
    final cx = coords.dx.round();
    final cy = coords.dy.round();
    final r = _eraserSize.round();
    for (int dy = -r; dy <= r; dy++) {
      for (int dx = -r; dx <= r; dx++) {
        if (dx * dx + dy * dy <= r * r) {
          final px = cx + dx;
          final py = cy + dy;
          if (px >= 0 && py >= 0 && px < _image!.width && py < _image!.height) {
            _image!.setPixelRgba(px, py, 0, 0, 0, 0);
          }
        }
      }
    }
  }

  // ── Undo ───────────────────────────────────────────────────────────────────
  Future<void> _undo() async {
    if (_undoStack.isEmpty) return;
    setState(() => _isProcessing = true);
    final previous = _undoStack.removeLast();
    final decoded = await _decode(previous);
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
    final decoded = await _decode(bytes);
    if (!mounted) return;
    setState(() {
      _image = decoded;
      _previewBytes = bytes;
      _isProcessing = false;
    });
  }

  // ── Done ───────────────────────────────────────────────────────────────────
  Future<void> _done() async {
    if (_image == null) return;
    setState(() => _isProcessing = true);
    final dir = await getApplicationDocumentsDirectory();
    final fileName = 'manual_bg_${DateTime.now().millisecondsSinceEpoch}.png';
    final outPath = p.join(dir.path, fileName);
    await File(outPath).writeAsBytes(Uint8List.fromList(img.encodePng(_image!)));
    if (!mounted) return;
    Navigator.pop(context, File(outPath));
  }

  void _showInfo(String msg) {
    final now = DateTime.now();
    if (_lastSnackbarTime != null &&
        now.difference(_lastSnackbarTime!).inMilliseconds < 2000) return;
    _lastSnackbarTime = now;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
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
          IconButton(
            icon: const Icon(Icons.undo),
            tooltip: 'Undo',
            onPressed: _undoStack.isEmpty || _isProcessing ? null : _undo,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reset',
            onPressed: _isProcessing ? null : _reset,
          ),
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
          ? const Center(child: CircularProgressIndicator(color: Colors.deepOrange))
          : Column(
              children: [
                // ── Mode selector ─────────────────────────────────────────
                Container(
                  color: const Color(0xff1c1c1c),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Row(
                    children: [
                      Expanded(child: _buildModeButton(_EditMode.fill)),
                      const SizedBox(width: 10),
                      Expanded(child: _buildModeButton(_EditMode.eraser)),
                    ],
                  ),
                ),

                // ── Instruction banner ────────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.deepOrange.withValues(alpha: 0.15),
                    border: Border(
                      bottom: BorderSide(color: Colors.deepOrange.withValues(alpha: 0.3)),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _mode == _EditMode.fill ? Icons.touch_app : Icons.auto_fix_normal,
                        color: Colors.deepOrange,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _mode == _EditMode.fill
                              ? 'Tap on a colour to remove it precisely. Use low tolerance for clean edges.'
                              : 'Swipe over areas you want to erase. Adjust size below.',
                          style: const TextStyle(color: Colors.white, fontSize: 12, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Image canvas ──────────────────────────────────────────
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(child: CustomPaint(painter: _CheckerboardPainter())),
                      Positioned.fill(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            _widgetSize = Size(constraints.maxWidth, constraints.maxHeight);
                            return GestureDetector(
                              // Fill mode: tap only
                              onTapDown: _mode == _EditMode.fill ? _onImageTap : null,
                              // Eraser mode: swipe (pan gestures)
                              onPanStart: _mode == _EditMode.eraser ? _onEraserStart : null,
                              onPanUpdate: _mode == _EditMode.eraser ? _onEraserUpdate : null,
                              onPanEnd: _mode == _EditMode.eraser ? _onEraserEnd : null,
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
                      if (_isProcessing)
                        Positioned.fill(
                          child: Container(
                            color: Colors.black.withValues(alpha: 0.45),
                            child: const Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircularProgressIndicator(color: Colors.deepOrange),
                                  SizedBox(height: 12),
                                  Text('Processing…', style: TextStyle(color: Colors.white, fontSize: 14)),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // ── Bottom controls ───────────────────────────────────────
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  color: const Color(0xff1c1c1c),
                  child: _mode == _EditMode.fill
                      ? _buildToleranceSlider()
                      : _buildEraserSizeSlider(),
                ),
              ],
            ),
    );
  }

  Widget _buildModeButton(_EditMode mode) {
    final isActive = _mode == mode;
    final label = mode == _EditMode.fill ? 'Fill Remove' : 'Eraser';
    final icon = mode == _EditMode.fill ? Icons.colorize : Icons.auto_fix_normal;
    return GestureDetector(
      onTap: () => setState(() => _mode = mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? Colors.deepOrange : Colors.white12,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isActive ? Colors.deepOrange : Colors.white24),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildToleranceSlider() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Colour Tolerance',
                style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
            _buildBadge(_tolerance.round().toString()),
          ],
        ),
        const SizedBox(height: 4),
        _buildSlider(
          value: _tolerance, min: 5, max: 80,
          leftLabel: 'Precise', rightLabel: 'Wide',
          onChanged: (v) => setState(() => _tolerance = v),
        ),
        const SizedBox(height: 4),
        const Text(
          'Keep low (5–20) for clean edges. Raise only if colour is patchy.',
          style: TextStyle(color: Colors.white38, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildEraserSizeSlider() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Eraser Size',
                style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
            _buildBadge('${_eraserSize.round()}px'),
          ],
        ),
        const SizedBox(height: 4),
        _buildSlider(
          value: _eraserSize, min: 5, max: 80,
          leftLabel: 'Small', rightLabel: 'Large',
          onChanged: (v) => setState(() => _eraserSize = v),
        ),
        const SizedBox(height: 4),
        const Text(
          'Swipe over areas to erase. Each stroke can be undone.',
          style: TextStyle(color: Colors.white38, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: Colors.deepOrange, borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildSlider({
    required double value, required double min, required double max,
    required String leftLabel, required String rightLabel,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: [
        Text(leftLabel, style: const TextStyle(color: Colors.white38, fontSize: 11)),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: Colors.deepOrange,
              inactiveTrackColor: Colors.white.withValues(alpha: 0.15),
              thumbColor: Colors.deepOrange,
              overlayColor: Colors.deepOrange.withValues(alpha: 0.2),
              trackHeight: 4,
            ),
            child: Slider(
              value: value, min: min, max: max,
              onChanged: _isProcessing ? null : onChanged,
            ),
          ),
        ),
        Text(rightLabel, style: const TextStyle(color: Colors.white38, fontSize: 11)),
      ],
    );
  }
}

class _CheckerboardPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const tileSize = 12.0;
    final paintLight = Paint()..color = const Color(0xFF3A3A3A);
    final paintDark = Paint()..color = const Color(0xFF2A2A2A);
    for (double y = 0; y < size.height; y += tileSize) {
      for (double x = 0; x < size.width; x += tileSize) {
        final isEven = ((x / tileSize).floor() + (y / tileSize).floor()) % 2 == 0;
        canvas.drawRect(Rect.fromLTWH(x, y, tileSize, tileSize), isEven ? paintLight : paintDark);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}