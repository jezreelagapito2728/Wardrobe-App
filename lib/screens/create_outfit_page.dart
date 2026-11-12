import '../../utils/constants.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../services/local_db.dart';
import 'outfit_detail_page.dart';





class CreateOutfitPage extends StatefulWidget {
  final Map<String, dynamic>? outfit;

  const CreateOutfitPage({super.key, this.outfit});

  @override
  State<CreateOutfitPage> createState() => _CreateOutfitPageState();
}

class _CreateOutfitPageState extends State<CreateOutfitPage> with SingleTickerProviderStateMixin {
  final TextEditingController _nameController = TextEditingController();
  Map<String, String?> selectedImages = {};
  Map<String, List<Map<String, dynamic>>> allItemsByCategory = {};

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  bool get isEditing => widget.outfit != null;

  // Ordered categories from top to bottom (how people dress)
  final List<String> predefinedCategories = [
    'Accessories',
    'Tops',
    'Bottoms',
    'Footwear',
  ];

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

    if (isEditing) {
      _nameController.text = widget.outfit!['name'] ?? "";
      selectedImages = {
        'Tops': widget.outfit!['topPath'],
        'Bottoms': widget.outfit!['bottomPath'],
        'Footwear': widget.outfit!['shoesPath'],
        'Accessories': widget.outfit!['accessoriesPath'],
      };
    } else {
      selectedImages = {for (var cat in predefinedCategories) cat: null};
    }

    _loadItems();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadItems() async {
    // Seed sample data if database is empty
    await DBHelper.instance.seedSampleDataIfEmpty();
    final items = await DBHelper.instance.getItems();
    final Map<String, List<Map<String, dynamic>>> categorizedItems = {
      for (var cat in predefinedCategories) cat: [],
    };

    for (var item in items) {
      final String? mainCategory = item['mainCategory'];
      if (mainCategory != null && categorizedItems.containsKey(mainCategory)) {
        categorizedItems[mainCategory]!.add(item);
      }
    }
    setState(() {
      allItemsByCategory = categorizedItems;
      if (!isEditing) {
        selectedImages = {for (var cat in predefinedCategories) cat: null};
      }
    });
  }

  void _selectItem(String category, String imagePath) {
    setState(() {
      selectedImages[category] = imagePath;
    });
    Navigator.pop(context);
  }

  void _openSelectionSheet(String category) {
    final items = allItemsByCategory[category] ?? [];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, controller) => Container(
          decoration: BoxDecoration(
            color: linen,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: softSage.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: [
              // Handle bar + header (non-scrollable)
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: softSage.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: forestInk.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _getCategoryIcon(category),
                        color: forestInk,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      "Select $category",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: forestInk,
                      ),
                    ),
                  ],
                ),
              ),
              // Scrollable grid
              Expanded(
                child: items.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(40),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: forestInk.withValues(alpha: 0.06),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.shopping_bag_outlined,
                                  size: 48,
                                  color: forestInk.withValues(alpha: 0.4),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                "No items found",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: forestInk,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "Please add items in this category first",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: forestInk.withValues(alpha: 0.5),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : GridView.builder(
                        controller: controller,
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.55,
                        ),
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final item = items[index];
                          return _ItemSelectionCard(
                            item: item,
                            onTap: () => _selectItem(category, item['imagePath']),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOutfitPreview() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: linen,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: softSage.withValues(alpha: 0.2)),
            boxShadow: [
              BoxShadow(
                color: forestInk.withValues(alpha: 0.06),
                spreadRadius: 1,
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: forestInk.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.preview_rounded, color: forestInk, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        "Outfit Preview",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: forestInk,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: forestInk.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      "${_getSelectedItemsCount()}/4",
                      style: TextStyle(
                        color: forestInk,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Outfit visualization in vertical layout
              Column(
                children: [
                  // Accessories
                  _buildPreviewItem('Accessories', 80),
                  const SizedBox(height: 12),

                  // Tops
                  _buildPreviewItem('Tops', 120),
                  const SizedBox(height: 12),

                  // Bottoms
                  _buildPreviewItem('Bottoms', 120),
                  const SizedBox(height: 12),

                  // Footwear
                  _buildPreviewItem('Footwear', 80),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewItem(String category, double height) {
    final imagePath = selectedImages[category];
    final hasItems = allItemsByCategory[category]?.isNotEmpty ?? false;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: GestureDetector(
          onTap: () => _openSelectionSheet(category),
          child: Container(
            height: height,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: linen,
              border: Border.all(
                color: imagePath != null
                    ? forestInk.withValues(alpha: 0.3)
                    : softSage.withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            child: Stack(
              children: [
                // Main content
                if (imagePath != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.file(
                      File(imagePath),
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.contain,
                    ),
                  )
                else
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: forestInk.withValues(alpha: 0.08),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.add_rounded,
                            size: 24,
                            color: softSage,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Flexible(
                          child: Text(
                            hasItems
                                ? "Add ${category.toLowerCase()}"
                                : "No ${category.toLowerCase()}",
                            style: TextStyle(
                              color: forestInk.withValues(alpha: 0.5),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Category label
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: forestInk.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      category,
                      style: const TextStyle(
                        color: linen,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                // Remove button (only if item is selected)
                if (imagePath != null)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          selectedImages[category] = null;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.red.shade600,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 14,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  int _getSelectedItemsCount() {
    return selectedImages.values.where((path) => path != null).length;
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Accessories':
        return Icons.watch_rounded;
      case 'Tops':
        return Icons.checkroom_rounded;
      case 'Bottoms':
        return Icons.dry_cleaning_rounded;
      case 'Footwear':
        return Icons.run_circle_rounded;
      default:
        return Icons.shopping_bag_outlined;
    }
  }

  void _saveOrUpdateOutfit() async {
    final name = _nameController.text.trim();

    // extract individual paths based on your DB schema
    final accessoriesPath = selectedImages['Accessories'];
    final topPath = selectedImages['Tops'];
    final bottomPath = selectedImages['Bottoms'];
    final shoesPath = selectedImages['Footwear'];

    if (name.isEmpty) {
      _showError('Please enter an outfit name.');
      return;
    }

    if ([
      accessoriesPath,
      topPath,
      bottomPath,
      shoesPath,
    ].every((e) => e == null)) {
      _showError('Please select at least one item.');
      return;
    }

    final outfit = {
      'name': name,
      'accessoriesPath': accessoriesPath,
      'topPath': topPath,
      'bottomPath': bottomPath,
      'shoesPath': shoesPath,
    };

    try {
      final outfitId;
      if (isEditing) {
        await DBHelper.instance.updateOutfit(widget.outfit!['id'], outfit);
        outfitId = widget.outfit!['id'];
      } else {
        outfitId = await DBHelper.instance.addOutfit(outfit);
      }

      final outfitWithId = {...outfit, 'id': outfitId};

      _showSuccess(isEditing ? 'Outfit updated!' : 'Outfit saved!');

      // Navigate to the outfit detail page
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OutfitDetailPage(
              outfit: outfitWithId,
              isWeb: kIsWeb,
            ),
          ),
        );
      }
    } catch (e) {
      _showError('Failed: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(message, style: const TextStyle(fontSize: 14))),
          ],
        ),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Text(message, style: const TextStyle(fontSize: 14)),
          ],
        ),
        backgroundColor: const Color(0xFF2D6A4F),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
            child: CustomScrollView(
              slivers: [
                // App Bar
                SliverAppBar(
                  floating: true,
                  snap: true,
                  elevation: 0,
                  backgroundColor: linen,
                  surfaceTintColor: Colors.transparent,
                  leading: IconButton(
                    icon: Icon(Icons.arrow_back_rounded, color: forestInk),
                    onPressed: () => Navigator.pop(context),
                  ),
                  title: Text(
                    isEditing ? 'Edit Outfit' : 'Create Outfit',
                    style: TextStyle(
                      color: forestInk,
                      fontWeight: FontWeight.w700,
                      fontSize: 22,
                      letterSpacing: -0.3,
                    ),
                  ),
                  centerTitle: false,
                ),

                // Content
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Outfit name input
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: linen,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: softSage.withValues(alpha: 0.2)),
                            boxShadow: [
                              BoxShadow(
                                color: forestInk.withValues(alpha: 0.04),
                                spreadRadius: 1,
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: forestInk.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(Icons.edit_rounded, color: forestInk, size: 24),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    "Outfit Name",
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: forestInk,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: _nameController,
                                style: TextStyle(fontSize: 16, color: forestInk),
                                decoration: InputDecoration(
                                  hintText: "Enter a name for your outfit...",
                                  hintStyle: TextStyle(color: forestInk.withValues(alpha: 0.4)),
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide.none,
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(color: forestInk, width: 2),
                                  ),
                                  contentPadding: const EdgeInsets.all(16),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Outfit preview section
                        _buildOutfitPreview(),
                        const SizedBox(height: 24),

                        // Save button
                        ScaleTransition(
                          scale: _fadeAnimation,
                          child: SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: _saveOrUpdateOutfit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: forestInk,
                                foregroundColor: linen,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(isEditing ? Icons.save_as_rounded : Icons.checkroom_rounded, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    isEditing ? "Update Outfit" : "Save Outfit",
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
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
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ItemSelectionCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onTap;

  const _ItemSelectionCard({
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: linen,
          border: Border.all(color: softSage.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(
              color: forestInk.withValues(alpha: 0.04),
              spreadRadius: 1,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                child: Container(
                  color: softSage.withValues(alpha: 0.1),
                  child: Image.file(
                    File(item['imagePath']),
                    fit: BoxFit.contain,
                    width: double.infinity,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['brand'] ?? 'No brand',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: forestInk,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (item['size'] != null && item['size'] != '')
                    Text(
                      "Size: ${item['size']}",
                      style: TextStyle(
                        fontSize: 11,
                        color: forestInk.withValues(alpha: 0.5),
                      ),
                    ),
                  if (item['tags'] != null && item['tags'].toString().isNotEmpty)
                    Text(
                      "Tags: ${item['tags']}",
                      style: TextStyle(
                        fontSize: 11,
                        color: forestInk.withValues(alpha: 0.5),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}