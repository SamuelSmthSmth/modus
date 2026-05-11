import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_navigator.dart';
import '../../core/settings_provider.dart';
import '../../models/app_mode.dart';
import '../../models/study_session.dart';
import '../../models/workflow_node.dart';
import '../stats/stats_provider.dart';
import '../tasks/task_provider.dart';

class TimerProvider extends ChangeNotifier {
  static const String _timerDurationKey = 'custom_duration_timer_seconds';
  static const String _pomodoroDurationKey = 'custom_duration_pomodoro_seconds';
  static const String _legacyZenDurationKey = 'custom_duration_zen_seconds';
  static const String _flowDurationKey = 'custom_duration_flow_seconds';

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
    AppMode.flow: const Duration(minutes: 30),
  };
  String? _pendingDecisionNodeId;
  bool _isDecisionDialogOpen = false;

  /// Kind of session this countdown belongs to (independent of the visible tab / [_mode]).
  AppMode? _countdownSessionMode;

  // Getters for the UI
  Duration get remaining => _remaining;
  bool get isRunning => _isRunning;
  Duration get activeSessionDuration => _activeSessionDuration;
  String? get pendingDecisionNodeId => _pendingDecisionNodeId;

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
  Future<void> startTimer(Duration duration, {AppMode? sessionMode}) async {
    if (duration <= Duration.zero) return;

    _countdownSessionMode = sessionMode ?? _countdownSessionMode ?? _mode;

    final prefs = await SharedPreferences.getInstance();
    _endTime = DateTime.now().add(duration);
    _remaining = duration;
    _activeSessionDuration = duration;

    // Save to disk so we can recover on reboot
    await prefs.setInt('timer_end_timestamp', _endTime!.millisecondsSinceEpoch);

    _isRunning = true;
    _pendingDecisionNodeId = null;
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
    _pendingDecisionNodeId = null;
    _isDecisionDialogOpen = false;
    _countdownSessionMode = null;
    _taskProvider?.setActiveNodeId(null);

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('timer_end_timestamp');
    notifyListeners();
  }

  Future<void> startOrResumeFlow() async {
    if (_mode != AppMode.flow) {
      return;
    }
    final taskProvider = _taskProvider;
    final activeFlow = taskProvider?.activeFlow;
    if (taskProvider == null || activeFlow == null) {
      return;
    }
    if (_pendingDecisionNodeId != null) {
      return;
    }

    final activeId = taskProvider.activeNodeId;
    _FlowLocation? location;
    if (activeId != null) {
      location = _findNodeById(activeFlow.startingNodes, activeId);
    }
    location ??= _findFirstWorkAfterStart(activeFlow.startingNodes);

    if (location == null) {
      return;
    }
    final started = await _enterFromLocation(location, autoStart: true);
    if (!started) {
      notifyListeners();
    }
  }

  Future<void> resolveFlowDecision(bool choosePathA) async {
    final decisionId = _pendingDecisionNodeId;
    final taskProvider = _taskProvider;
    final flow = taskProvider?.activeFlow;
    if (decisionId == null || taskProvider == null || flow == null) {
      return;
    }
    final decisionLocation = _findNodeById(flow.startingNodes, decisionId);
    if (decisionLocation == null || decisionLocation.node is! DecisionNode) {
      _pendingDecisionNodeId = null;
      notifyListeners();
      return;
    }

    final decisionNode = decisionLocation.node as DecisionNode;
    final selectedPath = choosePathA ? decisionNode.pathA : decisionNode.pathB;
    _pendingDecisionNodeId = null;
    _isDecisionDialogOpen = false;

    if (selectedPath.isEmpty) {
      final next = _nextInSameList(decisionLocation);
      if (next == null) {
        taskProvider.setActiveNodeId(null);
        return;
      }
      await _enterFromLocation(next, autoStart: false);
      return;
    }

    final started = await _enterFromLocation(
      _FlowLocation(list: selectedPath, index: 0, node: selectedPath[0]),
      autoStart: false,
    );
    if (!started) {
      notifyListeners();
    }
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
      final sessionKind = _countdownSessionMode ?? _mode;

      SessionType sessionType = SessionType.work;
      if (sessionKind == AppMode.pomodoro) {
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
          mode: sessionKind,
          type: sessionType,
        );
      }

      final handledFlow = await _handleFlowNodeCompletion();
      if (handledFlow) {
        return;
      }
      final shouldRestart = await _handlePomodoroPhaseCompletion();
      if (!shouldRestart) {
        final keepSessionKind =
            _pendingDecisionNodeId != null ||
            (_countdownSessionMode == AppMode.flow &&
                _taskProvider?.activeNodeId != null);
        if (!keepSessionKind) {
          _countdownSessionMode = null;
        }
        notifyListeners();
      }
      return;
    }

    _remaining = _endTime!.difference(now);
    notifyListeners(); // This tells the UI to rebuild
  }

  Future<bool> _handleFlowNodeCompletion() async {
    if (_countdownSessionMode != AppMode.flow) {
      return false;
    }
    final taskProvider = _taskProvider;
    final flow = taskProvider?.activeFlow;
    final activeNodeId = taskProvider?.activeNodeId;
    if (taskProvider == null || flow == null || activeNodeId == null) {
      return false;
    }
    final currentLocation = _findNodeById(flow.startingNodes, activeNodeId);
    if (currentLocation == null) {
      taskProvider.setActiveNodeId(null);
      return false;
    }

    final next = _nextInSameList(currentLocation);
    if (next == null) {
      taskProvider.setActiveNodeId(null);
      return false;
    }
    return _enterFromLocation(next, autoStart: false);
  }

  Future<bool> _enterFromLocation(
    _FlowLocation location, {
    required bool autoStart,
  }) async {
    final taskProvider = _taskProvider;
    final flow = taskProvider?.activeFlow;
    if (taskProvider == null || flow == null) {
      return false;
    }

    var current = location;
    var autoRun = autoStart;
    var guard = 0;
    while (guard < 200) {
      guard++;
      final node = current.node;
      taskProvider.setActiveNodeId(node.id);

      if (node is WorkNode) {
        _remaining = node.duration;
        if (autoRun || node.autoStart) {
          await startTimer(node.duration, sessionMode: AppMode.flow);
          return true;
        }
        notifyListeners();
        return false;
      }

      if (node is DecisionNode) {
        _pendingDecisionNodeId = node.id;
        notifyListeners();
        unawaited(_showGlobalDecisionDialog(node));
        return false;
      }

      if (node is JumpNode) {
        final jumpTarget = _findNodeById(flow.startingNodes, node.targetNodeId);
        if (jumpTarget == null) {
          taskProvider.setActiveNodeId(null);
          notifyListeners();
          return false;
        }
        current = jumpTarget;
        autoRun = true;
        continue;
      }

      if (node is EndNode) {
        await stopTimer();
        taskProvider.setActiveNodeId(null);
        return false;
      }

      final next = _nextInSameList(current);
      if (next == null) {
        taskProvider.setActiveNodeId(null);
        notifyListeners();
        return false;
      }
      current = next;
    }

    return false;
  }

  _FlowLocation? _findFirstWorkAfterStart(List<WorkflowNode> nodes) {
    var passedStart = false;
    for (var i = 0; i < nodes.length; i++) {
      final node = nodes[i];
      if (node is StartNode) {
        passedStart = true;
        continue;
      }
      if (passedStart && node is WorkNode) {
        return _FlowLocation(list: nodes, index: i, node: node);
      }
    }
    for (var i = 0; i < nodes.length; i++) {
      final node = nodes[i];
      if (node is WorkNode) {
        return _FlowLocation(list: nodes, index: i, node: node);
      }
    }
    return null;
  }

  _FlowLocation? _nextInSameList(_FlowLocation current) {
    final nextIndex = current.index + 1;
    if (nextIndex < 0 || nextIndex >= current.list.length) {
      return null;
    }
    return _FlowLocation(
      list: current.list,
      index: nextIndex,
      node: current.list[nextIndex],
    );
  }

  _FlowLocation? _findNodeById(List<WorkflowNode> nodes, String nodeId) {
    for (var i = 0; i < nodes.length; i++) {
      final node = nodes[i];
      if (node.id == nodeId) {
        return _FlowLocation(list: nodes, index: i, node: node);
      }
      if (node is DecisionNode) {
        final inA = _findNodeById(node.pathA, nodeId);
        if (inA != null) return inA;
        final inB = _findNodeById(node.pathB, nodeId);
        if (inB != null) return inB;
      }
      if (node is LoopNode) {
        final inLoop = _findNodeById(node.tasks, nodeId);
        if (inLoop != null) return inLoop;
      }
    }
    return null;
  }

  Future<void> _showGlobalDecisionDialog(DecisionNode decisionNode) async {
    if (_isDecisionDialogOpen) {
      return;
    }
    if (navigatorKey.currentContext == null) {
      return;
    }

    _isDecisionDialogOpen = true;
    final chooseA = await showDialog<bool>(
      context: navigatorKey.currentContext!,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Decision'),
        content: Text(decisionNode.question),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(decisionNode.labelB),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(decisionNode.labelA),
          ),
        ],
      ),
    );
    await resolveFlowDecision(chooseA ?? true);
  }

  Future<bool> _handlePomodoroPhaseCompletion() async {
    if (_countdownSessionMode != AppMode.pomodoro) {
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

    await startTimer(phase.duration, sessionMode: AppMode.pomodoro);
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
    _customDurations[AppMode.flow] = Duration(
      seconds:
          prefs.getInt(_flowDurationKey) ??
          prefs.getInt(_legacyZenDurationKey) ??
          _customDurations[AppMode.flow]!.inSeconds,
    );

    final savedTimestamp = prefs.getInt('timer_end_timestamp');

    if (savedTimestamp != null) {
      _endTime = DateTime.fromMillisecondsSinceEpoch(savedTimestamp);
      if (_endTime!.isAfter(DateTime.now())) {
        _remaining = _endTime!.difference(DateTime.now());
        _isRunning = true;
        _countdownSessionMode ??= _mode;
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
      _flowDurationKey,
      (_customDurations[AppMode.flow] ?? const Duration(minutes: 30)).inSeconds,
    );
  }

  @override
  void dispose() {
    _ticker?.cancel();
    unawaited(_audioPlayer.dispose());
    super.dispose();
  }
}

class _FlowLocation {
  final List<WorkflowNode> list;
  final int index;
  final WorkflowNode node;

  const _FlowLocation({
    required this.list,
    required this.index,
    required this.node,
  });
}
