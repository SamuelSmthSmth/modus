import '../models/app_mode.dart';

class StudySession {
  final DateTime date;
  final int durationInSeconds;
  final AppMode mode;
  final SessionType type;

  StudySession({
    required this.date,
    required this.durationInSeconds,
    required this.mode,
    required this.type,
  });

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'durationInSeconds': durationInSeconds,
      'mode': mode.toString(),
      'type': type.toString(),
    };
  }

  /// Create from JSON
  factory StudySession.fromJson(Map<String, dynamic> json) {
    final seconds = json['durationInSeconds'] as int?;
    final minutes = json['durationMinutes'] as int?;
    return StudySession(
      date: DateTime.parse(json['date'] as String),
      durationInSeconds: seconds ?? ((minutes ?? 0) * 60),
      mode: _parseAppMode(json['mode'] as String),
      type: _parseSessionType(json['type'] as String),
    );
  }

  static AppMode _parseAppMode(String value) {
    if (value.contains('pomodoro')) return AppMode.pomodoro;
    if (value.contains('zen')) return AppMode.zen;
    return AppMode.timer;
  }

  static SessionType _parseSessionType(String value) {
    if (value.contains('Break')) return SessionType.break_;
    return SessionType.work;
  }
}

enum SessionType { work, break_ }
