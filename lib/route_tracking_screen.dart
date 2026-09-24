import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'main.dart'; // AppColors, ActivityProvider
import 'database_helper.dart'; // ActivityModel

class RouteTrackingScreen extends StatefulWidget {
  const RouteTrackingScreen({super.key});

  @override
  State<RouteTrackingScreen> createState() => _RouteTrackingScreenState();
}

class _RouteTrackingScreenState extends State<RouteTrackingScreen>
    with TickerProviderStateMixin {
  final MapController _mapController = MapController();

  bool _mapReady = false;

  // Route & GPS variables
  final List<LatLng> _routePoints = [];
  StreamSubscription<Position>? _positionStream;
  LatLng? _currentLocation;
  LatLng? _displayLocation; // For smooth marker glide
  LatLng? _startLocation;
  DateTime? _lastValidPointTime; // Anti-teleportation time check

  // Status variables
  bool _isTracking = false;
  bool _isPaused = false;
  bool _isLoadingInitialLocation = true;
  String? _errorMessage;

  // Live Metrics
  Timer? _timer;
  int _secondsElapsed = 0;
  double _distanceInMeters = 0.0;
  double _currentSpeedKmH = 0.0;

  // 🌟 ANIMATION CONTROLLERS
  late AnimationController _pulseController;
  late AnimationController _markerGlideController;
  AnimationController? _cameraGlideController;
  LatLng? _glideStartPoint;
  LatLng? _glideEndPoint;

  @override
  void initState() {
    super.initState();

    // 1. Radar Wave Pulse Animation (Continuous 1.8s loop)
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    // 2. Smooth Marker Glide Controller (600ms easeOut glide)
    _markerGlideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _markerGlideController.addListener(() {
      if (_glideStartPoint != null && _glideEndPoint != null && mounted) {
        final t = Curves.easeOut.transform(_markerGlideController.value);
        final lat =
            _glideStartPoint!.latitude +
            (_glideEndPoint!.latitude - _glideStartPoint!.latitude) * t;
        final lng =
            _glideStartPoint!.longitude +
            (_glideEndPoint!.longitude - _glideStartPoint!.longitude) * t;

        setState(() {
          _displayLocation = LatLng(lat, lng);
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _positionStream?.cancel();
    _pulseController.dispose();
    _markerGlideController.dispose();
    _cameraGlideController?.dispose();
    super.dispose();
  }

  // 🚀 SMOOTH CAMERA GLIDE FUNCTION (No sudden jumps)
  void _animatedMapMove(LatLng destLocation, double destZoom) {
    if (!_mapReady || !mounted) return;

    _cameraGlideController?.dispose();
    _cameraGlideController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );

    final latTween = Tween<double>(
      begin: _mapController.camera.center.latitude,
      end: destLocation.latitude,
    );
    final lngTween = Tween<double>(
      begin: _mapController.camera.center.longitude,
      end: destLocation.longitude,
    );
    final zoomTween = Tween<double>(
      begin: _mapController.camera.zoom,
      end: destZoom,
    );

    final curved = CurvedAnimation(
      parent: _cameraGlideController!,
      curve: Curves.fastOutSlowIn,
    );

    _cameraGlideController!.addListener(() {
      if (_mapReady && mounted) {
        _mapController.move(
          LatLng(latTween.evaluate(curved), lngTween.evaluate(curved)),
          zoomTween.evaluate(curved),
        );
      }
    });

    _cameraGlideController!.forward();
  }

  // 🏃 SMOOTH MARKER GLIDE FUNCTION (Interpolates coordinates)
  void _smoothMoveMarker(LatLng newPoint) {
    if (_currentLocation == null) {
      _currentLocation = newPoint;
      _displayLocation = newPoint;
      return;
    }

    _markerGlideController.stop();
    _markerGlideController.reset();

    _glideStartPoint = _displayLocation ?? _currentLocation!;
    _glideEndPoint = newPoint;
    _currentLocation = newPoint;

    _markerGlideController.forward();
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          setState(() {
            _errorMessage = 'Please enable GPS/Location in phone settings.';
            _isLoadingInitialLocation = false;
          });
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            setState(() {
              _errorMessage =
                  'Location permission is required to track routes.';
              _isLoadingInitialLocation = false;
            });
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _errorMessage =
                'Location permissions are permanently denied. Please enable them from App Settings.';
            _isLoadingInitialLocation = false;
          });
        }
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
      );

      final latLng = LatLng(position.latitude, position.longitude);

      if (mounted) {
        setState(() {
          _currentLocation = latLng;
          _displayLocation = latLng;
          _isLoadingInitialLocation = false;
          _errorMessage = null;
        });

        if (_mapReady) {
          _animatedMapMove(latLng, 16.5);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to get GPS location. Error: $e';
          _isLoadingInitialLocation = false;
        });
      }
    }
  }

  // 🛡️ SMART FILTERED TRACKING FUNCTION
  void _startTracking() {
    if (_currentLocation == null) return;

    setState(() {
      _isTracking = true;
      _isPaused = false;
      _startLocation = _currentLocation;
      _routePoints.clear();
      _distanceInMeters = 0.0;
      _secondsElapsed = 0;
      _lastValidPointTime = null;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isPaused && mounted) {
        setState(() {
          _secondsElapsed++;
        });
      }
    });

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 3, // Real 3 meter movement
    );

    _positionStream =
        Geolocator.getPositionStream(
          locationSettings: locationSettings,
        ).listen((Position position) {
          if (_isPaused || !mounted) return;

          // 🛡️ FILTER 1: Weak / Poor Satellite Accuracy Reject Karein
          // Agar accuracy 22 meters se zyada kharab ho to point reject
          if (position.accuracy > 22.0) {
            return;
          }

          final newPoint = LatLng(position.latitude, position.longitude);
          final now = DateTime.now();

          if (_routePoints.isNotEmpty) {
            final lastPoint = _routePoints.last;
            final addedDistance = Geolocator.distanceBetween(
              lastPoint.latitude,
              lastPoint.longitude,
              newPoint.latitude,
              newPoint.longitude,
            );

            // 🛡️ FILTER 2: GPS Jitter / Stationary Drift Reject (< 3.0 meters)
            if (addedDistance < 3.0) {
              return;
            }

            // 🛡️ FILTER 3: Impossible Teleportation Jump Check
            if (_lastValidPointTime != null) {
              final timeDiffSeconds =
                  now.difference(_lastValidPointTime!).inMilliseconds / 1000.0;
              if (timeDiffSeconds > 0) {
                final calculatedSpeedKmH =
                    (addedDistance / timeDiffSeconds) * 3.6;
                // Agar speed 100 km/h se zyada achanak jump kare to glitch hai
                if (calculatedSpeedKmH > 100.0) {
                  return; // Ignore fake sudden jump!
                }
              }
            }

            _distanceInMeters += addedDistance;
          } else {
            // Pehla accurate point start location banega
            _startLocation = newPoint;
          }

          _lastValidPointTime = now;

          setState(() {
            _routePoints.add(newPoint);
            // Agar movement bohot slow ho (< 0.5 m/s) to speed 0 dikhaye
            _currentSpeedKmH = position.speed < 0.5
                ? 0.0
                : (position.speed * 3.6).clamp(0.0, 99.0);
          });

          // Smooth marker animation & Smooth camera tracking
          _smoothMoveMarker(newPoint);
          _animatedMapMove(newPoint, _mapController.camera.zoom);
        });
  }

  void _togglePause() {
    setState(() {
      _isPaused = !_isPaused;
    });
  }

  // 💾 SQLite Database mein save aur dialog dikhana
  Future<void> _finishTracking() async {
    _timer?.cancel();
    _positionStream?.cancel();

    final km = _distanceInMeters / 1000;
    final calories = (km * 60).round();
    final estimatedSteps = (_distanceInMeters / 0.75).round();

    try {
      final acts = Provider.of<ActivityProvider>(context, listen: false);
      final now = DateTime.now();
      final newWorkout = ActivityModel(
        activityType: 'Outdoor Run',
        duration: _secondsElapsed,
        steps: estimatedSteps,
        calories: calories.toDouble(),
        date: now.toIso8601String().split('T')[0],
        createdAt: now.toIso8601String(),
      );
      await acts.addActivity(newWorkout);
    } catch (e) {
      debugPrint('Workout save error: $e');
    }

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161F1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              Icons.emoji_events_rounded,
              color: AppColors.splashLime,
              size: 28,
            ),
            const SizedBox(width: 10),
            const Flexible(
              child: Text(
                'Workout Complete!',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDialogStat('Total Distance:', '${km.toStringAsFixed(2)} km'),
            const SizedBox(height: 8),
            _buildDialogStat('Duration:', _formatDuration(_secondsElapsed)),
            const SizedBox(height: 8),
            _buildDialogStat('Calories Burned:', '$calories kcal'),
            const SizedBox(height: 8),
            _buildDialogStat(
              'Route Points:',
              '${_routePoints.length} GPS points',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: Text(
              'Done',
              style: TextStyle(
                color: AppColors.splashLime,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogStat(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  String _formatDuration(int totalSeconds) {
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final km = (_distanceInMeters / 1000).toStringAsFixed(2);
    final calories = ((_distanceInMeters / 1000) * 60).round();
    final activeLoc = _displayLocation ?? _currentLocation;

    return Scaffold(
      backgroundColor: const Color(0xFF0D1411),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(0, 0),
              initialZoom: 16.5,
              onMapReady: () {
                _mapReady = true;
                _getCurrentLocation();
              },
            ),
            children: [
              // Dark Inverted OpenStreetMap Tiles
              ColorFiltered(
                colorFilter: const ColorFilter.matrix(<double>[
                  -0.75,
                  0.0,
                  0.0,
                  0.0,
                  210.0,
                  0.0,
                  -0.75,
                  0.0,
                  0.0,
                  210.0,
                  0.0,
                  0.0,
                  -0.75,
                  0.0,
                  210.0,
                  0.0,
                  0.0,
                  0.0,
                  1.0,
                  0.0,
                ]),
                child: TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.fittrack',
                ),
              ),

              // Live Neon Green Polyline
              if (_routePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routePoints,
                      strokeWidth: 5.0,
                      color: AppColors.splashLime,
                    ),
                  ],
                ),

              // 📍 Markers Layer with Radar Pulse Wave
              MarkerLayer(
                markers: [
                  // Start Pin
                  if (_startLocation != null)
                    Marker(
                      point: _startLocation!,
                      width: 40,
                      height: 40,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.splashLime,
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          Icons.flag_rounded,
                          color: AppColors.splashLime,
                          size: 20,
                        ),
                      ),
                    ),

                  // 🌊 Live Location Marker with Glowing Radar Pulse Wave
                  if (activeLoc != null)
                    Marker(
                      point: activeLoc,
                      width: 60,
                      height: 60,
                      child: AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          final progress = _pulseController.value;
                          return Stack(
                            alignment: Alignment.center,
                            children: [
                              // Expanding Radar Ring (Smooth Wave)
                              Transform.scale(
                                scale: 1.0 + (progress * 1.5),
                                child: Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.splashLime.withValues(
                                      alpha: (1.0 - progress).clamp(0.0, 0.35),
                                    ),
                                    border: Border.all(
                                      color: AppColors.splashLime.withValues(
                                        alpha: (1.0 - progress).clamp(0.0, 0.6),
                                      ),
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                              ),

                              // Inner Glowing Core Dot
                              Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: AppColors.splashLime,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.splashLime.withValues(
                                        alpha: 0.6,
                                      ),
                                      blurRadius: 14,
                                      spreadRadius: 3,
                                    ),
                                  ],
                                  border: Border.all(
                                    color: Colors.black,
                                    width: 3,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                ],
              ),
            ],
          ),

          // Loading Overlay
          if (_isLoadingInitialLocation)
            Container(
              color: Colors.black54,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: AppColors.splashLime),
                    const SizedBox(height: 16),
                    const Text(
                      'Getting GPS location...',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Error Overlay
          if (_errorMessage != null && !_isLoadingInitialLocation)
            Container(
              color: Colors.black87,
              padding: const EdgeInsets.all(28),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.location_off_rounded,
                      color: Colors.redAccent,
                      size: 54,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 22),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.splashLime,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                      onPressed: () {
                        setState(() {
                          _isLoadingInitialLocation = true;
                          _errorMessage = null;
                        });
                        _getCurrentLocation();
                      },
                      child: const Text(
                        'Retry GPS',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Top Bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Semantics(
                    label: 'Back',
                    button: true,
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF161F1A,
                          ).withValues(alpha: 0.85),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white10),
                        ),
                        child: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF161F1A).withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isTracking && !_isPaused
                                ? AppColors.splashLime
                                : Colors.amber,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isTracking
                              ? (_isPaused ? 'PAUSED' : 'TRACKING ROUTE')
                              : 'GPS READY',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Recenter Button with Smooth Glide
                  Semantics(
                    label: 'Recenter to current location',
                    button: true,
                    child: GestureDetector(
                      onTap: () {
                        if (_mapReady && activeLoc != null) {
                          _animatedMapMove(activeLoc, 17.0);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF161F1A,
                          ).withValues(alpha: 0.85),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Icon(
                          Icons.my_location_rounded,
                          color: AppColors.splashLime,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Floating HUD
          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF161F1A).withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 25,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildMetricItem(km, 'KM', 'Distance'),
                      _buildDivider(),
                      _buildMetricItem(
                        _formatDuration(_secondsElapsed),
                        'MIN',
                        'Duration',
                      ),
                      _buildDivider(),
                      _buildMetricItem(
                        _currentSpeedKmH.toStringAsFixed(1),
                        'KM/H',
                        'Speed',
                      ),
                      _buildDivider(),
                      _buildMetricItem('$calories', 'KCAL', 'Burned'),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (!_isTracking)
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.splashLime,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          elevation: 0,
                        ),
                        onPressed: _isLoadingInitialLocation
                            ? null
                            : _startTracking,
                        icon: const Icon(Icons.play_arrow_rounded, size: 28),
                        label: const Text(
                          'START RUN / WALK',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 54,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                  color: AppColors.splashLime,
                                  width: 1.5,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                              onPressed: _togglePause,
                              icon: Icon(
                                _isPaused
                                    ? Icons.play_arrow_rounded
                                    : Icons.pause_rounded,
                                color: AppColors.splashLime,
                              ),
                              label: Text(
                                _isPaused ? 'RESUME' : 'PAUSE',
                                style: TextStyle(
                                  color: AppColors.splashLime,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: SizedBox(
                            height: 54,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.redAccent,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                              onPressed: _finishTracking,
                              icon: const Icon(Icons.stop_rounded, size: 24),
                              label: const Text(
                                'FINISH',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricItem(String value, String unit, String label) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(width: 2),
            Text(
              unit,
              style: TextStyle(
                color: AppColors.splashLime,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(width: 1, height: 24, color: Colors.white12);
  }
}
