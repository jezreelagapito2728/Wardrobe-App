import '../../utils/constants.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../../widgets/modern_app_bar.dart';


class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  static const int _numPages = 3;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final List<OnboardingData> _onboardingData = [
    OnboardingData(
      title: 'Organize Your Wardrobe',
      description:
          'Digitize your closet with smart categorization. Never lose track of your favorite pieces again.',
      icon: Icons.checkroom_rounded,
      color: const Color(0xFF2D6A4F), // Forest green accent
    ),
    OnboardingData(
      title: 'AI-Powered Outfit Suggestions',
      description:
          'Get personalized outfit recommendations based on weather, occasion, and your unique style.',
      icon: Icons.auto_awesome_rounded,
      color: const Color(0xFF52796F), // Sage accent
    ),
    OnboardingData(
      title: 'Plan & Create Perfect Looks',
      description:
          'Mix and match items to create stunning outfits. Save your favorites for any occasion.',
      icon: Icons.design_services_rounded,
      color: const Color(0xFF40916C), // Emerald accent
    ),
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
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', true);
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  void _nextPage() {
    if (_currentPage < _numPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _completeOnboarding();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: linen,
      appBar: ModernAppBar(
        title: '',
        automaticallyImplyLeading: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            children: [
              // Skip button
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextButton(
                    onPressed: _completeOnboarding,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    child: Text(
                      'Skip',
                      style: TextStyle(
                        color: forestInk.withValues(alpha: 0.5),
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),

              // Page View
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _numPages,
                  onPageChanged: (index) {
                    setState(() => _currentPage = index);
                  },
                  itemBuilder: (context, index) {
                    final data = _onboardingData[index];
                    return _OnboardingSlide(data: data, index: index);
                  },
                ),
              ),

              // Bottom section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
                child: Column(
                  children: [
                    // Page indicator
                    AnimatedSmoothIndicator(
                      activeIndex: _currentPage,
                      count: _numPages,
                      effect: WormEffect(
                        activeDotColor: forestInk,
                        dotColor: softSage.withValues(alpha: 0.3),
                        dotHeight: 10,
                        dotWidth: 10,
                        spacing: 10,
                        strokeWidth: 1.5,
                      ),
                    ),
                    const SizedBox(height: 40),

                    // Next/Get Started button
                    _ModernButton(
                      text: _currentPage < _numPages - 1 ? 'Next' : 'Get Started',
                      onPressed: _nextPage,
                      height: 58,
                      icon: Icon(
                        _currentPage < _numPages - 1
                            ? Icons.arrow_forward_rounded
                            : Icons.check_rounded,
                        size: 20,
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
}

class _OnboardingSlide extends StatelessWidget {
  final OnboardingData data;
  final int index;

  const _OnboardingSlide({required this.data, required this.index});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animated illustration container
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: Duration(milliseconds: 600 + index * 100),
            curve: Curves.elasticOut,
            builder: (context, scale, child) {
              return Transform.scale(
                scale: scale,
                child: Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                    color: data.color.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    border: Border.all(color: data.color.withValues(alpha: 0.2), width: 1),
                  ),
                  child: Center(
                    child: Icon(
                      data.icon,
                      size: 100,
                      color: data.color,
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 56),

          // Title with fade-in
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: Duration(milliseconds: 500 + index * 100),
            curve: Curves.easeOut,
            builder: (context, opacity, child) {
              return Opacity(
                opacity: opacity,
                child: Transform.translate(
                  offset: Offset(0, 20 * (1 - opacity)),
                  child: child,
                ),
              );
            },
            child: Text(
              data.title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: forestInk,
                height: 1.2,
                letterSpacing: -0.3,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Description
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: Duration(milliseconds: 600 + index * 100),
            curve: Curves.easeOut,
            builder: (context, opacity, child) {
              return Opacity(
                opacity: opacity,
                child: Transform.translate(
                  offset: Offset(0, 20 * (1 - opacity)),
                  child: child,
                ),
              );
            },
            child: Text(
              data.description,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: forestInk.withValues(alpha: 0.55),
                height: 1.6,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class OnboardingData {
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  OnboardingData({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });
}

// ============ Reusable Button (Same as Login) ============

class _ModernButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isOutlined;
  final Widget? icon;
  final double height;

  const _ModernButton({
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.isOutlined = false,
    this.icon,
    this.height = 56,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: height,
      decoration: isOutlined
          ? null
          : BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: onPressed != null
                  ? [
                      BoxShadow(
                        color: forestInk.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [],
            ),
    child: ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: forestInk,
        foregroundColor: linen,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.symmetric(horizontal: 24),
      ),
      child: _buildLabel(),
    ),
    );
  }

  Widget _buildLabel() {
    if (isLoading) {
      return const SizedBox(
        height: 22,
        width: 22,
        child: CircularProgressIndicator(strokeWidth: 2.5, color: linen),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[icon!, const SizedBox(width: 10)],
        Text(
          text,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}