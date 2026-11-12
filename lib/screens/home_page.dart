import 'package:flutter/material.dart';
import '../../utils/constants.dart';

import 'add_item_page.dart';
import 'settings_page.dart';
import 'browse_page.dart';
import 'weather_page.dart';
import 'gallery_page.dart';
import 'profile_tab.dart';

// ============ Navigation Item ============

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const _NavItem({required this.icon, required this.activeIcon, required this.label});

  BottomNavigationBarItem toBottomNavItem() {
    return BottomNavigationBarItem(
      icon: Icon(icon, size: 24),
      activeIcon: Icon(activeIcon, size: 24),
      label: label,
    );
  }
}


// ============ Modern Bottom Navigation Bar ============

class _ModernBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final Animation<double> animation;
  final bool hasFab;
  final VoidCallback? onAddItem;

  const _ModernBottomNavBar({
    required this.currentIndex,
    required this.onTap,
    required this.animation,
    this.hasFab = false,
    this.onAddItem,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      const _NavItem(icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, label: 'Profile'),
      const _NavItem(icon: Icons.explore_outlined, activeIcon: Icons.explore_rounded, label: 'Browse'),
      const _NavItem(icon: Icons.wb_sunny_outlined, activeIcon: Icons.wb_sunny_rounded, label: 'Weather'),
      const _NavItem(icon: Icons.photo_library_outlined, activeIcon: Icons.photo_library_rounded, label: 'Gallery'),
      const _NavItem(icon: Icons.settings_outlined, activeIcon: Icons.settings_rounded, label: 'Settings'),
    ];

    // Show add button only on Browse tab (index 1)
    final showAddButton = currentIndex == 1 && onAddItem != null;

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, 100 * (1 - animation.value)),
          child: Opacity(
            opacity: animation.value,
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              decoration: BoxDecoration(
                color: linen,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: softSage.withValues(alpha: 0.2)),
                boxShadow: [
                  BoxShadow(
                    color: forestInk.withValues(alpha: 0.08),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  BottomAppBar(
                    color: Colors.transparent,
                    elevation: 0,
                    notchMargin: 8,
                    shape: hasFab ? const CircularNotchedRectangle() : null,
                    child: SizedBox(
                      height: 64,
                      child: BottomNavigationBar(
                        currentIndex: currentIndex,
                        type: BottomNavigationBarType.fixed,
                        selectedItemColor: forestInk,
                        unselectedItemColor: forestInk.withValues(alpha: 0.4),
                        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
                        backgroundColor: Colors.transparent,
                        elevation: 0,
                        onTap: onTap,
                        items: items.map((item) => item.toBottomNavItem()).toList(),
                      ),
                    ),
                  ),
                  // Add Item button positioned at top right of navbar
                  if (showAddButton)
                    Positioned(
                      top: -24,
                      right: 8,
                      child: MediaQuery(
                        // Ensure button stays within safe area and doesn't overlap navbar content
                        data: MediaQuery.of(context).copyWith(
                          padding: EdgeInsets.zero,
                          viewInsets: EdgeInsets.zero,
                        ),
                        child: _AddItemButton(onPressed: onAddItem!),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AddItemButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _AddItemButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: forestInk,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: forestInk.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(Icons.add_rounded, color: linen, size: 24),
        ),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  final String? initialImagePath;
  final bool navigateToAddItem;

  const HomePage({
    super.key,
    this.initialImagePath,
    this.navigateToAddItem = false,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  int _currentIndex = 0;
  late AnimationController _navAnimationController;
  late Animation<double> _navAnimation;

  final List<Widget> _pages = [
    const ProfileTab(),
    const BrowsePage(),
    const WeatherPage(),
    const GalleryPage(),
    const SettingsPage(),
  ];

  @override
  void initState() {
    super.initState();
    _navAnimationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _navAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _navAnimationController, curve: Curves.easeOutCubic),
    );
    _navAnimationController.forward();
  }

  @override
  void dispose() {
    _navAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_pages.isEmpty) {
      return const Scaffold(
        backgroundColor: linen,
        body: Center(child: CircularProgressIndicator(color: forestInk)),
      );
    }

    // Show add item button on Browse tab
    final showAddButton = _currentIndex == 1;

    return Scaffold(
      backgroundColor: linen,
      body: _pages[_currentIndex],
      floatingActionButton: null,
      bottomNavigationBar: _ModernBottomNavBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() => _currentIndex = index);
        },
        animation: _navAnimation,
        hasFab: false,
        onAddItem: showAddButton ? _navigateToAddItem : null,
      ),
    );
  }

  void _navigateToAddItem() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddItemPage(
          isWeb: false,
        ),
      ),
    );
  }
}