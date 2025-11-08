import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:battery_plus/battery_plus.dart';

/// Battery monitoring and optimization service
/// Automatically adjusts wake word detection based on battery level
class BatteryService {
  final Battery _battery = Battery();
  int? _batteryLevel;
  BatteryState _batteryState = BatteryState.unknown;

  // Thresholds
  static const int lowBatteryThreshold = 20; // Below 20%: aggressive saving
  static const int mediumBatteryThreshold = 50; // Below 50%: moderate saving

  // Callbacks
  final Function(bool shouldOptimize)? onBatteryOptimizationChange;
  final Function(int level)? onBatteryLevelChange;

  StreamSubscription<BatteryState>? _stateSubscription;

  BatteryService({
    this.onBatteryOptimizationChange,
    this.onBatteryLevelChange,
  });

  /// Initialize battery monitoring
  Future<void> initialize() async {
    try {
      _batteryLevel = await _battery.batteryLevel;
      _batteryState = await _battery.batteryState;

      // Listen to battery state changes
      _stateSubscription = _battery.onBatteryStateChanged.listen((state) {
        _batteryState = state;
        _checkBatteryOptimization();
        debugPrint('🔋 Battery state: $state');
      });

      // Start periodic level check (every 5 minutes)
      Timer.periodic(const Duration(minutes = 5), (_) => _updateBatteryLevel());

      debugPrint('✓ BatteryService initialized (level: $_batteryLevel%)');
    } catch (e) {
      debugPrint('✗ BatteryService error: $e');
    }
  }

  Future<void> _updateBatteryLevel() async {
    final previousLevel = _batteryLevel;
    _batteryLevel = await _battery.batteryLevel;

    if (previousLevel != _batteryLevel) {
      onBatteryLevelChange?.call(_batteryLevel!);
      _checkBatteryOptimization();
      debugPrint('🔋 Battery level: $_batteryLevel%');
    }
  }

  void _checkBatteryOptimization() {
    if (_batteryLevel == null) return;

    final shouldOptimize = _batteryLevel! < mediumBatteryThreshold &&
        _batteryState != BatteryState.charging;

    onBatteryOptimizationChange?.call(shouldOptimize);
  }

  /// Get current battery optimization recommendation
  BatteryOptimizationLevel getOptimizationLevel() {
    if (_batteryLevel == null) {
      return BatteryOptimizationLevel.normal;
    }

    if (_batteryState == BatteryState.charging) {
      return BatteryOptimizationLevel.normal; // No optimization while charging
    }

    if (_batteryLevel! < lowBatteryThreshold) {
      return BatteryOptimizationLevel.aggressive;
    } else if (_batteryLevel! < mediumBatteryThreshold) {
      return BatteryOptimizationLevel.moderate;
    }

    return BatteryOptimizationLevel.normal;
  }

  /// Get recommendations based on battery level
  Map<String, bool> getRecommendations() {
    final level = getOptimizationLevel();

    return {
      'enableWakeWord': level != BatteryOptimizationLevel.aggressive,
      'enableContinuousListening': level == BatteryOptimizationLevel.normal,
      'enableHapticFeedback': level == BatteryOptimizationLevel.normal,
      'enableAnimations': level != BatteryOptimizationLevel.aggressive,
      'reducedPolling': level != BatteryOptimizationLevel.normal,
    };
  }

  /// Dispose resources
  void dispose() {
    _stateSubscription?.cancel();
    debugPrint('🧹 BatteryService disposed');
  }

  // Getters

  int? get batteryLevel => _batteryLevel;
  BatteryState get batteryState => _batteryState;
  bool get isCharging => _batteryState == BatteryState.charging;
  bool get isLowBattery =>
      _batteryLevel != null && _batteryLevel! < lowBatteryThreshold;

  /// Get estimated hours remaining for wake word detection
  double? get estimatedHoursRemaining {
    if (_batteryLevel == null || isCharging) return null;

    // Wake word uses ~1.5% per hour
    const batteryUsagePerHour = 1.5;
    return _batteryLevel! / batteryUsagePerHour;
  }
}

enum BatteryOptimizationLevel {
  normal, // > 50% or charging
  moderate, // 20-50%
  aggressive, // < 20%
}
