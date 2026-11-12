import '../../utils/constants.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';




class DownloadPage extends StatefulWidget {
  static const String APK_DOWNLOAD_URL = 'https://raw.githubusercontent.com/jezreelagapito2728/Wardrobe-App/main/releases/download/v1.0.0/app-debug.apk';

  const DownloadPage({super.key});

  @override
  State<DownloadPage> createState() => _DownloadPageState();
}

class _DownloadPageState extends State<DownloadPage> with SingleTickerProviderStateMixin {
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
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        _showError('Could not open download link');
      }
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
                    'Download App',
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
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                    child: Column(
                      children: [
                        // Hero section
                        _buildHeroSection(),
                        const SizedBox(height: 40),

                        // QR Code
                        _buildQRSection(),
                        const SizedBox(height: 32),

                        // Direct Download Button
                        _buildDirectDownloadButton(),
                        const SizedBox(height: 40),

                        // Instructions
                        _buildInstructionsSection(),
                        const SizedBox(height: 24),

                        // Developer Info
                        _buildDeveloperSection(),
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

  Widget _buildHeroSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [forestInk, const Color(0xFF2D4A3F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: forestInk.withValues(alpha: 0.3),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: linen.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: linen.withValues(alpha: 0.3), width: 2),
            ),
            child: Icon(
              Icons.download_rounded,
              size: 48,
              color: linen,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Download Wardrobe AI',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: linen,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Install directly on any Android device — no app store required',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: linen.withValues(alpha: 0.8),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQRSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: linen,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: softSage.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: forestInk.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: forestInk.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.qr_code_rounded, color: forestInk, size: 24),
              ),
              const SizedBox(width: 12),
              Text(
                'Scan to Download',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: forestInk,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: softSage.withValues(alpha: 0.2)),
            ),
            child: QrImageView(
              data: DownloadPage.APK_DOWNLOAD_URL,
              version: QrVersions.auto,
              size: 240.0,
              gapless: false,
              backgroundColor: Colors.white,
              errorStateBuilder: (cxt, err) {
                return Container(
                  height: 240,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
                        const SizedBox(height: 12),
                        Text(
                          'Error generating QR code',
                          style: TextStyle(color: Colors.red.shade600),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Point your camera at the QR code',
            style: TextStyle(
              fontSize: 14,
              color: forestInk.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDirectDownloadButton() {
    return ScaleTransition(
      scale: _fadeAnimation,
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton.icon(
          onPressed: () => _launchURL(DownloadPage.APK_DOWNLOAD_URL),
          icon: Icon(Icons.cloud_download_rounded, size: 22),
          label: Text(
            'Download APK Directly',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: forestInk,
            foregroundColor: linen,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
      ),
    );
  }

  Widget _buildInstructionsSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: linen,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: softSage.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: forestInk.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
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
                child: Icon(Icons.info_outline_rounded, color: forestInk, size: 24),
              ),
              const SizedBox(width: 12),
              Text(
                'How to Install',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: forestInk,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _InstructionStep(
            number: '1',
            text: 'Scan the QR code or tap "Download APK Directly"',
          ),
          _InstructionStep(
            number: '2',
            text: 'Your browser will download the APK file',
          ),
          _InstructionStep(
            number: '3',
            text: 'Open Downloads and tap the Wardrobe AI.apk file',
          ),
          _InstructionStep(
            number: '4',
            text: 'Allow installation from unknown sources if prompted',
          ),
          _InstructionStep(
            number: '5',
            text: 'Tap Install and wait for completion',
          ),
        ],
      ),
    );
  }

  Widget _buildDeveloperSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2D6A4F).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF2D6A4F).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF2D6A4F).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.code_rounded, color: const Color(0xFF2D6A4F), size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                'For Developers',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF2D6A4F),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '1. Build APK: flutter build apk --release\n\n'
            '2. Upload to GitHub Releases, Firebase Storage, or your web server\n\n'
            '3. Replace APK_DOWNLOAD_URL constant in download_page.dart with your URL',
            style: TextStyle(
              fontSize: 13,
              color: const Color(0xFF2D6A4F).withValues(alpha: 0.8),
              height: 1.7,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}

class _InstructionStep extends StatelessWidget {
  final String number;
  final String text;

  const _InstructionStep({
    required this.number,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: forestInk,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: linen,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 15,
                  color: forestInk.withValues(alpha: 0.7),
                  height: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}