import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import '../services/local_db.dart';

class BrowsePage extends StatefulWidget {
  const BrowsePage({super.key});

  @override
  State<BrowsePage> createState() => _BrowsePageState();
}

class _BrowsePageState extends State<BrowsePage> {
  static const List<String> _displayCategories = [
    'Accessories',
    'Tops',
    'Bottoms',
    'Footwear',
    'Bag',
  ];

  static const Map<String, IconData> _categoryIcons = {
    'Tops':        Icons.dry_cleaning,
    'Bottoms':     Icons.straighten,
    'Accessories': Icons.watch,
    'Footwear':    Icons.directions_walk,
    'Bag':         Icons.shopping_bag,
  };

  static const List<_OutfitStyle> _outfitStyles = [
    _OutfitStyle('Normal Outfit',          Icons.checkroom_outlined, _ShuffleMode.normal),
    _OutfitStyle('Standard Outfit',        Icons.checkroom,          _ShuffleMode.standard),
    _OutfitStyle('Formal Outfit',          Icons.business_center,    _ShuffleMode.formal),
    _OutfitStyle('Semi-Formal Outfit',     Icons.style,              _ShuffleMode.semiFormal),
    _OutfitStyle('Dark / Bad Boy Outfit',  Icons.nights_stay,        _ShuffleMode.dark),
    _OutfitStyle('Light / Cute Outfit',    Icons.wb_sunny,           _ShuffleMode.light),
    _OutfitStyle('Light-Light-Dark',       Icons.contrast,           _ShuffleMode.lightLightDark),
    _OutfitStyle('Dark-Dark-Light',        Icons.brightness_3,       _ShuffleMode.darkDarkLight),
    _OutfitStyle('Random Outfit',          Icons.shuffle,            _ShuffleMode.random),
  ];

  Map<String, List<Map<String, dynamic>>> allItemsByCategory = {};
  Map<String, List<Map<String, dynamic>>> _displayedByCategory = {};
  final Map<String, PageController> _pageControllers = {};
  final Map<String, int> _currentPages = {};
  bool _loading = true;
  _ShuffleMode _shuffleMode = _ShuffleMode.random;
  int _shuffleVersion = 0;

  @override
  void initState() {
    super.initState();
    _initControllers();
    _loadItems();
  }

  void _initControllers() {
    for (final cat in _displayCategories) {
      _pageControllers[cat] = PageController(viewportFraction: 0.85);
      _currentPages[cat] = 0;
    }
  }

  @override
  void dispose() {
    for (final c in _pageControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadItems() async {
    setState(() => _loading = true);
    final items = await DBHelper.instance.getItems();
    final Map<String, List<Map<String, dynamic>>> categorized = {
      for (final cat in _displayCategories) cat: [],
    };
    for (final item in items) {
      final mc = item['mainCategory'] as String?;
      if (mc != null && categorized.containsKey(mc)) {
        categorized[mc]!.add(item);
      }
    }
    if (!mounted) return;
    setState(() {
      allItemsByCategory = categorized;
      _displayedByCategory = {
        for (final e in categorized.entries) e.key: List.of(e.value),
      };
      _loading = false;
    });
  }

  void _shuffle() {
    final rng = Random();
    final Map<String, List<Map<String, dynamic>>> shuffled = {};

    for (final cat in _displayCategories) {
      final src = List<Map<String, dynamic>>.from(allItemsByCategory[cat] ?? []);
      if (src.isEmpty) {
        shuffled[cat] = src;
        continue;
      }

      switch (_shuffleMode) {
        case _ShuffleMode.normal:
        case _ShuffleMode.standard:
        case _ShuffleMode.random:
          src.shuffle(rng);

        case _ShuffleMode.formal:
          src.sort((a, b) {
            final aF = _isFormalColor(a['color'] as String?);
            final bF = _isFormalColor(b['color'] as String?);
            return (bF ? 1 : 0) - (aF ? 1 : 0);
          });
          if (src.length > 1) src.sublist(1).shuffle(rng);

        case _ShuffleMode.semiFormal:
          src.shuffle(rng);

        case _ShuffleMode.dark:
          src.sort((a, b) {
            final aD = _isDark(a['color'] as String?);
            final bD = _isDark(b['color'] as String?);
            return (bD ? 1 : 0) - (aD ? 1 : 0);
          });
          if (src.length > 1) src.sublist(1).shuffle(rng);

        case _ShuffleMode.light:
          src.sort((a, b) {
            final aL = _isLight(a['color'] as String?);
            final bL = _isLight(b['color'] as String?);
            return (bL ? 1 : 0) - (aL ? 1 : 0);
          });
          if (src.length > 1) src.sublist(1).shuffle(rng);

        case _ShuffleMode.lightLightDark:
          final lights = src
              .where((i) => _isLight(i['color'] as String?))
              .toList()
            ..shuffle(rng);
          final darks = src
              .where((i) => _isDark(i['color'] as String?))
              .toList()
            ..shuffle(rng);
          final others = src
              .where((i) =>
                  !_isLight(i['color'] as String?) &&
                  !_isDark(i['color'] as String?))
              .toList()
            ..shuffle(rng);
          src..clear()..addAll([...lights, ...darks, ...others]);

        case _ShuffleMode.darkDarkLight:
          final darks = src
              .where((i) => _isDark(i['color'] as String?))
              .toList()
            ..shuffle(rng);
          final lights = src
              .where((i) => _isLight(i['color'] as String?))
              .toList()
            ..shuffle(rng);
          final others = src
              .where((i) =>
                  !_isDark(i['color'] as String?) &&
                  !_isLight(i['color'] as String?))
              .toList()
            ..shuffle(rng);
          src..clear()..addAll([...darks, ...lights, ...others]);
      }

      shuffled[cat] = src;
    }

    // Recreate controllers so the PageView truly resets to page 0
    for (final cat in _displayCategories) {
      _pageControllers[cat]?.dispose();
      _pageControllers[cat] = PageController(viewportFraction: 0.85);
    }

    setState(() {
      _displayedByCategory = shuffled;
      _shuffleVersion++;
      for (final cat in _displayCategories) {
        _currentPages[cat] = 0;
      }
    });
  }

  bool _isDark(String? color) {
    if (color == null) return false;
    final c = color.toLowerCase();
    return ['black', 'charcoal', 'navy', 'dark', 'maroon', 'midnight', 'brown', 'burgundy']
        .any(c.contains);
  }

  bool _isLight(String? color) {
    if (color == null) return false;
    final c = color.toLowerCase();
    return ['white', 'cream', 'beige', 'ivory', 'light', 'blush', 'pale', 'pastel', 'powder']
        .any(c.contains);
  }

  bool _isFormalColor(String? color) {
    if (color == null) return false;
    final c = color.toLowerCase();
    return ['black', 'white', 'navy', 'grey', 'gray', 'charcoal', 'dark blue', 'burgundy']
        .any(c.contains);
  }

  // ─── Style selector (above Accessories) ─────────────────────────────────────

  Widget _buildStyleSelector() {
    final currentStyle =
        _outfitStyles.firstWhere((s) => s.mode == _shuffleMode);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      child: PopupMenuButton<_ShuffleMode>(
        onSelected: (mode) {
          setState(() => _shuffleMode = mode);
          _shuffle();
        },
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        itemBuilder: (ctx) => _outfitStyles.map((s) {
          final sel = s.mode == _shuffleMode;
          return PopupMenuItem<_ShuffleMode>(
            value: s.mode,
            child: Row(
              children: [
                Icon(s.icon,
                    size: 18,
                    color: sel ? Color(0xff1c1c1c) : Colors.grey.shade600),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    s.label,
                    style: TextStyle(
                      fontWeight:
                          sel ? FontWeight.bold : FontWeight.normal,
                      color:
                          sel ? const Color(0xFF222222) : Colors.black87,
                    ),
                  ),
                ),
                if (sel)
                  const Icon(Icons.check_circle,
                      color: Color(0xff1c1c1c), size: 16),
              ],
            ),
          );
        }).toList(),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(currentStyle.icon, size: 15, color: Color(0xff1c1c1c)),
              const SizedBox(width: 6),
              Text(
                currentStyle.label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF222222),
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.keyboard_arrow_down,
                  size: 16, color: Colors.grey.shade500),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Browse'),
        backgroundColor: const Color(0xff1c1c1c),
        foregroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      // Shuffle FAB — bottom-right, shuffles immediately
      floatingActionButton: FloatingActionButton(
        onPressed: _shuffle,
        backgroundColor: const Color(0xff1c1c1c),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.shuffle),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadItems,
              child: ListView(
                padding: const EdgeInsets.only(top: 16, bottom: 100),
                children: [
                  _buildStyleSelector(),
                  ..._displayCategories.map(
                    (cat) => _buildCarouselSection(
                        cat, _displayedByCategory[cat] ?? []),
                  ),
                ],
              ),
            ),
    );
  }

  // ─── Category Carousels ──────────────────────────────────────────────────────

  Widget _buildCarouselSection(
      String category, List<Map<String, dynamic>> items) {
    final currentPage = _currentPages[category] ?? 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(_categoryIcons[category] ?? Icons.checkroom,
                        size: 20, color: const Color(0xFF222222)),
                    const SizedBox(width: 8),
                    Text(
                      category,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF222222),
                      ),
                    ),
                  ],
                ),
                if (items.isNotEmpty)
                  Text(
                    '${currentPage + 1} / ${items.length}',
                    style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w500),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          if (items.isEmpty)
            Container(
              height: 140,
              margin: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                        _categoryIcons[category] ??
                            Icons.checkroom_outlined,
                        size: 36,
                        color: Colors.grey.shade400),
                    const SizedBox(height: 8),
                    Text('No $category yet',
                        style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            )
          else
            SizedBox(
              height: 160,
              child: PageView.builder(
                // key forces a full rebuild each shuffle so new order is shown
                key: ValueKey('${category}_$_shuffleVersion'),
                controller: _pageControllers[category],
                itemCount: items.length,
                onPageChanged: (index) =>
                    setState(() => _currentPages[category] = index),
                itemBuilder: (_, index) =>
                    _buildCarouselCard(items[index]),
              ),
            ),
          if (items.length > 1) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(items.length, (i) {
                final active = currentPage == i;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: active ? 18 : 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: active
                        ? const Color(0xff1c1c1c)
                        : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCarouselCard(Map<String, dynamic> item) {
    final imagePath = item['imagePath'] as String?;
    final hasImage = imagePath != null && imagePath.isNotEmpty;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Full image, no crop - transparent background
            if (hasImage)
              Image.file(
                File(imagePath),
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Container(
                  color: Colors.transparent,
                  child: const Icon(Icons.broken_image,
                      size: 40, color: Colors.grey),
                ),
              )
            else
              Container(
                color: Colors.transparent,
                child:
                    const Icon(Icons.image, size: 40, color: Colors.grey),
              ),
            // Gradient overlay + brand name
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.60),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Text(
                  item['brand'] as String? ?? 'No brand',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Data types ───────────────────────────────────────────────────────────────

enum _ShuffleMode {
  normal,
  standard,
  formal,
  semiFormal,
  dark,
  light,
  lightLightDark,
  darkDarkLight,
  random,
}

class _OutfitStyle {
  final String label;
  final IconData icon;
  final _ShuffleMode mode;
  const _OutfitStyle(this.label, this.icon, this.mode);
}
