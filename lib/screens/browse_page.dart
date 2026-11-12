import '../../utils/constants.dart';
import 'dart:math';
import 'dart:io';
import 'package:flutter/material.dart';
import '../services/local_db.dart';
import 'create_outfit_page.dart';
import 'chat_screen.dart';
import '../../widgets/modern_app_bar.dart';





class BrowsePage extends StatefulWidget {
  const BrowsePage({super.key});

  @override
  State<BrowsePage> createState() => _BrowsePageState();
}

class _BrowsePageState extends State<BrowsePage> with SingleTickerProviderStateMixin {
  static const List<String> _displayCategories = [
    'Accessories',
    'Tops',
    'Bottoms',
    'Footwear',
  ];

  static const Map<String, IconData> _categoryIcons = {
    'Tops': Icons.checkroom_rounded,
    'Bottoms': Icons.straighten_rounded,
    'Accessories': Icons.watch_rounded,
    'Footwear': Icons.directions_walk_rounded,
  };

  static const List<_OutfitStyle> _outfitStyles = [
    _OutfitStyle('Random Outfit', Icons.shuffle_rounded, _ShuffleMode.random),
    _OutfitStyle('Normal Outfit', Icons.checkroom_outlined, _ShuffleMode.normal),
    _OutfitStyle('Standard Outfit', Icons.checkroom_rounded, _ShuffleMode.standard),
    _OutfitStyle('Formal Outfit', Icons.business_rounded, _ShuffleMode.formal),
    _OutfitStyle('Semi-Formal Outfit', Icons.style_rounded, _ShuffleMode.semiFormal),
    _OutfitStyle('Dark / Bad Boy Outfit', Icons.nights_stay_rounded, _ShuffleMode.dark),
    _OutfitStyle('Light / Cute Outfit', Icons.wb_sunny_rounded, _ShuffleMode.light),
    _OutfitStyle('Light-Light-Dark', Icons.contrast_rounded, _ShuffleMode.lightLightDark),
    _OutfitStyle('Dark-Dark-Light', Icons.brightness_3_rounded, _ShuffleMode.darkDarkLight),
  ];

  Map<String, List<Map<String, dynamic>>> allItemsByCategory = {};
  Map<String, List<Map<String, dynamic>>> _displayedByCategory = {};
  final Map<String, PageController> _pageControllers = {};
  final Map<String, int> _currentPages = {};
  bool _loading = true;
  _ShuffleMode _shuffleMode = _ShuffleMode.random;
  int _shuffleVersion = 0;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
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
    _initControllers();
    _loadItems();
  }

  @override
  void dispose() {
    _animationController.dispose();
    for (final c in _pageControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _initControllers() {
    for (final cat in _displayCategories) {
      _pageControllers[cat] = PageController(viewportFraction: 0.85);
      _currentPages[cat] = 0;
    }
  }

  Future<void> _loadItems() async {
    setState(() => _loading = true);
    // Seed sample data if database is empty
    await DBHelper.instance.seedSampleDataIfEmpty();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: linen,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: CustomScrollView(
              slivers: [
                // App Bar
                ModernSliverAppBar(
                  title: 'Browse',
                  centerTitle: false,
                  actions: [
                    AnimatedActionButton(
                      icon: Icons.chat_bubble_outline_rounded,
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ChatScreen()),
                      ),
                      tooltip: 'Chat',
                    ),
                    AnimatedActionButton(
                      icon: Icons.add_rounded,
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const CreateOutfitPage()),
                      ),
                      tooltip: 'Create Outfit',
                    ),
                    const SizedBox(width: 8),
                  ],
                ),

                // Style Selector
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    child: _StyleSelector(
                      currentStyle: _outfitStyles.firstWhere((s) => s.mode == _shuffleMode),
                      onChanged: (mode) {
                        setState(() => _shuffleMode = mode);
                        _shuffle();
                      },
                      styles: _outfitStyles,
                    ),
                  ),
                ),

                // Content
                _loading
                    ? SliverFillRemaining(
                        child: Center(
                          child: CircularProgressIndicator(color: forestInk),
                        ),
                      )
                    : SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            if (index == 0) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 100),
                                child: Column(
                                  children: _displayCategories.map((cat) =>
                                    _buildCarouselSection(cat, _displayedByCategory[cat] ?? [])
                                  ).toList(),
                                ),
                              );
                            }
                            return null;
                          },
                          childCount: 1,
                        ),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCarouselSection(
      String category, List<Map<String, dynamic>> items) {
    final currentPage = _currentPages[category] ?? 0;
    final categoryColor = _getCategoryColor(category);
    final categoryIcon = _categoryIcons[category] ?? Icons.checkroom_rounded;

    return Padding(
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: categoryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(categoryIcon, size: 20, color: categoryColor),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      category,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: forestInk,
                      ),
                    ),
                  ],
                ),
                if (items.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: categoryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${currentPage + 1} / ${items.length}',
                      style: TextStyle(
                        fontSize: 12,
                        color: categoryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            _EmptyCategoryCard(
              category: category,
              icon: categoryIcon,
              color: categoryColor,
            )
          else
            SizedBox(
              height: 180,
              child: PageView.builder(
                key: ValueKey('${category}_$_shuffleVersion'),
                controller: _pageControllers[category],
                itemCount: items.length,
                onPageChanged: (index) =>
                    setState(() => _currentPages[category] = index),
                itemBuilder: (_, index) =>
                    _buildCarouselCard(items[index], categoryColor),
              ),
            ),
          if (items.length > 1) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(items.length, (i) {
                final active = currentPage == i;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: active ? 20 : 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: active
                        ? categoryColor
                        : softSage.withValues(alpha: 0.3),
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

  Widget _buildCarouselCard(Map<String, dynamic> item, Color categoryColor) {
    final imagePath = item['imagePath'] as String?;
    final hasImage = imagePath != null && imagePath.isNotEmpty;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: linen,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: categoryColor.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: categoryColor.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
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
                errorBuilder: (_, __, ___) => Center(
                  child: Icon(Icons.broken_image, size: 40, color: softSage),
                ),
              )
            else
              Center(
                child: Icon(Icons.image_rounded, size: 40, color: softSage),
              ),
            // Gradient overlay + brand name
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
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

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Tops': return const Color(0xFF2D6A4F);
      case 'Bottoms': return const Color(0xFF40916C);
      case 'Footwear': return const Color(0xFF52796F);
      default: return const Color(0xFF74C69D);
    }
  }
}


// ============ Style Selector ============

class _StyleSelector extends StatelessWidget {
  final _OutfitStyle currentStyle;
  final ValueChanged<_ShuffleMode> onChanged;
  final List<_OutfitStyle> styles;

  const _StyleSelector({
    required this.currentStyle,
    required this.onChanged,
    required this.styles,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showStyleMenu(context),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: linen,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: softSage.withValues(alpha: 0.2)),
            boxShadow: [
              BoxShadow(
                color: forestInk.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: forestInk.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(currentStyle.icon, size: 16, color: forestInk),
              ),
              const SizedBox(width: 10),
              Text(
                currentStyle.label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: forestInk,
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.keyboard_arrow_down_rounded,
                  size: 18, color: forestInk.withValues(alpha: 0.4)),
            ],
          ),
        ),
      ),
    );
  }

  void _showStyleMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: linen,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: softSage.withValues(alpha: 0.2)),
        ),
        child: DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) => SingleChildScrollView(
            controller: scrollController,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: softSage.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'Outfit Style',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: forestInk,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ...styles.map((style) {
                  final selected = style.mode == currentStyle.mode;
                  final color = _getStyleColor(style.mode);
                  return _SheetActionTile(
                    icon: style.icon,
                    title: style.label,
                    subtitle: _getStyleDescription(style.mode),
                    color: color,
                    onTap: () {
                      Navigator.pop(context);
                      onChanged(style.mode);
                    },
                    isSelected: selected,
                  );
                }),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getStyleColor(_ShuffleMode mode) {
    switch (mode) {
      case _ShuffleMode.random: return const Color(0xFF2D6A4F);
      case _ShuffleMode.normal: return const Color(0xFF40916C);
      case _ShuffleMode.standard: return const Color(0xFF52796F);
      case _ShuffleMode.formal: return const Color(0xFF1F2A24);
      case _ShuffleMode.semiFormal: return const Color(0xFF74C69D);
      case _ShuffleMode.dark: return const Color(0xFF0D1B16);
      case _ShuffleMode.light: return const Color(0xFF96D4B3);
      case _ShuffleMode.lightLightDark: return const Color(0xFF52796F);
      case _ShuffleMode.darkDarkLight: return const Color(0xFF2D6A4F);
    }
  }

  String _getStyleDescription(_ShuffleMode mode) {
    switch (mode) {
      case _ShuffleMode.random: return 'Completely random combination';
      case _ShuffleMode.normal: return 'Balanced everyday look';
      case _ShuffleMode.standard: return 'Classic coordinated outfit';
      case _ShuffleMode.formal: return 'Elegant formal attire';
      case _ShuffleMode.semiFormal: return 'Smart casual style';
      case _ShuffleMode.dark: return 'Dark, edgy aesthetic';
      case _ShuffleMode.light: return 'Bright, fresh colors';
      case _ShuffleMode.lightLightDark: return 'Two lights, one dark';
      case _ShuffleMode.darkDarkLight: return 'Two darks, one light';
    }
  }
}

// ============ Empty Category Card ============

class _EmptyCategoryCard extends StatelessWidget {
  final String category;
  final IconData icon;
  final Color color;

  const _EmptyCategoryCard({
    required this.category,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: linen,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 36, color: color),
            ),
            const SizedBox(height: 12),
            Text(
              'No $category yet',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: forestInk,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Add items from your wardrobe',
              style: TextStyle(
                fontSize: 13,
                color: forestInk.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============ Sheet Action Tile ============

class _SheetActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  final bool isSelected;

  const _SheetActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: color.withValues(alpha: isSelected ? 0.5 : 0.2)),
              color: color.withValues(alpha: isSelected ? 0.1 : 0.06),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected ? color : color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: isSelected ? Colors.white : color, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: forestInk,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: forestInk.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Icon(Icons.check_circle_rounded, color: color, size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============ Data types ============

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