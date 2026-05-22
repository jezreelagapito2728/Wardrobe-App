import 'dart:math';

/// Provides 10 outfit-suggestion algorithms that select one item per category
/// (Tops, Bottoms, Accessories, Footwear) based on different color and style rules.
class OutfitAlgorithms {
  OutfitAlgorithms._();

  static const List<String> algorithmNames = [
    'Random Mix',
    'Color Harmony',
    'Monochromatic',
    'Dark & Light Contrast',
    'All Neutrals',
    'Earth Tones',
    'Pastel Palette',
    'Analogous Colors',
    'Seasonal Palette',
    'Most Recent',
  ];

  static const List<String> algorithmDescriptions = [
    'A random mix of items from each category',
    'Pairs items using complementary / opposing colors',
    'All pieces share the same base color family',
    'Contrasting dark top with light bottom (or vice versa)',
    'Classic neutrals only — black, white, grey, beige',
    'Warm earthy tones: brown, olive, rust, camel',
    'Soft pastels: pink, lavender, mint, baby blue',
    'Colors adjacent on the color wheel for a cohesive look',
    'Palette suited to the current season',
    'Your most recently added pieces from each category',
  ];

  static const List<String> algorithmIcons = [
    'shuffle',
    'color_lens',
    'palette',
    'contrast',
    'circle',
    'forest',
    'water_drop',
    'gradient',
    'calendar_month',
    'access_time',
  ];

  // ─── Color family definitions ───────────────────────────────────────────────

  static const Map<String, List<String>> _families = {
    'neutral': ['black', 'white', 'grey', 'gray', 'beige', 'cream', 'nude', 'ivory', 'charcoal', 'off-white', 'off white', 'ecru'],
    'dark':    ['black', 'charcoal', 'navy', 'dark grey', 'dark gray', 'dark brown', 'maroon', 'deep burgundy', 'midnight'],
    'light':   ['white', 'cream', 'beige', 'ivory', 'off-white', 'light grey', 'light gray', 'blush', 'powder blue', 'pale'],
    'earth':   ['brown', 'tan', 'camel', 'khaki', 'olive', 'rust', 'terracotta', 'burgundy', 'wine', 'forest green', 'caramel', 'chocolate', 'coffee', 'mustard'],
    'pastel':  ['pink', 'lavender', 'lilac', 'mint', 'baby blue', 'light blue', 'peach', 'blush', 'powder blue', 'coral', 'rose', 'mauve', 'sage'],
    'cool':    ['blue', 'teal', 'cyan', 'purple', 'indigo', 'navy', 'cobalt', 'turquoise', 'violet', 'periwinkle', 'slate'],
    'warm':    ['red', 'orange', 'yellow', 'coral', 'salmon', 'gold', 'amber', 'mustard', 'magenta', 'hot pink'],
  };

  // Base color → complementary color keywords
  static const Map<String, List<String>> _complementary = {
    'blue':   ['orange', 'rust', 'amber', 'gold', 'coral', 'peach'],
    'orange': ['blue', 'navy', 'cobalt', 'teal', 'sky blue'],
    'red':    ['green', 'olive', 'forest green', 'teal', 'mint'],
    'green':  ['red', 'burgundy', 'pink', 'coral', 'magenta'],
    'purple': ['yellow', 'gold', 'mustard', 'lime', 'chartreuse'],
    'yellow': ['purple', 'violet', 'lavender', 'indigo', 'plum'],
    'pink':   ['olive', 'khaki', 'forest green', 'sage'],
    'navy':   ['white', 'cream', 'orange', 'rust', 'gold'],
    'brown':  ['blue', 'teal', 'cream', 'sky blue', 'cobalt'],
    'grey':   ['pink', 'coral', 'yellow', 'orange', 'peach'],
    'gray':   ['pink', 'coral', 'yellow', 'orange', 'peach'],
    'black':  ['white', 'red', 'yellow', 'gold', 'any'],
    'white':  ['black', 'navy', 'blue', 'any'],
    'beige':  ['brown', 'olive', 'teal', 'navy', 'burgundy'],
    'teal':   ['orange', 'coral', 'red', 'rust', 'salmon'],
    'coral':  ['teal', 'blue', 'navy', 'green', 'cobalt'],
  };

  // Base color → analogous (adjacent) color keywords
  static const Map<String, List<String>> _analogous = {
    'red':    ['orange', 'pink', 'coral', 'burgundy', 'rose'],
    'orange': ['red', 'yellow', 'coral', 'amber', 'peach'],
    'yellow': ['orange', 'gold', 'lime', 'amber', 'mustard'],
    'green':  ['yellow', 'teal', 'olive', 'lime', 'sage'],
    'teal':   ['green', 'blue', 'cyan', 'turquoise', 'aqua'],
    'blue':   ['teal', 'navy', 'purple', 'indigo', 'cobalt'],
    'purple': ['blue', 'pink', 'violet', 'lavender', 'magenta'],
    'pink':   ['purple', 'red', 'rose', 'coral', 'magenta'],
  };

  static final _rng = Random();

  // ─── Public entry point ─────────────────────────────────────────────────────

  /// Runs algorithm [index] and returns a map of {category → suggested item (nullable)}.
  static Map<String, Map<String, dynamic>?> run(
    int index,
    Map<String, List<Map<String, dynamic>>> byCategory,
  ) {
    switch (index) {
      case 0:  return _randomMix(byCategory);
      case 1:  return _colorHarmony(byCategory);
      case 2:  return _monochromatic(byCategory);
      case 3:  return _darkLightContrast(byCategory);
      case 4:  return _allNeutrals(byCategory);
      case 5:  return _earthTones(byCategory);
      case 6:  return _pastelPalette(byCategory);
      case 7:  return _analogousColors(byCategory);
      case 8:  return _seasonalPalette(byCategory);
      case 9:  return _mostRecent(byCategory);
      default: return _randomMix(byCategory);
    }
  }

  // ─── Algorithms ─────────────────────────────────────────────────────────────

  // 1. Random Mix
  static Map<String, Map<String, dynamic>?> _randomMix(
    Map<String, List<Map<String, dynamic>>> by,
  ) => _pickAll(by, null);

  // 2. Color Harmony (Complementary)
  static Map<String, Map<String, dynamic>?> _colorHarmony(
    Map<String, List<Map<String, dynamic>>> by,
  ) {
    final tops = by['Tops'] ?? [];
    if (tops.isEmpty) return _pickAll(by, null);

    final top = _randomItem(tops)!;
    final topColors = _colors(top);

    final complementary = <String>[];
    for (final c in topColors) {
      for (final key in _complementary.keys) {
        if (c.contains(key)) complementary.addAll(_complementary[key]!);
      }
    }

    return {
      'Tops':        top,
      'Bottoms':     _pickByColor(by['Bottoms'] ?? [],     complementary.isNotEmpty ? complementary : topColors),
      'Accessories': _pickByColor(by['Accessories'] ?? [], [...topColors, ...complementary]),
      'Footwear':    _pickByColor(by['Footwear'] ?? [],    _families['neutral']!),
    };
  }

  // 3. Monochromatic (dominant color family across all items)
  static Map<String, Map<String, dynamic>?> _monochromatic(
    Map<String, List<Map<String, dynamic>>> by,
  ) {
    final all = by.values.expand((i) => i).toList();
    final scorable = {..._families}..remove('dark')..remove('light');

    String bestFamily = 'neutral';
    int bestScore = -1;
    for (final entry in scorable.entries) {
      final score = all.where((item) {
        final cs = _colors(item);
        return cs.any((c) => entry.value.any((fc) => c.contains(fc) || fc.contains(c)));
      }).length;
      if (score > bestScore) {
        bestScore = score;
        bestFamily = entry.key;
      }
    }

    final palette = _families[bestFamily]!;
    return _pickAll(by, palette);
  }

  // 4. Dark & Light Contrast
  static Map<String, Map<String, dynamic>?> _darkLightContrast(
    Map<String, List<Map<String, dynamic>>> by,
  ) {
    final darks  = _families['dark']!;
    final lights = _families['light']!;
    final flipTop = _rng.nextBool();

    return {
      'Tops':        _pickByColor(by['Tops'] ?? [],        flipTop ? darks : lights),
      'Bottoms':     _pickByColor(by['Bottoms'] ?? [],     flipTop ? lights : darks),
      'Accessories': _pickByColor(by['Accessories'] ?? [], [...darks, ...lights]),
      'Footwear':    _pickByColor(by['Footwear'] ?? [],    darks),
    };
  }

  // 5. All Neutrals
  static Map<String, Map<String, dynamic>?> _allNeutrals(
    Map<String, List<Map<String, dynamic>>> by,
  ) => _pickAll(by, _families['neutral']!);

  // 6. Earth Tones
  static Map<String, Map<String, dynamic>?> _earthTones(
    Map<String, List<Map<String, dynamic>>> by,
  ) {
    final earth   = _families['earth']!;
    final neutral = _families['neutral']!;
    return {
      'Tops':        _pickByColor(by['Tops'] ?? [],        earth),
      'Bottoms':     _pickByColor(by['Bottoms'] ?? [],     [...earth, ...neutral]),
      'Accessories': _pickByColor(by['Accessories'] ?? [], earth),
      'Footwear':    _pickByColor(by['Footwear'] ?? [],    [...earth, ...neutral]),
    };
  }

  // 7. Pastel Palette
  static Map<String, Map<String, dynamic>?> _pastelPalette(
    Map<String, List<Map<String, dynamic>>> by,
  ) {
    final pastel  = _families['pastel']!;
    final neutral = _families['neutral']!;
    return {
      'Tops':        _pickByColor(by['Tops'] ?? [],        pastel),
      'Bottoms':     _pickByColor(by['Bottoms'] ?? [],     [...pastel, ...neutral]),
      'Accessories': _pickByColor(by['Accessories'] ?? [], pastel),
      'Footwear':    _pickByColor(by['Footwear'] ?? [],    neutral),
    };
  }

  // 8. Analogous Colors
  static Map<String, Map<String, dynamic>?> _analogousColors(
    Map<String, List<Map<String, dynamic>>> by,
  ) {
    final tops = by['Tops'] ?? [];
    if (tops.isEmpty) return _pickAll(by, null);

    final top = _randomItem(tops)!;
    final topColors = _colors(top);

    final analogous = <String>[];
    for (final c in topColors) {
      for (final key in _analogous.keys) {
        if (c.contains(key)) analogous.addAll(_analogous[key]!);
      }
    }
    final palette = analogous.isNotEmpty ? [...analogous, ...topColors] : topColors;

    return {
      'Tops':        top,
      'Bottoms':     _pickByColor(by['Bottoms'] ?? [],     palette),
      'Accessories': _pickByColor(by['Accessories'] ?? [], analogous.isNotEmpty ? analogous : palette),
      'Footwear':    _pickByColor(by['Footwear'] ?? [],    _families['neutral']!),
    };
  }

  // 9. Seasonal Palette
  static Map<String, Map<String, dynamic>?> _seasonalPalette(
    Map<String, List<Map<String, dynamic>>> by,
  ) {
    final month = DateTime.now().month;
    final List<String> palette;

    if (month >= 3 && month <= 5) {
      // Spring
      palette = ['pink', 'lavender', 'mint', 'light blue', 'peach', 'blush', 'white', 'sage', 'lilac'];
    } else if (month >= 6 && month <= 8) {
      // Summer
      palette = ['white', 'yellow', 'coral', 'turquoise', 'sky blue', 'orange', 'hot pink', 'lime', 'aqua'];
    } else if (month >= 9 && month <= 11) {
      // Autumn
      palette = ['rust', 'orange', 'brown', 'olive', 'burgundy', 'mustard', 'camel', 'terracotta', 'forest green'];
    } else {
      // Winter
      palette = ['black', 'white', 'grey', 'navy', 'charcoal', 'burgundy', 'forest green', 'cobalt', 'cream'];
    }

    return _pickAll(by, palette);
  }

  // 10. Most Recent (highest DB id = most recently added)
  static Map<String, Map<String, dynamic>?> _mostRecent(
    Map<String, List<Map<String, dynamic>>> by,
  ) {
    return {
      for (final cat in ['Tops', 'Bottoms', 'Accessories', 'Footwear'])
        cat: (by[cat] ?? []).isEmpty
            ? null
            : (by[cat]!.toList()
              ..sort((a, b) => (b['id'] as int? ?? 0).compareTo(a['id'] as int? ?? 0)))
                .first,
    };
  }

  // ─── Helpers ────────────────────────────────────────────────────────────────

  /// Picks one item per category, optionally preferring items matching [palette].
  static Map<String, Map<String, dynamic>?> _pickAll(
    Map<String, List<Map<String, dynamic>>> by,
    List<String>? palette,
  ) {
    return {
      for (final cat in ['Tops', 'Bottoms', 'Accessories', 'Footwear'])
        cat: palette == null
            ? _randomItem(by[cat] ?? [])
            : _pickByColor(by[cat] ?? [], palette),
    };
  }

  static Map<String, dynamic>? _randomItem(List<Map<String, dynamic>> items) {
    if (items.isEmpty) return null;
    return items[_rng.nextInt(items.length)];
  }

  /// Returns the item whose colors best match [preferred]; falls back to random.
  static Map<String, dynamic>? _pickByColor(
    List<Map<String, dynamic>> items,
    List<String> preferred,
  ) {
    if (items.isEmpty) return null;

    int bestScore = -1;
    final topItems = <Map<String, dynamic>>[];

    for (final item in items) {
      int score = 0;
      for (final c in _colors(item)) {
        for (final p in preferred) {
          if (c.contains(p) || p.contains(c)) score++;
        }
      }
      if (score > bestScore) {
        bestScore = score;
        topItems.clear();
        topItems.add(item);
      } else if (score == bestScore) {
        topItems.add(item);
      }
    }

    // If no color match at all, fall back to random
    if (bestScore == 0) return _randomItem(items);
    return topItems[_rng.nextInt(topItems.length)];
  }

  static List<String> _colors(Map<String, dynamic> item) {
    final raw = item['colors'] as String? ?? '';
    return raw.split(',').map((c) => c.trim().toLowerCase()).where((c) => c.isNotEmpty).toList();
  }
}
