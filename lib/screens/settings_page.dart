import '../../utils/constants.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'download_page.dart';
import '../../widgets/modern_app_bar.dart';





class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  bool _notificationsOn = true;
  bool _darkMode = false;
  String _selectedLanguage = 'English';

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
    _loadSettings();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsOn = prefs.getBool('notifications_on') ?? true;
      _darkMode = prefs.getBool('dark_mode') ?? false;
      _selectedLanguage = prefs.getString('language') ?? 'English';
    });
  }

  Future<void> _saveSetting(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is String) {
      await prefs.setString(key, value);
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
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
                  title: 'Settings',
                  centerTitle: false,
                  floating: true,
                  snap: true,
                  elevation: 0,
                  backgroundColor: linen,
                  surfaceTintColor: Colors.transparent,
                ),

                // Content
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Column(
                      children: [
                        // Profile Section
                        _SettingsCard(
                          children: [
                            _SettingsTile(
                              icon: Icons.person_outline_rounded,
                              title: 'Edit Profile',
                              subtitle: 'Update your personal information',
                              onTap: () => Navigator.pushNamed(context, '/edit-profile'),
                            ),
                            _SettingsDivider(),
                            _SettingsTile(
                              icon: Icons.download_outlined,
                              title: 'Download App',
                              subtitle: 'Get the APK for easy sharing',
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const DownloadPage()),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // Preferences Section
                        _SettingsCard(
                          title: 'Preferences',
                          children: [
                            _SettingsSwitchTile(
                              icon: Icons.notifications_outlined,
                              title: 'Notifications',
                              subtitle: 'Receive outfit suggestions & reminders',
                              value: _notificationsOn,
                              onChanged: (v) {
                                setState(() => _notificationsOn = v);
                                _saveSetting('notifications_on', v);
                              },
                            ),
                            _SettingsDivider(),
                            _SettingsSwitchTile(
                              icon: Icons.dark_mode_outlined,
                              title: 'Dark Mode',
                              subtitle: 'Use dark theme (coming soon)',
                              value: _darkMode,
                              onChanged: (v) {
                                setState(() => _darkMode = v);
                                _saveSetting('dark_mode', v);
                              },
                            ),
                            _SettingsDivider(),
                            _SettingsDropdownTile(
                              icon: Icons.language_outlined,
                              title: 'Language',
                              subtitle: 'App display language',
                              value: _selectedLanguage,
                              items: ['English', 'Spanish', 'French', 'German', 'Japanese'],
                              onChanged: (v) {
                                setState(() => _selectedLanguage = v!);
                                _saveSetting('language', v);
                              },
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // Account Section
                        _SettingsCard(
                          title: 'Account',
                          children: [
                            _SettingsTile(
                              icon: Icons.logout_rounded,
                              title: 'Sign Out',
                              subtitle: 'Log out of your account',
                              isDestructive: true,
                              onTap: _logout,
                            ),
                            _SettingsDivider(),
                            _SettingsTile(
                              icon: Icons.delete_forever_outlined,
                              title: 'Delete Account',
                              subtitle: 'Permanently remove your data',
                              isDestructive: true,
                              onTap: () => _showDeleteConfirmation(),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // About Section
                        _SettingsCard(
                          title: 'About',
                          children: [
                            _SettingsTile(
                              icon: Icons.info_outline_rounded,
                              title: 'Version',
                              subtitle: '1.0.0',
                              onTap: null,
                            ),
                            _SettingsDivider(),
                            _SettingsTile(
                              icon: Icons.privacy_tip_outlined,
                              title: 'Privacy Policy',
                              subtitle: 'Read our privacy policy',
                              onTap: () {},
                            ),
                            _SettingsDivider(),
                            _SettingsTile(
                              icon: Icons.description_outlined,
                              title: 'Terms of Service',
                              subtitle: 'Read our terms of service',
                              onTap: () {},
                            ),
                          ],
                        ),

                        const SizedBox(height: 40),

                        // App tagline
                        Text(
                          'Wardrobe AI',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: forestInk.withValues(alpha: 0.4),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'v1.0.0 • Made with ❤️',
                          style: TextStyle(
                            fontSize: 13,
                            color: forestInk.withValues(alpha: 0.3),
                          ),
                        ),
                        const SizedBox(height: 40),
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

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: linen,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete Account', style: TextStyle(color: forestInk, fontWeight: FontWeight.w700)),
        content: Text(
          'This action is irreversible. All your wardrobe items, outfits, and profile data will be permanently deleted.',
          style: TextStyle(color: forestInk.withValues(alpha: 0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: forestInk.withValues(alpha: 0.7))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Implement account deletion
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Account deletion coming soon')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// ============ Settings UI Components ============

class _SettingsCard extends StatelessWidget {
  final String? title;
  final List<Widget> children;

  const _SettingsCard({this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: linen,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: softSage.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: forestInk.withValues(alpha: 0.03),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Text(
                title!,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: forestInk.withValues(alpha: 0.5),
                  letterSpacing: 0.5,
                ),
              ),
            ),
          Column(children: children),
        ],
      ),
    );
  }
}

class _SettingsDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Divider(color: softSage.withValues(alpha: 0.15), height: 1, thickness: 1),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool isDestructive;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? Colors.red.shade600 : forestInk;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 22, color: color),
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
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 2),
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
            if (onTap != null)
              Icon(
                Icons.chevron_right_rounded,
                color: forestInk.withValues(alpha: 0.3),
                size: 22,
              ),
          ],
        ),
      ),
    );
  }
}

class _SettingsSwitchTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingsSwitchTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: forestInk.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 22, color: forestInk),
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
                const SizedBox(height: 2),
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
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: linen,
            activeTrackColor: forestInk,
            inactiveThumbColor: softSage,
            inactiveTrackColor: softSage.withValues(alpha: 0.3),
          ),
        ],
      ),
    );
  }
}

class _SettingsDropdownTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  const _SettingsDropdownTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: forestInk.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 22, color: forestInk),
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
                const SizedBox(height: 2),
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
          DropdownButton<String>(
            value: value,
            onChanged: onChanged,
            underline: const SizedBox(),
            dropdownColor: linen,
            style: TextStyle(color: forestInk, fontSize: 15, fontWeight: FontWeight.w500),
            icon: Icon(Icons.keyboard_arrow_down_rounded, color: softSage, size: 22),
            borderRadius: BorderRadius.circular(12),
            items: items
                .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                .toList(),
          ),
        ],
      ),
    );
  }
}