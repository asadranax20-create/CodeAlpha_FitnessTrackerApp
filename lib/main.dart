import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'route_tracking_screen.dart';

import 'database_helper.dart';

// ============================================================================
// 1. APP THEME & COLORS (MATCHED WITH SPLASH & SCREENSHOT AESTHETICS)
// ============================================================================
class AppColors {
  // Splash Screen & Primary Neon Lime
  static const Color splashLime = Color(0xFFA3E635);
  static const Color splashLimeLight = Color(0xFFBEF264);
  static const Color splashLimeMuted = Color(0xFF1E2D12);

  // Background & Surface Colors (Dark Gym Aesthetic)
  static const Color backgroundDark = Color(0xFF070B11);
  static const Color cardDark = Color(0xFF0F1725);
  static const Color cardDark2 = Color(0xFF141F32);
  static const Color borderDark = Color(0xFF1C273C);

  static const Color textPrimaryDark = Color(0xFFF8FAFC);
  static const Color textSecondaryDark = Color(0xFF94A3B8);

  // Exact 4-Card Color Gradients from "My Progress" Screenshot
  // 1. Steps (Emerald Green)
  static const Color greenCardBg1 = Color(0xFF062319);
  static const Color greenCardBg2 = Color(0xFF03140E);
  static const Color greenIcon = Color(0xFF22C55E);

  // 2. Calories (Orange Flame)
  static const Color orangeCardBg1 = Color(0xFF281408);
  static const Color orangeCardBg2 = Color(0xFF140803);
  static const Color orangeIcon = Color(0xFFF97316);

  // 3. Workout (Deep Purple)
  static const Color purpleCardBg1 = Color(0xFF1C0D2F);
  static const Color purpleCardBg2 = Color(0xFF0E0619);
  static const Color purpleIcon = Color(0xFFA855F7);

  // 4. Sessions (Cyan / Sky Blue)
  static const Color blueCardBg1 = Color(0xFF081C2E);
  static const Color blueCardBg2 = Color(0xFF030D17);
  static const Color blueIcon = Color(0xFF0284C7);

  static const Color deleteRed = Color(0xFFEF4444);
}

class AppTheme {
  static ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primaryColor: AppColors.splashLime,
    scaffoldBackgroundColor: AppColors.backgroundDark,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.splashLime,
      secondary: AppColors.splashLimeLight,
      surface: AppColors.cardDark,
      onSurface: AppColors.textPrimaryDark,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.cardDark,
      indicatorColor: AppColors.splashLime,
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: Colors.black);
        }
        return const IconThemeData(color: AppColors.textSecondaryDark);
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const TextStyle(
            color: AppColors.splashLime,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          );
        }
        return const TextStyle(
          color: AppColors.textSecondaryDark,
          fontSize: 12,
        );
      }),
    ),
  );
}

// ============================================================================
// 2. CONSTANTS & FORMAT UTILITIES (ACCURATE REAL SECONDS & TIMING)
// ============================================================================
class AppConstants {
  static const List<String> activityTypes = [
    'Walking',
    'Running',
    'Cycling',
    'Gym',
    'Swimming',
    'Yoga',
    'Other',
  ];

  static IconData getActivityIcon(String type) {
    switch (type.toLowerCase()) {
      case 'walking':
        return Icons.directions_walk_rounded;
      case 'running':
        return Icons.directions_run_rounded;
      case 'cycling':
        return Icons.directions_bike_rounded;
      case 'gym':
        return Icons.fitness_center_rounded;
      case 'swimming':
        return Icons.pool_rounded;
      case 'yoga':
        return Icons.self_improvement_rounded;
      default:
        return Icons.sports_score_rounded;
    }
  }

  static List<Color> getActivityGradient(String type, int index) {
    final palettes = [
      [const Color(0xFF166534), const Color(0xFF22C55E)],
      [const Color(0xFF0E7490), const Color(0xFF06B6D4)],
      [const Color(0xFF581C87), const Color(0xFFA855F7)],
      [const Color(0xFF1E3A8A), const Color(0xFF3B82F6)],
    ];
    return palettes[index % palettes.length];
  }
}

class FormatHelper {
  static String formatDuration(int totalSeconds) {
    if (totalSeconds <= 0) return '0s';
    if (totalSeconds < 60) {
      return '${totalSeconds}s';
    }
    final mins = totalSeconds ~/ 60;
    final remainingSecs = totalSeconds % 60;
    if (remainingSecs == 0) {
      return '$mins min';
    }
    return '${mins}m ${remainingSecs}s';
  }

  static String formatDurationLong(int totalSeconds) {
    if (totalSeconds <= 0) return '0 Seconds';
    if (totalSeconds < 60) {
      return '$totalSeconds Seconds';
    }
    final mins = totalSeconds ~/ 60;
    final remainingSecs = totalSeconds % 60;
    if (remainingSecs == 0) {
      return '$mins Minutes';
    }
    return '$mins Minutes $remainingSecs Seconds';
  }
}

class DateUtilsHelper {
  static String formatIsoDate(DateTime date) =>
      DateFormat('yyyy-MM-dd').format(date);
  static String formatDisplayDate(DateTime date) =>
      DateFormat('EEEE, d MMMM yyyy').format(date);
  static String formatShortDate(DateTime date) =>
      DateFormat('MMM d, yyyy').format(date);
  static String formatTime(DateTime date) => DateFormat('hh:mm a').format(date);

  static String getRelativeHeader(String isoDate) {
    final today = formatIsoDate(DateTime.now());
    final yesterday = formatIsoDate(
      DateTime.now().subtract(const Duration(days: 1)),
    );
    if (isoDate == today) return 'TODAY';
    if (isoDate == yesterday) return 'YESTERDAY';
    try {
      final parsed = DateFormat('yyyy-MM-dd').parse(isoDate);
      return DateFormat('EEEE, MMM d').format(parsed).toUpperCase();
    } catch (_) {
      return isoDate;
    }
  }

  static List<DateTime> getCurrentWeekDays() {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    return List.generate(
      7,
      (i) => DateTime(monday.year, monday.month, monday.day + i),
    );
  }

  static String getGreeting() {
    final h = DateTime.now().hour;
    if (h >= 5 && h < 12) {
      return 'Good Morning 🌅';
    } else if (h >= 12 && h < 17) {
      return 'Good Afternoon ☀️';
    } else if (h >= 17 && h < 21) {
      return 'Good Evening 🌇';
    } else {
      return 'Good Night 🌙';
    }
  }
}

// ============================================================================
// 3. BACKGROUND NOTIFICATION SERVICE
// ============================================================================
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static const int stepNotificationId = 888;
  static const String channelId = 'fitness_tracker_live_steps';
  static const String channelName = 'Fitness Tracker Live Steps';

  Future<void> init() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const initSettings = InitializationSettings(android: androidSettings);

    await _notificationsPlugin.initialize(initSettings);

    const androidChannel = AndroidNotificationChannel(
      channelId,
      channelName,
      description: 'Live step counting in real time',
      importance: Importance.low,
      enableVibration: false,
      playSound: false,
      showBadge: false,
    );

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(androidChannel);
  }

  Future<void> updateStepNotification(
    int steps,
    double calories,
    String status,
    int durationSeconds,
  ) async {
    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: 'Ongoing live step tracking',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      onlyAlertOnce: true,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
    );

    final notificationDetails = NotificationDetails(android: androidDetails);

    final m = durationSeconds ~/ 60;
    final s = durationSeconds % 60;
    final durStr =
        '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';

    await _notificationsPlugin.show(
      stepNotificationId,
      'Fitness Tracker: $steps Steps ($durStr)',
      '🔥 ${calories.toStringAsFixed(1)} kcal | $status | Live tracking active',
      notificationDetails,
    );
  }

  Future<void> cancelStepNotification() async {
    await _notificationsPlugin.cancel(stepNotificationId);
  }
}

// ============================================================================
// 4. REAL STOPWATCH SECONDS TRACKER + HARDWARE SENSOR ENGINE
// ============================================================================
class StepTrackerProvider extends ChangeNotifier {
  StreamSubscription<StepCount>? _stepSubscription;
  StreamSubscription<PedestrianStatus>? _statusSubscription;
  StreamSubscription<UserAccelerometerEvent>? _accelSubscription;
  Timer? _stopwatchTimer;

  bool _isTracking = false;
  int _liveSteps = 0;
  int _initialSensorSteps = -1;
  int _activeSeconds = 0;
  String _pedestrianStatus = 'Stopped';
  String? _statusError;

  int _lastStepTimeMs = 0;
  double _prevAccel = 0.0;
  bool _stepPeakDetected = false;
  final double _minStepThreshold = 2.85;

  bool get isTracking => _isTracking;
  int get liveSteps => _liveSteps;
  int get activeSeconds => _activeSeconds;
  String get pedestrianStatus => _pedestrianStatus;
  String? get statusError => _statusError;

  String get formattedDuration {
    final m = _activeSeconds ~/ 60;
    final s = _activeSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  double get estimatedCalories => _liveSteps * 0.04;
  double get estimatedDistanceKm => (_liveSteps * 0.76) / 1000.0;

  Future<void> initTracker() async {
    await NotificationService().init();

    final prefs = await SharedPreferences.getInstance();
    _isTracking = prefs.getBool('fittrack_auto_steps_enabled') ?? false;
    _liveSteps = prefs.getInt('fittrack_today_live_steps') ?? 0;
    _initialSensorSteps = prefs.getInt('fittrack_sensor_initial_steps') ?? -1;
    _activeSeconds = prefs.getInt('fittrack_today_active_seconds') ?? 0;

    if (_isTracking) {
      startTracking(silent: true);
    }
  }

  Future<bool> toggleTracking() async {
    if (_isTracking) {
      await stopTracking();
      return false;
    } else {
      return await startTracking();
    }
  }

  Future<bool> startTracking({bool silent = false}) async {
    var status = await Permission.activityRecognition.status;
    if (!status.isGranted) {
      status = await Permission.activityRecognition.request();
      if (!status.isGranted) {
        _statusError = 'Physical Activity permission required';
        notifyListeners();
        return false;
      }
    }

    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }

    _isTracking = true;
    _statusError = null;

    _stopwatchTimer?.cancel();
    _stopwatchTimer = Timer.periodic(const Duration(seconds: 1), (t) async {
      _activeSeconds++;
      if (_activeSeconds % 5 == 0) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('fittrack_today_active_seconds', _activeSeconds);
        NotificationService().updateStepNotification(
          _liveSteps,
          estimatedCalories,
          _pedestrianStatus,
          _activeSeconds,
        );
      }
      notifyListeners();
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('fittrack_auto_steps_enabled', true);

    NotificationService().updateStepNotification(
      _liveSteps,
      estimatedCalories,
      _pedestrianStatus,
      _activeSeconds,
    );

    try {
      _stepSubscription = Pedometer.stepCountStream.listen(
        _onHardwareStepCount,
        onError: (_) {},
      );

      _statusSubscription = Pedometer.pedestrianStatusStream.listen((
        PedestrianStatus event,
      ) {
        _pedestrianStatus = event.status;
        NotificationService().updateStepNotification(
          _liveSteps,
          estimatedCalories,
          _pedestrianStatus,
          _activeSeconds,
        );
        notifyListeners();
      }, onError: (_) {});

      _accelSubscription = userAccelerometerEventStream().listen((event) {
        final double magnitude = sqrt(
          event.x * event.x + event.y * event.y + event.z * event.z,
        );
        final int nowMs = DateTime.now().millisecondsSinceEpoch;

        if (magnitude > _minStepThreshold && _prevAccel <= _minStepThreshold) {
          _stepPeakDetected = true;
        }

        if (_stepPeakDetected && magnitude < _prevAccel) {
          final timeDiff = nowMs - _lastStepTimeMs;
          if (timeDiff >= 320 && timeDiff <= 1200) {
            _lastStepTimeMs = nowMs;
            _onAccurateStepDetected();
          } else if (timeDiff > 1200) {
            _lastStepTimeMs = nowMs;
            _onAccurateStepDetected();
          }
          _stepPeakDetected = false;
        }

        _prevAccel = magnitude;
      }, onError: (_) {});
    } catch (e) {
      _statusError = 'Error starting sensors: $e';
    }

    notifyListeners();
    return true;
  }

  void _onAccurateStepDetected() async {
    _liveSteps++;
    _pedestrianStatus = 'Walking';

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('fittrack_today_live_steps', _liveSteps);

    NotificationService().updateStepNotification(
      _liveSteps,
      estimatedCalories,
      _pedestrianStatus,
      _activeSeconds,
    );

    notifyListeners();
  }

  void _onHardwareStepCount(StepCount event) async {
    final currentRawSteps = event.steps;

    if (_initialSensorSteps == -1 || _initialSensorSteps > currentRawSteps) {
      _initialSensorSteps = currentRawSteps - _liveSteps;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('fittrack_sensor_initial_steps', _initialSensorSteps);
    }

    final computedSteps = currentRawSteps - _initialSensorSteps;
    if (computedSteps > _liveSteps) {
      _liveSteps = computedSteps;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('fittrack_today_live_steps', _liveSteps);

      NotificationService().updateStepNotification(
        _liveSteps,
        estimatedCalories,
        _pedestrianStatus,
        _activeSeconds,
      );

      notifyListeners();
    }
  }

  Future<void> stopTracking() async {
    _isTracking = false;
    _pedestrianStatus = 'Stopped';

    _stopwatchTimer?.cancel();
    _stopwatchTimer = null;

    await _stepSubscription?.cancel();
    await _statusSubscription?.cancel();
    await _accelSubscription?.cancel();
    _stepSubscription = null;
    _statusSubscription = null;
    _accelSubscription = null;

    await NotificationService().cancelStepNotification();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('fittrack_auto_steps_enabled', false);
    await prefs.setInt('fittrack_today_active_seconds', _activeSeconds);

    notifyListeners();
  }

  Future<bool> saveStepsToHistory(ActivityProvider activityProv) async {
    if (_liveSteps <= 0 && _activeSeconds <= 0) return false;

    final act = ActivityModel(
      activityType: 'Walking',
      duration: _activeSeconds,
      steps: _liveSteps,
      calories: estimatedCalories,
      date: DateUtilsHelper.formatIsoDate(DateTime.now()),
      createdAt: DateTime.now().toIso8601String(),
    );

    final ok = await activityProv.addActivity(act);
    if (ok) {
      _liveSteps = 0;
      _activeSeconds = 0;
      _initialSensorSteps = -1;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('fittrack_today_live_steps', 0);
      await prefs.setInt('fittrack_today_active_seconds', 0);
      await prefs.setInt('fittrack_sensor_initial_steps', -1);

      NotificationService().updateStepNotification(
        0,
        0.0,
        _pedestrianStatus,
        0,
      );

      notifyListeners();
      return true;
    }
    return false;
  }
}

// ============================================================================
// 5. ACTIVITY & GOAL PROVIDERS
// ============================================================================
class DailyMetric {
  final String dayName;
  final String dateIso;
  final int steps;
  final double calories;
  final int duration;
  final int sessions;

  DailyMetric({
    required this.dayName,
    required this.dateIso,
    required this.steps,
    required this.calories,
    required this.duration,
    required this.sessions,
  });
}

class ActivityProvider extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper.instance;
  List<ActivityModel> _activities = [];
  bool _isLoading = true;

  List<ActivityModel> get activities => _activities;
  bool get isLoading => _isLoading;

  List<ActivityModel> get todayActivities {
    final today = DateUtilsHelper.formatIsoDate(DateTime.now());
    return _activities.where((a) => a.date == today).toList();
  }

  int get todaySteps => todayActivities.fold(0, (sum, a) => sum + a.steps);
  double get todayCalories =>
      todayActivities.fold(0.0, (sum, a) => sum + a.calories);

  int get todayDuration =>
      todayActivities.fold(0, (sum, a) => sum + a.duration);

  int get todaySessions => todayActivities.length;

  List<ActivityModel> get weeklyActivities {
    final week = DateUtilsHelper.getCurrentWeekDays();
    final start = DateUtilsHelper.formatIsoDate(week.first);
    final end = DateUtilsHelper.formatIsoDate(week.last);
    return _activities
        .where(
          (a) => a.date.compareTo(start) >= 0 && a.date.compareTo(end) <= 0,
        )
        .toList();
  }

  int get weeklyTotalSteps =>
      weeklyActivities.fold(0, (sum, a) => sum + a.steps);
  double get weeklyTotalCalories =>
      weeklyActivities.fold(0.0, (sum, a) => sum + a.calories);
  int get weeklyTotalDuration =>
      weeklyActivities.fold(0, (sum, a) => sum + a.duration);
  int get weeklyTotalSessions => weeklyActivities.length;

  List<DailyMetric> get weeklyBreakdown {
    final week = DateUtilsHelper.getCurrentWeekDays();
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return List.generate(7, (i) {
      final iso = DateUtilsHelper.formatIsoDate(week[i]);
      final dayActs = _activities.where((a) => a.date == iso).toList();
      return DailyMetric(
        dayName: days[i],
        dateIso: iso,
        steps: dayActs.fold(0, (sum, a) => sum + a.steps),
        calories: dayActs.fold(0.0, (sum, a) => sum + a.calories),
        duration: dayActs.fold(0, (sum, a) => sum + a.duration),
        sessions: dayActs.length,
      );
    });
  }

  Map<String, List<ActivityModel>> get groupedActivities {
    final Map<String, List<ActivityModel>> map = {};
    for (var act in _activities) {
      map.putIfAbsent(act.date, () => []).add(act);
    }
    return map;
  }

  Future<void> loadActivities() async {
    try {
      _activities = await _db.getAllActivities();
    } catch (_) {
      _activities = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addActivity(ActivityModel activity) async {
    final id = await _db.insertActivity(activity);
    if (id > 0) {
      await loadActivities();
      return true;
    }
    return false;
  }

  Future<bool> deleteActivity(int id) async {
    await _db.deleteActivity(id);
    await loadActivities();
    return true;
  }

  Future<bool> clearAllActivities() async {
    await _db.deleteAllActivities();
    _activities = [];
    notifyListeners();
    return true;
  }
}

class GoalProvider extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper.instance;
  GoalModel _goals = GoalModel.defaultGoals();
  bool _isLoading = true;

  GoalModel get goals => _goals;
  bool get isLoading => _isLoading;

  Future<void> loadGoals() async {
    try {
      _goals = await _db.getGoals();
    } catch (_) {
      _goals = GoalModel.defaultGoals();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateGoals(
    int steps,
    double calories,
    int workoutMinutes,
  ) async {
    final updated = _goals.copyWith(
      stepsGoal: steps,
      caloriesGoal: calories,
      workoutGoal: workoutMinutes,
    );
    final count = await _db.updateGoals(updated);
    if (count > 0) {
      _goals = updated;
      notifyListeners();
      return true;
    }
    return false;
  }
}

// ============================================================================
// 6. SPLASH SCREEN (ATHLETIC GYM VIGNETTE + "FITNESS TRACKER" LOGO)
// ============================================================================
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  late AnimationController _popupCtrl;
  late Animation<double> _popupScale;
  late Animation<double> _glowPulse;

  final List<Map<String, String>> _splashData = [
    {
      'title': 'Train Smarter.\nLive Stronger.',
      'subtitle': 'Your personalized fitness journey, all in one place.',
    },
    {
      'title': 'Real-Time Sensor\nStep Counter',
      'subtitle':
          'Instant motion cadence counting. Background alert continues tracking.',
    },
    {
      'title': 'Zero Fake Data.\nReal Progress.',
      'subtitle':
          'Log your actual workouts, calories, & view real-time visual progress.',
    },
  ];

  @override
  void initState() {
    super.initState();
    _popupCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    _popupScale = CurvedAnimation(parent: _popupCtrl, curve: Curves.elasticOut);

    _glowPulse = Tween<double>(
      begin: 0.98,
      end: 1.04,
    ).animate(CurvedAnimation(parent: _popupCtrl, curve: Curves.easeInOut));

    _popupCtrl.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _popupCtrl.dispose();
    super.dispose();
  }

  void _onNext() {
    if (_currentPage < _splashData.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, anim, _) => const DashboardScreen(),
          transitionsBuilder: (_, anim, _, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0.4, -0.3),
                  radius: 1.25,
                  colors: [
                    Color(0xFF26332A),
                    Color(0xFF0F1618),
                    Color(0xFF050709),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 20,
            right: -30,
            child: Opacity(
              opacity: 0.18,
              child: Icon(
                Icons.fitness_center_rounded,
                size: size.width * 1.15,
                color: Colors.white,
              ),
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.50),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.85),
                    Colors.black,
                  ],
                  stops: const [0.0, 0.35, 0.70, 1.0],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: AppColors.splashLime,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.splashLime.withValues(alpha: 0.45),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.bolt_rounded,
                        color: Colors.black,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Fitness Tracker',
                      style: TextStyle(
                        color: AppColors.splashLime,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.6,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 140,
                      child: PageView.builder(
                        controller: _pageController,
                        onPageChanged: (idx) {
                          setState(() => _currentPage = idx);
                          _popupCtrl.reset();
                          _popupCtrl.forward();
                        },
                        itemCount: _splashData.length,
                        itemBuilder: (ctx, idx) {
                          final item = _splashData[idx];
                          return Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                item['title']!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  height: 1.25,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                item['subtitle']!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Color(0xFFCBD5E1),
                                  fontSize: 14,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        _splashData.length,
                        (i) => AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: _currentPage == i ? 22 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _currentPage == i
                                ? AppColors.splashLime
                                : Colors.white24,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    ScaleTransition(
                      scale: _popupScale,
                      child: AnimatedBuilder(
                        animation: _glowPulse,
                        builder: (ctx, child) => Container(
                          width: double.infinity,
                          height: 56,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.splashLime.withValues(
                                  alpha: 0.4,
                                ),
                                blurRadius: 24,
                                spreadRadius: 1,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: child,
                        ),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.splashLime,
                            foregroundColor: Colors.black,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                          ),
                          onPressed: _onNext,
                          child: Text(
                            _currentPage == _splashData.length - 1
                                ? 'Get Started'
                                : 'Next',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.2,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 7. MAIN DASHBOARD SCREEN & TABS
// ============================================================================
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _tab = 0;

  final List<Widget> _pages = const [
    _DashboardHomeTab(),
    StatisticsScreen(),
    HistoryScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: IndexedStack(index: _tab, children: _pages),
      floatingActionButton: (_tab == 0 || _tab == 2)
          ? Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.splashLime.withValues(alpha: 0.35),
                    blurRadius: 18,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: FloatingActionButton.extended(
                backgroundColor: AppColors.splashLime,
                foregroundColor: Colors.black,
                elevation: 0,
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddActivityScreen()),
                ),
                icon: const Icon(Icons.add, color: Colors.black, size: 22),
                label: const Text(
                  'Add Workout',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                    fontSize: 14,
                  ),
                ),
              ),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Statistics',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _DashboardHomeTab extends StatelessWidget {
  const _DashboardHomeTab();

  @override
  Widget build(BuildContext context) {
    final acts = Provider.of<ActivityProvider>(context);
    final goals = Provider.of<GoalProvider>(context);
    final tracker = Provider.of<StepTrackerProvider>(context);

    if (acts.isLoading || goals.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.splashLime),
      );
    }

    final totalStepsToday = acts.todaySteps + tracker.liveSteps;
    final totalCaloriesToday = acts.todayCalories + tracker.estimatedCalories;
    final totalDurationToday = acts.todayDuration + tracker.activeSeconds;
    final recentList = acts.activities.take(5).toList();

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Header (Greeting & Date)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateUtilsHelper.getGreeting(),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimaryDark,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      DateUtilsHelper.formatDisplayDate(DateTime.now()),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.splashLime,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  tooltip: 'Power / Reset',
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.splashLime.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.power_settings_new_rounded,
                      color: AppColors.splashLime,
                      size: 24,
                    ),
                  ),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const GoalsScreen()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // 2. Indoor Live Step Counter Card
            const LiveStepCounterCard(),
            const SizedBox(height: 14),

            // 🗺️ 3. NAYA FEATURE: OUTDOOR GPS ROUTE TRACKER BANNER
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RouteTrackingScreen()),
              ),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1B2C23), Color(0xFF141F1A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.splashLime.withValues(alpha: 0.35),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.splashLime.withValues(alpha: 0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.splashLime,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.splashLime.withValues(alpha: 0.4),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.map_rounded,
                        color: Colors.black,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'GPS Route Tracker',
                                style: TextStyle(
                                  color: AppColors.textPrimaryDark,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2E4536),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'LIVE',
                                  style: TextStyle(
                                    color: AppColors.splashLime,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          const Text(
                            'Map your outdoor run & walk live',
                            style: TextStyle(
                              color: AppColors.textSecondaryDark,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: AppColors.splashLime,
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 22),

            // 4. My Progress Section
            _MyProgressSection(
              steps: totalStepsToday,
              calories: totalCaloriesToday,
              durationSeconds: totalDurationToday,
              sessions: acts.todaySessions,
              goals: goals.goals,
            ),
            const SizedBox(height: 24),

            // 5. Recent Workouts Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent Workouts',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimaryDark,
                  ),
                ),
                if (recentList.isNotEmpty)
                  TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const HistoryScreen()),
                    ),
                    child: const Text(
                      'View All',
                      style: TextStyle(
                        color: AppColors.splashLime,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // 6. Workouts List / Empty State
            if (recentList.isEmpty)
              EmptyState(
                icon: Icons.sports_gymnastics_rounded,
                title: 'No workouts logged yet',
                message:
                    'Turn on Live Step Counter above or tap Add Workout below.',
                buttonText: 'Add Workout',
                onAction: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddActivityScreen()),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: recentList.length,
                itemBuilder: (ctx, idx) => ActivityCard(
                  activity: recentList[idx],
                  index: idx,
                  onDelete: () => acts.deleteActivity(recentList[idx].id!),
                ),
              ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 8. LIVE STEP CARD (FIXED OVERFLOW: NO CLIPPED SAVE BUTTON)
// ============================================================================
class LiveStepCounterCard extends StatefulWidget {
  const LiveStepCounterCard({super.key});

  @override
  State<LiveStepCounterCard> createState() => _LiveStepCounterCardState();
}

class _LiveStepCounterCardState extends State<LiveStepCounterCard> {
  bool _isAnimatingTap = false;

  @override
  Widget build(BuildContext context) {
    final tracker = Provider.of<StepTrackerProvider>(context);
    final actProv = Provider.of<ActivityProvider>(context, listen: false);

    final bool hasDataToSave =
        tracker.liveSteps > 0 || tracker.activeSeconds > 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1725),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: tracker.isTracking
              ? AppColors.splashLime
              : AppColors.splashLime.withValues(alpha: 0.55),
          width: 1.6,
        ),
        boxShadow: [
          if (tracker.isTracking)
            BoxShadow(
              color: AppColors.splashLime.withValues(alpha: 0.18),
              blurRadius: 20,
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
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.splashLime,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.directions_walk_rounded,
                  color: Colors.black,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Live Step Counter',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimaryDark,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tracker.isTracking
                          ? 'Real Timer: ${tracker.formattedDuration} • active'
                          : 'Real Timer: ${tracker.formattedDuration} • stopped',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: tracker.isTracking
                            ? AppColors.splashLime
                            : AppColors.splashLime.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () async {
                  setState(() => _isAnimatingTap = true);
                  await tracker.toggleTracking();
                  await Future.delayed(const Duration(milliseconds: 150));
                  if (mounted) setState(() => _isAnimatingTap = false);
                },
                child: AnimatedScale(
                  scale: _isAnimatingTap ? 0.90 : 1.0,
                  duration: const Duration(milliseconds: 150),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: 54,
                    height: 32,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: tracker.isTracking
                          ? AppColors.splashLime
                          : AppColors.cardDark2,
                      border: Border.all(
                        color: tracker.isTracking
                            ? AppColors.splashLime
                            : AppColors.borderDark,
                      ),
                    ),
                    child: AnimatedAlign(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                      alignment: tracker.isTracking
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: tracker.isTracking
                              ? Colors.black
                              : AppColors.textSecondaryDark,
                        ),
                        child: Icon(
                          tracker.isTracking
                              ? Icons.check_rounded
                              : Icons.close_rounded,
                          size: 14,
                          color: tracker.isTracking
                              ? AppColors.splashLime
                              : Colors.black,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              TweenAnimationBuilder<int>(
                tween: IntTween(begin: 0, end: tracker.liveSteps),
                duration: const Duration(milliseconds: 300),
                builder: (_, val, _) => Text(
                  NumberFormat('#,###').format(val),
                  style: const TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.w900,
                    color: AppColors.splashLime,
                    letterSpacing: -1.0,
                  ),
                ),
              ),
              if (hasDataToSave)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.splashLime,
                    foregroundColor: Colors.black,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () async {
                    final saved = await tracker.saveStepsToHistory(actProv);
                    if (saved && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Live workout saved to history!'),
                          backgroundColor: AppColors.splashLime,
                        ),
                      );
                    }
                  },
                  icon: const Icon(
                    Icons.save_rounded,
                    size: 17,
                    color: Colors.black,
                  ),
                  label: const Text(
                    'Save',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      color: Colors.black,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(
                Icons.timer_outlined,
                size: 13,
                color: AppColors.textSecondaryDark,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  'Actual Time: ${tracker.activeSeconds}s | 0ms Cadence Motion',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondaryDark,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 9. "MY PROGRESS" SECTION (FIXED: "STAY CONSISTENT" NEVER CLIPPED)
// ============================================================================
class _MyProgressSection extends StatelessWidget {
  final int steps;
  final double calories;
  final int durationSeconds;
  final int sessions;
  final GoalModel goals;

  const _MyProgressSection({
    required this.steps,
    required this.calories,
    required this.durationSeconds,
    required this.sessions,
    required this.goals,
  });

  @override
  Widget build(BuildContext context) {
    final stepProgress = goals.stepsGoal > 0
        ? (steps / goals.stepsGoal).clamp(0.0, 1.0)
        : 0.0;
    final calProgress = goals.caloriesGoal > 0
        ? (calories / goals.caloriesGoal).clamp(0.0, 1.0)
        : 0.0;

    final workoutGoalSeconds = max(1, goals.workoutGoal * 60);
    final durProgress = (durationSeconds / workoutGoalSeconds).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: const Color(0xFF102A1E),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.greenIcon.withValues(alpha: 0.4),
                      ),
                    ),
                    child: const Icon(
                      Icons.show_chart_rounded,
                      color: AppColors.greenIcon,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'My Progress',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimaryDark,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Text(
                          'Small steps make big results',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondaryDark,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF101826),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF1E293B)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.local_fire_department_rounded,
                    color: AppColors.orangeIcon,
                    size: 16,
                  ),
                  SizedBox(width: 5),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Stay Consistent',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimaryDark,
                        ),
                      ),
                      Text(
                        "You're doing great!",
                        style: TextStyle(
                          fontSize: 9,
                          color: AppColors.textSecondaryDark,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _progressCardTile(
                bgColor1: AppColors.greenCardBg1,
                bgColor2: AppColors.greenCardBg2,
                borderColor: const Color(0xFF133E2B),
                watermarkIcon: Icons.pets_rounded,
                avatarBg: AppColors.greenIcon,
                avatarIcon: Icons.directions_walk_rounded,
                title: 'Steps',
                valueText: '$steps',
                subText: '/ ${goals.stepsGoal}',
                progress: stepProgress,
                progressColor: AppColors.greenIcon,
                percentText: '${(stepProgress * 100).toInt()}%',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _progressCardTile(
                bgColor1: AppColors.orangeCardBg1,
                bgColor2: AppColors.orangeCardBg2,
                borderColor: const Color(0xFF3F1D0A),
                watermarkIcon: Icons.local_fire_department_rounded,
                avatarBg: AppColors.orangeIcon,
                avatarIcon: Icons.local_fire_department_rounded,
                title: 'Calories',
                valueText: '${calories.toInt()}',
                subText: '/ ${goals.caloriesGoal.toInt()} kcal',
                progress: calProgress,
                progressColor: AppColors.orangeIcon,
                percentText: '${(calProgress * 100).toInt()}%',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _progressCardTile(
                bgColor1: AppColors.purpleCardBg1,
                bgColor2: AppColors.purpleCardBg2,
                borderColor: const Color(0xFF331652),
                watermarkIcon: Icons.timer_rounded,
                avatarBg: AppColors.purpleIcon,
                avatarIcon: Icons.timer_rounded,
                title: 'Workout',
                valueText: FormatHelper.formatDuration(durationSeconds),
                subText: '/ ${goals.workoutGoal} min',
                progress: durProgress,
                progressColor: AppColors.purpleIcon,
                percentText: '${(durProgress * 100).toInt()}%',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _progressCardTile(
                bgColor1: AppColors.blueCardBg1,
                bgColor2: AppColors.blueCardBg2,
                borderColor: const Color(0xFF0F3252),
                watermarkIcon: Icons.event_available_rounded,
                avatarBg: AppColors.blueIcon,
                avatarIcon: Icons.fitness_center_rounded,
                title: 'Sessions',
                valueText: '$sessions',
                subText: 'Today',
                progress: null,
                progressColor: AppColors.blueIcon,
                percentText: null,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _progressCardTile({
    required Color bgColor1,
    required Color bgColor2,
    required Color borderColor,
    required IconData watermarkIcon,
    required Color avatarBg,
    required IconData avatarIcon,
    required String title,
    required String valueText,
    required String subText,
    required double? progress,
    required Color progressColor,
    required String? percentText,
  }) {
    return Container(
      height: 160,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [bgColor1, bgColor2],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -8,
            top: 28,
            child: Opacity(
              opacity: 0.08,
              child: Icon(watermarkIcon, size: 75, color: Colors.white),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: avatarBg,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: avatarBg.withValues(alpha: 0.35),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Icon(avatarIcon, color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimaryDark,
                      ),
                    ),
                    const SizedBox(width: 3),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 16,
                      color: AppColors.textSecondaryDark,
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      valueText,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimaryDark,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      subText,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondaryDark,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                if (progress != null)
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 6,
                            color: progressColor,
                            backgroundColor: Colors.white10,
                          ),
                        ),
                      ),
                      if (percentText != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          percentText,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: progressColor,
                          ),
                        ),
                      ],
                    ],
                  )
                else
                  const SizedBox(height: 6),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 10. RECENT WORKOUT CARD & POPUP MODAL (SHOWS EXACT SECONDS / TIME)
// ============================================================================
class ActivityCard extends StatelessWidget {
  final ActivityModel activity;
  final int index;
  final VoidCallback? onDelete;

  const ActivityCard({
    super.key,
    required this.activity,
    this.index = 0,
    this.onDelete,
  });

  void _showWorkoutDetails(BuildContext context) {
    String formattedDateTime = activity.date;
    try {
      final dt = DateTime.parse(activity.createdAt);
      formattedDateTime =
          "${DateFormat('EEEE, d MMMM yyyy').format(dt)} at ${DateFormat('hh:mm a').format(dt)}";
    } catch (_) {}

    final distanceKm = (activity.steps * 0.76) / 1000.0;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Color(0xFF0F172A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(
            top: BorderSide(color: AppColors.splashLime, width: 1.5),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.borderDark,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: AppConstants.getActivityGradient(
                            activity.activityType,
                            index,
                          ),
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        AppConstants.getActivityIcon(activity.activityType),
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          activity.activityType,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimaryDark,
                          ),
                        ),
                        Text(
                          activity.date,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.splashLime,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    if (onDelete != null) onDelete!();
                  },
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.deleteRed.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.delete_outline_rounded,
                      color: AppColors.deleteRed,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              formattedDateTime,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondaryDark,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.cardDark,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.borderDark),
              ),
              child: Column(
                children: [
                  _detailRow(
                    Icons.timer_rounded,
                    'Duration',
                    FormatHelper.formatDurationLong(activity.duration),
                    AppColors.purpleIcon,
                  ),
                  const Divider(color: AppColors.borderDark, height: 24),
                  _detailRow(
                    Icons.local_fire_department_rounded,
                    'Energy Burned',
                    '${activity.calories.toInt()} kcal',
                    AppColors.orangeIcon,
                  ),
                  const Divider(color: AppColors.borderDark, height: 24),
                  _detailRow(
                    Icons.directions_walk_rounded,
                    'Steps Counted',
                    '${activity.steps} steps',
                    AppColors.greenIcon,
                  ),
                  if (activity.steps > 0) ...[
                    const Divider(color: AppColors.borderDark, height: 24),
                    _detailRow(
                      Icons.straighten_rounded,
                      'Estimated Distance',
                      '${distanceKm.toStringAsFixed(2)} km',
                      AppColors.splashLime,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.cardDark2,
                  foregroundColor: AppColors.textPrimaryDark,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: AppColors.borderDark),
                  ),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text(
                  'Close',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String val, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondaryDark,
              ),
            ),
          ],
        ),
        Text(
          val,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimaryDark,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final gradient = AppConstants.getActivityGradient(
      activity.activityType,
      index,
    );
    final icon = AppConstants.getActivityIcon(activity.activityType);

    String timeStr = '00:00 AM';
    try {
      timeStr = DateUtilsHelper.formatTime(DateTime.parse(activity.createdAt));
    } catch (_) {}

    return GestureDetector(
      onTap: () => _showWorkoutDetails(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.cardDark,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.borderDark, width: 1.2),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: gradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: Colors.white, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        activity.activityType,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimaryDark,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.access_time_rounded,
                            size: 13,
                            color: AppColors.textSecondaryDark,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            timeStr,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondaryDark,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (onDelete != null)
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (dCtx) => AlertDialog(
                            backgroundColor: AppColors.cardDark,
                            title: const Text('Delete Workout?'),
                            content: const Text(
                              'This workout record will be permanently removed.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(dCtx),
                                child: const Text(
                                  'Cancel',
                                  style: TextStyle(
                                    color: AppColors.textSecondaryDark,
                                  ),
                                ),
                              ),
                              TextButton(
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.deleteRed,
                                ),
                                onPressed: () {
                                  Navigator.pop(dCtx);
                                  onDelete!();
                                },
                                child: const Text(
                                  'Delete',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.deleteRed.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.delete_outline_rounded,
                          color: AppColors.deleteRed,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textSecondaryDark,
                  size: 20,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.only(left: 62),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _metricPill(
                    icon: Icons.timer_outlined,
                    iconColor: AppColors.purpleIcon,
                    value: FormatHelper.formatDuration(activity.duration),
                    label: 'Duration',
                  ),
                  _metricPill(
                    icon: Icons.local_fire_department_rounded,
                    iconColor: AppColors.orangeIcon,
                    value: '${activity.calories.toInt()} kcal',
                    label: 'Calories',
                  ),
                  _metricPill(
                    icon: Icons.directions_walk_rounded,
                    iconColor: AppColors.greenIcon,
                    value: '${activity.steps}',
                    label: 'Steps',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricPill({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: iconColor),
            const SizedBox(width: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimaryDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Padding(
          padding: const EdgeInsets.only(left: 19),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.textSecondaryDark,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? buttonText;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.buttonText,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 36,
              backgroundColor: AppColors.splashLime.withValues(alpha: 0.15),
              child: Icon(icon, size: 36, color: AppColors.splashLime),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimaryDark,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              message,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondaryDark,
              ),
              textAlign: TextAlign.center,
            ),
            if (buttonText != null && onAction != null) ...[
              const SizedBox(height: 18),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.splashLime,
                  foregroundColor: Colors.black,
                  minimumSize: const Size(160, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: onAction,
                icon: const Icon(Icons.add, color: Colors.black),
                label: Text(
                  buttonText!,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 11. SCREENS: ADD ACTIVITY, HISTORY, STATS, GOALS, PROFILE
// ============================================================================
class AddActivityScreen extends StatefulWidget {
  const AddActivityScreen({super.key});

  @override
  State<AddActivityScreen> createState() => _AddActivityScreenState();
}

class _AddActivityScreenState extends State<AddActivityScreen> {
  final _formKey = GlobalKey<FormState>();
  String _selectedType = AppConstants.activityTypes.first;
  final TextEditingController _durCtrl = TextEditingController();
  final TextEditingController _stepsCtrl = TextEditingController(text: '0');
  final TextEditingController _calCtrl = TextEditingController();

  DateTime _date = DateTime.now();
  TimeOfDay _time = TimeOfDay.now();
  bool _isSaving = false;

  @override
  void dispose() {
    _durCtrl.dispose();
    _stepsCtrl.dispose();
    _calCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final now = DateTime(
      _date.year,
      _date.month,
      _date.day,
      _time.hour,
      _time.minute,
    );

    final int durationSeconds = int.parse(_durCtrl.text.trim()) * 60;

    final act = ActivityModel(
      activityType: _selectedType,
      duration: durationSeconds,
      steps: int.tryParse(_stepsCtrl.text.trim()) ?? 0,
      calories: double.parse(_calCtrl.text.trim()),
      date: DateUtilsHelper.formatIsoDate(_date),
      createdAt: now.toIso8601String(),
    );

    final provider = Provider.of<ActivityProvider>(context, listen: false);
    final ok = await provider.addActivity(act);

    if (mounted) {
      setState(() => _isSaving = false);
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Workout added successfully'),
            backgroundColor: AppColors.splashLime,
          ),
        );
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(title: const Text('Add Workout')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            DropdownButtonFormField<String>(
              initialValue: _selectedType,
              dropdownColor: AppColors.cardDark,
              decoration: const InputDecoration(
                labelText: 'Activity Type',
                border: OutlineInputBorder(),
              ),
              items: AppConstants.activityTypes
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: (v) => setState(() => _selectedType = v!),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _durCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Duration (Minutes)',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Duration is required';
                final n = int.tryParse(v);
                if (n == null || n <= 0) return 'Must be greater than 0';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _stepsCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Steps',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _calCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Calories Burned (kcal)',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Calories are required';
                return null;
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.splashLime,
                      side: const BorderSide(color: AppColors.borderDark),
                    ),
                    onPressed: () async {
                      final p = await showDatePicker(
                        context: context,
                        initialDate: _date,
                        firstDate: DateTime(2022),
                        lastDate: DateTime.now(),
                      );
                      if (p != null) setState(() => _date = p);
                    },
                    icon: const Icon(Icons.calendar_today),
                    label: Text(DateUtilsHelper.formatShortDate(_date)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.splashLime,
                      side: const BorderSide(color: AppColors.borderDark),
                    ),
                    onPressed: () async {
                      final t = await showTimePicker(
                        context: context,
                        initialTime: _time,
                      );
                      if (t != null) setState(() => _time = t);
                    },
                    icon: const Icon(Icons.access_time),
                    label: Text(_time.format(context)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.splashLime,
                foregroundColor: Colors.black,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const CircularProgressIndicator(color: Colors.black)
                  : const Text(
                      'Save Workout',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final acts = Provider.of<ActivityProvider>(context);
    final grouped = acts.groupedActivities;

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(title: const Text('Workout History')),
      body: grouped.isEmpty
          ? EmptyState(
              icon: Icons.history_rounded,
              title: 'No workout history',
              message: 'Saved workouts will appear here grouped by date.',
              buttonText: 'Add Workout',
              onAction: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddActivityScreen()),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: grouped.keys.length,
              itemBuilder: (ctx, i) {
                final dateIso = grouped.keys.elementAt(i);
                final list = grouped[dateIso]!;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 4,
                      ),
                      child: Text(
                        DateUtilsHelper.getRelativeHeader(dateIso),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: AppColors.splashLime,
                        ),
                      ),
                    ),
                    ...list.asMap().entries.map(
                      (entry) => ActivityCard(
                        activity: entry.value,
                        index: entry.key,
                        onDelete: () => acts.deleteActivity(entry.value.id!),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}

// ============================================================================
// WEEKLY STATISTICS SCREEN (100% MATCHING SCREENSHOT + LIVE SYNCED)
// ============================================================================

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  String _selectedPeriod = 'This Week';
  int _selectedDayIndex = 6; // Default to Sunday (Index 6)

  void _showPeriodSelector() {
    final periods = ['This Week', 'Last Week', 'Last 2 Weeks', 'This Month'];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // <-- 1. Yeh add karein
      backgroundColor: const Color(0xFF0F1726),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          // <-- 2. SingleChildScrollView wrap karein
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Select Time Period',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              ...periods.map(
                (period) => ListTile(
                  title: Text(
                    period,
                    style: TextStyle(
                      color: _selectedPeriod == period
                          ? AppColors.splashLime
                          : Colors.white,
                      fontWeight: _selectedPeriod == period
                          ? FontWeight.bold
                          : FontWeight.w500,
                    ),
                  ),
                  trailing: _selectedPeriod == period
                      ? const Icon(Icons.check, color: AppColors.splashLime)
                      : null,
                  onTap: () {
                    setState(() => _selectedPeriod = period);
                    Navigator.pop(ctx);
                  },
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  void _showMetricDetails(
    String title,
    String value,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // <-- Yeh line zaroor add karein
      backgroundColor: const Color(0xFF0F1726),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          // <-- Yahan SingleChildScrollView wrap karein
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: color, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Color(0xFF8E9BAE),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF080C14),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Recorded Value',
                      style: TextStyle(color: Color(0xFF8E9BAE), fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.splashLime,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text(
                    'Close',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final acts = Provider.of<ActivityProvider>(context);
    final tracker = Provider.of<StepTrackerProvider>(context);
    final breakdown = acts.weeklyBreakdown;

    int targetSteps = 10000;
    try {
      final goalProv = Provider.of<GoalProvider>(context, listen: false);
      if (goalProv.goals.stepsGoal > 0) {
        targetSteps = goalProv.goals.stepsGoal;
      }
    } catch (_) {}

    final todayWeekdayIndex = (DateTime.now().weekday - 1).clamp(0, 6);

    final defaultDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final List<String> dayNames = List.generate(7, (i) {
      if (i < breakdown.length && breakdown[i].dayName.isNotEmpty) {
        return breakdown[i].dayName;
      }
      return defaultDays[i];
    });

    final List<double> daySteps = List.generate(7, (i) {
      int s = (i < breakdown.length) ? breakdown[i].steps : 0;
      if (i == todayWeekdayIndex) {
        s += tracker.liveSteps;
      }
      return s.toDouble();
    });

    final selectedSteps = daySteps[_selectedDayIndex].toInt();

    final totalWeeklySteps = acts.weeklyTotalSteps + tracker.liveSteps;
    final totalWeeklyCalories =
        acts.weeklyTotalCalories + tracker.estimatedCalories;
    final totalWeeklyDuration =
        acts.weeklyTotalDuration + tracker.activeSeconds;
    final totalWeeklySessions = acts.weeklyTotalSessions;

    return Scaffold(
      backgroundColor: const Color(0xFF080B11),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          children: [
            // ==================== 1. TOP HEADER ====================
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F1722),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF1E293B)),
                  ),
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _buildHeaderBar(height: 12),
                        const SizedBox(width: 3),
                        _buildHeaderBar(height: 18),
                        const SizedBox(width: 3),
                        _buildHeaderBar(height: 10),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Weekly Statistics',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.3,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Track your progress. Build a better you.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF7D8B9D),
                        ),
                      ),
                    ],
                  ),
                ),
                InkWell(
                  onTap: _showPeriodSelector,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F1726),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF223046)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.calendar_today_outlined,
                          size: 13,
                          color: Color(0xFF7D8B9D),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _selectedPeriod,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 16,
                          color: Color(0xFF7D8B9D),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ==================== 2. WEEKLY STEPS CARD ====================
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF0B111D),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF1B283C)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [Color(0xFF4ADE80), Color(0xFF16A34A)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Center(
                          child: CustomPaint(
                            size: const Size(22, 22),
                            painter: _SneakerIconPainter(color: Colors.white),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Weekly Steps',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Your daily movement',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF7D8B9D),
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: '$selectedSteps',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            TextSpan(
                              text:
                                  ' / ${targetSteps.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF7D8B9D),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildBarChart(dayNames, daySteps),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ==================== 3. WEEKLY SUMMARY HEADER ====================
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Weekly Summary',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                InkWell(
                  onTap: () {
                    _showMetricDetails(
                      'Weekly Summary',
                      '$totalWeeklySteps Steps Completed',
                      '$totalWeeklySessions Workout Sessions this week',
                      Icons.insights_rounded,
                      AppColors.splashLime,
                    );
                  },
                  child: Row(
                    children: const [
                      Text(
                        'View Details',
                        style: TextStyle(
                          color: AppColors.splashLime,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_rounded,
                        color: AppColors.splashLime,
                        size: 15,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // ==================== 4. LIVE SUMMARY CARDS ====================
            // 1. Total Steps
            _SummaryStatCard(
              title: 'Total Steps',
              subtitle: 'Across 7 days',
              value: '$totalWeeklySteps',
              unitText: 'steps',
              unitIcon: Icons.directions_walk_rounded,
              iconWidget: CustomPaint(
                size: const Size(22, 22),
                painter: _SneakerIconPainter(color: Colors.white),
              ),
              badgeGradient: const [Color(0xFF4ADE80), Color(0xFF16A34A)],
              waveColor: const Color(0xFF10B981),
              borderColor: const Color(0xFF143026),
              onTap: () => _showMetricDetails(
                'Total Steps',
                '$totalWeeklySteps steps',
                'Across 7 days',
                Icons.directions_walk_rounded,
                const Color(0xFF4ADE80),
              ),
            ),
            const SizedBox(height: 12),

            // 2. Total Calories
            _SummaryStatCard(
              title: 'Total Calories',
              subtitle: 'Burned this week',
              value: '${totalWeeklyCalories.toInt()}',
              unitText: 'kcal',
              unitIcon: Icons.local_fire_department_rounded,
              unitIconColor: const Color(0xFFFF7A00),
              iconWidget: const Icon(
                Icons.local_fire_department_rounded,
                color: Colors.white,
                size: 24,
              ),
              badgeGradient: const [Color(0xFFFF7A00), Color(0xFFFF3D00)],
              waveColor: const Color(0xFFFF5722),
              borderColor: const Color(0xFF381F1A),
              onTap: () => _showMetricDetails(
                'Total Calories',
                '${totalWeeklyCalories.toInt()} kcal',
                'Burned this week',
                Icons.local_fire_department_rounded,
                const Color(0xFFFF7A00),
              ),
            ),
            const SizedBox(height: 12),

            // 3. Total Workout Time
            _SummaryStatCard(
              title: 'Total Workout Time',
              subtitle: 'Active time spent',
              value: FormatHelper.formatDuration(totalWeeklyDuration),
              unitText: 'minutes',
              unitIcon: Icons.access_time_rounded,
              unitIconColor: const Color(0xFFA855F7),
              iconWidget: const Icon(
                Icons.timer_outlined,
                color: Colors.white,
                size: 24,
              ),
              badgeGradient: const [Color(0xFFA855F7), Color(0xFF7C3AED)],
              waveColor: const Color(0xFF8B5CF6),
              borderColor: const Color(0xFF2C1B42),
              onTap: () => _showMetricDetails(
                'Total Workout Time',
                FormatHelper.formatDuration(totalWeeklyDuration),
                'Active time spent',
                Icons.timer_outlined,
                const Color(0xFFA855F7),
              ),
            ),
            const SizedBox(height: 12),

            // 4. Total Sessions
            _SummaryStatCard(
              title: 'Total Sessions',
              subtitle: 'Completed this week',
              value: '$totalWeeklySessions',
              unitText: 'sessions',
              unitIcon: Icons.event_available_rounded,
              unitIconColor: const Color(0xFF0EA5E9),
              iconWidget: const Icon(
                Icons.fitness_center_rounded,
                color: Colors.white,
                size: 22,
              ),
              badgeGradient: const [Color(0xFF0EA5E9), Color(0xFF2563EB)],
              waveColor: const Color(0xFF3B82F6),
              borderColor: const Color(0xFF142944),
              onTap: () => _showMetricDetails(
                'Total Sessions',
                '$totalWeeklySessions sessions',
                'Completed this week',
                Icons.fitness_center_rounded,
                const Color(0xFF0EA5E9),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderBar({required double height}) {
    return Container(
      width: 3.5,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.splashLime,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildBarChart(List<String> days, List<double> steps) {
    const yLabels = ['10K', '7.5K', '5K', '2.5K', '0'];
    const double chartHeight = 150.0;

    double peak = 10000.0;
    for (var s in steps) {
      if (s > peak) peak = s;
    }

    return Column(
      children: [
        SizedBox(
          height: chartHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 34,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: yLabels
                      .map(
                        (label) => Text(
                          label,
                          style: const TextStyle(
                            color: Color(0xFF7D8B9D),
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              Expanded(
                child: Stack(
                  children: [
                    Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(
                        5,
                        (index) => Container(
                          height: 1,
                          color: const Color(
                            0xFF1B283C,
                          ).withValues(alpha: 0.55),
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: List.generate(7, (index) {
                        final val = steps[index];
                        final heightFactor = (val / peak).clamp(0.02, 1.0);
                        final isSelected = _selectedDayIndex == index;

                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedDayIndex = index;
                            });
                          },
                          behavior: HitTestBehavior.opaque,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (isSelected) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0B111D),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: AppColors.splashLime,
                                      width: 1.2,
                                    ),
                                  ),
                                  child: Text(
                                    val >= 1000
                                        ? '${(val / 1000).toStringAsFixed(1)}K'
                                        : '${val.toInt()}',
                                    style: const TextStyle(
                                      color: AppColors.splashLime,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Container(
                                  width: 4,
                                  height: 4,
                                  decoration: const BoxDecoration(
                                    color: AppColors.splashLime,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(height: 3),
                              ] else
                                const SizedBox(height: 20),

                              AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                width: 22,
                                height: (chartHeight - 30) * heightFactor,
                                decoration: BoxDecoration(
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(5),
                                  ),
                                  gradient: isSelected
                                      ? const LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            Color(0xFF86EFAC),
                                            Color(0xFF22C55E),
                                          ],
                                        )
                                      : LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            const Color(
                                              0xFF244773,
                                            ).withValues(alpha: 0.85),
                                            const Color(
                                              0xFF14243A,
                                            ).withValues(alpha: 0.95),
                                          ],
                                        ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            const SizedBox(width: 34),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(7, (index) {
                  final isSelected = _selectedDayIndex == index;
                  return Text(
                    days[index],
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : const Color(0xFF7D8B9D),
                      fontSize: 11,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.w500,
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SummaryStatCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String value;
  final String unitText;
  final IconData unitIcon;
  final Color? unitIconColor;
  final Widget iconWidget;
  final List<Color> badgeGradient;
  final Color waveColor;
  final Color borderColor;
  final VoidCallback onTap;

  const _SummaryStatCard({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.unitText,
    required this.unitIcon,
    this.unitIconColor,
    required this.iconWidget,
    required this.badgeGradient,
    required this.waveColor,
    required this.borderColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 76,
        decoration: BoxDecoration(
          color: const Color(0xFF0C121C),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            children: [
              Positioned(
                right: -20,
                top: -10,
                bottom: -10,
                child: Container(
                  width: 140,
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.centerRight,
                      radius: 0.9,
                      colors: [
                        waveColor.withValues(alpha: 0.18),
                        waveColor.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: badgeGradient,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Center(child: iconWidget),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: const TextStyle(
                              color: Color(0xFF7D8B9D),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          value,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              unitIcon,
                              size: 13,
                              color: unitIconColor ?? const Color(0xFF7D8B9D),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              unitText,
                              style: const TextStyle(
                                color: Color(0xFF7D8B9D),
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(width: 10),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: Color(0xFF475569),
                      size: 20,
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

class _SneakerIconPainter extends CustomPainter {
  final Color color;
  const _SneakerIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final w = size.width;
    final h = size.height;

    final path = Path();
    path.moveTo(w * 0.78, h * 0.36);
    path.quadraticBezierTo(w * 0.88, h * 0.58, w * 0.82, h * 0.76);
    path.lineTo(w * 0.22, h * 0.76);
    path.quadraticBezierTo(w * 0.10, h * 0.70, w * 0.16, h * 0.56);
    path.lineTo(w * 0.40, h * 0.50);
    path.lineTo(w * 0.56, h * 0.30);
    path.quadraticBezierTo(w * 0.68, h * 0.40, w * 0.78, h * 0.36);

    canvas.drawPath(path, paint);

    final solePath = Path();
    solePath.moveTo(w * 0.18, h * 0.68);
    solePath.lineTo(w * 0.82, h * 0.68);
    canvas.drawPath(solePath, paint..strokeWidth = 1.4);

    canvas.drawLine(
      Offset(w * 0.42, h * 0.45),
      Offset(w * 0.49, h * 0.43),
      paint,
    );
    canvas.drawLine(
      Offset(w * 0.48, h * 0.38),
      Offset(w * 0.55, h * 0.36),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ============================================================================
// GOALS SCREEN
// ============================================================================
class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _stepsCtrl;
  late TextEditingController _calCtrl;
  late TextEditingController _durCtrl;

  @override
  void initState() {
    super.initState();
    final g = Provider.of<GoalProvider>(context, listen: false).goals;
    _stepsCtrl = TextEditingController(text: '${g.stepsGoal}');
    _calCtrl = TextEditingController(text: '${g.caloriesGoal.toInt()}');
    _durCtrl = TextEditingController(text: '${g.workoutGoal}');
  }

  @override
  void dispose() {
    _stepsCtrl.dispose();
    _calCtrl.dispose();
    _durCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveGoals() async {
    if (!_formKey.currentState!.validate()) return;
    final prov = Provider.of<GoalProvider>(context, listen: false);
    await prov.updateGoals(
      int.parse(_stepsCtrl.text.trim()),
      double.parse(_calCtrl.text.trim()),
      int.parse(_durCtrl.text.trim()),
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Goals updated successfully'),
          backgroundColor: AppColors.splashLime,
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(title: const Text('Daily Goals')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: _stepsCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Daily Steps Target',
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _calCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Daily Calories Target (kcal)',
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _durCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Daily Workout Target (Minutes)',
              ),
            ),
            const SizedBox(height: 28),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.splashLime,
                foregroundColor: Colors.black,
                minimumSize: const Size.fromHeight(50),
              ),
              onPressed: _saveGoals,
              child: const Text(
                'Save Goals',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// PROFILE & SETTINGS SCREEN
// ============================================================================
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _athleteName = '';
  String _athleteMotto = 'Stronger • Healthier • Happier';
  Uint8List? _profileImageBytes;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      final savedImageBase64 = prefs.getString('user_profile_image_bytes');
      setState(() {
        _athleteName = prefs.getString('user_athlete_name') ?? '';
        _athleteMotto =
            prefs.getString('user_athlete_motto') ??
            'Stronger • Healthier • Happier';
        if (savedImageBase64 != null && savedImageBase64.isNotEmpty) {
          try {
            _profileImageBytes = base64Decode(savedImageBase64);
          } catch (_) {}
        }
      });
    }
  }

  Future<void> _saveProfileData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_athlete_name', _athleteName);
    await prefs.setString('user_athlete_motto', _athleteMotto);
    if (_profileImageBytes != null) {
      final base64String = base64Encode(_profileImageBytes!);
      await prefs.setString('user_profile_image_bytes', base64String);
    } else {
      await prefs.remove('user_profile_image_bytes');
    }
  }

  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.backgroundDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Profile Photo',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimaryDark,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Choose photo from camera or gallery',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondaryDark,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.splashLime,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _pickImage(ImageSource.camera);
                    },
                    icon: const Icon(Icons.camera_alt, color: Colors.black),
                    label: const Text(
                      'Camera',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.08),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _pickImage(ImageSource.gallery);
                    },
                    icon: const Icon(Icons.photo_library),
                    label: const Text(
                      'Gallery',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
            if (_profileImageBytes != null) ...[
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: () {
                    setState(() => _profileImageBytes = null);
                    _saveProfileData();
                    Navigator.pop(ctx);
                  },
                  child: const Text(
                    'Remove Photo',
                    style: TextStyle(color: Colors.redAccent),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        setState(() => _profileImageBytes = bytes);
        await _saveProfileData();
      }
    } catch (_) {}
  }

  void _showEditNameSheet() {
    final nameCtrl = TextEditingController(text: _athleteName);
    final mottoCtrl = TextEditingController(text: _athleteMotto);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.backgroundDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          left: 20,
          right: 20,
          top: 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Set Your Name',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimaryDark,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameCtrl,
              style: const TextStyle(color: AppColors.textPrimaryDark),
              decoration: InputDecoration(
                labelText: 'Your Name',
                hintText: 'Enter your name',
                hintStyle: const TextStyle(color: AppColors.textSecondaryDark),
                labelStyle: const TextStyle(color: AppColors.textSecondaryDark),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: mottoCtrl,
              style: const TextStyle(color: AppColors.textPrimaryDark),
              decoration: InputDecoration(
                labelText: 'Motto / Status',
                hintText: 'Stronger • Healthier • Happier',
                hintStyle: const TextStyle(color: AppColors.textSecondaryDark),
                labelStyle: const TextStyle(color: AppColors.textSecondaryDark),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.splashLime,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () {
                  setState(() {
                    _athleteName = nameCtrl.text.trim();
                    _athleteMotto = mottoCtrl.text.trim().isNotEmpty
                        ? mottoCtrl.text.trim()
                        : 'Stronger • Healthier • Happier';
                  });
                  _saveProfileData();
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      backgroundColor: AppColors.splashLime,
                      content: Text(
                        'Name saved permanently!',
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                },
                child: const Text(
                  'Save',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPrivacySecuritySheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.backgroundDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF332412),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.verified_user_rounded,
                      color: Color(0xFFFFA726),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Privacy & Security',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimaryDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Text(
                'Your health data is 100% private and protected:\n\n'
                '• 100% On-Device Storage: All step counts, calories, and workout history are stored exclusively in your phone\'s local encrypted SQLite database.\n\n'
                '• Zero Cloud Tracking: We do not upload, sell, or sync your private biometric data to external servers.\n\n'
                '• Complete Ownership: You can permanently wipe all your records anytime using the "Clear Local Data" button.',
                style: TextStyle(
                  color: AppColors.textSecondaryDark,
                  fontSize: 13.5,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.splashLime,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text(
                    'Understood',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showHelpSupportSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.backgroundDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF102D33),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.support_agent_rounded,
                      color: Color(0xFF26C6DA),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Help & Support',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimaryDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Text(
                'Frequently Asked Questions (FAQ)',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: AppColors.textPrimaryDark,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '• How are steps calculated?\nSteps use real hardware accelerometer and motion sensors with intelligent cadence filters.\n\n'
                '• Can I recover deleted workouts?\nOnce deleted from local storage, workouts cannot be recovered.',
                style: TextStyle(
                  color: AppColors.textSecondaryDark,
                  fontSize: 12.5,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              const Divider(color: AppColors.borderDark),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text(
                    'App Version',
                    style: TextStyle(
                      color: AppColors.textSecondaryDark,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    'FitTrack Pro v1.0.0',
                    style: TextStyle(
                      color: AppColors.splashLime,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.splashLime,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Support email: support@fittrack.app'),
                      ),
                    );
                  },
                  icon: const Icon(Icons.email_outlined, color: Colors.black),
                  label: const Text(
                    'Contact Support Team',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              children: [
                InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.arrow_back,
                      color: AppColors.splashLime,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Profile & Settings',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimaryDark,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Manage your account, goals and preferences',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondaryDark,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.splashLime.withValues(alpha: 0.18),
                    AppColors.backgroundDark,
                  ],
                ),
                border: Border.all(
                  color: AppColors.splashLime.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: _showImagePickerOptions,
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 36,
                          backgroundColor: AppColors.splashLime,
                          backgroundImage: _profileImageBytes != null
                              ? MemoryImage(_profileImageBytes!)
                              : null,
                          child: _profileImageBytes == null
                              ? const Icon(
                                  Icons.person,
                                  size: 40,
                                  color: Colors.black,
                                )
                              : null,
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Colors.black87,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: GestureDetector(
                      onTap: _showEditNameSheet,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _athleteName.isNotEmpty
                                ? _athleteName
                                : 'Set your name',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: _athleteName.isNotEmpty
                                  ? AppColors.textPrimaryDark
                                  : AppColors.splashLime,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _athleteMotto,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondaryDark,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppColors.splashLime.withValues(
                                  alpha: 0.6,
                                ),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(
                                  Icons.workspace_premium,
                                  size: 14,
                                  color: AppColors.splashLime,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Premium Member',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.splashLime,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.chevron_right,
                      color: AppColors.textSecondaryDark,
                    ),
                    onPressed: _showEditNameSheet,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            const _SectionHeader(title: 'Account'),
            const SizedBox(height: 10),
            _SettingsGroup(
              children: [
                _SettingsTile(
                  icon: Icons.gps_fixed_rounded,
                  iconColor: Colors.white,
                  gradient: const [Color(0xFF43A047), Color(0xFF1B5E20)],
                  title: 'Daily Goals',
                  subtitle: 'Set and track your fitness goals',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const GoalsScreen()),
                  ),
                ),
                _SettingsTile(
                  icon: Icons.delete_rounded,
                  iconColor: Colors.white,
                  gradient: const [Color(0xFFE53935), Color(0xFFB71C1C)],
                  title: 'Clear Local Data',
                  subtitle: 'Remove all saved data from this device',
                  onTap: () {
                    Provider.of<ActivityProvider>(
                      context,
                      listen: false,
                    ).clearAllActivities();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('All data cleared successfully'),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
            const _SectionHeader(title: 'Preferences'),
            const SizedBox(height: 10),
            _SettingsGroup(
              children: [
                _SettingsTile(
                  icon: Icons.notifications_rounded,
                  iconColor: Colors.white,
                  gradient: const [Color(0xFF42A5F5), Color(0xFF0D47A1)],
                  title: 'Notifications',
                  subtitle: 'Workout reminders, achievements & more',
                  onTap: () {},
                ),
                _SettingsTile(
                  icon: Icons.dark_mode_rounded,
                  iconColor: Colors.white,
                  gradient: const [Color(0xFFAB47BC), Color(0xFF4A148C)],
                  title: 'Appearance',
                  subtitle: 'Light / Dark mode',
                  onTap: () {},
                ),
                _SettingsTile(
                  icon: Icons.public_rounded,
                  iconColor: Colors.white,
                  gradient: const [Color(0xFF26C6DA), Color(0xFF006064)],
                  title: 'Language',
                  subtitle: 'English (Default)',
                  onTap: () {},
                ),
                _SettingsTile(
                  icon: Icons.verified_user_rounded,
                  iconColor: Colors.white,
                  gradient: const [Color(0xFFFFA726), Color(0xFFE65100)],
                  title: 'Privacy & Security',
                  subtitle: 'Your data is safe with us',
                  onTap: _showPrivacySecuritySheet,
                ),
              ],
            ),
            const SizedBox(height: 24),
            const _SectionHeader(title: 'Support'),
            const SizedBox(height: 10),
            _SettingsGroup(
              children: [
                _SettingsTile(
                  icon: Icons.support_agent_rounded,
                  iconColor: Colors.white,
                  gradient: const [Color(0xFF26C6DA), Color(0xFF006064)],
                  title: 'Help & Support',
                  subtitle: 'Get help or contact us',
                  onTap: _showHelpSupportSheet,
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});
  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimaryDark,
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  final List<Widget> children;
  const _SettingsGroup({required this.children});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1)
              Divider(
                height: 1,
                color: Colors.white.withValues(alpha: 0.06),
                indent: 72,
              ),
          ],
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final List<Color> gradient;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.gradient,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(13),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: gradient,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: gradient.last.withValues(alpha: 0.45),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(icon, color: iconColor, size: 21),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimaryDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondaryDark,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: AppColors.textSecondaryDark,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// 12. MAIN ENTRYPOINT
// ============================================================================
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FitTrackApp());
}

class FitTrackApp extends StatelessWidget {
  const FitTrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => ActivityProvider()..loadActivities(),
        ),
        ChangeNotifierProvider(create: (_) => GoalProvider()..loadGoals()),
        ChangeNotifierProvider(
          create: (_) => StepTrackerProvider()..initTracker(),
        ),
      ],
      child: MaterialApp(
        title: 'Fitness Tracker',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.dark,
        home: const SplashScreen(),
      ),
    );
  }
}
