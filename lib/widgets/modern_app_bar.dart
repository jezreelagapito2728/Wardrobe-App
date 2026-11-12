/// Reusable Modern App Bar with consistent styling

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/constants.dart';

class ModernAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool centerTitle;
  final double elevation;
  final Color? backgroundColor;
  final Color? surfaceTintColor;
  final PreferredSizeWidget? bottom;
  final double toolbarHeight;
  final TextStyle? titleStyle;
  final bool automaticallyImplyLeading;

  const ModernAppBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
    this.centerTitle = false,
    this.elevation = 0,
    this.backgroundColor,
    this.surfaceTintColor,
    this.bottom,
    this.toolbarHeight = kToolbarHeight,
    this.titleStyle,
    this.automaticallyImplyLeading = true,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBackgroundColor = backgroundColor ?? linen;
    final effectiveSurfaceTintColor = surfaceTintColor ?? Colors.transparent;
    final effectiveTitleStyle = titleStyle ?? TextStyle(
      color: forestInk,
      fontWeight: FontWeight.w700,
      fontSize: 28,
      letterSpacing: -0.5,
    );

    return AppBar(
      title: Text(title, style: effectiveTitleStyle),
      centerTitle: centerTitle,
      elevation: elevation,
      backgroundColor: effectiveBackgroundColor,
      surfaceTintColor: effectiveSurfaceTintColor,
      leading: leading,
      automaticallyImplyLeading: automaticallyImplyLeading,
      actions: actions,
      bottom: bottom,
      toolbarHeight: toolbarHeight,
      scrolledUnderElevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: effectiveBackgroundColor,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(toolbarHeight + (bottom?.preferredSize.height ?? 0));
}

// Sliver version for CustomScrollView
class ModernSliverAppBar extends StatelessWidget {
  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool centerTitle;
  final double elevation;
  final Color? backgroundColor;
  final Color? surfaceTintColor;
  final double expandedHeight;
  final Widget? flexibleSpace;
  final TextStyle? titleStyle;
  final bool automaticallyImplyLeading;
  final bool floating;
  final bool snap;

  const ModernSliverAppBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
    this.centerTitle = false,
    this.elevation = 0,
    this.backgroundColor,
    this.surfaceTintColor,
    this.expandedHeight = 0,
    this.flexibleSpace,
    this.titleStyle,
    this.automaticallyImplyLeading = true,
    this.floating = false,
    this.snap = false,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBackgroundColor = backgroundColor ?? linen;
    final effectiveSurfaceTintColor = surfaceTintColor ?? Colors.transparent;
    final effectiveTitleStyle = titleStyle ?? TextStyle(
      color: forestInk,
      fontWeight: FontWeight.w700,
      fontSize: 28,
      letterSpacing: -0.5,
    );

    return SliverAppBar(
      title: Text(title, style: effectiveTitleStyle),
      centerTitle: centerTitle,
      elevation: elevation,
      backgroundColor: effectiveBackgroundColor,
      surfaceTintColor: effectiveSurfaceTintColor,
      leading: leading,
      automaticallyImplyLeading: automaticallyImplyLeading,
      actions: actions,
      expandedHeight: expandedHeight,
      flexibleSpace: flexibleSpace,
      floating: floating,
      snap: snap,
      scrolledUnderElevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: effectiveBackgroundColor,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
    );
  }
}

// Modern button styles
class ModernButtonStyles {
  static ElevatedButtonThemeData get elevatedButtonTheme => ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: forestInk,
      foregroundColor: linen,
      elevation: 0,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      textStyle: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    ),
  );

  static OutlinedButtonThemeData get outlinedButtonTheme => OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: forestInk,
      side: BorderSide(color: softSage, width: 2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      textStyle: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    ),
  );

  static TextButtonThemeData get textButtonTheme => TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: forestInk,
      textStyle: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
    ),
  );

  // Individual button styles
  static ButtonStyle get primaryElevated => ElevatedButton.styleFrom(
    backgroundColor: forestInk,
    foregroundColor: linen,
    elevation: 0,
    shadowColor: Colors.transparent,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
  );

  static ButtonStyle get secondaryElevated => ElevatedButton.styleFrom(
    backgroundColor: softSage,
    foregroundColor: forestInk,
    elevation: 0,
    shadowColor: Colors.transparent,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
  );

  static ButtonStyle get outlined => OutlinedButton.styleFrom(
    foregroundColor: forestInk,
    side: BorderSide(color: softSage, width: 2),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
  );

  static ButtonStyle get text => TextButton.styleFrom(
    foregroundColor: forestInk,
    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
  );

  static ButtonStyle get destructive => ElevatedButton.styleFrom(
    backgroundColor: errorRed,
    foregroundColor: linen,
    elevation: 0,
    shadowColor: Colors.transparent,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
  );
}

// Modern Card
class ModernCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final List<BoxShadow>? boxShadow;
  final BorderRadius? borderRadius;
  final Border? border;
  final VoidCallback? onTap;
  final bool isInteractive;

  const ModernCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.margin,
    this.color,
    this.boxShadow,
    this.borderRadius,
    this.border,
    this.onTap,
    this.isInteractive = false,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? linen;
    final effectiveBorderRadius = borderRadius ?? BorderRadius.circular(20);
    final effectiveBorder = border ?? Border.all(color: softSage.withValues(alpha: 0.2));
    final effectiveShadow = boxShadow ?? [
      BoxShadow(
        color: forestInk.withValues(alpha: 0.04),
        blurRadius: 12,
        offset: const Offset(0, 4),
      ),
    ];

    Widget card = Container(
      padding: padding,
      margin: margin,
      decoration: BoxDecoration(
        color: effectiveColor,
        borderRadius: effectiveBorderRadius,
        border: effectiveBorder,
        boxShadow: effectiveShadow,
      ),
      child: child,
    );

    if (isInteractive && onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: effectiveBorderRadius,
          child: card,
        ),
      );
    }

    return card;
  }
}

// Modern Input Field
class ModernTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? labelText;
  final String? hintText;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;
  final void Function(String?)? onChanged;
  final void Function()? onTap;
  final bool readOnly;
  final int? maxLines;
  final TextCapitalization textCapitalization;
  final TextInputAction? textInputAction;

  const ModernTextField({
    super.key,
    this.controller,
    this.labelText,
    this.hintText,
    this.keyboardType,
    this.obscureText = false,
    this.prefixIcon,
    this.suffixIcon,
    this.validator,
    this.onChanged,
    this.onTap,
    this.readOnly = false,
    this.maxLines = 1,
    this.textCapitalization = TextCapitalization.none,
    this.textInputAction,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      onChanged: onChanged,
      onTap: onTap,
      readOnly: readOnly,
      maxLines: maxLines,
      textCapitalization: textCapitalization,
      textInputAction: textInputAction,
      style: TextStyle(fontSize: 16, color: forestInk),
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        labelStyle: TextStyle(color: forestInk.withValues(alpha: 0.6)),
        hintStyle: TextStyle(color: forestInk.withValues(alpha: 0.4)),
        prefixIcon: prefixIcon != null ? IconTheme(data: IconThemeData(color: softSage, size: 22), child: prefixIcon!) : null,
        suffixIcon: suffixIcon,
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
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: errorRed, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: errorRed, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }
}

// Modern Dropdown
class ModernDropdown<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final IconData? prefixIcon;
  final String? Function(T?)? validator;

  const ModernDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.prefixIcon,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      value: value,
      onChanged: onChanged,
      validator: validator,
      style: TextStyle(fontSize: 16, color: forestInk),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: forestInk.withValues(alpha: 0.6)),
        prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: softSage, size: 22) : null,
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
      items: items,
      dropdownColor: linen,
      borderRadius: BorderRadius.circular(16),
      icon: Icon(Icons.keyboard_arrow_down_rounded, color: softSage),
    );
  }
}

// Animated Action Button
class AnimatedActionButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;
  final Color? backgroundColor;
  final Color? foregroundColor;

  const AnimatedActionButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.backgroundColor,
    this.foregroundColor,
  });

  @override
  State<AnimatedActionButton> createState() => _AnimatedActionButtonState();
}

class _AnimatedActionButtonState extends State<AnimatedActionButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.85).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: GestureDetector(
        onTapDown: (_) => _controller.forward(),
        onTapUp: (_) => _controller.reverse(),
        onTapCancel: () => _controller.reverse(),
        onTap: widget.onPressed,
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: widget.backgroundColor ?? forestInk.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: softSage.withValues(alpha: 0.2)),
                ),
                child: IconButton(
                  icon: Icon(widget.icon, color: widget.foregroundColor ?? forestInk, size: 24),
                  onPressed: widget.onPressed,
                  tooltip: widget.tooltip,
                  padding: const EdgeInsets.all(10),
                  constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}