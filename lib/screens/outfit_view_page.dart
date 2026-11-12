import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../utils/constants.dart';
import '../services/local_db.dart';
import '../../widgets/modern_app_bar.dart';

class OutfitViewPage extends StatefulWidget {
  const OutfitViewPage({super.key});

  @override
  State<OutfitViewPage> createState() => _OutfitViewPageState();
}

class _OutfitViewPageState extends State<OutfitViewPage> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _outfits = [];
  bool _isLoading = true;

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
    _loadOutfits();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadOutfits() async {
    final dbHelper = DBHelper.instance;
    await dbHelper.seedSampleDataIfEmpty();
    final outfits = await dbHelper.getAllOutfits();
    setState(() {
      _outfits = outfits;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: linen,
      appBar: ModernAppBar(
        title: 'My Outfits',
        centerTitle: false,
        backgroundColor: linen,
        elevation: 0,
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: forestInk))
              : _outfits.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _outfits.length,
                      itemBuilder: (context, index) {
                        final outfit = _outfits[index];
                        return _OutfitCard(
                          outfit: outfit,
                          onTap: () => Navigator.of(context).push(
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
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
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
                Icons.checkroom_outlined,
                size: 56,
                color: forestInk.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No outfits yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: forestInk,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first outfit from the Browse tab',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: forestInk.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
        borderRadius: BorderRadius.circular(16),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: linen,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: softSage.withValues(alpha: 0.2)),
            boxShadow: [
              BoxShadow(
                color: forestInk.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: forestInk.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.checkroom_rounded,
                  size: 30,
                  color: forestInk.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      outfit['name'] ?? 'Outfit',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: forestInk,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_countItems(outfit)} items',
                      style: TextStyle(
                        fontSize: 13,
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

class OutfitDetailPage extends StatefulWidget {
  final Map<String, dynamic> outfit;
  final bool isWeb;

  const OutfitDetailPage({
    super.key,
    required this.outfit,
    required this.isWeb,
  });

  @override
  State<OutfitDetailPage> createState() => _OutfitDetailPageState();
}

class _OutfitDetailPageState extends State<OutfitDetailPage> with SingleTickerProviderStateMixin {
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
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: linen,
      appBar: ModernAppBar(
        title: widget.outfit['name'] ?? 'Outfit',
        centerTitle: false,
        backgroundColor: linen,
        elevation: 0,
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _OutfitDetailCard(outfit: widget.outfit),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OutfitDetailCard extends StatelessWidget {
  final Map<String, dynamic> outfit;

  const _OutfitDetailCard({required this.outfit});

  @override
  Widget build(BuildContext context) {
    final fields = [
      {'key': 'accessoriesPath', 'label': 'Accessories', 'icon': Icons.watch_rounded, 'color': const Color(0xFF74C69D)},
      {'key': 'topPath', 'label': 'Top', 'icon': Icons.checkroom_rounded, 'color': const Color(0xFF2D6A4F)},
      {'key': 'bottomPath', 'label': 'Bottom', 'icon': Icons.straighten_rounded, 'color': const Color(0xFF40916C)},
      {'key': 'shoesPath', 'label': 'Shoes', 'icon': Icons.directions_walk_rounded, 'color': const Color(0xFF52796F)},
      {'key': 'bagPath', 'label': 'Bag', 'icon': Icons.shopping_bag_rounded, 'color': const Color(0xFF1F2A24)},
    ];

    return ModernCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Outfit Details',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: forestInk,
            ),
          ),
          const SizedBox(height: 20),
          ...fields.map((field) {
            final path = outfit[field['key'] as String];
            final hasItem = path != null && path.toString().isNotEmpty;
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: (field['color'] as Color).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      field['icon'] as IconData,
                      size: 22,
                      color: field['color'] as Color,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          field['label'] as String,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: forestInk,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          hasItem ? 'Added' : 'Not added',
                          style: TextStyle(
                            fontSize: 13,
                            color: hasItem
                                ? (field['color'] as Color)
                                : forestInk.withValues(alpha: 0.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (hasItem)
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (field['color'] as Color).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.check_circle_rounded,
                        color: field['color'] as Color,
                        size: 20,
                      ),
                    ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
}