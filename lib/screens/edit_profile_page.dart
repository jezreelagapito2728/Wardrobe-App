import '../../utils/constants.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../widgets/modern_app_bar.dart';




class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();

  String? _selectedGender;
  DateTime? _selectedBirthday;

  bool _isLoading = false;
  bool _showCurrentPassword = false;
  bool _showNewPassword = false;
  bool _isCurrentPasswordValid = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final List<String> _genders = [
    'Male',
    'Female',
    'Non-binary',
    'Prefer not to say',
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

    _loadUserData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _fullNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = doc.data();
      if (data != null) {
        _fullNameController.text = data['fullName'] ?? '';
        _usernameController.text = data['username'] ?? '';
        _emailController.text = data['email'] ?? '';
        _selectedGender = data['gender'];
        if (data['birthday'] != null) {
          _selectedBirthday = (data['birthday'] as Timestamp).toDate();
        }
        setState(() {});
      }
    }
  }

  Future<void> _selectBirthday(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedBirthday ?? DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: forestInk,
              surface: linen,
              onPrimary: linen,
              onSurface: forestInk,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: forestInk),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedBirthday = picked);
    }
  }

  Future<void> _validateCurrentPassword(String inputPassword) async {
    final user = FirebaseAuth.instance.currentUser;
    final cred = EmailAuthProvider.credential(
      email: user!.email!,
      password: inputPassword,
    );
    try {
      await user.reauthenticateWithCredential(cred);
      setState(() => _isCurrentPasswordValid = true);
    } catch (_) {
      setState(() => _isCurrentPasswordValid = false);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    final bool isChangingPassword =
        _currentPasswordController.text.isNotEmpty &&
        _newPasswordController.text.isNotEmpty;

    if (isChangingPassword && !_isCurrentPasswordValid) {
      _showError('Incorrect current password');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .update({
            'fullName': _fullNameController.text.trim(),
            'username': _usernameController.text.trim(),
            'email': _emailController.text.trim(),
            'gender': _selectedGender,
            'birthday':
                _selectedBirthday != null
                    ? Timestamp.fromDate(_selectedBirthday!)
                    : null,
          });

      if (isChangingPassword) {
        await user.updatePassword(_newPasswordController.text.trim());
        _showSuccess('Password updated. Please log in again.');
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
        }
      } else {
        _showSuccess('Profile updated successfully');
      }
    } catch (e) {
      _showError('Update failed: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
                ModernSliverAppBar(
                  title: 'Edit Profile',
                  centerTitle: false,
                  floating: true,
                  snap: true,
                  elevation: 0,
                  backgroundColor: linen,
                  surfaceTintColor: Colors.transparent,
                  leading: IconButton(
                    icon: Icon(Icons.arrow_back_rounded, color: forestInk),
                    onPressed: () => Navigator.pushReplacementNamed(context, '/settings'),
                  ),
                ),

                // Content
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          // Avatar
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [forestInk, softSage],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: const CircleAvatar(
                              radius: 50,
                              backgroundColor: forestInk,
                              child: Icon(Icons.person_rounded, size: 56, color: linen),
                            ),
                          ),
                          const SizedBox(height: 32),

                          // Profile Info Section
                          _ModernCard(
                            child: Column(
                              children: [
                                _buildTextField(_fullNameController, 'Full Name'),
                                _buildTextField(_usernameController, 'Username'),
                                _buildTextField(
                                  _emailController,
                                  'Email',
                                  inputType: TextInputType.emailAddress,
                                  readOnly: true,
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Personal Details Section
                          _ModernCard(
                            title: 'Personal Details',
                            child: Column(
                              children: [
                                _ModernDropdownField(
                                  label: 'Gender',
                                  value: _selectedGender,
                                  items: _genders,
                                  onChanged: (val) => setState(() => _selectedGender = val),
                                  icon: Icons.person_outline_rounded,
                                ),
                                const SizedBox(height: 16),
                                _ModernDateField(
                                  label: 'Birthday',
                                  value: _selectedBirthday,
                                  onTap: () => _selectBirthday(context),
                                  icon: Icons.cake_outlined,
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Security Section
                          _ModernCard(
                            title: 'Security',
                            child: Column(
                              children: [
                                _ModernPasswordField(
                                  controller: _currentPasswordController,
                                  label: 'Current Password',
                                  hint: 'Enter to change password',
                                  obscureText: !_showCurrentPassword,
                                  onChanged: _validateCurrentPassword,
                                  onVisibilityToggle: () => setState(() => _showCurrentPassword = !_showCurrentPassword),
                                  showVisibilityToggle: true,
                                  isValid: _currentPasswordController.text.isNotEmpty ? _isCurrentPasswordValid : null,
                                  icon: Icons.lock_outline_rounded,
                                ),
                                const SizedBox(height: 16),
                                _ModernPasswordField(
                                  controller: _newPasswordController,
                                  label: 'New Password',
                                  hint: 'At least 6 characters',
                                  obscureText: !_showNewPassword,
                                  onVisibilityToggle: () => setState(() => _showNewPassword = !_showNewPassword),
                                  showVisibilityToggle: true,
                                  showCheck: true,
                                  icon: Icons.lock_rounded,
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 32),

                          // Save Button
                          ScaleTransition(
                            scale: _fadeAnimation,
                            child: SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: _ModernButton(
                                text: 'Save Changes',
                                onPressed: _isLoading ? null : _saveProfile,
                                isLoading: _isLoading,
                                height: 56,
                              ),
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
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label, {
    TextInputType inputType = TextInputType.text,
    bool readOnly = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        readOnly: readOnly,
        keyboardType: inputType,
        style: TextStyle(fontSize: 16, color: forestInk),
        validator: (value) => value == null || value.isEmpty ? 'Please enter $label' : null,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: forestInk.withValues(alpha: 0.6)),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: softSage.withValues(alpha: 0.3)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: softSage.withValues(alpha: 0.3)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: forestInk, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }
}

// ============ Modern Card ============

class _ModernCard extends StatelessWidget {
  final Widget child;
  final String? title;

  const _ModernCard({required this.child, this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
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
          if (title != null) ...[
            Text(
              title!,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: forestInk,
              ),
            ),
            const SizedBox(height: 16),
          ],
          child,
        ],
      ),
    );
  }
}

// ============ Modern Dropdown Field ============

class _ModernDropdownField extends StatelessWidget {
  final String label;
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  final IconData icon;

  const _ModernDropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: value,
      onChanged: onChanged,
      style: TextStyle(fontSize: 16, color: forestInk),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: forestInk.withValues(alpha: 0.6)),
        prefixIcon: Icon(icon, color: softSage, size: 22),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: softSage.withValues(alpha: 0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: softSage.withValues(alpha: 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: forestInk, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      items: items.map((String value) {
        return DropdownMenuItem<String>(
          value: value,
          child: Text(value, style: TextStyle(color: forestInk)),
        );
      }).toList(),
      dropdownColor: linen,
      borderRadius: BorderRadius.circular(16),
      icon: Icon(Icons.keyboard_arrow_down_rounded, color: softSage),
    );
  }
}

// ============ Modern Date Field ============

class _ModernDateField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  final IconData icon;

  const _ModernDateField({
    required this.label,
    required this.value,
    required this.onTap,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      readOnly: true,
      onTap: onTap,
      style: TextStyle(fontSize: 16, color: forestInk),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: forestInk.withValues(alpha: 0.6)),
        prefixIcon: Icon(icon, color: softSage, size: 22),
        suffixIcon: value != null
            ? IconButton(
                icon: Icon(Icons.clear_rounded, color: forestInk.withValues(alpha: 0.5)),
                onPressed: () => onTap(), // This would need a callback to clear
              )
            : null,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: softSage.withValues(alpha: 0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: softSage.withValues(alpha: 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: forestInk, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      controller: TextEditingController(
        text: value == null
            ? ''
            : '${value!.month}/${value!.day}/${value!.year}',
      ),
    );
  }
}

// ============ Modern Password Field ============

class _ModernPasswordField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final bool obscureText;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onVisibilityToggle;
  final bool showVisibilityToggle;
  final bool showCheck;
  final bool? isValid;
  final IconData icon;

  const _ModernPasswordField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.obscureText,
    this.onChanged,
    this.onVisibilityToggle,
    this.showVisibilityToggle = false,
    this.showCheck = false,
    this.isValid,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final hasText = controller.text.isNotEmpty;
    final isValidState = isValid ?? (hasText && controller.text.length >= 6);

    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      onChanged: onChanged,
      style: TextStyle(fontSize: 16, color: forestInk),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: forestInk.withValues(alpha: 0.6)),
        hintText: hint,
        hintStyle: TextStyle(color: forestInk.withValues(alpha: 0.4)),
        prefixIcon: Icon(icon, color: softSage, size: 22),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasText && !showVisibilityToggle) ...[
              Icon(
                isValidState ? Icons.check_circle_rounded : Icons.error_rounded,
                color: isValidState ? const Color(0xFF2D6A4F) : Colors.red.shade600,
                size: 20,
              ),
              const SizedBox(width: 8),
            ],
            if (showVisibilityToggle)
              IconButton(
                icon: Icon(
                  obscureText ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                  color: forestInk.withValues(alpha: 0.5),
                  size: 20,
                ),
                onPressed: onVisibilityToggle,
              ),
          ],
        ),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: softSage.withValues(alpha: 0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: softSage.withValues(alpha: 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: forestInk, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }
}

// ============ Modern Button ============

class _ModernButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isOutlined;
  final Widget? icon;
  final double height;
  final Color? backgroundColor;

  const _ModernButton({
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.isOutlined = false,
    this.icon,
    this.height = 52,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBackground = backgroundColor ?? forestInk;
    final effectiveForeground = isOutlined ? effectiveBackground : linen;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: height,
      decoration: isOutlined
          ? null
          : BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              boxShadow: onPressed != null
                  ? [
                      BoxShadow(
                        color: effectiveBackground.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [],
            ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isOutlined ? Colors.transparent : effectiveBackground,
          foregroundColor: effectiveForeground,
          elevation: 0,
          shadowColor: Colors.transparent,
          side: isOutlined
              ? BorderSide(color: effectiveBackground.withValues(alpha: 0.5), width: 1.5)
              : BorderSide.none,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(horizontal: 20),
        ),
        child: _buildLabel(),
      ),
    );
  }

  Widget _buildLabel() {
    if (isLoading) {
      return SizedBox(
        height: 22,
        width: 22,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: isOutlined ? forestInk : linen,
        ),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[icon!, const SizedBox(width: 8)],
        Text(
          text,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
            color: isOutlined ? forestInk : linen,
          ),
        ),
      ],
    );
  }
}