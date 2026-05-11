import 'package:uuid/uuid.dart';

import 'workflow_node.dart';

class TaskPhase {
  final String name;
  final Duration duration;
  final bool autoStartNext;

  TaskPhase({
    required this.name,
    required this.duration,
    this.autoStartNext = false,
  });

  // Convert to JSON for storage
  Map<String, dynamic> toJson() => {
    'name': name,
    'duration': duration.inSeconds,
    'autoStartNext': autoStartNext,
  };

  factory TaskPhase.fromJson(Map<String, dynamic> json) {
    return TaskPhase(
      name: json['name'] as String? ?? 'Phase',
      duration: Duration(seconds: json['duration'] as int? ?? 0),
      autoStartNext: json['autoStartNext'] as bool? ?? false,
    );
  }
}

class MainTask {
  final String title;
  final List<TaskPhase> phases;
  int currentPhaseIndex;

  MainTask({
    required this.title,
    required this.phases,
    this.currentPhaseIndex = 0,
  });
}

class RoutineTemplate {
  final String name;
  final List<TaskPhase> phases;
  final int originalDurationSeconds;

  RoutineTemplate({
    required this.name,
    required this.phases,
    this.originalDurationSeconds = 0,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'phases': phases.map((phase) => phase.toJson()).toList(),
    'originalDurationSeconds': originalDurationSeconds,
  };

  factory RoutineTemplate.fromJson(Map<String, dynamic> json) {
    final phasesJson = json['phases'] as List<dynamic>? ?? const <dynamic>[];
    return RoutineTemplate(
      name: json['name'] as String? ?? 'Untitled Template',
      phases: phasesJson
          .whereType<Map<String, dynamic>>()
          .map(TaskPhase.fromJson)
          .toList(),
      originalDurationSeconds: json['originalDurationSeconds'] as int? ?? 0,
    );
  }
}

class FlowTemplate {
  final String id;
  final String name;
  final List<WorkflowNode> startingNodes;

  FlowTemplate({
    String? id,
    required this.name,
    required this.startingNodes,
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'startingNodes': startingNodes.map((node) => node.toJson()).toList(),
  };

  factory FlowTemplate.fromJson(Map<String, dynamic> json) {
    final nodesJson = json['startingNodes'] as List<dynamic>? ?? const <dynamic>[];
    return FlowTemplate(
      id: json['id'] as String?,
      name: json['name'] as String? ?? 'Untitled Flow',
      startingNodes: nodesJson
          .whereType<Map<String, dynamic>>()
          .map(WorkflowNode.fromJson)
          .toList(),
    );
  }

  /// Snapshot for “Save as new template” (new id, new name, deep-copied nodes).
  FlowTemplate copyAsNewNamed(String newName) {
    final nodesJson = startingNodes.map((n) => n.toJson()).toList();
    return FlowTemplate.fromJson({
      'id': const Uuid().v4(),
      'name': newName,
      'startingNodes': nodesJson,
    });
  }
}
