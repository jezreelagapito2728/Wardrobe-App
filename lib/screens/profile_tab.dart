import '../../utils/constants.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';

import 'add_item_page.dart';
import '../services/local_db.dart';
import 'item_detail_page.dart';
import 'outfit_detail_page.dart';





class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final DBHelper _dbHelper = DBHelper.instance;
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _outfits = [];
  Map<String, List<Map<String, dynamic>>> _categorizedItems = {};
  bool _isLoading = true;
  String? _userName;
  String? _userEmail;

  static const List<String> _categories = [
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
    _loadData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    // Load user info
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists) {
          final data = doc.data()!;
          setState(() {
            _userName = data['fullName'] ?? data['username'] ?? 'Wardrobe Owner';
            _userEmail = data['email'];
          });
        }
      } catch (e) {
        setState(() {
          _userName = user.displayName ?? 'Wardrobe Owner';
          _userEmail = user.email;
        });
      }
    }

    // Seed sample data if database is empty
    await _dbHelper.seedSampleDataIfEmpty();

    // Load items and outfits
    final items = await _dbHelper.getItems();
    final outfits = await _dbHelper.getAllOutfits();

    final categorized = <String, List<Map<String, dynamic>>>{};
    for (final cat in _categories) {
      categorized[cat] = [];
    }
    for (final item in items) {
      final mc = item['mainCategory'] as String?;
      if (mc != null && categorized.containsKey(mc)) {
        categorized[mc]!.add(item);
      }
    }

    if (!mounted) return;
    setState(() {
      _items = items;
      _outfits = outfits;
      _categorizedItems = categorized;
      _isLoading = false;
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (image != null) {
        final Uint8List? bytes = kIsWeb ? await image.readAsBytes() : null;
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AddItemPage(
              isWeb: kIsWeb,
              imageFile: kIsWeb ? null : File(image.path),
              imageBytes: bytes,
            ),
          ),
        ).then((result) {
          if (result == true) _loadData();
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to pick image: $e'),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  void _showAddOptions() {
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
                'Add New Item',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: forestInk,
                ),
              ),
            ),
            const SizedBox(height: 24),
            _SheetActionTile(
              icon: Icons.camera_alt_rounded,
              title: 'Take Photo',
              subtitle: 'Capture a new item with camera',
              color: const Color(0xFF2D6A4F),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            _SheetActionTile(
              icon: Icons.photo_library_rounded,
              title: 'Choose from Gallery',
              subtitle: 'Select existing photos',
              color: const Color(0xFF40916C),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: linen,
        body: Center(
          child: CircularProgressIndicator(color: forestInk),
        ),
      );
    }

    return Scaffold(
      backgroundColor: linen,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: CustomScrollView(
              slivers: [
                // Profile Header
                SliverToBoxAdapter(
                  child: _ProfileHeader(
                    userName: _userName,
                    userEmail: _userEmail,
                    itemCount: _items.length,
                    outfitCount: _outfits.length,
                    onAddItem: _showAddOptions,
                    onRefresh: _loadData,
                  ),
                ),

                // Categories
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                    child: Row(
                      children: [
                        Text(
                          'Your Wardrobe',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: forestInk,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${_items.length} items',
                          style: TextStyle(
                            fontSize: 13,
                            color: forestInk.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Category Grid
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.1,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final category = _categories[index];
                        final items = _categorizedItems[category] ?? [];
                        return _CategoryCard(
                          category: category,
                          itemCount: items.length,
                          icon: _getCategoryIcon(category),
                          color: _getCategoryColor(category),
                          onTap: () => _navigateToCategory(category),
                        );
                      },
                      childCount: _categories.length,
                    ),
                  ),
                ),

                // Recent Outfits
                if (_outfits.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 32, 20, 12),
                      child: Row(
                        children: [
                          Text(
                            'Recent Outfits',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: forestInk,
                            ),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () => Navigator.pushNamed(context, '/outfit-view'),
                            child: Text(
                              'View All',
                              style: TextStyle(
                                color: forestInk,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 180,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: _outfits.length.clamp(0, 5),
                        itemBuilder: (context, index) {
                          final outfit = _outfits[index];
                          return _OutfitCard(
                            outfit: outfit,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => OutfitDetailPage(
                                  outfit: outfit,
                                  isWeb: kIsWeb,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],

                const SliverToBoxAdapter(child: SizedBox(height: 40)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToCategory(String category) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CategoryItemsPage(category: category, items: _categorizedItems[category] ?? []),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Tops': return Icons.checkroom_rounded;
      case 'Bottoms': return Icons.straighten_rounded;
      case 'Footwear': return Icons.directions_walk_rounded;
      default: return Icons.watch_rounded;
    }
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

// ============ Profile Header ============

class _ProfileHeader extends StatelessWidget {
  final String? userName;
  final String? userEmail;
  final int itemCount;
  final int outfitCount;
  final VoidCallback onAddItem;
  final VoidCallback onRefresh;

  const _ProfileHeader({
    this.userName,
    this.userEmail,
    required this.itemCount,
    required this.outfitCount,
    required this.onAddItem,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: linen,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: softSage.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: forestInk.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Profile row
          Row(
            children: [
              // Avatar
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: forestInk.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                  border: Border.all(color: softSage.withValues(alpha: 0.2)),
                ),
                child: Icon(
                  Icons.person_rounded,
                  size: 32,
                  color: forestInk.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(width: 16),
              // Name & Email
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userName ?? 'Wardrobe Owner',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: forestInk,
                      ),
                    ),
                    const SizedBox(height: 2),
                    if (userEmail != null)
                      Text(
                        userEmail!,
                        style: TextStyle(
                          fontSize: 13,
                          color: forestInk.withValues(alpha: 0.5),
                        ),
                      ),
                  ],
                ),
              ),
              // Add button
              Container(
                decoration: BoxDecoration(
                  color: forestInk.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: IconButton(
                  onPressed: onAddItem,
                  icon: Icon(Icons.add_rounded, color: forestInk, size: 24),
                  tooltip: 'Add Item',
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Stats row
          Row(
            children: [
              Expanded(
                child: _StatItem(
                  label: 'Items',
                  value: '$itemCount',
                  icon: Icons.checkroom_rounded,
                  color: const Color(0xFF2D6A4F),
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: softSage.withValues(alpha: 0.2),
              ),
              Expanded(
                child: _StatItem(
                  label: 'Outfits',
                  value: '$outfitCount',
                  icon: Icons.design_services_rounded,
                  color: const Color(0xFF40916C),
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: softSage.withValues(alpha: 0.2),
              ),
              Expanded(
                child: _StatItem(
                  label: 'Categories',
                  value: '4',
                  icon: Icons.category_rounded,
                  color: const Color(0xFF52796F),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: forestInk,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: forestInk.withValues(alpha: 0.5),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ============ Category Card ============

class _CategoryCard extends StatelessWidget {
  final String category;
  final int itemCount;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _CategoryCard({
    required this.category,
    required this.itemCount,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.2)),
            color: color.withValues(alpha: 0.06),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: Colors.white, size: 26),
              ),
              const Spacer(),
              Text(
                category,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: forestInk,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$itemCount ${itemCount == 1 ? 'item' : 'items'}',
                style: TextStyle(
                  fontSize: 13,
                  color: forestInk.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============ Outfit Card ============

class _OutfitCard extends StatelessWidget {
  final Map<String, dynamic> outfit;
  final VoidCallback onTap;

  const _OutfitCard({required this.outfit, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 150,
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
            color: linen,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: softSage.withValues(alpha: 0.2)),
            boxShadow: [
              BoxShadow(
                color: forestInk.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Outfit image placeholder
              Container(
                height: 110,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: forestInk.withValues(alpha: 0.05),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Center(
                  child: Icon(
                    Icons.checkroom_rounded,
                    size: 40,
                    color: forestInk.withValues(alpha: 0.3),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      outfit['name']?.toString() ?? 'Unnamed Outfit',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: forestInk,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _countItems(outfit).toString() + ' pieces',
                      style: TextStyle(
                        fontSize: 12,
                        color: forestInk.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  int _countItems(Map<String, dynamic> outfit) {
    int count = 0;
    final fields = ['accessoriesPath', 'topPath', 'bottomPath', 'shoesPath', 'bagPath'];
    for (final field in fields) {
      if (outfit[field] != null && outfit[field].toString().isNotEmpty) count++;
    }
    return count;
  }
}

// ============ Category Items Page ============

class CategoryItemsPage extends StatelessWidget {
  final String category;
  final List<Map<String, dynamic>> items;

  const CategoryItemsPage({
    super.key,
    required this.category,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: linen,
      appBar: AppBar(
        title: Text(category, style: TextStyle(color: forestInk, fontWeight: FontWeight.w600)),
        backgroundColor: linen,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: forestInk),
      ),
      body: items.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox_rounded, size: 64, color: softSage),
                  const SizedBox(height: 16),
                  Text(
                    'No $category yet',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: forestInk),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add your first item to get started',
                    style: TextStyle(color: forestInk.withValues(alpha: 0.5)),
                  ),
                ],
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(20),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.75,
              ),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return _ItemGridCard(item: item);
              },
            ),
    );
  }
}

class _ItemGridCard extends StatelessWidget {
  final Map<String, dynamic> item;

  const _ItemGridCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ItemDetailPage(item: item)),
        ),
        borderRadius: BorderRadius.circular(18),
        child: Container(
          decoration: BoxDecoration(
            color: linen,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: softSage.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: forestInk.withValues(alpha: 0.04),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                  ),
                  child: item['imagePath'] != null && item['imagePath'].toString().isNotEmpty
                      ? ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                          child: Image.file(
                            File(item['imagePath']),
                            fit: BoxFit.cover,
                            width: double.infinity,
                            errorBuilder: (_, __, ___) => Icon(
                              Icons.image_rounded,
                              size: 40,
                              color: softSage,
                            ),
                          ),
                        )
                      : Center(
                          child: Icon(Icons.image_rounded, size: 40, color: softSage),
                        ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['category']?.toString() ?? 'Unknown',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: forestInk,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (item['brand'] != null && item['brand'].toString().isNotEmpty)
                      Text(
                        item['brand'],
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

  const _SheetActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: color.withValues(alpha: 0.2)),
              color: color.withValues(alpha: 0.06),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: Colors.white, size: 26),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: forestInk,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 14,
                          color: forestInk.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: forestInk.withValues(alpha: 0.3), size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }
}