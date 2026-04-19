import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/app_mode.dart';
import '../../models/study_session.dart';

class StatsProvider extends ChangeNotifier {
  List<StudySession> _sessions = [];

  StatsProvider() {
    _loadSessions();
  }

  List<StudySession> get sessions => _sessions;

  Future<void> _loadSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('study_sessions');

    if (jsonString != null) {
      try {
        final List<dynamic> jsonList = jsonDecode(jsonString);
        _sessions = jsonList
            .map((item) => StudySession.fromJson(item as Map<String, dynamic>))
            .toList();
      } catch (e) {
        debugPrint('Error loading sessions: $e');
        _sessions = [];
      }
    }
    notifyListeners();
  }

  Future<void> _saveSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(
      _sessions.map((session) => session.toJson()).toList(),
    );
    await prefs.setString('study_sessions', jsonString);
  }

  /// Log a new study session
  Future<void> logSession({
    required int durationInSeconds,
    required AppMode mode,
    required SessionType type,
  }) async {
    if (durationInSeconds <= 0) {
      return;
    }

    final session = StudySession(
      date: DateTime.now(),
      durationInSeconds: durationInSeconds,
      mode: mode,
      type: type,
    );
    _sessions.add(session);
    await _saveSessions();
    notifyListeners();
  }

  /// Export sessions to CSV format (returns the CSV string)
  String exportToCSV() {
    final buffer = StringBuffer();

    // CSV header
    buffer.writeln('Date,Time,Duration (sec),Mode,Type');

    // CSV rows
    for (final session in _sessions) {
      final dateStr = _formatDate(session.date);
      final timeStr = _formatTime(session.date);
      final durationStr = session.durationInSeconds;
      final modeStr = _modeToString(session.mode);
      final typeStr = _typeToString(session.type);

      buffer.writeln('$dateStr,$timeStr,$durationStr,$modeStr,$typeStr');
    }

    final csv = buffer.toString();
    debugPrint('=== CSV Export ===\n$csv');
    return csv;
  }

  /// Get total focus time
  Duration getTotalFocusTime() {
    int totalSeconds = 0;
    for (final session in _sessions) {
      if (session.type == SessionType.work) {
        totalSeconds += session.durationInSeconds;
      }
    }
    return Duration(seconds: totalSeconds);
  }

  /// Get total sessions count
  int getTotalSessions() {
    return _sessions.length;
  }

  /// Get work sessions count
  int getWorkSessions() {
    return _sessions.where((s) => s.type == SessionType.work).length;
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _modeToString(AppMode mode) {
    switch (mode) {
      case AppMode.timer:
        return 'Timer';
      case AppMode.pomodoro:
        return 'Pomodoro';
      case AppMode.zen:
        return 'Zen';
    }
  }

  String _typeToString(SessionType type) {
    switch (type) {
      case SessionType.work:
        return 'Work';
      case SessionType.break_:
        return 'Break';
    }
  }
}
