import '../../utils/constants.dart';
import 'dart:async';
import 'dart:ui' as ui;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../services/weather_service.dart';
import '../widgets/weather_background.dart';





class WeatherPage extends StatefulWidget {
  const WeatherPage({super.key});

  @override
  State<WeatherPage> createState() => _WeatherPageState();
}

class _WeatherPageState extends State<WeatherPage>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  static const _refreshInterval = Duration(hours: 2);
  static const _minGap = Duration(seconds: 20);

  static const _shadows = [Shadow(blurRadius: 12, color: Color(0xAA000000))];

  WeatherData? weather;
  bool isLoading = true;
  String? error;

  Timer? _timer;
  bool _fetching = false;
  bool _reloadAfter = false;
  bool _wasVisible = false;
  DateTime? _lastFetch;

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

    WidgetsBinding.instance.addObserver(this);
    _loadWeather();
    _timer = Timer.periodic(_refreshInterval, (_) => _loadWeather());
  }

  @override
  void dispose() {
    _animationController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _wasVisible) {
      _loadWeather();
    }
  }

  void _onVisibilityChanged(VisibilityInfo info) {
    final visible = info.visibleFraction > 0.5;
    if (visible && !_wasVisible) {
      final last = _lastFetch;
      final stale = last == null || DateTime.now().difference(last) > _minGap;
      if (stale) _loadWeather();
    }
    _wasVisible = visible;
  }

  Future<void> _loadWeather({bool force = false}) async {
    if (!mounted) return;
    if (_fetching) {
      if (force) _reloadAfter = true;
      return;
    }
    _fetching = true;
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      final data = await WeatherService.fetchCurrentWeather();
      if (!mounted) return;
      setState(() {
        weather = data;
        isLoading = false;
      });
      _lastFetch = DateTime.now();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.toString().replaceFirst('Exception: ', '');
        isLoading = false;
      });
    } finally {
      _fetching = false;
      if (_reloadAfter && mounted) {
        _reloadAfter = false;
        _loadWeather();
      }
    }
  }

  Future<void> _openLocationSearch() async {
    final picked = await showModalBottomSheet<PlaceResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _LocationSearchSheet(),
    );
    if (picked == null || !mounted) return;

    await WeatherService.setManualLocation(picked);
    _loadWeather(force: true);
  }

  Future<void> _useGps() async {
    await WeatherService.clearManualLocation();
    _loadWeather(force: true);
  }

  String _recipientName() {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final name = user?.displayName?.trim() ?? '';
      if (name.isNotEmpty) return name;
      return user?.email ?? '';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: const Key('weather-page-visibility'),
      onVisibilityChanged: _onVisibilityChanged,
      child: Container(
        color: linen,
        child: SafeArea(
          bottom: false,
          child: Scaffold(
            extendBodyBehindAppBar: true,
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              title: Text(
                'Weather',
                style: TextStyle(
                  color: forestInk,
                  fontWeight: FontWeight.w700,
                  fontSize: 22,
                  letterSpacing: -0.3,
                  shadows: [Shadow(blurRadius: 4, color: Colors.black.withValues(alpha: 0.1))],
                ),
              ),
              backgroundColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              surfaceTintColor: Colors.transparent,
              foregroundColor: forestInk,
              actions: [
                IconButton(
                  tooltip: 'Enter location',
                  icon: Icon(Icons.edit_location_alt_rounded, shadows: _shadows),
                  onPressed: _openLocationSearch,
                ),
                IconButton(
                  tooltip: 'Refresh',
                  icon: Icon(Icons.refresh_rounded, shadows: _shadows),
                  onPressed: isLoading ? null : _loadWeather,
                ),
              ],
            ),
            body: WeatherBackground(
              weatherCode: weather?.weatherCode ?? 0,
              isDay: weather?.isDay ?? true,
              child: SafeArea(
                child: RefreshIndicator(
                  onRefresh: _loadWeather,
                  color: forestInk,
                  backgroundColor: linen,
                  child: LayoutBuilder(
                    builder: (context, cons) => SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: cons.maxHeight),
                        child: Padding(
                          padding: const EdgeInsets.only(
                              top: kToolbarHeight, left: 16, right: 16, bottom: 24),
                          child: Center(child: _buildContent()),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    final w = weather;

    if (w == null) {
      if (isLoading) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: forestInk),
                const SizedBox(height: 20),
                Text(
                  'Loading weather...',
                  style: TextStyle(
                    color: forestInk.withValues(alpha: 0.6),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      }
      return FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: _glass(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Error: $error',
                  style: TextStyle(color: forestInk, fontSize: 15),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    _ModernButton(
                      text: 'Retry',
                      onPressed: _loadWeather,
                      icon: Icon(Icons.refresh_rounded, size: 18),
                    ),
                    _ModernButton(
                      text: 'Enter location',
                      onPressed: _openLocationSearch,
                      icon: Icon(Icons.edit_location_alt_rounded, size: 18),
                      isOutlined: true,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
      }

    final manual = w.source == LocationSource.manual;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Location title
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.location_on_rounded, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    w.placeName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      shadows: _shadows,
                    ),
                  ),
                ),
              ],
            ),
            if (w.placeDetail.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  w.placeDetail,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    shadows: _shadows,
                  ),
                ),
              ),
            const SizedBox(height: 12),
            _sourceChip(w),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _PillButton(
                  icon: Icons.edit_location_alt_rounded,
                  label: 'Change location',
                  onTap: _openLocationSearch,
                ),
                if (manual)
                  _PillButton(
                    icon: Icons.gps_fixed_rounded,
                    label: 'Use GPS',
                    onTap: _useGps,
                  ),
              ],
            ),

            // Temperature
            const SizedBox(height: 24),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 800),
              curve: Curves.elasticOut,
              builder: (context, scale, child) {
                return Transform.scale(scale: scale, child: child);
              },
              child: Icon(
                w.icon,
                size: 100,
                color: Colors.white,
                shadows: const [Shadow(blurRadius: 24, color: Color(0x66000000))],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${w.temperatureC.round()}°',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 96,
                fontWeight: FontWeight.w200,
                height: 1.05,
                shadows: _shadows,
              ),
            ),
            Text(
              w.description,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w700,
                shadows: _shadows,
              ),
            ),

            // Weather details
            const SizedBox(height: 28),
            _glass(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _InfoTile(icon: Icons.thermostat_rounded, label: 'Feels like', value: '${w.feelsLikeC.round()}°'),
                  _InfoTile(icon: Icons.water_drop_rounded, label: 'Humidity', value: '${w.humidity}%'),
                  _InfoTile(icon: Icons.air_rounded, label: 'Wind', value: '${w.windKmh.round()} km/h'),
                ],
              ),
            ),

            // Address
            const SizedBox(height: 20),
            _addressCard(w),

            // GPS warning
            if (w.locationNote != null) ...[
              const SizedBox(height: 20),
              _glass(
                tint: const Color(0xFF7A4B00),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Colors.amberAccent, size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'GPS could not get your location, so this is only an '
                            'approximate spot.\n${w.locationNote}\n\n'
                            'Tap "Change location" to type your exact place.',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      alignment: WrapAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: isLoading ? null : _loadWeather,
                          icon: const Icon(Icons.gps_fixed_rounded, size: 18),
                          label: const Text('Try GPS again'),
                          style: TextButton.styleFrom(foregroundColor: Colors.white),
                        ),
                        _ModernButton(
                          text: 'Change location',
                          onPressed: _openLocationSearch,
                          icon: Icon(Icons.edit_location_alt_rounded, size: 18),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],

            // Footer
            const SizedBox(height: 22),
            Text(
              'Updated ${DateFormat('h:mm a').format(w.updatedAt)} · refreshes when you open this screen',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                shadows: _shadows,
              ),
            ),
            if (isLoading)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                ),
              ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  "Couldn't refresh: $error",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    shadows: _shadows,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _addressCard(WeatherData w) {
    final a = w.address;
    final recipient = _recipientName();
    final showBarangay = a.barangay.isNotEmpty ||
        a.country.isEmpty ||
        a.country.toLowerCase() == 'philippines';

    final rows = <(String, String)>[
      ('Recipient Name', recipient),
      ('Building / Unit No.', a.buildingUnit),
      ('Street Name', a.street),
      if (showBarangay) ('Barangay', a.barangay),
      ('Neighborhood / District', a.neighborhood),
      ('City / Municipality', a.city),
      ('State / Province', a.province),
      ('Postal Code', a.postalCode),
      ('Country', a.country),
    ];

    return _glass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: forestInk.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.home_outlined, color: forestInk, size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Current address',
                  style: TextStyle(
                    color: forestInk,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Copy address',
                icon: Icon(Icons.copy_rounded, color: forestInk, size: 20),
                onPressed: () {
                  final text = [
                    if (recipient.isNotEmpty) recipient,
                    if (a.formatted.isNotEmpty) a.formatted,
                  ].join('\n');
                  Clipboard.setData(ClipboardData(text: text));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Address copied'),
                      backgroundColor: forestInk,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  );
                },
              ),
            ],
          ),
          if (w.source == LocationSource.ip)
            const Padding(
              padding: EdgeInsets.only(bottom: 8, top: 8),
              child: Text(
                'Only city-level details are available without GPS.',
                style: TextStyle(color: Colors.amberAccent, fontSize: 13),
              ),
            ),
          const SizedBox(height: 8),
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0)
              Divider(height: 1, color: softSage.withValues(alpha: 0.15)),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 5,
                    child: Text(
                      rows[i].$1,
                      style: TextStyle(
                        color: forestInk.withValues(alpha: 0.6),
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 6,
                    child: Text(
                      rows[i].$2.isEmpty ? '—' : rows[i].$2,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: rows[i].$2.isEmpty ? forestInk.withValues(alpha: 0.4) : forestInk,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sourceChip(WeatherData w) {
    IconData icon;
    String label;
    Color color;
    switch (w.source) {
      case LocationSource.gps:
        icon = Icons.gps_fixed_rounded;
        label = 'GPS · precise';
        color = const Color(0xFF2D6A4F);
        break;
      case LocationSource.manual:
        icon = Icons.edit_location_alt_rounded;
        label = 'Location you entered';
        color = const Color(0xFF40916C);
        break;
      case LocationSource.ip:
        icon = Icons.public_rounded;
        label = 'Approximate · from IP';
        color = const Color(0xFF52796F);
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _glass({required Widget child, Color tint = Colors.black}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: tint.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.30)),
          ),
          child: child,
        ),
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

  const _ModernButton({
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.isOutlined = false,
    this.icon,
    this.height = 52,
  });

  @override
  Widget build(BuildContext context) {
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
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [],
            ),
    child: ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: isOutlined ? Colors.transparent : Colors.white,
        foregroundColor: isOutlined ? Colors.white : forestInk,
        elevation: 0,
        shadowColor: Colors.transparent,
        side: isOutlined ? BorderSide(color: Colors.white.withValues(alpha: 0.5), width: 1.5) : BorderSide.none,
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
          color: isOutlined ? Colors.white : forestInk,
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
            color: isOutlined ? Colors.white : forestInk,
          ),
        ),
      ],
    );
  }
}

// ============ Pill Button ============

class _PillButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _PillButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(Radius.circular(24)),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============ Info Tile ============

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.85),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Bottom sheet: type a place, pick a result
// -----------------------------------------------------------------------------

class _LocationSearchSheet extends StatefulWidget {
  const _LocationSearchSheet();

  @override
  State<_LocationSearchSheet> createState() => _LocationSearchSheetState();
}

class _LocationSearchSheetState extends State<_LocationSearchSheet>
    with SingleTickerProviderStateMixin {
  final _controller = TextEditingController();
  List<PlaceResult> _results = [];
  bool _loading = false;
  bool _searched = false;
  String? _error;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _controller.text.trim();
    if (q.length < 3) {
      setState(() => _error = 'Type at least 3 characters.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await WeatherService.searchPlaces(q);
      if (!mounted) return;
      setState(() {
        _results = r;
        _searched = true;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.of(context).viewInsets.bottom;
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Padding(
          padding: EdgeInsets.only(bottom: inset),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.75,
            decoration: BoxDecoration(
              color: linen,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border.all(color: softSage.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
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
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                  child: Text(
                    'Enter your location',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: forestInk,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: Text(
                    'Include the barangay, city and province for best results, '
                    'e.g. "Brgy. San Roque, Antipolo, Rizal".',
                    style: TextStyle(
                      fontSize: 14,
                      color: forestInk.withValues(alpha: 0.5),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: TextField(
                    controller: _controller,
                    autofocus: true,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _search(),
                    decoration: InputDecoration(
                      hintText: 'Barangay, city, province',
                      prefixIcon: Icon(Icons.search_rounded, color: softSage),
                      suffixIcon: IconButton(
                        icon: Icon(Icons.arrow_forward_rounded, color: forestInk),
                        onPressed: _loading ? null : _search,
                      ),
                      filled: true,
                      fillColor: linen,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: softSage.withValues(alpha: 0.3)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: forestInk, width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                    ),
                  ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    child: Text(
                      _error!,
                      style: TextStyle(color: Colors.red.shade600, fontSize: 14),
                    ),
                  ),
                const SizedBox(height: 12),
                Expanded(
                  child: _loading
                      ? Center(
                          child: CircularProgressIndicator(color: forestInk),
                        )
                      : (_searched && _results.isEmpty)
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  children: [
                                    Icon(Icons.location_off_rounded, size: 48, color: softSage),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No places found',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        color: forestInk,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Try adding the city or province, or simplify the name.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: forestInk.withValues(alpha: 0.5),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              itemCount: _results.length,
                              separatorBuilder: (_, __) => Divider(
                                height: 1,
                                color: softSage.withValues(alpha: 0.1),
                              ),
                              itemBuilder: (context, i) {
                                final r = _results[i];
                                return Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () => Navigator.of(context).pop(r),
                                    borderRadius: BorderRadius.circular(16),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: forestInk.withValues(alpha: 0.08),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Icon(Icons.place_outlined, color: forestInk, size: 22),
                                          ),
                                          const SizedBox(width: 14),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  r.title,
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w600,
                                                    color: forestInk,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  r.displayName,
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
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
                              },
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