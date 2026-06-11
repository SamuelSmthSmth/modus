import 'dart:math';

abstract class WorkflowNode {
  static final Random _random = Random();

  final String id;
  final String type;

  WorkflowNode({String? id, required this.type}) : id = id ?? _generateId();

  Map<String, dynamic> toJson();

  factory WorkflowNode.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String?;
    switch (type) {
      case 'start':
        return StartNode.fromJson(json);
      case 'work':
        return WorkNode.fromJson(json);
      case 'decision':
        return DecisionNode.fromJson(json);
      case 'loop':
        return LoopNode.fromJson(json);
      case 'jump':
        return JumpNode.fromJson(json);
      case 'end':
        return EndNode.fromJson(json);
      case 'action':
        return ActionNode.fromJson(json);
      default:
        throw ArgumentError('Unknown workflow node type: $type');
    }
  }

  static String _generateId() {
    final timestamp = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final randomPart = _random.nextInt(1 << 32).toRadixString(36);
    return '$timestamp-$randomPart';
  }
}

class StartNode extends WorkflowNode {
  final String title;

  StartNode({super.id, String? type, required this.title})
    : super(type: type ?? 'start');

  factory StartNode.fromJson(Map<String, dynamic> json) {
    return StartNode(
      id: json['id'] as String?,
      title: json['title'] as String? ?? 'Start',
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {'id': id, 'type': type, 'title': title};
  }
}

class WorkNode extends WorkflowNode {
  final String title;
  final int durationSeconds;
  final bool autoStart;

  Duration get duration => Duration(seconds: durationSeconds);
  int get durationMinutes => durationSeconds ~/ 60;

  WorkNode({
    super.id,
    String? type,
    required this.title,
    int? durationMinutes,
    int? durationSeconds,
    this.autoStart = false,
  }) : durationSeconds = durationSeconds ?? ((durationMinutes ?? 0) * 60),
       super(type: type ?? 'work');

  factory WorkNode.fromJson(Map<String, dynamic> json) {
    final seconds = json['durationSeconds'] as int?;
    final minutes = json['durationMinutes'] as int?;
    return WorkNode(
      id: json['id'] as String?,
      title: json['title'] as String? ?? 'Work',
      durationSeconds: seconds ?? ((minutes ?? 0) * 60),
      autoStart: json['autoStart'] as bool? ?? false,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'title': title,
      'durationSeconds': durationSeconds,
      'durationMinutes': durationMinutes,
      'autoStart': autoStart,
    };
  }
}

class DecisionNode extends WorkflowNode {
  final String question;
  final List<WorkflowNode> pathA;
  final List<WorkflowNode> pathB;
  final String labelA;
  final String labelB;

  DecisionNode({
    super.id,
    String? type,
    required this.question,
    required this.pathA,
    required this.pathB,
    required this.labelA,
    required this.labelB,
  }) : super(type: type ?? 'decision');

  factory DecisionNode.fromJson(Map<String, dynamic> json) {
    final pathAJson = json['pathA'] as List<dynamic>? ?? const <dynamic>[];
    final pathBJson = json['pathB'] as List<dynamic>? ?? const <dynamic>[];

    return DecisionNode(
      id: json['id'] as String?,
      question: json['question'] as String? ?? '',
      pathA: pathAJson
          .whereType<Map<String, dynamic>>()
          .map(WorkflowNode.fromJson)
          .toList(),
      pathB: pathBJson
          .whereType<Map<String, dynamic>>()
          .map(WorkflowNode.fromJson)
          .toList(),
      labelA: json['labelA'] as String? ?? 'Yes',
      labelB: json['labelB'] as String? ?? 'No',
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'question': question,
      'pathA': pathA.map((node) => node.toJson()).toList(),
      'pathB': pathB.map((node) => node.toJson()).toList(),
      'labelA': labelA,
      'labelB': labelB,
    };
  }
}

class LoopNode extends WorkflowNode {
  final String title;
  final int totalMinutes;
  final List<WorkflowNode> tasks;

  LoopNode({
    super.id,
    String? type,
    required this.title,
    required this.totalMinutes,
    required this.tasks,
  }) : super(type: type ?? 'loop');

  factory LoopNode.fromJson(Map<String, dynamic> json) {
    final tasksJson = json['tasks'] as List<dynamic>? ?? const <dynamic>[];
    return LoopNode(
      id: json['id'] as String?,
      title: json['title'] as String? ?? 'Loop',
      totalMinutes: json['totalMinutes'] as int? ?? 20,
      tasks: tasksJson
          .whereType<Map<String, dynamic>>()
          .map(WorkflowNode.fromJson)
          .toList(),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'title': title,
      'totalMinutes': totalMinutes,
      'tasks': tasks.map((node) => node.toJson()).toList(),
    };
  }
}

class EndNode extends WorkflowNode {
  final String title;

  EndNode({super.id, String? type, required this.title})
    : super(type: type ?? 'end');

  factory EndNode.fromJson(Map<String, dynamic> json) {
    return EndNode(
      id: json['id'] as String?,
      title: json['title'] as String? ?? 'End',
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {'id': id, 'type': type, 'title': title};
  }
}

class JumpNode extends WorkflowNode {
  final String targetNodeId;

  JumpNode({super.id, String? type, required this.targetNodeId})
    : super(type: type ?? 'jump');

  factory JumpNode.fromJson(Map<String, dynamic> json) {
    return JumpNode(
      id: json['id'] as String?,
      targetNodeId: json['targetNodeId'] as String? ?? '',
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {'id': id, 'type': type, 'targetNodeId': targetNodeId};
  }
}

class ActionNode extends WorkflowNode {
  final String actionType;

  ActionNode({super.id, String? type, required this.actionType})
    : super(type: type ?? 'action');

  factory ActionNode.fromJson(Map<String, dynamic> json) {
    return ActionNode(
      id: json['id'] as String?,
      actionType: json['actionType'] as String? ?? '',
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {'id': id, 'type': type, 'actionType': actionType};
  }
}
