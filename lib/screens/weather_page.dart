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
    with WidgetsBindingObserver {
  static const _refreshInterval = Duration(hours: 2);
  // Don't re-fetch if we fetched less than this long ago (avoids spamming
  // the APIs when the user flips between tabs quickly).
  static const _minGap = Duration(seconds: 20);

  // Strong shadow + white text so everything stays readable on any sky.
  static const _shadows = [Shadow(blurRadius: 12, color: Color(0xAA000000))];

  WeatherData? weather;
  bool isLoading = true;
  String? error;

  Timer? _timer;
  bool _fetching = false;
  bool _reloadAfter = false;
  bool _wasVisible = false;
  DateTime? _lastFetch;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadWeather(); // refresh every time the page is opened
    _timer = Timer.periodic(_refreshInterval, (_) => _loadWeather());
  }

  @override
  void dispose() {
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
      // A request is already running; if the caller needs fresh data (e.g.
      // the location just changed) run once more when it finishes.
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

  // ---------------------------------------------------------------------------
  // Manual location
  // ---------------------------------------------------------------------------
  Future<void> _openLocationSearch() async {
    final picked = await showModalBottomSheet<PlaceResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
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

  /// Recipient name comes from the signed-in account, not from the map.
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

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: const Key('weather-page-visibility'),
      onVisibilityChanged: _onVisibilityChanged,
      child: Container(
        color: Theme.of(context).appBarTheme.backgroundColor,
        child: SafeArea(
          bottom: false,
          child: Scaffold(
            extendBodyBehindAppBar: true,
            appBar: AppBar(
              title: const Text('Weather', style: TextStyle(shadows: _shadows)),
              backgroundColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              foregroundColor: Colors.white,
              actions: [
                IconButton(
                  tooltip: 'Enter location',
                  icon: const Icon(Icons.edit_location_alt, shadows: _shadows),
                  onPressed: _openLocationSearch,
                ),
                IconButton(
                  tooltip: 'Refresh',
                  icon: const Icon(Icons.refresh, shadows: _shadows),
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
        return const CircularProgressIndicator(color: Colors.white);
      }
      return _glass(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Error: $error',
              style: const TextStyle(color: Colors.white, fontSize: 15),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _loadWeather,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
                ElevatedButton.icon(
                  onPressed: _openLocationSearch,
                  icon: const Icon(Icons.edit_location_alt),
                  label: const Text('Enter location'),
                ),
              ],
            ),
          ],
        ),
      );
    }

    final manual = w.source == LocationSource.manual;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ---- Location title
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.location_on, color: Colors.white, shadows: _shadows),
            const SizedBox(width: 4),
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
            padding: const EdgeInsets.only(top: 4),
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
        const SizedBox(height: 10),
        _sourceChip(w),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            _pill(Icons.edit_location_alt, 'Change location', _openLocationSearch),
            if (manual) _pill(Icons.gps_fixed, 'Use GPS', _useGps),
          ],
        ),

        // ---- Temperature
        const SizedBox(height: 20),
        Icon(
          w.icon,
          size: 96,
          color: Colors.white,
          shadows: const [Shadow(blurRadius: 24, color: Color(0x66000000))],
        ),
        Text(
          '${w.temperatureC.round()}°',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 92,
            fontWeight: FontWeight.w300,
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

        // ---- Weather details
        const SizedBox(height: 24),
        _glass(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _infoTile(Icons.thermostat, 'Feels like', '${w.feelsLikeC.round()}°'),
              _infoTile(Icons.water_drop_outlined, 'Humidity', '${w.humidity}%'),
              _infoTile(Icons.air, 'Wind', '${w.windKmh.round()} km/h'),
            ],
          ),
        ),

        // ---- Address
        const SizedBox(height: 16),
        _addressCard(w),

        // ---- GPS warning
        if (w.locationNote != null) ...[
          const SizedBox(height: 16),
          _glass(
            tint: const Color(0xFF7A4B00),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: Colors.amberAccent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'GPS could not get your location, so this is only an '
                        'approximate spot.\n${w.locationNote}\n\n'
                        'Tap "Enter location" to type your exact place.',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  alignment: WrapAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: isLoading ? null : _loadWeather,
                      icon: const Icon(Icons.gps_fixed, size: 18),
                      label: const Text('Try GPS again'),
                      style: TextButton.styleFrom(foregroundColor: Colors.white),
                    ),
                    FilledButton.icon(
                      onPressed: _openLocationSearch,
                      icon: const Icon(Icons.edit_location_alt, size: 18),
                      label: const Text('Enter location'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],

        // ---- Footer
        const SizedBox(height: 18),
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
            padding: EdgeInsets.only(top: 12),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
          ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
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
    );
  }

  // ---------------------------------------------------------------------------
  // Address card
  // ---------------------------------------------------------------------------
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
              const Icon(Icons.home_outlined, color: Colors.white),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Current address',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Copy address',
                icon: const Icon(Icons.copy, color: Colors.white, size: 20),
                onPressed: () {
                  final text = [
                    if (recipient.isNotEmpty) recipient,
                    if (a.formatted.isNotEmpty) a.formatted,
                  ].join('\n');
                  Clipboard.setData(ClipboardData(text: text));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Address copied')),
                  );
                },
              ),
            ],
          ),
          if (w.source == LocationSource.ip)
            const Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: Text(
                'Only city-level details are available without GPS.',
                style: TextStyle(color: Colors.amberAccent, fontSize: 13),
              ),
            ),
          const SizedBox(height: 4),
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0)
              Divider(height: 1, color: Colors.white.withValues(alpha: 0.18)),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 5,
                    child: Text(
                      rows[i].$1,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.78),
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
                        color: rows[i].$2.isEmpty ? Colors.white54 : Colors.white,
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

  // ---------------------------------------------------------------------------
  // Small widgets
  // ---------------------------------------------------------------------------
  Widget _sourceChip(WeatherData w) {
    IconData icon;
    String label;
    switch (w.source) {
      case LocationSource.gps:
        icon = Icons.gps_fixed;
        label = 'GPS · precise';
        break;
      case LocationSource.manual:
        icon = Icons.edit_location_alt;
        label = 'Location you entered';
        break;
      case LocationSource.ip:
        icon = Icons.public;
        label = 'Approximate · from IP';
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Colors.white),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _pill(IconData icon, String label, VoidCallback onTap) {
    return Material(
      color: Colors.black.withValues(alpha: 0.45),
      shape: StadiumBorder(
        side: BorderSide(color: Colors.white.withValues(alpha: 0.4)),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: Colors.white),
              const SizedBox(width: 6),
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

  /// Dark frosted-glass container: readable on bright and dark skies alike.
  Widget _glass({required Widget child, Color tint = Colors.black}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: tint.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withValues(alpha: 0.30)),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _infoTile(IconData icon, String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white, size: 28),
        const SizedBox(height: 6),
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
            fontSize: 13,
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

class _LocationSearchSheetState extends State<_LocationSearchSheet> {
  final _controller = TextEditingController();
  List<PlaceResult> _results = [];
  bool _loading = false;
  bool _searched = false;
  String? _error;

  @override
  void dispose() {
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
    return Padding(
      padding: EdgeInsets.only(bottom: inset),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Text(
                'Enter your location',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                'Include the barangay, city and province for best results, '
                'e.g. "Brgy. San Roque, Antipolo, Rizal".',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _controller,
                autofocus: true,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _search(),
                decoration: InputDecoration(
                  hintText: 'Barangay, city, province',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.arrow_forward),
                    onPressed: _loading ? null : _search,
                  ),
                ),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : (_searched && _results.isEmpty)
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'No places found. Try adding the city or province, '
                              'or simplify the name.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : ListView.separated(
                          itemCount: _results.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, i) {
                            final r = _results[i];
                            return ListTile(
                              leading: const Icon(Icons.place_outlined),
                              title: Text(r.title),
                              subtitle: Text(
                                r.displayName,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onTap: () => Navigator.of(context).pop(r),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}