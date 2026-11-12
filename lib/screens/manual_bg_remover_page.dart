import '../../utils/constants.dart';
import 'dart:io';
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

class _ManualBgRemoverPageState extends State<ManualBgRemoverPage> with SingleTickerProviderStateMixin {
  img.Image? _image;
  Uint8List? _previewBytes;
  bool _isLoading = true;
  bool _isProcessing = false;

  double _tolerance = 20;
  double _eraserSize = 20;

  _EditMode _mode = _EditMode.fill;

  final List<Uint8List> _undoStack = [];
  Size _widgetSize = Size.zero;
  DateTime? _lastSnackbarTime;

  bool _strokeActive = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic));
    _animationController.forward();

    _loadImage();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

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

  void _onImageTap(TapDownDetails details) {
    if (_mode != _EditMode.fill || _image == null || _isProcessing) return;
    final coords = _toImageCoords(details.localPosition);
    if (coords == null) return;
    _doFloodFill(coords.dx.round(), coords.dy.round());
  }

  Offset? _toImageCoords(Offset localPos) {
    if (_image == null || _widgetSize.width == 0 || _widgetSize.height == 0) return null;

    final imgW = _image!.width.toDouble();
    final imgH = _image!.height.toDouble();
    final fit = BoxFit.contain;
    final fitted = applyBoxFit(fit, Size(imgW, imgH), _widgetSize);
    final destRect = Alignment.center.inscribe(fitted.destination, Offset.zero & _widgetSize);

    if (!destRect.contains(localPos)) return null;

    final dx = (localPos.dx - destRect.left) / destRect.width * imgW;
    final dy = (localPos.dy - destRect.top) / destRect.height * imgH;

    if (dx < 0 || dx >= imgW || dy < 0 || dy >= imgH) return null;
    return Offset(dx, dy);
  }

  void _doFloodFill(int imgX, int imgY) {
    if (_image == null || _isProcessing) return;
    final w = _image!.width;
    final h = _image!.height;
    if (imgX < 0 || imgX >= w || imgY < 0 || imgY >= h) return;

    final px = _image!.getPixel(imgX, imgY);
    if (px.a.toInt() == 0) {
      _showInfo('That area is already transparent.');
      return;
    }

    final snapshot = Uint8List.fromList(img.encodePng(_image!));
    _undoStack.add(snapshot);

    _preciseFloodFill(
      _image!,
      imgX,
      imgY,
      px.r.toInt(),
      px.g.toInt(),
      px.b.toInt(),
      _tolerance,
    );

    _cleanEdgeFringe(
      _image!,
      px.r.toInt(),
      px.g.toInt(),
      px.b.toInt(),
      _tolerance * 1.6,
    );

    final newBytes = Uint8List.fromList(img.encodePng(_image!));
    if (!mounted) return;
    setState(() {
      _previewBytes = newBytes;
      _isProcessing = false;
    });
  }

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
    final deltaETolerance = tolerance * tolerance;

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
        if (px.a.toInt() == 0) continue;

        bool hasTransparentNeighbour = false;
        if (x > 0 && image.getPixel(x - 1, y).a.toInt() == 0) hasTransparentNeighbour = true;
        if (!hasTransparentNeighbour && x < w - 1 && image.getPixel(x + 1, y).a.toInt() == 0) hasTransparentNeighbour = true;
        if (!hasTransparentNeighbour && y > 0 && image.getPixel(x, y - 1).a.toInt() == 0) hasTransparentNeighbour = true;
        if (!hasTransparentNeighbour && y < h - 1 && image.getPixel(x, y + 1).a.toInt() == 0) hasTransparentNeighbour = true;
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

  void _onEraserStart(DragStartDetails details) {
    if (_mode != _EditMode.eraser || _image == null) return;
    if (!_strokeActive) {
      final snapshot = Uint8List.fromList(img.encodePng(_image!));
      _undoStack.add(snapshot);
      _strokeActive = true;
    }
    _applyEraserAt(details.localPosition);
  }

  void _onEraserUpdate(DragUpdateDetails details) {
    if (_mode != _EditMode.eraser || _image == null) return;
    _applyEraserAt(details.localPosition);
    _schedulePreviewUpdate();
  }

  int _pendingUpdates = 0;
  void _schedulePreviewUpdate() {
    _pendingUpdates++;
    if (_pendingUpdates > 3) return;
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
    final newBytes = Uint8List.fromList(img.encodePng(_image!));
    setState(() => _previewBytes = newBytes);
  }

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
        now.difference(_lastSnackbarTime!).inMilliseconds < 2000) {
      return;
    }
    _lastSnackbarTime = now;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text(msg, style: const TextStyle(fontSize: 14))),
            ],
          ),
          backgroundColor: const Color(0xFF2D6A4F),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: linen,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Column(
              children: [
                // Custom App Bar
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  decoration: BoxDecoration(
                    color: linen,
                    border: Border(
                      bottom: BorderSide(
                        color: softSage.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back_rounded, color: forestInk),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Expanded(
                        child: Text(
                          'Background Remover',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: forestInk,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      // Actions
                      _AnimatedIconButton(
                        icon: Icons.undo_rounded,
                        onPressed: _undoStack.isEmpty || _isProcessing ? null : _undo,
                        isEnabled: _undoStack.isNotEmpty && !_isProcessing,
                      ),
                      _AnimatedIconButton(
                        icon: Icons.refresh_rounded,
                        onPressed: _isProcessing ? null : _reset,
                        isEnabled: !_isProcessing,
                      ),
                      _AnimatedIconButton(
                        icon: Icons.check_rounded,
                        onPressed: _isProcessing || _image == null ? null : _done,
                        isEnabled: _image != null && !_isProcessing,
                        isPrimary: true,
                      ),
                    ],
                  ),
                ),

                // Loading state
                if (_isLoading)
                  Expanded(
                    child: Center(
                      child: CircularProgressIndicator(color: forestInk),
                    ),
                  )
                else
                  Expanded(
                    child: Column(
                      children: [
                        // Mode selector
                        FadeTransition(
                          opacity: _fadeAnimation,
                          child: SlideTransition(
                            position: _slideAnimation,
                            child: Container(
                              color: linen,
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: softSage.withValues(alpha: 0.2),
                                    width: 1,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: _buildModeButton(_EditMode.fill),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildModeButton(_EditMode.eraser),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // Instruction banner
                        FadeTransition(
                          opacity: _fadeAnimation,
                          child: SlideTransition(
                            position: _slideAnimation,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              decoration: BoxDecoration(
                                color: forestInk.withValues(alpha: 0.06),
                                border: Border(
                                  bottom: BorderSide(
                                    color: softSage.withValues(alpha: 0.2),
                                    width: 1,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    _mode == _EditMode.fill
                                        ? Icons.colorize_rounded
                                        : Icons.auto_fix_high_rounded,
                                    color: forestInk,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      _mode == _EditMode.fill
                                          ? 'Tap on a colour to remove it precisely. Use low tolerance for clean edges.'
                                          : 'Swipe over areas you want to erase. Adjust size below.',
                                      style: TextStyle(
                                        color: forestInk.withValues(alpha: 0.7),
                                        fontSize: 13,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // Image canvas
                        Expanded(
                          child: Stack(
                            children: [
                              Positioned.fill(child: CustomPaint(painter: _CheckerboardPainter())),
                              Positioned.fill(
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    _widgetSize = Size(constraints.maxWidth, constraints.maxHeight);
                                    return GestureDetector(
                                      onTapDown: _mode == _EditMode.fill ? _onImageTap : null,
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
                                    color: forestInk.withValues(alpha: 0.5),
                                    child: Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          CircularProgressIndicator(color: forestInk),
                                          const SizedBox(height: 16),
                                          Text(
                                            'Processing…',
                                            style: TextStyle(
                                              color: linen,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w500,
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

                        // Bottom controls
                        FadeTransition(
                          opacity: _fadeAnimation,
                          child: SlideTransition(
                            position: _slideAnimation,
                            child: Container(
                              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                              decoration: BoxDecoration(
                                color: linen,
                                border: Border(
                                  top: BorderSide(
                                    color: softSage.withValues(alpha: 0.2),
                                    width: 1,
                                  ),
                                ),
                              ),
                              child: _mode == _EditMode.fill
                                  ? _buildToleranceSlider()
                                  : _buildEraserSizeSlider(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModeButton(_EditMode mode) {
    final isActive = _mode == mode;
    final label = mode == _EditMode.fill ? 'Fill Remove' : 'Eraser';
    final icon = mode == _EditMode.fill ? Icons.colorize_rounded : Icons.auto_fix_high_rounded;

    return GestureDetector(
      onTap: () => setState(() => _mode = mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isActive ? forestInk : linen,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isActive ? forestInk : softSage.withValues(alpha: 0.3),
            width: 2,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: forestInk.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isActive ? linen : forestInk, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isActive ? linen : forestInk,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
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
            Text(
              'Colour Tolerance',
              style: TextStyle(
                color: forestInk.withValues(alpha: 0.7),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            _buildBadge(_tolerance.round().toString()),
          ],
        ),
        const SizedBox(height: 8),
        _buildSlider(
          value: _tolerance,
          min: 5,
          max: 80,
          leftLabel: 'Precise',
          rightLabel: 'Wide',
          onChanged: (v) => setState(() => _tolerance = v),
        ),
        const SizedBox(height: 8),
        Text(
          'Keep low (5–20) for clean edges. Raise only if colour is patchy.',
          style: TextStyle(
            color: forestInk.withValues(alpha: 0.5),
            fontSize: 11,
          ),
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
            Text(
              'Eraser Size',
              style: TextStyle(
                color: forestInk.withValues(alpha: 0.7),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            _buildBadge('${_eraserSize.round()}px'),
          ],
        ),
        const SizedBox(height: 8),
        _buildSlider(
          value: _eraserSize,
          min: 5,
          max: 80,
          leftLabel: 'Small',
          rightLabel: 'Large',
          onChanged: (v) => setState(() => _eraserSize = v),
        ),
        const SizedBox(height: 8),
        Text(
          'Swipe over areas to erase. Each stroke can be undone.',
          style: TextStyle(
            color: forestInk.withValues(alpha: 0.5),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: forestInk,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: linen,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildSlider({
    required double value,
    required double min,
    required double max,
    required String leftLabel,
    required String rightLabel,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: [
        Text(
          leftLabel,
          style: TextStyle(
            color: forestInk.withValues(alpha: 0.4),
            fontSize: 11,
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: forestInk,
              inactiveTrackColor: softSage.withValues(alpha: 0.3),
              thumbColor: forestInk,
              overlayColor: forestInk.withValues(alpha: 0.2),
              trackHeight: 4,
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              onChanged: _isProcessing ? null : onChanged,
            ),
          ),
        ),
        Text(
          rightLabel,
          style: TextStyle(
            color: forestInk.withValues(alpha: 0.4),
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

class _AnimatedIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final bool isEnabled;
  final bool isPrimary;

  const _AnimatedIconButton({
    required this.icon,
    this.onPressed,
    this.isEnabled = true,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isEnabled ? onPressed : null,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isPrimary
                  ? (isEnabled ? forestInk : forestInk.withValues(alpha: 0.4))
                  : (isEnabled ? forestInk.withValues(alpha: 0.08) : softSage.withValues(alpha: 0.1)),
              borderRadius: BorderRadius.circular(12),
              border: isPrimary
                  ? null
                  : Border.all(
                      color: isEnabled ? softSage.withValues(alpha: 0.3) : softSage.withValues(alpha: 0.15),
                      width: 1,
                    ),
            ),
            child: Icon(
              icon,
              color: isPrimary
                  ? linen
                  : (isEnabled ? forestInk : forestInk.withValues(alpha: 0.4)),
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}

class _CheckerboardPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const tileSize = 12.0;
    final paintLight = Paint()..color = softSage.withValues(alpha: 0.15);
    final paintDark = Paint()..color = softSage.withValues(alpha: 0.25);
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