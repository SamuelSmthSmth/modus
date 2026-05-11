import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../models/task_model.dart';
import '../../models/workflow_node.dart';

class TaskProvider extends ChangeNotifier {
  static const String _taskStorageKey = 'active_task';
  static const String _templateStorageKey = 'saved_routine_templates';
  static const String _flowTemplateStorageKey = 'saved_flow_templates';
  static const String _activeFlowIdKey = 'active_flow_template_id';

  MainTask _activeTask = MainTask(
    title: 'My Routine',
    phases: [],
    currentPhaseIndex: 0,
  );

  List<RoutineTemplate> savedTemplates = [];
  List<FlowTemplate> flowTemplates = [];
  FlowTemplate? activeFlow;
  String? activeNodeId;

  TaskProvider() {
    unawaited(_loadTaskFromDisk());
    unawaited(loadTemplatesFromDisk());
    unawaited(loadFlowTemplates());
  }

  MainTask get activeTask => _activeTask;

  Future<void> loadTemplatesFromDisk() async {
    final prefs = await SharedPreferences.getInstance();
    final rawTemplates =
        prefs.getStringList(_templateStorageKey) ?? const <String>[];

    final templates = <RoutineTemplate>[];
    for (final rawTemplate in rawTemplates) {
      try {
        final decoded = jsonDecode(rawTemplate);
        if (decoded is Map<String, dynamic>) {
          templates.add(RoutineTemplate.fromJson(decoded));
        }
      } catch (error) {
        debugPrint('Failed to load template: $error');
      }
    }

    savedTemplates = templates;
    notifyListeners();
  }

  Future<void> loadFlowTemplates() async {
    final prefs = await SharedPreferences.getInstance();
    final rawTemplates =
        prefs.getStringList(_flowTemplateStorageKey) ?? const <String>[];

    final templates = <FlowTemplate>[];
    var needsResave = false;
    for (final rawTemplate in rawTemplates) {
      try {
        final decoded = jsonDecode(rawTemplate);
        if (decoded is Map<String, dynamic>) {
          if (decoded['id'] == null) {
            needsResave = true;
          }
          templates.add(FlowTemplate.fromJson(decoded));
        }
      } catch (error) {
        debugPrint('Failed to load flow template: $error');
      }
    }

    flowTemplates = templates;
    await _restoreActiveFlowFromPrefs(prefs);
    if (needsResave && flowTemplates.isNotEmpty) {
      await saveFlowTemplates();
    }
    notifyListeners();
  }

  Future<void> _persistActiveFlowId() async {
    final flow = activeFlow;
    final prefs = await SharedPreferences.getInstance();
    if (flow == null) {
      await prefs.remove(_activeFlowIdKey);
      return;
    }
    await prefs.setString(_activeFlowIdKey, flow.id);
  }

  Future<void> _restoreActiveFlowFromPrefs(SharedPreferences prefs) async {
    if (flowTemplates.isEmpty) {
      activeFlow = null;
      activeNodeId = null;
      return;
    }
    final id = prefs.getString(_activeFlowIdKey);
    FlowTemplate? match;
    if (id != null) {
      for (final t in flowTemplates) {
        if (t.id == id) {
          match = t;
          break;
        }
      }
    }
    activeFlow = match ?? flowTemplates.first;
    activeNodeId = null;
  }

  Future<void> setActiveFlowById(String templateId) async {
    FlowTemplate? match;
    for (final t in flowTemplates) {
      if (t.id == templateId) {
        match = t;
        break;
      }
    }
    if (match == null) {
      return;
    }
    activeFlow = match;
    activeNodeId = null;
    await _persistActiveFlowId();
    notifyListeners();
  }

  Future<void> deleteFlowTemplate(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return;
    }

    final removedActiveFlow = activeFlow?.name == trimmed;
    flowTemplates = flowTemplates
        .where((template) => template.name != trimmed)
        .toList();

    if (removedActiveFlow) {
      activeFlow = null;
      activeNodeId = null;
    }

    await saveFlowTemplates();
    await _persistActiveFlowId();
    notifyListeners();
  }

  Future<void> saveActiveFlowAsNewTemplate(String name) async {
    final flow = activeFlow;
    if (flow == null) {
      return;
    }
    final trimmed = name.trim().isEmpty ? 'Untitled Flow' : name.trim();
    final existingIndex = flowTemplates.indexWhere(
      (template) => template.name == trimmed,
    );
    final snapshot = FlowTemplate(
      id: existingIndex == -1
          ? const Uuid().v4()
          : flowTemplates[existingIndex].id,
      name: trimmed,
      startingNodes: _cloneFlowNodes(flow.startingNodes),
    );

    if (existingIndex == -1) {
      flowTemplates = [...flowTemplates, snapshot];
    } else {
      final insertionIndex = existingIndex;
      flowTemplates = flowTemplates
          .where((template) => template.name != trimmed)
          .toList();
      flowTemplates.insert(insertionIndex, snapshot);
    }

    activeFlow = snapshot;
    activeNodeId = null;
    await saveFlowTemplates();
    await _persistActiveFlowId();
    notifyListeners();
  }

  void setActiveTask(MainTask task) {
    _activeTask = task;
    unawaited(_saveTaskToDisk());
    notifyListeners();
  }

  Future<void> saveCurrentAsTemplate(String name) async {
    final templateName = name.trim().isEmpty
        ? 'Untitled Template'
        : name.trim();
    final phases = List<TaskPhase>.from(_activeTask.phases);
    final originalDurationSeconds = phases.fold<int>(
      0,
      (total, phase) => total + phase.duration.inSeconds,
    );

    savedTemplates = [
      ...savedTemplates,
      RoutineTemplate(
        name: templateName,
        phases: phases,
        originalDurationSeconds: originalDurationSeconds,
      ),
    ];

    await _saveTemplatesToDisk();
    notifyListeners();
  }

  Future<void> saveFlowTemplates() async {
    final prefs = await SharedPreferences.getInstance();
    final payload = flowTemplates
        .map((template) => jsonEncode(template.toJson()))
        .toList();
    await prefs.setStringList(_flowTemplateStorageKey, payload);
  }

  List<WorkflowNode> _cloneFlowNodes(List<WorkflowNode> nodes) {
    return nodes
        .map((node) => WorkflowNode.fromJson(node.toJson()))
        .toList();
  }

  void addNodeToFlow(List<WorkflowNode> targetList, WorkflowNode newNode) {
    targetList.add(newNode);
    unawaited(saveFlowTemplates());
    notifyListeners();
  }

  void setActiveNodeId(String? nodeId) {
    activeNodeId = nodeId;
    notifyListeners();
  }

  void removeNodeFromFlow(List<WorkflowNode> targetList, WorkflowNode node) {
    targetList.remove(node);
    unawaited(saveFlowTemplates());
    notifyListeners();
  }

  void updateNodeInFlow(
    List<WorkflowNode> targetList,
    WorkflowNode oldNode,
    WorkflowNode updatedNode,
  ) {
    final index = targetList.indexOf(oldNode);
    if (index == -1) {
      return;
    }
    targetList[index] = updatedNode;
    unawaited(saveFlowTemplates());
    notifyListeners();
  }

  void deleteNode(String nodeId) {
    final flow = activeFlow;
    if (flow == null) {
      return;
    }
    final deleted = _deleteNodeRecursive(flow.startingNodes, nodeId);
    if (!deleted) {
      return;
    }
    if (activeNodeId == nodeId ||
        (activeNodeId != null &&
            !_nodeExistsRecursive(flow.startingNodes, activeNodeId!))) {
      activeNodeId = null;
    }
    unawaited(saveFlowTemplates());
    notifyListeners();
  }

  bool _deleteNodeRecursive(List<WorkflowNode> nodes, String nodeId) {
    for (var i = 0; i < nodes.length; i++) {
      final node = nodes[i];
      if (node.id == nodeId) {
        nodes.removeAt(i);
        return true;
      }
      if (node is DecisionNode) {
        if (_deleteNodeRecursive(node.pathA, nodeId)) {
          return true;
        }
        if (_deleteNodeRecursive(node.pathB, nodeId)) {
          return true;
        }
      } else if (node is LoopNode) {
        if (_deleteNodeRecursive(node.tasks, nodeId)) {
          return true;
        }
      }
    }
    return false;
  }

  bool _nodeExistsRecursive(List<WorkflowNode> nodes, String nodeId) {
    for (final node in nodes) {
      if (node.id == nodeId) {
        return true;
      }
      if (node is DecisionNode) {
        if (_nodeExistsRecursive(node.pathA, nodeId) ||
            _nodeExistsRecursive(node.pathB, nodeId)) {
          return true;
        }
      } else if (node is LoopNode) {
        if (_nodeExistsRecursive(node.tasks, nodeId)) {
          return true;
        }
      }
    }
    return false;
  }

  Future<void> createNewFlow(String name) async {
    final flowName = name.trim().isEmpty ? 'Untitled Flow' : name.trim();
    final template = FlowTemplate(
      name: flowName,
      startingNodes: [
        StartNode(id: const Uuid().v4(), type: 'start', title: 'START'),
      ],
    );

    flowTemplates = [...flowTemplates, template];
    activeFlow = template;
    activeNodeId = null;
    await saveFlowTemplates();
    await _persistActiveFlowId();
    notifyListeners();
  }

  Future<void> applyTemplate(RoutineTemplate template) async {
    _activeTask = MainTask(
      title: _activeTask.title,
      phases: List<TaskPhase>.from(template.phases),
      currentPhaseIndex: 0,
    );

    await _saveTaskToDisk();
    notifyListeners();
  }

  Future<void> deleteTemplate(int index) async {
    if (index < 0 || index >= savedTemplates.length) {
      return;
    }

    savedTemplates = List<RoutineTemplate>.from(savedTemplates)
      ..removeAt(index);
    await _saveTemplatesToDisk();
    notifyListeners();
  }

  bool advancePhase() {
    final task = _activeTask;

    final nextIndex = task.currentPhaseIndex + 1;
    if (nextIndex < task.phases.length) {
      task.currentPhaseIndex = nextIndex;
      notifyListeners();
      return true;
    }

    return false;
  }

  void loadMockTask() {
    _activeTask = MainTask(
      title: 'Biology Past Paper',
      phases: [
        TaskPhase(
          name: 'Setup and Scan Questions',
          duration: const Duration(minutes: 8),
        ),
        TaskPhase(
          name: 'Section A: Structured Answers',
          duration: const Duration(minutes: 35),
        ),
        TaskPhase(
          name: 'Section B: Extended Response',
          duration: const Duration(minutes: 30),
        ),
        TaskPhase(
          name: 'Review and Corrections',
          duration: const Duration(minutes: 12),
        ),
      ],
      currentPhaseIndex: 0,
    );

    notifyListeners();
  }

  Future<String?> importRoutineFromCSV() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result == null || result.files.isEmpty) {
        return null; // User cancelled
      }

      final file = result.files.first;

      // Read bytes: try file.bytes first, fall back to reading from path
      Uint8List? bytes = file.bytes;
      if (bytes == null) {
        if (file.path == null) {
          return 'Could not access file';
        }
        try {
          bytes = await File(file.path!).readAsBytes();
        } catch (e) {
          return 'Failed to read file: $e';
        }
      }

      // Decode bytes to string using UTF-8
      String csvContent;
      try {
        csvContent = utf8.decode(bytes);
      } catch (e) {
        return 'Invalid file encoding. Please use UTF-8 encoding.';
      }

      // Parse CSV
      List<List<dynamic>> rows;
      try {
        rows = const CsvToListConverter().convert(csvContent);
      } catch (e) {
        return 'Failed to parse CSV: $e';
      }

      if (rows.isEmpty) {
        return 'CSV file is empty';
      }

      // Smart header detection: check if first row contains mostly text (likely a header)
      final firstRow = rows[0];
      final isHeaderRow =
          firstRow.isNotEmpty &&
          (firstRow[0].toString().toLowerCase().contains('name') ||
              firstRow[0].toString().toLowerCase().contains('phase') ||
              firstRow[0].toString().toLowerCase().contains('duration'));

      final dataRows = isHeaderRow && rows.length > 1
          ? rows.skip(1).toList()
          : rows;

      final phases = <TaskPhase>[];
      int skippedRows = 0;

      for (final row in dataRows) {
        if (row.isEmpty || row.length < 2) {
          skippedRows++;
          continue;
        }

        try {
          final phaseName = (row[0]).toString().trim();
          if (phaseName.isEmpty) {
            skippedRows++;
            continue;
          }

          // Parse duration with error handling
          int minutes;
          try {
            final durationStr = (row[1]).toString().trim();
            minutes = int.parse(durationStr);
            if (minutes <= 0) {
              debugPrint('Skipping row with invalid duration: $durationStr');
              skippedRows++;
              continue;
            }
          } catch (e) {
            debugPrint('Failed to parse duration: ${row[1]}, error: $e');
            skippedRows++;
            continue;
          }

          // Parse autoStart (optional, defaults to false)
          bool autoStart = false;
          if (row.length > 2) {
            final autoStartStr = (row[2]).toString().trim().toLowerCase();
            autoStart =
                autoStartStr == 'true' ||
                autoStartStr == '1' ||
                autoStartStr == 'yes';
          }

          phases.add(
            TaskPhase(
              name: phaseName,
              duration: Duration(minutes: minutes),
              autoStartNext: autoStart,
            ),
          );
        } catch (e) {
          debugPrint('Error processing row: $row, error: $e');
          skippedRows++;
          continue;
        }
      }

      if (phases.isEmpty) {
        return 'No valid phases found in CSV. Please check the format: Name, Duration(minutes), AutoStart(true/false)';
      }

      _activeTask = MainTask(
        title: _activeTask.title,
        phases: phases,
        currentPhaseIndex: 0,
      );

      await _saveTaskToDisk();
      notifyListeners();

      if (skippedRows > 0) {
        debugPrint(
          'Imported $phases.length phases (skipped $skippedRows malformed rows)',
        );
      }

      return null; // Success
    } catch (error) {
      debugPrint('Failed to import CSV: $error');
      return 'Unexpected error: $error';
    }
  }

  Future<void> _saveTaskToDisk() async {
    final prefs = await SharedPreferences.getInstance();
    final payload = <String, dynamic>{
      'title': _activeTask.title,
      'currentPhaseIndex': _activeTask.currentPhaseIndex,
      'phases': _activeTask.phases
          .map(
            (phase) => <String, dynamic>{
              'name': phase.name,
              'durationSeconds': phase.duration.inSeconds,
              'autoStartNext': phase.autoStartNext,
            },
          )
          .toList(),
    };

    await prefs.setString(_taskStorageKey, jsonEncode(payload));
  }

  Future<void> _saveTemplatesToDisk() async {
    final prefs = await SharedPreferences.getInstance();
    final payload = savedTemplates
        .map((template) => jsonEncode(template.toJson()))
        .toList();
    await prefs.setStringList(_templateStorageKey, payload);
  }

  Future<void> _loadTaskFromDisk() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_taskStorageKey);
    if (raw == null || raw.isEmpty) {
      return;
    }

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final phasesJson = (decoded['phases'] as List<dynamic>? ?? <dynamic>[]);

      final phases = phasesJson
          .whereType<Map<String, dynamic>>()
          .map(
            (item) => TaskPhase(
              name: item['name'] as String? ?? 'Phase',
              duration: Duration(seconds: item['durationSeconds'] as int? ?? 0),
              autoStartNext: item['autoStartNext'] as bool? ?? false,
            ),
          )
          .toList();

      _activeTask = MainTask(
        title: decoded['title'] as String? ?? 'My Routine',
        phases: phases,
        currentPhaseIndex: decoded['currentPhaseIndex'] as int? ?? 0,
      );
      notifyListeners();
    } catch (error) {
      debugPrint('Failed to load task from disk: $error');
    }
  }
}
