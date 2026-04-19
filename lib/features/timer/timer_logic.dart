import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/settings_provider.dart';
import '../../models/app_mode.dart';
import '../../models/study_session.dart';
import '../stats/stats_provider.dart';
import '../tasks/task_provider.dart';

class TimerProvider extends ChangeNotifier {
  static const String _timerDurationKey = 'custom_duration_timer_seconds';
  static const String _pomodoroDurationKey = 'custom_duration_pomodoro_seconds';
  static const String _zenDurationKey = 'custom_duration_zen_seconds';

  Timer? _ticker;
  DateTime? _endTime;
  Duration _remaining = Duration.zero;
  Duration _activeSessionDuration = Duration.zero;
  bool _isRunning = false;
  AppMode _mode = AppMode.timer;
  TaskProvider? _taskProvider;
  SettingsProvider? _settingsProvider;
  StatsProvider? _statsProvider;
  final AudioPlayer _audioPlayer = AudioPlayer();
  final Map<AppMode, Duration> _customDurations = {
    AppMode.timer: const Duration(minutes: 10),
    AppMode.pomodoro: const Duration(minutes: 25),
    AppMode.zen: const Duration(minutes: 30),
  };

  // Getters for the UI
  Duration get remaining => _remaining;
  bool get isRunning => _isRunning;
  Duration get activeSessionDuration => _activeSessionDuration;

  Duration customDurationForMode(AppMode mode) {
    return _customDurations[mode] ?? const Duration(minutes: 10);
  }

  void setCustomDuration(AppMode mode, Duration duration) {
    if (duration <= Duration.zero) return;
    _customDurations[mode] = duration;
    if (!_isRunning && _mode == mode) {
      _remaining = duration;
    }
    unawaited(_saveCustomDurations());
    notifyListeners();
  }

  void setMode(AppMode mode) {
    _mode = mode;
    if (!_isRunning) {
      _remaining = customDurationForMode(mode);
      notifyListeners();
    }
  }

  void attachTaskProvider(TaskProvider taskProvider) {
    _taskProvider = taskProvider;
  }

  void attachSettingsProvider(SettingsProvider settingsProvider) {
    _settingsProvider = settingsProvider;
  }

  void attachStatsProvider(StatsProvider statsProvider) {
    _statsProvider = statsProvider;
  }

  /// Start the timer and save the timestamp
  Future<void> startTimer(Duration duration) async {
    if (duration <= Duration.zero) return;

    final prefs = await SharedPreferences.getInstance();
    _endTime = DateTime.now().add(duration);
    _remaining = duration;
    _activeSessionDuration = duration;

    // Save to disk so we can recover on reboot
    await prefs.setInt('timer_end_timestamp', _endTime!.millisecondsSinceEpoch);

    _isRunning = true;
    _startTicker();
    await _tick();
    notifyListeners();
  }

  Future<void> pauseTimer() async {
    final endTime = _endTime;
    final now = DateTime.now();
    if (endTime != null && endTime.isAfter(now)) {
      _remaining = endTime.difference(now);
    }

    _ticker?.cancel();
    _ticker = null;
    _endTime = null;
    _isRunning = false;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('timer_end_timestamp');
    notifyListeners();
  }

  Future<void> stopTimer() async {
    _ticker?.cancel();
    _endTime = null;
    _remaining = customDurationForMode(_mode);
    _activeSessionDuration = Duration.zero;
    _isRunning = false;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('timer_end_timestamp');
    notifyListeners();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      unawaited(_tick());
    });
  }

  Future<void> _tick() async {
    if (_endTime == null) return;

    final now = DateTime.now();
    if (!now.isBefore(_endTime!)) {
      _ticker?.cancel();
      _ticker = null;

      // Calculate the duration that just finished
      final elapsedDuration = _activeSessionDuration > Duration.zero
          ? _activeSessionDuration
          : _remaining;
      final durationInSeconds = elapsedDuration.inSeconds;

      _endTime = null;
      _remaining = Duration.zero;
      _activeSessionDuration = Duration.zero;
      _isRunning = false;

      final settings = _settingsProvider;
      if (settings?.hapticsEnabled ?? true) {
        unawaited(HapticFeedback.heavyImpact());
      }
      if (settings?.soundEnabled ?? true) {
        unawaited(_audioPlayer.play(AssetSource('audio/chime.mp3')));
      }

      // Log the session
      SessionType sessionType = SessionType.work;
      if (_mode == AppMode.pomodoro) {
        final taskProvider = _taskProvider;
        if (taskProvider != null) {
          final activeTask = taskProvider.activeTask;
          final phaseIndex = activeTask.currentPhaseIndex;
          // Infer breaks based on phase index: odd indices are breaks
          sessionType = phaseIndex % 2 == 1
              ? SessionType.break_
              : SessionType.work;
        }
      }

      final statsProvider = _statsProvider;
      if (statsProvider != null) {
        await statsProvider.logSession(
          durationInSeconds: durationInSeconds,
          mode: _mode,
          type: sessionType,
        );
      }

      final shouldRestart = await _handlePomodoroPhaseCompletion();
      if (!shouldRestart) {
        notifyListeners();
      }
      return;
    }

    _remaining = _endTime!.difference(now);
    notifyListeners(); // This tells the UI to rebuild
  }

  Future<bool> _handlePomodoroPhaseCompletion() async {
    if (_mode != AppMode.pomodoro) {
      return false;
    }

    final taskProvider = _taskProvider;
    if (taskProvider == null) {
      return false;
    }

    final advanced = taskProvider.advancePhase();
    if (!advanced) {
      return false;
    }

    final updatedTask = taskProvider.activeTask;

    final phaseIndex = updatedTask.currentPhaseIndex;
    if (phaseIndex < 0 || phaseIndex >= updatedTask.phases.length) {
      return false;
    }

    final phase = updatedTask.phases[phaseIndex];
    final settings = _settingsProvider;
    final shouldAutoStart =
        (settings?.globalAutoStart ?? false) || phase.autoStartNext;
    if (!shouldAutoStart) {
      return false;
    }

    await startTimer(phase.duration);
    return true;
  }

  /// The "Magic" Resume function
  Future<void> loadTimerState() async {
    final prefs = await SharedPreferences.getInstance();

    _customDurations[AppMode.timer] = Duration(
      seconds:
          prefs.getInt(_timerDurationKey) ??
          _customDurations[AppMode.timer]!.inSeconds,
    );
    _customDurations[AppMode.pomodoro] = Duration(
      seconds:
          prefs.getInt(_pomodoroDurationKey) ??
          _customDurations[AppMode.pomodoro]!.inSeconds,
    );
    _customDurations[AppMode.zen] = Duration(
      seconds:
          prefs.getInt(_zenDurationKey) ??
          _customDurations[AppMode.zen]!.inSeconds,
    );

    final savedTimestamp = prefs.getInt('timer_end_timestamp');

    if (savedTimestamp != null) {
      _endTime = DateTime.fromMillisecondsSinceEpoch(savedTimestamp);
      if (_endTime!.isAfter(DateTime.now())) {
        _remaining = _endTime!.difference(DateTime.now());
        _isRunning = true;
        _startTicker();
      } else {
        // Timer finished while app was closed
        _remaining = customDurationForMode(_mode);
        _isRunning = false;
      }
    } else {
      _remaining = customDurationForMode(_mode);
    }
    notifyListeners();
  }

  Future<void> _saveCustomDurations() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      _timerDurationKey,
      (_customDurations[AppMode.timer] ?? const Duration(minutes: 10))
          .inSeconds,
    );
    await prefs.setInt(
      _pomodoroDurationKey,
      (_customDurations[AppMode.pomodoro] ?? const Duration(minutes: 25))
          .inSeconds,
    );
    await prefs.setInt(
      _zenDurationKey,
      (_customDurations[AppMode.zen] ?? const Duration(minutes: 30)).inSeconds,
    );
  }

  @override
  void dispose() {
    _ticker?.cancel();
    unawaited(_audioPlayer.dispose());
    super.dispose();
  }
}
